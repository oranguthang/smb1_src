; -------------------------------------------------------------------------------------
; $00-$01 - tile numbers
; $02 - relative Y position
; $03 - horizontal flip flag (not used here)
; $04 - attributes
; $05 - relative X position

DefaultBlockObjTiles:
    .byte $85, $85, $86, $86  ; brick w/ line (these are sprite tiles, not BG!)

DrawBlock:
    LDA Block_Rel_YPos  ; get relative vertical coordinate of block object
    STA $02  ; store here
    LDA Block_Rel_XPos  ; get relative horizontal coordinate of block object
    STA $05  ; store here
    LDA #$03
    STA $04  ; set attribute byte here
    LSR
    STA $03  ; set horizontal flip bit here (will not be used)
    LDY Block_SprDataOffset,x  ; get sprite data offset
    LDX #$00  ; reset X for use as offset to tile data
DBlkLoop:
    LDA DefaultBlockObjTiles,x  ; get left tile number
    STA $00  ; set here
    LDA DefaultBlockObjTiles+1,x  ; get right tile number
    JSR DrawOneSpriteRow  ; do sub to write tile numbers to first row of sprites
    CPX #$04  ; check incremented offset
    BNE DBlkLoop  ; and loop back until all four sprites are done
    LDX ObjectOffset  ; get block object offset
    LDY Block_SprDataOffset,x  ; get sprite data offset
    LDA AreaType
    CMP #$01  ; check for ground level type area
    BEQ ChkRep  ; if found, branch to next part
    LDA #$86
    STA Sprite_Tilenumber,y  ; otherwise remove brick tiles with lines
    STA Sprite_Tilenumber+4,y  ; and replace then with lineless brick tiles
ChkRep:
    LDA Block_Metatile,x  ; check replacement metatile
    CMP #$c4  ; if not used block metatile, then
    BNE BlkOffscr  ; branch ahead to use current graphics
    LDA #$87  ; set A for used block tile
    INY  ; increment Y to write to tile bytes
    JSR DumpFourSpr  ; do sub to dump into all four sprites
    DEY  ; return Y to original offset
    LDA #$03  ; set palette bits
    LDX AreaType
    DEX  ; check for ground level type area again
    BEQ SetBFlip  ; if found, use current palette bits
    LSR  ; otherwise set to $01
SetBFlip:
    LDX ObjectOffset  ; put block object offset back in X
    STA Sprite_Attributes,y  ; store attribute byte as-is in first sprite
    ORA #%01000000
    STA Sprite_Attributes+4,y  ; set horizontal flip bit for second sprite
    ORA #%10000000
    STA Sprite_Attributes+12,y  ; set both flip bits for fourth sprite
    AND #%10000011
    STA Sprite_Attributes+8,y  ; set vertical flip bit for third sprite
BlkOffscr:
    LDA Block_OffscreenBits  ; get offscreen bits for block object
    PHA  ; save to stack
    AND #%00000100  ; check to see if d2 in offscreen bits are set
    BEQ PullOfsB  ; if not set, branch, otherwise move sprites offscreen
    LDA #$f8  ; move offscreen two OAMs
    STA Sprite_Y_Position+4,y  ; on the right side
    STA Sprite_Y_Position+12,y
PullOfsB:
    PLA  ; pull offscreen bits from stack
ChkLeftCo:
    AND #%00001000  ; check to see if d3 in offscreen bits are set
    BEQ ExDBlk  ; if not set, branch, otherwise move sprites offscreen

MoveColOffscreen:
    LDA #$f8  ; move offscreen two OAMs
    STA Sprite_Y_Position,y  ; on the left side (or two rows of enemy on either side
    STA Sprite_Y_Position+8,y  ; if branched here from enemy graphics handler)
ExDBlk:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used to hold palette bits for attribute byte or relative X position

DrawBrickChunks:
    LDA #$02  ; set palette bits here
    STA $00
    LDA #$75  ; set tile number for ball (something residual, likely)
    LDY GameEngineSubroutine
    CPY #$05  ; if end-of-level routine running,
    BEQ DChunks  ; use palette and tile number assigned
    LDA #$03  ; otherwise set different palette bits
    STA $00
    LDA #$84  ; and set tile number for brick chunks
DChunks:
    LDY Block_SprDataOffset,x  ; get OAM data offset
    INY  ; increment to start with tile bytes in OAM
    JSR DumpFourSpr  ; do sub to dump tile number into all four sprites
    LDA FrameCounter  ; get frame counter
    ASL
    ASL
    ASL  ; move low nybble to high
    ASL
    AND #$c0  ; get what was originally d3-d2 of low nybble
    ORA $00  ; add palette bits
    INY  ; increment offset for attribute bytes
    JSR DumpFourSpr  ; do sub to dump attribute data into all four sprites
    DEY
    DEY  ; decrement offset to Y coordinate
    LDA Block_Rel_YPos  ; get first block object's relative vertical coordinate
    JSR DumpTwoSpr  ; do sub to dump current Y coordinate into two sprites
    LDA Block_Rel_XPos  ; get first block object's relative horizontal coordinate
    STA Sprite_X_Position,y  ; save into X coordinate of first sprite
    LDA Block_Orig_XPos,x  ; get original horizontal coordinate
    SEC
    SBC ScreenLeft_X_Pos  ; subtract coordinate of left side from original coordinate
    STA $00  ; store result as relative horizontal coordinate of original
    SEC
    SBC Block_Rel_XPos  ; get difference of relative positions of original - current
    ADC $00  ; add original relative position to result
    ADC #$06  ; plus 6 pixels to position second brick chunk correctly
    STA Sprite_X_Position+4,y  ; save into X coordinate of second sprite
    LDA Block_Rel_YPos+1  ; get second block object's relative vertical coordinate
    STA Sprite_Y_Position+8,y
    STA Sprite_Y_Position+12,y  ; dump into Y coordinates of third and fourth sprites
    LDA Block_Rel_XPos+1  ; get second block object's relative horizontal coordinate
    STA Sprite_X_Position+8,y  ; save into X coordinate of third sprite
    LDA $00  ; use original relative horizontal position
    SEC
    SBC Block_Rel_XPos+1  ; get difference of relative positions of original - current
    ADC $00  ; add original relative position to result
    ADC #$06  ; plus 6 pixels to position fourth brick chunk correctly
    STA Sprite_X_Position+12,y  ; save into X coordinate of fourth sprite
    LDA Block_OffscreenBits  ; get offscreen bits for block object
    JSR ChkLeftCo  ; do sub to move left half of sprites offscreen if necessary
    LDA Block_OffscreenBits  ; get offscreen bits again
    ASL  ; shift d7 into carry
    BCC ChnkOfs  ; if d7 not set, branch to last part
    LDA #$f8
    JSR DumpTwoSpr  ; otherwise move top sprites offscreen
ChnkOfs:
    LDA $00  ; if relative position on left side of screen,
    BPL ExBCDr  ; go ahead and leave
    LDA Sprite_X_Position,y  ; otherwise compare left-side X coordinate
    CMP Sprite_X_Position+4,y  ; to right-side X coordinate
    BCC ExBCDr  ; branch to leave if less
    LDA #$f8  ; otherwise move right half of sprites offscreen
    STA Sprite_Y_Position+4,y
    STA Sprite_Y_Position+12,y
ExBCDr:
    RTS  ; leave

; -------------------------------------------------------------------------------------

DrawFireball:
    LDY FBall_SprDataOffset,x  ; get fireball's sprite data offset
    LDA Fireball_Rel_YPos  ; get relative vertical coordinate
    STA Sprite_Y_Position,y  ; store as sprite Y coordinate
    LDA Fireball_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as sprite X coordinate, then do shared code

DrawFirebar:
    LDA FrameCounter  ; get frame counter
    LSR  ; divide by four
    LSR
    PHA  ; save result to stack
    AND #$01  ; mask out all but last bit
    EOR #$64  ; set either tile $64 or $65 as fireball tile
    STA Sprite_Tilenumber,y  ; thus tile changes every four frames
    PLA  ; get from stack
    LSR  ; divide by four again
    LSR
    LDA #$02  ; load value $02 to set palette in attrib byte
    BCC FireA  ; if last bit shifted out was not set, skip this
    ORA #%11000000  ; otherwise flip both ways every eight frames
FireA:
    STA Sprite_Attributes,y  ; store attribute byte and leave
    RTS

; -------------------------------------------------------------------------------------

ExplosionTiles:
    .byte $68, $67, $66

DrawExplosion_Fireball:
    LDY Alt_SprDataOffset,x  ; get OAM data offset of alternate sort for fireball's explosion
    LDA Fireball_State,x  ; load fireball state
    INC Fireball_State,x  ; increment state for next frame
    LSR  ; divide by 2
    AND #%00000111  ; mask out all but d3-d1
    CMP #$03  ; check to see if time to kill fireball
    BCS KillFireBall  ; branch if so, otherwise continue to draw explosion

DrawExplosion_Fireworks:
    TAX  ; use whatever's in A for offset
    LDA ExplosionTiles,x  ; get tile number using offset
    INY  ; increment Y (contains sprite data offset)
    JSR DumpFourSpr  ; and dump into tile number part of sprite data
    DEY  ; decrement Y so we have the proper offset again
    LDX ObjectOffset  ; return enemy object buffer offset to X
    LDA Fireball_Rel_YPos  ; get relative vertical coordinate
    SEC  ; subtract four pixels vertically
    SBC #$04  ; for first and third sprites
    STA Sprite_Y_Position,y
    STA Sprite_Y_Position+8,y
    CLC  ; add eight pixels vertically
    ADC #$08  ; for second and fourth sprites
    STA Sprite_Y_Position+4,y
    STA Sprite_Y_Position+12,y
    LDA Fireball_Rel_XPos  ; get relative horizontal coordinate
    SEC  ; subtract four pixels horizontally
    SBC #$04  ; for first and second sprites
    STA Sprite_X_Position,y
    STA Sprite_X_Position+4,y
    CLC  ; add eight pixels horizontally
    ADC #$08  ; for third and fourth sprites
    STA Sprite_X_Position+8,y
    STA Sprite_X_Position+12,y
    LDA #$02  ; set palette attributes for all sprites, but
    STA Sprite_Attributes,y  ; set no flip at all for first sprite
    LDA #$82
    STA Sprite_Attributes+4,y  ; set vertical flip for second sprite
    LDA #$42
    STA Sprite_Attributes+8,y  ; set horizontal flip for third sprite
    LDA #$c2
    STA Sprite_Attributes+12,y  ; set both flips for fourth sprite
    RTS  ; we are done

KillFireBall:
    LDA #$00  ; clear fireball state to kill it
    STA Fireball_State,x
    RTS

; -------------------------------------------------------------------------------------

DrawSmallPlatform:
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA #$5b  ; load tile number for small platforms
    INY  ; increment offset for tile numbers
    JSR DumpSixSpr  ; dump tile number into all six sprites
    INY  ; increment offset for attributes
    LDA #$02  ; load palette controls
    JSR DumpSixSpr  ; dump attributes into all six sprites
    DEY  ; decrement for original offset
    DEY
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y
    STA Sprite_X_Position+12,y  ; dump as X coordinate into first and fourth sprites
    CLC
    ADC #$08  ; add eight pixels
    STA Sprite_X_Position+4,y  ; dump into second and fifth sprites
    STA Sprite_X_Position+16,y
    CLC
    ADC #$08  ; add eight more pixels
    STA Sprite_X_Position+8,y  ; dump into third and sixth sprites
    STA Sprite_X_Position+20,y
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    TAX
    PHA  ; save to stack
    CPX #$20  ; if vertical coordinate below status bar,
    BCS TopSP  ; do not mess with it
    LDA #$f8  ; otherwise move first three sprites offscreen
TopSP:
    JSR DumpThreeSpr  ; dump vertical coordinate into Y coordinates
    PLA  ; pull from stack
    CLC
    ADC #$80  ; add 128 pixels
    TAX
    CPX #$20  ; if below status bar (taking wrap into account)
    BCS BotSP  ; then do not change altered coordinate
    LDA #$f8  ; otherwise move last three sprites offscreen
BotSP:
    STA Sprite_Y_Position+12,y  ; dump vertical coordinate + 128 pixels
    STA Sprite_Y_Position+16,y  ; into Y coordinates
    STA Sprite_Y_Position+20,y
    LDA Enemy_OffscreenBits  ; get offscreen bits
    PHA  ; save to stack
    AND #%00001000  ; check d3
    BEQ SOfs
    LDA #$f8  ; if d3 was set, move first and
    STA Sprite_Y_Position,y  ; fourth sprites offscreen
    STA Sprite_Y_Position+12,y
SOfs:
    PLA  ; move out and back into stack
    PHA
    AND #%00000100  ; check d2
    BEQ SOfs2
    LDA #$f8  ; if d2 was set, move second and
    STA Sprite_Y_Position+4,y  ; fifth sprites offscreen
    STA Sprite_Y_Position+16,y
SOfs2:
    PLA  ; get from stack
    AND #%00000010  ; check d1
    BEQ ExSPl
    LDA #$f8  ; if d1 was set, move third and
    STA Sprite_Y_Position+8,y  ; sixth sprites offscreen
    STA Sprite_Y_Position+20,y
ExSPl:
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

; -------------------------------------------------------------------------------------

DrawBubble:
    LDY Player_Y_HighPos  ; if player's vertical high position
    DEY  ; not within screen, skip all of this
    BNE ExDBub
    LDA Bubble_OffscreenBits  ; check air bubble's offscreen bits
    AND #%00001000
    BNE ExDBub  ; if bit set, branch to leave
    LDY Bubble_SprDataOffset,x  ; get air bubble's OAM data offset
    LDA Bubble_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as X coordinate here
    LDA Bubble_Rel_YPos  ; get relative vertical coordinate
    STA Sprite_Y_Position,y  ; store as Y coordinate here
    LDA #$74
    STA Sprite_Tilenumber,y  ; put air bubble tile into OAM data
    LDA #$02
    STA Sprite_Attributes,y  ; set attribute byte
ExDBub:
    RTS  ; leave
