;-------------------------------------------------------------------------------------
;$00-$01 - used in DrawEnemyObjRow to hold sprite tile numbers
;$02 - used to store Y position
;$03 - used to store moving direction, used to flip enemies horizontally
;$04 - used to store enemy's sprite attributes
;$05 - used to store X position
;$eb - used to hold sprite data offset
;$ec - used to hold either altered enemy state or special value used in gfx handler as condition
;$ed - used to hold enemy state from buffer
;$ef - used to hold enemy code used in gfx handler (may or may not resemble Enemy_ID values)

;tiles arranged in top left, right, middle left, right, bottom left, right order
EnemyGraphicsTable:
      .byte $fc, $fc, $aa, $ab, $ac, $ad  ;buzzy beetle frame 1
      .byte $fc, $fc, $ae, $af, $b0, $b1  ;             frame 2
      .byte $fc, $a5, $a6, $a7, $a8, $a9  ;koopa troopa frame 1
      .byte $fc, $a0, $a1, $a2, $a3, $a4  ;             frame 2
      .byte $69, $a5, $6a, $a7, $a8, $a9  ;koopa paratroopa frame 1
      .byte $6b, $a0, $6c, $a2, $a3, $a4  ;                 frame 2
      .byte $fc, $fc, $96, $97, $98, $99  ;spiny frame 1
      .byte $fc, $fc, $9a, $9b, $9c, $9d  ;      frame 2
      .byte $fc, $fc, $8f, $8e, $8e, $8f  ;spiny's egg frame 1
      .byte $fc, $fc, $95, $94, $94, $95  ;            frame 2
      .byte $fc, $fc, $dc, $dc, $df, $df  ;bloober frame 1
      .byte $dc, $dc, $dd, $dd, $de, $de  ;        frame 2
      .byte $fc, $fc, $b2, $b3, $b4, $b5  ;cheep-cheep frame 1
      .byte $fc, $fc, $b6, $b3, $b7, $b5  ;            frame 2
      .byte $fc, $fc, $70, $71, $72, $73  ;goomba
      .byte $fc, $fc, $6e, $6e, $6f, $6f  ;koopa shell frame 1 (upside-down)
      .byte $fc, $fc, $6d, $6d, $6f, $6f  ;            frame 2
      .byte $fc, $fc, $6f, $6f, $6e, $6e  ;koopa shell frame 1 (rightsideup)
      .byte $fc, $fc, $6f, $6f, $6d, $6d  ;            frame 2
      .byte $fc, $fc, $f4, $f4, $f5, $f5  ;buzzy beetle shell frame 1 (rightsideup)
      .byte $fc, $fc, $f4, $f4, $f5, $f5  ;                   frame 2
      .byte $fc, $fc, $f5, $f5, $f4, $f4  ;buzzy beetle shell frame 1 (upside-down)
      .byte $fc, $fc, $f5, $f5, $f4, $f4  ;                   frame 2
      .byte $fc, $fc, $fc, $fc, $ef, $ef  ;defeated goomba
      .byte $b9, $b8, $bb, $ba, $bc, $bc  ;lakitu frame 1
      .byte $fc, $fc, $bd, $bd, $bc, $bc  ;       frame 2
      .byte $7a, $7b, $da, $db, $d8, $d8  ;princess
      .byte $cd, $cd, $ce, $ce, $cf, $cf  ;mushroom retainer
      .byte $7d, $7c, $d1, $8c, $d3, $d2  ;hammer bro frame 1
      .byte $7d, $7c, $89, $88, $8b, $8a  ;           frame 2
      .byte $d5, $d4, $e3, $e2, $d3, $d2  ;           frame 3
      .byte $d5, $d4, $e3, $e2, $8b, $8a  ;           frame 4
      .byte $e5, $e5, $e6, $e6, $eb, $eb  ;piranha plant frame 1
      .byte $ec, $ec, $ed, $ed, $ee, $ee  ;              frame 2
      .byte $fc, $fc, $d0, $d0, $d7, $d7  ;podoboo
      .byte $bf, $be, $c1, $c0, $c2, $fc  ;bowser front frame 1
      .byte $c4, $c3, $c6, $c5, $c8, $c7  ;bowser rear frame 1
      .byte $bf, $be, $ca, $c9, $c2, $fc  ;       front frame 2
      .byte $c4, $c3, $c6, $c5, $cc, $cb  ;       rear frame 2
      .byte $fc, $fc, $e8, $e7, $ea, $e9  ;bullet bill
      .byte $f2, $f2, $f3, $f3, $f2, $f2  ;jumpspring frame 1
      .byte $f1, $f1, $f1, $f1, $fc, $fc  ;           frame 2
      .byte $f0, $f0, $fc, $fc, $fc, $fc  ;           frame 3

EnemyGfxTableOffsets:
      .byte $0c, $0c, $00, $0c, $0c, $a8, $54, $3c
      .byte $ea, $18, $48, $48, $cc, $c0, $18, $18
      .byte $18, $90, $24, $ff, $48, $9c, $d2, $d8
      .byte $f0, $f6, $fc

EnemyAttributeData:
      .byte $01, $02, $03, $02, $01, $01, $03, $03
      .byte $03, $01, $01, $02, $02, $21, $01, $02
      .byte $01, $01, $02, $ff, $02, $02, $01, $01
      .byte $02, $02, $02

EnemyAnimTimingBMask:
      .byte $08, $18

JumpspringFrameOffsets:
      .byte $18, $19, $1a, $19, $18

EnemyGfxHandler:
      lda Enemy_Y_Position,x      ;get enemy object vertical position
      sta $02
      lda Enemy_Rel_XPos          ;get enemy object horizontal position
      sta $05                     ;relative to screen
      ldy Enemy_SprDataOffset,x
      sty $eb                     ;get sprite data offset
      lda #$00
      sta VerticalFlipFlag        ;initialize vertical flip flag by default
      lda Enemy_MovingDir,x
      sta $03                     ;get enemy object moving direction
      lda Enemy_SprAttrib,x
      sta $04                     ;get enemy object sprite attributes
      lda Enemy_ID,x
      cmp #PiranhaPlant           ;is enemy object piranha plant?
      bne CheckForRetainerObj     ;if not, branch
      ldy PiranhaPlant_Y_Speed,x
      bmi CheckForRetainerObj     ;if piranha plant moving upwards, branch
      ldy EnemyFrameTimer,x
      beq CheckForRetainerObj     ;if timer for movement expired, branch
      rts                         ;if all conditions fail, leave

CheckForRetainerObj:
      lda Enemy_State,x           ;store enemy state
      sta $ed
      and #%00011111              ;nullify all but 5 LSB and use as Y
      tay
      lda Enemy_ID,x              ;check for mushroom retainer/princess object
      cmp #RetainerObject
      bne CheckForBulletBillCV    ;if not found, branch
      ldy #$00                    ;if found, nullify saved state in Y
      lda #$01                    ;set value that will not be used
      sta $03
      lda #$15                    ;set value $15 as code for mushroom retainer/princess object

CheckForBulletBillCV:
       cmp #BulletBill_CannonVar   ;otherwise check for bullet bill object
       bne CheckForJumpspring      ;if not found, branch again
       dec $02                     ;decrement saved vertical position
       lda #$03
       ldy EnemyFrameTimer,x       ;get timer for enemy object
       beq SBBAt                   ;if expired, do not set priority bit
       ora #%00100000              ;otherwise do so
SBBAt: sta $04                     ;set new sprite attributes
       ldy #$00                    ;nullify saved enemy state both in Y and in
       sty $ed                     ;memory location here
       lda #$08                    ;set specific value to unconditionally branch once

CheckForJumpspring:
      cmp #JumpspringObject        ;check for jumpspring object
      bne CheckForPodoboo
      ldy #$03                     ;set enemy state -2 MSB here for jumpspring object
      ldx JumpspringAnimCtrl       ;get current frame number for jumpspring object
      lda JumpspringFrameOffsets,x ;load data using frame number as offset

CheckForPodoboo:
      sta $ef                 ;store saved enemy object value here
      sty $ec                 ;and Y here (enemy state -2 MSB if not changed)
      ldx ObjectOffset        ;get enemy object offset
      cmp #$0c                ;check for podoboo object
      bne CheckBowserGfxFlag  ;branch if not found
      lda Enemy_Y_Speed,x     ;if moving upwards, branch
      bmi CheckBowserGfxFlag
      inc VerticalFlipFlag    ;otherwise, set flag for vertical flip

CheckBowserGfxFlag:
             lda BowserGfxFlag   ;if not drawing bowser at all, skip to something else
             beq CheckForGoomba
             ldy #$16            ;if set to 1, draw bowser's front
             cmp #$01
             beq SBwsrGfxOfs
             iny                 ;otherwise draw bowser's rear
SBwsrGfxOfs: sty $ef

CheckForGoomba:
          ldy $ef               ;check value for goomba object
          cpy #Goomba
          bne CheckBowserFront  ;branch if not found
          lda Enemy_State,x
          cmp #$02              ;check for defeated state
          bcc GmbaAnim          ;if not defeated, go ahead and animate
          ldx #$04              ;if defeated, write new value here
          stx $ec
GmbaAnim: and #%00100000        ;check for d5 set in enemy object state
          ora TimerControl      ;or timer disable flag set
          bne CheckBowserFront  ;if either condition true, do not animate goomba
          lda FrameCounter
          and #%00001000        ;check for every eighth frame
          bne CheckBowserFront
          lda $03
          eor #%00000011        ;invert bits to flip horizontally every eight frames
          sta $03               ;leave alone otherwise

CheckBowserFront:
             lda EnemyAttributeData,y    ;load sprite attribute using enemy object
             ora $04                     ;as offset, and add to bits already loaded
             sta $04
             lda EnemyGfxTableOffsets,y  ;load value based on enemy object as offset
             tax                         ;save as X
             ldy $ec                     ;get previously saved value
             lda BowserGfxFlag
             beq CheckForSpiny           ;if not drawing bowser object at all, skip all of this
             cmp #$01
             bne CheckBowserRear         ;if not drawing front part, branch to draw the rear part
             lda BowserBodyControls      ;check bowser's body control bits
             bpl ChkFrontSte             ;branch if d7 not set (control's bowser's mouth)
             ldx #$de                    ;otherwise load offset for second frame
ChkFrontSte: lda $ed                     ;check saved enemy state
             and #%00100000              ;if bowser not defeated, do not set flag
             beq DrawBowser

FlipBowserOver:
      stx VerticalFlipFlag  ;set vertical flip flag to nonzero

DrawBowser:
      jmp DrawEnemyObject   ;draw bowser's graphics now

CheckBowserRear:
            lda BowserBodyControls  ;check bowser's body control bits
            and #$01
            beq ChkRearSte          ;branch if d0 not set (control's bowser's feet)
            ldx #$e4                ;otherwise load offset for second frame
ChkRearSte: lda $ed                 ;check saved enemy state
            and #%00100000          ;if bowser not defeated, do not set flag
            beq DrawBowser
            lda $02                 ;subtract 16 pixels from
            sec                     ;saved vertical coordinate
            sbc #$10
            sta $02
            jmp FlipBowserOver      ;jump to set vertical flip flag

CheckForSpiny:
        cpx #$24               ;check if value loaded is for spiny
        bne CheckForLakitu     ;if not found, branch
        cpy #$05               ;if enemy state set to $05, do this,
        bne NotEgg             ;otherwise branch
        ldx #$30               ;set to spiny egg offset
        lda #$02
        sta $03                ;set enemy direction to reverse sprites horizontally
        lda #$05
        sta $ec                ;set enemy state
NotEgg: jmp CheckForHammerBro  ;skip a big chunk of this if we found spiny but not in egg

CheckForLakitu:
        cpx #$90                  ;check value for lakitu's offset loaded
        bne CheckUpsideDownShell  ;branch if not loaded
        lda $ed
        and #%00100000            ;check for d5 set in enemy state
        bne NoLAFr                ;branch if set
        lda FrenzyEnemyTimer
        cmp #$10                  ;check timer to see if we've reached a certain range
        bcs NoLAFr                ;branch if not
        ldx #$96                  ;if d6 not set and timer in range, load alt frame for lakitu
NoLAFr: jmp CheckDefeatedState    ;skip this next part if we found lakitu but alt frame not needed

CheckUpsideDownShell:
      lda $ef                    ;check for enemy object => $04
      cmp #$04
      bcs CheckRightSideUpShell  ;branch if true
      cpy #$02
      bcc CheckRightSideUpShell  ;branch if enemy state < $02
      ldx #$5a                   ;set for upside-down koopa shell by default
      ldy $ef
      cpy #BuzzyBeetle           ;check for buzzy beetle object
      bne CheckRightSideUpShell
      ldx #$7e                   ;set for upside-down buzzy beetle shell if found
      inc $02                    ;increment vertical position by one pixel

CheckRightSideUpShell:
      lda $ec                ;check for value set here
      cmp #$04               ;if enemy state < $02, do not change to shell, if
      bne CheckForHammerBro  ;enemy state => $02 but not = $04, leave shell upside-down
      ldx #$72               ;set right-side up buzzy beetle shell by default
      inc $02                ;increment saved vertical position by one pixel
      ldy $ef
      cpy #BuzzyBeetle       ;check for buzzy beetle object
      beq CheckForDefdGoomba ;branch if found
      ldx #$66               ;change to right-side up koopa shell if not found
      inc $02                ;and increment saved vertical position again

CheckForDefdGoomba:
      cpy #Goomba            ;check for goomba object (necessary if previously
      bne CheckForHammerBro  ;failed buzzy beetle object test)
      ldx #$54               ;load for regular goomba
      lda $ed                ;note that this only gets performed if enemy state => $02
      and #%00100000         ;check saved enemy state for d5 set
      bne CheckForHammerBro  ;branch if set
      ldx #$8a               ;load offset for defeated goomba
      dec $02                ;set different value and decrement saved vertical position

CheckForHammerBro:
      ldy ObjectOffset
      lda $ef                  ;check for hammer bro object
      cmp #HammerBro
      bne CheckForBloober      ;branch if not found
      lda $ed
      beq CheckToAnimateEnemy  ;branch if not in normal enemy state
      and #%00001000
      beq CheckDefeatedState   ;if d3 not set, branch further away
      ldx #$b4                 ;otherwise load offset for different frame
      bne CheckToAnimateEnemy  ;unconditional branch

CheckForBloober:
      cpx #$48                 ;check for cheep-cheep offset loaded
      beq CheckToAnimateEnemy  ;branch if found
      lda EnemyIntervalTimer,y
      cmp #$05
      bcs CheckDefeatedState   ;branch if some timer is above a certain point
      cpx #$3c                 ;check for bloober offset loaded
      bne CheckToAnimateEnemy  ;branch if not found this time
      cmp #$01
      beq CheckDefeatedState   ;branch if timer is set to certain point
      inc $02                  ;increment saved vertical coordinate three pixels
      inc $02
      inc $02
      jmp CheckAnimationStop   ;and do something else

CheckToAnimateEnemy:
      lda $ef                  ;check for specific enemy objects
      cmp #Goomba
      beq CheckDefeatedState   ;branch if goomba
      cmp #$08
      beq CheckDefeatedState   ;branch if bullet bill (note both variants use $08 here)
      cmp #Podoboo
      beq CheckDefeatedState   ;branch if podoboo
      cmp #$18                 ;branch if => $18
      bcs CheckDefeatedState
      ldy #$00
      cmp #$15                 ;check for mushroom retainer/princess object
      bne CheckForSecondFrame  ;which uses different code here, branch if not found
      iny                      ;residual instruction
      lda WorldNumber          ;are we on world 8?
      cmp #World8
      bcs CheckDefeatedState   ;if so, leave the offset alone (use princess)
      ldx #$a2                 ;otherwise, set for mushroom retainer object instead
      lda #$03                 ;set alternate state here
      sta $ec
      bne CheckDefeatedState   ;unconditional branch

CheckForSecondFrame:
      lda FrameCounter            ;load frame counter
      and EnemyAnimTimingBMask,y  ;mask it (partly residual, one byte not ever used)
      bne CheckDefeatedState      ;branch if timing is off

CheckAnimationStop:
      lda $ed                 ;check saved enemy state
      and #%10100000          ;for d7 or d5, or check for timers stopped
      ora TimerControl
      bne CheckDefeatedState  ;if either condition true, branch
      txa
      clc
      adc #$06                ;add $06 to current enemy offset
      tax                     ;to animate various enemy objects

CheckDefeatedState:
      lda $ed               ;check saved enemy state
      and #%00100000        ;for d5 set
      beq DrawEnemyObject   ;branch if not set
      lda $ef
      cmp #$04              ;check for saved enemy object => $04
      bcc DrawEnemyObject   ;branch if less
      ldy #$01
      sty VerticalFlipFlag  ;set vertical flip flag
      dey
      sty $ec               ;init saved value here

DrawEnemyObject:
      ldy $eb                    ;load sprite data offset
      jsr DrawEnemyObjRow        ;draw six tiles of data
      jsr DrawEnemyObjRow        ;into sprite data
      jsr DrawEnemyObjRow
      ldx ObjectOffset           ;get enemy object offset
      ldy Enemy_SprDataOffset,x  ;get sprite data offset
      lda $ef
      cmp #$08                   ;get saved enemy object and check
      bne CheckForVerticalFlip   ;for bullet bill, branch if not found

SkipToOffScrChk:
      jmp SprObjectOffscrChk     ;jump if found

CheckForVerticalFlip:
      lda VerticalFlipFlag       ;check if vertical flip flag is set here
      beq CheckForESymmetry      ;branch if not
      lda Sprite_Attributes,y    ;get attributes of first sprite we dealt with
      ora #%10000000             ;set bit for vertical flip
      iny
      iny                        ;increment two bytes so that we store the vertical flip
      jsr DumpSixSpr             ;in attribute bytes of enemy obj sprite data
      dey
      dey                        ;now go back to the Y coordinate offset
      tya
      tax                        ;give offset to X
      lda $ef
      cmp #HammerBro             ;check saved enemy object for hammer bro
      beq FlipEnemyVertically
      cmp #Lakitu                ;check saved enemy object for lakitu
      beq FlipEnemyVertically    ;branch for hammer bro or lakitu
      cmp #$15
      bcs FlipEnemyVertically    ;also branch if enemy object => $15
      txa
      clc
      adc #$08                   ;if not selected objects or => $15, set
      tax                        ;offset in X for next row

FlipEnemyVertically:
      lda Sprite_Tilenumber,x     ;load first or second row tiles
      pha                         ;and save tiles to the stack
      lda Sprite_Tilenumber+4,x
      pha
      lda Sprite_Tilenumber+16,y  ;exchange third row tiles
      sta Sprite_Tilenumber,x     ;with first or second row tiles
      lda Sprite_Tilenumber+20,y
      sta Sprite_Tilenumber+4,x
      pla                         ;pull first or second row tiles from stack
      sta Sprite_Tilenumber+20,y  ;and save in third row
      pla
      sta Sprite_Tilenumber+16,y

CheckForESymmetry:
        lda BowserGfxFlag           ;are we drawing bowser at all?
        bne SkipToOffScrChk         ;branch if so
        lda $ef
        ldx $ec                     ;get alternate enemy state
        cmp #$05                    ;check for hammer bro object
        bne ContES
        jmp SprObjectOffscrChk      ;jump if found
ContES: cmp #Bloober                ;check for bloober object
        beq MirrorEnemyGfx
        cmp #PiranhaPlant           ;check for piranha plant object
        beq MirrorEnemyGfx
        cmp #Podoboo                ;check for podoboo object
        beq MirrorEnemyGfx          ;branch if either of three are found
        cmp #Spiny                  ;check for spiny object
        bne ESRtnr                  ;branch closer if not found
        cpx #$05                    ;check spiny's state
        bne CheckToMirrorLakitu     ;branch if not an egg, otherwise
ESRtnr: cmp #$15                    ;check for princess/mushroom retainer object
        bne SpnySC
        lda #$42                    ;set horizontal flip on bottom right sprite
        sta Sprite_Attributes+20,y  ;note that palette bits were already set earlier
SpnySC: cpx #$02                    ;if alternate enemy state set to 1 or 0, branch
        bcc CheckToMirrorLakitu

MirrorEnemyGfx:
        lda BowserGfxFlag           ;if enemy object is bowser, skip all of this
        bne CheckToMirrorLakitu
        lda Sprite_Attributes,y     ;load attribute bits of first sprite
        and #%10100011
        sta Sprite_Attributes,y     ;save vertical flip, priority, and palette bits
        sta Sprite_Attributes+8,y   ;in left sprite column of enemy object OAM data
        sta Sprite_Attributes+16,y
        ora #%01000000              ;set horizontal flip
        cpx #$05                    ;check for state used by spiny's egg
        bne EggExc                  ;if alternate state not set to $05, branch
        ora #%10000000              ;otherwise set vertical flip
EggExc: sta Sprite_Attributes+4,y   ;set bits of right sprite column
        sta Sprite_Attributes+12,y  ;of enemy object sprite data
        sta Sprite_Attributes+20,y
        cpx #$04                    ;check alternate enemy state
        bne CheckToMirrorLakitu     ;branch if not $04
        lda Sprite_Attributes+8,y   ;get second row left sprite attributes
        ora #%10000000
        sta Sprite_Attributes+8,y   ;store bits with vertical flip in
        sta Sprite_Attributes+16,y  ;second and third row left sprites
        ora #%01000000
        sta Sprite_Attributes+12,y  ;store with horizontal and vertical flip in
        sta Sprite_Attributes+20,y  ;second and third row right sprites

CheckToMirrorLakitu:
        lda $ef                     ;check for lakitu enemy object
        cmp #Lakitu
        bne CheckToMirrorJSpring    ;branch if not found
        lda VerticalFlipFlag
        bne NVFLak                  ;branch if vertical flip flag not set
        lda Sprite_Attributes+16,y  ;save vertical flip and palette bits
        and #%10000001              ;in third row left sprite
        sta Sprite_Attributes+16,y
        lda Sprite_Attributes+20,y  ;set horizontal flip and palette bits
        ora #%01000001              ;in third row right sprite
        sta Sprite_Attributes+20,y
        ldx FrenzyEnemyTimer        ;check timer
        cpx #$10
        bcs SprObjectOffscrChk      ;branch if timer has not reached a certain range
        sta Sprite_Attributes+12,y  ;otherwise set same for second row right sprite
        and #%10000001
        sta Sprite_Attributes+8,y   ;preserve vertical flip and palette bits for left sprite
        bcc SprObjectOffscrChk      ;unconditional branch
NVFLak: lda Sprite_Attributes,y     ;get first row left sprite attributes
        and #%10000001
        sta Sprite_Attributes,y     ;save vertical flip and palette bits
        lda Sprite_Attributes+4,y   ;get first row right sprite attributes
        ora #%01000001              ;set horizontal flip and palette bits
        sta Sprite_Attributes+4,y   ;note that vertical flip is left as-is

CheckToMirrorJSpring:
      lda $ef                     ;check for jumpspring object (any frame)
      cmp #$18
      bcc SprObjectOffscrChk      ;branch if not jumpspring object at all
      lda #$82
      sta Sprite_Attributes+8,y   ;set vertical flip and palette bits of
      sta Sprite_Attributes+16,y  ;second and third row left sprites
      ora #%01000000
      sta Sprite_Attributes+12,y  ;set, in addition to those, horizontal flip
      sta Sprite_Attributes+20,y  ;for second and third row right sprites

SprObjectOffscrChk:
         ldx ObjectOffset          ;get enemy buffer offset
         lda Enemy_OffscreenBits   ;check offscreen information
         lsr
         lsr                       ;shift three times to the right
         lsr                       ;which puts d2 into carry
         pha                       ;save to stack
         bcc LcChk                 ;branch if not set
         lda #$04                  ;set for right column sprites
         jsr MoveESprColOffscreen  ;and move them offscreen
LcChk:   pla                       ;get from stack
         lsr                       ;move d3 to carry
         pha                       ;save to stack
         bcc Row3C                 ;branch if not set
         lda #$00                  ;set for left column sprites,
         jsr MoveESprColOffscreen  ;move them offscreen
Row3C:   pla                       ;get from stack again
         lsr                       ;move d5 to carry this time
         lsr
         pha                       ;save to stack again
         bcc Row23C                ;branch if carry not set
         lda #$10                  ;set for third row of sprites
         jsr MoveESprRowOffscreen  ;and move them offscreen
Row23C:  pla                       ;get from stack
         lsr                       ;move d6 into carry
         pha                       ;save to stack
         bcc AllRowC
         lda #$08                  ;set for second and third rows
         jsr MoveESprRowOffscreen  ;move them offscreen
AllRowC: pla                       ;get from stack once more
         lsr                       ;move d7 into carry
         bcc ExEGHandler
         jsr MoveESprRowOffscreen  ;move all sprites offscreen (A should be 0 by now)
         lda Enemy_ID,x
         cmp #Podoboo              ;check enemy identifier for podoboo
         beq ExEGHandler           ;skip this part if found, we do not want to erase podoboo!
         lda Enemy_Y_HighPos,x     ;check high byte of vertical position
         cmp #$02                  ;if not yet past the bottom of the screen, branch
         bne ExEGHandler
         jsr EraseEnemyObject      ;what it says

ExEGHandler:
      rts

DrawEnemyObjRow:
      lda EnemyGraphicsTable,x    ;load two tiles of enemy graphics
      sta $00
      lda EnemyGraphicsTable+1,x

DrawOneSpriteRow:
      sta $01
      jmp DrawSpriteObject        ;draw them

MoveESprRowOffscreen:
      clc                         ;add A to enemy object OAM data offset
      adc Enemy_SprDataOffset,x
      tay                         ;use as offset
      lda #$f8
      jmp DumpTwoSpr              ;move first row of sprites offscreen

MoveESprColOffscreen:
      clc                         ;add A to enemy object OAM data offset
      adc Enemy_SprDataOffset,x
      tay                         ;use as offset
      jsr MoveColOffscreen        ;move first and second row sprites in column offscreen
      sta Sprite_Data+16,y        ;move third row sprite in column offscreen
      rts
