; -------------------------------------------------------------------------------------

; Decode enemy-stream commands and initialize eligible enemy slots

; Inputs:
; Enemy stream pointer/offset and current screen position

; Outputs:
; Enemy slots, loop state, and stream offset may be updated

; Clobbers:
; A, X, Y
.if con_revision_profile = con_revision_profile_pal
    .byte $ff  ; retained PAL alignment byte
.elseif con_revision_profile = con_revision_profile_vs
    .repeat 6
        .byte $ff
    .endrepeat
.endif
sub_enemies_and_loops_core:
    LDA ram_enemy_flag,x  ; check data here for MSB set
    PHA  ; save in stack
    ASL
    BCS bra_resolve_bowser_rear_slot  ; if MSB set in enemy flag, branch ahead of jumps
    PLA  ; get from stack
    BEQ bra_check_area_parser_task  ; if data zero, branch
    JMP loc_run_enemy_objects_core  ; otherwise, jump to run enemy subroutines
bra_check_area_parser_task:
    LDA ram_area_parser_task_num  ; check number of tasks to perform
    AND #$07
    CMP #$07  ; if at a specific task, jump and leave
    BEQ bra_exit_enemy_and_loop_core
    JMP loc_process_game_loop_command  ; otherwise, jump to process loop command/load enemies
bra_resolve_bowser_rear_slot:
    PLA  ; get data from stack
    AND #%00001111  ; mask out high nybble
    TAY
    LDA ram_enemy_flag,y  ; use as pointer and load same place with different offset
    BNE bra_exit_enemy_and_loop_core
    STA ram_enemy_flag,x  ; if second enemy flag not set, also clear first one
bra_exit_enemy_and_loop_core:
    RTS

; --------------------------------

; loop command data
tbl_loop_command_world_numbers:
.if con_revision_profile = con_revision_profile_vs
    .byte $04, $04, $06, $06, $06, $06, $06, $06, $07, $07, $07
.else
    .byte $03, $03, $06, $06, $06, $06, $06, $06, $07, $07, $07
.endif

tbl_loop_command_page_numbers:
    .byte $05, $09, $04, $05, $06, $08, $09, $0a, $06, $0b, $10

tbl_loop_command_player_y_positions:
.if con_revision_profile = con_revision_profile_vs
    .byte $40, $b0, $b0, $40, $40, $b0, $40, $80, $f0, $f0, $f0
.else
    .byte $40, $b0, $b0, $80, $40, $40, $80, $40, $f0, $f0, $f0
.endif

sub_exec_game_loopback:
    LDA ram_player_page_loc  ; send player back four pages
    SEC
    SBC #$04
    STA ram_player_page_loc
    LDA ram_current_page_loc  ; send current page back four pages
    SEC
    SBC #$04
    STA ram_current_page_loc
    LDA ram_screen_left_page_loc  ; subtract four from page location
    SEC  ; of screen's left border
    SBC #$04
    STA ram_screen_left_page_loc
    LDA ram_screen_right_page_loc  ; do the same for the page location
    SEC  ; of screen's right border
    SBC #$04
    STA ram_screen_right_page_loc
    LDA ram_area_object_page_loc  ; subtract four from page control
    SEC  ; for area objects
    SBC #$04
    STA ram_area_object_page_loc
    LDA #$00  ; initialize page select for both
    STA ram_enemy_object_page_sel  ; area and enemy objects
    STA ram_area_object_page_sel
    STA ram_enemy_data_offset  ; initialize enemy object data offset
    STA ram_enemy_object_page_loc  ; and enemy object page control
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
    LDA ram_vs_io_buffer,y  ; read the CHR-resident loop offset copied during course loading
.else
    LDA tbl_area_object_loopback_offsets,y  ; adjust area object offset based on
.endif
    STA ram_area_data_offset  ; which loop command we encountered
    RTS

loc_process_game_loop_command:
    LDA ram_loop_command  ; check if loop command was found
    BEQ bra_spawn_queued_frenzy_enemy
    LDA ram_current_column_pos  ; check to see if we're still on the first page
    BNE bra_spawn_queued_frenzy_enemy  ; if not, do not loop yet
    LDY #$0b  ; start at the end of each set of loop data
bra_find_matching_loop_command:
    DEY
    BMI bra_spawn_queued_frenzy_enemy  ; if all data is checked and not match, do not loop
    LDA ram_world_number  ; check to see if one of the world numbers
    CMP tbl_loop_command_world_numbers,y  ; matches our current world number
    BNE bra_find_matching_loop_command
    LDA ram_current_page_loc  ; check to see if one of the page numbers
    CMP tbl_loop_command_page_numbers,y  ; matches the page we're currently on
    BNE bra_find_matching_loop_command
    LDA ram_player_y_position  ; check to see if the player is at the correct position
    CMP tbl_loop_command_player_y_positions,y  ; if not, branch to check for world 7
    BNE bra_handle_incorrect_loop_path
    LDA ram_player_state  ; check to see if the player is
    CMP #$00  ; on solid ground (i.e. not jumping or falling)
    BNE bra_handle_incorrect_loop_path  ; if not, player fails to pass loop, and loopback
    LDA ram_world_number  ; are we in world 7? (check performed on correct
    CMP #con_world7  ; vertical position and on solid ground)
    BNE bra_reset_multi_loop_state  ; if not, initialize flags used there, otherwise
    INC ram_multi_loop_correct_cntr  ; increment counter for correct progression
bra_advance_world_7_loop_sequence:
    INC ram_multi_loop_pass_cntr  ; increment master multi-part counter
    LDA ram_multi_loop_pass_cntr  ; have we done all three parts?
    CMP #$03
    BNE bra_clear_loop_command  ; if not, skip this part
    LDA ram_multi_loop_correct_cntr  ; if so, have we done them all correctly?
    CMP #$03
    BEQ bra_reset_multi_loop_state  ; if so, branch past unnecessary check here
    BNE bra_execute_game_loopback  ; unconditional branch if previous branch fails
bra_handle_incorrect_loop_path:
    LDA ram_world_number  ; are we in world 7? (check performed on
    CMP #con_world7  ; incorrect vertical position or not on solid ground)
    BEQ bra_advance_world_7_loop_sequence
bra_execute_game_loopback:
    JSR sub_exec_game_loopback  ; if player is not in right place, loop back
    JSR sub_kill_all_enemies
bra_reset_multi_loop_state:
    LDA #$00  ; initialize counters used for multi-part loop commands
    STA ram_multi_loop_pass_cntr
    STA ram_multi_loop_correct_cntr
bra_clear_loop_command:
    LDA #$00  ; initialize loop command flag
    STA ram_loop_command

; --------------------------------

bra_spawn_queued_frenzy_enemy:
    LDA ram_enemy_frenzy_queue  ; check for enemy object in frenzy queue
    BEQ bra_process_enemy_stream  ; if not, skip this part
    STA ram_enemy_id,x  ; store as enemy object identifier here
    LDA #$01
    STA ram_enemy_flag,x  ; activate enemy object flag
    LDA #$00
    STA ram_enemy_state,x  ; initialize state and frenzy queue
    STA ram_enemy_frenzy_queue
    JMP sub_initialize_enemy_object  ; and then jump to deal with this enemy

; --------------------------------
; $06 - used to hold page location of extended right boundary
; $07 - used to hold high nybble of position of extended right boundary

bra_process_enemy_stream:
    request_vs_low_chr_bank
    LDY ram_enemy_data_offset  ; get offset of enemy object data
    LDA (ram_enemy_data),y  ; load first byte
    CMP #$ff  ; check for EOD terminator
    BNE bra_enforce_enemy_slot_limit
    JMP loc_spawn_frenzy_enemy_or_vine  ; if found, jump to check frenzy buffer, otherwise

bra_enforce_enemy_slot_limit:
    AND #%00001111  ; check for special row $0e
    CMP #$0e
    BEQ bra_compute_enemy_spawn_boundary  ; if found, branch, otherwise
    CPX #$05  ; check for end of buffer
    BCC bra_compute_enemy_spawn_boundary  ; if not at end of buffer, branch
    INY
    request_vs_low_chr_bank
    LDA (ram_enemy_data),y  ; check for specific value here
    AND #%00111111  ; !(WHY?) CODE-002 - residual object-range check
    CMP #$2e
    BEQ bra_compute_enemy_spawn_boundary  ; but it has the effect of keeping enemies out of
    RTS  ; the sixth slot

bra_compute_enemy_spawn_boundary:
    LDA ram_screen_right_x_pos  ; add 48 to pixel coordinate of right boundary
    CLC
    ADC #$30
    AND #%11110000  ; store high nybble
    STA $07
    LDA ram_screen_right_page_loc  ; add carry to page location of right boundary
    ADC #$00
    STA $06  ; store page location + carry
    LDY ram_enemy_data_offset
    INY
    request_vs_low_chr_bank
    LDA (ram_enemy_data),y  ; if MSB of enemy object is clear, branch to check for row $0f
    ASL
    BCC bra_parse_enemy_page_command
    LDA ram_enemy_object_page_sel  ; if page select already set, do not set again
    BNE bra_parse_enemy_page_command
    INC ram_enemy_object_page_sel  ; otherwise, if MSB is set, set page select
    INC ram_enemy_object_page_loc  ; and increment page control

bra_parse_enemy_page_command:
    DEY
    request_vs_low_chr_bank
    LDA (ram_enemy_data),y  ; reread first byte
    AND #$0f
    CMP #$0f  ; check for special row $0f
    BNE bra_decode_enemy_position  ; if not found, branch to position enemy object
    LDA ram_enemy_object_page_sel  ; if page select set,
    BNE bra_decode_enemy_position  ; branch without reading second byte
    INY
    request_vs_low_chr_bank
    LDA (ram_enemy_data),y  ; otherwise, get second byte, mask out 2 MSB
    AND #%00111111
    STA ram_enemy_object_page_loc  ; store as page control for enemy object data
    INC ram_enemy_data_offset  ; increment enemy object data offset 2 bytes
    INC ram_enemy_data_offset
    INC ram_enemy_object_page_sel  ; set page select for enemy object data and
    JMP loc_process_game_loop_command  ; jump back to process loop commands again

bra_decode_enemy_position:
    request_vs_low_chr_bank
    LDA ram_enemy_object_page_loc  ; store page control as page location
    STA ram_enemy_page_loc,x  ; for enemy object
    request_vs_low_chr_bank
    LDA (ram_enemy_data),y  ; get first byte of enemy object
    AND #%11110000
    STA ram_enemy_x_position,x  ; store column position
    CMP ram_screen_right_x_pos  ; check column position against right boundary
    LDA ram_enemy_page_loc,x  ; without subtracting, then subtract borrow
    SBC ram_screen_right_page_loc  ; from page location
    BCS bra_check_enemy_spawn_boundary  ; if enemy object beyond or at boundary, branch
    request_vs_low_chr_bank
    LDA (ram_enemy_data),y
    AND #%00001111  ; check for special row $0e
    CMP #$0e  ; if found, jump elsewhere
    BEQ bra_parse_area_transition_command
    JMP loc_advance_enemy_stream  ; if not found, unconditional jump

bra_check_enemy_spawn_boundary:
    LDA $07  ; check right boundary + 48 against
    CMP ram_enemy_x_position,x  ; column position without subtracting,
    LDA $06  ; then subtract borrow from page control temp
    SBC ram_enemy_page_loc,x  ; plus carry
    BCC loc_spawn_frenzy_enemy_or_vine  ; if enemy object beyond extended boundary, branch
    LDA #$01  ; store value in vertical high byte
    STA ram_enemy_y_high_pos,x
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_enemy_data),y  ; get first byte again
    ASL  ; multiply by four to get the vertical
    ASL  ; coordinate
    ASL
    ASL
    STA ram_enemy_y_position,x
    CMP #$e0  ; do one last check for special row $0e
    BEQ bra_parse_area_transition_command  ; (necessary if branched to $c1cb)
    INY
    request_vs_low_chr_bank
    LDA (ram_enemy_data),y  ; get second byte of object
.if con_revision_profile <> con_revision_profile_vs
    AND #%01000000  ; check to see if hard mode bit is set
    BEQ bra_decode_enemy_or_group_id  ; if not, branch to check for group enemy objects
    LDA ram_secondary_hard_mode  ; if set, check to see if secondary hard mode flag
    BEQ loc_advance_enemy_stream_two_bytes  ; is on, and if not, branch to skip this object completely

bra_decode_enemy_or_group_id:
    LDA (ram_enemy_data),y  ; get second byte and mask out 2 MSB
.endif
    AND #%00111111
    CMP #$37  ; check for value below $37
    BCC bra_apply_hard_mode_enemy_substitution
    CMP #$3f  ; if $37 or greater, check for value
    BCC bra_spawn_enemy_group  ; below $3f, branch if below $3f

bra_apply_hard_mode_enemy_substitution:
.if con_revision_profile <> con_revision_profile_vs
    CMP #con_goomba  ; if below $37, check for goomba
    BNE bra_store_and_initialize_enemy_id  ; value ($3f or more always fails)
    LDY ram_primary_hard_mode  ; check if primary hard mode flag is set
    BEQ bra_store_and_initialize_enemy_id  ; and if so, change goomba to buzzy beetle
    LDA #con_buzzy_beetle
.endif
bra_store_and_initialize_enemy_id:
    STA ram_enemy_id,x  ; store enemy object number into buffer
    LDA #$01
    STA ram_enemy_flag,x  ; set flag for enemy in buffer
    JSR sub_initialize_enemy_object
    LDA ram_enemy_flag,x  ; check to see if flag is set
    BNE loc_advance_enemy_stream_two_bytes  ; if not, leave, otherwise branch
    RTS

loc_spawn_frenzy_enemy_or_vine:
    LDA ram_enemy_frenzy_buffer  ; if enemy object stored in frenzy buffer
    BNE bra_store_queued_frenzy_or_vine_id  ; then branch ahead to store in enemy object buffer
    LDA ram_vine_flag_offset  ; otherwise check vine flag offset
    CMP #$01
    BNE bra_exit_enemy_stream_parser  ; if other value <> 1, leave
    LDA #con_vine_object  ; otherwise put vine in enemy identifier
bra_store_queued_frenzy_or_vine_id:
    STA ram_enemy_id,x  ; store contents of frenzy buffer into enemy identifier value

sub_initialize_enemy_object:
    LDA #$00  ; initialize enemy state
    STA ram_enemy_state,x
    JSR sub_checkpoint_enemy_id  ; jump ahead to run jump engine and subroutines
bra_exit_enemy_stream_parser:
    RTS  ; then leave

bra_spawn_enemy_group:
    JMP loc_spawn_enemy_group  ; handle enemy group objects

bra_parse_area_transition_command:
    request_vs_low_chr_bank
    INY  ; increment Y to load third byte of object
    INY
    LDA (ram_enemy_data),y
    LSR  ; move 3 MSB to the bottom, effectively
    LSR  ; making %xxx00000 into %00000xxx
    LSR
    LSR
    LSR
    CMP ram_world_number  ; is it the same world number as we're on?
    BNE bra_skip_area_transition_command  ; if not, do not use (this allows multiple uses
    DEY  ; of the same area, like the underground bonus areas)
    request_vs_low_chr_bank
    LDA (ram_enemy_data),y  ; otherwise, get second byte and use as offset
    STA ram_area_pointer  ; to addresses for level and enemy object data
    INY
    LDA (ram_enemy_data),y  ; get third byte again, and this time mask out
    AND #%00011111  ; the 3 MSB from before, save as page number to be
    STA ram_entrance_page  ; used upon entry to area, if area is entered
bra_skip_area_transition_command:
    JMP loc_advance_enemy_stream_three_bytes

loc_advance_enemy_stream:
    request_vs_low_chr_bank
    LDY ram_enemy_data_offset  ; load current offset for enemy object data
    LDA (ram_enemy_data),y  ; get first byte
    AND #%00001111  ; check for special row $0e
    CMP #$0e
    BNE loc_advance_enemy_stream_two_bytes
loc_advance_enemy_stream_three_bytes:
    INC ram_enemy_data_offset  ; if row = $0e, increment three bytes
loc_advance_enemy_stream_two_bytes:
    INC ram_enemy_data_offset  ; otherwise increment two bytes
    INC ram_enemy_data_offset
    LDA #$00  ; init page select for enemy objects
    STA ram_enemy_object_page_sel
    LDX ram_object_offset  ; reload current offset in enemy buffers
    RTS  ; and leave

sub_checkpoint_enemy_id:
    LDA ram_enemy_id,x
    CMP #$15  ; check enemy object identifier for $15 or greater
    BCS bra_dispatch_enemy_initializer  ; and branch straight to the jump engine if found
    TAY  ; save identifier in Y register for now
    LDA ram_enemy_y_position,x
    ADC #$08  ; add eight pixels to what will eventually be the
    STA ram_enemy_y_position,x  ; enemy object's vertical coordinate ($00-$14 only)
    LDA #$01
    STA ram_enemy_offscr_bits_masked,x  ; set offscreen masked bit
    TYA  ; get identifier back and use as offset for jump engine

bra_dispatch_enemy_initializer:
    JSR sub_dispatch_inline_handler

; jump engine table for newly loaded enemy objects

    .word sub_initialize_normal_enemy  ; for objects $00-$0f
    .word sub_initialize_normal_enemy
    .word sub_initialize_normal_enemy
    .word handler_initialize_red_koopa
    .word handler_no_enemy_initialization
    .word handler_initialize_hammer_bro
    .word handler_initialize_goomba
    .word handler_initialize_blooper
    .word handler_initialize_bullet_bill
    .word handler_no_enemy_initialization
    .word handler_initialize_cheep_cheep
    .word handler_initialize_cheep_cheep
    .word sub_initialize_podoboo
    .word sub_initialize_piranha_plant
    .word handler_initialize_jumping_green_paratroopa
    .word handler_initialize_red_paratroopa

    .word sub_initialize_horizontal_flying_or_swimming_enemy  ; for objects $10-$1f
    .word handler_initialize_lakitu
    .word handler_initialize_enemy_frenzy
    .word handler_no_enemy_initialization
    .word handler_initialize_enemy_frenzy
    .word handler_initialize_enemy_frenzy
    .word handler_initialize_enemy_frenzy
    .word handler_initialize_enemy_frenzy
    .word handler_end_enemy_frenzy
    .word handler_no_enemy_initialization
    .word handler_no_enemy_initialization
    .word handler_initialize_short_firebar
    .word handler_initialize_short_firebar
    .word handler_initialize_short_firebar
    .word handler_initialize_short_firebar
    .word handler_initialize_long_firebar

    .word handler_no_enemy_initialization  ; for objects $20-$2f
    .word handler_no_enemy_initialization
    .word handler_no_enemy_initialization
    .word handler_no_enemy_initialization
    .word handler_initialize_balance_platform
    .word handler_initialize_vertical_platform
    .word handler_initialize_large_lift_up
    .word handler_initialize_large_lift_down
    .word handler_initialize_horizontal_platform
    .word handler_initialize_drop_platform
    .word handler_initialize_horizontal_platform
    .word sub_initialize_platform_lift_up
    .word sub_initialize_platform_lift_down
    .word handler_initialize_bowser
    .word handler_initialize_power_up_object  ; possibly dummy value
    .word sub_setup_vine

    .word handler_no_enemy_initialization  ; for objects $30-$36
    .word handler_no_enemy_initialization
    .word handler_no_enemy_initialization
    .word handler_no_enemy_initialization
    .word handler_no_enemy_initialization
    .word handler_initialize_retainer
    .word handler_end_enemy_initialization

; -------------------------------------------------------------------------------------

handler_no_enemy_initialization:
    RTS  ; this executed when enemy object has no init code

; --------------------------------

handler_initialize_goomba:
    JSR sub_initialize_normal_enemy  ; set appropriate horizontal speed
    JMP sub_initialize_small_enemy_bounding_box  ; set $09 as bounding box control, set other values

; --------------------------------

sub_initialize_podoboo:
    LDA #$02  ; set enemy position to below
    STA ram_enemy_y_high_pos,x  ; the bottom of the screen
    STA ram_enemy_y_position,x
    LSR
    STA ram_enemy_interval_timer,x  ; set timer for enemy
    LSR
    STA ram_enemy_state,x  ; initialize enemy state, then jump to use
    JMP sub_initialize_small_enemy_bounding_box  ; $09 as bounding box size and set other things

; --------------------------------

handler_initialize_retainer:
    LDA #$b8  ; set fixed vertical position for
    STA ram_enemy_y_position,x  ; princess/mushroom retainer object
    RTS

; --------------------------------

tbl_normal_enemy_x_speeds:
    .byte <-con_normal_enemy_x_speed, <-con_hard_enemy_x_speed

sub_initialize_normal_enemy:
    LDY #$01  ; load offset of 1 by default
    LDA ram_primary_hard_mode  ; check for primary hard mode flag set
    BNE bra_select_normal_enemy_x_speed
    DEY  ; if not set, decrement offset
bra_select_normal_enemy_x_speed:
    LDA tbl_normal_enemy_x_speeds,y  ; get appropriate horizontal speed
loc_store_enemy_x_speed:
    STA ram_enemy_x_speed,x  ; store as speed for enemy object
    JMP loc_set_tall_enemy_bounding_box  ; branch to set bounding box control and other data

; --------------------------------

handler_initialize_red_koopa:
    JSR sub_initialize_normal_enemy  ; load appropriate horizontal speed
    LDA #$01  ; set enemy state for red koopa troopa $03
    STA ram_enemy_state,x
    RTS

; --------------------------------

tbl_hammer_bro_walking_delays:
.if con_revision_profile <> con_revision_profile_vs
    .byte $80, $50
.endif

handler_initialize_hammer_bro:
    LDA #$00  ; init horizontal speed and timer used by hammer bro
    STA ram_hammer_throwing_timer,x  ; apparently to time hammer throwing
    STA ram_enemy_x_speed,x
.if con_revision_profile = con_revision_profile_vs
    LDA #$ff  ; use the fixed arcade walking delay
.else
    LDY ram_secondary_hard_mode  ; get secondary hard mode flag
    LDA tbl_hammer_bro_walking_delays,y
.endif
    STA ram_enemy_interval_timer,x  ; set value as delay for hammer bro to walk left
    LDA #$0b  ; set specific value for bounding box size control
    JMP loc_set_enemy_bounding_box

; --------------------------------

sub_initialize_horizontal_flying_or_swimming_enemy:
    LDA #$00  ; initialize horizontal speed
    JMP loc_store_enemy_x_speed

; --------------------------------

handler_initialize_blooper:
    LDA #$00  ; initialize horizontal speed
    STA ram_blooper_move_speed,x
sub_initialize_small_enemy_bounding_box:
    LDA #$09  ; set specific bounding box size control
    BNE loc_set_enemy_bounding_box  ; unconditional branch

; --------------------------------

handler_initialize_red_paratroopa:
    LDY #$30  ; load central position adder for 48 pixels down
    LDA ram_enemy_y_position,x  ; set vertical coordinate into location to
    STA ram_red_p_troopa_orig_x_pos,x  ; be used as original vertical coordinate
    BPL bra_compute_red_paratroopa_center_y  ; if vertical coordinate < $80
    LDY #$e0  ; if => $80, load position adder for 32 pixels up
bra_compute_red_paratroopa_center_y:
    TYA  ; send central position adder to A
    ADC ram_enemy_y_position,x  ; add to current vertical coordinate
    STA ram_red_p_troopa_center_y_pos,x  ; store as central vertical coordinate
loc_set_tall_enemy_bounding_box:
    LDA #$03  ; set specific bounding box size control
loc_set_enemy_bounding_box:
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box control here
    LDA #$02  ; set moving direction for left
    STA ram_enemy_moving_dir,x
sub_clear_enemy_vertical_motion:
    LDA #$00  ; initialize vertical speed
    STA ram_enemy_y_speed,x  ; and movement force
    STA ram_enemy_y_move_force,x
    RTS

; --------------------------------

handler_initialize_bullet_bill:
    LDA #$02  ; set moving direction for left
    STA ram_enemy_moving_dir,x
    LDA #$09  ; set bounding box control for $09
    STA ram_enemy_bound_box_ctrl,x
    RTS

; --------------------------------

handler_initialize_cheep_cheep:
    JSR sub_initialize_small_enemy_bounding_box  ; set vertical bounding box, speed, init others
    LDA ram_pseudo_random_bit_reg,x  ; check one portion of LSFR
    AND #%00010000  ; get d4 from it
    STA ram_cheep_cheep_move_m_flag,x  ; save as movement flag of some sort
    LDA ram_enemy_y_position,x
    STA ram_cheep_cheep_orig_y_pos,x  ; save original vertical coordinate here
    RTS

; --------------------------------

handler_initialize_lakitu:
    LDA ram_enemy_frenzy_buffer  ; check to see if an enemy is already in
    BNE bra_erase_duplicate_lakitu  ; the frenzy buffer, and branch to kill lakitu if so

sub_setup_lakitu:
    LDA #$00  ; erase counter for lakitu's reappearance
    STA ram_lakitu_reappear_timer
    JSR sub_initialize_horizontal_flying_or_swimming_enemy  ; set $03 as bounding box, set other attributes
    JMP loc_set_tall_special_enemy_bounding_box  ; set $03 as bounding box again (not necessary) and leave

bra_erase_duplicate_lakitu:
    JMP sub_erase_enemy_object

; --------------------------------
; $01-$03 - used to hold pseudorandom difference adjusters

tbl_spiny_throw_speed_adjustments:
    .byte $26, $2c, $32, $38
    .byte $20, $22, $24, $26
    .byte $13, $14, $15, $16

handler_spawn_lakitu_or_spiny:
    LDA ram_frenzy_enemy_timer  ; if timer here not expired, leave
    BNE bra_exit_lakitu_spiny_handler
    CPX #$05  ; if we are on the special use slot, leave
    BCS bra_exit_lakitu_spiny_handler
    LDA #$80  ; set timer
    STA ram_frenzy_enemy_timer
    LDY #$04  ; start with the last enemy slot
bra_find_active_lakitu:
    LDA ram_enemy_id,y  ; check all enemy slots to see
    CMP #con_lakitu  ; if lakitu is on one of them
    BEQ bra_spawn_spiny_egg  ; if so, branch out of this loop
    DEY  ; otherwise check another slot
    BPL bra_find_active_lakitu  ; loop until all slots are checked
    INC ram_lakitu_reappear_timer  ; increment reappearance timer
    LDA ram_lakitu_reappear_timer
    CMP #$07  ; check to see if we're up to a certain value yet
    BCC bra_exit_lakitu_spiny_handler  ; if not, leave
    LDX #$04  ; start with the last enemy slot again
bra_find_empty_enemy_slot_for_lakitu:
    LDA ram_enemy_flag,x  ; check enemy buffer flag for non-active enemy slot
    BEQ bra_spawn_lakitu  ; branch out of loop if found
    DEX  ; otherwise check next slot
    BPL bra_find_empty_enemy_slot_for_lakitu  ; branch until all slots are checked
    BMI bra_restore_current_enemy_slot  ; if no empty slots were found, branch to leave
bra_spawn_lakitu:
    LDA #$00  ; initialize enemy state
    STA ram_enemy_state,x
    LDA #con_lakitu  ; create lakitu enemy object
    STA ram_enemy_id,x
    JSR sub_setup_lakitu  ; do a sub to set up lakitu
    LDA #$20
    JSR sub_put_at_right_extent  ; finish setting up lakitu
bra_restore_current_enemy_slot:
    LDX ram_object_offset  ; get enemy object buffer offset again and leave
bra_exit_lakitu_spiny_handler:
    RTS

; --------------------------------

bra_spawn_spiny_egg:
    LDA ram_player_y_position  ; if player above a certain point, branch to leave
    CMP #$2c
    BCC bra_exit_lakitu_spiny_handler
    LDA ram_enemy_state,y  ; if lakitu is not in normal state, branch to leave
    BNE bra_exit_lakitu_spiny_handler
    LDA ram_enemy_page_loc,y  ; store horizontal coordinates (high and low) of lakitu
    STA ram_enemy_page_loc,x  ; into the coordinates of the spiny we're going to create
    LDA ram_enemy_x_position,y
    STA ram_enemy_x_position,x
    LDA #$01  ; put spiny within vertical screen unit
    STA ram_enemy_y_high_pos,x
    LDA ram_enemy_y_position,y  ; put spiny eight pixels above where lakitu is
    SEC
    SBC #$08
    STA ram_enemy_y_position,x
    LDA ram_pseudo_random_bit_reg,x  ; get 2 LSB of LSFR and save to Y
    AND #%00000011
    TAY
    LDX #$02
bra_build_spiny_throw_adjustments:
    LDA tbl_spiny_throw_speed_adjustments,y  ; get three values and save them
    STA $01,x  ; to $01-$03
    INY
    INY  ; increment Y four bytes for each value
    INY
    INY
    DEX  ; decrement X for each one
    BPL bra_build_spiny_throw_adjustments  ; loop until all three are written
    LDX ram_object_offset  ; get enemy object buffer offset
    JSR sub_player_lakitu_diff  ; move enemy, change direction, get value - difference
    LDY ram_player_x_speed  ; check player's horizontal speed
    CPY #con_spiny_player_speed_cutoff
    BCS bra_initialize_spiny_throw_speed  ; if moving faster than a certain amount, branch elsewhere
    TAY  ; otherwise save value in A to Y for now
    LDA ram_pseudo_random_bit_reg+1,x
    AND #%00000011  ; get one of the LSFR parts and save the 2 LSB
    BEQ bra_use_positive_spiny_throw_speed  ; branch if neither bits are set
    TYA
    EOR #%11111111  ; otherwise get two's compliment of Y
    TAY
    INY
bra_use_positive_spiny_throw_speed:
    TYA  ; put value from A in Y back to A (they will be lost anyway)
bra_initialize_spiny_throw_speed:
    JSR sub_initialize_small_enemy_bounding_box  ; set bounding box control, init attributes, lose contents of A
    LDY #$02
    STA ram_enemy_x_speed,x  ; set horizontal speed to zero because previous contents
    CMP #$00  ; of A were lost...branch here will never be taken for
    BMI bra_store_spiny_throw_direction  ; the same reason
    DEY
bra_store_spiny_throw_direction:
    STY ram_enemy_moving_dir,x  ; set moving direction to the right
    LDA #$fd
    STA ram_enemy_y_speed,x  ; set vertical speed to move upwards
    LDA #$01
    STA ram_enemy_flag,x  ; enable enemy object by setting flag
    LDA #$05
    STA ram_enemy_state,x  ; put spiny in egg state and leave
bra_exit_enemy_initialization:
    RTS
