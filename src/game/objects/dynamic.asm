; -------------------------------------------------------------------------------------

CannonBitmasks:
    .byte %00001111, %00000111

ProcessCannons:
    LDA AreaType  ; get area type
    BEQ ExCannon  ; if water type area, branch to leave
    LDX #$02
ThreeSChk:
    STX ObjectOffset  ; start at third enemy slot
    LDA Enemy_Flag,x  ; check enemy buffer flag
    BNE Chk_BB  ; if set, branch to check enemy
    LDA PseudoRandomBitReg+1,x  ; otherwise get part of LSFR
    LDY SecondaryHardMode  ; get secondary hard mode flag, use as offset
    AND CannonBitmasks,y  ; mask out bits of LSFR as decided by flag
    CMP #$06  ; check to see if lower nybble is above certain value
    BCS Chk_BB  ; if so, branch to check enemy
    TAY  ; transfer masked contents of LSFR to Y as pseudorandom offset
    LDA Cannon_PageLoc,y  ; get page location
    BEQ Chk_BB  ; if not set or on page 0, branch to check enemy
    LDA Cannon_Timer,y  ; get cannon timer
    BEQ FireCannon  ; if expired, branch to fire cannon
    SBC #$00  ; otherwise subtract borrow (note carry will always be clear here)
    STA Cannon_Timer,y  ; to count timer down
    JMP Chk_BB  ; then jump ahead to check enemy

FireCannon:
    LDA TimerControl  ; if master timer control set,
    BNE Chk_BB  ; branch to check enemy
    LDA #$0e  ; otherwise we start creating one
    STA Cannon_Timer,y  ; first, reset cannon timer
    LDA Cannon_PageLoc,y  ; get page location of cannon
    STA Enemy_PageLoc,x  ; save as page location of bullet bill
    LDA Cannon_X_Position,y  ; get horizontal coordinate of cannon
    STA Enemy_X_Position,x  ; save as horizontal coordinate of bullet bill
    LDA Cannon_Y_Position,y  ; get vertical coordinate of cannon
    SEC
    SBC #$08  ; subtract eight pixels (because enemies are 24 pixels tall)
    STA Enemy_Y_Position,x  ; save as vertical coordinate of bullet bill
    LDA #$01
    STA Enemy_Y_HighPos,x  ; set vertical high byte of bullet bill
    STA Enemy_Flag,x  ; set buffer flag
    LSR  ; shift right once to init A
    STA Enemy_State,x  ; then initialize enemy's state
    LDA #$09
    STA Enemy_BoundBoxCtrl,x  ; set bounding box size control for bullet bill
    LDA #BulletBill_CannonVar
    STA Enemy_ID,x  ; load identifier for bullet bill (cannon variant)
    JMP Next3Slt  ; move onto next slot
Chk_BB:
    LDA Enemy_ID,x  ; check enemy identifier for bullet bill (cannon variant)
    CMP #BulletBill_CannonVar
    BNE Next3Slt  ; if not found, branch to get next slot
    JSR OffscreenBoundsCheck  ; otherwise, check to see if it went offscreen
    LDA Enemy_Flag,x  ; check enemy buffer flag
    BEQ Next3Slt  ; if not set, branch to get next slot
    JSR GetEnemyOffscreenBits  ; otherwise, get offscreen information
    JSR BulletBillHandler  ; then do sub to handle bullet bill
Next3Slt:
    DEX  ; move onto next slot
    BPL ThreeSChk  ; do this until first three slots are checked
ExCannon:
    RTS  ; then leave

; --------------------------------

BulletBillXSpdData:
    .byte $18, $e8

BulletBillHandler:
    LDA TimerControl  ; if master timer control set,
    BNE RunBBSubs  ; branch to run subroutines except movement sub
    LDA Enemy_State,x
    BNE ChkDSte  ; if bullet bill's state set, branch to check defeated state
    LDA Enemy_OffscreenBits  ; otherwise load offscreen bits
    AND #%00001100  ; mask out bits
    CMP #%00001100  ; check to see if all bits are set
    BEQ KillBB  ; if so, branch to kill this object
    LDY #$01  ; set to move right by default
    JSR PlayerEnemyDiff  ; get horizontal difference between player and bullet bill
    BMI SetupBB  ; if enemy to the left of player, branch
    INY  ; otherwise increment to move left
SetupBB:
    STY Enemy_MovingDir,x  ; set bullet bill's moving direction
    DEY  ; decrement to use as offset
    LDA BulletBillXSpdData,y  ; get horizontal speed based on moving direction
    STA Enemy_X_Speed,x  ; and store it
    LDA $00  ; get horizontal difference
    ADC #$28  ; add 40 pixels
    CMP #$50  ; if less than a certain amount, player is too close
    BCC KillBB  ; to cannon either on left or right side, thus branch
    LDA #$01
    STA Enemy_State,x  ; otherwise set bullet bill's state
    LDA #$0a
    STA EnemyFrameTimer,x  ; set enemy frame timer
    LDA #Sfx_Blast
    STA Square2SoundQueue  ; play fireworks/gunfire sound
ChkDSte:
    LDA Enemy_State,x  ; check enemy state for d5 set
    AND #%00100000
    BEQ BBFly  ; if not set, skip to move horizontally
    JSR MoveD_EnemyVertically  ; otherwise do sub to move bullet bill vertically
BBFly:
    JSR MoveEnemyHorizontally  ; do sub to move bullet bill horizontally
RunBBSubs:
    JSR GetEnemyOffscreenBits  ; get offscreen information
    JSR RelativeEnemyPosition  ; get relative coordinates
    JSR GetEnemyBoundBox  ; get bounding box coordinates
    JSR PlayerEnemyCollision  ; handle player to enemy collisions
    JMP EnemyGfxHandler  ; draw the bullet bill and leave
KillBB:
    JSR EraseEnemyObject  ; kill bullet bill and leave
    RTS

; -------------------------------------------------------------------------------------

HammerEnemyOfsData:
    .byte $04, $04, $04, $05, $05, $05
    .byte $06, $06, $06

HammerXSpdData:
    .byte $10, $f0

SpawnHammerObj:
    LDA PseudoRandomBitReg+1  ; get pseudorandom bits from
    AND #%00000111  ; second part of LSFR
    BNE SetMOfs  ; if any bits are set, branch and use as offset
    LDA PseudoRandomBitReg+1
    AND #%00001000  ; get d3 from same part of LSFR
SetMOfs:
    TAY  ; use either d3 or d2-d0 for offset here
    LDA Misc_State,y  ; if any values loaded in
    BNE NoHammer  ; $2a-$32 where offset is then leave with carry clear
    LDX HammerEnemyOfsData,y  ; get offset of enemy slot to check using Y as offset
    LDA Enemy_Flag,x  ; check enemy buffer flag at offset
    BNE NoHammer  ; if buffer flag set, branch to leave with carry clear
    LDX ObjectOffset  ; get original enemy object offset
    TXA
    STA HammerEnemyOffset,y  ; save here
    LDA #$90
    STA Misc_State,y  ; save hammer's state here
    LDA #$07
    STA Misc_BoundBoxCtrl,y  ; set something else entirely, here
    SEC  ; return with carry set
    RTS
NoHammer:
    LDX ObjectOffset  ; get original enemy object offset
    CLC  ; return with carry clear
    RTS

; --------------------------------
; $00 - used to set downward force
; $01 - used to set upward force (residual)
; $02 - used to set maximum speed

ProcHammerObj:
    LDA TimerControl  ; if master timer control set
    BNE RunHSubs  ; skip all of this code and go to last subs at the end
    LDA Misc_State,x  ; otherwise get hammer's state
    AND #%01111111  ; mask out d7
    LDY HammerEnemyOffset,x  ; get enemy object offset that spawned this hammer
    CMP #$02  ; check hammer's state
    BEQ SetHSpd  ; if currently at 2, branch
    BCS SetHPos  ; if greater than 2, branch elsewhere
    TXA
    CLC  ; add 13 bytes to use
    ADC #$0d  ; proper misc object
    TAX  ; return offset to X
    LDA #$10
    STA $00  ; set downward movement force
    LDA #$0f
    STA $01  ; set upward movement force (not used)
    LDA #$04
    STA $02  ; set maximum vertical speed
    LDA #$00  ; set A to impose gravity on hammer
    JSR ImposeGravity  ; do sub to impose gravity on hammer and move vertically
    JSR MoveObjectHorizontally  ; do sub to move it horizontally
    LDX ObjectOffset  ; get original misc object offset
    JMP RunAllH  ; branch to essential subroutines
SetHSpd:
    LDA #$fe
    STA Misc_Y_Speed,x  ; set hammer's vertical speed
    LDA Enemy_State,y  ; get enemy object state
    AND #%11110111  ; mask out d3
    STA Enemy_State,y  ; store new state
    LDX Enemy_MovingDir,y  ; get enemy's moving direction
    DEX  ; decrement to use as offset
    LDA HammerXSpdData,x  ; get proper speed to use based on moving direction
    LDX ObjectOffset  ; reobtain hammer's buffer offset
    STA Misc_X_Speed,x  ; set hammer's horizontal speed
SetHPos:
    DEC Misc_State,x  ; decrement hammer's state
    LDA Enemy_X_Position,y  ; get enemy's horizontal position
    CLC
    ADC #$02  ; set position 2 pixels to the right
    STA Misc_X_Position,x  ; store as hammer's horizontal position
    LDA Enemy_PageLoc,y  ; get enemy's page location
    ADC #$00  ; add carry
    STA Misc_PageLoc,x  ; store as hammer's page location
    LDA Enemy_Y_Position,y  ; get enemy's vertical position
    SEC
    SBC #$0a  ; move position 10 pixels upward
    STA Misc_Y_Position,x  ; store as hammer's vertical position
    LDA #$01
    STA Misc_Y_HighPos,x  ; set hammer's vertical high byte
    BNE RunHSubs  ; unconditional branch to skip first routine
RunAllH:
    JSR PlayerHammerCollision  ; handle collisions
RunHSubs:
    JSR GetMiscOffscreenBits  ; get offscreen information
    JSR RelativeMiscPosition  ; get relative coordinates
    JSR GetMiscBoundBox  ; get bounding box coordinates
    JSR DrawHammer  ; draw the hammer
    RTS  ; and we are done here

; -------------------------------------------------------------------------------------
; $02 - used to store vertical high nybble offset from block buffer routine
; $06 - used to store low byte of block buffer address

CoinBlock:
    JSR FindEmptyMiscSlot  ; set offset for empty or last misc object buffer slot
    LDA Block_PageLoc,x  ; get page location of block object
    STA Misc_PageLoc,y  ; store as page location of misc object
    LDA Block_X_Position,x  ; get horizontal coordinate of block object
    ORA #$05  ; add 5 pixels
    STA Misc_X_Position,y  ; store as horizontal coordinate of misc object
    LDA Block_Y_Position,x  ; get vertical coordinate of block object
    SBC #$10  ; subtract 16 pixels
    STA Misc_Y_Position,y  ; store as vertical coordinate of misc object
    JMP JCoinC  ; jump to rest of code as applies to this misc object

SetupJumpCoin:
    JSR FindEmptyMiscSlot  ; set offset for empty or last misc object buffer slot
    LDA Block_PageLoc2,x  ; get page location saved earlier
    STA Misc_PageLoc,y  ; and save as page location for misc object
    LDA $06  ; get low byte of block buffer offset
    ASL
    ASL  ; multiply by 16 to use lower nybble
    ASL
    ASL
    ORA #$05  ; add five pixels
    STA Misc_X_Position,y  ; save as horizontal coordinate for misc object
    LDA $02  ; get vertical high nybble offset from earlier
    ADC #$20  ; add 32 pixels for the status bar
    STA Misc_Y_Position,y  ; store as vertical coordinate
JCoinC:
    LDA #$fb
    STA Misc_Y_Speed,y  ; set vertical speed
    LDA #$01
    STA Misc_Y_HighPos,y  ; set vertical high byte
    STA Misc_State,y  ; set state for misc object
    STA Square2SoundQueue  ; load coin grab sound
    STX ObjectOffset  ; store current control bit as misc object offset
    JSR GiveOneCoin  ; update coin tally on the screen and coin amount variable
    INC CoinTallyFor1Ups  ; increment coin tally used to activate 1-up block flag
    RTS

FindEmptyMiscSlot:
    LDY #$08  ; start at end of misc objects buffer
FMiscLoop:
    LDA Misc_State,y  ; get misc object state
    BEQ UseMiscS  ; branch if none found to use current offset
    DEY  ; decrement offset
    CPY #$05  ; do this for three slots
    BNE FMiscLoop  ; do this until all slots are checked
    LDY #$08  ; if no empty slots found, use last slot
UseMiscS:
    STY JumpCoinMiscOffset  ; store offset of misc object buffer here (residual)
    RTS

; -------------------------------------------------------------------------------------

MiscObjectsCore:
    LDX #$08  ; set at end of misc object buffer
MiscLoop:
    STX ObjectOffset  ; store misc object offset here
    LDA Misc_State,x  ; check misc object state
    BEQ MiscLoopBack  ; branch to check next slot
    ASL  ; otherwise shift d7 into carry
    BCC ProcJumpCoin  ; if d7 not set, jumping coin, thus skip to rest of code here
    JSR ProcHammerObj  ; otherwise go to process hammer,
    JMP MiscLoopBack  ; then check next slot

; --------------------------------
; $00 - used to set downward force
; $01 - used to set upward force (residual)
; $02 - used to set maximum speed

ProcJumpCoin:
    LDY Misc_State,x  ; check misc object state
    DEY  ; decrement to see if it's set to 1
    BEQ JCoinRun  ; if so, branch to handle jumping coin
    INC Misc_State,x  ; otherwise increment state to either start off or as timer
    LDA Misc_X_Position,x  ; get horizontal coordinate for misc object
    CLC  ; whether its jumping coin (state 0 only) or floatey number
    ADC ScrollAmount  ; add current scroll speed
    STA Misc_X_Position,x  ; store as new horizontal coordinate
    LDA Misc_PageLoc,x  ; get page location
    ADC #$00  ; add carry
    STA Misc_PageLoc,x  ; store as new page location
    LDA Misc_State,x
    CMP #$30  ; check state of object for preset value
    BNE RunJCSubs  ; if not yet reached, branch to subroutines
    LDA #$00
    STA Misc_State,x  ; otherwise nullify object state
    JMP MiscLoopBack  ; and move onto next slot
JCoinRun:
    TXA
    CLC  ; add 13 bytes to offset for next subroutine
    ADC #$0d
    TAX
    LDA #$50  ; set downward movement amount
    STA $00
    LDA #$06  ; set maximum vertical speed
    STA $02
    LSR  ; divide by 2 and set
    STA $01  ; as upward movement amount (apparently residual)
    LDA #$00  ; set A to impose gravity on jumping coin
    JSR ImposeGravity  ; do sub to move coin vertically and impose gravity on it
    LDX ObjectOffset  ; get original misc object offset
    LDA Misc_Y_Speed,x  ; check vertical speed
    CMP #$05
    BNE RunJCSubs  ; if not moving downward fast enough, keep state as-is
    INC Misc_State,x  ; otherwise increment state to change to floatey number
RunJCSubs:
    JSR RelativeMiscPosition  ; get relative coordinates
    JSR GetMiscOffscreenBits  ; get offscreen information
    JSR GetMiscBoundBox  ; get bounding box coordinates (why?)
    JSR JCoinGfxHandler  ; draw the coin or floatey number

MiscLoopBack:
    DEX  ; decrement misc object offset
    BPL MiscLoop  ; loop back until all misc objects handled
    RTS  ; then leave

; -------------------------------------------------------------------------------------

CoinTallyOffsets:
    .byte $17, $1d

ScoreOffsets:
    .byte $0b, $11

StatusBarNybbles:
    .byte $02, $13

GiveOneCoin:
    LDA #$01  ; set digit modifier to add 1 coin
    STA DigitModifier+5  ; to the current player's coin tally
    LDX CurrentPlayer  ; get current player on the screen
    LDY CoinTallyOffsets,x  ; get offset for player's coin tally
    JSR DigitsMathRoutine  ; update the coin tally
    INC CoinTally  ; increment onscreen player's coin amount
    LDA CoinTally
    CMP #100  ; does player have 100 coins yet?
    BNE CoinPoints  ; if not, skip all of this
    LDA #$00
    STA CoinTally  ; otherwise, reinitialize coin amount
    INC NumberofLives  ; give the player an extra life
    LDA #Sfx_ExtraLife
    STA Square2SoundQueue  ; play 1-up sound

CoinPoints:
    LDA #$02  ; set digit modifier to award
    STA DigitModifier+4  ; 200 points to the player

AddToScore:
    LDX CurrentPlayer  ; get current player
    LDY ScoreOffsets,x  ; get offset for player's score
    JSR DigitsMathRoutine  ; update the score internally with value in digit modifier

GetSBNybbles:
    LDY CurrentPlayer  ; get current player
    LDA StatusBarNybbles,y  ; get nybbles based on player, use to update score and coins

UpdateNumber:
    JSR PrintStatusBarNumbers  ; print status bar numbers based on nybbles, whatever they be
    LDY VRAM_Buffer1_Offset
    LDA VRAM_Buffer1-6,y  ; check highest digit of score
    BNE NoZSup  ; if zero, overwrite with space tile for zero suppression
    LDA #$24
    STA VRAM_Buffer1-6,y
NoZSup:
    LDX ObjectOffset  ; get enemy object buffer offset
    RTS

; -------------------------------------------------------------------------------------

SetupPowerUp:
    LDA #PowerUpObject  ; load power-up identifier into
    STA Enemy_ID+5  ; special use slot of enemy object buffer
    LDA Block_PageLoc,x  ; store page location of block object
    STA Enemy_PageLoc+5  ; as page location of power-up object
    LDA Block_X_Position,x  ; store horizontal coordinate of block object
    STA Enemy_X_Position+5  ; as horizontal coordinate of power-up object
    LDA #$01
    STA Enemy_Y_HighPos+5  ; set vertical high byte of power-up object
    LDA Block_Y_Position,x  ; get vertical coordinate of block object
    SEC
    SBC #$08  ; subtract 8 pixels
    STA Enemy_Y_Position+5  ; and use as vertical coordinate of power-up object
PwrUpJmp:
    LDA #$01  ; this is a residual jump point in enemy object jump table
    STA Enemy_State+5  ; set power-up object's state
    STA Enemy_Flag+5  ; set buffer flag
    LDA #$03
    STA Enemy_BoundBoxCtrl+5  ; set bounding box size control for power-up object
    LDA PowerUpType
    CMP #$02  ; check currently loaded power-up type
    BCS PutBehind  ; if star or 1-up, branch ahead
    LDA PlayerStatus  ; otherwise check player's current status
    CMP #$02
    BCC StrType  ; if player not fiery, use status as power-up type
    LSR  ; otherwise shift right to force fire flower type
StrType:
    STA PowerUpType  ; store type here
PutBehind:
    LDA #%00100000
    STA Enemy_SprAttrib+5  ; set background priority bit
    LDA #Sfx_GrowPowerUp
    STA Square2SoundQueue  ; load power-up reveal sound and leave
    RTS

; -------------------------------------------------------------------------------------

PowerUpObjHandler:
    LDX #$05  ; set object offset for last slot in enemy object buffer
    STX ObjectOffset
    LDA Enemy_State+5  ; check power-up object's state
    BEQ ExitPUp  ; if not set, branch to leave
    ASL  ; shift to check if d7 was set in object state
    BCC GrowThePowerUp  ; if not set, branch ahead to skip this part
    LDA TimerControl  ; if master timer control set,
    BNE RunPUSubs  ; branch ahead to enemy object routines
    LDA PowerUpType  ; check power-up type
    BEQ ShroomM  ; if normal mushroom, branch ahead to move it
    CMP #$03
    BEQ ShroomM  ; if 1-up mushroom, branch ahead to move it
    CMP #$02
    BNE RunPUSubs  ; if not star, branch elsewhere to skip movement
    JSR MoveJumpingEnemy  ; otherwise impose gravity on star power-up and make it jump
    JSR EnemyJump  ; note that green paratroopa shares the same code here
    JMP RunPUSubs  ; then jump to other power-up subroutines
ShroomM:
    JSR MoveNormalEnemy  ; do sub to make mushrooms move
    JSR EnemyToBGCollisionDet  ; deal with collisions
    JMP RunPUSubs  ; run the other subroutines

GrowThePowerUp:
    LDA FrameCounter  ; get frame counter
    AND #$03  ; mask out all but 2 LSB
    BNE ChkPUSte  ; if any bits set here, branch
    DEC Enemy_Y_Position+5  ; otherwise decrement vertical coordinate slowly
    LDA Enemy_State+5  ; load power-up object state
    INC Enemy_State+5  ; increment state for next frame (to make power-up rise)
    CMP #$11  ; if power-up object state not yet past 16th pixel,
    BCC ChkPUSte  ; branch ahead to last part here
    LDA #$10
    STA Enemy_X_Speed,x  ; otherwise set horizontal speed
    LDA #%10000000
    STA Enemy_State+5  ; and then set d7 in power-up object's state
    ASL  ; shift once to init A
    STA Enemy_SprAttrib+5  ; initialize background priority bit set here
    ROL  ; rotate A to set right moving direction
    STA Enemy_MovingDir,x  ; set moving direction
ChkPUSte:
    LDA Enemy_State+5  ; check power-up object's state
    CMP #$06  ; for if power-up has risen enough
    BCC ExitPUp  ; if not, don't even bother running these routines
RunPUSubs:
    JSR RelativeEnemyPosition  ; get coordinates relative to screen
    JSR GetEnemyOffscreenBits  ; get offscreen bits
    JSR GetEnemyBoundBox  ; get bounding box coordinates
    JSR DrawPowerUp  ; draw the power-up object
    JSR PlayerEnemyCollision  ; check for collision with player
    JSR OffscreenBoundsCheck  ; check to see if it went offscreen
ExitPUp:
    RTS  ; and we're done
