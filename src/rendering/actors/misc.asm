;-------------------------------------------------------------------------------------
;$00 - offset to vine Y coordinate adder
;$02 - offset to sprite data

VineYPosAdder:
      .byte $00, $30

DrawVine:
         sty $00                    ;save offset here
         lda Enemy_Rel_YPos         ;get relative vertical coordinate
         clc
         adc VineYPosAdder,y        ;add value using offset in Y to get value
         ldx VineObjOffset,y        ;get offset to vine
         ldy Enemy_SprDataOffset,x  ;get sprite data offset
         sty $02                    ;store sprite data offset here
         jsr SixSpriteStacker       ;stack six sprites on top of each other vertically
         lda Enemy_Rel_XPos         ;get relative horizontal coordinate
         sta Sprite_X_Position,y    ;store in first, third and fifth sprites
         sta Sprite_X_Position+8,y
         sta Sprite_X_Position+16,y
         clc
         adc #$06                   ;add six pixels to second, fourth and sixth sprites
         sta Sprite_X_Position+4,y  ;to give characteristic staggered vine shape to
         sta Sprite_X_Position+12,y ;our vertical stack of sprites
         sta Sprite_X_Position+20,y
         lda #%00100001             ;set bg priority and palette attribute bits
         sta Sprite_Attributes,y    ;set in first, third and fifth sprites
         sta Sprite_Attributes+8,y
         sta Sprite_Attributes+16,y
         ora #%01000000             ;additionally, set horizontal flip bit
         sta Sprite_Attributes+4,y  ;for second, fourth and sixth sprites
         sta Sprite_Attributes+12,y
         sta Sprite_Attributes+20,y
         ldx #$05                   ;set tiles for six sprites
VineTL:  lda #$e1                   ;set tile number for sprite
         sta Sprite_Tilenumber,y
         iny                        ;move offset to next sprite data
         iny
         iny
         iny
         dex                        ;move onto next sprite
         bpl VineTL                 ;loop until all sprites are done
         ldy $02                    ;get original offset
         lda $00                    ;get offset to vine adding data
         bne SkpVTop                ;if offset not zero, skip this part
         lda #$e0
         sta Sprite_Tilenumber,y    ;set other tile number for top of vine
SkpVTop: ldx #$00                   ;start with the first sprite again
ChkFTop: lda VineStart_Y_Position   ;get original starting vertical coordinate
         sec
         sbc Sprite_Y_Position,y    ;subtract top-most sprite's Y coordinate
         cmp #$64                   ;if two coordinates are less than 100/$64 pixels
         bcc NextVSp                ;apart, skip this to leave sprite alone
         lda #$f8
         sta Sprite_Y_Position,y    ;otherwise move sprite offscreen
NextVSp: iny                        ;move offset to next OAM data
         iny
         iny
         iny
         inx                        ;move onto next sprite
         cpx #$06                   ;do this until all sprites are checked
         bne ChkFTop
         ldy $00                    ;return offset set earlier
         rts

SixSpriteStacker:
       ldx #$06           ;do six sprites
StkLp: sta Sprite_Data,y  ;store X or Y coordinate into OAM data
       clc
       adc #$08           ;add eight pixels
       iny
       iny                ;move offset four bytes forward
       iny
       iny
       dex                ;do another sprite
       bne StkLp          ;do this until all sprites are done
       ldy $02            ;get saved OAM data offset and leave
       rts

;-------------------------------------------------------------------------------------

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
            ldy Misc_SprDataOffset,x    ;get misc object OAM data offset
            lda TimerControl
            bne ForceHPose              ;if master timer control set, skip this part
            lda Misc_State,x            ;otherwise get hammer's state
            and #%01111111              ;mask out d7
            cmp #$01                    ;check to see if set to 1 yet
            beq GetHPose                ;if so, branch
ForceHPose: ldx #$00                    ;reset offset here
            beq RenderH                 ;do unconditional branch to rendering part
GetHPose:   lda FrameCounter            ;get frame counter
            lsr                         ;move d3-d2 to d1-d0
            lsr
            and #%00000011              ;mask out all but d1-d0 (changes every four frames)
            tax                         ;use as timing offset
RenderH:    lda Misc_Rel_YPos           ;get relative vertical coordinate
            clc
            adc FirstSprYPos,x          ;add first sprite vertical adder based on offset
            sta Sprite_Y_Position,y     ;store as sprite Y coordinate for first sprite
            clc
            adc SecondSprYPos,x         ;add second sprite vertical adder based on offset
            sta Sprite_Y_Position+4,y   ;store as sprite Y coordinate for second sprite
            lda Misc_Rel_XPos           ;get relative horizontal coordinate
            clc
            adc FirstSprXPos,x          ;add first sprite horizontal adder based on offset
            sta Sprite_X_Position,y     ;store as sprite X coordinate for first sprite
            clc
            adc SecondSprXPos,x         ;add second sprite horizontal adder based on offset
            sta Sprite_X_Position+4,y   ;store as sprite X coordinate for second sprite
            lda FirstSprTilenum,x
            sta Sprite_Tilenumber,y     ;get and store tile number of first sprite
            lda SecondSprTilenum,x
            sta Sprite_Tilenumber+4,y   ;get and store tile number of second sprite
            lda HammerSprAttrib,x
            sta Sprite_Attributes,y     ;get and store attribute bytes for both
            sta Sprite_Attributes+4,y   ;note in this case they use the same data
            ldx ObjectOffset            ;get misc object offset
            lda Misc_OffscreenBits
            and #%11111100              ;check offscreen bits
            beq NoHOffscr               ;if all bits clear, leave object alone
            lda #$00
            sta Misc_State,x            ;otherwise nullify misc object state
            lda #$f8
            jsr DumpTwoSpr              ;do sub to move hammer sprites offscreen
NoHOffscr:  rts                         ;leave

;-------------------------------------------------------------------------------------
;$00-$01 - used to hold tile numbers ($01 addressed in draw floatey number part)
;$02 - used to hold Y coordinate for floatey number
;$03 - residual byte used for flip (but value set here affects nothing)
;$04 - attribute byte for floatey number
;$05 - used as X coordinate for floatey number

FlagpoleScoreNumTiles:
      .byte $f9, $50
      .byte $f7, $50
      .byte $fa, $fb
      .byte $f8, $fb
      .byte $f6, $fb

FlagpoleGfxHandler:
      ldy Enemy_SprDataOffset,x      ;get sprite data offset for flagpole flag
      lda Enemy_Rel_XPos             ;get relative horizontal coordinate
      sta Sprite_X_Position,y        ;store as X coordinate for first sprite
      clc
      adc #$08                       ;add eight pixels and store
      sta Sprite_X_Position+4,y      ;as X coordinate for second and third sprites
      sta Sprite_X_Position+8,y
      clc
      adc #$0c                       ;add twelve more pixels and
      sta $05                        ;store here to be used later by floatey number
      lda Enemy_Y_Position,x         ;get vertical coordinate
      jsr DumpTwoSpr                 ;and do sub to dump into first and second sprites
      adc #$08                       ;add eight pixels
      sta Sprite_Y_Position+8,y      ;and store into third sprite
      lda FlagpoleFNum_Y_Pos         ;get vertical coordinate for floatey number
      sta $02                        ;store it here
      lda #$01
      sta $03                        ;set value for flip which will not be used, and
      sta $04                        ;attribute byte for floatey number
      sta Sprite_Attributes,y        ;set attribute bytes for all three sprites
      sta Sprite_Attributes+4,y
      sta Sprite_Attributes+8,y
      lda #$7e
      sta Sprite_Tilenumber,y        ;put triangle shaped tile
      sta Sprite_Tilenumber+8,y      ;into first and third sprites
      lda #$7f
      sta Sprite_Tilenumber+4,y      ;put skull tile into second sprite
      lda FlagpoleCollisionYPos      ;get vertical coordinate at time of collision
      beq ChkFlagOffscreen           ;if zero, branch ahead
      tya
      clc                            ;add 12 bytes to sprite data offset
      adc #$0c
      tay                            ;put back in Y
      lda FlagpoleScore              ;get offset used to award points for touching flagpole
      asl                            ;multiply by 2 to get proper offset here
      tax
      lda FlagpoleScoreNumTiles,x    ;get appropriate tile data
      sta $00
      lda FlagpoleScoreNumTiles+1,x
      jsr DrawOneSpriteRow           ;use it to render floatey number

ChkFlagOffscreen:
      ldx ObjectOffset               ;get object offset for flag
      ldy Enemy_SprDataOffset,x      ;get OAM data offset
      lda Enemy_OffscreenBits        ;get offscreen bits
      and #%00001110                 ;mask out all but d3-d1
      beq ExitDumpSpr                ;if none of these bits set, branch to leave

;-------------------------------------------------------------------------------------

MoveSixSpritesOffscreen:
      lda #$f8                  ;set offscreen coordinate if jumping here

DumpSixSpr:
      sta Sprite_Data+20,y      ;dump A contents
      sta Sprite_Data+16,y      ;into third row sprites

DumpFourSpr:
      sta Sprite_Data+12,y      ;into second row sprites

DumpThreeSpr:
      sta Sprite_Data+8,y

DumpTwoSpr:
      sta Sprite_Data+4,y       ;and into first row sprites
      sta Sprite_Data,y

ExitDumpSpr:
      rts

;-------------------------------------------------------------------------------------

DrawLargePlatform:
      ldy Enemy_SprDataOffset,x   ;get OAM data offset
      sty $02                     ;store here
      iny                         ;add 3 to it for offset
      iny                         ;to X coordinate
      iny
      lda Enemy_Rel_XPos          ;get horizontal relative coordinate
      jsr SixSpriteStacker        ;store X coordinates using A as base, stack horizontally
      ldx ObjectOffset
      lda Enemy_Y_Position,x      ;get vertical coordinate
      jsr DumpFourSpr             ;dump into first four sprites as Y coordinate
      ldy AreaType
      cpy #$03                    ;check for castle-type level
      beq ShrinkPlatform
      ldy SecondaryHardMode       ;check for secondary hard mode flag set
      beq SetLast2Platform        ;branch if not set elsewhere

ShrinkPlatform:
      lda #$f8                    ;load offscreen coordinate if flag set or castle-type level

SetLast2Platform:
      ldy Enemy_SprDataOffset,x   ;get OAM data offset
      sta Sprite_Y_Position+16,y  ;store vertical coordinate or offscreen
      sta Sprite_Y_Position+20,y  ;coordinate into last two sprites as Y coordinate
      lda #$5b                    ;load default tile for platform (girder)
      ldx CloudTypeOverride
      beq SetPlatformTilenum      ;if cloud level override flag not set, use
      lda #$75                    ;otherwise load other tile for platform (puff)

SetPlatformTilenum:
        ldx ObjectOffset            ;get enemy object buffer offset
        iny                         ;increment Y for tile offset
        jsr DumpSixSpr              ;dump tile number into all six sprites
        lda #$02                    ;set palette controls
        iny                         ;increment Y for sprite attributes
        jsr DumpSixSpr              ;dump attributes into all six sprites
        inx                         ;increment X for enemy objects
        jsr GetXOffscreenBits       ;get offscreen bits again
        dex
        ldy Enemy_SprDataOffset,x   ;get OAM data offset
        asl                         ;rotate d7 into carry, save remaining
        pha                         ;bits to the stack
        bcc SChk2
        lda #$f8                    ;if d7 was set, move first sprite offscreen
        sta Sprite_Y_Position,y
SChk2:  pla                         ;get bits from stack
        asl                         ;rotate d6 into carry
        pha                         ;save to stack
        bcc SChk3
        lda #$f8                    ;if d6 was set, move second sprite offscreen
        sta Sprite_Y_Position+4,y
SChk3:  pla                         ;get bits from stack
        asl                         ;rotate d5 into carry
        pha                         ;save to stack
        bcc SChk4
        lda #$f8                    ;if d5 was set, move third sprite offscreen
        sta Sprite_Y_Position+8,y
SChk4:  pla                         ;get bits from stack
        asl                         ;rotate d4 into carry
        pha                         ;save to stack
        bcc SChk5
        lda #$f8                    ;if d4 was set, move fourth sprite offscreen
        sta Sprite_Y_Position+12,y
SChk5:  pla                         ;get bits from stack
        asl                         ;rotate d3 into carry
        pha                         ;save to stack
        bcc SChk6
        lda #$f8                    ;if d3 was set, move fifth sprite offscreen
        sta Sprite_Y_Position+16,y
SChk6:  pla                         ;get bits from stack
        asl                         ;rotate d2 into carry
        bcc SLChk                   ;save to stack
        lda #$f8
        sta Sprite_Y_Position+20,y  ;if d2 was set, move sixth sprite offscreen
SLChk:  lda Enemy_OffscreenBits     ;check d7 of offscreen bits
        asl                         ;and if d7 is not set, skip sub
        bcc ExDLPl
        jsr MoveSixSpritesOffscreen ;otherwise branch to move all sprites offscreen
ExDLPl: rts

;-------------------------------------------------------------------------------------

DrawFloateyNumber_Coin:
          lda FrameCounter          ;get frame counter
          lsr                       ;divide by 2
          bcs NotRsNum              ;branch if d0 not set to raise number every other frame
          dec Misc_Y_Position,x     ;otherwise, decrement vertical coordinate
NotRsNum: lda Misc_Y_Position,x     ;get vertical coordinate
          jsr DumpTwoSpr            ;dump into both sprites
          lda Misc_Rel_XPos         ;get relative horizontal coordinate
          sta Sprite_X_Position,y   ;store as X coordinate for first sprite
          clc
          adc #$08                  ;add eight pixels
          sta Sprite_X_Position+4,y ;store as X coordinate for second sprite
          lda #$02
          sta Sprite_Attributes,y   ;store attribute byte in both sprites
          sta Sprite_Attributes+4,y
          lda #$f7
          sta Sprite_Tilenumber,y   ;put tile numbers into both sprites
          lda #$fb                  ;that resemble "200"
          sta Sprite_Tilenumber+4,y
          jmp ExJCGfx               ;then jump to leave (why not an rts here instead?)

JumpingCoinTiles:
      .byte $60, $61, $62, $63

JCoinGfxHandler:
         ldy Misc_SprDataOffset,x    ;get coin/floatey number's OAM data offset
         lda Misc_State,x            ;get state of misc object
         cmp #$02                    ;if 2 or greater,
         bcs DrawFloateyNumber_Coin  ;branch to draw floatey number
         lda Misc_Y_Position,x       ;store vertical coordinate as
         sta Sprite_Y_Position,y     ;Y coordinate for first sprite
         clc
         adc #$08                    ;add eight pixels
         sta Sprite_Y_Position+4,y   ;store as Y coordinate for second sprite
         lda Misc_Rel_XPos           ;get relative horizontal coordinate
         sta Sprite_X_Position,y
         sta Sprite_X_Position+4,y   ;store as X coordinate for first and second sprites
         lda FrameCounter            ;get frame counter
         lsr                         ;divide by 2 to alter every other frame
         and #%00000011              ;mask out d2-d1
         tax                         ;use as graphical offset
         lda JumpingCoinTiles,x      ;load tile number
         iny                         ;increment OAM data offset to write tile numbers
         jsr DumpTwoSpr              ;do sub to dump tile number into both sprites
         dey                         ;decrement to get old offset
         lda #$02
         sta Sprite_Attributes,y     ;set attribute byte in first sprite
         lda #$82
         sta Sprite_Attributes+4,y   ;set attribute byte with vertical flip in second sprite
         ldx ObjectOffset            ;get misc object offset
ExJCGfx: rts                         ;leave

;-------------------------------------------------------------------------------------
;$00-$01 - used to hold tiles for drawing the power-up, $00 also used to hold power-up type
;$02 - used to hold bottom row Y position
;$03 - used to hold flip control (not used here)
;$04 - used to hold sprite attributes
;$05 - used to hold X position
;$07 - counter

;tiles arranged in top left, right, bottom left, right order
PowerUpGfxTable:
      .byte $76, $77, $78, $79 ;regular mushroom
      .byte $d6, $d6, $d9, $d9 ;fire flower
      .byte $8d, $8d, $e4, $e4 ;star
      .byte $76, $77, $78, $79 ;1-up mushroom

PowerUpAttributes:
      .byte $02, $01, $02, $01

DrawPowerUp:
      ldy Enemy_SprDataOffset+5  ;get power-up's sprite data offset
      lda Enemy_Rel_YPos         ;get relative vertical coordinate
      clc
      adc #$08                   ;add eight pixels
      sta $02                    ;store result here
      lda Enemy_Rel_XPos         ;get relative horizontal coordinate
      sta $05                    ;store here
      ldx PowerUpType            ;get power-up type
      lda PowerUpAttributes,x    ;get attribute data for power-up type
      ora Enemy_SprAttrib+5      ;add background priority bit if set
      sta $04                    ;store attributes here
      txa
      pha                        ;save power-up type to the stack
      asl
      asl                        ;multiply by four to get proper offset
      tax                        ;use as X
      lda #$01
      sta $07                    ;set counter here to draw two rows of sprite object
      sta $03                    ;init d1 of flip control

PUpDrawLoop:
        lda PowerUpGfxTable,x      ;load left tile of power-up object
        sta $00
        lda PowerUpGfxTable+1,x    ;load right tile
        jsr DrawOneSpriteRow       ;branch to draw one row of our power-up object
        dec $07                    ;decrement counter
        bpl PUpDrawLoop            ;branch until two rows are drawn
        ldy Enemy_SprDataOffset+5  ;get sprite data offset again
        pla                        ;pull saved power-up type from the stack
        beq PUpOfs                 ;if regular mushroom, branch, do not change colors or flip
        cmp #$03
        beq PUpOfs                 ;if 1-up mushroom, branch, do not change colors or flip
        sta $00                    ;store power-up type here now
        lda FrameCounter           ;get frame counter
        lsr                        ;divide by 2 to change colors every two frames
        and #%00000011             ;mask out all but d1 and d0 (previously d2 and d1)
        ora Enemy_SprAttrib+5      ;add background priority bit if any set
        sta Sprite_Attributes,y    ;set as new palette bits for top left and
        sta Sprite_Attributes+4,y  ;top right sprites for fire flower and star
        ldx $00
        dex                        ;check power-up type for fire flower
        beq FlipPUpRightSide       ;if found, skip this part
        sta Sprite_Attributes+8,y  ;otherwise set new palette bits  for bottom left
        sta Sprite_Attributes+12,y ;and bottom right sprites as well for star only

FlipPUpRightSide:
        lda Sprite_Attributes+4,y
        ora #%01000000             ;set horizontal flip bit for top right sprite
        sta Sprite_Attributes+4,y
        lda Sprite_Attributes+12,y
        ora #%01000000             ;set horizontal flip bit for bottom right sprite
        sta Sprite_Attributes+12,y ;note these are only done for fire flower and star power-ups
PUpOfs: jmp SprObjectOffscrChk     ;jump to check to see if power-up is offscreen at all, then leave
