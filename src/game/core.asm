; -------------------------------------------------------------------------------------

; indirect jump routine called when
; $0770 is set to 1
handler_run_game_mode:
    LDA ram_oper_mode_task
    JSR sub_dispatch_inline_handler

    .word handler_initialize_area
    .word ScreenRoutines
    .word handler_secondary_game_setup
    .word sub_game_core_routine

; -------------------------------------------------------------------------------------

sub_game_core_routine:
    LDX ram_current_player  ; get which player is on the screen
    LDA ram_saved_joypad_bits,x  ; use appropriate player's controller bits
    STA ram_saved_joypad_bits  ; as the master controller bits
    JSR sub_game_routines  ; execute one of many possible subs
    LDA ram_oper_mode_task  ; check major task of operating mode
    CMP #$03  ; if we are supposed to be here,
    BCS bra_run_game_engine  ; branch to the game engine itself
    RTS

bra_run_game_engine:
    JSR sub_process_fireballs_and_bubbles  ; process fireballs and air bubbles
    LDX #$00
bra_process_enemy_slots:
    STX ram_object_offset  ; put incremented offset in X as enemy object offset
    JSR sub_enemies_and_loops_core  ; process enemy objects
    JSR sub_floatey_numbers_routine  ; process floatey numbers
    INX
    CPX #$06  ; do these two subroutines until the whole buffer is done
    BNE bra_process_enemy_slots
    JSR sub_get_player_offscreen_bits  ; get offscreen bits for player object
    JSR sub_relative_player_position  ; get relative coordinates for player object
    JSR sub_player_gfx_handler  ; draw the player
    JSR sub_update_block_object_metatile  ; replace block objects with metatiles if necessary
    LDX #$01
    STX ram_object_offset  ; set offset for second
    JSR sub_block_objects_core  ; process second block object
    DEX
    STX ram_object_offset  ; set offset for first
    JSR sub_block_objects_core  ; process first block object
    JSR sub_misc_objects_core  ; process misc objects (hammer, jumping coins)
    JSR sub_process_cannons  ; process bullet bill cannons
    JSR sub_process_whirlpool_pull  ; process whirlpools
    JSR sub_flagpole_routine  ; process the flagpole
    JSR sub_run_game_timer  ; count down the game timer
    JSR sub_color_rotation  ; cycle one of the background colors
    LDA ram_player_y_high_pos
    CMP #$02  ; if player is below the screen, don't bother with the music
    BPL bra_update_invincibility_palette
    LDA ram_star_invincible_timer  ; if star mario invincibility timer at zero,
    BEQ bra_reset_star_palette  ; skip this part
    CMP #$04
    BNE bra_update_invincibility_palette  ; if not yet at a certain point, continue
    LDA ram_interval_timer_control  ; if interval timer not yet expired,
    BNE bra_update_invincibility_palette  ; branch ahead, don't bother with the music
    JSR sub_get_area_music  ; to re-attain appropriate level music
bra_update_invincibility_palette:
    LDY ram_star_invincible_timer  ; get invincibility timer
    LDA ram_frame_counter  ; get frame counter
    CPY #$08  ; if timer still above certain point,
    BCS bra_select_palette_cycle_rate  ; branch to cycle player's palette quickly
    LSR  ; otherwise, divide by 8 to cycle every eighth frame
    LSR
bra_select_palette_cycle_rate:
    LSR  ; if branched here, divide by 2 to cycle every other frame
    JSR sub_cycle_player_palette  ; do sub to cycle the palette (note: shares fire flower code)
    JMP loc_save_button_history  ; then skip this sub to finish up the game engine
bra_reset_star_palette:
    JSR sub_reset_star_palette_cycle  ; do sub to clear player's palette bits in attributes
loc_save_button_history:
    LDA ram_a_b_buttons  ; save current A and B button
    STA ram_previous_a_b_buttons  ; into temp variable to be used on next frame
    LDA #$00
    STA ram_left_right_buttons  ; nullify left and right buttons temp variable
sub_update_scroll_variables:
    LDA ram_vram_buffer_addr_ctrl
    CMP #$06  ; if vram address controller set to 6 (one of two $0341s)
    BEQ bra_exit_game_engine  ; then branch to leave
    LDA ram_area_parser_task_num  ; otherwise check number of tasks
    BNE bra_run_area_parser
    LDA ram_scroll_thirty_two  ; get horizontal scroll in 0-31 or $00-$20 range
    CMP #$20  ; check to see if exceeded $21
    BMI bra_exit_game_engine  ; branch to leave if not
    LDA ram_scroll_thirty_two
    SBC #$20  ; otherwise subtract $20 to set appropriately
    STA ram_scroll_thirty_two  ; and store
    LDA #$00  ; reset vram buffer offset used in conjunction with
    STA ram_vram_buffer2_offset  ; level graphics buffer at $0341-$035f
bra_run_area_parser:
    JSR sub_area_parser_task_handler  ; update the name table with more level graphics
bra_exit_game_engine:
    RTS  ; and after all that, we're finally done!

; -------------------------------------------------------------------------------------

sub_scroll_handler:
    LDA ram_player_x_scroll  ; load value saved here
    CLC
    ADC ram_platform_x_scroll  ; add value used by left/right platforms
    STA ram_player_x_scroll  ; save as new value here to impose force on scroll
    LDA ram_scroll_lock  ; check scroll lock flag
    BNE bra_clear_scroll_amount  ; skip a bunch of code here if set
    LDA ram_player_pos_for_scroll
    CMP #$50  ; check player's horizontal screen position
    BCC bra_clear_scroll_amount  ; if less than 80 pixels to the right, branch
    LDA ram_side_collision_timer  ; if timer related to player's side collision
    BNE bra_clear_scroll_amount  ; not expired, branch
    LDY ram_player_x_scroll  ; get value and decrement by one
    DEY  ; if value originally set to zero or otherwise
    BMI bra_clear_scroll_amount  ; negative for left movement, branch
    INY
    CPY #$02  ; if value $01, branch and do not decrement
    BCC bra_check_player_near_screen_middle
    DEY  ; otherwise decrement by one
bra_check_player_near_screen_middle:
    LDA ram_player_pos_for_scroll
    CMP #$70  ; check player's horizontal screen position
    BCC sub_scroll_screen  ; if less than 112 pixels to the right, branch
    LDY ram_player_x_scroll  ; otherwise get original value undecremented

sub_scroll_screen:
    TYA
    STA ram_scroll_amount  ; save value here
    CLC
    ADC ram_scroll_thirty_two  ; add to value already set here
    STA ram_scroll_thirty_two  ; save as new value here
    TYA
    CLC
    ADC ram_screen_left_x_pos  ; add to left side coordinate
    STA ram_screen_left_x_pos  ; save as new left side coordinate
    STA ram_horizontal_scroll  ; save here also
    LDA ram_screen_left_page_loc
    ADC #$00  ; add carry to page location for left
    STA ram_screen_left_page_loc  ; side of the screen
    AND #$01  ; get LSB of page location
    STA $00  ; save as temp variable for PPU register 1 mirror
    LDA ram_mirror_ppu_ctrl_reg1  ; get PPU register 1 mirror
    AND #%11111110  ; save all bits except d0
    ORA $00  ; get saved bit here and save in PPU register 1
    STA ram_mirror_ppu_ctrl_reg1  ; mirror to be used to set name table later
    JSR sub_get_screen_position  ; figure out where the right side is
    LDA #$08
    STA ram_scroll_interval_timer  ; set scroll timer (residual, not used elsewhere)
    JMP loc_clamp_player_to_screen  ; skip this part
bra_clear_scroll_amount:
    LDA #$00
    STA ram_scroll_amount  ; initialize value here
loc_clamp_player_to_screen:
    LDX #$00  ; set X for player offset
    JSR sub_get_x_offscreen_bits  ; get horizontal offscreen bits for player
    STA $00  ; save them here
    LDY #$00  ; load default offset (left side)
    ASL  ; if d7 of offscreen bits are set,
    BCS bra_clamp_player_to_screen_edge  ; branch with default offset
    INY  ; otherwise use different offset (right side)
    LDA $00
    AND #%00100000  ; check offscreen bits for d5 set
    BEQ bra_clear_platform_scroll  ; if not set, branch ahead of this part
bra_clamp_player_to_screen_edge:
    LDA ram_screen_edge_x_pos,y  ; get left or right side coordinate based on offset
    SEC
    SBC tbl_screen_edge_x_offsets,y  ; subtract amount based on offset
    STA ram_player_x_position  ; store as player position to prevent movement further
    LDA ram_screen_edge_page_loc,y  ; get left or right page location based on offset
    SBC #$00  ; subtract borrow
    STA ram_player_page_loc  ; save as player's page location
    LDA ram_left_right_buttons  ; check saved controller bits
    CMP tbl_offscreen_joypad_direction_bits,y  ; against bits based on offset
    BEQ bra_clear_platform_scroll  ; if not equal, branch
    LDA #$00
    STA ram_player_x_speed  ; otherwise nullify horizontal speed of player
bra_clear_platform_scroll:
    LDA #$00  ; nullify platform force imposed on scroll
    STA ram_platform_x_scroll
    RTS

tbl_screen_edge_x_offsets:
    .byte $00, $10

tbl_offscreen_joypad_direction_bits:
    .byte $01, $02

; -------------------------------------------------------------------------------------

sub_get_screen_position:
    LDA ram_screen_left_x_pos  ; get coordinate of screen's left boundary
    CLC
    ADC #$ff  ; add 255 pixels
    STA ram_screen_right_x_pos  ; store as coordinate of screen's right boundary
    LDA ram_screen_left_page_loc  ; get page number where left boundary is
    ADC #$00  ; add carry from before
    STA ram_screen_right_page_loc  ; store as page number where right boundary is
    RTS

; -------------------------------------------------------------------------------------

sub_game_routines:
    LDA ram_game_engine_subroutine  ; run routine based on number (a few of these routines are
    JSR sub_dispatch_inline_handler  ; merely placeholders as conditions for other routines)

    .word handler_setup_entrance_and_game_timer
    .word handler_vine_automatic_climb
    .word handler_side_exit_pipe_entry
    .word handler_vertical_pipe_entry
    .word handler_flagpole_slide
    .word handler_player_end_level
    .word handler_player_lose_life
    .word handler_player_entrance
    .word handler_player_control
    .word handler_player_size_transition
    .word handler_player_injury_blink
    .word handler_player_death
    .word handler_player_fire_flower_transition

; -------------------------------------------------------------------------------------

handler_player_entrance:
    LDA ram_alt_entrance_control  ; check for mode of alternate entry
    CMP #$02
    BEQ bra_enter_from_pipe_or_vine  ; if found, branch to enter from pipe or with vine
    LDA #$00
    LDY ram_player_y_position  ; if vertical position above a certain
    CPY #$30  ; point, nullify controller bits and continue
    BCC sub_auto_control_player  ; with player movement code, do not return
    LDA ram_player_entrance_ctrl  ; check player entry bits from header
    CMP #$06
    BEQ bra_check_pipe_intro  ; if set to 6 or 7, execute pipe intro code
    CMP #$07  ; otherwise branch to normal entry
    BNE bra_finish_player_entrance
bra_check_pipe_intro:
    LDA ram_player_spr_attrib  ; check for sprite attributes
    BNE bra_run_pipe_intro  ; branch if found
    LDA #$01
    JMP sub_auto_control_player  ; force player to walk to the right
bra_run_pipe_intro:
    JSR sub_enter_side_pipe  ; execute sub to move player to the right
    DEC ram_change_area_timer  ; decrement timer for change of area
    BNE bra_exit_player_entrance  ; branch to exit if not yet expired
    INC ram_disable_intermediate  ; set flag to skip world and lives display
    JMP loc_advance_to_next_area  ; jump to increment to next area and set modes
bra_enter_from_pipe_or_vine:
    LDA ram_joypad_override  ; if controller override bits set here,
    BNE bra_enter_from_vine  ; branch to enter with vine
    LDA #$ff  ; otherwise, set value here then execute sub
    JSR sub_move_player_y_axis  ; to move player upwards (note $ff = -1)
    LDA ram_player_y_position  ; check to see if player is at a specific coordinate
    CMP #$91  ; if player risen to a certain point (this requires pipes
    BCC bra_finish_player_entrance  ; to be at specific height to look/function right) branch
    RTS  ; to the last part, otherwise leave
bra_enter_from_vine:
    LDA ram_vine_height
    CMP #$60  ; check vine height
    BNE bra_exit_player_entrance  ; if vine not yet reached maximum height, branch to leave
    LDA ram_player_y_position  ; get player's vertical coordinate
    CMP #$99  ; check player's vertical coordinate against preset value
    LDY #$00  ; load default values to be written to
    LDA #$01  ; this value moves player to the right off the vine
    BCC bra_auto_move_off_vine  ; if vertical coordinate < preset value, use defaults
    LDA #$03
    STA ram_player_state  ; otherwise set player state to climbing
    INY  ; increment value in Y
    LDA #$08  ; set block in block buffer to cover hole, then
    STA ram_block_buffer_1+$b4  ; use same value to force player to climb
bra_auto_move_off_vine:
    STY ram_disable_collision_det  ; set collision detection disable flag
    JSR sub_auto_control_player  ; use contents of A to move player up or right, execute sub
    LDA ram_player_x_position
    CMP #$48  ; check player's horizontal position
    BCC bra_exit_player_entrance  ; if not far enough to the right, branch to leave
bra_finish_player_entrance:
    LDA #$08  ; set routine to be executed by game engine next frame
    STA ram_game_engine_subroutine
    LDA #$01  ; set to face player to the right
    STA ram_player_facing_dir
    LSR  ; init A
    STA ram_alt_entrance_control  ; init mode of entry
    STA ram_disable_collision_det  ; init collision detection disable flag
    STA ram_joypad_override  ; nullify controller override bits
bra_exit_player_entrance:
    RTS  ; leave!

; -------------------------------------------------------------------------------------
; $07 - used to hold upper limit of high byte when player falls down hole

sub_auto_control_player:
    STA ram_saved_joypad_bits  ; override controller bits with contents of A if executing here

; Run player input, movement, scrolling, bounds, and background collision

; Inputs:
; ram_saved_joypad_bits - current or scripted controller state
; ram_game_engine_subroutine - active player/gameplay task

; Outputs:
; Player position, motion, state, bounds, and scroll state may be updated

; Clobbers:
; A, X, Y
handler_player_control:
    LDA ram_game_engine_subroutine  ; check task here
    CMP #$0b  ; if certain value is set, branch to skip controller bit loading
    BEQ bra_update_player_collision_box
    LDA ram_area_type  ; are we in a water type area?
    BNE bra_split_player_input_bits  ; if not, branch
    LDY ram_player_y_high_pos
    DEY  ; if not in vertical area between
    BNE bra_disable_player_input  ; status bar and bottom, branch
    LDA ram_player_y_position
    CMP #$d0  ; if nearing the bottom of the screen or
    BCC bra_split_player_input_bits  ; not in the vertical area between status bar or bottom,
bra_disable_player_input:
    LDA #$00  ; disable controller bits
    STA ram_saved_joypad_bits
bra_split_player_input_bits:
    LDA ram_saved_joypad_bits  ; otherwise store A and B buttons in $0a
    AND #%11000000
    STA ram_a_b_buttons
    LDA ram_saved_joypad_bits  ; store left and right buttons in $0c
    AND #%00000011
    STA ram_left_right_buttons
    LDA ram_saved_joypad_bits  ; store up and down buttons in $0b
    AND #%00001100
    STA ram_up_down_buttons
    AND #%00000100  ; check for pressing down
    BEQ bra_update_player_collision_box  ; if not, branch
    LDA ram_player_state  ; check player's state
    BNE bra_update_player_collision_box  ; if not on the ground, branch
    LDY ram_left_right_buttons  ; check left and right
    BEQ bra_update_player_collision_box  ; if neither pressed, branch
    LDA #$00
    STA ram_left_right_buttons  ; if pressing down while on the ground,
    STA ram_up_down_buttons  ; nullify directional bits
bra_update_player_collision_box:
    JSR sub_update_player_movement  ; run movement subroutines
    LDY #$01  ; is player small?
    LDA ram_player_size
    BNE bra_update_player_moving_direction
    LDY #$00  ; check for if crouching
    LDA ram_crouching_flag
    BEQ bra_update_player_moving_direction  ; if not, branch ahead
    LDY #$02  ; if big and crouching, load y with 2
bra_update_player_moving_direction:
    STY ram_player_bound_box_ctrl  ; set contents of Y as player's bounding box size control
    LDA #$01  ; set moving direction to right by default
    LDY ram_player_x_speed  ; check player's horizontal speed
    BEQ bra_run_player_frame_subsystems  ; if not moving at all horizontally, skip this part
    BPL bra_store_player_moving_direction  ; if moving to the right, use default moving direction
    ASL  ; otherwise change to move to the left
bra_store_player_moving_direction:
    STA ram_player_moving_dir  ; set moving direction
bra_run_player_frame_subsystems:
    JSR sub_scroll_handler  ; move the screen if necessary
    JSR sub_get_player_offscreen_bits  ; get player's offscreen bits
    JSR sub_relative_player_position  ; get coordinates relative to the screen
    LDX #$00  ; set offset for player object
    JSR sub_bounding_box_core  ; get player's bounding box coordinates
    JSR sub_handle_player_background_collision  ; do collision detection and process
    LDA ram_player_y_position
    CMP #$40  ; check to see if player is higher than 64th pixel
    BCC bra_check_player_below_screen  ; if so, branch ahead
    LDA ram_game_engine_subroutine
    CMP #$05  ; if running end-of-level routine, branch ahead
    BEQ bra_check_player_below_screen
    CMP #$07  ; if running player entrance routine, branch ahead
    BEQ bra_check_player_below_screen
    CMP #$04  ; if running routines $00-$03, branch ahead
    BCC bra_check_player_below_screen
    LDA ram_player_spr_attrib
    AND #%11011111  ; otherwise nullify player's
    STA ram_player_spr_attrib  ; background priority flag
bra_check_player_below_screen:
    LDA ram_player_y_high_pos  ; check player's vertical high byte
    CMP #$02  ; for below the screen
    BMI bra_exit_game_engine_control  ; branch to leave if not that far down
    LDX #$01
    STX ram_scroll_lock  ; set scroll lock
    LDY #$04
    STY $07  ; set value here
    LDX #$00  ; use X as flag, and clear for cloud level
    LDY ram_game_timer_expired_flag  ; check game timer expiration flag
    BNE bra_prepare_player_death  ; if set, branch
    LDY ram_cloud_type_override  ; check for cloud type override
    BNE bra_compare_player_depth_limit  ; skip to last part if found
bra_prepare_player_death:
    INX  ; set flag in X for player death
    LDY ram_game_engine_subroutine
    CPY #$0b  ; check for some other routine running
    BEQ bra_compare_player_depth_limit  ; if so, branch ahead
    LDY ram_death_music_loaded  ; check value here
    BNE bra_set_death_depth_limit  ; if already set, branch to next part
    INY
    STY ram_event_music_queue  ; otherwise play death music
    STY ram_death_music_loaded  ; and set value here
bra_set_death_depth_limit:
    LDY #$06
    STY $07  ; change value here
bra_compare_player_depth_limit:
    CMP $07  ; compare vertical high byte with value set here
    BMI bra_exit_game_engine_control  ; if less, branch to leave
    DEX  ; otherwise decrement flag in X
    BMI bra_exit_cloud_area  ; if flag was clear, branch to set modes and other values
    LDY ram_event_music_buffer  ; check to see if music is still playing
    BNE bra_exit_game_engine_control  ; branch to leave if so
    LDA #$06  ; otherwise set to run lose life routine
    STA ram_game_engine_subroutine  ; on next frame
bra_exit_game_engine_control:
    RTS  ; leave

bra_exit_cloud_area:
    LDA #$00
    STA ram_joypad_override  ; clear controller override bits if any are set
    JSR sub_setup_player_entrance  ; do sub to set secondary mode
    INC ram_alt_entrance_control  ; set mode of entry to 3
    RTS

; -------------------------------------------------------------------------------------

handler_vine_automatic_climb:
    LDA ram_player_y_high_pos  ; check to see whether player reached position
    BNE bra_force_vine_climb  ; above the status bar yet and if so, set modes
    LDA ram_player_y_position
    CMP #$e4
    BCC sub_setup_player_entrance
bra_force_vine_climb:
    LDA #%00001000  ; set controller bits override to up
    STA ram_joypad_override
    LDY #$03  ; set player state to climbing
    STY ram_player_state
    JMP sub_auto_control_player
sub_setup_player_entrance:
    LDA #$02  ; set starting position to override
    STA ram_alt_entrance_control
    JMP sub_change_area_mode  ; set modes

; -------------------------------------------------------------------------------------

handler_vertical_pipe_entry:
    LDA #$01  ; set 1 as movement amount
    JSR sub_move_player_y_axis  ; do sub to move player downwards
    JSR sub_scroll_handler  ; do sub to scroll screen with saved force if necessary
    LDY #$00  ; load default mode of entry
    LDA ram_warp_zone_control  ; check warp zone control variable/flag
    BNE loc_finish_pipe_area_change  ; if set, branch to use mode 0
    INY
    LDA ram_area_type  ; check for castle level type
    CMP #$03
    BNE loc_finish_pipe_area_change  ; if not castle type level, use mode 1
    INY
    JMP loc_finish_pipe_area_change  ; otherwise use mode 2

sub_move_player_y_axis:
    CLC
    ADC ram_player_y_position  ; add contents of A to player position
    STA ram_player_y_position
    RTS

; -------------------------------------------------------------------------------------

handler_side_exit_pipe_entry:
    JSR sub_enter_side_pipe  ; execute sub to move player to the right
    LDY #$02
loc_finish_pipe_area_change:
    DEC ram_change_area_timer  ; decrement timer for change of area
    BNE bra_exit_pipe_area_change
    STY ram_alt_entrance_control  ; when timer expires set mode of alternate entry
sub_change_area_mode:
    INC ram_disable_screen_flag  ; set flag to disable screen output
    LDA #$00
    STA ram_oper_mode_task  ; set secondary mode of operation
    STA ram_sprite0_hit_detect_flag  ; disable sprite 0 check
bra_exit_pipe_area_change:
    RTS  ; leave

sub_enter_side_pipe:
    LDA #$08  ; set player's horizontal speed
    STA ram_player_x_speed
    LDY #$01  ; set controller right button by default
    LDA ram_player_x_position  ; mask out higher nybble of player's
    AND #%00001111  ; horizontal position
    BNE bra_apply_side_pipe_control
    STA ram_player_x_speed  ; if lower nybble = 0, set as horizontal speed
    TAY  ; and nullify controller bit override here
bra_apply_side_pipe_control:
    TYA  ; use contents of Y to
    JSR sub_auto_control_player  ; execute player control routine with ctrl bits nulled
    RTS

; -------------------------------------------------------------------------------------

handler_player_size_transition:
    LDA ram_timer_control  ; check master timer control
    CMP #$f8  ; for specific moment in time
    BNE bra_check_size_change_completion  ; branch if before or after that point
    JMP loc_finish_player_size_transition  ; otherwise run code to get growing/shrinking going
bra_check_size_change_completion:
    CMP #$c4  ; check again for another specific moment
    BNE bra_exit_size_change  ; and branch to leave if before or after that point
    JSR sub_done_player_task  ; otherwise do sub to init timer control and set routine
bra_exit_size_change:
    RTS  ; and then leave

; -------------------------------------------------------------------------------------

handler_player_injury_blink:
    LDA ram_timer_control  ; check master timer control
    CMP #$f0  ; for specific moment in time
    BCS bra_exit_player_blink  ; branch if before that point
    CMP #$c8  ; check again for another specific point
    BEQ sub_done_player_task  ; branch if at that point, and not before or after
    JMP handler_player_control  ; otherwise run player control routine
bra_exit_player_blink:
    BNE bra_exit_player_transition  ; do unconditional branch to leave

loc_finish_player_size_transition:
    LDY ram_player_change_size_flag  ; if growing/shrinking flag already set
    BNE bra_exit_player_transition  ; then branch to leave
    STY ram_player_anim_ctrl  ; otherwise initialize player's animation frame control
    INC ram_player_change_size_flag  ; set growing/shrinking flag
    LDA ram_player_size
    EOR #$01  ; invert player's size
    STA ram_player_size
bra_exit_player_transition:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00 - used in sub_cycle_player_palette to store current palette to cycle

handler_player_death:
    LDA ram_timer_control  ; check master timer control
    CMP #$f0  ; for specific moment in time
    BCS bra_exit_player_death_handler  ; branch to leave if before that point
    JMP handler_player_control  ; otherwise run player control routine

sub_done_player_task:
    LDA #$00
    STA ram_timer_control  ; initialize master timer control to continue timers
    LDA #$08
    STA ram_game_engine_subroutine  ; set player control routine to run next frame
    RTS  ; leave

handler_player_fire_flower_transition:
    LDA ram_timer_control  ; check master timer control
    CMP #$c0  ; for specific moment in time
    BEQ bra_reset_fire_flower_palette_cycle  ; branch if at moment, not before or after
    LDA ram_frame_counter  ; get frame counter
    LSR
    LSR  ; divide by four to change every four frames

sub_cycle_player_palette:
    AND #$03  ; mask out all but d1-d0 (previously d3-d2)
    STA $00  ; store result here to use as palette bits
    LDA ram_player_spr_attrib  ; get player attributes
    AND #%11111100  ; save any other bits but palette bits
    ORA $00  ; add palette bits
    STA ram_player_spr_attrib  ; store as new player attributes
    RTS  ; and leave

bra_reset_fire_flower_palette_cycle:
    JSR sub_done_player_task  ; do sub to init timer control and run player control routine

sub_reset_star_palette_cycle:
    LDA ram_player_spr_attrib  ; get player attributes
    AND #%11111100  ; mask out palette bits to force palette 0
    STA ram_player_spr_attrib  ; store as new player attributes
    RTS  ; and leave

bra_exit_player_death_handler:
    RTS  ; leave from death routine

; -------------------------------------------------------------------------------------

handler_flagpole_slide:
    LDA ram_enemy_id+5  ; check special use enemy slot
    CMP #con_flagpole_flag_object  ; for flagpole flag object
    BNE bra_handle_missing_flagpole_object  ; if not found, branch to something residual
    LDA ram_flagpole_sound_queue  ; load flagpole sound
    STA ram_square1_sound_queue  ; into square 1's sfx queue
    LDA #$00
    STA ram_flagpole_sound_queue  ; init flagpole sound queue
    LDY ram_player_y_position
    CPY #$9e  ; check to see if player has slid down
    BCS bra_slide_player_to_castle_exit  ; far enough, and if so, branch with no controller bits set
    LDA #$04  ; otherwise force player to climb down (to slide)
bra_slide_player_to_castle_exit:
    JMP sub_auto_control_player  ; jump to player control routine
bra_handle_missing_flagpole_object:
    INC ram_game_engine_subroutine  ; increment to next routine (this may
    RTS  ; be residual code)

; -------------------------------------------------------------------------------------

tbl_hidden_1_up_coin_thresholds:
    .byte $15, $23, $16, $1b, $17, $18, $23, $63

handler_player_end_level:
    LDA #$01  ; force player to walk to the right
    JSR sub_auto_control_player
    LDA ram_player_y_position  ; check player's vertical position
    CMP #$ae
    BCC bra_check_player_end_level_stop  ; if player is not yet off the flagpole, skip this part
    LDA ram_scroll_lock  ; if scroll lock not set, branch ahead to next part
    BEQ bra_check_player_end_level_stop  ; because we only need to do this part once
    LDA #con_end_of_level_music
    STA ram_event_music_queue  ; load win level music in event music queue
    LDA #$00
    STA ram_scroll_lock  ; turn off scroll lock to skip this part later
bra_check_player_end_level_stop:
    LDA ram_player_collision_bits  ; get player collision bits
    LSR  ; check for d0 set
    BCS bra_check_end_level_task_complete  ; if d0 set, skip to next part
    LDA ram_star_flag_task_control  ; if star flag task control already set,
    BNE bra_finish_castle_end_level_walk  ; go ahead with the rest of the code
    INC ram_star_flag_task_control  ; otherwise set task control now (this gets ball rolling!)
bra_finish_castle_end_level_walk:
    LDA #%00100000  ; set player's background priority bit to
    STA ram_player_spr_attrib  ; give illusion of being inside the castle
bra_check_end_level_task_complete:
    LDA ram_star_flag_task_control
    CMP #$05  ; if star flag task control not yet set
    BNE bra_exit_next_area  ; beyond last valid task number, branch to leave
    INC ram_level_number  ; increment level number used for game logic
    LDA ram_level_number
    CMP #$03  ; check to see if we have yet reached level -4
    BNE loc_advance_to_next_area  ; and skip this last part here if not
    LDY ram_world_number  ; get world number as offset
    LDA ram_coin_tally_for1_ups  ; check third area coin tally for bonus 1-ups
    CMP tbl_hidden_1_up_coin_thresholds,y  ; against minimum value, if player has not collected
    BCC loc_advance_to_next_area  ; at least this number of coins, leave flag clear
    INC ram_hidden1_up_flag  ; otherwise set hidden 1-up box control flag
loc_advance_to_next_area:
    INC ram_area_number  ; increment area number used for address loader
    JSR sub_load_area_pointer  ; get new level pointer
    INC ram_fetch_new_game_timer_flag  ; set flag to load new game timer
    JSR sub_change_area_mode  ; do sub to set secondary mode, disable screen and sprite 0
    STA ram_halfway_page  ; reset halfway page to 0 (beginning)
    LDA #con_silence
    STA ram_event_music_queue  ; silence music and leave
bra_exit_next_area:
    RTS
