sub_build_vs_high_score_row:
    LDY $04
    JSR sub_load_vs_high_score_entry_pointers
    LDA tbl_vs_high_score_row_addresses_high, y
    STA ram_vs_io_buffer, x
    INX
    LDA tbl_vs_high_score_row_addresses_low, y
    STA ram_vs_io_buffer, x
    INX
    LDA #$15
    STA ram_vs_io_buffer, x
    INX
    INY
    TYA
    CMP #$0A
    BNE :+  ; if (++$04 == 0x0A) {
    LDA #1
    STA ram_vs_io_buffer, x
    INX
    LDA #0
    STA ram_vs_io_buffer, x
    INX
    JMP :++
    :
    JSR sub_append_vs_space_to_score_row
    TYA
    STA ram_vs_io_buffer, x
    INX
    :
    LDA #$AF
    STA ram_vs_io_buffer, x
    INX
    JSR sub_append_vs_space_to_score_row
    LDY #0
    :  ; for (y = 0; y < 3; x++, y++) {
    LDA ($02), y
    STA ram_vs_io_buffer, x

    INX
    INY
    CPY #3
    BNE :-
    JSR sub_append_two_vs_spaces_to_score_row
    LDY #0
    LDA ($06), y
    STA ram_vs_io_buffer, x
    INX
    LDA #$20
    STA ram_vs_io_buffer, x
    INX
    LDA #$28
    STA ram_vs_io_buffer, x
    INX
    INY
    LDA ($06), y
    STA ram_vs_io_buffer, x
    INX
    JSR sub_append_vs_space_to_score_row

    LDY #0
    LDA ($00), y
    BNE :+
    LDA #$24
    :
    STA ram_vs_io_buffer, x

    INX
    INY
    :  ; for (y = 1; y < 7, x++, y++) {
    LDA ($00), y
    STA ram_vs_io_buffer, x

    INX
    INY
    CPY #7
    BNE :-
    INC $04
    RTS
; ----------------------------------
sub_append_two_vs_spaces_to_score_row:
    LDA #$24
    STA ram_vs_io_buffer, x
    INX
sub_append_vs_space_to_score_row:
    LDA #$24
    STA ram_vs_io_buffer, x
    INX
    RTS
; ----------------------------------
sub_initialize_vs_score_countdown:
    LDA #0
    STA ram_disable_screen_flag
    STA ram_vs_arena0+$22
    LDA #$14
    STA ram_vs_arena0+$1F
    INC ram_vs_arena0+$17
    LDA #$01
    STA ram_vs_arena0+$19
    LDA #$40
    STA ram_vs_arena0+$1A
    RTS
; ----------------------------------
off_vs_blank_name_packet:
    .byte $55, $24, $00

tbl_vs_high_score_row_addresses_high:
    .byte >(PPU_NAMETABLE_0+$0E5)
    .byte >(PPU_NAMETABLE_0+$125)
    .byte >(PPU_NAMETABLE_0+$165)
    .byte >(PPU_NAMETABLE_0+$1A5)
    .byte >(PPU_NAMETABLE_0+$1E5)
    .byte >(PPU_NAMETABLE_0+$225)
    .byte >(PPU_NAMETABLE_0+$265)
    .byte >(PPU_NAMETABLE_0+$2A5)
    .byte >(PPU_NAMETABLE_0+$2E5)
    .byte >(PPU_NAMETABLE_0+$325)

tbl_vs_high_score_row_addresses_low:
    .byte <(PPU_NAMETABLE_0+$0E5)
    .byte <(PPU_NAMETABLE_0+$125)
    .byte <(PPU_NAMETABLE_0+$165)
    .byte <(PPU_NAMETABLE_0+$1A5)
    .byte <(PPU_NAMETABLE_0+$1E5)
    .byte <(PPU_NAMETABLE_0+$225)
    .byte <(PPU_NAMETABLE_0+$265)
    .byte <(PPU_NAMETABLE_0+$2A5)
    .byte <(PPU_NAMETABLE_0+$2E5)
    .byte <(PPU_NAMETABLE_0+$325)
; ----------------------------------
handler_animate_vs_high_score_row:
    LDA ram_vs_arena0+$19
    BNE :++
    LDA ram_vs_arena0+$1A
    BEQ :+
    AND #$80
    BNE :++
    LDA ram_saved_joypad1_bits
    AND #con_btn_select
    BEQ :++
    :  ; if (!vs_ram_arena0[0x19] || (!(vs_ram_arena0[0x19] & 0x80) && joypad[0].select))) {
    LDA #con_silence
    STA ram_area_music_queue
    JMP handler_finish_vs_game_over_sequence
    :
    LDY ram_vs_arena0+$18
    JSR sub_load_vs_high_score_entry_pointers

    LDA ram_vs_arena0+$1A
    SEC
    SBC #1
    STA ram_vs_arena0+$1A
    LDA ram_vs_arena0+$19
    SBC #0
    STA ram_vs_arena0+$19
    LDX #0
    LDA tbl_vs_high_score_row_addresses_high, y
    STA ram_vram_buffer1, x
    INX
    LDA tbl_vs_high_score_row_addresses_low, y
    STA ram_vram_buffer1, x
    INX
    LDA ram_vs_arena0+$22
    AND #$01
    BEQ :+++
    LDA ram_vs_arena0+$1F
    BNE :+
    JSR sub_toggle_vs_score_phase_long
    RTS
    :
    LDY #0
    :  ; for (y = 0; y < 3; x++, y++) {
    LDA off_vs_blank_name_packet, y
    STA ram_vram_buffer1, x

    INX
    INY
    CPY #3
    BNE :-
    DEC ram_vs_arena0+$1F
    RTS
    :
    LDA ram_vs_arena0+$1F
    BNE :+
    JSR sub_toggle_vs_score_phase_short
    RTS
    :
    LDA #$15
    STA ram_vram_buffer1, x
    INX
    JSR sub_append_vs_rank_number
    JSR sub_append_vs_space_tile

    LDY #0
    :  ; for (y = 0; y < 3; x++, y++) {
    LDA ($02), y
    STA ram_vram_buffer1, x

    INX
    INY
    CPY #3
    BNE :-
    JSR sub_append_two_vs_space_tiles
    JSR sub_append_vs_course_number
    JSR sub_append_vs_space_tile

    LDY #0
    LDA ($00), y
    BNE :+
    LDA #$24
    :
    STA ram_vram_buffer1, x

    INX
    INY
    :  ; for (y = 1; y < 7; x++, y++) {
    LDA ($00), y
    STA ram_vram_buffer1, x

    INX
    INY
    CPY #7
    BNE :-
    LDA #0
    STA ram_vram_buffer1, x
    DEC ram_vs_arena0+$1F
    RTS
; ----------------------------------
sub_toggle_vs_score_phase_short:
    LDA #$0A
    STA ram_vs_arena0+$1F
    INC ram_vs_arena0+$22
    RTS
; ----------------------------------
sub_toggle_vs_score_phase_long:
    LDA #$14
    STA ram_vs_arena0+$1F
    INC ram_vs_arena0+$22
    RTS
; ----------------------------------
off_vs_continue_prompt_tiles:
    .byte $21, $2A
    .byte $0B, $12
    .byte $17, $1C
    .byte $0E, $1B
    .byte $1D, $24
    .byte $0C, $18
    .byte $12, $17

off_vs_insert_coin_prompt_tiles:
    .byte $20, $EA
    .byte $0B, $19
    .byte $1E, $1C
    .byte $11, $24
    .byte $0B, $1E
    .byte $1D, $1D
    .byte $18, $17

off_vs_countdown_packet:
    .byte $22, $71, $02

off_vs_continue_prompt_header:
    .byte $21, $2A, $4B, $24

off_vs_insert_coin_prompt_header:
    .byte $20, $EA, $4B, $24

off_vs_continue_palette_packet:
    .byte $3F, $08
    .byte $04, $14
    .byte $36, $12
    .byte $26, $00

off_vs_continue_attributes_packet:
    .byte $23, $C0
    .byte $60, $AA
    .byte $23, $E0
    .byte $60, $AA
    .byte $00
; ----------------------------------
handler_prepare_vs_continue_attributes:
    LDX #9-1
    :  ; for (x = 9-1; x >= 0; x--) {
    LDA off_vs_continue_attributes_packet, x
    STA ram_vram_buffer1, x

    DEX
    BPL :-
    INC ram_vs_arena0+$22
    RTS
; ----------------------------------
tbl_vs_continue_player_oam:
    .byte $00
    .byte $01
    .byte $4C
    .byte $4D
    .byte $4A
    .byte $80|$4A
    .byte $4B
    .byte $80|$4B
; ----------------------------------
handler_prepare_vs_continue_screen:
    LDA ram_vs_arena0+$22  ; switch (vs_ram_arena0[0x22]) {
    BNE :+  ; case 0:
    LDA #con_vs_nmi_palette_1e_f
    STA ram_vram_buffer_addr_ctrl
    INC ram_vs_arena0+$22
    RTS
    : cmp   #1
    BNE :++  ; case 1:
    LDX #7
    :  ; for (x = 8-1; x >= 0; x--) {
    LDA off_vs_continue_palette_packet, x
    STA ram_vram_buffer1, x

    DEX
    BPL :-
    INC ram_vs_arena0+$22
    RTS
    : cmp   #2
    BNE :+  ; case 2:
    JMP handler_prepare_vs_continue_attributes
    : cmp   #3
    BNE :+  ; case 3:
    LDY #con_vs_chr_screen_insert_coin
    JSR sub_load_vs_title_chr_screen
    INC ram_vs_arena0+$22
    RTS
    :  ; default:
    JSR sub_initialize_vs_score_countdown
    LDA #0
    STA ram_vs_arena0+$1A
    STA ram_vs_arena0+$18

    LDA #$80
    STA $00
    LDY #7
    LDX #$1F
    :  ; for (i = 0x80; i > 0x60; i -= 8) {
    LDA #$80
    STA $00+1
    LDA #2
    STA $02
    :  ; for (j = 2; j > 0; j--) {
    LDA $00+1
    STA ram_sprite_data+3-3, x
    SEC
    SBC #$08
    STA $00+1
    DEX
    LDA tbl_vs_continue_player_oam, y
    AND #$80
    LSR a
    ORA ram_current_player
    STA ram_sprite_data+2-2, x
    DEX
    LDA tbl_vs_continue_player_oam, y
    AND #$7F
    STA ram_sprite_data+1-1, x
    DEX
    LDA $00
    STA ram_sprite_data+0, x

    DEX
    DEY
    DEC $02
    BNE :-
    SEC
    SBC #8
    STA $00
    CMP #$60
    BNE :--
    RTS
; ----------------------------------
handler_update_vs_continue_screen:
    LDA ram_vs_arena0+$10
    BEQ :++
    LDA ram_vs_arena0+$18
    BNE :+
    LDA #1
    STA ram_disable_screen_flag
    INC ram_vs_arena0+$18
    RTS
    :
    LDY #con_vs_chr_screen_continue
    JSR sub_load_vs_title_chr_screen
    JSR sub_initialize_vs_score_countdown
    LDA #0
    STA ram_vs_arena0+$1A
    RTS
    :
    JSR sub_tick_vs_continue_timer
    LDX #0
    LDA ram_vs_arena0+$22
    AND #$01
    BNE :++
    LDA ram_vs_arena0+$1F
    BEQ :+
    JSR sub_write_vs_prompt_tiles
    DEC ram_vs_arena0+$1F
    JMP sub_finish_vs_countdown_packet
    :
    JSR sub_toggle_vs_score_phase_short
    JMP sub_finish_vs_countdown_packet
    :
    JSR sub_update_vs_continue_blink
    RTS
; ----------------------------------
sub_update_vs_continue_blink:
    LDA ram_vs_arena0+$1F
    BEQ :+  ; if (vs_ram_arena0[0x1F]) {
    JSR sub_write_vs_prompt_header
    DEC ram_vs_arena0+$1F
    JMP :++
    :
    JSR sub_toggle_vs_score_phase_long
    :
    JSR sub_finish_vs_countdown_packet
    RTS
; ----------------------------------
handler_process_vs_continue_input:
    LDA ram_saved_joypad1_bits
    AND #con_btn_select
    BEQ :++++  ; if (joypad[0].select) {
    LDA ram_vs_arena0+$04
    BEQ :+
    LDA #2
    BNE :++
    :
    LDA #3
    :
    STA ram_numberof_lives

    LDA #0
    STA ram_vs_arena0+$17
    STA ram_level_number
    STA ram_area_number
    INC ram_oper_mode_task
    JSR sub_select_vs_player_score

    LDY #6-1
    :  ; for (y = 6-1; y >= 0; y--) {
    LDA #0
    STA ($04), y

    DEY
    BPL :-
    DEC ram_vs_arena0+$10
    RTS
    :
    JSR sub_tick_vs_continue_timer
    JSR sub_vs_display_credit_message
    LDX #$0C

    LDA ram_vs_arena0+$22
    AND #$01
    BNE :++
    LDA ram_vs_arena0+$1F
    BEQ :+  ; if (!(vs_ram_arena0[0x22] & 0x01) && vs_ram_arena0[0x1F]) {
    JSR sub_write_vs_prompt_tiles
    DEC ram_vs_arena0+$1F
    JMP sub_finish_vs_countdown_packet
    :  ; } else if (!(vs_ram_arena0[0x22] & 0x01)) {
    JSR sub_toggle_vs_score_phase_short
    JMP sub_finish_vs_countdown_packet
    :
    JMP sub_update_vs_continue_blink
    RTS
; ----------------------------------
sub_tick_vs_continue_timer:
    LDA ram_vs_arena0+$19
    BNE :+
    LDA ram_vs_arena0+$1A
    BNE :+
    LDA #0
    STA ram_vs_arena0+$17
    STA ram_world_select_enable_flag
    STA ram_primary_hard_mode
    INC ram_oper_mode_task
    RTS
    : lda   ram_vs_arena0+$1B
    BEQ :+
    DEC ram_vs_arena0+$1B
    JMP :+++
    :
    LDA #$48
    STA ram_vs_arena0+$1B

    LDA ram_vs_arena0+$1A
    BNE :+
    LDA #9
    STA ram_vs_arena0+$1A
    DEC ram_vs_arena0+$19
    JMP :++
    :
    DEC ram_vs_arena0+$1A
    :
    RTS
; ----------------------------------
sub_finish_vs_countdown_packet:
    LDY #0
    :  ; for (y = 0; y < 3; x++, y++) {
    LDA off_vs_countdown_packet, y
    STA ram_vram_buffer1, x

    INX
    INY
    CPY #3
    BNE :-
    LDY #0
    :  ; for (y = 0; y < 2; y++) {
    LDA ram_vs_arena0+$19, y
    STA ram_vram_buffer1, x

    INX
    INY
    CPY #2
    BNE :-
    LDA #0
    STA ram_vram_buffer1, x
    STX ram_vram_buffer1_offset
    RTS
; ----------------------------------
sub_write_vs_prompt_tiles:
    LDY #0
    :  ; for (y = 0; y < 0x0E; x++, y++) {
    LDA ram_vs_arena0+$17
    CMP #3
    BNE :+  ; if (vs_ram_arena[0x17] == 3) {
    LDA off_vs_continue_prompt_tiles, y
    JMP :++
    :
    LDA off_vs_insert_coin_prompt_tiles, y
    :
    STA ram_vram_buffer1, x

    INX
    INY
    CPY #$0E
    BNE :---
    RTS
; ----------------------------------
sub_write_vs_prompt_header:
    LDY #0
    :  ; for (y = 0; y < 4; y++) {
    LDA ram_vs_arena0+$17
    CMP #3
    BNE :+  ; if (vs_ram_arena[0x17] == 3) {
    LDA off_vs_continue_prompt_header, y
    JMP :++
    :
    LDA off_vs_insert_coin_prompt_header, y
    :
    STA ram_vram_buffer1, x

    INX
    INY
    CPY #4
    BNE :---
    RTS
