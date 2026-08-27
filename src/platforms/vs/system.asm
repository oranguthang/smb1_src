; Nintendo VS. System hardware services

sub_vs_read_dip_switches:
    JSR sub_vs_select_low_chr_bank
    LDA VS_STATUS
    STA ram_vs_arena0
    LDA VS_STATUS2
    STA ram_vs_arena0+1
    LDA ram_vs_arena0
    LSR
    LSR
    LSR
    AND #(con_vs_status_dip_1+con_vs_status_dip_2)>>3
    STA $00
    LDA ram_vs_arena0+1
    AND #con_vs_status2_dips
    ORA $00
    LDY #$08
bra_reverse_vs_dip_bits:
    ASL
    ROR $01
    DEY
    BNE bra_reverse_vs_dip_bits
    LDA $01
    PHA
    AND #$01
    STA ram_vs_arena0+4
    PLA
    LSR
    PHA
    AND #$01
    STA ram_vs_arena0+3
    PLA
    LSR
    PHA
    AND #$03
    STA ram_vs_arena0+2
    PLA
    LSR
    LSR
    PHA
    AND #$01
    STA ram_vs_arena0+5
    PLA
    LSR
    AND #$07
    STA ram_vs_arena0+6
    RTS

off_vs_credit_count_packet:
    .byte $0c, $23, $94, $09, $0c, $1b, $0e, $0d, $12, $1d, $24, $00, $00, $00

off_vs_free_play_packet:
    .byte $0c, $23, $94, $09, $0f, $1b, $0e, $0e, $24, $19, $15, $0a, $22, $00

sub_vs_display_credit_message:
    JSR sub_vs_select_low_chr_bank
    LDX #$0d
    LDA ram_vs_arena0+6
    CMP #$07
    BNE bra_copy_vs_credit_count
bra_copy_vs_free_play:
    LDA off_vs_free_play_packet,x
    STA ram_vram_buffer1_offset,x
    DEX
    BPL bra_copy_vs_free_play
    RTS
bra_copy_vs_credit_count:
    LDA off_vs_credit_count_packet,x
    STA ram_vram_buffer1_offset,x
    DEX
    BPL bra_copy_vs_credit_count
    LDA ram_vs_arena0+$10
bra_convert_vs_credit_tens:
    CMP #10
    BMI bra_store_vs_credit_units
    INC ram_vram_buffer1+10
    SEC
    SBC #10
    JMP bra_convert_vs_credit_tens
bra_store_vs_credit_units:
    STA ram_vram_buffer1+11
    RTS

tbl_vs_coinage_pulses:
    .byte $01, $02, $03, $01, $01, $01, $01, $ff

tbl_vs_coinage_credits:
    .byte $01, $01, $01, $02, $03, $04, $05, $ff

sub_vs_process_coin_service:
    JSR sub_vs_select_low_chr_bank
    LDA ram_vs_arena0+$08
    BNE bra_advance_vs_coin_counter_pulse
    LDA ram_vs_arena0+$0c
    BEQ bra_exit_vs_coin_counter_pulse
    DEC ram_vs_arena0+$0c
    LDA #$04
    STA ram_vs_arena0+$13
    INC ram_vs_arena0+$08
    LDA #$01
    STA VS_COIN_COUNTER
bra_exit_vs_coin_counter_pulse:
    RTS
bra_advance_vs_coin_counter_pulse:
    DEC ram_vs_arena0+$13
    BNE bra_exit_vs_coin_counter_pulse
    LDA ram_vs_arena0+$08
    CMP #$01
    BNE bra_finish_vs_coin_counter_pulse
    LDA #$00
    STA VS_COIN_COUNTER
    LDA #$06
    STA ram_vs_arena0+$13
    INC ram_vs_arena0+$08
    RTS
bra_finish_vs_coin_counter_pulse:
    LDA #$00
    STA ram_vs_arena0+$08
    RTS

sub_vs_update_credit_display:
    JSR sub_vs_select_low_chr_bank
    LDA ram_vs_arena0+$09
    BNE bra_wait_for_vs_service_release
    LDA VS_STATUS
    AND #con_vs_status_service
    BEQ bra_exit_vs_service_poll
    LDA #$01
    STA ram_vs_arena0+$09
bra_exit_vs_service_poll:
    RTS
bra_wait_for_vs_service_release:
    LDA VS_STATUS
    AND #con_vs_status_service
    BNE bra_exit_vs_service_poll
    LDX #$02
    JSR sub_vs_add_credit
    LDA #$00
    STA ram_vs_arena0+$09
    RTS

sub_vs_update_saved_data:
    JSR sub_vs_select_low_chr_bank
    LDA ram_vs_arena0+$06
    CMP #$07
    BNE bra_poll_vs_coin_slots
    LDA #$20
    STA ram_vs_arena0+$10
bra_poll_vs_coin_slots:
    LDA VS_STATUS
    STA ram_temp_byte
    LDX #$00
    JSR sub_vs_poll_coin_slot
    LDX #$01
    LSR ram_temp_byte

sub_vs_poll_coin_slot:
    LDA ram_vs_arena0+$0a,x
    BNE bra_check_vs_coin_release
    LDA ram_temp_byte
    AND #$20
    BEQ bra_exit_vs_coin_slot_poll
    LDA #$01
    STA ram_vs_arena0+$0a,x
    LDA #$0f
    STA ram_vs_arena0+$14,x
bra_exit_vs_coin_slot_poll:
    RTS
bra_check_vs_coin_release:
    LDA ram_temp_byte
    AND #$20
    BNE bra_debounce_vs_coin_slot
    LDA ram_vs_arena0+$0a,x
    CMP #$ff
    BEQ bra_clear_vs_coin_slot
    JSR sub_vs_queue_coin_sound
    INC ram_vs_arena0+$0c
bra_clear_vs_coin_slot:
    LDA #$00
    STA ram_vs_arena0+$0a,x
    RTS
bra_debounce_vs_coin_slot:
    DEC ram_vs_arena0+$14,x
    BNE bra_exit_vs_coin_slot_poll
    LDA #$ff
    STA ram_vs_arena0+$0a,x
    RTS

sub_vs_queue_coin_sound:
    JSR sub_vs_select_low_chr_bank
    LDA #con_sfx_coin_grab
    STA ram_square2_sound_queue

sub_vs_add_credit:
    LDA ram_vs_arena0+$06
    CMP #$07
    BEQ bra_exit_vs_add_credit
    INC ram_vs_arena0+$0d,x
    TXA
    PHA
    LDA #$00
    TAX
    CLC
    ADC ram_vs_arena0+$06
    TAY
    PLA
    TAX
    LDA tbl_vs_coinage_pulses,y
    CMP ram_vs_arena0+$0d,x
    BEQ bra_award_vs_credit
    BPL bra_exit_vs_add_credit
bra_award_vs_credit:
    LDA #$00
    STA ram_vs_arena0+$0d,x
    LDA ram_vs_arena0+$10
    CMP #$5c
    BPL bra_exit_vs_add_credit
    LDA tbl_vs_coinage_credits,y
    CLC
    ADC ram_vs_arena0+$10
    STA ram_vs_arena0+$10
bra_exit_vs_add_credit:
    RTS

handler_run_vs_player_select_mode:
    LDA ram_oper_mode_task
    JSR sub_dispatch_inline_handler
    .word handler_vs_player_select_initialize
    .word handler_vs_player_select_load_screen
    .word handler_vs_player_select_prepare
    .word handler_vs_player_select_update

handler_vs_player_select_initialize:
    LDA #$00
    STA ram_screen_routine_task
    STA ram_sprite0_hit_detect_flag
    JSR sub_move_all_sprites_offscreen
    INC ram_disable_screen_flag
    INC ram_oper_mode_task
    RTS

handler_vs_player_select_load_screen:
    JSR sub_initialize_name_tables
    LDY #$01  ; player-select screen in the second Vs. CHR bank
    JSR sub_load_vs_title_chr_screen
    LDA #$00
    STA ram_vs_arena0+$27
    LDA #$01
    STA ram_vs_arena0+$26
    INC ram_oper_mode_task
    RTS

handler_vs_player_select_prepare:
    INC ram_oper_mode_task

loc_vs_player_select_prepare:
    LDA ram_vs_arena0+$10
    CMP #$01
    BEQ bra_exit_vs_player_select_prepare
    LDA #$26
    STA ram_vram_buffer_addr_ctrl
bra_exit_vs_player_select_prepare:
    RTS

tbl_vs_player_select_blink_delay:
    .byte $0a, $05

off_vs_push_button_packet:
    .byte $20, $ea, $0b, $19, $1e, $1c, $11, $24
    .byte $0b, $1e, $1d, $1d, $18, $17, $00

off_vs_clear_push_button_packet:
    .byte $20, $ea, $4b, $24, $00

loc_vs_title_exit = $82fe

handler_vs_player_select_update:
    JSR sub_vs_select_low_chr_bank
    LDA #$00
    STA ram_disable_screen_flag
    LDA ram_saved_joypad1_bits
    AND #con_btn_select
    BEQ bra_check_vs_player_two_select
    LDA #$00
    JMP bra_start_vs_selected_game
bra_check_vs_player_two_select:
    LDA ram_saved_joypad2_bits
    AND #con_btn_select
    BEQ bra_update_vs_player_select_prompt
    LDA ram_vs_arena0+$10
    CMP #$01
    BEQ bra_update_vs_player_select_prompt
    DEC ram_vs_arena0+$10
    LDA #$01
bra_start_vs_selected_game:
    STA ram_number_of_players
    LDA #$00
    STA ram_vs_arena0+$28
    STA ram_vs_arena0+$29
    DEC ram_vs_arena0+$10
    JSR sub_initialize_vs_game_ram
    JSR sub_initialize_vs_game_setup
    LDA ram_saved_joypad1_bits
    JMP loc_vs_title_exit
bra_update_vs_player_select_prompt:
    LDA ram_frame_counter
    AND #$01
    BEQ bra_refresh_vs_player_select_palette
    JSR sub_vs_display_credit_message
    DEC ram_vs_arena0+$26
    BNE bra_exit_vs_player_select_update
    LDX ram_vs_arena0+$27
    LDA tbl_vs_player_select_blink_delay,x
    STA ram_vs_arena0+$26
    LDX #$00
    LDY ram_vram_buffer1_offset
    LDA ram_vs_arena0+$27
    BNE bra_copy_vs_clear_prompt
bra_copy_vs_push_prompt:
    LDA off_vs_push_button_packet,x
    STA ram_vram_buffer1,y
    INY
    INX
    CPX #$10
    BNE bra_copy_vs_push_prompt
    BEQ bra_toggle_vs_player_select_prompt
bra_copy_vs_clear_prompt:
    LDA off_vs_clear_push_button_packet,x
    STA ram_vram_buffer1,y
    INY
    INX
    CPX #$05
    BNE bra_copy_vs_clear_prompt
bra_toggle_vs_player_select_prompt:
    LDA #$01
    EOR ram_vs_arena0+$27
    STA ram_vs_arena0+$27
bra_exit_vs_player_select_update:
    RTS
bra_refresh_vs_player_select_palette:
    JMP loc_vs_player_select_prepare

handler_vs_title_ppu_initialize:
    JSR sub_move_all_sprites_offscreen
    JSR sub_initialize_name_tables
    LDA #$ff
    STA ram_vs_arena0+$16
    LDA #$02  ; overworld palette packet
    STA ram_vram_buffer_addr_ctrl
    LDA #$00
    STA ram_vs_arena0+$22
    INC ram_oper_mode_task
    RTS

off_vs_super_players_oam:
    .byte $20, $32, $00, $30
    .byte $20, $41, $00, $38
    .byte $28, $42, $00, $30
    .byte $28, $43, $00, $38
    .byte $20, $41, $41, $c0
    .byte $20, $32, $41, $c8
    .byte $28, $43, $41, $c0
    .byte $28, $42, $41, $c8

handler_vs_title_super_players:
    LDA ram_vs_arena0+$22
    BNE bra_advance_vs_super_players_screen
    LDA #$24
    STA ram_vram_buffer_addr_ctrl
    JMP bra_increment_vs_super_players_state
bra_advance_vs_super_players_screen:
    CMP #$01
    BNE bra_render_vs_super_players
    LDY #$07  ; super-players screen in the second Vs. CHR bank
    JSR sub_load_vs_title_chr_screen
bra_increment_vs_super_players_state:
    INC ram_vs_arena0+$22
    RTS
bra_render_vs_super_players:
    LDX #$00
    STX ram_temp_byte_4
bra_render_vs_super_player_digits:
    LDA ram_temp_byte_4
    CMP #10
    BEQ bra_finish_vs_super_player_digits
    JSR sub_build_vs_high_score_row
    JMP bra_render_vs_super_player_digits
bra_finish_vs_super_player_digits:
    LDA #$00
    STA ram_vs_io_buffer,x
    LDA #$1e
    STA ram_vram_buffer_addr_ctrl
    LDY #$1f
bra_copy_vs_super_players_oam:
    LDA off_vs_super_players_oam,y
    STA ram_sprite_y_position,y
    DEY
    BPL bra_copy_vs_super_players_oam
    LDA ram_vs_arena0+$17
    CMP #$06
    BNE bra_exit_vs_super_players
    JMP sub_initialize_vs_score_countdown
bra_exit_vs_super_players:
    INC ram_oper_mode_task
    RTS

loc_vs_title_recycle = $82ef

handler_vs_title_tick:
    LDA #$00
    STA ram_disable_screen_flag
    LDA ram_frame_counter
    AND #$01
    BNE bra_exit_vs_title_tick
    DEC ram_vs_arena0+$16
    BNE bra_exit_vs_title_tick
    JMP loc_vs_title_recycle
bra_exit_vs_title_tick:
    RTS
