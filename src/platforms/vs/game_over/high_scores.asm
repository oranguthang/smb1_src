handler_run_vs_high_score_mode:
    LDA ram_vs_arena0+$17
    JSR sub_dispatch_inline_handler
    .addr sub_advance_vs_game_over_state
    .addr handler_insert_vs_high_score
    .addr handler_initialize_vs_game_over_screen
    .addr handler_prepare_vs_name_entry_screen
    .addr handler_update_vs_name_entry
    .addr handler_initialize_vs_game_over_screen
    .addr handler_vs_title_super_players
    .addr handler_animate_vs_high_score_row

handler_run_vs_continue_mode:
    LDA ram_vs_arena0+$17
    JSR sub_dispatch_inline_handler
    .addr sub_advance_vs_game_over_state
    .addr handler_initialize_vs_game_over_screen
    .addr handler_prepare_vs_continue_screen
    .addr handler_update_vs_continue_screen
    .addr handler_process_vs_continue_input
; ----------------------------------
handler_finish_vs_game_over_delay:
    LDA #0
    STA ram_disable_screen_flag
    LDA ram_screen_timer
    BNE :+  ; if (!ram_screen_timer) {
    LDA #con_silence
    STA ram_event_music_queue
    INC ram_oper_mode_task
    LDA #0
    STA ram_vs_arena0+$17
    :
    RTS
; ----------------------------------
sub_advance_vs_game_over_state:
    LDA #1
    STA ram_disable_screen_flag
    INC ram_vs_arena0+$17
    RTS
; ----------------------------------
tbl_vs_player_score_addresses_low:
    .byte $DD, $E3
sub_select_vs_player_score:
    LDX ram_current_player
    LDA tbl_vs_player_score_addresses_low, x
    STA $04
    LDA #7
    STA $04+1
    RTS
; ----------------------------------
tbl_vs_high_score_name_addresses_low:
    .byte <(ram_vs_arena0+$BA)
    .byte <(ram_vs_arena0+$C1)
    .byte <(ram_vs_arena0+$C8)
    .byte <(ram_vs_arena0+$CF)
    .byte <(ram_vs_arena0+$D6)
    .byte <(ram_vs_arena0+$DD)
    .byte <(ram_vs_arena0+$E4)
    .byte <(ram_vs_arena0+$EB)
    .byte <(ram_vs_arena0+$F2)
    .byte <(ram_vs_arena0+$F9)

tbl_vs_high_score_course_addresses_low:
    .byte <(ram_vs_arena0+$75)
    .byte <(ram_vs_arena0+$78)
    .byte <(ram_vs_arena0+$7B)
    .byte <(ram_vs_arena0+$7E)
    .byte <(ram_vs_arena0+$81)
    .byte <(ram_vs_arena0+$84)
    .byte <(ram_vs_arena0+$87)
    .byte <(ram_vs_arena0+$8A)
    .byte <(ram_vs_arena0+$8D)
    .byte <(ram_vs_arena0+$90)

sub_load_vs_high_score_entry_pointers:
    LDA tbl_vs_high_score_name_addresses_low, y
    STA $00
    LDA tbl_vs_high_score_course_addresses_low, y
    STA $06
    CLC
    ADC #<(ram_vs_arena0+$1D)
    STA $02
    LDA #>(ram_vs_arena0)
    STA $00+1
    STA $02+1
    STA $06+1
    RTS
; ----------------------------------
handler_insert_vs_high_score:
    JSR sub_select_vs_player_score

    LDA #0
    STA ram_vs_arena0+$18
    LDA #9
    STA ram_vs_arena0+$22
    :  ; for (vs_ram_arena[0x18] = 0; vs_ram_arena[0x18] < 9; vs_ram_arena[0x18]++) {
    LDY ram_vs_arena0+$18
    JSR sub_load_vs_high_score_entry_pointers

    LDY #0
    :  ; for (y = 0; $04[y] > $00[y] && y < 6; y++) {
    LDA ($04), y
    CMP ($00), y
    BCC :+
    BNE :+++

    INY
    CPY #6
    BNE :-
    :
    LDA ram_vs_arena0+$18
    CMP #9
    BNE :+  ; if (vs_ram_arena0[0x18] == 9) {
    JMP handler_finish_vs_game_over_sequence
    :
    INC ram_vs_arena0+$18
    JMP :----
    :
    :  ; while (vs_ram_arena0[0x22] < vs_ram_arena0[0x18]) {
    LDY ram_vs_arena0+$22
    CPY ram_vs_arena0+$18
    BEQ :++++
    BCC :++++

    JSR sub_load_vs_high_score_entry_pointers

    DEY
    LDA tbl_vs_high_score_name_addresses_low, y
    STA $04
    LDA tbl_vs_high_score_course_addresses_low, y
    STA $ed
    CLC
    ADC #$1D
    STA $eb
    LDA #>ram_vs_arena0
    STA $04+1
    STA $eb+1
    STA $ed+1
    STY ram_vs_arena0+$22

    LDY #7-1
    :  ; for (y = 7-1; y >= 0; y--) {
    LDA ($04), y
    STA ($00), y

    DEY
    BPL :-
    LDY #3-1
    :  ; for (y = 3-1; y >=0; y--) {
    LDA ($eb), y
    STA ($02), y

    DEY
    BPL :-
    LDY #2-1
    :  ; for (y = 2-1; y >= 0; y--) {
    LDA ($ed), y
    STA ($06), y

    DEY
    BPL :-
    JMP :----
    :
    LDY ram_vs_arena0+$18
    JSR sub_load_vs_high_score_entry_pointers
    JSR sub_select_vs_player_score

    LDY #7-1
    LDA #0
    STA ($00), y
    DEY
    :  ; for (y = 6-1; y >= 0; y--) {
    LDA ($04), y
    STA ($00), y

    DEY
    BPL :-
    LDY #3-1
    :  ; for (y = 3-1; y >= 0; y--) {
    LDA #$24
    STA ($02), y

    DEY
    BPL :-
    LDY #$00
    LDA ram_world_number
    CLC
    ADC #1
    STA ($06), y
    INY
    LDA ram_level_number
    CLC
    ADC #1
    STA ($06), y
    JSR sub_advance_vs_game_over_state
    RTS
; ----------------------------------
handler_finish_vs_game_over_sequence:
    LDA #0
    STA ram_vs_arena0+$17
    LDX ram_current_player
    LDA ram_vs_arena0+$28, x
    BEQ :+  ; if (vs_ram_arena0[0x28]) {
    INC ram_oper_mode_task
    :
    INC ram_oper_mode_task
    RTS
; ----------------------------------
handler_initialize_vs_game_over_screen:
    JSR sub_initialize_name_tables
    JSR sub_move_all_sprites_offscreen
    INC ram_vs_arena0+$17
    LDA #0
    STA ram_vs_arena0+$22
    RTS
; ----------------------------------
off_vs_high_score_course_packet:
    .byte $23
    .byte $2F
    .byte $0C
; ----------------------------------
sub_append_vs_course_number:
    LDY #0
    LDA ($06), y
    STA ram_vram_buffer1, x
    INX
    LDA #$20
    STA ram_vram_buffer1, x
    INX
    LDA #$28
    STA ram_vram_buffer1, x
    INX
    INY
    LDA ($06), y
    STA ram_vram_buffer1, x
    INX
    RTS
; ----------------------------------
handler_prepare_vs_name_entry_screen:
    LDA ram_vs_arena0+$22
    BNE :+  ; if (!vs_ram_arena0[0x22]) {
    LDA #con_vs_nmi_palette_1e_f
    STA ram_vram_buffer_addr_ctrl
    INC ram_vs_arena0+$22
    RTS
    :  ; } else if (vs_ram_arena0[0x22].in(1, 2, 3)) {
    CMP #1
    BNE :+  ; if (vs_ram_arena0[0x22] == 1) {
    LDY #con_vs_chr_screen_box
    JMP :+++
    : cmp   #2
    BNE :+  ; } else if (vs_ram_arena0[0x22] == 2) {
    LDY #con_vs_chr_screen_name_entry
    JMP :++
    : cmp   #3
    BNE :++
    LDY #con_vs_chr_screen_high_scores
    :
    JSR sub_load_vs_title_chr_screen
    INC ram_vs_arena0+$22
    RTS
    :
    LDY ram_vs_arena0+$18
    JSR sub_load_vs_high_score_entry_pointers

    LDX #0
    :  ; for (x = 0; x < 3; x++) {
    LDA off_vs_high_score_course_packet, x
    STA ram_vram_buffer1, x

    INX
    CPX #3
    BNE :-
    JSR sub_append_vs_course_number
    JSR sub_append_vs_period_tile

    LDY #0
    LDA ($00), y
    BNE :+  ; if (!$00) {
    LDA #>PPU_NAMETABLE_1
    :
    STA ram_vram_buffer1, x

    INX
    INY
    :  ; for (x = 3, y = 1; y < 7; x++, y++) {
    LDA ($00), y
    STA ram_vram_buffer1, x

    INX
    INY
    CPY #7
    BNE :-
    LDA #0
    STA ram_vram_buffer1, x
    STA ram_vs_arena0+$22
    STA ram_disable_screen_flag
    STA ram_vs_arena0+$1A
    STA ram_vs_arena0+$20
    STA ram_vs_arena0+$21
    STA ram_vs_arena0+$23
    STA ram_vs_arena0+$24
    INC ram_vs_arena0+$17

    LDY #2
    STY ram_vs_arena0+$19
    :  ; for (y = 3-1; y >= 0; y--) {
    LDA #$24
    STA ram_vs_arena0+$1C, y

    DEY
    BPL :-
    LDA #$10
    STA ram_vs_arena0+$1F
    LDA #con_star_power_music
    STA ram_area_music_queue
    STA ram_vs_arena0+$1B
    RTS
; ----------------------------------
sub_append_vs_rank_number:
    INY
    CPY #$0A
    BNE :+
    LDA #1
    STA ram_vram_buffer1, x
    INX
    LDA #0
    STA ram_vram_buffer1, x
    INX
    JMP :++
    :
    JSR sub_append_vs_space_tile
    TYA
    STA ram_vram_buffer1, x
    INX
    :
sub_append_vs_period_tile:
    LDA #$AF
    STA ram_vram_buffer1, x
    INX
    RTS
; ----------------------------------
sub_append_two_vs_space_tiles:
    LDA #$24
    STA ram_vram_buffer1, x
    INX

sub_append_vs_space_tile:
    LDA #$24
    STA ram_vram_buffer1, x
    INX
    RTS
; ----------------------------------
tbl_vs_name_cursor_y_positions:
    .byte $48, $68, $88

tbl_vs_name_cursor_x_positions:
    .byte $2C, $3C, $4C, $5C
    .byte $6C, $7C, $8C, $9C
    .byte $AC, $BC, $CC

tbl_vs_name_cursor_symbol_x_positions:
    .byte $2C, $3C, $4C, $5C
    .byte $6C, $7C, $8C, $9C
    .byte $B0, $C8

tbl_vs_name_character_page_offsets:
    .byte $00, $0B

tbl_vs_name_symbol_tiles:
    .byte $20, $21, $22, $23
    .byte $2B, $28, $AF, $FA

off_vs_name_entry_packet:
    .byte $22, $F6, $03
off_vs_name_entry_packet_end:
; ----------------------------------
handler_update_vs_name_entry:
    LDA ram_vs_arena0+$19
    BNE :+
    LDA ram_vs_arena0+$1A
    BNE :+
    JSR sub_advance_vs_game_over_state
    JSR sub_store_vs_high_score_name
    JMP loc_render_vs_name_cursor
    :
    LDA ram_vs_arena0+$1B
    BEQ :+  ; if (vs_ram_arena0[0x1B]) {
    DEC ram_vs_arena0+$1B
    JMP :+++
    :
    LDA #$40
    STA ram_vs_arena0+$1B

    LDA ram_vs_arena0+$1A
    BNE :+  ; if (!vs_ram_arena0[0x1A]) {
    LDA #9
    STA ram_vs_arena0+$1A
    DEC ram_vs_arena0+$19

    JMP :++
    :
    DEC ram_vs_arena0+$1A
    :
    JSR sub_read_vs_game_over_joypad
    AND #con_btn_up|con_btn_down|con_btn_left|con_btn_right
    BNE :+  ; if (joypad.not_in(up, down, left, right)) {
    STA ram_vs_arena0+$25
    JMP loc_update_vs_name_input_latches
    :
    STA ram_vs_arena0+$25
    AND ram_vs_arena0+$24
    BEQ :+
    STA ram_vs_arena0+$25
    DEC ram_vs_arena0+$1F
    LDA ram_vs_arena0+$1F
    BEQ :+
    JMP loc_update_vs_name_input_latches

    :
    LDA ram_vs_arena0+$25
    AND #$01
    BNE :+
    LDA ram_vs_arena0+$25
    AND #$02
    BNE :+++++
    LDA ram_vs_arena0+$25
    AND #$08
    STA ram_vs_arena0+$25
    BNE loc_decrement_vs_name_cursor_row
    LDA #4
    STA ram_vs_arena0+$25
    JMP loc_advance_vs_name_cursor_row
    :
    STA ram_vs_arena0+$25
    INC ram_vs_arena0+$20
    LDA ram_vs_arena0+$20
    CMP #$0B
    BEQ :+
    CMP #$0A
    BNE :+++
    LDA ram_vs_arena0+$21
    CMP #2
    BNE :+++
    :
    LDA #0
    STA ram_vs_arena0+$20
loc_advance_vs_name_cursor_row:
    INC ram_vs_arena0+$21
    LDA ram_vs_arena0+$21
    CMP #3
    BEQ :+
    CMP #2
    BNE :++
    LDA ram_vs_arena0+$20
    CMP #$0A
    BNE :++
    LDA #9
    STA ram_vs_arena0+$20
    JMP :++
    :
    LDA #0
    STA ram_vs_arena0+$21
    :
    JMP :+++++
    :
    STA ram_vs_arena0+$25
    LDA ram_vs_arena0+$20
    BEQ :+
    DEC ram_vs_arena0+$20
    JMP :++++
    :
    LDA #$0A
    STA ram_vs_arena0+$20
    LDA ram_vs_arena0+$21
    BNE :+
    LDA #9
    STA ram_vs_arena0+$20
    :
loc_decrement_vs_name_cursor_row:
    LDA ram_vs_arena0+$21
    BEQ :+
    DEC ram_vs_arena0+$21
    JMP :++
    :
    LDA #2
    STA ram_vs_arena0+$21
    LDA ram_vs_arena0+$20
    CMP #$0A
    BNE :+
    LDA #9
    STA ram_vs_arena0+$20
    :
    LDA #$10
    STA ram_vs_arena0+$1F
loc_update_vs_name_input_latches:

    LDA ram_vs_arena0+$25
    STA ram_vs_arena0+$24

    JSR sub_read_vs_game_over_joypad
    AND #con_btn_a
    BNE :+
    STA ram_vs_arena0+$23
    JMP :+++++++
    : cmp   ram_vs_arena0+$23
    BEQ :++++++  ; if (joypad.face_a && vs_ram_arena0[0x23] != face_a) {
    STA ram_vs_arena0+$23
    LDA ram_vs_arena0+$21
    CMP #2
    BNE :+++
    LDA ram_vs_arena0+$20
    CMP #9
    BNE :+
    JSR sub_advance_vs_game_over_state
    JSR sub_store_vs_high_score_name
    RTS
    : cmp   #$08
    BNE :++
    LDA ram_vs_arena0+$22
    BEQ :+
    DEC ram_vs_arena0+$22
    :
    LDX ram_vs_arena0+$22
    LDA #$24
    STA ram_vs_arena0+$1C, x
    JMP :++++
    :
    LDX ram_vs_arena0+$22
    CPX #3
    BEQ loc_render_vs_name_cursor
    LDY ram_vs_arena0+$21
    CPY #2
    BNE :+
    LDY ram_vs_arena0+$20
    LDA tbl_vs_name_symbol_tiles, y
    JMP :++
    :
    LDA ram_vs_arena0+$20
    CLC
    ADC tbl_vs_name_character_page_offsets, y
    CLC
    ADC #$0A
    :
    STA ram_vs_arena0+$1C, x
    INC ram_vs_arena0+$22
    LDA ram_vs_arena0+$22
    CMP #3
    BNE :+
    LDA #2
    STA ram_vs_arena0+$21
    LDA #9
    STA ram_vs_arena0+$20
    :
loc_render_vs_name_cursor:
    LDX ram_vs_arena0+$21
    LDA tbl_vs_name_cursor_y_positions, x
    STA ram_sprite_data+(4*0)+0
    STA ram_sprite_data+(4*1)+0
    CLC
    ADC #$08
    STA ram_sprite_data+(4*2)+0
    STA ram_sprite_data+(4*3)+0

    LDA #$32
    STA ram_sprite_data+(4*0)+1
    LDA #$41
    STA ram_sprite_data+(4*1)+1
    LDA #$42
    STA ram_sprite_data+(4*2)+1
    LDA #$43
    STA ram_sprite_data+(4*3)+1

    LDX ram_vs_arena0+$20
    LDA ram_vs_arena0+$21
    CMP #2
    BNE :+  ; if (vs_ram_arena0[0x21] == 2) {
    LDA tbl_vs_name_cursor_symbol_x_positions, x
    JMP :++
    :
    LDA tbl_vs_name_cursor_x_positions, x
    :
    STA ram_sprite_data+(4*0)+3
    STA ram_sprite_data+(4*2)+3
    CLC
    ADC #$08
    STA ram_sprite_data+(4*1)+3
    STA ram_sprite_data+(4*3)+3

    LDA ram_current_player
    STA ram_sprite_data+(4*0)+2
    STA ram_sprite_data+(4*1)+2
    STA ram_sprite_data+(4*2)+2
    STA ram_sprite_data+(4*3)+2

    LDX #(off_vs_name_entry_packet_end-off_vs_name_entry_packet)-1
    :  ; for (x = 3-1; x > 0; x--) {
    LDA off_vs_name_entry_packet, x
    STA ram_vram_buffer1+0, x
    LDA ram_vs_arena0+$1C, x
    STA ram_vram_buffer1+3, x

    DEX
    BPL :-
    LDA #>(PPU_NAMETABLE_0+$305)
    STA ram_vram_buffer1+6
    LDA #<(PPU_NAMETABLE_0+$305)
    STA ram_vram_buffer1+7
    LDA #2
    STA ram_vram_buffer1+8
    LDA ram_vs_arena0+$19
    STA ram_vram_buffer1+9
    LDA ram_vs_arena0+$1A
    STA ram_vram_buffer1+10
    LDA #0
    STA ram_vram_buffer1+11
    RTS
; ----------------------------------
sub_store_vs_high_score_name:
    LDY ram_vs_arena0+$18
    JSR sub_load_vs_high_score_entry_pointers
    LDY #3-1
    :  ; for (y = 3-1; y >= 0; y--) {
    LDA ram_vs_arena0+$1C, y
    STA ($02), y

    DEY
    BPL :-
    RTS
; ----------------------------------
sub_read_vs_game_over_joypad:
    LDA ram_number_of_players
    BEQ :+  ; if (ram_number_of_players > 0) {
    LDX ram_current_player
    LDA ram_saved_joypad_bits, x
    JMP :++
    :
    LDA ram_saved_joypad1_bits
    ORA ram_saved_joypad2_bits
    :
    RTS
; ----------------------------------
