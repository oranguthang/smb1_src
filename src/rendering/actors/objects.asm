;-------------------------------------------------------------------------------------
;$00-$01 - tile numbers
;$02 - relative Y position
;$03 - horizontal flip flag (not used here)
;$04 - attributes
;$05 - relative X position

DefaultBlockObjTiles:
      .byte $85, $85, $86, $86             ;brick w/ line (these are sprite tiles, not BG!)

DrawBlock:
           lda Block_Rel_YPos            ;get relative vertical coordinate of block object
           sta $02                       ;store here
           lda Block_Rel_XPos            ;get relative horizontal coordinate of block object
           sta $05                       ;store here
           lda #$03
           sta $04                       ;set attribute byte here
           lsr
           sta $03                       ;set horizontal flip bit here (will not be used)
           ldy Block_SprDataOffset,x     ;get sprite data offset
           ldx #$00                      ;reset X for use as offset to tile data
DBlkLoop:  lda DefaultBlockObjTiles,x    ;get left tile number
           sta $00                       ;set here
           lda DefaultBlockObjTiles+1,x  ;get right tile number
           jsr DrawOneSpriteRow          ;do sub to write tile numbers to first row of sprites
           cpx #$04                      ;check incremented offset
           bne DBlkLoop                  ;and loop back until all four sprites are done
           ldx ObjectOffset              ;get block object offset
           ldy Block_SprDataOffset,x     ;get sprite data offset
           lda AreaType
           cmp #$01                      ;check for ground level type area
           beq ChkRep                    ;if found, branch to next part
           lda #$86
           sta Sprite_Tilenumber,y       ;otherwise remove brick tiles with lines
           sta Sprite_Tilenumber+4,y     ;and replace then with lineless brick tiles
ChkRep:    lda Block_Metatile,x          ;check replacement metatile
           cmp #$c4                      ;if not used block metatile, then
           bne BlkOffscr                 ;branch ahead to use current graphics
           lda #$87                      ;set A for used block tile
           iny                           ;increment Y to write to tile bytes
           jsr DumpFourSpr               ;do sub to dump into all four sprites
           dey                           ;return Y to original offset
           lda #$03                      ;set palette bits
           ldx AreaType
           dex                           ;check for ground level type area again
           beq SetBFlip                  ;if found, use current palette bits
           lsr                           ;otherwise set to $01
SetBFlip:  ldx ObjectOffset              ;put block object offset back in X
           sta Sprite_Attributes,y       ;store attribute byte as-is in first sprite
           ora #%01000000
           sta Sprite_Attributes+4,y     ;set horizontal flip bit for second sprite
           ora #%10000000
           sta Sprite_Attributes+12,y    ;set both flip bits for fourth sprite
           and #%10000011
           sta Sprite_Attributes+8,y     ;set vertical flip bit for third sprite
BlkOffscr: lda Block_OffscreenBits       ;get offscreen bits for block object
           pha                           ;save to stack
           and #%00000100                ;check to see if d2 in offscreen bits are set
           beq PullOfsB                  ;if not set, branch, otherwise move sprites offscreen
           lda #$f8                      ;move offscreen two OAMs
           sta Sprite_Y_Position+4,y     ;on the right side
           sta Sprite_Y_Position+12,y
PullOfsB:  pla                           ;pull offscreen bits from stack
ChkLeftCo: and #%00001000                ;check to see if d3 in offscreen bits are set
           beq ExDBlk                    ;if not set, branch, otherwise move sprites offscreen

MoveColOffscreen:
        lda #$f8                   ;move offscreen two OAMs
        sta Sprite_Y_Position,y    ;on the left side (or two rows of enemy on either side
        sta Sprite_Y_Position+8,y  ;if branched here from enemy graphics handler)
ExDBlk: rts

;-------------------------------------------------------------------------------------
;$00 - used to hold palette bits for attribute byte or relative X position

DrawBrickChunks:
         lda #$02                   ;set palette bits here
         sta $00
         lda #$75                   ;set tile number for ball (something residual, likely)
         ldy GameEngineSubroutine
         cpy #$05                   ;if end-of-level routine running,
         beq DChunks                ;use palette and tile number assigned
         lda #$03                   ;otherwise set different palette bits
         sta $00
         lda #$84                   ;and set tile number for brick chunks
DChunks: ldy Block_SprDataOffset,x  ;get OAM data offset
         iny                        ;increment to start with tile bytes in OAM
         jsr DumpFourSpr            ;do sub to dump tile number into all four sprites
         lda FrameCounter           ;get frame counter
         asl
         asl
         asl                        ;move low nybble to high
         asl
         and #$c0                   ;get what was originally d3-d2 of low nybble
         ora $00                    ;add palette bits
         iny                        ;increment offset for attribute bytes
         jsr DumpFourSpr            ;do sub to dump attribute data into all four sprites
         dey
         dey                        ;decrement offset to Y coordinate
         lda Block_Rel_YPos         ;get first block object's relative vertical coordinate
         jsr DumpTwoSpr             ;do sub to dump current Y coordinate into two sprites
         lda Block_Rel_XPos         ;get first block object's relative horizontal coordinate
         sta Sprite_X_Position,y    ;save into X coordinate of first sprite
         lda Block_Orig_XPos,x      ;get original horizontal coordinate
         sec
         sbc ScreenLeft_X_Pos       ;subtract coordinate of left side from original coordinate
         sta $00                    ;store result as relative horizontal coordinate of original
         sec
         sbc Block_Rel_XPos         ;get difference of relative positions of original - current
         adc $00                    ;add original relative position to result
         adc #$06                   ;plus 6 pixels to position second brick chunk correctly
         sta Sprite_X_Position+4,y  ;save into X coordinate of second sprite
         lda Block_Rel_YPos+1       ;get second block object's relative vertical coordinate
         sta Sprite_Y_Position+8,y
         sta Sprite_Y_Position+12,y ;dump into Y coordinates of third and fourth sprites
         lda Block_Rel_XPos+1       ;get second block object's relative horizontal coordinate
         sta Sprite_X_Position+8,y  ;save into X coordinate of third sprite
         lda $00                    ;use original relative horizontal position
         sec
         sbc Block_Rel_XPos+1       ;get difference of relative positions of original - current
         adc $00                    ;add original relative position to result
         adc #$06                   ;plus 6 pixels to position fourth brick chunk correctly
         sta Sprite_X_Position+12,y ;save into X coordinate of fourth sprite
         lda Block_OffscreenBits    ;get offscreen bits for block object
         jsr ChkLeftCo              ;do sub to move left half of sprites offscreen if necessary
         lda Block_OffscreenBits    ;get offscreen bits again
         asl                        ;shift d7 into carry
         bcc ChnkOfs                ;if d7 not set, branch to last part
         lda #$f8
         jsr DumpTwoSpr             ;otherwise move top sprites offscreen
ChnkOfs: lda $00                    ;if relative position on left side of screen,
         bpl ExBCDr                 ;go ahead and leave
         lda Sprite_X_Position,y    ;otherwise compare left-side X coordinate
         cmp Sprite_X_Position+4,y  ;to right-side X coordinate
         bcc ExBCDr                 ;branch to leave if less
         lda #$f8                   ;otherwise move right half of sprites offscreen
         sta Sprite_Y_Position+4,y
         sta Sprite_Y_Position+12,y
ExBCDr:  rts                        ;leave

;-------------------------------------------------------------------------------------

DrawFireball:
      ldy FBall_SprDataOffset,x  ;get fireball's sprite data offset
      lda Fireball_Rel_YPos      ;get relative vertical coordinate
      sta Sprite_Y_Position,y    ;store as sprite Y coordinate
      lda Fireball_Rel_XPos      ;get relative horizontal coordinate
      sta Sprite_X_Position,y    ;store as sprite X coordinate, then do shared code

DrawFirebar:
       lda FrameCounter         ;get frame counter
       lsr                      ;divide by four
       lsr
       pha                      ;save result to stack
       and #$01                 ;mask out all but last bit
       eor #$64                 ;set either tile $64 or $65 as fireball tile
       sta Sprite_Tilenumber,y  ;thus tile changes every four frames
       pla                      ;get from stack
       lsr                      ;divide by four again
       lsr
       lda #$02                 ;load value $02 to set palette in attrib byte
       bcc FireA                ;if last bit shifted out was not set, skip this
       ora #%11000000           ;otherwise flip both ways every eight frames
FireA: sta Sprite_Attributes,y  ;store attribute byte and leave
       rts

;-------------------------------------------------------------------------------------

ExplosionTiles:
      .byte $68, $67, $66

DrawExplosion_Fireball:
      ldy Alt_SprDataOffset,x  ;get OAM data offset of alternate sort for fireball's explosion
      lda Fireball_State,x     ;load fireball state
      inc Fireball_State,x     ;increment state for next frame
      lsr                      ;divide by 2
      and #%00000111           ;mask out all but d3-d1
      cmp #$03                 ;check to see if time to kill fireball
      bcs KillFireBall         ;branch if so, otherwise continue to draw explosion

DrawExplosion_Fireworks:
      tax                         ;use whatever's in A for offset
      lda ExplosionTiles,x        ;get tile number using offset
      iny                         ;increment Y (contains sprite data offset)
      jsr DumpFourSpr             ;and dump into tile number part of sprite data
      dey                         ;decrement Y so we have the proper offset again
      ldx ObjectOffset            ;return enemy object buffer offset to X
      lda Fireball_Rel_YPos       ;get relative vertical coordinate
      sec                         ;subtract four pixels vertically
      sbc #$04                    ;for first and third sprites
      sta Sprite_Y_Position,y
      sta Sprite_Y_Position+8,y
      clc                         ;add eight pixels vertically
      adc #$08                    ;for second and fourth sprites
      sta Sprite_Y_Position+4,y
      sta Sprite_Y_Position+12,y
      lda Fireball_Rel_XPos       ;get relative horizontal coordinate
      sec                         ;subtract four pixels horizontally
      sbc #$04                    ;for first and second sprites
      sta Sprite_X_Position,y
      sta Sprite_X_Position+4,y
      clc                         ;add eight pixels horizontally
      adc #$08                    ;for third and fourth sprites
      sta Sprite_X_Position+8,y
      sta Sprite_X_Position+12,y
      lda #$02                    ;set palette attributes for all sprites, but
      sta Sprite_Attributes,y     ;set no flip at all for first sprite
      lda #$82
      sta Sprite_Attributes+4,y   ;set vertical flip for second sprite
      lda #$42
      sta Sprite_Attributes+8,y   ;set horizontal flip for third sprite
      lda #$c2
      sta Sprite_Attributes+12,y  ;set both flips for fourth sprite
      rts                         ;we are done

KillFireBall:
      lda #$00                    ;clear fireball state to kill it
      sta Fireball_State,x
      rts

;-------------------------------------------------------------------------------------

DrawSmallPlatform:
       ldy Enemy_SprDataOffset,x   ;get OAM data offset
       lda #$5b                    ;load tile number for small platforms
       iny                         ;increment offset for tile numbers
       jsr DumpSixSpr              ;dump tile number into all six sprites
       iny                         ;increment offset for attributes
       lda #$02                    ;load palette controls
       jsr DumpSixSpr              ;dump attributes into all six sprites
       dey                         ;decrement for original offset
       dey
       lda Enemy_Rel_XPos          ;get relative horizontal coordinate
       sta Sprite_X_Position,y
       sta Sprite_X_Position+12,y  ;dump as X coordinate into first and fourth sprites
       clc
       adc #$08                    ;add eight pixels
       sta Sprite_X_Position+4,y   ;dump into second and fifth sprites
       sta Sprite_X_Position+16,y
       clc
       adc #$08                    ;add eight more pixels
       sta Sprite_X_Position+8,y   ;dump into third and sixth sprites
       sta Sprite_X_Position+20,y
       lda Enemy_Y_Position,x      ;get vertical coordinate
       tax
       pha                         ;save to stack
       cpx #$20                    ;if vertical coordinate below status bar,
       bcs TopSP                   ;do not mess with it
       lda #$f8                    ;otherwise move first three sprites offscreen
TopSP: jsr DumpThreeSpr            ;dump vertical coordinate into Y coordinates
       pla                         ;pull from stack
       clc
       adc #$80                    ;add 128 pixels
       tax
       cpx #$20                    ;if below status bar (taking wrap into account)
       bcs BotSP                   ;then do not change altered coordinate
       lda #$f8                    ;otherwise move last three sprites offscreen
BotSP: sta Sprite_Y_Position+12,y  ;dump vertical coordinate + 128 pixels
       sta Sprite_Y_Position+16,y  ;into Y coordinates
       sta Sprite_Y_Position+20,y
       lda Enemy_OffscreenBits     ;get offscreen bits
       pha                         ;save to stack
       and #%00001000              ;check d3
       beq SOfs
       lda #$f8                    ;if d3 was set, move first and
       sta Sprite_Y_Position,y     ;fourth sprites offscreen
       sta Sprite_Y_Position+12,y
SOfs:  pla                         ;move out and back into stack
       pha
       and #%00000100              ;check d2
       beq SOfs2
       lda #$f8                    ;if d2 was set, move second and
       sta Sprite_Y_Position+4,y   ;fifth sprites offscreen
       sta Sprite_Y_Position+16,y
SOfs2: pla                         ;get from stack
       and #%00000010              ;check d1
       beq ExSPl
       lda #$f8                    ;if d1 was set, move third and
       sta Sprite_Y_Position+8,y   ;sixth sprites offscreen
       sta Sprite_Y_Position+20,y
ExSPl: ldx ObjectOffset            ;get enemy object offset and leave
       rts

;-------------------------------------------------------------------------------------

DrawBubble:
        ldy Player_Y_HighPos        ;if player's vertical high position
        dey                         ;not within screen, skip all of this
        bne ExDBub
        lda Bubble_OffscreenBits    ;check air bubble's offscreen bits
        and #%00001000
        bne ExDBub                  ;if bit set, branch to leave
        ldy Bubble_SprDataOffset,x  ;get air bubble's OAM data offset
        lda Bubble_Rel_XPos         ;get relative horizontal coordinate
        sta Sprite_X_Position,y     ;store as X coordinate here
        lda Bubble_Rel_YPos         ;get relative vertical coordinate
        sta Sprite_Y_Position,y     ;store as Y coordinate here
        lda #$74
        sta Sprite_Tilenumber,y     ;put air bubble tile into OAM data
        lda #$02
        sta Sprite_Attributes,y     ;set attribute byte
ExDBub: rts                         ;leave
