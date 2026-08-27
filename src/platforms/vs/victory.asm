; Vs. Super Mario Bros. castle-victory extensions

sub_vs_tally_timer_score = $d260
sub_vs_render_parade_actor = $e7da
sub_vs_award_castle_end_stats = $d279
bra_exit_world_completion = bra_exit_vs_victory_parade
handler_print_victory_messages = handler_vs_print_victory_messages
bra_advance_victory_mode_task = bra_advance_vs_victory_mode_task
handler_finish_world = handler_vs_finish_world

handler_vs_print_victory_messages:
    LDA ram_secondary_msg_counter
    BNE bra_advance_vs_victory_message
    LDY ram_primary_msg_counter
    LDA ram_world_number
    CMP #con_world8
    BEQ bra_select_vs_world8_message
    CPY #$00
    BNE bra_check_vs_message_end
    INC ram_primary_msg_counter
    LDA ram_current_player
    BEQ bra_check_vs_message_end
    INY
bra_check_vs_message_end:
    CPY #$03
    BCC bra_queue_vs_victory_message
    BCS bra_finish_vs_victory_messages
bra_select_vs_world8_message:
    CPY #$02
    BEQ bra_select_vs_player_message
    CPY #$06
    BNE bra_check_vs_world8_message_end
bra_select_vs_player_message:
    INC ram_primary_msg_counter
    LDA ram_current_player
    BEQ bra_check_vs_world8_message_end
    INY
bra_check_vs_world8_message_end:
    CPY #$0d
    BCS bra_finish_vs_victory_messages
    INY
    INY
    INY
    CPY #$07
    BNE bra_queue_vs_victory_message
    LDA #con_victory_music
    STA ram_event_music_queue
bra_queue_vs_victory_message:
    TYA
    CLC
    ADC #$0c
    STA ram_vram_buffer_addr_ctrl
bra_advance_vs_victory_message:
    LDA ram_secondary_msg_counter
    CLC
    ADC #$04
    STA ram_secondary_msg_counter
    LDA ram_primary_msg_counter
    ADC #$00
    STA ram_primary_msg_counter
    RTS
bra_finish_vs_victory_messages:
    LDA #$0c
    STA ram_world_end_timer
bra_advance_vs_victory_mode_task:
    INC ram_oper_mode_task
    LDA #$00
    STA ram_vs_arena0+$18
    STA ram_vs_arena0+$22
    STA ram_vs_arena0+$1f
    RTS

handler_vs_victory_time_tally:
    LDA ram_world_end_timer
    CMP #10
    BCS bra_exit_vs_victory_time_tally
    JSR sub_vs_tally_timer_score
    LDA ram_game_timer_display
    ORA ram_game_timer_display+1
    ORA ram_game_timer_display+2
    BNE bra_exit_vs_victory_time_tally
    LDA #$30
    STA ram_select_timer
    INC ram_oper_mode_task
bra_exit_vs_victory_time_tally:
    RTS

off_vs_victory_palette:
    .byte $3f, $00, $10, $14, $36, $14, $14, $14
    .byte $36, $08, $26, $14, $1f, $12, $1f, $14
    .byte $39, $07, $26, $00

tbl_vs_victory_cycle_colors:
    .byte $06, $23, $2a, $1f

off_vs_clear_parade_rows:
    .byte $26, $86, $55, $24, $26, $a6, $55, $24, $00

tbl_vs_parade_oam_offsets:
    .byte $50, $b0, $e0, $68, $98, $c8

tbl_vs_parade_slots:
    .byte $80, $50, $68, $80, $98, $b0, $c8

tbl_vs_parade_y_positions:
    .byte $e0, $b8, $90, $70, $68, $70, $90

tbl_vs_parade_x_positions:
    .byte $b8, $38, $48, $60, $80, $a0, $b8, $c8

handler_vs_victory_palette_cycle:
    LDA ram_world_number
    CMP #con_world8
    BEQ bra_cycle_vs_victory_palette
    LDA ram_oper_mode_task
    CLC
    ADC #$02
    STA ram_oper_mode_task
    RTS
bra_cycle_vs_victory_palette:
    INC ram_vs_arena0+$18
    LDA ram_vs_arena0+$1f
    BNE bra_wait_vs_victory_palette_step
    LDA ram_vs_arena0+$18
    AND #$ff
    BNE bra_exit_vs_victory_palette_cycle
    INC ram_vs_arena0+$1f
    JMP bra_write_vs_victory_palette
bra_wait_vs_victory_palette_step:
    LDA ram_vs_arena0+$18
    AND #$0f
    BNE bra_exit_vs_victory_palette_cycle
bra_write_vs_victory_palette:
    LDX #$13
bra_copy_vs_victory_palette:
    LDA off_vs_victory_palette,x
    STA ram_vram_buffer1,x
    DEX
    BPL bra_copy_vs_victory_palette
    LDX #$0c
    LDY ram_vs_arena0+$22
bra_apply_vs_victory_cycle_color:
    LDA tbl_vs_victory_cycle_colors,y
    STA ram_vram_buffer1+3,x
    DEX
    DEX
    DEX
    DEX
    BPL bra_apply_vs_victory_cycle_color
    INC ram_vs_arena0+$22
    LDA ram_vs_arena0+$22
    CMP #$04
    BNE bra_exit_vs_victory_palette_cycle
    INC ram_oper_mode_task
bra_exit_vs_victory_palette_cycle:
    RTS

handler_vs_victory_prepare_parade:
    LDX #$08
bra_copy_vs_clear_parade_rows:
    LDA off_vs_clear_parade_rows,x
    STA ram_vram_buffer1,x
    DEX
    BPL bra_copy_vs_clear_parade_rows
    INC ram_oper_mode_task
    LDX ram_current_player
    LDA #$01
    STA ram_vs_arena0+$28,x
    LDA #$00
    STA ram_vs_arena0+$22
    STA ram_vs_arena0+$18
    STA ram_vs_arena0+$1f
    LDA #$06
    STA ram_world_end_timer
    LDA #$60
    STA ram_vs_arena0+$2a
    RTS

sub_vs_render_victory_parade:
    LDA ram_vs_arena0+$2a
    BEQ bra_advance_vs_parade
    DEC ram_vs_arena0+$2a
    RTS
bra_advance_vs_parade:
    LDX ram_vs_arena0+$22
    CPX #$07
    BEQ bra_cycle_vs_parade_actor
    LDA ram_vs_arena0+$18
    AND #$1f
    BNE bra_render_vs_parade
    INC ram_vs_arena0+$22
    LDA #con_sfx_coin_grab
    STA ram_square2_sound_queue
    JMP bra_render_vs_parade
bra_cycle_vs_parade_actor:
    LDA ram_vs_arena0+$18
    AND #$1f
    BNE bra_render_vs_parade
    INC ram_vs_arena0+$1f
    LDA ram_vs_arena0+$1f
    CMP #$0b
    BCC bra_render_vs_parade
    LDA #$04
    STA ram_vs_arena0+$1f
bra_render_vs_parade:
    INC ram_vs_arena0+$18
    LDA ram_world_number
    PHA
    LDA ram_vs_arena0+$22
    PHA
    TAX
bra_render_vs_parade_loop:
    LDA ram_vs_arena0+$1f
    CMP #$04
    BCC bra_render_vs_parade_actor
    SBC #$04
    TAY
    LDA tbl_vs_parade_oam_offsets,y
    CMP tbl_vs_parade_slots,x
    BEQ bra_advance_vs_parade_slot
bra_render_vs_parade_actor:
    LDY tbl_vs_parade_slots,x
    STY ram_enemy_spr_data_offset
    LDA #$35
    STA ram_enemy_id
    LDA tbl_vs_parade_y_positions,x
    STA ram_enemy_y_position
    LDA tbl_vs_parade_x_positions,x
    STA ram_enemy_rel_x_pos
    LDX #$00
    STX ram_world_number
    STX ram_object_offset
    JSR sub_vs_render_parade_actor
bra_advance_vs_parade_slot:
    DEC ram_vs_arena0+$22
    LDX ram_vs_arena0+$22
    BNE bra_render_vs_parade_loop
    PLA
    STA ram_vs_arena0+$22
    PLA
    STA ram_world_number
    LDA #$30
    STA ram_enemy_spr_data_offset
    LDA #$b8
    STA ram_enemy_y_position
    RTS

handler_vs_victory_advance_course:
    LDA ram_world_number
    CMP #con_world8
    BNE bra_check_vs_next_course
    JSR sub_vs_render_victory_parade
bra_check_vs_next_course:
    LDA ram_world_end_timer
    BNE bra_exit_vs_victory_advance
    LDY ram_world_number
    CPY #con_world8
    BCS bra_prepare_vs_parade_wait
    LDA #$00
    STA ram_area_number
    STA ram_level_number
    STA ram_oper_mode_task
    INC ram_world_number
    JSR sub_load_area_pointer
    INC ram_fetch_new_game_timer_flag
    LDA #con_vs_mode_game
    STA ram_oper_mode
bra_exit_vs_victory_advance:
    RTS
bra_prepare_vs_parade_wait:
    LDA #$00
    STA ram_timer_control
    LDA #$1c
    STA ram_enemy_interval_timer+1
    INC ram_oper_mode_task
    RTS

handler_vs_finish_world:
    LDA ram_world_end_timer
    BNE bra_exit_vs_finish_world
    LDA ram_world_number
    CMP #con_world8
    BNE bra_advance_vs_finish_world
    LDA ram_numberof_lives
    BMI bra_advance_vs_finish_world
    LDA ram_select_timer
    BNE bra_exit_vs_finish_world
    LDA #$30
    STA ram_select_timer
    LDA #con_sfx_extra_life
    STA ram_square2_sound_queue
    DEC ram_numberof_lives
    LDA #$01
    STA ram_digit_modifier+1
    JMP sub_vs_award_castle_end_stats
bra_advance_vs_finish_world:
    INC ram_oper_mode_task
bra_exit_vs_finish_world:
    RTS

handler_vs_victory_wait_parade:
    JSR sub_vs_render_victory_parade
    LDA ram_enemy_interval_timer+1
    BNE bra_exit_vs_victory_parade
    INC ram_oper_mode_task
    LDA #$d8
    STA ram_select_timer
bra_exit_vs_victory_wait:
    RTS

handler_vs_victory_finish_parade:
    JSR sub_vs_render_victory_parade
    LDA ram_select_timer
    BNE bra_exit_vs_victory_parade
    LDA ram_event_music_buffer
    BNE bra_exit_vs_victory_parade
    STA ram_world_select_enable_flag
    LDA #$ff
    STA ram_numberof_lives
    LDA #con_vs_mode_game_over
    STA ram_oper_mode
    LDA #$00
    STA ram_oper_mode_task
bra_exit_vs_victory_parade:
    RTS
