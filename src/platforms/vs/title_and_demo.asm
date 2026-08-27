; Vs. Super Mario Bros. title flow and attract-mode input script

sub_vs_game_initialize_0 = $9651
handler_vs_background_process = $8748
sub_vs_game_initialize_1 = $96ff
sub_vs_game_core = $ad6e
sub_draw_mushroom_icon = $ffff
handler_run_title_screen_mode = handler_run_vs_title_screen_mode
tbl_world_select_vram_template = tbl_vs_world_select_vram_template
loc_start_or_continue_game = loc_vs_start_or_continue_game
sub_go_continue = sub_vs_go_continue
tbl_demo_joypad_actions = tbl_vs_demo_joypad_actions
tbl_demo_action_durations = tbl_vs_demo_action_durations
sub_demo_engine = sub_vs_demo_engine

handler_run_vs_title_screen_mode:
    LDA ram_vs_arena0+$10
    BEQ bra_dispatch_vs_title_task
    LDA #$00
    STA ram_oper_mode_task
    STA ram_sprite0_hit_detect_flag
    INC ram_oper_mode
    LDA #$01
    STA ram_disable_screen_flag
    RTS
bra_dispatch_vs_title_task:
    LDA ram_oper_mode_task
    JSR sub_dispatch_inline_handler
    .word handler_vs_title_initialize
    .word sub_vs_game_initialize_0
    .word handler_vs_background_process
    .word sub_vs_game_initialize_1
    .word handler_vs_title_process
    .word handler_vs_player_select_initialize
    .word handler_vs_title_ppu_initialize
    .word handler_vs_title_super_players
    .word handler_vs_title_tick

handler_vs_title_initialize:
    LDA #$01
    STA ram_disable_screen_flag
    LDA #$00
    STA ram_sprite0_hit_detect_flag
    INC ram_oper_mode_task
    RTS

tbl_vs_world_select_vram_template:
    .byte $04, $20, $73, $01, $00, $00

handler_vs_title_process:
    LDY #$00
    LDX ram_demo_timer
    BNE bra_clear_vs_title_joypads
    JSR sub_vs_demo_engine
    BCS bra_advance_vs_title_task
    JMP loc_run_vs_title_demo
bra_clear_vs_title_joypads:
    LDA #$00
    STA ram_saved_joypad1_bits
    STA ram_saved_joypad2_bits
loc_run_vs_title_demo:
    JSR sub_vs_game_core
    LDA ram_game_engine_subroutine
    CMP #$06
    BNE bra_exit_vs_title_process
bra_advance_vs_title_task:
    INC ram_oper_mode_task
    LDA #$00
    STA ram_sprite0_hit_detect_flag
    INC ram_disable_screen_flag
    RTS

loc_vs_reset_title:
    LDA #$00
    STA ram_oper_mode
    STA ram_oper_mode_task
    STA ram_sprite0_hit_detect_flag
    INC ram_disable_screen_flag
    RTS

loc_vs_start_or_continue_game:
    ASL
    BCC bra_start_vs_game
    LDA ram_continue_world
    JSR sub_vs_go_continue
bra_start_vs_game:
    JSR sub_load_area_pointer
    INC ram_hidden1_up_flag
    INC ram_off_scr_hidden1_up_flag
    INC ram_fetch_new_game_timer_flag
    INC ram_oper_mode
    LDA ram_world_select_enable_flag
    STA ram_primary_hard_mode
    LDA #$00
    STA ram_oper_mode_task
    STA ram_demo_timer
    LDX #$17
    LDA #$00
bra_initialize_vs_player_scores:
    STA ram_score_and_coin_display,x
    DEX
    BPL bra_initialize_vs_player_scores
bra_exit_vs_title_process:
    RTS

sub_vs_go_continue:
    STA ram_world_number
    STA ram_off_scr_world_number
    LDX #$00
    STX ram_area_number
    STX ram_off_scr_area_number
    RTS

tbl_vs_demo_joypad_actions:
    .byte $01, $80, $02, $81, $41, $80, $01
    .byte $42, $c2, $02, $80, $41, $c1, $41, $c1
    .byte $01, $c1, $01, $02, $80, $00

tbl_vs_demo_action_durations:
    .byte $9b, $10, $18, $05, $2c, $20, $24
    .byte $15, $5a, $10, $20, $28, $30, $20, $10
    .byte $80, $20, $30, $30, $01, $ff, $00

sub_vs_demo_engine:
    LDX ram_demo_action
    LDA ram_demo_action_timer
    BNE bra_apply_vs_demo_action
    INX
    INC ram_demo_action
    SEC
    LDA tbl_vs_demo_action_durations-1,x
    STA ram_demo_action_timer
    BEQ bra_finish_vs_title_demo
bra_apply_vs_demo_action:
    LDA tbl_vs_demo_joypad_actions-1,x
    STA ram_saved_joypad1_bits
    DEC ram_demo_action_timer
    CLC
bra_finish_vs_title_demo:
    LDA #$00
    STA ram_saved_joypad2_bits
    RTS
