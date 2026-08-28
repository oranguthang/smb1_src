; All Night Nippon ending sequence, guest procession, and ending text

handler_ann_ending_background:
    LDA ram_screen_routine_task
    JSR $6d0f
    .byte $7d, $65, $2e, $66, $36, $66, $e6, $c5, $a6, $65, $c6, $65, $f2, $c5, $fb, $c5

handler_ann_show_throne_room:
    LDA #$1b
    STA ram_vram_buffer_addr_ctrl
    STA ram_sprite0_hit_detect_flag

loc_ann_advance_ending_background:
    INC ram_screen_routine_task
    RTS

handler_ann_load_ending_palette:
    LDA #$1e
    STA ram_vram_buffer_addr_ctrl
    INC ram_screen_routine_task
    RTS

handler_ann_show_princess:
    LDA #$a2
    JSR $6e0b
    LDA #$cc
    STA $6121
    LDA #$b1
    STA $6120
    LDA #$01
    STA ram_area_music_queue
    LDA #$00
    STA ram_left_right_buttons
    STA ram_fds_background_pattern_bits
    STA ram_sprite0_hit_detect_flag
    STA ram_disable_screen_flag

loc_ann_advance_ending_state:
    INC ram_oper_mode_task
    RTS

handler_ann_ending_victory_message:
    LDA ram_secondary_msg_counter
    BNE $c63d
    LDY ram_primary_msg_counter
    CPY #$0a
    BCS $c64f
    INY
    INY
    INY
    CPY #$05
    BNE $c636
    LDA #$04
    STA ram_event_music_queue
    TYA
    CLC
    ADC #$0c
    STA ram_vram_buffer_addr_ctrl
    LDA ram_secondary_msg_counter
    CLC
    ADC #$04
    STA ram_secondary_msg_counter
    LDA ram_primary_msg_counter
    ADC #$00
    STA ram_primary_msg_counter
    RTS
    LDA #$0c
    STA ram_world_end_timer

loc_ann_initialize_ending_state:
    INC ram_oper_mode_task

sub_ann_clear_ending_state:
    LDA #$00
    STA ram_offscreen_player_info
    STA ram_off_scr_halfway_page
    STA ram_off_scr_level_number
    RTS

handler_ann_convert_extra_lives:
    LDA ram_world_end_timer
    BNE $c662
    LDA ram_onscreen_player_info
    BMI loc_ann_initialize_ending_state
    LDA ram_select_timer
    BNE $c662
    LDA #$30
    STA ram_select_timer
    LDA #$40
    STA ram_square2_sound_queue
    DEC ram_onscreen_player_info
    LDA #$01
    STA $0135
    JSR $9f74
    LDA ram_ann_fds_music_current
    BNE $c68f
    LDA #$01
    STA ram_area_music_queue
    RTS

tbl_ann_ending_palette:
    .byte $3f, $00, $10

tbl_ann_ending_palette_bytes:
    .byte $0f, $30, $0f, $0f, $0f, $30, $10, $00, $0f, $21, $12, $21, $0f, $27, $17, $00

tbl_ann_ending_palette_bytes_end:
    .byte $00

tbl_ann_ending_palette_variants:
    .byte $01, $02, $11, $21

tbl_ann_ending_lives_display:
    .byte $22, $86, $55, $24, $22, $a6, $55, $24, $00

handler_ann_cycle_ending_palette:
    INC ram_offscreen_player_info
    LDA ram_off_scr_level_number
    BNE $c6c6
    LDA ram_offscreen_player_info
    AND #$ff
    BNE $c6f6
    INC ram_off_scr_level_number
    JMP $c6cd
    LDA ram_offscreen_player_info
    AND #$0f
    BNE $c6f6
    LDX #$13
    LDA tbl_ann_ending_palette, X
    STA ram_vram_buffer1, X
    DEX
    BPL $c6cf
    LDX #$0c
    LDY ram_off_scr_halfway_page
    LDA tbl_ann_ending_palette_variants, Y
    STA $0304, X
    DEX
    DEX
    DEX
    DEX
    BPL $c6dd
    INC ram_off_scr_halfway_page
    LDA ram_off_scr_halfway_page
    CMP #$04
    BNE $c6f6
    INC ram_oper_mode_task
    RTS

handler_ann_draw_ending_lives:
    LDX #$08
    LDA tbl_ann_ending_lives_display, X
    STA ram_vram_buffer1, X
    DEX
    BPL $c6f9
    INC ram_oper_mode_task
    JSR sub_ann_clear_ending_state
    LDA #$60
    STA ram_off_scr_hidden1_up_flag
    LDA #$02
    STA $079c
    RTS

handler_ann_render_ending_guests:
    JSR sub_ann_render_ending_guest_sprites
    LDA ram_ann_fds_music_current
    BNE $c72d
    LDA $079c
    BEQ $c725
    LDA #$01
    STA ram_area_music_queue
    RTS
    LDA ram_ann_hard_mode
    BNE loc_ann_finish_save
    INC ram_oper_mode_task
    RTS

handler_ann_save_ending:
    LDA ram_fds_disk_loader_task
    JSR $6d0f
    .byte $29, $c1, $4f, $c7, $3c, $c1, $4e, $c1, $56, $c1

tbl_ann_save_file_header:
    .byte $0f, $53, $4d, $32, $53, $41, $56, $45, $20, $e3, $d2, $01, $00, $00, $e3, $d2
    .byte $00

handler_ann_write_save:
    LDA #$07
    JSR $e239
    .byte $e8, $c0, $3e, $c7
    BEQ loc_ann_finish_save
    INC ram_fds_disk_loader_task
    JMP $c198

loc_ann_finish_save:
    LDA #$d2
    STA $6121
    LDA #$e5
    STA $6120
    LDA #$00
    STA ram_fds_disk_loader_task
    STA ram_oper_mode_task
    LDA #$00
    STA ram_oper_mode
    JMP $bfbf

tbl_ann_guest_sprite_offsets:
    .byte $50, $b0, $e0, $68, $98, $c8

tbl_ann_guest_sprite_next_offsets:
    .byte $80, $50, $68, $80, $98, $b0, $c8

tbl_ann_guest_sprite_y:
    .byte $e0, $b8, $90, $70, $68, $70, $90

tbl_ann_guest_sprite_x:
    .byte $b8, $38, $48, $60, $80, $a0, $b8, $c8

tbl_ann_guest_sprite_tiles:
    .byte $7a, $80, $86, $8c, $92, $98, $9e

tbl_ann_guest_sprite_attributes:
    .byte $02, $03, $01, $02, $03, $01, $03

sub_ann_render_ending_guest_sprites:
    LDA ram_off_scr_hidden1_up_flag
    BEQ $c7ad
    DEC ram_off_scr_hidden1_up_flag
    RTS
    JSR $628d
    LDX ram_off_scr_halfway_page
    CPX #$07
    BEQ $c7c8
    LDA ram_offscreen_player_info
    AND #$1f
    BNE $c7de
    INC ram_off_scr_halfway_page
    LDA #$01
    STA ram_square2_sound_queue
    JMP $c7de
    LDA ram_offscreen_player_info
    AND #$1f
    BNE $c7de
    INC ram_off_scr_level_number
    LDA ram_off_scr_level_number
    CMP #$0b
    BCC $c7de
    LDA #$04
    STA ram_off_scr_level_number
    INC ram_offscreen_player_info
    LDA ram_off_scr_halfway_page
    PHA
    TAX
    LDA ram_off_scr_level_number
    CMP #$04
    BCC $c7f8
    SBC #$04
    TAY
    LDA tbl_ann_guest_sprite_offsets, Y
    CMP tbl_ann_guest_sprite_next_offsets, X
    BEQ $c84f
    LDY tbl_ann_guest_sprite_next_offsets, X
    LDA tbl_ann_guest_sprite_y, X
    STA ram_sprite_y_position, Y
    STA $020c, Y
    CLC
    ADC #$08
    STA $0204, Y
    STA $0210, Y
    CLC
    ADC #$08
    STA $0208, Y
    STA $0214, Y
    LDA tbl_ann_guest_sprite_x, X
    STA ram_sprite_x_position, Y
    STA $0207, Y
    STA $020b, Y
    CLC
    ADC #$08
    STA $020f, Y
    STA $0213, Y
    STA $0217, Y
    LDA $c795, X
    STA ram_temp_byte
    LDA $c79c, X
    STA zp_ann_fds_wave_id
    LDX #$00
    LDA ram_temp_byte
    STA ram_sprite_tilenumber, Y
    LDA zp_ann_fds_wave_id
    STA ram_sprite_attributes, Y
    INY
    INY
    INY
    INY
    INC ram_temp_byte
    INX
    CPX #$06
    BNE $c83a
    DEC ram_off_scr_halfway_page
    LDX ram_off_scr_halfway_page
    BNE $c7e6
    PLA
    STA ram_off_scr_halfway_page
    LDA #$30
    STA ram_enemy_spr_data_offset
    LDA #$b8
    STA ram_enemy_y_position
    RTS

tbl_ann_ending_player_names:
    .byte $16, $0a, $1b, $12, $18, $15, $1e, $12, $10, $12

handler_ann_set_ending_player_name:
    LDA #$00
    STA ram_screen_routine_task
    LDX #$04
    LDA ram_current_player
    BEQ $c87d
    LDX #$09
    LDY #$04
    LDA tbl_ann_ending_player_names, X
    STA tbl_ann_thank_you_player_name, Y
    STA tbl_ann_hurrah_player_name, Y
    DEX
    DEY
    BPL $c87f
    RTS

tbl_ann_ending_attributes:
    .byte $23, $c0, $48, $55, $23, $c2, $01, $d5, $00

tbl_ann_ending_palette_nmi:
    .byte $3f, $00, $10, $0f, $0f, $0f, $0f, $0f, $30, $10, $00, $0f, $21, $12, $02, $0f
    .byte $27, $17, $00, $00

tbl_ann_msg_thank_you:
    .byte $20, $e8, $10, $1d, $11, $0a, $17, $14, $24, $22, $18, $1e, $24

tbl_ann_thank_you_player_name:
    .byte $16, $0a, $1b, $12, $18, $2b, $23, $c8, $48, $05, $00

tbl_ann_msg_peace_is_paved:
    .byte $21, $09, $0e, $19, $0e, $0a, $0c, $0e, $24, $12, $1c, $24, $19, $0a, $1f, $0e
    .byte $0d, $23, $d0, $58, $aa, $00

tbl_ann_msg_kingdom_saved:
    .byte $21, $47, $12, $20, $12, $1d, $11, $24, $14, $12, $17, $10, $0d, $18, $16, $24
    .byte $1c, $0a, $1f, $0e, $0d, $00

tbl_ann_msg_hurrah_to:
    .byte $21, $89, $10, $11, $1e, $1b, $1b, $0a, $11, $24, $1d, $18, $24, $24

tbl_ann_hurrah_player_name:
    .byte $16, $0a, $1b, $12, $18, $00

tbl_ann_msg_only_hero:
    .byte $21, $ca, $0d, $18, $1e, $1b, $24, $18, $17, $15, $22, $24, $11, $0e, $1b, $18
    .byte $00

tbl_ann_msg_trip_end:
    .byte $22, $07, $13, $1d, $11, $12, $1c, $24, $0e, $17, $0d, $1c, $24, $22, $18, $1e
    .byte $1b, $24, $1d, $1b, $12, $19, $00

tbl_ann_msg_long_friendship:
    .byte $22, $46, $14, $18, $0f, $24, $0a, $24, $15, $18, $17, $10, $24, $0f, $1b, $12
    .byte $0e, $17, $0d, $1c, $11, $12, $19, $00

tbl_ann_msg_bonus_points:
    .byte $22, $88, $10, $01, $00, $00, $00, $00, $00, $24, $19, $1d, $1c, $af, $0a, $0d
    .byte $0d, $0e, $0d, $23, $e8, $48, $ff, $00

tbl_ann_msg_players_left:
    .byte $22, $a6, $15, $0f, $18, $1b, $24, $0e, $0a, $0c, $11, $24, $19, $15, $0a, $22
    .byte $0e, $1b, $24, $15, $0e, $0f, $1d, $af, $00

tbl_ann_ending_palette_extension:
    .byte $3f, $14, $0c, $0f, $12, $30, $36, $0f, $36, $30, $16, $0f, $36, $30, $1a, $00

tbl_ann_throne_room_map:
    .byte $20, $80, $60, $5e, $20, $a0, $60, $5d, $23, $40, $60, $5e, $23, $60, $60, $5d
    .byte $23, $80, $60, $5e, $23, $a0, $60, $5d, $23, $c0, $50, $55, $23, $f0, $50, $55
    .byte $00
