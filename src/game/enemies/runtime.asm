; -------------------------------------------------------------------------------------

RunEnemyObjectsCore:
    LDX ObjectOffset  ; get offset for enemy object buffer
    LDA #$00  ; load value 0 for jump engine by default
    LDY Enemy_ID,x
    CPY #$15  ; if enemy object < $15, use default value
    BCC JmpEO
    TYA  ; otherwise subtract $14 from the value and use
    SBC #$14  ; as value for jump engine
JmpEO:
    JSR JumpEngine

    .word RunNormalEnemies  ; for objects $00-$14

    .word RunBowserFlame  ; for objects $15-$1f
    .word RunFireworks
    .word NoRunCode
    .word NoRunCode
    .word NoRunCode
    .word NoRunCode
    .word RunFirebarObj
    .word RunFirebarObj
    .word RunFirebarObj
    .word RunFirebarObj
    .word RunFirebarObj

    .word RunFirebarObj  ; for objects $20-$2f
    .word RunFirebarObj
    .word RunFirebarObj
    .word NoRunCode
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunSmallPlatform
    .word RunSmallPlatform
    .word RunBowser
    .word PowerUpObjHandler
    .word VineObjectHandler

    .word NoRunCode  ; for objects $30-$35
    .word RunStarFlagObj
    .word JumpspringHandler
    .word NoRunCode
    .word WarpZoneObject
    .word RunRetainerObj

; --------------------------------

NoRunCode:
    RTS

; --------------------------------

RunRetainerObj:
    JSR GetEnemyOffscreenBits
    JSR RelativeEnemyPosition
    JMP EnemyGfxHandler

; --------------------------------

RunNormalEnemies:
    LDA #$00  ; init sprite attributes
    STA Enemy_SprAttrib,x
    JSR GetEnemyOffscreenBits
    JSR RelativeEnemyPosition
    JSR EnemyGfxHandler
    JSR GetEnemyBoundBox
    JSR EnemyToBGCollisionDet
    JSR EnemiesCollision
    JSR PlayerEnemyCollision
    LDY TimerControl  ; if master timer control set, skip to last routine
    BNE SkipMove
    JSR EnemyMovementSubs
SkipMove:
    JMP OffscreenBoundsCheck

EnemyMovementSubs:
    LDA Enemy_ID,x
    JSR JumpEngine

    .word MoveNormalEnemy  ; only objects $00-$14 use this table
    .word MoveNormalEnemy
    .word MoveNormalEnemy
    .word MoveNormalEnemy
    .word MoveNormalEnemy
    .word ProcHammerBro
    .word MoveNormalEnemy
    .word MoveBloober
    .word MoveBulletBill
    .word NoMoveCode
    .word MoveSwimmingCheepCheep
    .word MoveSwimmingCheepCheep
    .word MovePodoboo
    .word MovePiranhaPlant
    .word MoveJumpingEnemy
    .word ProcMoveRedPTroopa
    .word MoveFlyGreenPTroopa
    .word MoveLakitu
    .word MoveNormalEnemy
    .word NoMoveCode  ; dummy
    .word MoveFlyingCheepCheep

; --------------------------------

NoMoveCode:
    RTS

; --------------------------------

RunBowserFlame:
    JSR ProcBowserFlame
    JSR GetEnemyOffscreenBits
    JSR RelativeEnemyPosition
    JSR GetEnemyBoundBox
    JSR PlayerEnemyCollision
    JMP OffscreenBoundsCheck

; --------------------------------

RunFirebarObj:
    JSR ProcFirebar
    JMP OffscreenBoundsCheck

; --------------------------------

RunSmallPlatform:
    JSR GetEnemyOffscreenBits
    JSR RelativeEnemyPosition
    JSR SmallPlatformBoundBox
    JSR SmallPlatformCollision
    JSR RelativeEnemyPosition
    JSR DrawSmallPlatform
    JSR MoveSmallPlatform
    JMP OffscreenBoundsCheck

; --------------------------------

RunLargePlatform:
    JSR GetEnemyOffscreenBits
    JSR RelativeEnemyPosition
    JSR LargePlatformBoundBox
    JSR LargePlatformCollision
    LDA TimerControl  ; if master timer control set,
    BNE SkipPT  ; skip subroutine tree
    JSR LargePlatformSubroutines
SkipPT:
    JSR RelativeEnemyPosition
    JSR DrawLargePlatform
    JMP OffscreenBoundsCheck

; --------------------------------

LargePlatformSubroutines:
    LDA Enemy_ID,x  ; subtract $24 to get proper offset for jump table
    SEC
    SBC #$24
    JSR JumpEngine

    .word BalancePlatform  ; table used by objects $24-$2a
    .word YMovingPlatform
    .word MoveLargeLiftPlat
    .word MoveLargeLiftPlat
    .word XMovingPlatform
    .word DropPlatform
    .word RightPlatform

; -------------------------------------------------------------------------------------

EraseEnemyObject:
    LDA #$00  ; clear all enemy object variables
    STA Enemy_Flag,x
    STA Enemy_ID,x
    STA Enemy_State,x
    STA FloateyNum_Control,x
    STA EnemyIntervalTimer,x
    STA ShellChainCounter,x
    STA Enemy_SprAttrib,x
    STA EnemyFrameTimer,x
    RTS

; -------------------------------------------------------------------------------------

MovePodoboo:
    LDA EnemyIntervalTimer,x  ; check enemy timer
    BNE PdbM  ; branch to move enemy if not expired
    JSR InitPodoboo  ; otherwise set up podoboo again
    LDA PseudoRandomBitReg+1,x  ; get part of LSFR
    ORA #%10000000  ; set d7
    STA Enemy_Y_MoveForce,x  ; store as movement force
    AND #%00001111  ; mask out high nybble
    ORA #$06  ; set for at least six intervals
    STA EnemyIntervalTimer,x  ; store as new enemy timer
    LDA #$f9
    STA Enemy_Y_Speed,x  ; set vertical speed to move podoboo upwards
PdbM:
    JMP MoveJ_EnemyVertically  ; branch to impose gravity on podoboo

; --------------------------------
; $00 - used in HammerBroJumpCode as bitmask

HammerThrowTmrData:
    .byte $30, $1c

XSpeedAdderData:
    .byte $00, $e8, $00, $18

RevivedXSpeed:
    .byte $08, $f8, $0c, $f4

ProcHammerBro:
    LDA Enemy_State,x  ; check hammer bro's enemy state for d5 set
    AND #%00100000
    BEQ ChkJH  ; if not set, go ahead with code
    JMP MoveDefeatedEnemy  ; otherwise jump to something else
ChkJH:
    LDA HammerBroJumpTimer,x  ; check jump timer
    BEQ HammerBroJumpCode  ; if expired, branch to jump
    DEC HammerBroJumpTimer,x  ; otherwise decrement jump timer
    LDA Enemy_OffscreenBits
    AND #%00001100  ; check offscreen bits
    BNE MoveHammerBroXDir  ; if hammer bro a little offscreen, skip to movement code
    LDA HammerThrowingTimer,x  ; check hammer throwing timer
    BNE DecHT  ; if not expired, skip ahead, do not throw hammer
    LDY SecondaryHardMode  ; otherwise get secondary hard mode flag
    LDA HammerThrowTmrData,y  ; get timer data using flag as offset
    STA HammerThrowingTimer,x  ; set as new timer
    JSR SpawnHammerObj  ; do a sub here to spawn hammer object
    BCC DecHT  ; if carry clear, hammer not spawned, skip to decrement timer
    LDA Enemy_State,x
    ORA #%00001000  ; set d3 in enemy state for hammer throw
    STA Enemy_State,x
    JMP MoveHammerBroXDir  ; jump to move hammer bro
DecHT:
    DEC HammerThrowingTimer,x  ; decrement timer
    JMP MoveHammerBroXDir  ; jump to move hammer bro

HammerBroJumpLData:
    .byte $20, $37

HammerBroJumpCode:
    LDA Enemy_State,x  ; get hammer bro's enemy state
    AND #%00000111  ; mask out all but 3 LSB
    CMP #$01  ; check for d0 set (for jumping)
    BEQ MoveHammerBroXDir  ; if set, branch ahead to moving code
    LDA #$00  ; load default value here
    STA $00  ; save into temp variable for now
    LDY #$fa  ; set default vertical speed
    LDA Enemy_Y_Position,x  ; check hammer bro's vertical coordinate
    BMI SetHJ  ; if on the bottom half of the screen, use current speed
    LDY #$fd  ; otherwise set alternate vertical speed
    CMP #$70  ; check to see if hammer bro is above the middle of screen
    INC $00  ; increment preset value to $01
    BCC SetHJ  ; if above the middle of the screen, use current speed and $01
    DEC $00  ; otherwise return value to $00
    LDA PseudoRandomBitReg+1,x  ; get part of LSFR, mask out all but LSB
    AND #$01
    BNE SetHJ  ; if d0 of LSFR set, branch and use current speed and $00
    LDY #$fa  ; otherwise reset to default vertical speed
SetHJ:
    STY Enemy_Y_Speed,x  ; set vertical speed for jumping
    LDA Enemy_State,x  ; set d0 in enemy state for jumping
    ORA #$01
    STA Enemy_State,x
    LDA $00  ; load preset value here to use as bitmask
    AND PseudoRandomBitReg+2,x  ; and do bit-wise comparison with part of LSFR
    TAY  ; then use as offset
    LDA SecondaryHardMode  ; check secondary hard mode flag
    BNE HJump
    TAY  ; if secondary hard mode flag clear, set offset to 0
HJump:
    LDA HammerBroJumpLData,y  ; get jump length timer data using offset from before
    STA EnemyFrameTimer,x  ; save in enemy timer
    LDA PseudoRandomBitReg+1,x
    ORA #%11000000  ; get contents of part of LSFR, set d7 and d6, then
    STA HammerBroJumpTimer,x  ; store in jump timer

MoveHammerBroXDir:
    LDY #$fc  ; move hammer bro a little to the left
    LDA FrameCounter
    AND #%01000000  ; change hammer bro's direction every 64 frames
    BNE Shimmy
    LDY #$04  ; if d6 set in counter, move him a little to the right
Shimmy:
    STY Enemy_X_Speed,x  ; store horizontal speed
    LDY #$01  ; set to face right by default
    JSR PlayerEnemyDiff  ; get horizontal difference between player and hammer bro
    BMI SetShim  ; if enemy to the left of player, skip this part
    INY  ; set to face left
    LDA EnemyIntervalTimer,x  ; check walking timer
    BNE SetShim  ; if not yet expired, skip to set moving direction
    LDA #$f8
    STA Enemy_X_Speed,x  ; otherwise, make the hammer bro walk left towards player
SetShim:
    STY Enemy_MovingDir,x  ; set moving direction

MoveNormalEnemy:
    LDY #$00  ; init Y to leave horizontal movement as-is
    LDA Enemy_State,x
    AND #%01000000  ; check enemy state for d6 set, if set skip
    BNE FallE  ; to move enemy vertically, then horizontally if necessary
    LDA Enemy_State,x
    ASL  ; check enemy state for d7 set
    BCS SteadM  ; if set, branch to move enemy horizontally
    LDA Enemy_State,x
    AND #%00100000  ; check enemy state for d5 set
    BNE MoveDefeatedEnemy  ; if set, branch to move defeated enemy object
    LDA Enemy_State,x
    AND #%00000111  ; check d2-d0 of enemy state for any set bits
    BEQ SteadM  ; if enemy in normal state, branch to move enemy horizontally
    CMP #$05
    BEQ FallE  ; if enemy in state used by spiny's egg, go ahead here
    CMP #$03
    BCS ReviveStunned  ; if enemy in states $03 or $04, skip ahead to yet another part
FallE:
    JSR MoveD_EnemyVertically  ; do a sub here to move enemy downwards
    LDY #$00
    LDA Enemy_State,x  ; check for enemy state $02
    CMP #$02
    BEQ MEHor  ; if found, branch to move enemy horizontally
    AND #%01000000  ; check for d6 set
    BEQ SteadM  ; if not set, branch to something else
    LDA Enemy_ID,x
    CMP #PowerUpObject  ; check for power-up object
    BEQ SteadM
    BNE SlowM  ; if any other object where d6 set, jump to set Y
MEHor:
    JMP MoveEnemyHorizontally  ; jump here to move enemy horizontally for <> $2e and d6 set

SlowM:
    LDY #$01  ; if branched here, increment Y to slow horizontal movement
SteadM:
    LDA Enemy_X_Speed,x  ; get current horizontal speed
    PHA  ; save to stack
    BPL AddHS  ; if not moving or moving right, skip, leave Y alone
    INY
    INY  ; otherwise increment Y to next data
AddHS:
    CLC
    ADC XSpeedAdderData,y  ; add value here to slow enemy down if necessary
    STA Enemy_X_Speed,x  ; save as horizontal speed temporarily
    JSR MoveEnemyHorizontally  ; then do a sub to move horizontally
    PLA
    STA Enemy_X_Speed,x  ; get old horizontal speed from stack and return to
    RTS  ; original memory location, then leave

ReviveStunned:
    LDA EnemyIntervalTimer,x  ; if enemy timer not expired yet,
    BNE ChkKillGoomba  ; skip ahead to something else
    STA Enemy_State,x  ; otherwise initialize enemy state to normal
    LDA FrameCounter
    AND #$01  ; get d0 of frame counter
    TAY  ; use as Y and increment for movement direction
    INY
    STY Enemy_MovingDir,x  ; store as pseudorandom movement direction
    DEY  ; decrement for use as pointer
    LDA PrimaryHardMode  ; check primary hard mode flag
    BEQ SetRSpd  ; if not set, use pointer as-is
    INY
    INY  ; otherwise increment 2 bytes to next data
SetRSpd:
    LDA RevivedXSpeed,y  ; load and store new horizontal speed
    STA Enemy_X_Speed,x  ; and leave
    RTS

MoveDefeatedEnemy:
    JSR MoveD_EnemyVertically  ; execute sub to move defeated enemy downwards
    JMP MoveEnemyHorizontally  ; now move defeated enemy horizontally

ChkKillGoomba:
    CMP #$0e  ; check to see if enemy timer has reached
    BNE NKGmba  ; a certain point, and branch to leave if not
    LDA Enemy_ID,x
    CMP #Goomba  ; check for goomba object
    BNE NKGmba  ; branch if not found
    JSR EraseEnemyObject  ; otherwise, kill this goomba object
NKGmba:
    RTS  ; leave!

; --------------------------------

MoveJumpingEnemy:
    JSR MoveJ_EnemyVertically  ; do a sub to impose gravity on green paratroopa
    JMP MoveEnemyHorizontally  ; jump to move enemy horizontally

; --------------------------------

ProcMoveRedPTroopa:
    LDA Enemy_Y_Speed,x
    ORA Enemy_Y_MoveForce,x  ; check for any vertical force or speed
    BNE MoveRedPTUpOrDown  ; branch if any found
    STA Enemy_YMF_Dummy,x  ; initialize something here
    LDA Enemy_Y_Position,x  ; check current vs. original vertical coordinate
    CMP RedPTroopaOrigXPos,x
    BCS MoveRedPTUpOrDown  ; if current => original, skip ahead to more code
    LDA FrameCounter  ; get frame counter
    AND #%00000111  ; mask out all but 3 LSB
    BNE NoIncPT  ; if any bits set, branch to leave
    INC Enemy_Y_Position,x  ; otherwise increment red paratroopa's vertical position
NoIncPT:
    RTS  ; leave

MoveRedPTUpOrDown:
    LDA Enemy_Y_Position,x  ; check current vs. central vertical coordinate
    CMP RedPTroopaCenterYPos,x
    BCC MovPTDwn  ; if current < central, jump to move downwards
    JMP MoveRedPTroopaUp  ; otherwise jump to move upwards
MovPTDwn:
    JMP MoveRedPTroopaDown  ; move downwards

; --------------------------------
; $00 - used to store adder for movement, also used as adder for platform
; $01 - used to store maximum value for secondary counter

MoveFlyGreenPTroopa:
    JSR XMoveCntr_GreenPTroopa  ; do sub to increment primary and secondary counters
    JSR MoveWithXMCntrs  ; do sub to move green paratroopa accordingly, and horizontally
    LDY #$01  ; set Y to move green paratroopa down
    LDA FrameCounter
    AND #%00000011  ; check frame counter 2 LSB for any bits set
    BNE NoMGPT  ; branch to leave if set to move up/down every fourth frame
    LDA FrameCounter
    AND #%01000000  ; check frame counter for d6 set
    BNE YSway  ; branch to move green paratroopa down if set
    LDY #$ff  ; otherwise set Y to move green paratroopa up
YSway:
    STY $00  ; store adder here
    LDA Enemy_Y_Position,x
    CLC  ; add or subtract from vertical position
    ADC $00  ; to give green paratroopa a wavy flight
    STA Enemy_Y_Position,x
NoMGPT:
    RTS  ; leave!

XMoveCntr_GreenPTroopa:
    LDA #$13  ; load preset maximum value for secondary counter

XMoveCntr_Platform:
    STA $01  ; store value here
    LDA FrameCounter
    AND #%00000011  ; branch to leave if not on
    BNE NoIncXM  ; every fourth frame
    LDY XMoveSecondaryCounter,x  ; get secondary counter
    LDA XMovePrimaryCounter,x  ; get primary counter
    LSR
    BCS DecSeXM  ; if d0 of primary counter set, branch elsewhere
    CPY $01  ; compare secondary counter to preset maximum value
    BEQ IncPXM  ; if equal, branch ahead of this part
    INC XMoveSecondaryCounter,x  ; increment secondary counter and leave
NoIncXM:
    RTS
IncPXM:
    INC XMovePrimaryCounter,x  ; increment primary counter and leave
    RTS
DecSeXM:
    TYA  ; put secondary counter in A
    BEQ IncPXM  ; if secondary counter at zero, branch back
    DEC XMoveSecondaryCounter,x  ; otherwise decrement secondary counter and leave
    RTS

MoveWithXMCntrs:
    LDA XMoveSecondaryCounter,x  ; save secondary counter to stack
    PHA
    LDY #$01  ; set value here by default
    LDA XMovePrimaryCounter,x
    AND #%00000010  ; if d1 of primary counter is
    BNE XMRight  ; set, branch ahead of this part here
    LDA XMoveSecondaryCounter,x
    EOR #$ff  ; otherwise change secondary
    CLC  ; counter to two's compliment
    ADC #$01
    STA XMoveSecondaryCounter,x
    LDY #$02  ; load alternate value here
XMRight:
    STY Enemy_MovingDir,x  ; store as moving direction
    JSR MoveEnemyHorizontally
    STA $00  ; save value obtained from sub here
    PLA  ; get secondary counter from stack
    STA XMoveSecondaryCounter,x  ; and return to original place
    RTS

; --------------------------------

BlooberBitmasks:
    .byte %00111111, %00000011

MoveBloober:
    LDA Enemy_State,x
    AND #%00100000  ; check enemy state for d5 set
    BNE MoveDefeatedBloober  ; branch if set to move defeated bloober
    LDY SecondaryHardMode  ; use secondary hard mode flag as offset
    LDA PseudoRandomBitReg+1,x  ; get LSFR
    AND BlooberBitmasks,y  ; mask out bits in LSFR using bitmask loaded with offset
    BNE BlooberSwim  ; if any bits set, skip ahead to make swim
    TXA
    LSR  ; check to see if on second or fourth slot (1 or 3)
    BCC FBLeft  ; if not, branch to figure out moving direction
    LDY Player_MovingDir  ; otherwise, load player's moving direction and
    BCS SBMDir  ; do an unconditional branch to set
FBLeft:
    LDY #$02  ; set left moving direction by default
    JSR PlayerEnemyDiff  ; get horizontal difference between player and bloober
    BPL SBMDir  ; if enemy to the right of player, keep left
    DEY  ; otherwise decrement to set right moving direction
SBMDir:
    STY Enemy_MovingDir,x  ; set moving direction of bloober, then continue on here

BlooberSwim:
    JSR ProcSwimmingB  ; execute sub to make bloober swim characteristically
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    SEC
    SBC Enemy_Y_MoveForce,x  ; subtract movement force
    CMP #$20  ; check to see if position is above edge of status bar
    BCC SwimX  ; if so, don't do it
    STA Enemy_Y_Position,x  ; otherwise, set new vertical position, make bloober swim
SwimX:
    LDY Enemy_MovingDir,x  ; check moving direction
    DEY
    BNE LeftSwim  ; if moving to the left, branch to second part
    LDA Enemy_X_Position,x
    CLC  ; add movement speed to horizontal coordinate
    ADC BlooperMoveSpeed,x
    STA Enemy_X_Position,x  ; store result as new horizontal coordinate
    LDA Enemy_PageLoc,x
    ADC #$00  ; add carry to page location
    STA Enemy_PageLoc,x  ; store as new page location and leave
    RTS

LeftSwim:
    LDA Enemy_X_Position,x
    SEC  ; subtract movement speed from horizontal coordinate
    SBC BlooperMoveSpeed,x
    STA Enemy_X_Position,x  ; store result as new horizontal coordinate
    LDA Enemy_PageLoc,x
    SBC #$00  ; subtract borrow from page location
    STA Enemy_PageLoc,x  ; store as new page location and leave
    RTS

MoveDefeatedBloober:
    JMP MoveEnemySlowVert  ; jump to move defeated bloober downwards

ProcSwimmingB:
    LDA BlooperMoveCounter,x  ; get enemy's movement counter
    AND #%00000010  ; check for d1 set
    BNE ChkForFloatdown  ; branch if set
    LDA FrameCounter
    AND #%00000111  ; get 3 LSB of frame counter
    PHA  ; and save it to the stack
    LDA BlooperMoveCounter,x  ; get enemy's movement counter
    LSR  ; check for d0 set
    BCS SlowSwim  ; branch if set
    PLA  ; pull 3 LSB of frame counter from the stack
    BNE BSwimE  ; branch to leave, execute code only every eighth frame
    LDA Enemy_Y_MoveForce,x
    CLC  ; add to movement force to speed up swim
    ADC #$01
    STA Enemy_Y_MoveForce,x  ; set movement force
    STA BlooperMoveSpeed,x  ; set as movement speed
    CMP #$02
    BNE BSwimE  ; if certain horizontal speed, branch to leave
    INC BlooperMoveCounter,x  ; otherwise increment movement counter
BSwimE:
    RTS

SlowSwim:
    PLA  ; pull 3 LSB of frame counter from the stack
    BNE NoSSw  ; branch to leave, execute code only every eighth frame
    LDA Enemy_Y_MoveForce,x
    SEC  ; subtract from movement force to slow swim
    SBC #$01
    STA Enemy_Y_MoveForce,x  ; set movement force
    STA BlooperMoveSpeed,x  ; set as movement speed
    BNE NoSSw  ; if any speed, branch to leave
    INC BlooperMoveCounter,x  ; otherwise increment movement counter
    LDA #$02
    STA EnemyIntervalTimer,x  ; set enemy's timer
NoSSw:
    RTS  ; leave

ChkForFloatdown:
    LDA EnemyIntervalTimer,x  ; get enemy timer
    BEQ ChkNearPlayer  ; branch if expired

Floatdown:
    LDA FrameCounter  ; get frame counter
    LSR  ; check for d0 set
    BCS NoFD  ; branch to leave on every other frame
    INC Enemy_Y_Position,x  ; otherwise increment vertical coordinate
NoFD:
    RTS  ; leave

ChkNearPlayer:
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    ADC #$10  ; add sixteen pixels
    CMP Player_Y_Position  ; compare result with player's vertical coordinate
    BCC Floatdown  ; if modified vertical less than player's, branch
    LDA #$00
    STA BlooperMoveCounter,x  ; otherwise nullify movement counter
    RTS

; --------------------------------

MoveBulletBill:
    LDA Enemy_State,x  ; check bullet bill's enemy object state for d5 set
    AND #%00100000
    BEQ NotDefB  ; if not set, continue with movement code
    JMP MoveJ_EnemyVertically  ; otherwise jump to move defeated bullet bill downwards
NotDefB:
    LDA #$e8  ; set bullet bill's horizontal speed
    STA Enemy_X_Speed,x  ; and move it accordingly (note: this bullet bill
    JMP MoveEnemyHorizontally  ; object occurs in frenzy object $17, not from cannons)

; --------------------------------
; $02 - used to hold preset values
; $03 - used to hold enemy state

SwimCCXMoveData:
    .byte $40, $80
    .byte $04, $04  ; residual data, not used

MoveSwimmingCheepCheep:
    LDA Enemy_State,x  ; check cheep-cheep's enemy object state
    AND #%00100000  ; for d5 set
    BEQ CCSwim  ; if not set, continue with movement code
    JMP MoveEnemySlowVert  ; otherwise jump to move defeated cheep-cheep downwards
CCSwim:
    STA $03  ; save enemy state in $03
    LDA Enemy_ID,x  ; get enemy identifier
    SEC
    SBC #$0a  ; subtract ten for cheep-cheep identifiers
    TAY  ; use as offset
    LDA SwimCCXMoveData,y  ; load value here
    STA $02
    LDA Enemy_X_MoveForce,x  ; load horizontal force
    SEC
    SBC $02  ; subtract preset value from horizontal force
    STA Enemy_X_MoveForce,x  ; store as new horizontal force
    LDA Enemy_X_Position,x  ; get horizontal coordinate
    SBC #$00  ; subtract borrow (thus moving it slowly)
    STA Enemy_X_Position,x  ; and save as new horizontal coordinate
    LDA Enemy_PageLoc,x
    SBC #$00  ; subtract borrow again, this time from the
    STA Enemy_PageLoc,x  ; page location, then save
    LDA #$20
    STA $02  ; save new value here
    CPX #$02  ; check enemy object offset
    BCC ExSwCC  ; if in first or second slot, branch to leave
    LDA CheepCheepMoveMFlag,x  ; check movement flag
    CMP #$10  ; if movement speed set to $00,
    BCC CCSwimUpwards  ; branch to move upwards
    LDA Enemy_YMF_Dummy,x
    CLC
    ADC $02  ; add preset value to dummy variable to get carry
    STA Enemy_YMF_Dummy,x  ; and save dummy
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    ADC $03  ; add carry to it plus enemy state to slowly move it downwards
    STA Enemy_Y_Position,x  ; save as new vertical coordinate
    LDA Enemy_Y_HighPos,x
    ADC #$00  ; add carry to page location and
    JMP ChkSwimYPos  ; jump to end of movement code

CCSwimUpwards:
    LDA Enemy_YMF_Dummy,x
    SEC
    SBC $02  ; subtract preset value to dummy variable to get borrow
    STA Enemy_YMF_Dummy,x  ; and save dummy
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    SBC $03  ; subtract borrow to it plus enemy state to slowly move it upwards
    STA Enemy_Y_Position,x  ; save as new vertical coordinate
    LDA Enemy_Y_HighPos,x
    SBC #$00  ; subtract borrow from page location

ChkSwimYPos:
    STA Enemy_Y_HighPos,x  ; save new page location here
    LDY #$00  ; load movement speed to upwards by default
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    SEC
    SBC CheepCheepOrigYPos,x  ; subtract original coordinate from current
    BPL YPDiff  ; if result positive, skip to next part
    LDY #$10  ; otherwise load movement speed to downwards
    EOR #$ff
    CLC  ; get two's compliment of result
    ADC #$01  ; to obtain total difference of original vs. current
YPDiff:
    CMP #$0f  ; if difference between original vs. current vertical
    BCC ExSwCC  ; coordinates < 15 pixels, leave movement speed alone
    TYA
    STA CheepCheepMoveMFlag,x  ; otherwise change movement speed
ExSwCC:
    RTS  ; leave
