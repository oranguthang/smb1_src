; Prepare the ANN title screen, player identity, palette, and demo course

con_ann_title_star_first_offset = $47
con_ann_title_star_second_offset = $2f
con_ann_title_star_half_count = 10
con_ann_title_star_count = 20
con_ann_title_blank_star_tile = $26
con_ann_title_completed_star_tile = $f1
con_ann_title_game_init_clear_end = $6f
con_ann_title_sound_clear_count = $20
con_ann_title_player_name_length = 5
con_ann_title_palette_length = 4

handler_ann_title_cursor_background:
    LDA ram_oper_mode
    BNE handler_advance_ann_title_background
    LDX #$00
    :
    STA ram_vram_buffer1_offset,x
    STA $0400,x
    DEX
    BNE :-
    JSR sub_ann_draw_title_cursor
    INC ram_screen_routine_task
    RTS

handler_ann_title_score_background:
    LDA #$fa
    JSR sub_update_number
handler_advance_ann_title_background:
    JMP loc_finish_ann_title_screen

handler_ann_title_init_0:
    LDA #$00
    STA ram_ann_hard_mode
    STA ram_current_player
    JSR sub_ann_patch_title_player
    JSR sub_ann_transfer_title_cursor
    LDY #con_ann_title_star_first_offset
    LDA #con_ann_title_star_half_count
    STA ram_temp_byte
    LDX #$00
    :
    LDA #con_ann_title_blank_star_tile
    CPX off_ann_save_data
    BCS :+
    LDA #con_ann_title_completed_star_tile
    :
    STA off_ann_title_map,y
    INY
    DEC ram_temp_byte
    BNE :+
    LDY #con_ann_title_star_second_offset
    :
    INX
    CPX #con_ann_title_star_count
    BNE :---
    LDY #con_ann_title_game_init_clear_end
    JSR sub_initialize_memory
    LDY #con_ann_title_sound_clear_count-1
    :
    STA ram_sound_memory,y
    DEY
    BPL :-
    LDA #con_ann_title_demo_timer
    STA ram_demo_timer
    JSR sub_ann_load_course
    JMP handler_initialize_area

handler_ann_title_init_1:
    LDA #$01
    STA ram_ann_player_first_start
    STA ram_player_size
    LDA #$02
    STA ram_numberof_lives
    JMP handler_secondary_game_setup

tbl_ann_title_player_names:
    .byte $16, $0a, $1b, $12, $18  ; MARIO
    .byte $15, $1e, $12, $10, $12  ; LUIGI

tbl_ann_title_player_palettes:
    .byte $22, $16, $27, $18
    .byte $22, $30, $27, $19

tbl_ann_title_player_name_ends:
    .byte $04, $09

sub_ann_patch_title_player:
    LDY ram_current_player
    LDA tbl_ann_title_player_name_ends,y
    PHA
    INY
    STY ram_temp_byte
    TAY
    LDX #con_ann_title_player_name_length-1
    :
    LDA tbl_ann_title_player_names,y
    STA off_ann_title_player_name,x
    STA off_ann_thanks_player_name,x
    DEY
    DEX
    BPL :-
    PLA
    SEC
    SBC ram_temp_byte
    TAY
    LDX #con_ann_title_palette_length-1
    :
    LDA tbl_ann_title_player_palettes,y
    STA off_ann_player_palette,x
    DEY
    DEX
    BPL :-
    RTS
