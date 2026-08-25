; -------------------------------------------------------------------------------------
; $04-$05 - used to store name table address in little endian order

BridgeCollapseData:
    .byte $1a  ; axe
    .byte $58  ; chain
    .byte $98, $96, $94, $92, $90, $8e, $8c  ; bridge
    .byte $8a, $88, $86, $84, $82, $80

BridgeCollapse:
    LDX BowserFront_Offset  ; get enemy offset for bowser
    LDA Enemy_ID,x  ; check enemy object identifier for bowser
    CMP #Bowser  ; if not found, branch ahead,
    BNE SetM2  ; metatile removal not necessary
    STX ObjectOffset  ; store as enemy offset here
    LDA Enemy_State,x  ; if bowser in normal state, skip all of this
    BEQ RemoveBridge
    AND #%01000000  ; if bowser's state has d6 clear, skip to silence music
    BEQ SetM2
    LDA Enemy_Y_Position,x  ; check bowser's vertical coordinate
    CMP #$e0  ; if bowser not yet low enough, skip this part ahead
    BCC MoveD_Bowser
SetM2:
    LDA #Silence  ; silence music
    STA EventMusicQueue
    INC OperMode_Task  ; move onto next secondary mode in autoctrl mode
    JMP KillAllEnemies  ; jump to empty all enemy slots and then leave

MoveD_Bowser:
    JSR sub_move_enemy_downward_slow  ; do a sub to move bowser downwards
    JMP BowserGfxHandler  ; jump to draw bowser's front and rear, then leave

RemoveBridge:
    DEC BowserFeetCounter  ; decrement timer to control bowser's feet
    BNE NoBFall  ; if not expired, skip all of this
    LDA #$04
    STA BowserFeetCounter  ; otherwise, set timer now
    LDA BowserBodyControls
    EOR #$01  ; invert bit to control bowser's feet
    STA BowserBodyControls
    LDA #$22  ; put high byte of name table address here for now
    STA $05
    LDY BridgeCollapseOffset  ; get bridge collapse offset here
    LDA BridgeCollapseData,y  ; load low byte of name table address and store here
    STA $04
    LDY VRAM_Buffer1_Offset  ; increment vram buffer offset
    INY
    LDX #$0c  ; set offset for tile data for sub to draw blank metatile
    JSR RemBridge  ; do sub here to remove bowser's bridge metatiles
    LDX ObjectOffset  ; get enemy offset
    JSR MoveVOffset  ; set new vram buffer offset
    LDA #Sfx_Blast  ; load the fireworks/gunfire sound into the square 2 sfx
    STA Square2SoundQueue  ; queue while at the same time loading the brick
    LDA #Sfx_BrickShatter  ; shatter sound into the noise sfx queue thus
    STA NoiseSoundQueue  ; producing the unique sound of the bridge collapsing
    INC BridgeCollapseOffset  ; increment bridge collapse offset
    LDA BridgeCollapseOffset
    CMP #$0f  ; if bridge collapse offset has not yet reached
    BNE NoBFall  ; the end, go ahead and skip this part
    JSR InitVStf  ; initialize whatever vertical speed bowser has
    LDA #%01000000
    STA Enemy_State,x  ; set bowser's state to one of defeated states (d6 set)
    LDA #Sfx_BowserFall
    STA Square2SoundQueue  ; play bowser defeat sound
NoBFall:
    JMP BowserGfxHandler  ; jump to code that draws bowser

; --------------------------------

PRandomRange:
    .byte $21, $41, $11, $31

RunBowser:
    LDA Enemy_State,x  ; if d5 in enemy state is not set
    AND #%00100000  ; then branch elsewhere to run bowser
    BEQ BowserControl
    LDA Enemy_Y_Position,x  ; otherwise check vertical position
    CMP #$e0  ; if above a certain point, branch to move defeated bowser
    BCC MoveD_Bowser  ; otherwise proceed to KillAllEnemies

KillAllEnemies:
    LDX #$04  ; start with last enemy slot
KillLoop:
    JSR EraseEnemyObject  ; branch to kill enemy objects
    DEX  ; move onto next enemy slot
    BPL KillLoop  ; do this until all slots are emptied
    STA EnemyFrenzyBuffer  ; empty frenzy buffer
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

BowserControl:
    LDA #$00
    STA EnemyFrenzyBuffer  ; empty frenzy buffer
    LDA TimerControl  ; if master timer control not set,
    BEQ ChkMouth  ; skip jump and execute code here
    JMP SkipToFB  ; otherwise, jump over a bunch of code
ChkMouth:
    LDA BowserBodyControls  ; check bowser's mouth
    BPL FeetTmr  ; if bit clear, go ahead with code here
    JMP HammerChk  ; otherwise skip a whole section starting here
FeetTmr:
    DEC BowserFeetCounter  ; decrement timer to control bowser's feet
    BNE ResetMDr  ; if not expired, skip this part
    LDA #$20  ; otherwise, reset timer
    STA BowserFeetCounter
    LDA BowserBodyControls  ; and invert bit used
    EOR #%00000001  ; to control bowser's feet
    STA BowserBodyControls
ResetMDr:
    LDA FrameCounter  ; check frame counter
    AND #%00001111  ; if not on every sixteenth frame, skip
    BNE B_FaceP  ; ahead to continue code
    LDA #$02  ; otherwise reset moving/facing direction every
    STA Enemy_MovingDir,x  ; sixteen frames
B_FaceP:
    LDA EnemyFrameTimer,x  ; if timer set here expired,
    BEQ GetPRCmp  ; branch to next section
    JSR PlayerEnemyDiff  ; get horizontal difference between player and bowser,
    BPL GetPRCmp  ; and branch if bowser to the right of the player
    LDA #$01
    STA Enemy_MovingDir,x  ; set bowser to move and face to the right
    LDA #$02
    STA BowserMovementSpeed  ; set movement speed
    LDA #$20
    STA EnemyFrameTimer,x  ; set timer here
    STA BowserFireBreathTimer  ; set timer used for bowser's flame
    LDA Enemy_X_Position,x
    CMP #$c8  ; if bowser to the right past a certain point,
    BCS HammerChk  ; skip ahead to some other section
GetPRCmp:
    LDA FrameCounter  ; get frame counter
    AND #%00000011
    BNE HammerChk  ; execute this code every fourth frame, otherwise branch
    LDA Enemy_X_Position,x
    CMP BowserOrigXPos  ; if bowser not at original horizontal position,
    BNE GetDToO  ; branch to skip this part
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get pseudorandom offset
    TAY
    LDA PRandomRange,y  ; load value using pseudorandom offset
    STA MaxRangeFromOrigin  ; and store here
GetDToO:
    LDA Enemy_X_Position,x
    CLC  ; add movement speed to bowser's horizontal
    ADC BowserMovementSpeed  ; coordinate and save as new horizontal position
    STA Enemy_X_Position,x
    LDY Enemy_MovingDir,x
    CPY #$01  ; if bowser moving and facing to the right, skip ahead
    BEQ HammerChk
    LDY #$ff  ; set default movement speed here (move left)
    SEC  ; get difference of current vs. original
    SBC BowserOrigXPos  ; horizontal position
    BPL CompDToO  ; if current position to the right of original, skip ahead
    EOR #$ff
    CLC  ; get two's compliment
    ADC #$01
    LDY #$01  ; set alternate movement speed here (move right)
CompDToO:
    CMP MaxRangeFromOrigin  ; compare difference with pseudorandom value
    BCC HammerChk  ; if difference < pseudorandom value, leave speed alone
    STY BowserMovementSpeed  ; otherwise change bowser's movement speed
HammerChk:
    LDA EnemyFrameTimer,x  ; if timer set here not expired yet, skip ahead to
    BNE MakeBJump  ; some other section of code
    JSR sub_move_enemy_downward_slow  ; otherwise start by moving bowser downwards
    LDA WorldNumber  ; check world number
    CMP #World6
    BCC SetHmrTmr  ; if world 1-5, skip this part (not time to throw hammers yet)
    LDA FrameCounter
    AND #%00000011  ; check to see if it's time to execute sub
    BNE SetHmrTmr  ; if not, skip sub, otherwise
    JSR SpawnHammerObj  ; execute sub on every fourth frame to spawn misc object (hammer)
SetHmrTmr:
    LDA Enemy_Y_Position,x  ; get current vertical position
    CMP #$80  ; if still above a certain point
    BCC ChkFireB  ; then skip to world number check for flames
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get pseudorandom offset
    TAY
    LDA PRandomRange,y  ; get value using pseudorandom offset
    STA EnemyFrameTimer,x  ; set for timer here
SkipToFB:
    JMP ChkFireB  ; jump to execute flames code
MakeBJump:
    CMP #$01  ; if timer not yet about to expire,
    BNE ChkFireB  ; skip ahead to next part
    DEC Enemy_Y_Position,x  ; otherwise decrement vertical coordinate
    JSR InitVStf  ; initialize movement amount
    LDA #$fe
    STA Enemy_Y_Speed,x  ; set vertical speed to move bowser upwards
ChkFireB:
    LDA WorldNumber  ; check world number here
    CMP #World8  ; world 8?
    BEQ SpawnFBr  ; if so, execute this part here
    CMP #World6  ; world 6-7?
    BCS BowserGfxHandler  ; if so, skip this part here
SpawnFBr:
    LDA BowserFireBreathTimer  ; check timer here
    BNE BowserGfxHandler  ; if not expired yet, skip all of this
    LDA #$20
    STA BowserFireBreathTimer  ; set timer here
    LDA BowserBodyControls
    EOR #%10000000  ; invert bowser's mouth bit to open
    STA BowserBodyControls  ; and close bowser's mouth
    BMI ChkFireB  ; if bowser's mouth open, loop back
    JSR SetFlameTimer  ; get timing for bowser's flame
    LDY SecondaryHardMode
    BEQ SetFBTmr  ; if secondary hard mode flag not set, skip this
    SEC
    SBC #$10  ; otherwise subtract from value in A
SetFBTmr:
    STA BowserFireBreathTimer  ; set value as timer here
    LDA #BowserFlame  ; put bowser's flame identifier
    STA EnemyFrenzyBuffer  ; in enemy frenzy buffer

; --------------------------------

BowserGfxHandler:
    JSR ProcessBowserHalf  ; do a sub here to process bowser's front
    LDY #$10  ; load default value here to position bowser's rear
    LDA Enemy_MovingDir,x  ; check moving direction
    LSR
    BCC CopyFToR  ; if moving left, use default
    LDY #$f0  ; otherwise load alternate positioning value here
CopyFToR:
    TYA  ; move bowser's rear object position value to A
    CLC
    ADC Enemy_X_Position,x  ; add to bowser's front object horizontal coordinate
    LDY DuplicateObj_Offset  ; get bowser's rear object offset
    STA Enemy_X_Position,y  ; store A as bowser's rear horizontal coordinate
    LDA Enemy_Y_Position,x
    CLC  ; add eight pixels to bowser's front object
    ADC #$08  ; vertical coordinate and store as vertical coordinate
    STA Enemy_Y_Position,y  ; for bowser's rear
    LDA Enemy_State,x
    STA Enemy_State,y  ; copy enemy state directly from front to rear
    LDA Enemy_MovingDir,x
    STA Enemy_MovingDir,y  ; copy moving direction also
    LDA ObjectOffset  ; save enemy object offset of front to stack
    PHA
    LDX DuplicateObj_Offset  ; put enemy object offset of rear as current
    STX ObjectOffset
    LDA #Bowser  ; set bowser's enemy identifier
    STA Enemy_ID,x  ; store in bowser's rear object
    JSR ProcessBowserHalf  ; do a sub here to process bowser's rear
    PLA
    STA ObjectOffset  ; get original enemy object offset
    TAX
    LDA #$00  ; nullify bowser's front/rear graphics flag
    STA BowserGfxFlag
ExBGfxH:
    RTS  ; leave!

ProcessBowserHalf:
    INC BowserGfxFlag  ; increment bowser's graphics flag, then run subroutines
    JSR RunRetainerObj  ; to get offscreen bits, relative position and draw bowser (finally!)
    LDA Enemy_State,x
    BNE ExBGfxH  ; if either enemy object not in normal state, branch to leave
    LDA #$0a
    STA Enemy_BoundBoxCtrl,x  ; set bounding box size control
    JSR GetEnemyBoundBox  ; get bounding box coordinates
    JMP PlayerEnemyCollision  ; do player-to-enemy collision detection

; -------------------------------------------------------------------------------------
; $00 - used to hold movement force and tile number
; $01 - used to hold sprite attribute data

FlameTimerData:
    .byte $bf, $40, $bf, $bf, $bf, $40, $40, $bf

SetFlameTimer:
    LDY BowserFlameTimerCtrl  ; load counter as offset
    INC BowserFlameTimerCtrl  ; increment
    LDA BowserFlameTimerCtrl  ; mask out all but 3 LSB
    AND #%00000111  ; to keep in range of 0-7
    STA BowserFlameTimerCtrl
    LDA FlameTimerData,y  ; load value to be used then leave
ExFl:
    RTS

ProcBowserFlame:
    LDA TimerControl  ; if master timer control flag set,
    BNE SetGfxF  ; skip all of this
    LDA #$40  ; load default movement force
    LDY SecondaryHardMode
    BEQ SFlmX  ; if secondary hard mode flag not set, use default
    LDA #$60  ; otherwise load alternate movement force to go faster
SFlmX:
    STA $00  ; store value here
    LDA Enemy_X_MoveForce,x
    SEC  ; subtract value from movement force
    SBC $00
    STA Enemy_X_MoveForce,x  ; save new value
    LDA Enemy_X_Position,x
    SBC #$01  ; subtract one from horizontal position to move
    STA Enemy_X_Position,x  ; to the left
    LDA Enemy_PageLoc,x
    SBC #$00  ; subtract borrow from page location
    STA Enemy_PageLoc,x
    LDY BowserFlamePRandomOfs,x  ; get some value here and use as offset
    LDA Enemy_Y_Position,x  ; load vertical coordinate
    CMP FlameYPosData,y  ; compare against coordinate data using $0417,x as offset
    BEQ SetGfxF  ; if equal, branch and do not modify coordinate
    CLC
    ADC Enemy_Y_MoveForce,x  ; otherwise add value here to coordinate and store
    STA Enemy_Y_Position,x  ; as new vertical coordinate
SetGfxF:
    JSR RelativeEnemyPosition  ; get new relative coordinates
    LDA Enemy_State,x  ; if bowser's flame not in normal state,
    BNE ExFl  ; branch to leave
    LDA #$51  ; otherwise, continue
    STA $00  ; write first tile number
    LDY #$02  ; load attributes without vertical flip by default
    LDA FrameCounter
    AND #%00000010  ; invert vertical flip bit every 2 frames
    BEQ FlmeAt  ; if d1 not set, write default value
    LDY #$82  ; otherwise write value with vertical flip bit set
FlmeAt:
    STY $01  ; set bowser's flame sprite attributes here
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDX #$00

DrawFlameLoop:
    LDA Enemy_Rel_YPos  ; get Y relative coordinate of current enemy object
    STA Sprite_Y_Position,y  ; write into Y coordinate of OAM data
    LDA $00
    STA Sprite_Tilenumber,y  ; write current tile number into OAM data
    INC $00  ; increment tile number to draw more bowser's flame
    LDA $01
    STA Sprite_Attributes,y  ; write saved attributes into OAM data
    LDA Enemy_Rel_XPos
    STA Sprite_X_Position,y  ; write X relative coordinate of current enemy object
    CLC
    ADC #$08
    STA Enemy_Rel_XPos  ; then add eight to it and store
    INY
    INY
    INY
    INY  ; increment Y four times to move onto the next OAM
    INX  ; move onto the next OAM, and branch if three
    CPX #$03  ; have not yet been done
    BCC DrawFlameLoop
    LDX ObjectOffset  ; reload original enemy offset
    JSR GetEnemyOffscreenBits  ; get offscreen information
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA Enemy_OffscreenBits  ; get enemy object offscreen bits
    LSR  ; move d0 to carry and result to stack
    PHA
    BCC M3FOfs  ; branch if carry not set
    LDA #$f8  ; otherwise move sprite offscreen, this part likely
    STA Sprite_Y_Position+12,y  ; residual since flame is only made of three sprites
M3FOfs:
    PLA  ; get bits from stack
    LSR  ; move d1 to carry and move bits back to stack
    PHA
    BCC M2FOfs  ; branch if carry not set again
    LDA #$f8  ; otherwise move third sprite offscreen
    STA Sprite_Y_Position+8,y
M2FOfs:
    PLA  ; get bits from stack again
    LSR  ; move d2 to carry and move bits back to stack again
    PHA
    BCC M1FOfs  ; branch if carry not set yet again
    LDA #$f8  ; otherwise move second sprite offscreen
    STA Sprite_Y_Position+4,y
M1FOfs:
    PLA  ; get bits from stack one last time
    LSR  ; move d3 to carry
    BCC ExFlmeD  ; branch if carry not set one last time
    LDA #$f8
    STA Sprite_Y_Position,y  ; otherwise move first sprite offscreen
ExFlmeD:
    RTS  ; leave

; --------------------------------

RunFireworks:
    DEC ExplosionTimerCounter,x  ; decrement explosion timing counter here
    BNE SetupExpl  ; if not expired, skip this part
    LDA #$08
    STA ExplosionTimerCounter,x  ; reset counter
    INC ExplosionGfxCounter,x  ; increment explosion graphics counter
    LDA ExplosionGfxCounter,x
    CMP #$03  ; check explosion graphics counter
    BCS FireworksSoundScore  ; if at a certain point, branch to kill this object
SetupExpl:
    JSR RelativeEnemyPosition  ; get relative coordinates of explosion
    LDA Enemy_Rel_YPos  ; copy relative coordinates
    STA Fireball_Rel_YPos  ; from the enemy object to the fireball object
    LDA Enemy_Rel_XPos  ; first vertical, then horizontal
    STA Fireball_Rel_XPos
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA ExplosionGfxCounter,x  ; get explosion graphics counter
    JSR DrawExplosion_Fireworks  ; do a sub to draw the explosion then leave
    RTS

FireworksSoundScore:
    LDA #$00  ; disable enemy buffer flag
    STA Enemy_Flag,x
    LDA #Sfx_Blast  ; play fireworks/gunfire sound
    STA Square2SoundQueue
    LDA #$05  ; set part of score modifier for 500 points
    STA DigitModifier+4
    JMP EndAreaPoints  ; jump to award points accordingly then leave

; --------------------------------

StarFlagYPosAdder:
    .byte $00, $00, $08, $08

StarFlagXPosAdder:
    .byte $00, $08, $00, $08

StarFlagTileData:
    .byte $54, $55, $56, $57

RunStarFlagObj:
    LDA #$00  ; initialize enemy frenzy buffer
    STA EnemyFrenzyBuffer
    LDA StarFlagTaskControl  ; check star flag object task number here
    CMP #$05  ; if greater than 5, branch to exit
    BCS StarFlagExit
    JSR sub_dispatch_inline_handler  ; otherwise jump to appropriate sub

    .word StarFlagExit
    .word GameTimerFireworks
    .word AwardGameTimerPoints
    .word RaiseFlagSetoffFWorks
    .word DelayToAreaEnd

GameTimerFireworks:
    LDY #$05  ; set default state for star flag object
    LDA GameTimerDisplay+2  ; get game timer's last digit
    CMP #$01
    BEQ SetFWC  ; if last digit of game timer set to 1, skip ahead
    LDY #$03  ; otherwise load new value for state
    CMP #$03
    BEQ SetFWC  ; if last digit of game timer set to 3, skip ahead
    LDY #$00  ; otherwise load one more potential value for state
    CMP #$06
    BEQ SetFWC  ; if last digit of game timer set to 6, skip ahead
    LDA #$ff  ; otherwise set value for no fireworks
SetFWC:
    STA FireworksCounter  ; set fireworks counter here
    STY Enemy_State,x  ; set whatever state we have in star flag object

IncrementSFTask1:
    INC StarFlagTaskControl  ; increment star flag object task number

StarFlagExit:
    RTS  ; leave

AwardGameTimerPoints:
    LDA GameTimerDisplay  ; check all game timer digits for any intervals left
    ORA GameTimerDisplay+1
    ORA GameTimerDisplay+2
    BEQ IncrementSFTask1  ; if no time left on game timer at all, branch to next task
    LDA FrameCounter
    AND #%00000100  ; check frame counter for d2 set (skip ahead
    BEQ NoTTick  ; for four frames every four frames) branch if not set
    LDA #Sfx_TimerTick
    STA Square2SoundQueue  ; load timer tick sound
NoTTick:
    LDY #$23  ; set offset here to subtract from game timer's last digit
    LDA #$ff  ; set adder here to $ff, or -1, to subtract one
    STA DigitModifier+5  ; from the last digit of the game timer
    JSR DigitsMathRoutine  ; subtract digit
    LDA #$05  ; set now to add 50 points
    STA DigitModifier+5  ; per game timer interval subtracted

EndAreaPoints:
    LDY #$0b  ; load offset for mario's score by default
    LDA CurrentPlayer  ; check player on the screen
    BEQ ELPGive  ; if mario, do not change
    LDY #$11  ; otherwise load offset for luigi's score
ELPGive:
    JSR DigitsMathRoutine  ; award 50 points per game timer interval
    LDA CurrentPlayer  ; get player on the screen (or 500 points per
    ASL  ; fireworks explosion if branched here from there)
    ASL  ; shift to high nybble
    ASL
    ASL
    ORA #%00000100  ; add four to set nybble for game timer
    JMP UpdateNumber  ; jump to print the new score and game timer

RaiseFlagSetoffFWorks:
    LDA Enemy_Y_Position,x  ; check star flag's vertical position
    CMP #$72  ; against preset value
    BCC SetoffF  ; if star flag higher vertically, branch to other code
    DEC Enemy_Y_Position,x  ; otherwise, raise star flag by one pixel
    JMP DrawStarFlag  ; and skip this part here
SetoffF:
    LDA FireworksCounter  ; check fireworks counter
    BEQ DrawFlagSetTimer  ; if no fireworks left to go off, skip this part
    BMI DrawFlagSetTimer  ; if no fireworks set to go off, skip this part
    LDA #Fireworks
    STA EnemyFrenzyBuffer  ; otherwise set fireworks object in frenzy queue

DrawStarFlag:
    JSR RelativeEnemyPosition  ; get relative coordinates of star flag
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDX #$03  ; do four sprites
DSFLoop:
    LDA Enemy_Rel_YPos  ; get relative vertical coordinate
    CLC
    ADC StarFlagYPosAdder,x  ; add Y coordinate adder data
    STA Sprite_Y_Position,y  ; store as Y coordinate
    LDA StarFlagTileData,x  ; get tile number
    STA Sprite_Tilenumber,y  ; store as tile number
    LDA #$22  ; set palette and background priority bits
    STA Sprite_Attributes,y  ; store as attributes
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    CLC
    ADC StarFlagXPosAdder,x  ; add X coordinate adder data
    STA Sprite_X_Position,y  ; store as X coordinate
    INY
    INY  ; increment OAM data offset four bytes
    INY  ; for next sprite
    INY
    DEX  ; move onto next sprite
    BPL DSFLoop  ; do this until all sprites are done
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

DrawFlagSetTimer:
    JSR DrawStarFlag  ; do sub to draw star flag
    LDA #$06
    STA EnemyIntervalTimer,x  ; set interval timer here

IncrementSFTask2:
    INC StarFlagTaskControl  ; move onto next task
    RTS

DelayToAreaEnd:
    JSR DrawStarFlag  ; do sub to draw star flag
    LDA EnemyIntervalTimer,x  ; if interval timer set in previous task
    BNE StarFlagExit2  ; not yet expired, branch to leave
    LDA EventMusicBuffer  ; if event music buffer empty,
    BEQ IncrementSFTask2  ; branch to increment task

StarFlagExit2:
    RTS  ; otherwise leave

; --------------------------------
; $00 - used to store horizontal difference between player and piranha plant

MovePiranhaPlant:
    LDA Enemy_State,x  ; check enemy state
    BNE PutinPipe  ; if set at all, branch to leave
    LDA EnemyFrameTimer,x  ; check enemy's timer here
    BNE PutinPipe  ; branch to end if not yet expired
    LDA PiranhaPlant_MoveFlag,x  ; check movement flag
    BNE SetupToMovePPlant  ; if moving, skip to part ahead
    LDA PiranhaPlant_Y_Speed,x  ; if currently rising, branch
    BMI ReversePlantSpeed  ; to move enemy upwards out of pipe
    JSR PlayerEnemyDiff  ; get horizontal difference between player and
    BPL ChkPlayerNearPipe  ; piranha plant, and branch if enemy to right of player
    LDA $00  ; otherwise get saved horizontal difference
    EOR #$ff
    CLC  ; and change to two's compliment
    ADC #$01
    STA $00  ; save as new horizontal difference

ChkPlayerNearPipe:
    LDA $00  ; get saved horizontal difference
    CMP #$21
    BCC PutinPipe  ; if player within a certain distance, branch to leave

ReversePlantSpeed:
    LDA PiranhaPlant_Y_Speed,x  ; get vertical speed
    EOR #$ff
    CLC  ; change to two's compliment
    ADC #$01
    STA PiranhaPlant_Y_Speed,x  ; save as new vertical speed
    INC PiranhaPlant_MoveFlag,x  ; increment to set movement flag

SetupToMovePPlant:
    LDA PiranhaPlantDownYPos,x  ; get original vertical coordinate (lowest point)
    LDY PiranhaPlant_Y_Speed,x  ; get vertical speed
    BPL RiseFallPiranhaPlant  ; branch if moving downwards
    LDA PiranhaPlantUpYPos,x  ; otherwise get other vertical coordinate (highest point)

RiseFallPiranhaPlant:
    STA $00  ; save vertical coordinate here
    LDA FrameCounter  ; get frame counter
    LSR
    BCC PutinPipe  ; branch to leave if d0 set (execute code every other frame)
    LDA TimerControl  ; get master timer control
    BNE PutinPipe  ; branch to leave if set (likely not necessary)
    LDA Enemy_Y_Position,x  ; get current vertical coordinate
    CLC
    ADC PiranhaPlant_Y_Speed,x  ; add vertical speed to move up or down
    STA Enemy_Y_Position,x  ; save as new vertical coordinate
    CMP $00  ; compare against low or high coordinate
    BNE PutinPipe  ; branch to leave if not yet reached
    LDA #$00
    STA PiranhaPlant_MoveFlag,x  ; otherwise clear movement flag
    LDA #$40
    STA EnemyFrameTimer,x  ; set timer to delay piranha plant movement

PutinPipe:
    LDA #%00100000  ; set background priority bit in sprite
    STA Enemy_SprAttrib,x  ; attributes to give illusion of being inside pipe
    RTS  ; then leave

; -------------------------------------------------------------------------------------
; $07 - spinning speed

FirebarSpin:
    STA $07  ; save spinning speed here
    LDA FirebarSpinDirection,x  ; check spinning direction
    BNE SpinCounterClockwise  ; if moving counter-clockwise, branch to other part
    LDY #$18  ; possibly residual ldy
    LDA FirebarSpinState_Low,x
    CLC  ; add spinning speed to what would normally be
    ADC $07  ; the horizontal speed
    STA FirebarSpinState_Low,x
    LDA FirebarSpinState_High,x  ; add carry to what would normally be the vertical speed
    ADC #$00
    RTS

SpinCounterClockwise:
    LDY #$08  ; possibly residual ldy
    LDA FirebarSpinState_Low,x
    SEC  ; subtract spinning speed to what would normally be
    SBC $07  ; the horizontal speed
    STA FirebarSpinState_Low,x
    LDA FirebarSpinState_High,x  ; add carry to what would normally be the vertical speed
    SBC #$00
    RTS
