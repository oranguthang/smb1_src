;-------------------------------------------------------------------------------------
;$00 - used to store high nybble of horizontal speed as adder
;$01 - used to store low nybble of horizontal speed
;$02 - used to store adder to page location

MoveEnemyHorizontally:
      inx                         ;increment offset for enemy offset
      jsr MoveObjectHorizontally  ;position object horizontally according to
      ldx ObjectOffset            ;counters, return with saved value in A,
      rts                         ;put enemy offset back in X and leave

MovePlayerHorizontally:
      lda JumpspringAnimCtrl  ;if jumpspring currently animating,
      bne ExXMove             ;branch to leave
      tax                     ;otherwise set zero for offset to use player's stuff

MoveObjectHorizontally:
          lda SprObject_X_Speed,x     ;get currently saved value (horizontal
          asl                         ;speed, secondary counter, whatever)
          asl                         ;and move low nybble to high
          asl
          asl
          sta $01                     ;store result here
          lda SprObject_X_Speed,x     ;get saved value again
          lsr                         ;move high nybble to low
          lsr
          lsr
          lsr
          cmp #$08                    ;if < 8, branch, do not change
          bcc SaveXSpd
          ora #%11110000              ;otherwise alter high nybble
SaveXSpd: sta $00                     ;save result here
          ldy #$00                    ;load default Y value here
          cmp #$00                    ;if result positive, leave Y alone
          bpl UseAdder
          dey                         ;otherwise decrement Y
UseAdder: sty $02                     ;save Y here
          lda SprObject_X_MoveForce,x ;get whatever number's here
          clc
          adc $01                     ;add low nybble moved to high
          sta SprObject_X_MoveForce,x ;store result here
          lda #$00                    ;init A
          rol                         ;rotate carry into d0
          pha                         ;push onto stack
          ror                         ;rotate d0 back onto carry
          lda SprObject_X_Position,x
          adc $00                     ;add carry plus saved value (high nybble moved to low
          sta SprObject_X_Position,x  ;plus $f0 if necessary) to object's horizontal position
          lda SprObject_PageLoc,x
          adc $02                     ;add carry plus other saved value to the
          sta SprObject_PageLoc,x     ;object's page location and save
          pla
          clc                         ;pull old carry from stack and add
          adc $00                     ;to high nybble moved to low
ExXMove:  rts                         ;and leave

;-------------------------------------------------------------------------------------
;$00 - used for downward force
;$01 - used for upward force
;$02 - used for maximum vertical speed

MovePlayerVertically:
         ldx #$00                ;set X for player offset
         lda TimerControl
         bne NoJSChk             ;if master timer control set, branch ahead
         lda JumpspringAnimCtrl  ;otherwise check to see if jumpspring is animating
         bne ExXMove             ;branch to leave if so
NoJSChk: lda VerticalForce       ;dump vertical force
         sta $00
         lda #$04                ;set maximum vertical speed here
         jmp ImposeGravitySprObj ;then jump to move player vertically

;--------------------------------

MoveD_EnemyVertically:
      ldy #$3d           ;set quick movement amount downwards
      lda Enemy_State,x  ;then check enemy state
      cmp #$05           ;if not set to unique state for spiny's egg, go ahead
      bne ContVMove      ;and use, otherwise set different movement amount, continue on

MoveFallingPlatform:
           ldy #$20       ;set movement amount
ContVMove: jmp SetHiMax   ;jump to skip the rest of this

;--------------------------------

MoveRedPTroopaDown:
      ldy #$00            ;set Y to move downwards
      jmp MoveRedPTroopa  ;skip to movement routine

MoveRedPTroopaUp:
      ldy #$01            ;set Y to move upwards

MoveRedPTroopa:
      inx                 ;increment X for enemy offset
      lda #$03
      sta $00             ;set downward movement amount here
      lda #$06
      sta $01             ;set upward movement amount here
      lda #$02
      sta $02             ;set maximum speed here
      tya                 ;set movement direction in A, and
      jmp RedPTroopaGrav  ;jump to move this thing

;--------------------------------

MoveDropPlatform:
      ldy #$7f      ;set movement amount for drop platform
      bne SetMdMax  ;skip ahead of other value set here

MoveEnemySlowVert:
          ldy #$0f         ;set movement amount for bowser/other objects
SetMdMax: lda #$02         ;set maximum speed in A
          bne SetXMoveAmt  ;unconditional branch

;--------------------------------

MoveJ_EnemyVertically:
             ldy #$1c                ;set movement amount for podoboo/other objects
SetHiMax:    lda #$03                ;set maximum speed in A
SetXMoveAmt: sty $00                 ;set movement amount here
             inx                     ;increment X for enemy offset
             jsr ImposeGravitySprObj ;do a sub to move enemy object downwards
             ldx ObjectOffset        ;get enemy object buffer offset and leave
             rts

;--------------------------------

MaxSpdBlockData:
      .byte $06, $08

ResidualGravityCode:
      ldy #$00       ;this part appears to be residual,
      .byte $2c        ;no code branches or jumps to it...

ImposeGravityBlock:
      ldy #$01       ;set offset for maximum speed
      lda #$50       ;set movement amount here
      sta $00
      lda MaxSpdBlockData,y    ;get maximum speed

ImposeGravitySprObj:
      sta $02            ;set maximum speed here
      lda #$00           ;set value to move downwards
      jmp ImposeGravity  ;jump to the code that actually moves it

;--------------------------------

MovePlatformDown:
      lda #$00    ;save value to stack (if branching here, execute next
      .byte $2c     ;part as BIT instruction)

MovePlatformUp:
           lda #$01        ;save value to stack
           pha
           ldy Enemy_ID,x  ;get enemy object identifier
           inx             ;increment offset for enemy object
           lda #$05        ;load default value here
           cpy #$29        ;residual comparison, object #29 never executes
           bne SetDplSpd   ;this code, thus unconditional branch here
           lda #$09        ;residual code
SetDplSpd: sta $00         ;save downward movement amount here
           lda #$0a        ;save upward movement amount here
           sta $01
           lda #$03        ;save maximum vertical speed here
           sta $02
           pla             ;get value from stack
           tay             ;use as Y, then move onto code shared by red koopa

RedPTroopaGrav:
      jsr ImposeGravity  ;do a sub to move object gradually
      ldx ObjectOffset   ;get enemy object offset and leave
      rts

;-------------------------------------------------------------------------------------
;$00 - used for downward force
;$01 - used for upward force
;$07 - used as adder for vertical position

ImposeGravity:
         pha                          ;push value to stack
         lda SprObject_YMF_Dummy,x
         clc                          ;add value in movement force to contents of dummy variable
         adc SprObject_Y_MoveForce,x
         sta SprObject_YMF_Dummy,x
         ldy #$00                     ;set Y to zero by default
         lda SprObject_Y_Speed,x      ;get current vertical speed
         bpl AlterYP                  ;if currently moving downwards, do not decrement Y
         dey                          ;otherwise decrement Y
AlterYP: sty $07                      ;store Y here
         adc SprObject_Y_Position,x   ;add vertical position to vertical speed plus carry
         sta SprObject_Y_Position,x   ;store as new vertical position
         lda SprObject_Y_HighPos,x
         adc $07                      ;add carry plus contents of $07 to vertical high byte
         sta SprObject_Y_HighPos,x    ;store as new vertical high byte
         lda SprObject_Y_MoveForce,x
         clc
         adc $00                      ;add downward movement amount to contents of $0433
         sta SprObject_Y_MoveForce,x
         lda SprObject_Y_Speed,x      ;add carry to vertical speed and store
         adc #$00
         sta SprObject_Y_Speed,x
         cmp $02                      ;compare to maximum speed
         bmi ChkUpM                   ;if less than preset value, skip this part
         lda SprObject_Y_MoveForce,x
         cmp #$80                     ;if less positively than preset maximum, skip this part
         bcc ChkUpM
         lda $02
         sta SprObject_Y_Speed,x      ;keep vertical speed within maximum value
         lda #$00
         sta SprObject_Y_MoveForce,x  ;clear fractional
ChkUpM:  pla                          ;get value from stack
         beq ExVMove                  ;if set to zero, branch to leave
         lda $02
         eor #%11111111               ;otherwise get two's compliment of maximum speed
         tay
         iny
         sty $07                      ;store two's compliment here
         lda SprObject_Y_MoveForce,x
         sec                          ;subtract upward movement amount from contents
         sbc $01                      ;of movement force, note that $01 is twice as large as $00,
         sta SprObject_Y_MoveForce,x  ;thus it effectively undoes add we did earlier
         lda SprObject_Y_Speed,x
         sbc #$00                     ;subtract borrow from vertical speed and store
         sta SprObject_Y_Speed,x
         cmp $07                      ;compare vertical speed to two's compliment
         bpl ExVMove                  ;if less negatively than preset maximum, skip this part
         lda SprObject_Y_MoveForce,x
         cmp #$80                     ;check if fractional part is above certain amount,
         bcs ExVMove                  ;and if so, branch to leave
         lda $07
         sta SprObject_Y_Speed,x      ;keep vertical speed within maximum value
         lda #$ff
         sta SprObject_Y_MoveForce,x  ;clear fractional
ExVMove: rts                          ;leave!
