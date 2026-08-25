;-------------------------------------------------------------------------------------
;$01 - enemy buffer offset

FireballEnemyCollision:
      lda Fireball_State,x  ;check to see if fireball state is set at all
      beq ExitFBallEnemy    ;branch to leave if not
      asl
      bcs ExitFBallEnemy    ;branch to leave also if d7 in state is set
      lda FrameCounter
      lsr                   ;get LSB of frame counter
      bcs ExitFBallEnemy    ;branch to leave if set (do routine every other frame)
      txa
      asl                   ;multiply fireball offset by four
      asl
      clc
      adc #$1c              ;then add $1c or 28 bytes to it
      tay                   ;to use fireball's bounding box coordinates
      ldx #$04

FireballEnemyCDLoop:
           stx $01                     ;store enemy object offset here
           tya
           pha                         ;push fireball offset to the stack
           lda Enemy_State,x
           and #%00100000              ;check to see if d5 is set in enemy state
           bne NoFToECol               ;if so, skip to next enemy slot
           lda Enemy_Flag,x            ;check to see if buffer flag is set
           beq NoFToECol               ;if not, skip to next enemy slot
           lda Enemy_ID,x              ;check enemy identifier
           cmp #$24
           bcc GoombaDie               ;if < $24, branch to check further
           cmp #$2b
           bcc NoFToECol               ;if in range $24-$2a, skip to next enemy slot
GoombaDie: cmp #Goomba                 ;check for goomba identifier
           bne NotGoomba               ;if not found, continue with code
           lda Enemy_State,x           ;otherwise check for defeated state
           cmp #$02                    ;if stomped or otherwise defeated,
           bcs NoFToECol               ;skip to next enemy slot
NotGoomba: lda EnemyOffscrBitsMasked,x ;if any masked offscreen bits set,
           bne NoFToECol               ;skip to next enemy slot
           txa
           asl                         ;otherwise multiply enemy offset by four
           asl
           clc
           adc #$04                    ;add 4 bytes to it
           tax                         ;to use enemy's bounding box coordinates
           jsr SprObjectCollisionCore  ;do fireball-to-enemy collision detection
           ldx ObjectOffset            ;return fireball's original offset
           bcc NoFToECol               ;if carry clear, no collision, thus do next enemy slot
           lda #%10000000
           sta Fireball_State,x        ;set d7 in enemy state
           ldx $01                     ;get enemy offset
           jsr HandleEnemyFBallCol     ;jump to handle fireball to enemy collision
NoFToECol: pla                         ;pull fireball offset from stack
           tay                         ;put it in Y
           ldx $01                     ;get enemy object offset
           dex                         ;decrement it
           bpl FireballEnemyCDLoop     ;loop back until collision detection done on all enemies

ExitFBallEnemy:
      ldx ObjectOffset                 ;get original fireball offset and leave
      rts

BowserIdentities:
      .byte Goomba, GreenKoopa, BuzzyBeetle, Spiny, Lakitu, Bloober, HammerBro, Bowser

HandleEnemyFBallCol:
      jsr RelativeEnemyPosition  ;get relative coordinate of enemy
      ldx $01                    ;get current enemy object offset
      lda Enemy_Flag,x           ;check buffer flag for d7 set
      bpl ChkBuzzyBeetle         ;branch if not set to continue
      and #%00001111             ;otherwise mask out high nybble and
      tax                        ;use low nybble as enemy offset
      lda Enemy_ID,x
      cmp #Bowser                ;check enemy identifier for bowser
      beq HurtBowser             ;branch if found
      ldx $01                    ;otherwise retrieve current enemy offset

ChkBuzzyBeetle:
      lda Enemy_ID,x
      cmp #BuzzyBeetle           ;check for buzzy beetle
      beq ExHCF                  ;branch if found to leave (buzzy beetles fireproof)
      cmp #Bowser                ;check for bowser one more time (necessary if d7 of flag was clear)
      bne ChkOtherEnemies        ;if not found, branch to check other enemies

HurtBowser:
          dec BowserHitPoints        ;decrement bowser's hit points
          bne ExHCF                  ;if bowser still has hit points, branch to leave
          jsr InitVStf               ;otherwise do sub to init vertical speed and movement force
          sta Enemy_X_Speed,x        ;initialize horizontal speed
          sta EnemyFrenzyBuffer      ;init enemy frenzy buffer
          lda #$fe
          sta Enemy_Y_Speed,x        ;set vertical speed to make defeated bowser jump a little
          ldy WorldNumber            ;use world number as offset
          lda BowserIdentities,y     ;get enemy identifier to replace bowser with
          sta Enemy_ID,x             ;set as new enemy identifier
          lda #$20                   ;set A to use starting value for state
          cpy #$03                   ;check to see if using offset of 3 or more
          bcs SetDBSte               ;branch if so
          ora #$03                   ;otherwise add 3 to enemy state
SetDBSte: sta Enemy_State,x          ;set defeated enemy state
          lda #Sfx_BowserFall
          sta Square2SoundQueue      ;load bowser defeat sound
          ldx $01                    ;get enemy offset
          lda #$09                   ;award 5000 points to player for defeating bowser
          bne EnemySmackScore        ;unconditional branch to award points

ChkOtherEnemies:
      cmp #BulletBill_FrenzyVar
      beq ExHCF                 ;branch to leave if bullet bill (frenzy variant)
      cmp #Podoboo
      beq ExHCF                 ;branch to leave if podoboo
      cmp #$15
      bcs ExHCF                 ;branch to leave if identifier => $15

ShellOrBlockDefeat:
      lda Enemy_ID,x            ;check for piranha plant
      cmp #PiranhaPlant
      bne StnE                  ;branch if not found
      lda Enemy_Y_Position,x
      adc #$18                  ;add 24 pixels to enemy object's vertical position
      sta Enemy_Y_Position,x
StnE: jsr ChkToStunEnemies      ;do yet another sub
      lda Enemy_State,x
      and #%00011111            ;mask out 2 MSB of enemy object's state
      ora #%00100000            ;set d5 to defeat enemy and save as new state
      sta Enemy_State,x
      lda #$02                  ;award 200 points by default
      ldy Enemy_ID,x            ;check for hammer bro
      cpy #HammerBro
      bne GoombaPoints          ;branch if not found
      lda #$06                  ;award 1000 points for hammer bro

GoombaPoints:
      cpy #Goomba               ;check for goomba
      bne EnemySmackScore       ;branch if not found
      lda #$01                  ;award 100 points for goomba

EnemySmackScore:
       jsr SetupFloateyNumber   ;update necessary score variables
       lda #Sfx_EnemySmack      ;play smack enemy sound
       sta Square1SoundQueue
ExHCF: rts                      ;and now let's leave

;-------------------------------------------------------------------------------------

PlayerHammerCollision:
        lda FrameCounter          ;get frame counter
        lsr                       ;shift d0 into carry
        bcc ExPHC                 ;branch to leave if d0 not set to execute every other frame
        lda TimerControl          ;if either master timer control
        ora Misc_OffscreenBits    ;or any offscreen bits for hammer are set,
        bne ExPHC                 ;branch to leave
        txa
        asl                       ;multiply misc object offset by four
        asl
        clc
        adc #$24                  ;add 36 or $24 bytes to get proper offset
        tay                       ;for misc object bounding box coordinates
        jsr PlayerCollisionCore   ;do player-to-hammer collision detection
        ldx ObjectOffset          ;get misc object offset
        bcc ClHCol                ;if no collision, then branch
        lda Misc_Collision_Flag,x ;otherwise read collision flag
        bne ExPHC                 ;if collision flag already set, branch to leave
        lda #$01
        sta Misc_Collision_Flag,x ;otherwise set collision flag now
        lda Misc_X_Speed,x
        eor #$ff                  ;get two's compliment of
        clc                       ;hammer's horizontal speed
        adc #$01
        sta Misc_X_Speed,x        ;set to send hammer flying the opposite direction
        lda StarInvincibleTimer   ;if star mario invincibility timer set,
        bne ExPHC                 ;branch to leave
        jmp InjurePlayer          ;otherwise jump to hurt player, do not return
ClHCol: lda #$00                  ;clear collision flag
        sta Misc_Collision_Flag,x
ExPHC:  rts

;-------------------------------------------------------------------------------------

HandlePowerUpCollision:
      jsr EraseEnemyObject    ;erase the power-up object
      lda #$06
      jsr SetupFloateyNumber  ;award 1000 points to player by default
      lda #Sfx_PowerUpGrab
      sta Square2SoundQueue   ;play the power-up sound
      lda PowerUpType         ;check power-up type
      cmp #$02
      bcc Shroom_Flower_PUp   ;if mushroom or fire flower, branch
      cmp #$03
      beq SetFor1Up           ;if 1-up mushroom, branch
      lda #$23                ;otherwise set star mario invincibility
      sta StarInvincibleTimer ;timer, and load the star mario music
      lda #StarPowerMusic     ;into the area music queue, then leave
      sta AreaMusicQueue
      rts

Shroom_Flower_PUp:
      lda PlayerStatus    ;if player status = small, branch
      beq UpToSuper
      cmp #$01            ;if player status not super, leave
      bne NoPUp
      ldx ObjectOffset    ;get enemy offset, not necessary
      lda #$02            ;set player status to fiery
      sta PlayerStatus
      jsr GetPlayerColors ;run sub to change colors of player
      ldx ObjectOffset    ;get enemy offset again, and again not necessary
      lda #$0c            ;set value to be used by subroutine tree (fiery)
      jmp UpToFiery       ;jump to set values accordingly

SetFor1Up:
      lda #$0b                 ;change 1000 points into 1-up instead
      sta FloateyNum_Control,x ;and then leave
      rts

UpToSuper:
       lda #$01         ;set player status to super
       sta PlayerStatus
       lda #$09         ;set value to be used by subroutine tree (super)

UpToFiery:
       ldy #$00         ;set value to be used as new player state
       jsr SetPRout     ;set values to stop certain things in motion
NoPUp: rts
