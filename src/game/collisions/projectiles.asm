; -------------------------------------------------------------------------------------
; $01 - enemy buffer offset

FireballEnemyCollision:
    LDA Fireball_State,x  ; check to see if fireball state is set at all
    BEQ ExitFBallEnemy  ; branch to leave if not
    ASL
    BCS ExitFBallEnemy  ; branch to leave also if d7 in state is set
    LDA FrameCounter
    LSR  ; get LSB of frame counter
    BCS ExitFBallEnemy  ; branch to leave if set (do routine every other frame)
    TXA
    ASL  ; multiply fireball offset by four
    ASL
    CLC
    ADC #$1c  ; then add $1c or 28 bytes to it
    TAY  ; to use fireball's bounding box coordinates
    LDX #$04

FireballEnemyCDLoop:
    STX $01  ; store enemy object offset here
    TYA
    PHA  ; push fireball offset to the stack
    LDA Enemy_State,x
    AND #%00100000  ; check to see if d5 is set in enemy state
    BNE NoFToECol  ; if so, skip to next enemy slot
    LDA Enemy_Flag,x  ; check to see if buffer flag is set
    BEQ NoFToECol  ; if not, skip to next enemy slot
    LDA Enemy_ID,x  ; check enemy identifier
    CMP #$24
    BCC GoombaDie  ; if < $24, branch to check further
    CMP #$2b
    BCC NoFToECol  ; if in range $24-$2a, skip to next enemy slot
GoombaDie:
    CMP #Goomba  ; check for goomba identifier
    BNE NotGoomba  ; if not found, continue with code
    LDA Enemy_State,x  ; otherwise check for defeated state
    CMP #$02  ; if stomped or otherwise defeated,
    BCS NoFToECol  ; skip to next enemy slot
NotGoomba:
    LDA EnemyOffscrBitsMasked,x  ; if any masked offscreen bits set,
    BNE NoFToECol  ; skip to next enemy slot
    TXA
    ASL  ; otherwise multiply enemy offset by four
    ASL
    CLC
    ADC #$04  ; add 4 bytes to it
    TAX  ; to use enemy's bounding box coordinates
    JSR SprObjectCollisionCore  ; do fireball-to-enemy collision detection
    LDX ObjectOffset  ; return fireball's original offset
    BCC NoFToECol  ; if carry clear, no collision, thus do next enemy slot
    LDA #%10000000
    STA Fireball_State,x  ; set d7 in enemy state
    LDX $01  ; get enemy offset
    JSR HandleEnemyFBallCol  ; jump to handle fireball to enemy collision
NoFToECol:
    PLA  ; pull fireball offset from stack
    TAY  ; put it in Y
    LDX $01  ; get enemy object offset
    DEX  ; decrement it
    BPL FireballEnemyCDLoop  ; loop back until collision detection done on all enemies

ExitFBallEnemy:
    LDX ObjectOffset  ; get original fireball offset and leave
    RTS

BowserIdentities:
    .byte Goomba, GreenKoopa, BuzzyBeetle, Spiny, Lakitu, Bloober, HammerBro, Bowser

HandleEnemyFBallCol:
    JSR RelativeEnemyPosition  ; get relative coordinate of enemy
    LDX $01  ; get current enemy object offset
    LDA Enemy_Flag,x  ; check buffer flag for d7 set
    BPL ChkBuzzyBeetle  ; branch if not set to continue
    AND #%00001111  ; otherwise mask out high nybble and
    TAX  ; use low nybble as enemy offset
    LDA Enemy_ID,x
    CMP #Bowser  ; check enemy identifier for bowser
    BEQ HurtBowser  ; branch if found
    LDX $01  ; otherwise retrieve current enemy offset

ChkBuzzyBeetle:
    LDA Enemy_ID,x
    CMP #BuzzyBeetle  ; check for buzzy beetle
    BEQ ExHCF  ; branch if found to leave (buzzy beetles fireproof)
    CMP #Bowser  ; check for bowser one more time (necessary if d7 of flag was clear)
    BNE ChkOtherEnemies  ; if not found, branch to check other enemies

HurtBowser:
    DEC BowserHitPoints  ; decrement bowser's hit points
    BNE ExHCF  ; if bowser still has hit points, branch to leave
    JSR InitVStf  ; otherwise do sub to init vertical speed and movement force
    STA Enemy_X_Speed,x  ; initialize horizontal speed
    STA EnemyFrenzyBuffer  ; init enemy frenzy buffer
    LDA #$fe
    STA Enemy_Y_Speed,x  ; set vertical speed to make defeated bowser jump a little
    LDY WorldNumber  ; use world number as offset
    LDA BowserIdentities,y  ; get enemy identifier to replace bowser with
    STA Enemy_ID,x  ; set as new enemy identifier
    LDA #$20  ; set A to use starting value for state
    CPY #$03  ; check to see if using offset of 3 or more
    BCS SetDBSte  ; branch if so
    ORA #$03  ; otherwise add 3 to enemy state
SetDBSte:
    STA Enemy_State,x  ; set defeated enemy state
    LDA #Sfx_BowserFall
    STA Square2SoundQueue  ; load bowser defeat sound
    LDX $01  ; get enemy offset
    LDA #$09  ; award 5000 points to player for defeating bowser
    BNE EnemySmackScore  ; unconditional branch to award points

ChkOtherEnemies:
    CMP #BulletBill_FrenzyVar
    BEQ ExHCF  ; branch to leave if bullet bill (frenzy variant)
    CMP #Podoboo
    BEQ ExHCF  ; branch to leave if podoboo
    CMP #$15
    BCS ExHCF  ; branch to leave if identifier => $15

ShellOrBlockDefeat:
    LDA Enemy_ID,x  ; check for piranha plant
    CMP #PiranhaPlant
    BNE StnE  ; branch if not found
    LDA Enemy_Y_Position,x
    ADC #$18  ; add 24 pixels to enemy object's vertical position
    STA Enemy_Y_Position,x
StnE:
    JSR ChkToStunEnemies  ; do yet another sub
    LDA Enemy_State,x
    AND #%00011111  ; mask out 2 MSB of enemy object's state
    ORA #%00100000  ; set d5 to defeat enemy and save as new state
    STA Enemy_State,x
    LDA #$02  ; award 200 points by default
    LDY Enemy_ID,x  ; check for hammer bro
    CPY #HammerBro
    BNE GoombaPoints  ; branch if not found
    LDA #$06  ; award 1000 points for hammer bro

GoombaPoints:
    CPY #Goomba  ; check for goomba
    BNE EnemySmackScore  ; branch if not found
    LDA #$01  ; award 100 points for goomba

EnemySmackScore:
    JSR SetupFloateyNumber  ; update necessary score variables
    LDA #Sfx_EnemySmack  ; play smack enemy sound
    STA Square1SoundQueue
ExHCF:
    RTS  ; and now let's leave

; -------------------------------------------------------------------------------------

PlayerHammerCollision:
    LDA FrameCounter  ; get frame counter
    LSR  ; shift d0 into carry
    BCC ExPHC  ; branch to leave if d0 not set to execute every other frame
    LDA TimerControl  ; if either master timer control
    ORA Misc_OffscreenBits  ; or any offscreen bits for hammer are set,
    BNE ExPHC  ; branch to leave
    TXA
    ASL  ; multiply misc object offset by four
    ASL
    CLC
    ADC #$24  ; add 36 or $24 bytes to get proper offset
    TAY  ; for misc object bounding box coordinates
    JSR PlayerCollisionCore  ; do player-to-hammer collision detection
    LDX ObjectOffset  ; get misc object offset
    BCC ClHCol  ; if no collision, then branch
    LDA Misc_Collision_Flag,x  ; otherwise read collision flag
    BNE ExPHC  ; if collision flag already set, branch to leave
    LDA #$01
    STA Misc_Collision_Flag,x  ; otherwise set collision flag now
    LDA Misc_X_Speed,x
    EOR #$ff  ; get two's compliment of
    CLC  ; hammer's horizontal speed
    ADC #$01
    STA Misc_X_Speed,x  ; set to send hammer flying the opposite direction
    LDA StarInvincibleTimer  ; if star mario invincibility timer set,
    BNE ExPHC  ; branch to leave
    JMP InjurePlayer  ; otherwise jump to hurt player, do not return
ClHCol:
    LDA #$00  ; clear collision flag
    STA Misc_Collision_Flag,x
ExPHC:
    RTS

; -------------------------------------------------------------------------------------

HandlePowerUpCollision:
    JSR EraseEnemyObject  ; erase the power-up object
    LDA #$06
    JSR SetupFloateyNumber  ; award 1000 points to player by default
    LDA #Sfx_PowerUpGrab
    STA Square2SoundQueue  ; play the power-up sound
    LDA PowerUpType  ; check power-up type
    CMP #$02
    BCC Shroom_Flower_PUp  ; if mushroom or fire flower, branch
    CMP #$03
    BEQ SetFor1Up  ; if 1-up mushroom, branch
    LDA #$23  ; otherwise set star mario invincibility
    STA StarInvincibleTimer  ; timer, and load the star mario music
    LDA #StarPowerMusic  ; into the area music queue, then leave
    STA AreaMusicQueue
    RTS

Shroom_Flower_PUp:
    LDA PlayerStatus  ; if player status = small, branch
    BEQ UpToSuper
    CMP #$01  ; if player status not super, leave
    BNE NoPUp
    LDX ObjectOffset  ; get enemy offset, not necessary
    LDA #$02  ; set player status to fiery
    STA PlayerStatus
    JSR GetPlayerColors  ; run sub to change colors of player
    LDX ObjectOffset  ; get enemy offset again, and again not necessary
    LDA #$0c  ; set value to be used by subroutine tree (fiery)
    JMP UpToFiery  ; jump to set values accordingly

SetFor1Up:
    LDA #$0b  ; change 1000 points into 1-up instead
    STA FloateyNum_Control,x  ; and then leave
    RTS

UpToSuper:
    LDA #$01  ; set player status to super
    STA PlayerStatus
    LDA #$09  ; set value to be used by subroutine tree (super)

UpToFiery:
    LDY #$00  ; set value to be used as new player state
    JSR SetPRout  ; set values to stop certain things in motion
NoPUp:
    RTS
