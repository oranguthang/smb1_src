; -------------------------------------------------------------------------------------
; $00 - offset to vine Y coordinate adder
; $02 - offset to sprite data

VineYPosAdder:
    .byte $00, $30

DrawVine:
    STY $00  ; save offset here
    LDA Enemy_Rel_YPos  ; get relative vertical coordinate
    CLC
    ADC VineYPosAdder,y  ; add value using offset in Y to get value
    LDX VineObjOffset,y  ; get offset to vine
    LDY Enemy_SprDataOffset,x  ; get sprite data offset
    STY $02  ; store sprite data offset here
    JSR SixSpriteStacker  ; stack six sprites on top of each other vertically
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store in first, third and fifth sprites
    STA Sprite_X_Position+8,y
    STA Sprite_X_Position+16,y
    CLC
    ADC #$06  ; add six pixels to second, fourth and sixth sprites
    STA Sprite_X_Position+4,y  ; to give characteristic staggered vine shape to
    STA Sprite_X_Position+12,y  ; our vertical stack of sprites
    STA Sprite_X_Position+20,y
    LDA #%00100001  ; set bg priority and palette attribute bits
    STA Sprite_Attributes,y  ; set in first, third and fifth sprites
    STA Sprite_Attributes+8,y
    STA Sprite_Attributes+16,y
    ORA #%01000000  ; additionally, set horizontal flip bit
    STA Sprite_Attributes+4,y  ; for second, fourth and sixth sprites
    STA Sprite_Attributes+12,y
    STA Sprite_Attributes+20,y
    LDX #$05  ; set tiles for six sprites
VineTL:
    LDA #$e1  ; set tile number for sprite
    STA Sprite_Tilenumber,y
    INY  ; move offset to next sprite data
    INY
    INY
    INY
    DEX  ; move onto next sprite
    BPL VineTL  ; loop until all sprites are done
    LDY $02  ; get original offset
    LDA $00  ; get offset to vine adding data
    BNE SkpVTop  ; if offset not zero, skip this part
    LDA #$e0
    STA Sprite_Tilenumber,y  ; set other tile number for top of vine
SkpVTop:
    LDX #$00  ; start with the first sprite again
ChkFTop:
    LDA VineStart_Y_Position  ; get original starting vertical coordinate
    SEC
    SBC Sprite_Y_Position,y  ; subtract top-most sprite's Y coordinate
    CMP #$64  ; if two coordinates are less than 100/$64 pixels
    BCC NextVSp  ; apart, skip this to leave sprite alone
    LDA #$f8
    STA Sprite_Y_Position,y  ; otherwise move sprite offscreen
NextVSp:
    INY  ; move offset to next OAM data
    INY
    INY
    INY
    INX  ; move onto next sprite
    CPX #$06  ; do this until all sprites are checked
    BNE ChkFTop
    LDY $00  ; return offset set earlier
    RTS

SixSpriteStacker:
    LDX #$06  ; do six sprites
StkLp:
    STA Sprite_Data,y  ; store X or Y coordinate into OAM data
    CLC
    ADC #$08  ; add eight pixels
    INY
    INY  ; move offset four bytes forward
    INY
    INY
    DEX  ; do another sprite
    BNE StkLp  ; do this until all sprites are done
    LDY $02  ; get saved OAM data offset and leave
    RTS

; -------------------------------------------------------------------------------------

FirstSprXPos:
    .byte $04, $00, $04, $00

FirstSprYPos:
    .byte $00, $04, $00, $04

SecondSprXPos:
    .byte $00, $08, $00, $08

SecondSprYPos:
    .byte $08, $00, $08, $00

FirstSprTilenum:
    .byte $80, $82, $81, $83

SecondSprTilenum:
    .byte $81, $83, $80, $82

HammerSprAttrib:
    .byte $03, $03, $c3, $c3

DrawHammer:
    LDY Misc_SprDataOffset,x  ; get misc object OAM data offset
    LDA TimerControl
    BNE ForceHPose  ; if master timer control set, skip this part
    LDA Misc_State,x  ; otherwise get hammer's state
    AND #%01111111  ; mask out d7
    CMP #$01  ; check to see if set to 1 yet
    BEQ GetHPose  ; if so, branch
ForceHPose:
    LDX #$00  ; reset offset here
    BEQ RenderH  ; do unconditional branch to rendering part
GetHPose:
    LDA FrameCounter  ; get frame counter
    LSR  ; move d3-d2 to d1-d0
    LSR
    AND #%00000011  ; mask out all but d1-d0 (changes every four frames)
    TAX  ; use as timing offset
RenderH:
    LDA Misc_Rel_YPos  ; get relative vertical coordinate
    CLC
    ADC FirstSprYPos,x  ; add first sprite vertical adder based on offset
    STA Sprite_Y_Position,y  ; store as sprite Y coordinate for first sprite
    CLC
    ADC SecondSprYPos,x  ; add second sprite vertical adder based on offset
    STA Sprite_Y_Position+4,y  ; store as sprite Y coordinate for second sprite
    LDA Misc_Rel_XPos  ; get relative horizontal coordinate
    CLC
    ADC FirstSprXPos,x  ; add first sprite horizontal adder based on offset
    STA Sprite_X_Position,y  ; store as sprite X coordinate for first sprite
    CLC
    ADC SecondSprXPos,x  ; add second sprite horizontal adder based on offset
    STA Sprite_X_Position+4,y  ; store as sprite X coordinate for second sprite
    LDA FirstSprTilenum,x
    STA Sprite_Tilenumber,y  ; get and store tile number of first sprite
    LDA SecondSprTilenum,x
    STA Sprite_Tilenumber+4,y  ; get and store tile number of second sprite
    LDA HammerSprAttrib,x
    STA Sprite_Attributes,y  ; get and store attribute bytes for both
    STA Sprite_Attributes+4,y  ; note in this case they use the same data
    LDX ObjectOffset  ; get misc object offset
    LDA Misc_OffscreenBits
    AND #%11111100  ; check offscreen bits
    BEQ NoHOffscr  ; if all bits clear, leave object alone
    LDA #$00
    STA Misc_State,x  ; otherwise nullify misc object state
    LDA #$f8
    JSR DumpTwoSpr  ; do sub to move hammer sprites offscreen
NoHOffscr:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold tile numbers ($01 addressed in draw floatey number part)
; $02 - used to hold Y coordinate for floatey number
; $03 - residual byte used for flip (but value set here affects nothing)
; $04 - attribute byte for floatey number
; $05 - used as X coordinate for floatey number

FlagpoleScoreNumTiles:
    .byte $f9, $50
    .byte $f7, $50
    .byte $fa, $fb
    .byte $f8, $fb
    .byte $f6, $fb

FlagpoleGfxHandler:
    LDY Enemy_SprDataOffset,x  ; get sprite data offset for flagpole flag
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as X coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels and store
    STA Sprite_X_Position+4,y  ; as X coordinate for second and third sprites
    STA Sprite_X_Position+8,y
    CLC
    ADC #$0c  ; add twelve more pixels and
    STA $05  ; store here to be used later by floatey number
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    JSR DumpTwoSpr  ; and do sub to dump into first and second sprites
    ADC #$08  ; add eight pixels
    STA Sprite_Y_Position+8,y  ; and store into third sprite
    LDA FlagpoleFNum_Y_Pos  ; get vertical coordinate for floatey number
    STA $02  ; store it here
    LDA #$01
    STA $03  ; set value for flip which will not be used, and
    STA $04  ; attribute byte for floatey number
    STA Sprite_Attributes,y  ; set attribute bytes for all three sprites
    STA Sprite_Attributes+4,y
    STA Sprite_Attributes+8,y
    LDA #$7e
    STA Sprite_Tilenumber,y  ; put triangle shaped tile
    STA Sprite_Tilenumber+8,y  ; into first and third sprites
    LDA #$7f
    STA Sprite_Tilenumber+4,y  ; put skull tile into second sprite
    LDA FlagpoleCollisionYPos  ; get vertical coordinate at time of collision
    BEQ ChkFlagOffscreen  ; if zero, branch ahead
    TYA
    CLC  ; add 12 bytes to sprite data offset
    ADC #$0c
    TAY  ; put back in Y
    LDA FlagpoleScore  ; get offset used to award points for touching flagpole
    ASL  ; multiply by 2 to get proper offset here
    TAX
    LDA FlagpoleScoreNumTiles,x  ; get appropriate tile data
    STA $00
    LDA FlagpoleScoreNumTiles+1,x
    JSR DrawOneSpriteRow  ; use it to render floatey number

ChkFlagOffscreen:
    LDX ObjectOffset  ; get object offset for flag
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA Enemy_OffscreenBits  ; get offscreen bits
    AND #%00001110  ; mask out all but d3-d1
    BEQ ExitDumpSpr  ; if none of these bits set, branch to leave

; -------------------------------------------------------------------------------------

MoveSixSpritesOffscreen:
    LDA #$f8  ; set offscreen coordinate if jumping here

DumpSixSpr:
    STA Sprite_Data+20,y  ; dump A contents
    STA Sprite_Data+16,y  ; into third row sprites

DumpFourSpr:
    STA Sprite_Data+12,y  ; into second row sprites

DumpThreeSpr:
    STA Sprite_Data+8,y

DumpTwoSpr:
    STA Sprite_Data+4,y  ; and into first row sprites
    STA Sprite_Data,y

ExitDumpSpr:
    RTS

; -------------------------------------------------------------------------------------

DrawLargePlatform:
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    STY $02  ; store here
    INY  ; add 3 to it for offset
    INY  ; to X coordinate
    INY
    LDA Enemy_Rel_XPos  ; get horizontal relative coordinate
    JSR SixSpriteStacker  ; store X coordinates using A as base, stack horizontally
    LDX ObjectOffset
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    JSR DumpFourSpr  ; dump into first four sprites as Y coordinate
    LDY AreaType
    CPY #$03  ; check for castle-type level
    BEQ ShrinkPlatform
    LDY SecondaryHardMode  ; check for secondary hard mode flag set
    BEQ SetLast2Platform  ; branch if not set elsewhere

ShrinkPlatform:
    LDA #$f8  ; load offscreen coordinate if flag set or castle-type level

SetLast2Platform:
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    STA Sprite_Y_Position+16,y  ; store vertical coordinate or offscreen
    STA Sprite_Y_Position+20,y  ; coordinate into last two sprites as Y coordinate
    LDA #$5b  ; load default tile for platform (girder)
    LDX CloudTypeOverride
    BEQ SetPlatformTilenum  ; if cloud level override flag not set, use
    LDA #$75  ; otherwise load other tile for platform (puff)

SetPlatformTilenum:
    LDX ObjectOffset  ; get enemy object buffer offset
    INY  ; increment Y for tile offset
    JSR DumpSixSpr  ; dump tile number into all six sprites
    LDA #$02  ; set palette controls
    INY  ; increment Y for sprite attributes
    JSR DumpSixSpr  ; dump attributes into all six sprites
    INX  ; increment X for enemy objects
    JSR GetXOffscreenBits  ; get offscreen bits again
    DEX
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    ASL  ; rotate d7 into carry, save remaining
    PHA  ; bits to the stack
    BCC SChk2
    LDA #$f8  ; if d7 was set, move first sprite offscreen
    STA Sprite_Y_Position,y
SChk2:
    PLA  ; get bits from stack
    ASL  ; rotate d6 into carry
    PHA  ; save to stack
    BCC SChk3
    LDA #$f8  ; if d6 was set, move second sprite offscreen
    STA Sprite_Y_Position+4,y
SChk3:
    PLA  ; get bits from stack
    ASL  ; rotate d5 into carry
    PHA  ; save to stack
    BCC SChk4
    LDA #$f8  ; if d5 was set, move third sprite offscreen
    STA Sprite_Y_Position+8,y
SChk4:
    PLA  ; get bits from stack
    ASL  ; rotate d4 into carry
    PHA  ; save to stack
    BCC SChk5
    LDA #$f8  ; if d4 was set, move fourth sprite offscreen
    STA Sprite_Y_Position+12,y
SChk5:
    PLA  ; get bits from stack
    ASL  ; rotate d3 into carry
    PHA  ; save to stack
    BCC SChk6
    LDA #$f8  ; if d3 was set, move fifth sprite offscreen
    STA Sprite_Y_Position+16,y
SChk6:
    PLA  ; get bits from stack
    ASL  ; rotate d2 into carry
    BCC SLChk  ; save to stack
    LDA #$f8
    STA Sprite_Y_Position+20,y  ; if d2 was set, move sixth sprite offscreen
SLChk:
    LDA Enemy_OffscreenBits  ; check d7 of offscreen bits
    ASL  ; and if d7 is not set, skip sub
    BCC ExDLPl
    JSR MoveSixSpritesOffscreen  ; otherwise branch to move all sprites offscreen
ExDLPl:
    RTS

; -------------------------------------------------------------------------------------

DrawFloateyNumber_Coin:
    LDA FrameCounter  ; get frame counter
    LSR  ; divide by 2
    BCS NotRsNum  ; branch if d0 not set to raise number every other frame
    DEC Misc_Y_Position,x  ; otherwise, decrement vertical coordinate
NotRsNum:
    LDA Misc_Y_Position,x  ; get vertical coordinate
    JSR DumpTwoSpr  ; dump into both sprites
    LDA Misc_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as X coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels
    STA Sprite_X_Position+4,y  ; store as X coordinate for second sprite
    LDA #$02
    STA Sprite_Attributes,y  ; store attribute byte in both sprites
    STA Sprite_Attributes+4,y
    LDA #$f7
    STA Sprite_Tilenumber,y  ; put tile numbers into both sprites
    LDA #$fb  ; that resemble "200"
    STA Sprite_Tilenumber+4,y
    JMP ExJCGfx  ; then jump to leave (why not an rts here instead?)

JumpingCoinTiles:
    .byte $60, $61, $62, $63

JCoinGfxHandler:
    LDY Misc_SprDataOffset,x  ; get coin/floatey number's OAM data offset
    LDA Misc_State,x  ; get state of misc object
    CMP #$02  ; if 2 or greater,
    BCS DrawFloateyNumber_Coin  ; branch to draw floatey number
    LDA Misc_Y_Position,x  ; store vertical coordinate as
    STA Sprite_Y_Position,y  ; Y coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels
    STA Sprite_Y_Position+4,y  ; store as Y coordinate for second sprite
    LDA Misc_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y
    STA Sprite_X_Position+4,y  ; store as X coordinate for first and second sprites
    LDA FrameCounter  ; get frame counter
    LSR  ; divide by 2 to alter every other frame
    AND #%00000011  ; mask out d2-d1
    TAX  ; use as graphical offset
    LDA JumpingCoinTiles,x  ; load tile number
    INY  ; increment OAM data offset to write tile numbers
    JSR DumpTwoSpr  ; do sub to dump tile number into both sprites
    DEY  ; decrement to get old offset
    LDA #$02
    STA Sprite_Attributes,y  ; set attribute byte in first sprite
    LDA #$82
    STA Sprite_Attributes+4,y  ; set attribute byte with vertical flip in second sprite
    LDX ObjectOffset  ; get misc object offset
ExJCGfx:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold tiles for drawing the power-up, $00 also used to hold power-up type
; $02 - used to hold bottom row Y position
; $03 - used to hold flip control (not used here)
; $04 - used to hold sprite attributes
; $05 - used to hold X position
; $07 - counter

; tiles arranged in top left, right, bottom left, right order
PowerUpGfxTable:
    .byte $76, $77, $78, $79  ; regular mushroom
    .byte $d6, $d6, $d9, $d9  ; fire flower
    .byte $8d, $8d, $e4, $e4  ; star
    .byte $76, $77, $78, $79  ; 1-up mushroom

PowerUpAttributes:
    .byte $02, $01, $02, $01

DrawPowerUp:
    LDY Enemy_SprDataOffset+5  ; get power-up's sprite data offset
    LDA Enemy_Rel_YPos  ; get relative vertical coordinate
    CLC
    ADC #$08  ; add eight pixels
    STA $02  ; store result here
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA $05  ; store here
    LDX PowerUpType  ; get power-up type
    LDA PowerUpAttributes,x  ; get attribute data for power-up type
    ORA Enemy_SprAttrib+5  ; add background priority bit if set
    STA $04  ; store attributes here
    TXA
    PHA  ; save power-up type to the stack
    ASL
    ASL  ; multiply by four to get proper offset
    TAX  ; use as X
    LDA #$01
    STA $07  ; set counter here to draw two rows of sprite object
    STA $03  ; init d1 of flip control

PUpDrawLoop:
    LDA PowerUpGfxTable,x  ; load left tile of power-up object
    STA $00
    LDA PowerUpGfxTable+1,x  ; load right tile
    JSR DrawOneSpriteRow  ; branch to draw one row of our power-up object
    DEC $07  ; decrement counter
    BPL PUpDrawLoop  ; branch until two rows are drawn
    LDY Enemy_SprDataOffset+5  ; get sprite data offset again
    PLA  ; pull saved power-up type from the stack
    BEQ PUpOfs  ; if regular mushroom, branch, do not change colors or flip
    CMP #$03
    BEQ PUpOfs  ; if 1-up mushroom, branch, do not change colors or flip
    STA $00  ; store power-up type here now
    LDA FrameCounter  ; get frame counter
    LSR  ; divide by 2 to change colors every two frames
    AND #%00000011  ; mask out all but d1 and d0 (previously d2 and d1)
    ORA Enemy_SprAttrib+5  ; add background priority bit if any set
    STA Sprite_Attributes,y  ; set as new palette bits for top left and
    STA Sprite_Attributes+4,y  ; top right sprites for fire flower and star
    LDX $00
    DEX  ; check power-up type for fire flower
    BEQ FlipPUpRightSide  ; if found, skip this part
    STA Sprite_Attributes+8,y  ; otherwise set new palette bits  for bottom left
    STA Sprite_Attributes+12,y  ; and bottom right sprites as well for star only

FlipPUpRightSide:
    LDA Sprite_Attributes+4,y
    ORA #%01000000  ; set horizontal flip bit for top right sprite
    STA Sprite_Attributes+4,y
    LDA Sprite_Attributes+12,y
    ORA #%01000000  ; set horizontal flip bit for bottom right sprite
    STA Sprite_Attributes+12,y  ; note these are only done for fire flower and star power-ups
PUpOfs:
    JMP SprObjectOffscrChk  ; jump to check to see if power-up is offscreen at all, then leave
