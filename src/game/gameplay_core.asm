; -------------------------------------------------------------------------------------

; indirect jump routine called when
; $0770 is set to 1
.if con_revision_profile = con_revision_profile_vs
    .repeat 9
        .byte $ff
    .endrepeat
.endif

handler_run_game_mode:
    LDA ram_oper_mode_task
    JSR sub_dispatch_inline_handler

.if con_revision_profile = con_revision_profile_vs
    .word handler_vs_initialize_game_core
.elseif con_revision_profile = con_revision_profile_ann
    .word handler_ann_disk_loader_data2
.endif
    .word handler_initialize_area
.if con_revision_profile = con_revision_profile_ann
    .word handler_load_ann_toad_graphics
.endif
    .word handler_run_screen_task
    .word handler_secondary_game_setup
    .word sub_game_core_routine

; -------------------------------------------------------------------------------------

.if con_revision_profile = con_revision_profile_vs
handler_vs_initialize_game_core:
    INC ram_oper_mode_task
    LDA #$01
    STA ram_disable_screen_flag
    LDA #$00
    STA ram_sprite0_hit_detect_flag
    RTS
.endif

sub_game_core_routine:
.if con_revision_profile = con_revision_profile_vs
    LDA ram_number_of_players
    BEQ bra_merge_vs_player_joypads
    LDX ram_current_player
    LDA ram_saved_joypad_bits,x
    JMP loc_store_vs_player_joypad
bra_merge_vs_player_joypads:
    LDA ram_saved_joypad1_bits
    ORA ram_saved_joypad2_bits
loc_store_vs_player_joypad:
    STA ram_saved_joypad1_bits
    AND #%00000001
    BEQ bra_filter_vs_vertical_joypad
    LDA ram_saved_joypad1_bits
    AND #%11111101
    STA ram_saved_joypad1_bits
bra_filter_vs_vertical_joypad:
    LDA ram_saved_joypad1_bits
    AND #%00000100
    BEQ bra_run_player_game_routine
    LDA ram_saved_joypad1_bits
    AND #%11110111
    STA ram_saved_joypad1_bits
bra_run_player_game_routine:
.elseif con_revision_profile <> con_revision_profile_ann
    LDX ram_current_player  ; get which player is on the screen
    LDA ram_saved_joypad_bits,x  ; use appropriate player's controller bits
    STA ram_saved_joypad_bits  ; as the master controller bits
.endif
    JSR sub_game_routines  ; execute one of many possible subs
    LDA ram_oper_mode_task  ; check major task of operating mode
.if con_revision_profile = con_revision_profile_ann
    CMP #con_ann_game_mode_process
.else
    CMP #$03  ; if we are supposed to be here,
.endif
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
    JSR sub_render_player_graphics  ; draw the player
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
.if con_revision_profile = con_revision_profile_ann
bra_wait_for_ann_sprite0_hit:
    LDA ram_fds_sprite0_irq_flag
    BNE bra_wait_for_ann_sprite0_hit
.endif
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
.if con_revision_profile = con_revision_profile_ann
    STA ram_fds_background_pattern_bits
.else
    STA $00  ; save as temp variable for PPU register 1 mirror
    LDA ram_mirror_ppu_ctrl_reg1  ; get PPU register 1 mirror
    AND #%11111110  ; save all bits except d0
    ORA $00  ; get saved bit here and save in PPU register 1
    STA ram_mirror_ppu_ctrl_reg1  ; mirror to be used to set name table later
.endif
    JSR sub_get_screen_position  ; figure out where the right side is
    LDA #$08
    STA ram_scroll_interval_timer  ; set scroll timer (residual, not used elsewhere)
    JMP loc_clamp_player_to_screen  ; skip this part
bra_clear_scroll_amount:
    LDA #$00
    STA ram_scroll_amount  ; initialize value here
loc_clamp_player_to_screen:
    LDX #$00  ; set X for player offset
    JSR sub_get_horizontal_offscreen_bits  ; get horizontal offscreen bits for player
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
