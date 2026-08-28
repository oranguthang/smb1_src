; Run the ANN title menu, cursor, and recorded demonstration input

con_ann_title_save_hard_mode_cutoff = 8
con_ann_title_demo_timer = $18
con_ann_title_select_timer = $10
con_ann_title_player_life_down = 6
con_ann_title_cursor_packet = $1c
con_ann_title_cursor_tile = $ce
con_ann_title_blank_tile = $24
con_ann_title_btn_a = %10000000
con_ann_title_btn_b = %01000000
con_ann_title_btn_select = %00100000
con_ann_title_btn_start = %00010000
con_ann_title_btn_left = %00000010
con_ann_title_btn_right = %00000001
con_ann_player_stat_bytes = 12

handler_ann_title_process:
    LDA ram_saved_joypad1_bits
    AND #con_ann_title_btn_start
    BEQ bra_process_ann_title_input
    LDA #$00
    STA ram_fds_disk_loader_task
    STA ram_ann_hard_mode
    LDA off_ann_save_data
    CMP #con_ann_title_save_hard_mode_cutoff
    BCC bra_start_ann_title_game
    LDA ram_saved_joypad1_bits
    AND #con_ann_title_btn_a
    BEQ bra_start_ann_title_game
    INC ram_ann_hard_mode
bra_start_ann_title_game:
    JMP handler_ann_title_exit

bra_process_ann_title_input:
    LDA ram_saved_joypad1_bits
    CMP #con_ann_title_btn_select
    BEQ bra_handle_ann_title_select
    LDX ram_demo_timer
    BNE bra_clear_ann_title_joypad
    STA ram_select_timer
    JSR sub_ann_run_title_demo
    BCS handler_ann_title_recycle
    BCC bra_run_ann_title_demo_frame
bra_handle_ann_title_select:
    LDA ram_demo_timer
    BEQ handler_ann_title_recycle
    LDA #con_ann_title_demo_timer
    STA ram_demo_timer
    LDA ram_frame_counter
    AND #%11111110
    STA ram_frame_counter
    LDA ram_select_timer
    BNE bra_clear_ann_title_joypad
    LDA #con_ann_title_select_timer
    STA ram_select_timer
    LDA ram_current_player
    EOR #$01
    STA ram_current_player
    JSR sub_ann_draw_title_cursor
bra_clear_ann_title_joypad:
    LDA #$00
    STA ram_saved_joypad1_bits
bra_run_ann_title_demo_frame:
    JSR sub_game_core_routine
    LDA ram_game_engine_subroutine
    CMP #con_ann_title_player_life_down
    BNE bra_continue_ann_title
handler_ann_title_recycle:
    LDA #$00
    STA ram_oper_mode
    STA ram_oper_mode_task
    STA ram_sprite0_hit_detect_flag
    INC ram_disable_screen_flag
    RTS

handler_ann_title_exit:
    LDA ram_demo_timer
    BEQ handler_ann_title_recycle
    INC ram_oper_mode_task
    JSR sub_ann_patch_title_player
    LDA #$00
    STA ram_ann_course_number
    LDA #$00
    STA ram_ann_player_goals
    LDA #$00
    STA ram_ann_course_sub
    LDX #con_ann_player_stat_bytes-1
    LDA #$00
    :
    STA ram_player_score_display,x
    DEX
    BPL :-
bra_continue_ann_title:
    RTS

off_ann_title_cursor_packet:
    .byte $22, $4b, $83
off_ann_title_cursor_first_tile:
    .byte con_ann_title_cursor_tile, con_ann_title_blank_tile
off_ann_title_cursor_second_tile:
    .byte con_ann_title_blank_tile, $00

tbl_ann_title_cursor_tiles:
    .byte con_ann_title_cursor_tile
    .byte con_ann_title_blank_tile
    .byte con_ann_title_cursor_tile

sub_ann_draw_title_cursor:
    LDA #con_ann_title_cursor_packet
    STA ram_vram_buffer_addr_ctrl
sub_ann_transfer_title_cursor:
    LDY ram_current_player
    LDA tbl_ann_title_cursor_tiles,y
    STA off_ann_title_cursor_first_tile
    LDA tbl_ann_title_cursor_tiles+1,y
    STA off_ann_title_cursor_second_tile
    RTS

tbl_ann_title_demo_buttons:
    .byte con_ann_title_btn_right, $00, con_ann_title_btn_a|con_ann_title_btn_right
    .byte con_ann_title_btn_right, con_ann_title_btn_a|con_ann_title_btn_right
    .byte con_ann_title_btn_b|con_ann_title_btn_left
    .byte con_ann_title_btn_a|con_ann_title_btn_b|con_ann_title_btn_left
    .byte con_ann_title_btn_right, con_ann_title_btn_a|con_ann_title_btn_right, $00
    .byte con_ann_title_btn_a|con_ann_title_btn_b|con_ann_title_btn_right
    .byte con_ann_title_btn_b|con_ann_title_btn_right
    .byte con_ann_title_btn_a|con_ann_title_btn_b|con_ann_title_btn_right
    .byte con_ann_title_btn_a|con_ann_title_btn_b|con_ann_title_btn_left
    .byte con_ann_title_btn_b|con_ann_title_btn_right
    .byte con_ann_title_btn_a|con_ann_title_btn_b|con_ann_title_btn_right
    .byte con_ann_title_btn_b|con_ann_title_btn_left
    .byte con_ann_title_btn_a|con_ann_title_btn_b|con_ann_title_btn_left, $00

tbl_ann_title_demo_timers:
    .byte $90, $70, $40, $18, $20, $10, $2c, $10, $1c, $70
    .byte $78, $08, $40, $20, $20, $40, $40, $20, $b0, $00

sub_ann_run_title_demo:
    LDX ram_demo_action
    LDA ram_demo_action_timer
    BNE bra_apply_ann_title_demo_input
    INX
    INC ram_demo_action
    SEC
    LDA tbl_ann_title_demo_timers-1,x
    STA ram_demo_action_timer
    BEQ bra_finish_ann_title_demo
bra_apply_ann_title_demo_input:
    LDA tbl_ann_title_demo_buttons-1,x
    STA ram_saved_joypad1_bits
    DEC ram_demo_action_timer
    CLC
bra_finish_ann_title_demo:
    RTS
