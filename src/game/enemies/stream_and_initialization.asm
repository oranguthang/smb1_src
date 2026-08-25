; -------------------------------------------------------------------------------------

EnemiesAndLoopsCore:
    LDA Enemy_Flag,x  ; check data here for MSB set
    PHA  ; save in stack
    ASL
    BCS ChkBowserF  ; if MSB set in enemy flag, branch ahead of jumps
    PLA  ; get from stack
    BEQ ChkAreaTsk  ; if data zero, branch
    JMP RunEnemyObjectsCore  ; otherwise, jump to run enemy subroutines
ChkAreaTsk:
    LDA AreaParserTaskNum  ; check number of tasks to perform
    AND #$07
    CMP #$07  ; if at a specific task, jump and leave
    BEQ ExitELCore
    JMP ProcLoopCommand  ; otherwise, jump to process loop command/load enemies
ChkBowserF:
    PLA  ; get data from stack
    AND #%00001111  ; mask out high nybble
    TAY
    LDA Enemy_Flag,y  ; use as pointer and load same place with different offset
    BNE ExitELCore
    STA Enemy_Flag,x  ; if second enemy flag not set, also clear first one
ExitELCore:
    RTS

; --------------------------------

; loop command data
LoopCmdWorldNumber:
    .byte $03, $03, $06, $06, $06, $06, $06, $06, $07, $07, $07

LoopCmdPageNumber:
    .byte $05, $09, $04, $05, $06, $08, $09, $0a, $06, $0b, $10

LoopCmdYPosition:
    .byte $40, $b0, $b0, $80, $40, $40, $80, $40, $f0, $f0, $f0

ExecGameLoopback:
    LDA Player_PageLoc  ; send player back four pages
    SEC
    SBC #$04
    STA Player_PageLoc
    LDA CurrentPageLoc  ; send current page back four pages
    SEC
    SBC #$04
    STA CurrentPageLoc
    LDA ScreenLeft_PageLoc  ; subtract four from page location
    SEC  ; of screen's left border
    SBC #$04
    STA ScreenLeft_PageLoc
    LDA ScreenRight_PageLoc  ; do the same for the page location
    SEC  ; of screen's right border
    SBC #$04
    STA ScreenRight_PageLoc
    LDA AreaObjectPageLoc  ; subtract four from page control
    SEC  ; for area objects
    SBC #$04
    STA AreaObjectPageLoc
    LDA #$00  ; initialize page select for both
    STA EnemyObjectPageSel  ; area and enemy objects
    STA AreaObjectPageSel
    STA EnemyDataOffset  ; initialize enemy object data offset
    STA EnemyObjectPageLoc  ; and enemy object page control
    LDA AreaDataOfsLoopback,y  ; adjust area object offset based on
    STA AreaDataOffset  ; which loop command we encountered
    RTS

ProcLoopCommand:
    LDA LoopCommand  ; check if loop command was found
    BEQ ChkEnemyFrenzy
    LDA CurrentColumnPos  ; check to see if we're still on the first page
    BNE ChkEnemyFrenzy  ; if not, do not loop yet
    LDY #$0b  ; start at the end of each set of loop data
FindLoop:
    DEY
    BMI ChkEnemyFrenzy  ; if all data is checked and not match, do not loop
    LDA WorldNumber  ; check to see if one of the world numbers
    CMP LoopCmdWorldNumber,y  ; matches our current world number
    BNE FindLoop
    LDA CurrentPageLoc  ; check to see if one of the page numbers
    CMP LoopCmdPageNumber,y  ; matches the page we're currently on
    BNE FindLoop
    LDA Player_Y_Position  ; check to see if the player is at the correct position
    CMP LoopCmdYPosition,y  ; if not, branch to check for world 7
    BNE WrongChk
    LDA Player_State  ; check to see if the player is
    CMP #$00  ; on solid ground (i.e. not jumping or falling)
    BNE WrongChk  ; if not, player fails to pass loop, and loopback
    LDA WorldNumber  ; are we in world 7? (check performed on correct
    CMP #World7  ; vertical position and on solid ground)
    BNE InitMLp  ; if not, initialize flags used there, otherwise
    INC MultiLoopCorrectCntr  ; increment counter for correct progression
IncMLoop:
    INC MultiLoopPassCntr  ; increment master multi-part counter
    LDA MultiLoopPassCntr  ; have we done all three parts?
    CMP #$03
    BNE InitLCmd  ; if not, skip this part
    LDA MultiLoopCorrectCntr  ; if so, have we done them all correctly?
    CMP #$03
    BEQ InitMLp  ; if so, branch past unnecessary check here
    BNE DoLpBack  ; unconditional branch if previous branch fails
WrongChk:
    LDA WorldNumber  ; are we in world 7? (check performed on
    CMP #World7  ; incorrect vertical position or not on solid ground)
    BEQ IncMLoop
DoLpBack:
    JSR ExecGameLoopback  ; if player is not in right place, loop back
    JSR KillAllEnemies
InitMLp:
    LDA #$00  ; initialize counters used for multi-part loop commands
    STA MultiLoopPassCntr
    STA MultiLoopCorrectCntr
InitLCmd:
    LDA #$00  ; initialize loop command flag
    STA LoopCommand

; --------------------------------

ChkEnemyFrenzy:
    LDA EnemyFrenzyQueue  ; check for enemy object in frenzy queue
    BEQ ProcessEnemyData  ; if not, skip this part
    STA Enemy_ID,x  ; store as enemy object identifier here
    LDA #$01
    STA Enemy_Flag,x  ; activate enemy object flag
    LDA #$00
    STA Enemy_State,x  ; initialize state and frenzy queue
    STA EnemyFrenzyQueue
    JMP InitEnemyObject  ; and then jump to deal with this enemy

; --------------------------------
; $06 - used to hold page location of extended right boundary
; $07 - used to hold high nybble of position of extended right boundary

ProcessEnemyData:
    LDY EnemyDataOffset  ; get offset of enemy object data
    LDA (EnemyData),y  ; load first byte
    CMP #$ff  ; check for EOD terminator
    BNE CheckEndofBuffer
    JMP CheckFrenzyBuffer  ; if found, jump to check frenzy buffer, otherwise

CheckEndofBuffer:
    AND #%00001111  ; check for special row $0e
    CMP #$0e
    BEQ CheckRightBounds  ; if found, branch, otherwise
    CPX #$05  ; check for end of buffer
    BCC CheckRightBounds  ; if not at end of buffer, branch
    INY
    LDA (EnemyData),y  ; check for specific value here
    AND #%00111111  ; not sure what this was intended for, exactly
    CMP #$2e  ; this part is quite possibly residual code
    BEQ CheckRightBounds  ; but it has the effect of keeping enemies out of
    RTS  ; the sixth slot

CheckRightBounds:
    LDA ScreenRight_X_Pos  ; add 48 to pixel coordinate of right boundary
    CLC
    ADC #$30
    AND #%11110000  ; store high nybble
    STA $07
    LDA ScreenRight_PageLoc  ; add carry to page location of right boundary
    ADC #$00
    STA $06  ; store page location + carry
    LDY EnemyDataOffset
    INY
    LDA (EnemyData),y  ; if MSB of enemy object is clear, branch to check for row $0f
    ASL
    BCC CheckPageCtrlRow
    LDA EnemyObjectPageSel  ; if page select already set, do not set again
    BNE CheckPageCtrlRow
    INC EnemyObjectPageSel  ; otherwise, if MSB is set, set page select
    INC EnemyObjectPageLoc  ; and increment page control

CheckPageCtrlRow:
    DEY
    LDA (EnemyData),y  ; reread first byte
    AND #$0f
    CMP #$0f  ; check for special row $0f
    BNE PositionEnemyObj  ; if not found, branch to position enemy object
    LDA EnemyObjectPageSel  ; if page select set,
    BNE PositionEnemyObj  ; branch without reading second byte
    INY
    LDA (EnemyData),y  ; otherwise, get second byte, mask out 2 MSB
    AND #%00111111
    STA EnemyObjectPageLoc  ; store as page control for enemy object data
    INC EnemyDataOffset  ; increment enemy object data offset 2 bytes
    INC EnemyDataOffset
    INC EnemyObjectPageSel  ; set page select for enemy object data and
    JMP ProcLoopCommand  ; jump back to process loop commands again

PositionEnemyObj:
    LDA EnemyObjectPageLoc  ; store page control as page location
    STA Enemy_PageLoc,x  ; for enemy object
    LDA (EnemyData),y  ; get first byte of enemy object
    AND #%11110000
    STA Enemy_X_Position,x  ; store column position
    CMP ScreenRight_X_Pos  ; check column position against right boundary
    LDA Enemy_PageLoc,x  ; without subtracting, then subtract borrow
    SBC ScreenRight_PageLoc  ; from page location
    BCS CheckRightExtBounds  ; if enemy object beyond or at boundary, branch
    LDA (EnemyData),y
    AND #%00001111  ; check for special row $0e
    CMP #$0e  ; if found, jump elsewhere
    BEQ ParseRow0e
    JMP CheckThreeBytes  ; if not found, unconditional jump

CheckRightExtBounds:
    LDA $07  ; check right boundary + 48 against
    CMP Enemy_X_Position,x  ; column position without subtracting,
    LDA $06  ; then subtract borrow from page control temp
    SBC Enemy_PageLoc,x  ; plus carry
    BCC CheckFrenzyBuffer  ; if enemy object beyond extended boundary, branch
    LDA #$01  ; store value in vertical high byte
    STA Enemy_Y_HighPos,x
    LDA (EnemyData),y  ; get first byte again
    ASL  ; multiply by four to get the vertical
    ASL  ; coordinate
    ASL
    ASL
    STA Enemy_Y_Position,x
    CMP #$e0  ; do one last check for special row $0e
    BEQ ParseRow0e  ; (necessary if branched to $c1cb)
    INY
    LDA (EnemyData),y  ; get second byte of object
    AND #%01000000  ; check to see if hard mode bit is set
    BEQ CheckForEnemyGroup  ; if not, branch to check for group enemy objects
    LDA SecondaryHardMode  ; if set, check to see if secondary hard mode flag
    BEQ Inc2B  ; is on, and if not, branch to skip this object completely

CheckForEnemyGroup:
    LDA (EnemyData),y  ; get second byte and mask out 2 MSB
    AND #%00111111
    CMP #$37  ; check for value below $37
    BCC BuzzyBeetleMutate
    CMP #$3f  ; if $37 or greater, check for value
    BCC DoGroup  ; below $3f, branch if below $3f

BuzzyBeetleMutate:
    CMP #Goomba  ; if below $37, check for goomba
    BNE StrID  ; value ($3f or more always fails)
    LDY PrimaryHardMode  ; check if primary hard mode flag is set
    BEQ StrID  ; and if so, change goomba to buzzy beetle
    LDA #BuzzyBeetle
StrID:
    STA Enemy_ID,x  ; store enemy object number into buffer
    LDA #$01
    STA Enemy_Flag,x  ; set flag for enemy in buffer
    JSR InitEnemyObject
    LDA Enemy_Flag,x  ; check to see if flag is set
    BNE Inc2B  ; if not, leave, otherwise branch
    RTS

CheckFrenzyBuffer:
    LDA EnemyFrenzyBuffer  ; if enemy object stored in frenzy buffer
    BNE StrFre  ; then branch ahead to store in enemy object buffer
    LDA VineFlagOffset  ; otherwise check vine flag offset
    CMP #$01
    BNE ExEPar  ; if other value <> 1, leave
    LDA #VineObject  ; otherwise put vine in enemy identifier
StrFre:
    STA Enemy_ID,x  ; store contents of frenzy buffer into enemy identifier value

InitEnemyObject:
    LDA #$00  ; initialize enemy state
    STA Enemy_State,x
    JSR CheckpointEnemyID  ; jump ahead to run jump engine and subroutines
ExEPar:
    RTS  ; then leave

DoGroup:
    JMP HandleGroupEnemies  ; handle enemy group objects

ParseRow0e:
    INY  ; increment Y to load third byte of object
    INY
    LDA (EnemyData),y
    LSR  ; move 3 MSB to the bottom, effectively
    LSR  ; making %xxx00000 into %00000xxx
    LSR
    LSR
    LSR
    CMP WorldNumber  ; is it the same world number as we're on?
    BNE NotUse  ; if not, do not use (this allows multiple uses
    DEY  ; of the same area, like the underground bonus areas)
    LDA (EnemyData),y  ; otherwise, get second byte and use as offset
    STA AreaPointer  ; to addresses for level and enemy object data
    INY
    LDA (EnemyData),y  ; get third byte again, and this time mask out
    AND #%00011111  ; the 3 MSB from before, save as page number to be
    STA EntrancePage  ; used upon entry to area, if area is entered
NotUse:
    JMP Inc3B

CheckThreeBytes:
    LDY EnemyDataOffset  ; load current offset for enemy object data
    LDA (EnemyData),y  ; get first byte
    AND #%00001111  ; check for special row $0e
    CMP #$0e
    BNE Inc2B
Inc3B:
    INC EnemyDataOffset  ; if row = $0e, increment three bytes
Inc2B:
    INC EnemyDataOffset  ; otherwise increment two bytes
    INC EnemyDataOffset
    LDA #$00  ; init page select for enemy objects
    STA EnemyObjectPageSel
    LDX ObjectOffset  ; reload current offset in enemy buffers
    RTS  ; and leave

CheckpointEnemyID:
    LDA Enemy_ID,x
    CMP #$15  ; check enemy object identifier for $15 or greater
    BCS InitEnemyRoutines  ; and branch straight to the jump engine if found
    TAY  ; save identifier in Y register for now
    LDA Enemy_Y_Position,x
    ADC #$08  ; add eight pixels to what will eventually be the
    STA Enemy_Y_Position,x  ; enemy object's vertical coordinate ($00-$14 only)
    LDA #$01
    STA EnemyOffscrBitsMasked,x  ; set offscreen masked bit
    TYA  ; get identifier back and use as offset for jump engine

InitEnemyRoutines:
    JSR sub_dispatch_inline_handler

; jump engine table for newly loaded enemy objects

    .word InitNormalEnemy  ; for objects $00-$0f
    .word InitNormalEnemy
    .word InitNormalEnemy
    .word InitRedKoopa
    .word NoInitCode
    .word InitHammerBro
    .word InitGoomba
    .word InitBloober
    .word InitBulletBill
    .word NoInitCode
    .word InitCheepCheep
    .word InitCheepCheep
    .word InitPodoboo
    .word InitPiranhaPlant
    .word InitJumpGPTroopa
    .word InitRedPTroopa

    .word InitHorizFlySwimEnemy  ; for objects $10-$1f
    .word InitLakitu
    .word InitEnemyFrenzy
    .word NoInitCode
    .word InitEnemyFrenzy
    .word InitEnemyFrenzy
    .word InitEnemyFrenzy
    .word InitEnemyFrenzy
    .word EndFrenzy
    .word NoInitCode
    .word NoInitCode
    .word InitShortFirebar
    .word InitShortFirebar
    .word InitShortFirebar
    .word InitShortFirebar
    .word InitLongFirebar

    .word NoInitCode  ; for objects $20-$2f
    .word NoInitCode
    .word NoInitCode
    .word NoInitCode
    .word InitBalPlatform
    .word InitVertPlatform
    .word LargeLiftUp
    .word LargeLiftDown
    .word InitHoriPlatform
    .word InitDropPlatform
    .word InitHoriPlatform
    .word PlatLiftUp
    .word PlatLiftDown
    .word InitBowser
    .word PwrUpJmp  ; possibly dummy value
    .word Setup_Vine

    .word NoInitCode  ; for objects $30-$36
    .word NoInitCode
    .word NoInitCode
    .word NoInitCode
    .word NoInitCode
    .word InitRetainerObj
    .word EndOfEnemyInitCode

; -------------------------------------------------------------------------------------

NoInitCode:
    RTS  ; this executed when enemy object has no init code

; --------------------------------

InitGoomba:
    JSR InitNormalEnemy  ; set appropriate horizontal speed
    JMP SmallBBox  ; set $09 as bounding box control, set other values

; --------------------------------

InitPodoboo:
    LDA #$02  ; set enemy position to below
    STA Enemy_Y_HighPos,x  ; the bottom of the screen
    STA Enemy_Y_Position,x
    LSR
    STA EnemyIntervalTimer,x  ; set timer for enemy
    LSR
    STA Enemy_State,x  ; initialize enemy state, then jump to use
    JMP SmallBBox  ; $09 as bounding box size and set other things

; --------------------------------

InitRetainerObj:
    LDA #$b8  ; set fixed vertical position for
    STA Enemy_Y_Position,x  ; princess/mushroom retainer object
    RTS

; --------------------------------

NormalXSpdData:
    .byte $f8, $f4

InitNormalEnemy:
    LDY #$01  ; load offset of 1 by default
    LDA PrimaryHardMode  ; check for primary hard mode flag set
    BNE GetESpd
    DEY  ; if not set, decrement offset
GetESpd:
    LDA NormalXSpdData,y  ; get appropriate horizontal speed
SetESpd:
    STA Enemy_X_Speed,x  ; store as speed for enemy object
    JMP TallBBox  ; branch to set bounding box control and other data

; --------------------------------

InitRedKoopa:
    JSR InitNormalEnemy  ; load appropriate horizontal speed
    LDA #$01  ; set enemy state for red koopa troopa $03
    STA Enemy_State,x
    RTS

; --------------------------------

HBroWalkingTimerData:
    .byte $80, $50

InitHammerBro:
    LDA #$00  ; init horizontal speed and timer used by hammer bro
    STA HammerThrowingTimer,x  ; apparently to time hammer throwing
    STA Enemy_X_Speed,x
    LDY SecondaryHardMode  ; get secondary hard mode flag
    LDA HBroWalkingTimerData,y
    STA EnemyIntervalTimer,x  ; set value as delay for hammer bro to walk left
    LDA #$0b  ; set specific value for bounding box size control
    JMP SetBBox

; --------------------------------

InitHorizFlySwimEnemy:
    LDA #$00  ; initialize horizontal speed
    JMP SetESpd

; --------------------------------

InitBloober:
    LDA #$00  ; initialize horizontal speed
    STA BlooperMoveSpeed,x
SmallBBox:
    LDA #$09  ; set specific bounding box size control
    BNE SetBBox  ; unconditional branch

; --------------------------------

InitRedPTroopa:
    LDY #$30  ; load central position adder for 48 pixels down
    LDA Enemy_Y_Position,x  ; set vertical coordinate into location to
    STA RedPTroopaOrigXPos,x  ; be used as original vertical coordinate
    BPL GetCent  ; if vertical coordinate < $80
    LDY #$e0  ; if => $80, load position adder for 32 pixels up
GetCent:
    TYA  ; send central position adder to A
    ADC Enemy_Y_Position,x  ; add to current vertical coordinate
    STA RedPTroopaCenterYPos,x  ; store as central vertical coordinate
TallBBox:
    LDA #$03  ; set specific bounding box size control
SetBBox:
    STA Enemy_BoundBoxCtrl,x  ; set bounding box control here
    LDA #$02  ; set moving direction for left
    STA Enemy_MovingDir,x
InitVStf:
    LDA #$00  ; initialize vertical speed
    STA Enemy_Y_Speed,x  ; and movement force
    STA Enemy_Y_MoveForce,x
    RTS

; --------------------------------

InitBulletBill:
    LDA #$02  ; set moving direction for left
    STA Enemy_MovingDir,x
    LDA #$09  ; set bounding box control for $09
    STA Enemy_BoundBoxCtrl,x
    RTS

; --------------------------------

InitCheepCheep:
    JSR SmallBBox  ; set vertical bounding box, speed, init others
    LDA PseudoRandomBitReg,x  ; check one portion of LSFR
    AND #%00010000  ; get d4 from it
    STA CheepCheepMoveMFlag,x  ; save as movement flag of some sort
    LDA Enemy_Y_Position,x
    STA CheepCheepOrigYPos,x  ; save original vertical coordinate here
    RTS

; --------------------------------

InitLakitu:
    LDA EnemyFrenzyBuffer  ; check to see if an enemy is already in
    BNE KillLakitu  ; the frenzy buffer, and branch to kill lakitu if so

SetupLakitu:
    LDA #$00  ; erase counter for lakitu's reappearance
    STA LakituReappearTimer
    JSR InitHorizFlySwimEnemy  ; set $03 as bounding box, set other attributes
    JMP TallBBox2  ; set $03 as bounding box again (not necessary) and leave

KillLakitu:
    JMP EraseEnemyObject

; --------------------------------
; $01-$03 - used to hold pseudorandom difference adjusters

PRDiffAdjustData:
    .byte $26, $2c, $32, $38
    .byte $20, $22, $24, $26
    .byte $13, $14, $15, $16

LakituAndSpinyHandler:
    LDA FrenzyEnemyTimer  ; if timer here not expired, leave
    BNE ExLSHand
    CPX #$05  ; if we are on the special use slot, leave
    BCS ExLSHand
    LDA #$80  ; set timer
    STA FrenzyEnemyTimer
    LDY #$04  ; start with the last enemy slot
ChkLak:
    LDA Enemy_ID,y  ; check all enemy slots to see
    CMP #Lakitu  ; if lakitu is on one of them
    BEQ CreateSpiny  ; if so, branch out of this loop
    DEY  ; otherwise check another slot
    BPL ChkLak  ; loop until all slots are checked
    INC LakituReappearTimer  ; increment reappearance timer
    LDA LakituReappearTimer
    CMP #$07  ; check to see if we're up to a certain value yet
    BCC ExLSHand  ; if not, leave
    LDX #$04  ; start with the last enemy slot again
ChkNoEn:
    LDA Enemy_Flag,x  ; check enemy buffer flag for non-active enemy slot
    BEQ CreateL  ; branch out of loop if found
    DEX  ; otherwise check next slot
    BPL ChkNoEn  ; branch until all slots are checked
    BMI RetEOfs  ; if no empty slots were found, branch to leave
CreateL:
    LDA #$00  ; initialize enemy state
    STA Enemy_State,x
    LDA #Lakitu  ; create lakitu enemy object
    STA Enemy_ID,x
    JSR SetupLakitu  ; do a sub to set up lakitu
    LDA #$20
    JSR PutAtRightExtent  ; finish setting up lakitu
RetEOfs:
    LDX ObjectOffset  ; get enemy object buffer offset again and leave
ExLSHand:
    RTS

; --------------------------------

CreateSpiny:
    LDA Player_Y_Position  ; if player above a certain point, branch to leave
    CMP #$2c
    BCC ExLSHand
    LDA Enemy_State,y  ; if lakitu is not in normal state, branch to leave
    BNE ExLSHand
    LDA Enemy_PageLoc,y  ; store horizontal coordinates (high and low) of lakitu
    STA Enemy_PageLoc,x  ; into the coordinates of the spiny we're going to create
    LDA Enemy_X_Position,y
    STA Enemy_X_Position,x
    LDA #$01  ; put spiny within vertical screen unit
    STA Enemy_Y_HighPos,x
    LDA Enemy_Y_Position,y  ; put spiny eight pixels above where lakitu is
    SEC
    SBC #$08
    STA Enemy_Y_Position,x
    LDA PseudoRandomBitReg,x  ; get 2 LSB of LSFR and save to Y
    AND #%00000011
    TAY
    LDX #$02
DifLoop:
    LDA PRDiffAdjustData,y  ; get three values and save them
    STA $01,x  ; to $01-$03
    INY
    INY  ; increment Y four bytes for each value
    INY
    INY
    DEX  ; decrement X for each one
    BPL DifLoop  ; loop until all three are written
    LDX ObjectOffset  ; get enemy object buffer offset
    JSR PlayerLakituDiff  ; move enemy, change direction, get value - difference
    LDY Player_X_Speed  ; check player's horizontal speed
    CPY #$08
    BCS SetSpSpd  ; if moving faster than a certain amount, branch elsewhere
    TAY  ; otherwise save value in A to Y for now
    LDA PseudoRandomBitReg+1,x
    AND #%00000011  ; get one of the LSFR parts and save the 2 LSB
    BEQ UsePosv  ; branch if neither bits are set
    TYA
    EOR #%11111111  ; otherwise get two's compliment of Y
    TAY
    INY
UsePosv:
    TYA  ; put value from A in Y back to A (they will be lost anyway)
SetSpSpd:
    JSR SmallBBox  ; set bounding box control, init attributes, lose contents of A
    LDY #$02
    STA Enemy_X_Speed,x  ; set horizontal speed to zero because previous contents
    CMP #$00  ; of A were lost...branch here will never be taken for
    BMI SpinyRte  ; the same reason
    DEY
SpinyRte:
    STY Enemy_MovingDir,x  ; set moving direction to the right
    LDA #$fd
    STA Enemy_Y_Speed,x  ; set vertical speed to move upwards
    LDA #$01
    STA Enemy_Flag,x  ; enable enemy object by setting flag
    LDA #$05
    STA Enemy_State,x  ; put spiny in egg state and leave
ChpChpEx:
    RTS
