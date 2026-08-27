; -------------------------------------------------------------------------------------

; Apply input and state-specific movement for the current player frame

; Inputs:
; ram_player_state - ground, jump/swim, fall, or climb state
; ram_a_b_buttons - current A/B button bits
; ram_left_right_buttons - current horizontal input bits
; ram_up_down_buttons - current vertical input bits

; Outputs:
; Player position, speed, facing, crouch, and animation timing may change

; Clobbers:
; A, X, Y
sub_update_player_movement:
    LDA #$00  ; set A to init crouch flag by default
    LDY ram_player_size  ; is player small?
    BNE bra_store_crouching_flag  ; if so, branch
    LDA ram_player_state  ; check state of player
    BNE bra_process_player_movement  ; if not on the ground, branch
    LDA ram_up_down_buttons  ; load controller bits for up and down
    AND #%00000100  ; single out bit for down button
bra_store_crouching_flag:
    STA ram_crouching_flag  ; store value in crouch flag
bra_process_player_movement:
    JSR sub_update_player_physics  ; run sub related to jumping and swimming
    LDA ram_player_change_size_flag  ; if growing/shrinking flag set,
    BNE bra_return_from_player_movement  ; branch to leave
    LDA ram_player_state
    CMP #$03  ; get player state
    BEQ bra_dispatch_player_state_movement  ; if climbing, branch ahead, leave timer unset
    LDY #$18
    STY ram_climb_side_timer  ; otherwise reset timer now
bra_dispatch_player_state_movement:
    JSR sub_dispatch_inline_handler

tbl_player_state_movement_handlers:
    .word handler_player_on_ground
    .word handler_player_jumping_or_swimming
    .word handler_player_falling
    .word handler_player_climbing

bra_return_from_player_movement:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used by handler_player_climbing to store high vertical adder

; Apply animation, friction, and horizontal motion while grounded
handler_player_on_ground:
    JSR sub_update_player_animation_speed  ; do a sub to set animation frame timing
    LDA ram_left_right_buttons
    BEQ bra_apply_ground_movement  ; if left/right controller bits not set, skip instruction
    STA ram_player_facing_dir  ; otherwise set new facing direction
bra_apply_ground_movement:
    JSR sub_apply_player_horizontal_friction  ; do a sub to impose friction on player's walk/run
    JSR sub_move_player_horizontally  ; do another sub to move player horizontally
    STA ram_player_x_scroll  ; set returned value as player's movement speed for scroll
    RTS

; --------------------------------

; Select falling gravity before entering shared airborne movement
handler_player_falling:
    LDA ram_player_fall_gravity
    STA ram_player_active_gravity  ; dump vertical movement force for falling into main one
    JMP loc_process_airborne_horizontal_input  ; movement force, then skip ahead to process left/right movement

; --------------------------------

; Apply variable-height jump or swimming motion and horizontal air control
handler_player_jumping_or_swimming:
    LDY ram_player_y_speed  ; if player's vertical speed zero
    BPL bra_use_falling_vertical_force  ; or moving downwards, branch to falling
    LDA ram_a_b_buttons
    AND #con_btn_a  ; check to see if A button is being pressed
    AND ram_previous_a_b_buttons  ; and was pressed in previous frame
    BNE bra_check_swimming_state  ; if so, branch elsewhere
    LDA ram_jump_origin_y_position  ; get vertical position player jumped from
    SEC
    SBC ram_player_y_position  ; subtract current from original vertical coordinate
    CMP ram_jump_release_min_displacement  ; compare to value set here to see if player is in mid-jump
    BCC bra_check_swimming_state  ; or just starting to jump, if just starting, skip ahead
bra_use_falling_vertical_force:
    LDA ram_player_fall_gravity  ; otherwise dump falling into main fractional
    STA ram_player_active_gravity
bra_check_swimming_state:
    LDA ram_swimming_flag  ; if swimming flag not set,
    BEQ loc_process_airborne_horizontal_input  ; branch ahead to last part
    JSR sub_update_player_animation_speed  ; do a sub to get animation frame timing
    LDA ram_player_y_position
    CMP #$14  ; check vertical position against preset value
    BCS bra_process_swimming_horizontal_input  ; if not yet reached a certain position, branch ahead
    LDA #$18
    STA ram_player_active_gravity  ; otherwise set fractional
bra_process_swimming_horizontal_input:
    LDA ram_left_right_buttons  ; check left/right controller bits (check for swimming)
    BEQ loc_process_airborne_horizontal_input  ; if not pressing any, skip
    STA ram_player_facing_dir  ; otherwise set facing direction accordingly
loc_process_airborne_horizontal_input:
    LDA ram_left_right_buttons  ; check left/right controller bits (check for jumping/falling)
    BEQ bra_move_airborne_player  ; if not pressing any, skip
    JSR sub_apply_player_horizontal_friction  ; otherwise process horizontal movement
bra_move_airborne_player:
    JSR sub_move_player_horizontally  ; do a sub to move player horizontally
    STA ram_player_x_scroll  ; set player's speed here, to be used for scroll later
    LDA ram_game_engine_subroutine
    CMP #$0b  ; check for specific routine selected
    BNE bra_move_player_vertically  ; branch if not set to run
    LDA #$28
    STA ram_player_active_gravity  ; otherwise set fractional
bra_move_player_vertically:
    JMP loc_move_player_vertically  ; jump to move player vertically, then leave

; --------------------------------

tbl_climb_side_x_delta_low:
    .byte $0e, $04, $fc, $f2
tbl_climb_side_x_delta_high:
    .byte $00, $00, $ff, $ff

; Move the player vertically on a vine and handle side switching
handler_player_climbing:
    LDA ram_player_y_position_fraction
    CLC  ; add movement force to dummy variable
    ADC ram_player_y_speed_fraction  ; save with carry
    STA ram_player_y_position_fraction
    LDY #$00  ; set default adder here
    LDA ram_player_y_speed  ; get player's vertical speed
    BPL bra_apply_climbing_position  ; if not moving upwards, branch
    DEY  ; otherwise set adder to $ff
bra_apply_climbing_position:
    STY $00  ; store adder here
    ADC ram_player_y_position  ; add carry to player's vertical position
    STA ram_player_y_position  ; and store to move player up or down
    LDA ram_player_y_high_pos
    ADC $00  ; add carry to player's page location
    STA ram_player_y_high_pos  ; and store
    LDA ram_left_right_buttons  ; compare left/right controller bits
    AND ram_player_collision_bits  ; to collision flag
    BEQ bra_clear_climb_side_timer  ; if not set, skip to end
    LDY ram_climb_side_timer  ; otherwise check timer
    BNE bra_return_from_climbing_handler  ; if timer not expired, branch to leave
    LDY #$18
    STY ram_climb_side_timer  ; otherwise set timer now
    LDX #$00  ; set default offset here
    LDY ram_player_facing_dir  ; get facing direction
    LSR  ; move right button controller bit to carry
    BCS bra_select_climb_side_delta  ; if controller right pressed, branch ahead
    INX
    INX  ; otherwise increment offset by 2 bytes
bra_select_climb_side_delta:
    DEY  ; check to see if facing right
    BEQ bra_apply_climb_side_delta  ; if so, branch, do not increment
    INX  ; otherwise increment by 1 byte
bra_apply_climb_side_delta:
    LDA ram_player_x_position
    CLC  ; add or subtract from player's horizontal position
    ADC tbl_climb_side_x_delta_low,x  ; using value here as adder and X as offset
    STA ram_player_x_position
    LDA ram_player_page_loc  ; add or subtract carry or borrow using value here
    ADC tbl_climb_side_x_delta_high,x  ; from the player's page location
    STA ram_player_page_loc
    LDA ram_left_right_buttons  ; get left/right controller bits again
    EOR #%00000011  ; invert them and store them while player
    STA ram_player_facing_dir  ; is on vine to face player in opposite direction
bra_return_from_climbing_handler:
    RTS  ; then leave
bra_clear_climb_side_timer:
    STA ram_climb_side_timer  ; initialize timer here
    RTS

; -------------------------------------------------------------------------------------
; $00 - used to store offset to friction data

tbl_jump_gravity:
.if con_revision_profile = con_revision_profile_pal
    .byte $30, $30, $2d, $38, $38, $0d, $04
.else
    .byte $20, $20, $1e, $28, $28, $0d, $04
.endif

tbl_fall_gravity:
.if con_revision_profile = con_revision_profile_pal
    .byte $a8, $a8, $90, $d0, $d0, $0a, $09
.else
    .byte $70, $70, $60, $90, $90, $0a, $09
.endif

tbl_initial_player_y_speed:
.if con_revision_profile = con_revision_profile_pal
    .byte $fb, $fb, $fb, $fa, $fa, $fe, $ff
.else
    .byte $fc, $fc, $fc, $fb, $fb, $fe, $ff
.endif

tbl_initial_player_y_speed_fraction:
.if con_revision_profile = con_revision_profile_pal
    .byte $34, $34, $34, $00, $00, $80, $00
.else
    .byte $00, $00, $00, $00, $00, $80, $00
.endif

tbl_maximum_left_speed:
.if con_revision_profile = con_revision_profile_pal
    .byte $d0, $e4, $ed
.else
    .byte $d8, $e8, $f0
.endif

tbl_maximum_right_speed:
.if con_revision_profile = con_revision_profile_pal
    .byte $30, $1c, $13
    .byte $0e  ; used for pipe intros
.else
    .byte $28, $18, $10
    .byte $0c  ; used for pipe intros
.endif

tbl_horizontal_friction:
.if con_revision_profile = con_revision_profile_pal
    .byte $c0, $00, $80
.else
    .byte $e4, $98, $d0
.endif

tbl_climb_y_speed:
    .byte $00, $ff, $01

tbl_climb_y_speed_fraction:
    .byte $00, $20, $ff

; Select vertical and horizontal physics parameters for this frame

; Inputs:
; ram_player_state - current movement state
; ram_player_x_speed_absolute - unsigned horizontal speed magnitude
; ram_a_b_buttons - current A/B input
; ram_previous_a_b_buttons - prior-frame A/B input

; Outputs:
; Jump state, gravity, speed limits, friction, and climb motion may change

; Clobbers:
; A, X, Y
sub_update_player_physics:
    LDA ram_player_state  ; check player state
    CMP #$03
    BNE bra_check_jump_input  ; if not climbing, branch
    LDY #$00
    LDA ram_up_down_buttons  ; get controller bits for up/down
    AND ram_player_collision_bits  ; check against player's collision detection bits
    BEQ bra_set_climbing_motion  ; if not pressing up or down, branch
    INY
    AND #%00001000  ; check for pressing up
    BNE bra_set_climbing_motion
    INY
bra_set_climbing_motion:
    LDX tbl_climb_y_speed_fraction,y  ; load value here
    STX ram_player_y_speed_fraction  ; store as vertical movement force
    LDA #$08  ; load default animation timing
    LDX tbl_climb_y_speed,y  ; load some other value here
    STX ram_player_y_speed  ; store as vertical speed
    BMI bra_store_climbing_animation_timer  ; if climbing down, use default animation timing value
    LSR  ; otherwise divide timer setting by 2
bra_store_climbing_animation_timer:
    STA ram_player_anim_timer_reload  ; store animation timer setting and leave
    RTS

bra_check_jump_input:
    LDA ram_jumpspring_anim_ctrl  ; if jumpspring animating,
    BNE bra_skip_jump_initialization  ; skip ahead to something else
    LDA ram_a_b_buttons  ; check for A button press
    AND #con_btn_a
    BEQ bra_skip_jump_initialization  ; if not, branch to something else
    AND ram_previous_a_b_buttons  ; if button not pressed in previous frame, branch
    BEQ bra_process_jump_input
bra_skip_jump_initialization:
    JMP loc_configure_horizontal_physics  ; otherwise, jump to something else

bra_process_jump_input:
    LDA ram_player_state  ; check player state
    BEQ bra_initialize_jump_or_swim  ; if on the ground, branch
    LDA ram_swimming_flag  ; if swimming flag not set, jump to do something else
    BEQ bra_skip_jump_initialization  ; to prevent midair jumping, otherwise continue
    LDA ram_jump_swim_timer  ; if jump/swim timer nonzero, branch
    BNE bra_initialize_jump_or_swim
    LDA ram_player_y_speed  ; check player's vertical speed
    BPL bra_initialize_jump_or_swim  ; if player's vertical speed motionless or down, branch
    JMP loc_configure_horizontal_physics  ; if timer at zero and player still rising, do not swim
bra_initialize_jump_or_swim:
    LDA #$20  ; set jump/swim timer
    STA ram_jump_swim_timer
    LDY #$00  ; initialize vertical force and dummy variable
    STY ram_player_y_position_fraction
    STY ram_player_y_speed_fraction
    LDA ram_player_y_high_pos  ; get vertical high and low bytes of jump origin
    STA ram_jump_origin_y_high_pos  ; and store them next to each other here
    LDA ram_player_y_position
    STA ram_jump_origin_y_position
    LDA #$01  ; set player state to jumping/swimming
    STA ram_player_state
    LDA ram_player_x_speed_absolute  ; check value related to walking/running speed
    CMP #con_jump_speed_cutoff_a
    BCC bra_select_water_jump_profile  ; branch if below certain values, increment Y
    INY  ; for each amount equal or exceeded
    CMP #con_jump_speed_cutoff_b
    BCC bra_select_water_jump_profile
    INY
    CMP #con_jump_speed_cutoff_c
    BCC bra_select_water_jump_profile
    INY
    CMP #con_jump_speed_cutoff_d
    BCC bra_select_water_jump_profile  ; note that for jumping, range is 0-4 for Y
    INY
bra_select_water_jump_profile:
    LDA #$01  ; set value here (apparently always set to 1)
    STA ram_jump_release_min_displacement
    LDA ram_swimming_flag  ; if swimming flag disabled, branch
    BEQ bra_load_vertical_physics_profile
    LDY #$05  ; otherwise set Y to 5, range is 5-6
    LDA ram_whirlpool_flag  ; if whirlpool flag not set, branch
    BEQ bra_load_vertical_physics_profile
    INY  ; otherwise increment to 6
bra_load_vertical_physics_profile:
    LDA tbl_jump_gravity,y  ; store appropriate jump/swim
    STA ram_player_active_gravity  ; data here
    LDA tbl_fall_gravity,y
    STA ram_player_fall_gravity
    LDA tbl_initial_player_y_speed_fraction,y
    STA ram_player_y_speed_fraction
    LDA tbl_initial_player_y_speed,y
    STA ram_player_y_speed
    LDA ram_swimming_flag  ; if swimming flag disabled, branch
    BEQ bra_queue_jump_sound
    LDA #con_sfx_enemy_stomp  ; load swim/goomba stomp sound into
    STA ram_square1_sound_queue  ; square 1's sfx queue
    LDA ram_player_y_position
    CMP #$14  ; check vertical low byte of player position
    BCS loc_configure_horizontal_physics  ; if below a certain point, branch
    LDA #$00  ; otherwise reset player's vertical speed
    STA ram_player_y_speed  ; and jump to something else to keep player
    JMP loc_configure_horizontal_physics  ; from swimming above water level
bra_queue_jump_sound:
    LDA #con_sfx_big_jump  ; load big mario's jump sound by default
    LDY ram_player_size  ; is mario big?
    BEQ bra_store_jump_sound
    LDA #con_sfx_small_jump  ; if not, load small mario's jump sound
bra_store_jump_sound:
    STA ram_square1_sound_queue  ; store appropriate jump sound in square 1 sfx queue
loc_configure_horizontal_physics:
    LDY #$00
    STY $00  ; init value here
    LDA ram_player_state  ; if mario is on the ground, branch
    BEQ bra_process_ground_running
    LDA ram_player_x_speed_absolute  ; check something that seems to be related
    CMP #con_jump_speed_cutoff_c  ; to mario's speed
    BCS loc_load_horizontal_speed_limits  ; if =>$19 branch here
    BCC bra_select_running_speed_profile  ; if not branch elsewhere
bra_process_ground_running:
    INY  ; if mario on the ground, increment Y
    LDA ram_area_type  ; check area type
    BEQ bra_select_running_speed_profile  ; if water type, branch
    DEY  ; decrement Y by default for non-water type area
    LDA ram_left_right_buttons  ; get left/right controller bits
    CMP ram_player_moving_dir  ; check against moving direction
    BNE bra_select_running_speed_profile  ; if controller bits <> moving direction, skip this part
    LDA ram_a_b_buttons  ; check for b button pressed
    AND #con_btn_b
    BNE bra_set_running_timer  ; if pressed, skip ahead to set timer
    LDA ram_running_timer  ; check for running timer set
    BNE loc_load_horizontal_speed_limits  ; if set, branch
bra_select_running_speed_profile:
    INY  ; if running timer not set or level type is water,
    INC $00  ; increment Y again and temp variable in memory
    LDA ram_running_speed
    BNE bra_use_fast_friction  ; if running speed set here, branch
    LDA ram_player_x_speed_absolute
    CMP #con_player_slow_speed_cap  ; otherwise check player's walking/running speed
    BCC loc_load_horizontal_speed_limits  ; if less than a certain amount, branch ahead
bra_use_fast_friction:
    INC $00  ; if running speed set or speed => $21 increment $00
    JMP loc_load_horizontal_speed_limits  ; and jump ahead
bra_set_running_timer:
    LDA #$0a  ; if b button pressed, set running timer
    STA ram_running_timer
loc_load_horizontal_speed_limits:
    LDA tbl_maximum_left_speed,y  ; get maximum speed to the left
    STA ram_player_maximum_left_speed
    LDA ram_game_engine_subroutine  ; check for specific routine running
    CMP #$07  ; (player entrance)
    BNE bra_load_right_speed_limit  ; if not running, skip and use old value of Y
    LDY #$03  ; otherwise set Y to 3
bra_load_right_speed_limit:
    LDA tbl_maximum_right_speed,y  ; get maximum speed to the right
    STA ram_player_maximum_right_speed
    LDY $00  ; get other value in memory
    LDA tbl_horizontal_friction,y  ; get value using value in memory as offset
    STA ram_player_friction_low
    LDA #con_player_friction_high
    STA ram_player_friction_high  ; init something here
    LDA ram_player_facing_dir
    CMP ram_player_moving_dir  ; check facing direction against moving direction
    BEQ bra_return_from_player_physics  ; if the same, branch to leave
    ASL ram_player_friction_low  ; otherwise shift d7 of friction adder low into carry
    ROL ram_player_friction_high  ; then rotate carry onto d0 of friction adder high
bra_return_from_player_physics:
    RTS  ; and then leave

; -------------------------------------------------------------------------------------

tbl_player_animation_timer:
.if con_revision_profile = con_revision_profile_pal
    .byte $02, $03, $05
.else
    .byte $02, $04, $07
.endif

; Select the animation timer and detect running or skidding

; Outputs:
; ram_player_anim_timer_reload and running/skid motion fields may change

; Clobbers:
; A, Y
sub_update_player_animation_speed:
    LDY #$00  ; initialize offset in Y
    LDA ram_player_x_speed_absolute  ; check player's walking/running speed
    CMP #con_animation_speed_cutoff_a  ; against preset amount
    BCS bra_store_running_speed  ; if greater than a certain amount, branch ahead
    INY  ; otherwise increment Y
    CMP #con_animation_speed_cutoff_b  ; compare against lower amount
    BCS bra_check_player_skid  ; if greater than this but not greater than first, skip increment
    INY  ; otherwise increment Y again
bra_check_player_skid:
    LDA ram_saved_joypad_bits  ; get controller bits
    AND #%01111111  ; mask out A button
    BEQ loc_store_player_animation_timer  ; if no other buttons pressed, branch ahead of all this
    AND #$03  ; mask out all others except left and right
    CMP ram_player_moving_dir  ; check against moving direction
    BNE bra_process_player_skid  ; if left/right controller bits <> moving direction, branch
    LDA #$00  ; otherwise set zero value here
bra_store_running_speed:
    STA ram_running_speed  ; store zero or running speed here
    JMP loc_store_player_animation_timer
bra_process_player_skid:
    LDA ram_player_x_speed_absolute  ; check player's walking/running speed
    CMP #con_animation_speed_cutoff_c  ; against one last amount
    BCS loc_store_player_animation_timer  ; if greater than this amount, branch
    LDA ram_player_facing_dir
    STA ram_player_moving_dir  ; otherwise use facing direction to set moving direction
    LDA #$00
    STA ram_player_x_speed  ; nullify player's horizontal speed
    STA ram_player_x_speed_fraction  ; and dummy variable for player
loc_store_player_animation_timer:
    LDA tbl_player_animation_timer,y  ; get animation timer setting using Y as offset
    STA ram_player_anim_timer_reload
    RTS

; -------------------------------------------------------------------------------------

; Accelerate, decelerate, or reverse horizontal player velocity

; Inputs:
; A - left/right input bits
; ram_player_collision_bits - directions not blocked by background collision

; Outputs:
; Horizontal speed, speed fraction, and absolute speed are updated

; Clobbers:
; A
sub_apply_player_horizontal_friction:
    AND ram_player_collision_bits  ; perform AND between left/right controller bits and collision flag
    CMP #$00  ; then compare to zero (this instruction is redundant)
    BNE bra_apply_input_friction  ; if any bits set, branch to next part
    LDA ram_player_x_speed
    BEQ loc_store_absolute_x_speed  ; if player has no horizontal speed, branch ahead to last part
    BPL bra_accelerate_player_left  ; if player moving to the right, branch to slow
    BMI bra_accelerate_player_right  ; otherwise logic dictates player moving left, branch to slow
bra_apply_input_friction:
    LSR  ; put right controller bit into carry
    BCC bra_accelerate_player_left  ; if left button pressed, carry = 0, thus branch
bra_accelerate_player_right:
    LDA ram_player_x_speed_fraction  ; load value set here
    CLC
    ADC ram_player_friction_low  ; add to it another value set here
    STA ram_player_x_speed_fraction  ; store here
    LDA ram_player_x_speed
    ADC ram_player_friction_high  ; add value plus carry to horizontal speed
    STA ram_player_x_speed  ; set as new horizontal speed
    CMP ram_player_maximum_right_speed  ; compare against maximum value for right movement
    BMI bra_compute_absolute_x_speed  ; if horizontal speed greater negatively, branch
    LDA ram_player_maximum_right_speed  ; otherwise set preset value as horizontal speed
    STA ram_player_x_speed  ; thus slowing the player's left movement down
    JMP loc_store_absolute_x_speed  ; skip to the end
bra_accelerate_player_left:
    LDA ram_player_x_speed_fraction  ; load value set here
    SEC
    SBC ram_player_friction_low  ; subtract from it another value set here
    STA ram_player_x_speed_fraction  ; store here
    LDA ram_player_x_speed
    SBC ram_player_friction_high  ; subtract value plus borrow from horizontal speed
    STA ram_player_x_speed  ; set as new horizontal speed
    CMP ram_player_maximum_left_speed  ; compare against maximum value for left movement
    BPL bra_compute_absolute_x_speed  ; if horizontal speed greater positively, branch
    LDA ram_player_maximum_left_speed  ; otherwise set preset value as horizontal speed
    STA ram_player_x_speed  ; thus slowing the player's right movement down
bra_compute_absolute_x_speed:
    CMP #$00  ; if player not moving or moving to the right,
    BPL loc_store_absolute_x_speed  ; branch and leave horizontal speed value unmodified
    EOR #$ff
    CLC  ; otherwise get two's compliment to get absolute
    ADC #$01  ; unsigned walking/running speed
loc_store_absolute_x_speed:
    STA ram_player_x_speed_absolute  ; store walking/running speed here and leave
    RTS
