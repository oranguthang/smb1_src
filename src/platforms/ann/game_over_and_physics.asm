; Handle the ANN game-over choice and load character-specific player physics

con_ann_game_over_cursor_tile = $5b
con_ann_game_over_cursor_attribute = $02
con_ann_game_over_cursor_x = $48
con_ann_game_over_continue_y = $77
con_ann_game_over_end_y = $8f
con_ann_btn_select = %00100000
con_ann_btn_start = %00010000
con_ann_player_stat_length = 6
con_opcode_asl_absolute = $0e
con_opcode_rts = $60

tbl_ann_game_over_cursor_oam:
    .byte con_ann_game_over_cursor_tile
    .byte con_ann_game_over_cursor_attribute
    .byte con_ann_game_over_cursor_x

tbl_ann_game_over_cursor_y:
    .byte con_ann_game_over_continue_y
    .byte con_ann_game_over_end_y

handler_ann_game_over_menu:
    LDA ram_saved_joypad1_bits
    AND #con_ann_btn_start
    BNE bra_commit_ann_game_over_choice
    LDA ram_saved_joypad1_bits
    AND #con_ann_btn_select
    BEQ bra_draw_ann_game_over_cursor
    LDX ram_select_timer
    BNE bra_draw_ann_game_over_cursor
    LSR
    STA ram_select_timer
    LDA ram_ann_game_over_choice
    EOR #$01
    STA ram_ann_game_over_choice
bra_draw_ann_game_over_cursor:
    LDY #$02
    :
    LDA tbl_ann_game_over_cursor_oam,y
    STA ram_sprite_tilenumber,y
    DEY
    BPL :-
    LDY ram_ann_game_over_choice
    LDA tbl_ann_game_over_cursor_y,y
    STA ram_sprite_y_position
    RTS

bra_commit_ann_game_over_choice:
    LDA ram_ann_game_over_choice
    BEQ bra_continue_ann_game
    JMP sub_terminate_game

bra_continue_ann_game:
    LDY #$02
    STY ram_numberof_lives
    STA ram_ann_player_goals
    STA ram_ann_course_sub
    STA ram_coin_tally
    LDY #(2*con_ann_player_stat_length)-1
    :
    STA ram_player_score_display,y
    DEY
    BPL :-
    INC ram_hidden1_up_flag
    JMP loc_restart_game

tbl_ann_player_physics:
    .byte $20, $20, $1e, $28, $28, $0d, $04
    .byte $70, $70, $60, $90, $90, $0a, $09
    .byte $e4, $98, $d0
tbl_ann_luigi_physics:
    .byte $18, $18, $18, $22, $22, $0d, $04
    .byte $42, $42, $3e, $5d, $5d, $0a, $09
    .byte $b4, $68, $a0
tbl_ann_player_physics_end:

sub_ann_load_player_physics:
    LDX #con_opcode_rts
    LDY #(tbl_ann_player_physics_end-tbl_ann_player_physics)-1
    LDA ram_current_player
    BNE bra_copy_ann_player_physics
sub_ann_load_default_player_physics:
    LDX #con_opcode_asl_absolute
    LDY #(tbl_ann_luigi_physics-tbl_ann_player_physics)-1
bra_copy_ann_player_physics:
    STX off_ann_player_friction_shift_opcode
    LDX #(tbl_ann_luigi_physics-tbl_ann_player_physics)-1
    :
    LDA tbl_ann_player_physics,y
    STA off_ann_player_physics_parameters,x
    DEY
    DEX
    BPL :-
    RTS
