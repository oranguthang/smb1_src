; -------------------------------------------------------------------------------------

sub_update_player_movement:
    LDA #$00  ; set A to init crouch flag by default
    LDY PlayerSize  ; is player small?
    BNE SetCrouch  ; if so, branch
    LDA Player_State  ; check state of player
    BNE ProcMove  ; if not on the ground, branch
    LDA Up_Down_Buttons  ; load controller bits for up and down
    AND #%00000100  ; single out bit for down button
SetCrouch:
    STA CrouchingFlag  ; store value in crouch flag
ProcMove:
    JSR sub_update_player_physics  ; run sub related to jumping and swimming
    LDA PlayerChangeSizeFlag  ; if growing/shrinking flag set,
    BNE NoMoveSub  ; branch to leave
    LDA Player_State
    CMP #$03  ; get player state
    BEQ bra_dispatch_player_state_movement  ; if climbing, branch ahead, leave timer unset
    LDY #$18
    STY ClimbSideTimer  ; otherwise reset timer now
bra_dispatch_player_state_movement:
    JSR JumpEngine

tbl_player_state_movement_handlers:
    .word handler_player_on_ground
    .word handler_player_jumping_or_swimming
    .word handler_player_falling
    .word handler_player_climbing

NoMoveSub:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used by handler_player_climbing to store high vertical adder

handler_player_on_ground:
    JSR sub_update_player_animation_speed  ; do a sub to set animation frame timing
    LDA Left_Right_Buttons
    BEQ GndMove  ; if left/right controller bits not set, skip instruction
    STA PlayerFacingDir  ; otherwise set new facing direction
GndMove:
    JSR sub_apply_player_horizontal_friction  ; do a sub to impose friction on player's walk/run
    JSR MovePlayerHorizontally  ; do another sub to move player horizontally
    STA Player_X_Scroll  ; set returned value as player's movement speed for scroll
    RTS

; --------------------------------

handler_player_falling:
    LDA VerticalForceDown
    STA VerticalForce  ; dump vertical movement force for falling into main one
    JMP LRAir  ; movement force, then skip ahead to process left/right movement

; --------------------------------

handler_player_jumping_or_swimming:
    LDY Player_Y_Speed  ; if player's vertical speed zero
    BPL DumpFall  ; or moving downwards, branch to falling
    LDA A_B_Buttons
    AND #A_Button  ; check to see if A button is being pressed
    AND PreviousA_B_Buttons  ; and was pressed in previous frame
    BNE ProcSwim  ; if so, branch elsewhere
    LDA JumpOrigin_Y_Position  ; get vertical position player jumped from
    SEC
    SBC Player_Y_Position  ; subtract current from original vertical coordinate
    CMP DiffToHaltJump  ; compare to value set here to see if player is in mid-jump
    BCC ProcSwim  ; or just starting to jump, if just starting, skip ahead
DumpFall:
    LDA VerticalForceDown  ; otherwise dump falling into main fractional
    STA VerticalForce
ProcSwim:
    LDA SwimmingFlag  ; if swimming flag not set,
    BEQ LRAir  ; branch ahead to last part
    JSR sub_update_player_animation_speed  ; do a sub to get animation frame timing
    LDA Player_Y_Position
    CMP #$14  ; check vertical position against preset value
    BCS LRWater  ; if not yet reached a certain position, branch ahead
    LDA #$18
    STA VerticalForce  ; otherwise set fractional
LRWater:
    LDA Left_Right_Buttons  ; check left/right controller bits (check for swimming)
    BEQ LRAir  ; if not pressing any, skip
    STA PlayerFacingDir  ; otherwise set facing direction accordingly
LRAir:
    LDA Left_Right_Buttons  ; check left/right controller bits (check for jumping/falling)
    BEQ JSMove  ; if not pressing any, skip
    JSR sub_apply_player_horizontal_friction  ; otherwise process horizontal movement
JSMove:
    JSR MovePlayerHorizontally  ; do a sub to move player horizontally
    STA Player_X_Scroll  ; set player's speed here, to be used for scroll later
    LDA GameEngineSubroutine
    CMP #$0b  ; check for specific routine selected
    BNE ExitMov1  ; branch if not set to run
    LDA #$28
    STA VerticalForce  ; otherwise set fractional
ExitMov1:
    JMP MovePlayerVertically  ; jump to move player vertically, then leave

; --------------------------------

tbl_climb_side_x_delta_low:
    .byte $0e, $04, $fc, $f2
tbl_climb_side_x_delta_high:
    .byte $00, $00, $ff, $ff

handler_player_climbing:
    LDA Player_YMF_Dummy
    CLC  ; add movement force to dummy variable
    ADC Player_Y_MoveForce  ; save with carry
    STA Player_YMF_Dummy
    LDY #$00  ; set default adder here
    LDA Player_Y_Speed  ; get player's vertical speed
    BPL MoveOnVine  ; if not moving upwards, branch
    DEY  ; otherwise set adder to $ff
MoveOnVine:
    STY $00  ; store adder here
    ADC Player_Y_Position  ; add carry to player's vertical position
    STA Player_Y_Position  ; and store to move player up or down
    LDA Player_Y_HighPos
    ADC $00  ; add carry to player's page location
    STA Player_Y_HighPos  ; and store
    LDA Left_Right_Buttons  ; compare left/right controller bits
    AND Player_CollisionBits  ; to collision flag
    BEQ InitCSTimer  ; if not set, skip to end
    LDY ClimbSideTimer  ; otherwise check timer
    BNE ExitCSub  ; if timer not expired, branch to leave
    LDY #$18
    STY ClimbSideTimer  ; otherwise set timer now
    LDX #$00  ; set default offset here
    LDY PlayerFacingDir  ; get facing direction
    LSR  ; move right button controller bit to carry
    BCS ClimbFD  ; if controller right pressed, branch ahead
    INX
    INX  ; otherwise increment offset by 2 bytes
ClimbFD:
    DEY  ; check to see if facing right
    BEQ CSetFDir  ; if so, branch, do not increment
    INX  ; otherwise increment by 1 byte
CSetFDir:
    LDA Player_X_Position
    CLC  ; add or subtract from player's horizontal position
    ADC tbl_climb_side_x_delta_low,x  ; using value here as adder and X as offset
    STA Player_X_Position
    LDA Player_PageLoc  ; add or subtract carry or borrow using value here
    ADC tbl_climb_side_x_delta_high,x  ; from the player's page location
    STA Player_PageLoc
    LDA Left_Right_Buttons  ; get left/right controller bits again
    EOR #%00000011  ; invert them and store them while player
    STA PlayerFacingDir  ; is on vine to face player in opposite direction
ExitCSub:
    RTS  ; then leave
InitCSTimer:
    STA ClimbSideTimer  ; initialize timer here
    RTS

; -------------------------------------------------------------------------------------
; $00 - used to store offset to friction data

tbl_jump_vertical_force:
    .byte $20, $20, $1e, $28, $28, $0d, $04

tbl_fall_vertical_force:
    .byte $70, $70, $60, $90, $90, $0a, $09

tbl_initial_player_y_speed:
    .byte $fc, $fc, $fc, $fb, $fb, $fe, $ff

tbl_initial_player_y_move_force:
    .byte $00, $00, $00, $00, $00, $80, $00

tbl_maximum_left_speed:
    .byte $d8, $e8, $f0

tbl_maximum_right_speed:
    .byte $28, $18, $10
    .byte $0c  ; used for pipe intros

tbl_horizontal_friction:
    .byte $e4, $98, $d0

tbl_climb_y_speed:
    .byte $00, $ff, $01

tbl_climb_y_move_force:
    .byte $00, $20, $ff

sub_update_player_physics:
    LDA Player_State  ; check player state
    CMP #$03
    BNE CheckForJumping  ; if not climbing, branch
    LDY #$00
    LDA Up_Down_Buttons  ; get controller bits for up/down
    AND Player_CollisionBits  ; check against player's collision detection bits
    BEQ ProcClimb  ; if not pressing up or down, branch
    INY
    AND #%00001000  ; check for pressing up
    BNE ProcClimb
    INY
ProcClimb:
    LDX tbl_climb_y_move_force,y  ; load value here
    STX Player_Y_MoveForce  ; store as vertical movement force
    LDA #$08  ; load default animation timing
    LDX tbl_climb_y_speed,y  ; load some other value here
    STX Player_Y_Speed  ; store as vertical speed
    BMI SetCAnim  ; if climbing down, use default animation timing value
    LSR  ; otherwise divide timer setting by 2
SetCAnim:
    STA PlayerAnimTimerSet  ; store animation timer setting and leave
    RTS

CheckForJumping:
    LDA JumpspringAnimCtrl  ; if jumpspring animating,
    BNE NoJump  ; skip ahead to something else
    LDA A_B_Buttons  ; check for A button press
    AND #A_Button
    BEQ NoJump  ; if not, branch to something else
    AND PreviousA_B_Buttons  ; if button not pressed in previous frame, branch
    BEQ ProcJumping
NoJump:
    JMP X_Physics  ; otherwise, jump to something else

ProcJumping:
    LDA Player_State  ; check player state
    BEQ InitJS  ; if on the ground, branch
    LDA SwimmingFlag  ; if swimming flag not set, jump to do something else
    BEQ NoJump  ; to prevent midair jumping, otherwise continue
    LDA JumpSwimTimer  ; if jump/swim timer nonzero, branch
    BNE InitJS
    LDA Player_Y_Speed  ; check player's vertical speed
    BPL InitJS  ; if player's vertical speed motionless or down, branch
    JMP X_Physics  ; if timer at zero and player still rising, do not swim
InitJS:
    LDA #$20  ; set jump/swim timer
    STA JumpSwimTimer
    LDY #$00  ; initialize vertical force and dummy variable
    STY Player_YMF_Dummy
    STY Player_Y_MoveForce
    LDA Player_Y_HighPos  ; get vertical high and low bytes of jump origin
    STA JumpOrigin_Y_HighPos  ; and store them next to each other here
    LDA Player_Y_Position
    STA JumpOrigin_Y_Position
    LDA #$01  ; set player state to jumping/swimming
    STA Player_State
    LDA Player_XSpeedAbsolute  ; check value related to walking/running speed
    CMP #$09
    BCC ChkWtr  ; branch if below certain values, increment Y
    INY  ; for each amount equal or exceeded
    CMP #$10
    BCC ChkWtr
    INY
    CMP #$19
    BCC ChkWtr
    INY
    CMP #$1c
    BCC ChkWtr  ; note that for jumping, range is 0-4 for Y
    INY
ChkWtr:
    LDA #$01  ; set value here (apparently always set to 1)
    STA DiffToHaltJump
    LDA SwimmingFlag  ; if swimming flag disabled, branch
    BEQ GetYPhy
    LDY #$05  ; otherwise set Y to 5, range is 5-6
    LDA Whirlpool_Flag  ; if whirlpool flag not set, branch
    BEQ GetYPhy
    INY  ; otherwise increment to 6
GetYPhy:
    LDA tbl_jump_vertical_force,y  ; store appropriate jump/swim
    STA VerticalForce  ; data here
    LDA tbl_fall_vertical_force,y
    STA VerticalForceDown
    LDA tbl_initial_player_y_move_force,y
    STA Player_Y_MoveForce
    LDA tbl_initial_player_y_speed,y
    STA Player_Y_Speed
    LDA SwimmingFlag  ; if swimming flag disabled, branch
    BEQ PJumpSnd
    LDA #Sfx_EnemyStomp  ; load swim/goomba stomp sound into
    STA Square1SoundQueue  ; square 1's sfx queue
    LDA Player_Y_Position
    CMP #$14  ; check vertical low byte of player position
    BCS X_Physics  ; if below a certain point, branch
    LDA #$00  ; otherwise reset player's vertical speed
    STA Player_Y_Speed  ; and jump to something else to keep player
    JMP X_Physics  ; from swimming above water level
PJumpSnd:
    LDA #Sfx_BigJump  ; load big mario's jump sound by default
    LDY PlayerSize  ; is mario big?
    BEQ SJumpSnd
    LDA #Sfx_SmallJump  ; if not, load small mario's jump sound
SJumpSnd:
    STA Square1SoundQueue  ; store appropriate jump sound in square 1 sfx queue
X_Physics:
    LDY #$00
    STY $00  ; init value here
    LDA Player_State  ; if mario is on the ground, branch
    BEQ ProcPRun
    LDA Player_XSpeedAbsolute  ; check something that seems to be related
    CMP #$19  ; to mario's speed
    BCS GetXPhy  ; if =>$19 branch here
    BCC ChkRFast  ; if not branch elsewhere
ProcPRun:
    INY  ; if mario on the ground, increment Y
    LDA AreaType  ; check area type
    BEQ ChkRFast  ; if water type, branch
    DEY  ; decrement Y by default for non-water type area
    LDA Left_Right_Buttons  ; get left/right controller bits
    CMP Player_MovingDir  ; check against moving direction
    BNE ChkRFast  ; if controller bits <> moving direction, skip this part
    LDA A_B_Buttons  ; check for b button pressed
    AND #B_Button
    BNE SetRTmr  ; if pressed, skip ahead to set timer
    LDA RunningTimer  ; check for running timer set
    BNE GetXPhy  ; if set, branch
ChkRFast:
    INY  ; if running timer not set or level type is water,
    INC $00  ; increment Y again and temp variable in memory
    LDA RunningSpeed
    BNE FastXSp  ; if running speed set here, branch
    LDA Player_XSpeedAbsolute
    CMP #$21  ; otherwise check player's walking/running speed
    BCC GetXPhy  ; if less than a certain amount, branch ahead
FastXSp:
    INC $00  ; if running speed set or speed => $21 increment $00
    JMP GetXPhy  ; and jump ahead
SetRTmr:
    LDA #$0a  ; if b button pressed, set running timer
    STA RunningTimer
GetXPhy:
    LDA tbl_maximum_left_speed,y  ; get maximum speed to the left
    STA MaximumLeftSpeed
    LDA GameEngineSubroutine  ; check for specific routine running
    CMP #$07  ; (player entrance)
    BNE GetXPhy2  ; if not running, skip and use old value of Y
    LDY #$03  ; otherwise set Y to 3
GetXPhy2:
    LDA tbl_maximum_right_speed,y  ; get maximum speed to the right
    STA MaximumRightSpeed
    LDY $00  ; get other value in memory
    LDA tbl_horizontal_friction,y  ; get value using value in memory as offset
    STA FrictionAdderLow
    LDA #$00
    STA FrictionAdderHigh  ; init something here
    LDA PlayerFacingDir
    CMP Player_MovingDir  ; check facing direction against moving direction
    BEQ ExitPhy  ; if the same, branch to leave
    ASL FrictionAdderLow  ; otherwise shift d7 of friction adder low into carry
    ROL FrictionAdderHigh  ; then rotate carry onto d0 of friction adder high
ExitPhy:
    RTS  ; and then leave

; -------------------------------------------------------------------------------------

tbl_player_animation_timer:
    .byte $02, $04, $07

sub_update_player_animation_speed:
    LDY #$00  ; initialize offset in Y
    LDA Player_XSpeedAbsolute  ; check player's walking/running speed
    CMP #$1c  ; against preset amount
    BCS SetRunSpd  ; if greater than a certain amount, branch ahead
    INY  ; otherwise increment Y
    CMP #$0e  ; compare against lower amount
    BCS ChkSkid  ; if greater than this but not greater than first, skip increment
    INY  ; otherwise increment Y again
ChkSkid:
    LDA SavedJoypadBits  ; get controller bits
    AND #%01111111  ; mask out A button
    BEQ SetAnimSpd  ; if no other buttons pressed, branch ahead of all this
    AND #$03  ; mask out all others except left and right
    CMP Player_MovingDir  ; check against moving direction
    BNE ProcSkid  ; if left/right controller bits <> moving direction, branch
    LDA #$00  ; otherwise set zero value here
SetRunSpd:
    STA RunningSpeed  ; store zero or running speed here
    JMP SetAnimSpd
ProcSkid:
    LDA Player_XSpeedAbsolute  ; check player's walking/running speed
    CMP #$0b  ; against one last amount
    BCS SetAnimSpd  ; if greater than this amount, branch
    LDA PlayerFacingDir
    STA Player_MovingDir  ; otherwise use facing direction to set moving direction
    LDA #$00
    STA Player_X_Speed  ; nullify player's horizontal speed
    STA Player_X_MoveForce  ; and dummy variable for player
SetAnimSpd:
    LDA tbl_player_animation_timer,y  ; get animation timer setting using Y as offset
    STA PlayerAnimTimerSet
    RTS

; -------------------------------------------------------------------------------------

sub_apply_player_horizontal_friction:
    AND Player_CollisionBits  ; perform AND between left/right controller bits and collision flag
    CMP #$00  ; then compare to zero (this instruction is redundant)
    BNE JoypFrict  ; if any bits set, branch to next part
    LDA Player_X_Speed
    BEQ SetAbsSpd  ; if player has no horizontal speed, branch ahead to last part
    BPL RghtFrict  ; if player moving to the right, branch to slow
    BMI LeftFrict  ; otherwise logic dictates player moving left, branch to slow
JoypFrict:
    LSR  ; put right controller bit into carry
    BCC RghtFrict  ; if left button pressed, carry = 0, thus branch
LeftFrict:
    LDA Player_X_MoveForce  ; load value set here
    CLC
    ADC FrictionAdderLow  ; add to it another value set here
    STA Player_X_MoveForce  ; store here
    LDA Player_X_Speed
    ADC FrictionAdderHigh  ; add value plus carry to horizontal speed
    STA Player_X_Speed  ; set as new horizontal speed
    CMP MaximumRightSpeed  ; compare against maximum value for right movement
    BMI XSpdSign  ; if horizontal speed greater negatively, branch
    LDA MaximumRightSpeed  ; otherwise set preset value as horizontal speed
    STA Player_X_Speed  ; thus slowing the player's left movement down
    JMP SetAbsSpd  ; skip to the end
RghtFrict:
    LDA Player_X_MoveForce  ; load value set here
    SEC
    SBC FrictionAdderLow  ; subtract from it another value set here
    STA Player_X_MoveForce  ; store here
    LDA Player_X_Speed
    SBC FrictionAdderHigh  ; subtract value plus borrow from horizontal speed
    STA Player_X_Speed  ; set as new horizontal speed
    CMP MaximumLeftSpeed  ; compare against maximum value for left movement
    BPL XSpdSign  ; if horizontal speed greater positively, branch
    LDA MaximumLeftSpeed  ; otherwise set preset value as horizontal speed
    STA Player_X_Speed  ; thus slowing the player's right movement down
XSpdSign:
    CMP #$00  ; if player not moving or moving to the right,
    BPL SetAbsSpd  ; branch and leave horizontal speed value unmodified
    EOR #$ff
    CLC  ; otherwise get two's compliment to get absolute
    ADC #$01  ; unsigned walking/running speed
SetAbsSpd:
    STA Player_XSpeedAbsolute  ; store walking/running speed here and leave
    RTS
