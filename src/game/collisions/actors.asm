; --------------------------------

ResidualXSpdData:
    .byte $18, $e8

KickedShellXSpdData:
    .byte $30, $d0

DemotedKoopaXSpdData:
    .byte $08, $f8

PlayerEnemyCollision:
    LDA FrameCounter  ; check counter for d0 set
    LSR
    BCS NoPUp  ; if set, branch to leave
    JSR CheckPlayerVertical  ; if player object is completely offscreen or
    BCS NoPECol  ; if down past 224th pixel row, branch to leave
    LDA EnemyOffscrBitsMasked,x  ; if current enemy is offscreen by any amount,
    BNE NoPECol  ; go ahead and branch to leave
    LDA GameEngineSubroutine
    CMP #$08  ; if not set to run player control routine
    BNE NoPECol  ; on next frame, branch to leave
    LDA Enemy_State,x
    AND #%00100000  ; if enemy state has d5 set, branch to leave
    BNE NoPECol
    JSR GetEnemyBoundBoxOfs  ; get bounding box offset for current enemy object
    JSR PlayerCollisionCore  ; do collision detection on player vs. enemy
    LDX ObjectOffset  ; get enemy object buffer offset
    BCS CheckForPUpCollision  ; if collision, branch past this part here
    LDA Enemy_CollisionBits,x
    AND #%11111110  ; otherwise, clear d0 of current enemy object's
    STA Enemy_CollisionBits,x  ; collision bit
NoPECol:
    RTS

CheckForPUpCollision:
    LDY Enemy_ID,x
    CPY #PowerUpObject  ; check for power-up object
    BNE EColl  ; if not found, branch to next part
    JMP HandlePowerUpCollision  ; otherwise, unconditional jump backwards
EColl:
    LDA StarInvincibleTimer  ; if star mario invincibility timer expired,
    BEQ HandlePECollisions  ; perform task here, otherwise kill enemy like
    JMP ShellOrBlockDefeat  ; hit with a shell, or from beneath

KickedShellPtsData:
    .byte $0a, $06, $04

HandlePECollisions:
    LDA Enemy_CollisionBits,x  ; check enemy collision bits for d0 set
    AND #%00000001  ; or for being offscreen at all
    ORA EnemyOffscrBitsMasked,x
    BNE ExPEC  ; branch to leave if either is true
    LDA #$01
    ORA Enemy_CollisionBits,x  ; otherwise set d0 now
    STA Enemy_CollisionBits,x
    CPY #Spiny  ; branch if spiny
    BEQ ChkForPlayerInjury
    CPY #PiranhaPlant  ; branch if piranha plant
    BEQ InjurePlayer
    CPY #Podoboo  ; branch if podoboo
    BEQ InjurePlayer
    CPY #BulletBill_CannonVar  ; branch if bullet bill
    BEQ ChkForPlayerInjury
    CPY #$15  ; branch if object => $15
    BCS InjurePlayer
    LDA AreaType  ; branch if water type level
    BEQ InjurePlayer
    LDA Enemy_State,x  ; branch if d7 of enemy state was set
    ASL
    BCS ChkForPlayerInjury
    LDA Enemy_State,x  ; mask out all but 3 LSB of enemy state
    AND #%00000111
    CMP #$02  ; branch if enemy is in normal or falling state
    BCC ChkForPlayerInjury
    LDA Enemy_ID,x  ; branch to leave if goomba in defeated state
    CMP #Goomba
    BEQ ExPEC
    LDA #Sfx_EnemySmack  ; play smack enemy sound
    STA Square1SoundQueue
    LDA Enemy_State,x  ; set d7 in enemy state, thus become moving shell
    ORA #%10000000
    STA Enemy_State,x
    JSR EnemyFacePlayer  ; set moving direction and get offset
    LDA KickedShellXSpdData,y  ; load and set horizontal speed data with offset
    STA Enemy_X_Speed,x
    LDA #$03  ; add three to whatever the stomp counter contains
    CLC  ; to give points for kicking the shell
    ADC StompChainCounter
    LDY EnemyIntervalTimer,x  ; check shell enemy's timer
    CPY #$03  ; if above a certain point, branch using the points
    BCS KSPts  ; data obtained from the stomp counter + 3
    LDA KickedShellPtsData,y  ; otherwise, set points based on proximity to timer expiration
KSPts:
    JSR SetupFloateyNumber  ; set values for floatey number now
ExPEC:
    RTS  ; leave!!!

ChkForPlayerInjury:
    LDA Player_Y_Speed  ; check player's vertical speed
    BMI ChkInj  ; perform procedure below if player moving upwards
    BNE EnemyStomped  ; or not at all, and branch elsewhere if moving downwards
ChkInj:
    LDA Enemy_ID,x  ; branch if enemy object < $07
    CMP #Bloober
    BCC ChkETmrs
    LDA Player_Y_Position  ; add 12 pixels to player's vertical position
    CLC
    ADC #$0c
    CMP Enemy_Y_Position,x  ; compare modified player's position to enemy's position
    BCC EnemyStomped  ; branch if this player's position above (less than) enemy's
ChkETmrs:
    LDA StompTimer  ; check stomp timer
    BNE EnemyStomped  ; branch if set
    LDA InjuryTimer  ; check to see if injured invincibility timer still
    BNE ExInjColRoutines  ; counting down, and branch elsewhere to leave if so
    LDA Player_Rel_XPos
    CMP Enemy_Rel_XPos  ; if player's relative position to the left of enemy's
    BCC TInjE  ; relative position, branch here
    JMP ChkEnemyFaceRight  ; otherwise do a jump here
TInjE:
    LDA Enemy_MovingDir,x  ; if enemy moving towards the left,
    CMP #$01  ; branch, otherwise do a jump here
    BNE InjurePlayer  ; to turn the enemy around
    JMP LInj

InjurePlayer:
    LDA InjuryTimer  ; check again to see if injured invincibility timer is
    BNE ExInjColRoutines  ; at zero, and branch to leave if so

ForceInjury:
    LDX PlayerStatus  ; check player's status
    BEQ KillPlayer  ; branch if small
    STA PlayerStatus  ; otherwise set player's status to small
    LDA #$08
    STA InjuryTimer  ; set injured invincibility timer
    ASL
    STA Square1SoundQueue  ; play pipedown/injury sound
    JSR GetPlayerColors  ; change player's palette if necessary
    LDA #$0a  ; set subroutine to run on next frame
SetKRout:
    LDY #$01  ; set new player state
SetPRout:
    STA GameEngineSubroutine  ; load new value to run subroutine on next frame
    STY Player_State  ; store new player state
    LDY #$ff
    STY TimerControl  ; set master timer control flag to halt timers
    INY
    STY ScrollAmount  ; initialize scroll speed

ExInjColRoutines:
    LDX ObjectOffset  ; get enemy offset and leave
    RTS

KillPlayer:
    STX Player_X_Speed  ; halt player's horizontal movement by initializing speed
    INX
    STX EventMusicQueue  ; set event music queue to death music
    LDA #$fc
    STA Player_Y_Speed  ; set new vertical speed
    LDA #$0b  ; set subroutine to run on next frame
    BNE SetKRout  ; branch to set player's state and other things

StompedEnemyPtsData:
    .byte $02, $06, $05, $06

EnemyStomped:
    LDA Enemy_ID,x  ; check for spiny, branch to hurt player
    CMP #Spiny  ; if found
    BEQ InjurePlayer
    LDA #Sfx_EnemyStomp  ; otherwise play stomp/swim sound
    STA Square1SoundQueue
    LDA Enemy_ID,x
    LDY #$00  ; initialize points data offset for stomped enemies
    CMP #FlyingCheepCheep  ; branch for cheep-cheep
    BEQ EnemyStompedPts
    CMP #BulletBill_FrenzyVar  ; branch for either bullet bill object
    BEQ EnemyStompedPts
    CMP #BulletBill_CannonVar
    BEQ EnemyStompedPts
    CMP #Podoboo  ; branch for podoboo (this branch is logically impossible
    BEQ EnemyStompedPts  ; for cpu to take due to earlier checking of podoboo)
    INY  ; increment points data offset
    CMP #HammerBro  ; branch for hammer bro
    BEQ EnemyStompedPts
    INY  ; increment points data offset
    CMP #Lakitu  ; branch for lakitu
    BEQ EnemyStompedPts
    INY  ; increment points data offset
    CMP #Bloober  ; branch if NOT bloober
    BNE ChkForDemoteKoopa

EnemyStompedPts:
    LDA StompedEnemyPtsData,y  ; load points data using offset in Y
    JSR SetupFloateyNumber  ; run sub to set floatey number controls
    LDA Enemy_MovingDir,x
    PHA  ; save enemy movement direction to stack
    JSR SetStun  ; run sub to kill enemy
    PLA
    STA Enemy_MovingDir,x  ; return enemy movement direction from stack
    LDA #%00100000
    STA Enemy_State,x  ; set d5 in enemy state
    JSR InitVStf  ; nullify vertical speed, physics-related thing,
    STA Enemy_X_Speed,x  ; and horizontal speed
    LDA #$fd  ; set player's vertical speed, to give bounce
    STA Player_Y_Speed
    RTS

ChkForDemoteKoopa:
    CMP #$09  ; branch elsewhere if enemy object < $09
    BCC HandleStompedShellE
    AND #%00000001  ; demote koopa paratroopas to ordinary troopas
    STA Enemy_ID,x
    LDY #$00  ; return enemy to normal state
    STY Enemy_State,x
    LDA #$03  ; award 400 points to the player
    JSR SetupFloateyNumber
    JSR InitVStf  ; nullify physics-related thing and vertical speed
    JSR EnemyFacePlayer  ; turn enemy around if necessary
    LDA DemotedKoopaXSpdData,y
    STA Enemy_X_Speed,x  ; set appropriate moving speed based on direction
    JMP SBnce  ; then move onto something else

RevivalRateData:
    .byte $10, $0b

HandleStompedShellE:
    LDA #$04  ; set defeated state for enemy
    STA Enemy_State,x
    INC StompChainCounter  ; increment the stomp counter
    LDA StompChainCounter  ; add whatever is in the stomp counter
    CLC  ; to whatever is in the stomp timer
    ADC StompTimer
    JSR SetupFloateyNumber  ; award points accordingly
    INC StompTimer  ; increment stomp timer of some sort
    LDY PrimaryHardMode  ; check primary hard mode flag
    LDA RevivalRateData,y  ; load timer setting according to flag
    STA EnemyIntervalTimer,x  ; set as enemy timer to revive stomped enemy
SBnce:
    LDA #$fc  ; set player's vertical speed for bounce
    STA Player_Y_Speed  ; and then leave!!!
    RTS

ChkEnemyFaceRight:
    LDA Enemy_MovingDir,x  ; check to see if enemy is moving to the right
    CMP #$01
    BNE LInj  ; if not, branch
    JMP InjurePlayer  ; otherwise go back to hurt player
LInj:
    JSR EnemyTurnAround  ; turn the enemy around, if necessary
    JMP InjurePlayer  ; go back to hurt player

EnemyFacePlayer:
    LDY #$01  ; set to move right by default
    JSR PlayerEnemyDiff  ; get horizontal difference between player and enemy
    BPL SFcRt  ; if enemy is to the right of player, do not increment
    INY  ; otherwise, increment to set to move to the left
SFcRt:
    STY Enemy_MovingDir,x  ; set moving direction here
    DEY  ; then decrement to use as a proper offset
    RTS

SetupFloateyNumber:
    STA FloateyNum_Control,x  ; set number of points control for floatey numbers
    LDA #$30
    STA FloateyNum_Timer,x  ; set timer for floatey numbers
    LDA Enemy_Y_Position,x
    STA FloateyNum_Y_Pos,x  ; set vertical coordinate
    LDA Enemy_Rel_XPos
    STA FloateyNum_X_Pos,x  ; set horizontal coordinate and leave
ExSFN:
    RTS

; -------------------------------------------------------------------------------------
; $01 - used to hold enemy offset for second enemy

SetBitsMask:
    .byte %10000000, %01000000, %00100000, %00010000, %00001000, %00000100, %00000010

ClearBitsMask:
    .byte %01111111, %10111111, %11011111, %11101111, %11110111, %11111011, %11111101

EnemiesCollision:
    LDA FrameCounter  ; check counter for d0 set
    LSR
    BCC ExSFN  ; if d0 not set, leave
    LDA AreaType
    BEQ ExSFN  ; if water area type, leave
    LDA Enemy_ID,x
    CMP #$15  ; if enemy object => $15, branch to leave
    BCS ExitECRoutine
    CMP #Lakitu  ; if lakitu, branch to leave
    BEQ ExitECRoutine
    CMP #PiranhaPlant  ; if piranha plant, branch to leave
    BEQ ExitECRoutine
    LDA EnemyOffscrBitsMasked,x  ; if masked offscreen bits nonzero, branch to leave
    BNE ExitECRoutine
    JSR GetEnemyBoundBoxOfs  ; otherwise, do sub, get appropriate bounding box offset for
    DEX  ; first enemy we're going to compare, then decrement for second
    BMI ExitECRoutine  ; branch to leave if there are no other enemies
ECLoop:
    STX $01  ; save enemy object buffer offset for second enemy here
    TYA  ; save first enemy's bounding box offset to stack
    PHA
    LDA Enemy_Flag,x  ; check enemy object enable flag
    BEQ ReadyNextEnemy  ; branch if flag not set
    LDA Enemy_ID,x
    CMP #$15  ; check for enemy object => $15
    BCS ReadyNextEnemy  ; branch if true
    CMP #Lakitu
    BEQ ReadyNextEnemy  ; branch if enemy object is lakitu
    CMP #PiranhaPlant
    BEQ ReadyNextEnemy  ; branch if enemy object is piranha plant
    LDA EnemyOffscrBitsMasked,x
    BNE ReadyNextEnemy  ; branch if masked offscreen bits set
    TXA  ; get second enemy object's bounding box offset
    ASL  ; multiply by four, then add four
    ASL
    CLC
    ADC #$04
    TAX  ; use as new contents of X
    JSR SprObjectCollisionCore  ; do collision detection using the two enemies here
    LDX ObjectOffset  ; use first enemy offset for X
    LDY $01  ; use second enemy offset for Y
    BCC NoEnemyCollision  ; if carry clear, no collision, branch ahead of this
    LDA Enemy_State,x
    ORA Enemy_State,y  ; check both enemy states for d7 set
    AND #%10000000
    BNE YesEC  ; branch if at least one of them is set
    LDA Enemy_CollisionBits,y  ; load first enemy's collision-related bits
    AND SetBitsMask,x  ; check to see if bit connected to second enemy is
    BNE ReadyNextEnemy  ; already set, and move onto next enemy slot if set
    LDA Enemy_CollisionBits,y
    ORA SetBitsMask,x  ; if the bit is not set, set it now
    STA Enemy_CollisionBits,y
YesEC:
    JSR ProcEnemyCollisions  ; react according to the nature of collision
    JMP ReadyNextEnemy  ; move onto next enemy slot

NoEnemyCollision:
    LDA Enemy_CollisionBits,y  ; load first enemy's collision-related bits
    AND ClearBitsMask,x  ; clear bit connected to second enemy
    STA Enemy_CollisionBits,y  ; then move onto next enemy slot

ReadyNextEnemy:
    PLA  ; get first enemy's bounding box offset from the stack
    TAY  ; use as Y again
    LDX $01  ; get and decrement second enemy's object buffer offset
    DEX
    BPL ECLoop  ; loop until all enemy slots have been checked

ExitECRoutine:
    LDX ObjectOffset  ; get enemy object buffer offset
    RTS  ; leave

ProcEnemyCollisions:
    LDA Enemy_State,y  ; check both enemy states for d5 set
    ORA Enemy_State,x
    AND #%00100000  ; if d5 is set in either state, or both, branch
    BNE ExitProcessEColl  ; to leave and do nothing else at this point
    LDA Enemy_State,x
    CMP #$06  ; if second enemy state < $06, branch elsewhere
    BCC ProcSecondEnemyColl
    LDA Enemy_ID,x  ; check second enemy identifier for hammer bro
    CMP #HammerBro  ; if hammer bro found in alt state, branch to leave
    BEQ ExitProcessEColl
    LDA Enemy_State,y  ; check first enemy state for d7 set
    ASL
    BCC ShellCollisions  ; branch if d7 is clear
    LDA #$06
    JSR SetupFloateyNumber  ; award 1000 points for killing enemy
    JSR ShellOrBlockDefeat  ; then kill enemy, then load
    LDY $01  ; original offset of second enemy

ShellCollisions:
    TYA  ; move Y to X
    TAX
    JSR ShellOrBlockDefeat  ; kill second enemy
    LDX ObjectOffset
    LDA ShellChainCounter,x  ; get chain counter for shell
    CLC
    ADC #$04  ; add four to get appropriate point offset
    LDX $01
    JSR SetupFloateyNumber  ; award appropriate number of points for second enemy
    LDX ObjectOffset  ; load original offset of first enemy
    INC ShellChainCounter,x  ; increment chain counter for additional enemies

ExitProcessEColl:
    RTS  ; leave!!!

ProcSecondEnemyColl:
    LDA Enemy_State,y  ; if first enemy state < $06, branch elsewhere
    CMP #$06
    BCC MoveEOfs
    LDA Enemy_ID,y  ; check first enemy identifier for hammer bro
    CMP #HammerBro  ; if hammer bro found in alt state, branch to leave
    BEQ ExitProcessEColl
    JSR ShellOrBlockDefeat  ; otherwise, kill first enemy
    LDY $01
    LDA ShellChainCounter,y  ; get chain counter for shell
    CLC
    ADC #$04  ; add four to get appropriate point offset
    LDX ObjectOffset
    JSR SetupFloateyNumber  ; award appropriate number of points for first enemy
    LDX $01  ; load original offset of second enemy
    INC ShellChainCounter,x  ; increment chain counter for additional enemies
    RTS  ; leave!!!

MoveEOfs:
    TYA  ; move Y ($01) to X
    TAX
    JSR EnemyTurnAround  ; do the sub here using value from $01
    LDX ObjectOffset  ; then do it again using value from $08

EnemyTurnAround:
    LDA Enemy_ID,x  ; check for specific enemies
    CMP #PiranhaPlant
    BEQ ExTA  ; if piranha plant, leave
    CMP #Lakitu
    BEQ ExTA  ; if lakitu, leave
    CMP #HammerBro
    BEQ ExTA  ; if hammer bro, leave
    CMP #Spiny
    BEQ RXSpd  ; if spiny, turn it around
    CMP #GreenParatroopaJump
    BEQ RXSpd  ; if green paratroopa, turn it around
    CMP #$07
    BCS ExTA  ; if any OTHER enemy object => $07, leave
RXSpd:
    LDA Enemy_X_Speed,x  ; load horizontal speed
    EOR #$ff  ; get two's compliment for horizontal speed
    TAY
    INY
    STY Enemy_X_Speed,x  ; store as new horizontal speed
    LDA Enemy_MovingDir,x
    EOR #%00000011  ; invert moving direction and store, then leave
    STA Enemy_MovingDir,x  ; thus effectively turning the enemy around
ExTA:
    RTS  ; leave!!!

; -------------------------------------------------------------------------------------
; $00 - vertical position of platform

LargePlatformCollision:
    LDA #$ff  ; save value here
    STA PlatformCollisionFlag,x
    LDA TimerControl  ; check master timer control
    BNE ExLPC  ; if set, branch to leave
    LDA Enemy_State,x  ; if d7 set in object state,
    BMI ExLPC  ; branch to leave
    LDA Enemy_ID,x
    CMP #$24  ; check enemy object identifier for
    BNE ChkForPlayerC_LargeP  ; balance platform, branch if not found
    LDA Enemy_State,x
    TAX  ; set state as enemy offset here
    JSR ChkForPlayerC_LargeP  ; perform code with state offset, then original offset, in X

ChkForPlayerC_LargeP:
    JSR CheckPlayerVertical  ; figure out if player is below a certain point
    BCS ExLPC  ; or offscreen, branch to leave if true
    TXA
    JSR GetEnemyBoundBoxOfsArg  ; get bounding box offset in Y
    LDA Enemy_Y_Position,x  ; store vertical coordinate in
    STA $00  ; temp variable for now
    TXA  ; send offset we're on to the stack
    PHA
    JSR PlayerCollisionCore  ; do player-to-platform collision detection
    PLA  ; retrieve offset from the stack
    TAX
    BCC ExLPC  ; if no collision, branch to leave
    JSR ProcLPlatCollisions  ; otherwise collision, perform sub
ExLPC:
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------
; $00 - counter for bounding boxes

SmallPlatformCollision:
    LDA TimerControl  ; if master timer control set,
    BNE ExSPC  ; branch to leave
    STA PlatformCollisionFlag,x  ; otherwise initialize collision flag
    JSR CheckPlayerVertical  ; do a sub to see if player is below a certain point
    BCS ExSPC  ; or entirely offscreen, and branch to leave if true
    LDA #$02
    STA $00  ; load counter here for 2 bounding boxes

ChkSmallPlatLoop:
    LDX ObjectOffset  ; get enemy object offset
    JSR GetEnemyBoundBoxOfs  ; get bounding box offset in Y
    AND #%00000010  ; if d1 of offscreen lower nybble bits was set
    BNE ExSPC  ; then branch to leave
    LDA BoundingBox_UL_YPos,y  ; check top of platform's bounding box for being
    CMP #$20  ; above a specific point
    BCC MoveBoundBox  ; if so, branch, don't do collision detection
    JSR PlayerCollisionCore  ; otherwise, perform player-to-platform collision detection
    BCS ProcSPlatCollisions  ; skip ahead if collision

MoveBoundBox:
    LDA BoundingBox_UL_YPos,y  ; move bounding box vertical coordinates
    CLC  ; 128 pixels downwards
    ADC #$80
    STA BoundingBox_UL_YPos,y
    LDA BoundingBox_DR_YPos,y
    CLC
    ADC #$80
    STA BoundingBox_DR_YPos,y
    DEC $00  ; decrement counter we set earlier
    BNE ChkSmallPlatLoop  ; loop back until both bounding boxes are checked
ExSPC:
    LDX ObjectOffset  ; get enemy object buffer offset, then leave
    RTS

; --------------------------------

ProcSPlatCollisions:
    LDX ObjectOffset  ; return enemy object buffer offset to X, then continue

ProcLPlatCollisions:
    LDA BoundingBox_DR_YPos,y  ; get difference by subtracting the top
    SEC  ; of the player's bounding box from the bottom
    SBC BoundingBox_UL_YPos  ; of the platform's bounding box
    CMP #$04  ; if difference too large or negative,
    BCS ChkForTopCollision  ; branch, do not alter vertical speed of player
    LDA Player_Y_Speed  ; check to see if player's vertical speed is moving down
    BPL ChkForTopCollision  ; if so, don't mess with it
    LDA #$01  ; otherwise, set vertical
    STA Player_Y_Speed  ; speed of player to kill jump

ChkForTopCollision:
    LDA BoundingBox_DR_YPos  ; get difference by subtracting the top
    SEC  ; of the platform's bounding box from the bottom
    SBC BoundingBox_UL_YPos,y  ; of the player's bounding box
    CMP #$06
    BCS PlatformSideCollisions  ; if difference not close enough, skip all of this
    LDA Player_Y_Speed
    BMI PlatformSideCollisions  ; if player's vertical speed moving upwards, skip this
    LDA $00  ; get saved bounding box counter from earlier
    LDY Enemy_ID,x
    CPY #$2b  ; if either of the two small platform objects are found,
    BEQ SetCollisionFlag  ; regardless of which one, branch to use bounding box counter
    CPY #$2c  ; as contents of collision flag
    BEQ SetCollisionFlag
    TXA  ; otherwise use enemy object buffer offset

SetCollisionFlag:
    LDX ObjectOffset  ; get enemy object buffer offset
    STA PlatformCollisionFlag,x  ; save either bounding box counter or enemy offset here
    LDA #$00
    STA Player_State  ; set player state to normal then leave
    RTS

PlatformSideCollisions:
    LDA #$01  ; set value here to indicate possible horizontal
    STA $00  ; collision on left side of platform
    LDA BoundingBox_DR_XPos  ; get difference by subtracting platform's left edge
    SEC  ; from player's right edge
    SBC BoundingBox_UL_XPos,y
    CMP #$08  ; if difference close enough, skip all of this
    BCC SideC
    INC $00  ; otherwise increment value set here for right side collision
    LDA BoundingBox_DR_XPos,y  ; get difference by subtracting player's left edge
    CLC  ; from platform's right edge
    SBC BoundingBox_UL_XPos
    CMP #$09  ; if difference not close enough, skip subroutine
    BCS NoSideC  ; and instead branch to leave (no collision)
SideC:
    JSR ImpedePlayerMove  ; deal with horizontal collision
NoSideC:
    LDX ObjectOffset  ; return with enemy object buffer offset
    RTS

; -------------------------------------------------------------------------------------

PlayerPosSPlatData:
    .byte $80, $00

PositionPlayerOnS_Plat:
    TAY  ; use bounding box counter saved in collision flag
    LDA Enemy_Y_Position,x  ; for offset
    CLC  ; add positioning data using offset to the vertical
    ADC PlayerPosSPlatData-1,y  ; coordinate
    .byte $2c  ; BIT instruction opcode

PositionPlayerOnVPlat:
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    LDY GameEngineSubroutine
    CPY #$0b  ; if certain routine being executed on this frame,
    BEQ ExPlPos  ; skip all of this
    LDY Enemy_Y_HighPos,x
    CPY #$01  ; if vertical high byte offscreen, skip this
    BNE ExPlPos
    SEC  ; subtract 32 pixels from vertical coordinate
    SBC #$20  ; for the player object's height
    STA Player_Y_Position  ; save as player's new vertical coordinate
    TYA
    SBC #$00  ; subtract borrow and store as player's
    STA Player_Y_HighPos  ; new vertical high byte
    LDA #$00
    STA Player_Y_Speed  ; initialize vertical speed and low byte of force
    STA Player_Y_MoveForce  ; and then leave
ExPlPos:
    RTS

; -------------------------------------------------------------------------------------

CheckPlayerVertical:
    LDA Player_OffscreenBits  ; if player object is completely offscreen
    CMP #$f0  ; vertically, leave this routine
    BCS ExCPV
    LDY Player_Y_HighPos  ; if player high vertical byte is not
    DEY  ; within the screen, leave this routine
    BNE ExCPV
    LDA Player_Y_Position  ; if on the screen, check to see how far down
    CMP #$d0  ; the player is vertically
ExCPV:
    RTS

; -------------------------------------------------------------------------------------

GetEnemyBoundBoxOfs:
    LDA ObjectOffset  ; get enemy object buffer offset

GetEnemyBoundBoxOfsArg:
    ASL  ; multiply A by four, then add four
    ASL  ; to skip player's bounding box
    CLC
    ADC #$04
    TAY  ; send to Y
    LDA Enemy_OffscreenBits  ; get offscreen bits for enemy object
    AND #%00001111  ; save low nybble
    CMP #%00001111  ; check for all bits set
    RTS
