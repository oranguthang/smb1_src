sub_smb2_main_update_player_movement:
    LDA #$00  ; set A to init crouch flag by default
    LDY PlayerSize  ; is player small?
    BNE bra_smb2_main_store_crouching_flag  ; if so, branch
    LDA Player_State  ; check state of player
    BNE bra_smb2_main_process_player_movement  ; if not on the ground, branch
    LDA Up_Down_Buttons  ; load controller bits for up and down
    AND #%00000100  ; single out bit for down button
bra_smb2_main_store_crouching_flag:
    STA CrouchingFlag  ; store value in crouch flag
bra_smb2_main_process_player_movement:
    JSR sub_smb2_main_update_player_physics  ; run sub related to jumping and swimming
    LDA PlayerChangeSizeFlag  ; if growing/shrinking flag set,
    BNE bra_smb2_main_return_from_player_movement  ; branch to leave
    LDA Player_State
    CMP #$03  ; get player state
    BEQ bra_smb2_main_dispatch_player_state_movement  ; if climbing, branch ahead, leave timer unset
    LDY #$18
    STY ClimbSideTimer  ; otherwise reset timer now
bra_smb2_main_dispatch_player_state_movement:
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_player_on_ground
    .word handler_smb2_main_player_jumping_or_swimming
    .word handler_smb2_main_player_falling
    .word handler_smb2_main_player_climbing

bra_smb2_main_return_from_player_movement:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used by ClimbingSub to store high vertical adder

handler_smb2_main_player_on_ground:
    JSR sub_smb2_main_update_player_animation_speed  ; do a sub to set animation frame timing
    LDA Left_Right_Buttons
    BEQ bra_smb2_main_apply_ground_movement  ; if left/right controller bits not set, skip instruction
    STA PlayerFacingDir  ; otherwise set new facing direction
bra_smb2_main_apply_ground_movement:
    JSR sub_smb2_main_apply_player_horizontal_friction  ; do a sub to impose friction on player's walk/run
sub_smb2_main_jmp_move:
    JSR sub_smb2_main_move_player_horizontally  ; do another sub to move player horizontally
    STA Player_X_Scroll  ; set returned value as player's movement speed for scroll
    LDA FileListNumber  ; if in worlds 1-4 don't bother checking for wind
    BEQ bra_smb2_main_exit_player_scroll_update
    JSR sub_smb2_data4_blow_player_around
bra_smb2_main_exit_player_scroll_update:
    RTS

; --------------------------------

handler_smb2_main_player_falling:
    LDA VerticalForceDown
    STA VerticalForce  ; dump vertical movement force for falling into main one
    JMP bra_smb2_main_process_airborne_horizontal_input  ; movement force, then skip ahead to process left/right movement

; --------------------------------

handler_smb2_main_player_jumping_or_swimming:
    LDY Player_Y_Speed  ; if player's vertical speed zero
    BPL bra_smb2_main_use_falling_vertical_force  ; or moving downwards, branch to falling
    LDA A_B_Buttons
    AND #A_Button  ; check to see if A button is being pressed
    AND PreviousA_B_Buttons  ; and was pressed in previous frame
    BNE bra_smb2_main_check_swimming_state  ; if so, branch elsewhere
    LDA JumpOrigin_Y_Position  ; get vertical position player jumped from
    SEC
    SBC Player_Y_Position  ; subtract current from original vertical coordinate
    CMP DiffToHaltJump  ; compare to value set here to see if player is in mid-jump
    BCC bra_smb2_main_check_swimming_state  ; or just starting to jump, if just starting, skip ahead
bra_smb2_main_use_falling_vertical_force:
    LDA VerticalForceDown  ; otherwise dump falling into main fractional
    STA VerticalForce
bra_smb2_main_check_swimming_state:
    LDA SwimmingFlag  ; if swimming flag not set,
    BEQ bra_smb2_main_process_airborne_horizontal_input  ; branch ahead to last part
    JSR sub_smb2_main_update_player_animation_speed  ; do a sub to get animation frame timing
    LDA Player_Y_Position
    CMP #$14  ; check vertical position against preset value
    BCS bra_smb2_main_process_swimming_horizontal_input  ; if not yet reached a certain position, branch ahead
    LDA #$18
    STA VerticalForce  ; otherwise set fractional
bra_smb2_main_process_swimming_horizontal_input:
    LDA Left_Right_Buttons  ; check left/right controller bits (check for swimming)
    BEQ bra_smb2_main_process_airborne_horizontal_input  ; if not pressing any, skip
    STA PlayerFacingDir  ; otherwise set facing direction accordingly
bra_smb2_main_process_airborne_horizontal_input:
    LDA Left_Right_Buttons  ; check left/right controller bits (check for jumping/falling)
    BEQ bra_smb2_main_move_airborne_player  ; if not pressing any, skip
    JSR sub_smb2_main_apply_player_horizontal_friction  ; otherwise process horizontal movement
bra_smb2_main_move_airborne_player:
    JSR sub_smb2_main_jmp_move
    LDA GameEngineSubroutine
    CMP #$0b  ; check for specific routine selected
    BNE bra_smb2_main_move_player_vertically  ; branch if not set to run
    LDA #$28
    STA VerticalForce  ; otherwise set fractional
bra_smb2_main_move_player_vertically:
    JMP loc_smb2_main_move_player_vertically  ; jump to move player vertically, then leave

; --------------------------------

tbl_smb2_main_climb_side_x_delta_low:
    .byte $0e, $04, $fc, $f2
tbl_smb2_main_climb_side_x_delta_high:
    .byte $00, $00, $ff, $ff

handler_smb2_main_player_climbing:
    LDA Player_YMF_Dummy
    CLC  ; add movement force to dummy variable
    ADC Player_Y_MoveForce  ; save with carry
    STA Player_YMF_Dummy
    LDY #$00  ; set default adder here
    LDA Player_Y_Speed  ; get player's vertical speed
    BPL bra_smb2_main_apply_climbing_position  ; if not moving upwards, branch
    DEY  ; otherwise set adder to $ff
bra_smb2_main_apply_climbing_position:
    STY $00  ; store adder here
    ADC Player_Y_Position  ; add carry to player's vertical position
    STA Player_Y_Position  ; and store to move player up or down
    LDA Player_Y_HighPos
    ADC $00  ; add carry to player's page location
    STA Player_Y_HighPos  ; and store
    LDA Left_Right_Buttons  ; compare left/right controller bits
    AND Player_CollisionBits  ; to collision flag
    BEQ bra_smb2_main_clear_climb_side_timer  ; if not set, skip to end
    LDY ClimbSideTimer  ; otherwise check timer
    BNE bra_smb2_main_return_from_climbing_handler  ; if timer not expired, branch to leave
    LDY #$18
    STY ClimbSideTimer  ; otherwise set timer now
    LDX #$00  ; set default offset here
    LDY PlayerFacingDir  ; get facing direction
    LSR  ; move right button controller bit to carry
    BCS bra_smb2_main_select_climb_side_delta  ; if controller right pressed, branch ahead
    INX
    INX  ; otherwise increment offset by 2 bytes
bra_smb2_main_select_climb_side_delta:
    DEY  ; check to see if facing right
    BEQ bra_smb2_main_apply_climb_side_delta  ; if so, branch, do not increment
    INX  ; otherwise increment by 1 byte
bra_smb2_main_apply_climb_side_delta:
    LDA Player_X_Position
    CLC  ; add or subtract from player's horizontal position
    ADC tbl_smb2_main_climb_side_x_delta_low,x  ; using value here as adder and X as offset
    STA Player_X_Position
    LDA Player_PageLoc  ; add or subtract carry or borrow using value here
    ADC tbl_smb2_main_climb_side_x_delta_high,x  ; from the player's page location
    STA Player_PageLoc
    LDA Left_Right_Buttons  ; get left/right controller bits again
    EOR #%00000011  ; invert them and store them while player
    STA PlayerFacingDir  ; is on vine to face player in opposite direction
bra_smb2_main_return_from_climbing_handler:
    RTS  ; then leave
bra_smb2_main_clear_climb_side_timer:
    STA ClimbSideTimer  ; initialize timer here
    RTS

; -------------------------------------------------------------------------------------
; $00 - used to store offset to friction data

off_smb2_main_jump_gravity:
    .byte $20, $20, $1e, $28, $28, $0d, $04

off_smb2_main_fall_gravity:
    .byte $70, $70, $60, $90, $90, $0a, $09

off_smb2_main_horizontal_friction:
    .byte $e4, $98, $d0

off_smb2_main_initial_player_y_speed:
    .byte $fc, $fc, $fc, $fb, $fb, $fe, $ff

off_smb2_main_initial_player_y_speed_fraction:
    .byte $00, $00, $00, $00, $00, $80, $00

off_smb2_main_maximum_left_speed:
    .byte $d8, $e8, $f0

off_smb2_main_maximum_right_speed:
    .byte $28, $18, $10
    .byte $0c  ; used for pipe intros

off_smb2_main_climb_y_speed:
    .byte $00, $ff, $01

off_smb2_main_climb_y_speed_fraction:
    .byte $00, $20, $ff

sub_smb2_main_update_player_physics:
    LDA Player_State  ; check player state
    CMP #$03
    BNE bra_smb2_main_check_jump_input  ; if not climbing, branch
    LDY #$00
    LDA Up_Down_Buttons  ; get controller bits for up/down
    AND Player_CollisionBits  ; check against player's collision detection bits
    BEQ bra_smb2_main_set_climbing_motion  ; if not pressing up or down, branch
    INY
    AND #%00001000  ; check for pressing up
    BNE bra_smb2_main_set_climbing_motion
    INY
bra_smb2_main_set_climbing_motion:
    LDX off_smb2_main_climb_y_speed_fraction,y  ; load value here
    STX Player_Y_MoveForce  ; store as vertical movement force
    LDA #$08  ; load default animation timing
    LDX off_smb2_main_climb_y_speed,y  ; load some other value here
    STX Player_Y_Speed  ; store as vertical speed
    BMI bra_smb2_main_store_climbing_animation_timer  ; if climbing down, use default animation timing value
    LSR  ; otherwise divide timer setting by 2
bra_smb2_main_store_climbing_animation_timer:
    STA PlayerAnimTimerSet  ; store animation timer setting and leave
    RTS

bra_smb2_main_check_jump_input:
    LDA JumpspringAnimCtrl  ; if jumpspring animating,
    BNE bra_smb2_main_skip_jump_initialization  ; skip ahead to something else
    LDA A_B_Buttons  ; check for A button press
    AND #A_Button
    BEQ bra_smb2_main_skip_jump_initialization  ; if not, branch to something else
    AND PreviousA_B_Buttons  ; if button not pressed in previous frame, branch
    BEQ bra_smb2_main_process_jump_input
bra_smb2_main_skip_jump_initialization:
    JMP bra_smb2_main_configure_horizontal_physics  ; otherwise, jump to something else

bra_smb2_main_process_jump_input:
    LDA Player_State  ; check player state
    BEQ bra_smb2_main_initialize_jump_or_swim  ; if on the ground, branch
    LDA SwimmingFlag  ; if swimming flag not set, jump to do something else
    BEQ bra_smb2_main_skip_jump_initialization  ; to prevent midair jumping, otherwise continue
    LDA JumpSwimTimer  ; if jump/swim timer nonzero, branch
    BNE bra_smb2_main_initialize_jump_or_swim
    LDA Player_Y_Speed  ; check player's vertical speed
    BPL bra_smb2_main_initialize_jump_or_swim  ; if player's vertical speed motionless or down, branch
    JMP bra_smb2_main_configure_horizontal_physics  ; if timer at zero and player still rising, do not swim
bra_smb2_main_initialize_jump_or_swim:
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
    BCC bra_smb2_main_select_water_jump_profile  ; branch if below certain values, increment Y
    INY  ; for each amount equal or exceeded
    CMP #$10
    BCC bra_smb2_main_select_water_jump_profile
    INY
    CMP #$19
    BCC bra_smb2_main_select_water_jump_profile
    INY
    CMP #$1c
    BCC bra_smb2_main_select_water_jump_profile  ; note that for jumping, range is 0-4 for Y
    INY
bra_smb2_main_select_water_jump_profile:
    LDA #$01  ; set value here (apparently always set to 1)
    STA DiffToHaltJump
    LDA SwimmingFlag  ; if swimming flag disabled, branch
    BEQ bra_smb2_main_load_vertical_physics_profile
    LDY #$05  ; otherwise set Y to 5, range is 5-6
    LDA Whirlpool_Flag  ; if whirlpool flag not set, branch
    BEQ bra_smb2_main_load_vertical_physics_profile
    INY  ; otherwise increment to 6
bra_smb2_main_load_vertical_physics_profile:
    LDA off_smb2_main_jump_gravity,y  ; store appropriate jump/swim
    STA VerticalForce  ; data here
    LDA off_smb2_main_fall_gravity,y
    STA VerticalForceDown
    LDA off_smb2_main_initial_player_y_speed_fraction,y
    STA Player_Y_MoveForce
    LDA off_smb2_main_initial_player_y_speed,y
    STA Player_Y_Speed
    LDA SwimmingFlag  ; if swimming flag disabled, branch
    BEQ bra_smb2_main_queue_jump_sound
    LDA #Sfx_EnemyStomp  ; load swim/goomba stomp sound into
    STA Square1SoundQueue  ; square 1's sfx queue
    LDA Player_Y_Position
    CMP #$14  ; check vertical low byte of player position
    BCS bra_smb2_main_configure_horizontal_physics  ; if below a certain point, branch
    LDA #$00  ; otherwise reset player's vertical speed
    STA Player_Y_Speed  ; and jump to something else to keep player
    JMP bra_smb2_main_configure_horizontal_physics  ; from swimming above water level
bra_smb2_main_queue_jump_sound:
    LDA #Sfx_BigJump  ; load big mario's jump sound by default
    LDY PlayerSize  ; is mario big?
    BEQ bra_smb2_main_store_jump_sound
    LDA #Sfx_SmallJump  ; if not, load small mario's jump sound
bra_smb2_main_store_jump_sound:
    STA Square1SoundQueue  ; store appropriate jump sound in square 1 sfx queue
bra_smb2_main_configure_horizontal_physics:
    LDY #$00
    STY $00  ; init value here
    LDA Player_State  ; if mario is on the ground, branch
    BEQ bra_smb2_main_process_ground_running
    LDA Player_XSpeedAbsolute  ; check something that seems to be related
    CMP #$19  ; to mario's speed
    BCS bra_smb2_main_load_horizontal_speed_limits  ; if =>$19 branch here
    BCC bra_smb2_main_select_running_speed_profile  ; if not branch elsewhere
bra_smb2_main_process_ground_running:
    INY  ; if mario on the ground, increment Y
    LDA AreaType  ; check area type
    BEQ bra_smb2_main_select_running_speed_profile  ; if water type, branch
    DEY  ; decrement Y by default for non-water type area
    LDA Left_Right_Buttons  ; get left/right controller bits
    CMP Player_MovingDir  ; check against moving direction
    BNE bra_smb2_main_select_running_speed_profile  ; if controller bits <> moving direction, skip this part
    LDA A_B_Buttons  ; check for b button pressed
    AND #B_Button
    BNE bra_smb2_main_set_running_timer  ; if pressed, skip ahead to set timer
    LDA RunningTimer  ; check for running timer set
    BNE bra_smb2_main_load_horizontal_speed_limits  ; if set, branch
bra_smb2_main_select_running_speed_profile:
    INY  ; if running timer not set or level type is water,
    INC $00  ; increment Y again and temp variable in memory
    LDA RunningSpeed
    BNE bra_smb2_main_use_fast_friction  ; if running speed set here, branch
    LDA Player_XSpeedAbsolute
    CMP #$21  ; otherwise check player's walking/running speed
    BCC bra_smb2_main_load_horizontal_speed_limits  ; if less than a certain amount, branch ahead
bra_smb2_main_use_fast_friction:
    INC $00  ; if running speed set or speed => $21 increment $00
    JMP bra_smb2_main_load_horizontal_speed_limits  ; and jump ahead
bra_smb2_main_set_running_timer:
    LDA #$0a  ; if b button pressed, set running timer
    STA RunningTimer
bra_smb2_main_load_horizontal_speed_limits:
    LDA off_smb2_main_maximum_left_speed,y  ; get maximum speed to the left
    STA MaximumLeftSpeed
    LDA GameEngineSubroutine  ; check for specific routine running
    CMP #$07  ; (player entrance)
    BNE bra_smb2_main_load_right_speed_limit  ; if not running, skip and use old value of Y
    LDY #$03  ; otherwise set Y to 3
bra_smb2_main_load_right_speed_limit:
    LDA off_smb2_main_maximum_right_speed,y  ; get maximum speed to the right
    STA MaximumRightSpeed
    LDY $00  ; get other value in memory
    LDA off_smb2_main_horizontal_friction,y  ; get value using value in memory as offset
    STA FrictionAdderLow
    LDA #$00
    STA FrictionAdderHigh  ; init something here
    LDA PlayerFacingDir
    CMP Player_MovingDir  ; check facing direction against moving direction
    BEQ bra_smb2_main_return_from_player_physics  ; if the same, branch to leave
loc_smb2_main_phy_opcode:
    ASL FrictionAdderLow  ; otherwise multiply friction by 2
    ROL FrictionAdderHigh  ; then leave (or just leave, if code was modified earlier
bra_smb2_main_return_from_player_physics:
    RTS

; -------------------------------------------------------------------------------------

off_smb2_main_player_animation_timer:
    .byte $02, $04, $07

sub_smb2_main_update_player_animation_speed:
    LDY #$00  ; initialize offset in Y
    LDA Player_XSpeedAbsolute  ; check player's walking/running speed
    CMP #$1c  ; against preset amount
    BCS bra_smb2_main_store_running_speed  ; if greater than a certain amount, branch ahead
    INY  ; otherwise increment Y
    CMP #$0e  ; compare against lower amount
    BCS bra_smb2_main_check_player_skid  ; if greater than this but not greater than first, skip increment
    INY  ; otherwise increment Y again
bra_smb2_main_check_player_skid:
    LDA SavedJoypadBits  ; get controller bits
    AND #%01111111  ; mask out A button
    BEQ bra_smb2_main_store_player_animation_timer  ; if no other buttons pressed, branch ahead of all this
    AND #$03  ; mask out all others except left and right
    CMP Player_MovingDir  ; check against moving direction
    BNE bra_smb2_main_process_player_skid  ; if left/right controller bits <> moving direction, branch
    LDA #$00  ; otherwise set zero value here
bra_smb2_main_store_running_speed:
    STA RunningSpeed  ; store zero or running speed here
    JMP bra_smb2_main_store_player_animation_timer
bra_smb2_main_process_player_skid:
    LDA Player_XSpeedAbsolute  ; check player's walking/running speed
    CMP #$0b  ; against one last amount
    BCS bra_smb2_main_store_player_animation_timer  ; if greater than this amount, branch
    LDA PlayerFacingDir
    STA Player_MovingDir  ; otherwise use facing direction to set moving direction
    LDA #$00
    STA Player_X_Speed  ; nullify player's horizontal speed
    STA Player_X_MoveForce  ; and dummy variable for player
bra_smb2_main_store_player_animation_timer:
    LDA off_smb2_main_player_animation_timer,y  ; get animation timer setting using Y as offset
    STA PlayerAnimTimerSet
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_apply_player_horizontal_friction:
    AND Player_CollisionBits  ; perform AND between left/right controller bits and collision flag
    CMP #$00  ; then compare to zero (this instruction is redundant)
    BNE bra_smb2_main_apply_input_friction  ; if any bits set, branch to next part
    LDA Player_X_Speed
    BEQ bra_smb2_main_store_absolute_x_speed  ; if player has no horizontal speed, branch ahead to last part
    BPL bra_smb2_main_accelerate_player_left  ; if player moving to the right, branch to slow
    BMI bra_smb2_main_accelerate_player_right  ; otherwise logic dictates player moving left, branch to slow
bra_smb2_main_apply_input_friction:
    LSR  ; put right controller bit into carry
    BCC bra_smb2_main_accelerate_player_left  ; if left button pressed, carry = 0, thus branch
bra_smb2_main_accelerate_player_right:
    LDA Player_X_MoveForce  ; load value set here
    CLC
    ADC FrictionAdderLow  ; add to it another value set here
    STA Player_X_MoveForce  ; store here
    LDA Player_X_Speed
    ADC FrictionAdderHigh  ; add value plus carry to horizontal speed
    STA Player_X_Speed  ; set as new horizontal speed
    CMP MaximumRightSpeed  ; compare against maximum value for right movement
    BMI bra_smb2_main_compute_absolute_x_speed  ; if horizontal speed greater negatively, branch
    LDA MaximumRightSpeed  ; otherwise set preset value as horizontal speed
    STA Player_X_Speed  ; thus slowing the player's left movement down
    JMP bra_smb2_main_store_absolute_x_speed  ; skip to the end
bra_smb2_main_accelerate_player_left:
    LDA Player_X_MoveForce  ; load value set here
    SEC
    SBC FrictionAdderLow  ; subtract from it another value set here
    STA Player_X_MoveForce  ; store here
    LDA Player_X_Speed
    SBC FrictionAdderHigh  ; subtract value plus borrow from horizontal speed
    STA Player_X_Speed  ; set as new horizontal speed
    CMP MaximumLeftSpeed  ; compare against maximum value for left movement
    BPL bra_smb2_main_compute_absolute_x_speed  ; if horizontal speed greater positively, branch
    LDA MaximumLeftSpeed  ; otherwise set preset value as horizontal speed
    STA Player_X_Speed  ; thus slowing the player's right movement down
bra_smb2_main_compute_absolute_x_speed:
    CMP #$00  ; if player not moving or moving to the right,
    BPL bra_smb2_main_store_absolute_x_speed  ; branch and leave horizontal speed value unmodified
    EOR #$ff
    CLC  ; otherwise get two's compliment to get absolute
    ADC #$01  ; unsigned walking/running speed
bra_smb2_main_store_absolute_x_speed:
    STA Player_XSpeedAbsolute  ; store walking/running speed here and leave
    RTS

; -------------------------------------------------------------------------------------
; $00 - used to store downward movement force in FireballObjCore
; $02 - used to store maximum vertical speed in FireballObjCore
; $07 - used to store pseudorandom bit in BubbleCheck

sub_smb2_main_process_fireballs_and_bubbles:
    LDA PlayerStatus  ; check player's status
    CMP #$02
    BCC bra_smb2_main_process_air_bubble_slots  ; if not fiery, branch
    LDA A_B_Buttons
    AND #B_Button  ; check for b button pressed
    BEQ bra_smb2_main_process_fireball_slots  ; branch if not pressed
    AND PreviousA_B_Buttons
    BNE bra_smb2_main_process_fireball_slots  ; if button pressed in previous frame, branch
    LDA FireballCounter  ; load fireball counter
    AND #%00000001  ; get LSB and use as offset for buffer
    TAX
    LDA Fireball_State,x  ; load fireball state
    BNE bra_smb2_main_process_fireball_slots  ; if not inactive, branch
    LDY Player_Y_HighPos  ; if player too high or too low, branch
    DEY
    BNE bra_smb2_main_process_fireball_slots
    LDA CrouchingFlag  ; if player crouching, branch
    BNE bra_smb2_main_process_fireball_slots
    LDA Player_State  ; if player's state = climbing, branch
    CMP #$03
    BEQ bra_smb2_main_process_fireball_slots
    LDA #Sfx_Fireball  ; play fireball sound effect
    STA Square1SoundQueue
    LDA #$02  ; load state
    STA Fireball_State,x
    LDY PlayerAnimTimerSet  ; copy animation frame timer setting
    STY FireballThrowingTimer  ; into fireball throwing timer
    DEY
    STY PlayerAnimTimer  ; decrement and store in player's animation timer
    INC FireballCounter  ; increment fireball counter

bra_smb2_main_process_fireball_slots:
    LDX #$00
    JSR sub_smb2_main_process_fireball_object  ; process first fireball object
    LDX #$01
    JSR sub_smb2_main_process_fireball_object  ; process second fireball object, then do air bubbles

bra_smb2_main_process_air_bubble_slots:
    LDA AreaType  ; if not water type level, skip the rest of this
    BNE bra_smb2_main_exit_bubble_processing
    LDX #$02  ; otherwise load counter and use as offset
bra_smb2_main_process_bubble_slots:
    STX ObjectOffset  ; store offset
    JSR sub_smb2_main_bubble_check  ; check timers and coordinates, create air bubble
    JSR sub_smb2_main_relative_bubble_position  ; get relative coordinates
    JSR sub_smb2_main_get_bubble_offscreen_bits  ; get offscreen information
    JSR sub_smb2_main_draw_bubble  ; draw the air bubble
    DEX
    BPL bra_smb2_main_process_bubble_slots  ; do this until all three are handled
bra_smb2_main_exit_bubble_processing:
    RTS  ; then leave

off_smb2_main_fireball_x_speeds:
    .byte $40, $c0

sub_smb2_main_process_fireball_object:
    STX ObjectOffset  ; store offset as current object
    LDA Fireball_State,x  ; check for d7 = 1
    ASL
    BCS bra_smb2_main_process_fireball_explosion  ; if so, branch to get relative coordinates and draw explosion
    LDY Fireball_State,x  ; if fireball inactive, branch to leave
    BEQ bra_smb2_main_skip_inactive_fireball
    DEY  ; if fireball state set to 1, skip this part and just run it
    BEQ bra_smb2_main_update_active_fireball
    LDA Player_X_Position  ; get player's horizontal position
    ADC #$04  ; add four pixels and store as fireball's horizontal position
    STA Fireball_X_Position,x
    LDA Player_PageLoc  ; get player's page location
    ADC #$00  ; add carry and store as fireball's page location
    STA Fireball_PageLoc,x
    LDA Player_Y_Position  ; get player's vertical position and store
    STA Fireball_Y_Position,x
    LDA #$01  ; set high byte of vertical position
    STA Fireball_Y_HighPos,x
    LDY PlayerFacingDir  ; get player's facing direction
    DEY  ; decrement to use as offset here
    LDA off_smb2_main_fireball_x_speeds,y  ; set horizontal speed of fireball accordingly
    STA Fireball_X_Speed,x
    LDA #$04  ; set vertical speed of fireball
    STA Fireball_Y_Speed,x
    LDA #$07
    STA Fireball_BoundBoxCtrl,x  ; set bounding box size control for fireball
    DEC Fireball_State,x  ; decrement state to 1 to skip this part from now on
bra_smb2_main_update_active_fireball:
    TXA  ; add 7 to offset to use
    CLC  ; as fireball offset for next routines
    ADC #$07
    TAX
    LDA #$50  ; set downward movement force here
    STA $00
    LDA #$03  ; set maximum speed here
    STA $02
    LDA #$00
    JSR sub_smb2_main_apply_object_gravity  ; do sub here to impose gravity on fireball and move vertically
    JSR sub_smb2_main_move_object_horizontally  ; do another sub to move it horizontally
    LDX ObjectOffset  ; return fireball offset to X
    JSR sub_smb2_main_relative_fireball_position  ; get relative coordinates
    JSR sub_smb2_main_get_fireball_offscreen_bits  ; get offscreen information
    JSR sub_smb2_main_get_fireball_bound_box  ; get bounding box coordinates
    JSR sub_smb2_main_handle_fireball_background_collision  ; do fireball to background collision detection
    LDA FBall_OffscreenBits  ; get fireball offscreen bits
    AND #%11001100  ; mask out certain bits
    BNE bra_smb2_main_erase_fireball  ; if any bits still set, branch to kill fireball
    JSR sub_smb2_main_fireball_enemy_collision  ; do fireball to enemy collision detection and deal with collisions
    JMP loc_smb2_main_draw_fireball  ; draw fireball appropriately and leave
bra_smb2_main_erase_fireball:
    LDA #$00  ; erase fireball state
    STA Fireball_State,x
bra_smb2_main_skip_inactive_fireball:
    RTS  ; leave

bra_smb2_main_process_fireball_explosion:
    JSR sub_smb2_main_relative_fireball_position
    JMP loc_smb2_main_draw_fireball_explosion

sub_smb2_main_bubble_check:
    LDA PseudoRandomBitReg+1,x  ; get part of LSFR
    AND #$01
    STA $07  ; store pseudorandom bit here
    LDA Bubble_Y_Position,x  ; get vertical coordinate for air bubble
    CMP #$f8  ; if offscreen coordinate not set,
    BNE bra_smb2_main_move_air_bubble  ; branch to move air bubble
    LDA AirBubbleTimer  ; if air bubble timer not expired,
    BNE bra_smb2_main_exit_bubble_motion  ; branch to leave, otherwise create new air bubble

sub_smb2_main_setup_bubble:
    LDY #$00  ; load default value here
    LDA PlayerFacingDir  ; get player's facing direction
    LSR  ; move d0 to carry
    BCC bra_smb2_main_position_bubble  ; branch to use default value if facing left
    LDY #$08  ; otherwise load alternate value here
bra_smb2_main_position_bubble:
    TYA  ; use value loaded as adder
    ADC Player_X_Position  ; add to player's horizontal position
    STA Bubble_X_Position,x  ; save as horizontal position for airbubble
    LDA Player_PageLoc
    ADC #$00  ; add carry to player's page location
    STA Bubble_PageLoc,x  ; save as page location for airbubble
    LDA Player_Y_Position
    CLC  ; add eight pixels to player's vertical position
    ADC #$08
    STA Bubble_Y_Position,x  ; save as vertical position for air bubble
    LDA #$01
    STA Bubble_Y_HighPos,x  ; set vertical high byte for air bubble
    LDY $07  ; get pseudorandom bit, use as offset
    LDA off_smb2_main_air_bubble_spawn_delays,y  ; get data for air bubble timer
    STA AirBubbleTimer  ; set air bubble timer
bra_smb2_main_move_air_bubble:
    LDY $07  ; get pseudorandom bit again, use as offset
    LDA Bubble_YMF_Dummy,x
    SEC  ; subtract pseudorandom amount from dummy variable
    SBC off_smb2_main_air_bubble_y_force_adjustments,y
    STA Bubble_YMF_Dummy,x  ; save dummy variable
    LDA Bubble_Y_Position,x
    SBC #$00  ; subtract borrow from airbubble's vertical coordinate
    CMP #$20  ; if below the status bar,
    BCS bra_smb2_main_move_air_bubble_vertically  ; branch to go ahead and use to move air bubble upwards
    LDA #$f8  ; otherwise set offscreen coordinate
bra_smb2_main_move_air_bubble_vertically:
    STA Bubble_Y_Position,x  ; store as new vertical coordinate for air bubble
bra_smb2_main_exit_bubble_motion:
    RTS  ; leave

off_smb2_main_air_bubble_y_force_adjustments:
    .byte $ff, $50

off_smb2_main_air_bubble_spawn_delays:
    .byte $40, $20

; -------------------------------------------------------------------------------------
