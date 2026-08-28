; ANN victory messages, timer tally, and course transition

handler_print_ann_victory_messages:
    LDA ram_secondary_msg_counter
    BNE bra_continue_ann_victory_message
    LDA ram_primary_msg_counter
    BEQ bra_select_ann_victory_message
    CMP #$08
    BCS bra_continue_ann_victory_message
    CMP #$01
    BCC bra_continue_ann_victory_message
bra_select_ann_victory_message:
    TAY
    BEQ bra_queue_ann_victory_message
    CPY #$03
    BCS bra_finish_ann_victory_message
    CPY #$02
    BCS bra_continue_ann_victory_message
bra_queue_ann_victory_message:
    TYA
    CLC
    ADC #$0c
    STA ram_vram_buffer_addr_ctrl
bra_continue_ann_victory_message:
    LDA ram_secondary_msg_counter
    CLC
    ADC #$04
    STA ram_secondary_msg_counter
    LDA ram_primary_msg_counter
    ADC #$00
    STA ram_primary_msg_counter
    CMP #$06
bra_finish_ann_victory_message:
    BCC bra_exit_ann_victory_message
    LDA #$08
    STA ram_world_end_timer
bra_advance_ann_victory_mode_task:
    INC ram_oper_mode_task
bra_exit_ann_victory_message:
    RTS

handler_ann_victory_time_tally:
    LDA ram_world_end_timer
    CMP #$06
    BCS bra_exit_ann_victory_time_tally
    LDA ram_ann_game_timer_digits
    ORA ram_ann_game_timer_digits+1
    ORA ram_ann_game_timer_digits+2
    BEQ bra_finish_ann_victory_time_tally
    JMP sub_ann_tally_timer_score
bra_finish_ann_victory_time_tally:
    LDA #$30
    STA ram_select_timer
    LDA #$06
    STA ram_world_end_timer
    INC ram_oper_mode_task
bra_exit_ann_victory_time_tally:
    RTS

handler_finish_ann_world:
    LDA ram_world_end_timer
    BNE bra_exit_ann_world_completion
    LDA #$00
    STA ram_area_number
    STA ram_level_number
    STA ram_oper_mode_task
    INC ram_ann_course_number
    JSR sub_ann_load_course
    INC ram_fetch_new_game_timer_flag
    LDA #con_mode_game
    STA ram_oper_mode
bra_exit_ann_world_completion:
    RTS
