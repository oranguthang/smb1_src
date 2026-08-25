; --------------------------------

FirebarSpinSpdData:
    .byte $28, $38, $28, $38, $28

FirebarSpinDirData:
    .byte $00, $00, $10, $10, $00

InitLongFirebar:
    JSR DuplicateEnemyObj  ; create enemy object for long firebar

InitShortFirebar:
    LDA #$00  ; initialize low byte of spin state
    STA FirebarSpinState_Low,x
    LDA Enemy_ID,x  ; subtract $1b from enemy identifier
    SEC  ; to get proper offset for firebar data
    SBC #$1b
    TAY
    LDA FirebarSpinSpdData,y  ; get spinning speed of firebar
    STA FirebarSpinSpeed,x
    LDA FirebarSpinDirData,y  ; get spinning direction of firebar
    STA FirebarSpinDirection,x
    LDA Enemy_Y_Position,x
    CLC  ; add four pixels to vertical coordinate
    ADC #$04
    STA Enemy_Y_Position,x
    LDA Enemy_X_Position,x
    CLC  ; add four pixels to horizontal coordinate
    ADC #$04
    STA Enemy_X_Position,x
    LDA Enemy_PageLoc,x
    ADC #$00  ; add carry to page location
    STA Enemy_PageLoc,x
    JMP TallBBox2  ; set bounding box control (not used) and leave

; --------------------------------
; $00-$01 - used to hold pseudorandom bits

FlyCCXPositionData:
    .byte $80, $30, $40, $80
    .byte $30, $50, $50, $70
    .byte $20, $40, $80, $a0
    .byte $70, $40, $90, $68

FlyCCXSpeedData:
    .byte $0e, $05, $06, $0e
    .byte $1c, $20, $10, $0c
    .byte $1e, $22, $18, $14

FlyCCTimerData:
    .byte $10, $60, $20, $48

InitFlyingCheepCheep:
    LDA FrenzyEnemyTimer  ; if timer here not expired yet, branch to leave
    BNE ChpChpEx
    JSR SmallBBox  ; jump to set bounding box size $09 and init other values
    LDA PseudoRandomBitReg+1,x
    AND #%00000011  ; set pseudorandom offset here
    TAY
    LDA FlyCCTimerData,y  ; load timer with pseudorandom offset
    STA FrenzyEnemyTimer
    LDY #$03  ; load Y with default value
    LDA SecondaryHardMode
    BEQ MaxCC  ; if secondary hard mode flag not set, do not increment Y
    INY  ; otherwise, increment Y to allow as many as four onscreen
MaxCC:
    STY $00  ; store whatever pseudorandom bits are in Y
    CPX $00  ; compare enemy object buffer offset with Y
    BCS ChpChpEx  ; if X => Y, branch to leave
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get last two bits of LSFR, first part
    STA $00  ; and store in two places
    STA $01
    LDA #$fb  ; set vertical speed for cheep-cheep
    STA Enemy_Y_Speed,x
    LDA #$00  ; load default value
    LDY Player_X_Speed  ; check player's horizontal speed
    BEQ GSeed  ; if player not moving left or right, skip this part
    LDA #$04
    CPY #$19  ; if moving to the right but not very quickly,
    BCC GSeed  ; do not change A
    ASL  ; otherwise, multiply A by 2
GSeed:
    PHA  ; save to stack
    CLC
    ADC $00  ; add to last two bits of LSFR we saved earlier
    STA $00  ; save it there
    LDA PseudoRandomBitReg+1,x
    AND #%00000011  ; if neither of the last two bits of second LSFR set,
    BEQ RSeed  ; skip this part and save contents of $00
    LDA PseudoRandomBitReg+2,x
    AND #%00001111  ; otherwise overwrite with lower nybble of
    STA $00  ; third LSFR part
RSeed:
    PLA  ; get value from stack we saved earlier
    CLC
    ADC $01  ; add to last two bits of LSFR we saved in other place
    TAY  ; use as pseudorandom offset here
    LDA FlyCCXSpeedData,y  ; get horizontal speed using pseudorandom offset
    STA Enemy_X_Speed,x
    LDA #$01  ; set to move towards the right
    STA Enemy_MovingDir,x
    LDA Player_X_Speed  ; if player moving left or right, branch ahead of this part
    BNE D2XPos1
    LDY $00  ; get first LSFR or third LSFR lower nybble
    TYA  ; and check for d1 set
    AND #%00000010
    BEQ D2XPos1  ; if d1 not set, branch
    LDA Enemy_X_Speed,x
    EOR #$ff  ; if d1 set, change horizontal speed
    CLC  ; into two's compliment, thus moving in the opposite
    ADC #$01  ; direction
    STA Enemy_X_Speed,x
    INC Enemy_MovingDir,x  ; increment to move towards the left
D2XPos1:
    TYA  ; get first LSFR or third LSFR lower nybble again
    AND #%00000010
    BEQ D2XPos2  ; check for d1 set again, branch again if not set
    LDA Player_X_Position  ; get player's horizontal position
    CLC
    ADC FlyCCXPositionData,y  ; if d1 set, add value obtained from pseudorandom offset
    STA Enemy_X_Position,x  ; and save as enemy's horizontal position
    LDA Player_PageLoc  ; get player's page location
    ADC #$00  ; add carry and jump past this part
    JMP FinCCSt
D2XPos2:
    LDA Player_X_Position  ; get player's horizontal position
    SEC
    SBC FlyCCXPositionData,y  ; if d1 not set, subtract value obtained from pseudorandom
    STA Enemy_X_Position,x  ; offset and save as enemy's horizontal position
    LDA Player_PageLoc  ; get player's page location
    SBC #$00  ; subtract borrow
FinCCSt:
    STA Enemy_PageLoc,x  ; save as enemy's page location
    LDA #$01
    STA Enemy_Flag,x  ; set enemy's buffer flag
    STA Enemy_Y_HighPos,x  ; set enemy's high vertical byte
    LDA #$f8
    STA Enemy_Y_Position,x  ; put enemy below the screen, and we are done
    RTS

; --------------------------------

InitBowser:
    JSR DuplicateEnemyObj  ; jump to create another bowser object
    STX BowserFront_Offset  ; save offset of first here
    LDA #$00
    STA BowserBodyControls  ; initialize bowser's body controls
    STA BridgeCollapseOffset  ; and bridge collapse offset
    LDA Enemy_X_Position,x
    STA BowserOrigXPos  ; store original horizontal position here
    LDA #$df
    STA BowserFireBreathTimer  ; store something here
    STA Enemy_MovingDir,x  ; and in moving direction
    LDA #$20
    STA BowserFeetCounter  ; set bowser's feet timer and in enemy timer
    STA EnemyFrameTimer,x
    LDA #$05
    STA BowserHitPoints  ; give bowser 5 hit points
    LSR
    STA BowserMovementSpeed  ; set default movement speed here
    RTS

; --------------------------------

DuplicateEnemyObj:
    LDY #$ff  ; start at beginning of enemy slots
FSLoop:
    INY  ; increment one slot
    LDA Enemy_Flag,y  ; check enemy buffer flag for empty slot
    BNE FSLoop  ; if set, branch and keep checking
    STY DuplicateObj_Offset  ; otherwise set offset here
    TXA  ; transfer original enemy buffer offset
    ORA #%10000000  ; store with d7 set as flag in new enemy
    STA Enemy_Flag,y  ; slot as well as enemy offset
    LDA Enemy_PageLoc,x
    STA Enemy_PageLoc,y  ; copy page location and horizontal coordinates
    LDA Enemy_X_Position,x  ; from original enemy to new enemy
    STA Enemy_X_Position,y
    LDA #$01
    STA Enemy_Flag,x  ; set flag as normal for original enemy
    STA Enemy_Y_HighPos,y  ; set high vertical byte for new enemy
    LDA Enemy_Y_Position,x
    STA Enemy_Y_Position,y  ; copy vertical coordinate from original to new
FlmEx:
    RTS  ; and then leave

; --------------------------------

FlameYPosData:
    .byte $90, $80, $70, $90

FlameYMFAdderData:
    .byte $ff, $01

InitBowserFlame:
    LDA FrenzyEnemyTimer  ; if timer not expired yet, branch to leave
    BNE FlmEx
    STA Enemy_Y_MoveForce,x  ; reset something here
    LDA NoiseSoundQueue
    ORA #Sfx_BowserFlame  ; load bowser's flame sound into queue
    STA NoiseSoundQueue
    LDY BowserFront_Offset  ; get bowser's buffer offset
    LDA Enemy_ID,y  ; check for bowser
    CMP #Bowser
    BEQ SpawnFromMouth  ; branch if found
    JSR SetFlameTimer  ; get timer data based on flame counter
    CLC
    ADC #$20  ; add 32 frames by default
    LDY SecondaryHardMode
    BEQ SetFrT  ; if secondary mode flag not set, use as timer setting
    SEC
    SBC #$10  ; otherwise subtract 16 frames for secondary hard mode
SetFrT:
    STA FrenzyEnemyTimer  ; set timer accordingly
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get 2 LSB from first part of LSFR
    STA BowserFlamePRandomOfs,x  ; set here
    TAY  ; use as offset
    LDA FlameYPosData,y  ; load vertical position based on pseudorandom offset

PutAtRightExtent:
    STA Enemy_Y_Position,x  ; set vertical position
    LDA ScreenRight_X_Pos
    CLC
    ADC #$20  ; place enemy 32 pixels beyond right side of screen
    STA Enemy_X_Position,x
    LDA ScreenRight_PageLoc
    ADC #$00  ; add carry
    STA Enemy_PageLoc,x
    JMP FinishFlame  ; skip this part to finish setting values

SpawnFromMouth:
    LDA Enemy_X_Position,y  ; get bowser's horizontal position
    SEC
    SBC #$0e  ; subtract 14 pixels
    STA Enemy_X_Position,x  ; save as flame's horizontal position
    LDA Enemy_PageLoc,y
    STA Enemy_PageLoc,x  ; copy page location from bowser to flame
    LDA Enemy_Y_Position,y
    CLC  ; add 8 pixels to bowser's vertical position
    ADC #$08
    STA Enemy_Y_Position,x  ; save as flame's vertical position
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get 2 LSB from first part of LSFR
    STA Enemy_YMF_Dummy,x  ; save here
    TAY  ; use as offset
    LDA FlameYPosData,y  ; get value here using bits as offset
    LDY #$00  ; load default offset
    CMP Enemy_Y_Position,x  ; compare value to flame's current vertical position
    BCC SetMF  ; if less, do not increment offset
    INY  ; otherwise increment now
SetMF:
    LDA FlameYMFAdderData,y  ; get value here and save
    STA Enemy_Y_MoveForce,x  ; to vertical movement force
    LDA #$00
    STA EnemyFrenzyBuffer  ; clear enemy frenzy buffer

FinishFlame:
    LDA #$08  ; set $08 for bounding box control
    STA Enemy_BoundBoxCtrl,x
    LDA #$01  ; set high byte of vertical and
    STA Enemy_Y_HighPos,x  ; enemy buffer flag
    STA Enemy_Flag,x
    LSR
    STA Enemy_X_MoveForce,x  ; initialize horizontal movement force, and
    STA Enemy_State,x  ; enemy state
    RTS

; --------------------------------

FireworksXPosData:
    .byte $00, $30, $60, $60, $00, $20

FireworksYPosData:
    .byte $60, $40, $70, $40, $60, $30

InitFireworks:
    LDA FrenzyEnemyTimer  ; if timer not expired yet, branch to leave
    BNE ExitFWk
    LDA #$20  ; otherwise reset timer
    STA FrenzyEnemyTimer
    DEC FireworksCounter  ; decrement for each explosion
    LDY #$06  ; start at last slot
StarFChk:
    DEY
    LDA Enemy_ID,y  ; check for presence of star flag object
    CMP #StarFlagObject  ; if there isn't a star flag object,
    BNE StarFChk  ; routine goes into infinite loop = crash
    LDA Enemy_X_Position,y
    SEC  ; get horizontal coordinate of star flag object, then
    SBC #$30  ; subtract 48 pixels from it and save to
    PHA  ; the stack
    LDA Enemy_PageLoc,y
    SBC #$00  ; subtract the carry from the page location
    STA $00  ; of the star flag object
    LDA FireworksCounter  ; get fireworks counter
    CLC
    ADC Enemy_State,y  ; add state of star flag object (possibly not necessary)
    TAY  ; use as offset
    PLA  ; get saved horizontal coordinate of star flag - 48 pixels
    CLC
    ADC FireworksXPosData,y  ; add number based on offset of fireworks counter
    STA Enemy_X_Position,x  ; store as the fireworks object horizontal coordinate
    LDA $00
    ADC #$00  ; add carry and store as page location for
    STA Enemy_PageLoc,x  ; the fireworks object
    LDA FireworksYPosData,y  ; get vertical position using same offset
    STA Enemy_Y_Position,x  ; and store as vertical coordinate for fireworks object
    LDA #$01
    STA Enemy_Y_HighPos,x  ; store in vertical high byte
    STA Enemy_Flag,x  ; and activate enemy buffer flag
    LSR
    STA ExplosionGfxCounter,x  ; initialize explosion counter
    LDA #$08
    STA ExplosionTimerCounter,x  ; set explosion timing counter
ExitFWk:
    RTS

; --------------------------------

Bitmasks:
    .byte %00000001, %00000010, %00000100, %00001000, %00010000, %00100000, %01000000, %10000000

Enemy17YPosData:
    .byte $40, $30, $90, $50, $20, $60, $a0, $70

SwimCC_IDData:
    .byte $0a, $0b

BulletBillCheepCheep:
    LDA FrenzyEnemyTimer  ; if timer not expired yet, branch to leave
    BNE ExF17
    LDA AreaType  ; are we in a water-type level?
    BNE DoBulletBills  ; if not, branch elsewhere
    CPX #$03  ; are we past third enemy slot?
    BCS ExF17  ; if so, branch to leave
    LDY #$00  ; load default offset
    LDA PseudoRandomBitReg,x
    CMP #$aa  ; check first part of LSFR against preset value
    BCC ChkW2  ; if less than preset, do not increment offset
    INY  ; otherwise increment
ChkW2:
    LDA WorldNumber  ; check world number
    CMP #World2
    BEQ Get17ID  ; if we're on world 2, do not increment offset
    INY  ; otherwise increment
Get17ID:
    TYA
    AND #%00000001  ; mask out all but last bit of offset
    TAY
    LDA SwimCC_IDData,y  ; load identifier for cheep-cheeps
Set17ID:
    STA Enemy_ID,x  ; store whatever's in A as enemy identifier
    LDA BitMFilter
    CMP #$ff  ; if not all bits set, skip init part and compare bits
    BNE GetRBit
    LDA #$00  ; initialize vertical position filter
    STA BitMFilter
GetRBit:
    LDA PseudoRandomBitReg,x  ; get first part of LSFR
    AND #%00000111  ; mask out all but 3 LSB
ChkRBit:
    TAY  ; use as offset
    LDA Bitmasks,y  ; load bitmask
    BIT BitMFilter  ; perform AND on filter without changing it
    BEQ AddFBit
    INY  ; increment offset
    TYA
    AND #%00000111  ; mask out all but 3 LSB thus keeping it 0-7
    JMP ChkRBit  ; do another check
AddFBit:
    ORA BitMFilter  ; add bit to already set bits in filter
    STA BitMFilter  ; and store
    LDA Enemy17YPosData,y  ; load vertical position using offset
    JSR PutAtRightExtent  ; set vertical position and other values
    STA Enemy_YMF_Dummy,x  ; initialize dummy variable
    LDA #$20  ; set timer
    STA FrenzyEnemyTimer
    JMP CheckpointEnemyID  ; process our new enemy object

DoBulletBills:
    LDY #$ff  ; start at beginning of enemy slots
BB_SLoop:
    INY  ; move onto the next slot
    CPY #$05  ; branch to play sound if we've done all slots
    BCS FireBulletBill
    LDA Enemy_Flag,y  ; if enemy buffer flag not set,
    BEQ BB_SLoop  ; loop back and check another slot
    LDA Enemy_ID,y
    CMP #BulletBill_FrenzyVar  ; check enemy identifier for
    BNE BB_SLoop  ; bullet bill object (frenzy variant)
ExF17:
    RTS  ; if found, leave

FireBulletBill:
    LDA Square2SoundQueue
    ORA #Sfx_Blast  ; play fireworks/gunfire sound
    STA Square2SoundQueue
    LDA #BulletBill_FrenzyVar  ; load identifier for bullet bill object
    BNE Set17ID  ; unconditional branch

; --------------------------------
; $00 - used to store Y position of group enemies
; $01 - used to store enemy ID
; $02 - used to store page location of right side of screen
; $03 - used to store X position of right side of screen

HandleGroupEnemies:
    LDY #$00  ; load value for green koopa troopa
    SEC
    SBC #$37  ; subtract $37 from second byte read
    PHA  ; save result in stack for now
    CMP #$04  ; was byte in $3b-$3e range?
    BCS SnglID  ; if so, branch
    PHA  ; save another copy to stack
    LDY #Goomba  ; load value for goomba enemy
    LDA PrimaryHardMode  ; if primary hard mode flag not set,
    BEQ PullID  ; branch, otherwise change to value
    LDY #BuzzyBeetle  ; for buzzy beetle
PullID:
    PLA  ; get second copy from stack
SnglID:
    STY $01  ; save enemy id here
    LDY #$b0  ; load default y coordinate
    AND #$02  ; check to see if d1 was set
    BEQ SetYGp  ; if so, move y coordinate up,
    LDY #$70  ; otherwise branch and use default
SetYGp:
    STY $00  ; save y coordinate here
    LDA ScreenRight_PageLoc  ; get page number of right edge of screen
    STA $02  ; save here
    LDA ScreenRight_X_Pos  ; get pixel coordinate of right edge
    STA $03  ; save here
    LDY #$02  ; load two enemies by default
    PLA  ; get first copy from stack
    LSR  ; check to see if d0 was set
    BCC CntGrp  ; if not, use default value
    INY  ; otherwise increment to three enemies
CntGrp:
    STY NumberofGroupEnemies  ; save number of enemies here
GrLoop:
    LDX #$ff  ; start at beginning of enemy buffers
GSltLp:
    INX  ; increment and branch if past
    CPX #$05  ; end of buffers
    BCS NextED
    LDA Enemy_Flag,x  ; check to see if enemy is already
    BNE GSltLp  ; stored in buffer, and branch if so
    LDA $01
    STA Enemy_ID,x  ; store enemy object identifier
    LDA $02
    STA Enemy_PageLoc,x  ; store page location for enemy object
    LDA $03
    STA Enemy_X_Position,x  ; store x coordinate for enemy object
    CLC
    ADC #$18  ; add 24 pixels for next enemy
    STA $03
    LDA $02  ; add carry to page location for
    ADC #$00  ; next enemy
    STA $02
    LDA $00  ; store y coordinate for enemy object
    STA Enemy_Y_Position,x
    LDA #$01  ; activate flag for buffer, and
    STA Enemy_Y_HighPos,x  ; put enemy within the screen vertically
    STA Enemy_Flag,x
    JSR CheckpointEnemyID  ; process each enemy object separately
    DEC NumberofGroupEnemies  ; do this until we run out of enemy objects
    BNE GrLoop
NextED:
    JMP Inc2B  ; jump to increment data offset and leave

; --------------------------------

InitPiranhaPlant:
    LDA #$01  ; set initial speed
    STA PiranhaPlant_Y_Speed,x
    LSR
    STA Enemy_State,x  ; initialize enemy state and what would normally
    STA PiranhaPlant_MoveFlag,x  ; be used as vertical speed, but not in this case
    LDA Enemy_Y_Position,x
    STA PiranhaPlantDownYPos,x  ; save original vertical coordinate here
    SEC
    SBC #$18
    STA PiranhaPlantUpYPos,x  ; save original vertical coordinate - 24 pixels here
    LDA #$09
    JMP SetBBox2  ; set specific value for bounding box control

; --------------------------------

InitEnemyFrenzy:
    LDA Enemy_ID,x  ; load enemy identifier
    STA EnemyFrenzyBuffer  ; save in enemy frenzy buffer
    SEC
    SBC #$12  ; subtract 12 and use as offset for jump engine
    JSR JumpEngine

; frenzy object jump table
    .word LakituAndSpinyHandler
    .word NoFrenzyCode
    .word InitFlyingCheepCheep
    .word InitBowserFlame
    .word InitFireworks
    .word BulletBillCheepCheep

; --------------------------------

NoFrenzyCode:
    RTS

; --------------------------------

EndFrenzy:
    LDY #$05  ; start at last slot
LakituChk:
    LDA Enemy_ID,y  ; check enemy identifiers
    CMP #Lakitu  ; for lakitu
    BNE NextFSlot
    LDA #$01  ; if found, set state
    STA Enemy_State,y
NextFSlot:
    DEY  ; move onto the next slot
    BPL LakituChk  ; do this until all slots are checked
    LDA #$00
    STA EnemyFrenzyBuffer  ; empty enemy frenzy buffer
    STA Enemy_Flag,x  ; disable enemy buffer flag for this object
    RTS

; --------------------------------

InitJumpGPTroopa:
    LDA #$02  ; set for movement to the left
    STA Enemy_MovingDir,x
    LDA #$f8  ; set horizontal speed
    STA Enemy_X_Speed,x
TallBBox2:
    LDA #$03  ; set specific value for bounding box control
SetBBox2:
    STA Enemy_BoundBoxCtrl,x  ; set bounding box control then leave
    RTS

; --------------------------------

InitBalPlatform:
    DEC Enemy_Y_Position,x  ; raise vertical position by two pixels
    DEC Enemy_Y_Position,x
    LDY SecondaryHardMode  ; if secondary hard mode flag not set,
    BNE AlignP  ; branch ahead
    LDY #$02  ; otherwise set value here
    JSR PosPlatform  ; do a sub to add or subtract pixels
AlignP:
    LDY #$ff  ; set default value here for now
    LDA BalPlatformAlignment  ; get current balance platform alignment
    STA Enemy_State,x  ; set platform alignment to object state here
    BPL SetBPA  ; if old alignment $ff, put $ff as alignment for negative
    TXA  ; if old contents already $ff, put
    TAY  ; object offset as alignment to make next positive
SetBPA:
    STY BalPlatformAlignment  ; store whatever value's in Y here
    LDA #$00
    STA Enemy_MovingDir,x  ; init moving direction
    TAY  ; init Y
    JSR PosPlatform  ; do a sub to add 8 pixels, then run shared code here

; --------------------------------

InitDropPlatform:
    LDA #$ff
    STA PlatformCollisionFlag,x  ; set some value here
    JMP CommonPlatCode  ; then jump ahead to execute more code

; --------------------------------

InitHoriPlatform:
    LDA #$00
    STA XMoveSecondaryCounter,x  ; init one of the moving counters
    JMP CommonPlatCode  ; jump ahead to execute more code

; --------------------------------

InitVertPlatform:
    LDY #$40  ; set default value here
    LDA Enemy_Y_Position,x  ; check vertical position
    BPL SetYO  ; if above a certain point, skip this part
    EOR #$ff
    CLC  ; otherwise get two's compliment
    ADC #$01
    LDY #$c0  ; get alternate value to add to vertical position
SetYO:
    STA YPlatformTopYPos,x  ; save as top vertical position
    TYA
    CLC  ; load value from earlier, add number of pixels
    ADC Enemy_Y_Position,x  ; to vertical position
    STA YPlatformCenterYPos,x  ; save result as central vertical position

; --------------------------------

CommonPlatCode:
    JSR InitVStf  ; do a sub to init certain other values
SPBBox:
    LDA #$05  ; set default bounding box size control
    LDY AreaType
    CPY #$03  ; check for castle-type level
    BEQ CasPBB  ; use default value if found
    LDY SecondaryHardMode  ; otherwise check for secondary hard mode flag
    BNE CasPBB  ; if set, use default value
    LDA #$06  ; use alternate value if not castle or secondary not set
CasPBB:
    STA Enemy_BoundBoxCtrl,x  ; set bounding box size control here and leave
    RTS

; --------------------------------

LargeLiftUp:
    JSR PlatLiftUp  ; execute code for platforms going up
    JMP LargeLiftBBox  ; overwrite bounding box for large platforms

LargeLiftDown:
    JSR PlatLiftDown  ; execute code for platforms going down

LargeLiftBBox:
    JMP SPBBox  ; jump to overwrite bounding box size control

; --------------------------------

PlatLiftUp:
    LDA #$10  ; set movement amount here
    STA Enemy_Y_MoveForce,x
    LDA #$ff  ; set moving speed for platforms going up
    STA Enemy_Y_Speed,x
    JMP CommonSmallLift  ; skip ahead to part we should be executing

; --------------------------------

PlatLiftDown:
    LDA #$f0  ; set movement amount here
    STA Enemy_Y_MoveForce,x
    LDA #$00  ; set moving speed for platforms going down
    STA Enemy_Y_Speed,x

; --------------------------------

CommonSmallLift:
    LDY #$01
    JSR PosPlatform  ; do a sub to add 12 pixels due to preset value
    LDA #$04
    STA Enemy_BoundBoxCtrl,x  ; set bounding box control for small platforms
    RTS

; --------------------------------

PlatPosDataLow:
    .byte $08,$0c,$f8

PlatPosDataHigh:
    .byte $00,$00,$ff

PosPlatform:
    LDA Enemy_X_Position,x  ; get horizontal coordinate
    CLC
    ADC PlatPosDataLow,y  ; add or subtract pixels depending on offset
    STA Enemy_X_Position,x  ; store as new horizontal coordinate
    LDA Enemy_PageLoc,x
    ADC PlatPosDataHigh,y  ; add or subtract page location depending on offset
    STA Enemy_PageLoc,x  ; store as new page location
    RTS  ; and go back

; --------------------------------

EndOfEnemyInitCode:
    RTS
