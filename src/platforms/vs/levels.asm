; Vs. Super Mario Bros. course loader and CHR-resident course indexes

; The arcade board keeps course streams in the second 8 KiB CHR bank. The loader
; selects that bank through the Vs. System protection latch, reads each stream
; through the PPU data port, and copies it to work RAM for the ordinary parser

.repeat 55
    .byte $ff
.endrepeat

sub_load_area_pointer = handler_vs_load_area_pointer
sub_get_area_type = sub_vs_get_area_type
sub_find_area_pointer = sub_vs_find_area_pointer
sub_get_area_data_addresses = handler_vs_get_area_data_addresses
tbl_world_area_pointer_offsets = tbl_vs_world_area_pointer_offsets
tbl_area_pointers = tbl_vs_area_pointers
tbl_enemy_data_offsets_by_area_type = tbl_vs_enemy_data_offsets_by_area_type
tbl_area_object_data_offsets_by_area_type = tbl_vs_area_object_data_offsets_by_area_type

handler_vs_load_area_pointer:
    JSR sub_vs_find_area_pointer
    STA ram_area_pointer
sub_vs_get_area_type:
    AND #%01100000
    ASL
    ROL
    ROL
    ROL
    STA ram_area_type
    RTS

sub_vs_find_area_pointer:
    LDY ram_world_number
    LDA tbl_world_area_pointer_offsets,y
    CLC
    ADC ram_area_number
    TAY
    LDA tbl_area_pointers,y
    RTS

handler_vs_get_area_data_addresses:
    JSR sub_vs_select_low_chr_bank
    LDA #con_vs_request_chr_high+con_vs_request_irq_release
    STA VS_REQUEST
    LDA PPU_STATUS
    LDA ram_temp_byte
    STA PPU_ADDRESS
    LDA ram_temp_byte
    STA PPU_ADDRESS
    LDY #$00
    LDA PPU_DATA
bra_copy_vs_io_buffer:
    LDA PPU_DATA
    STA ram_vs_io_buffer,y
    INY
    CPY #$20
    BNE bra_copy_vs_io_buffer

    LDA ram_area_pointer
    JSR sub_vs_get_area_type
    TAY
    LDA ram_area_pointer
    AND #%00011111
    STA ram_area_addrs_l_offset
    LDA tbl_enemy_data_offsets_by_area_type,y
    CLC
    ADC ram_area_addrs_l_offset
    ASL
    TAY
    LDA PPU_STATUS
    LDA tbl_enemy_data_ptr+1,y
    STA PPU_ADDRESS
    LDA tbl_enemy_data_ptr,y
    STA PPU_ADDRESS
    LDY #$00
    LDA PPU_DATA
bra_copy_vs_enemy_data:
    LDA PPU_DATA
    STA ram_vs_enemy_data,y
    INY
    CMP #$ff
    BNE bra_copy_vs_enemy_data
    LDA #<ram_vs_enemy_data
    STA ram_enemy_data_low
    LDA #>ram_vs_enemy_data
    STA ram_enemy_data_high

    LDY ram_area_type
    LDA tbl_area_object_data_offsets_by_area_type,y
    CLC
    ADC ram_area_addrs_l_offset
    ASL
    TAY
    LDA PPU_STATUS
    LDA tbl_area_object_data_ptr+1,y
    STA PPU_ADDRESS
    LDA tbl_area_object_data_ptr,y
    STA PPU_ADDRESS
    LDY #$00
    LDA PPU_DATA
bra_copy_vs_area_data:
    LDA PPU_DATA
    STA ram_vs_area_data,y
    INY
    CMP #$fd
    BNE bra_copy_vs_area_data
    LDA #<ram_vs_area_data
    STA ram_area_data_low
    LDA #>ram_vs_area_data
    STA ram_area_data_high

    LDY #$00
    LDA (ram_area_data),y
    PHA
    AND #%00000111
    CMP #$04
    BCC bra_store_vs_foreground_scenery
    STA ram_background_color_ctrl
    LDA #$00
bra_store_vs_foreground_scenery:
    STA ram_foreground_scenery
    PLA
    PHA
    AND #%00111000
    LSR
    LSR
    LSR
    STA ram_player_entrance_ctrl
    PLA
    AND #%11000000
    CLC
    ROL
    ROL
    ROL
    STA ram_game_timer_setting
    INY
    LDA (ram_area_data),y
    PHA
    AND #%00001111
    STA ram_terrain_control
    PLA
    PHA
    AND #%00110000
    LSR
    LSR
    LSR
    LSR
    STA ram_background_scenery
    PLA
    AND #%11000000
    CLC
    ROL
    ROL
    ROL
    CMP #%00000011
    BNE bra_store_vs_area_style
    STA ram_cloud_type_override
    LDA #$00
bra_store_vs_area_style:
    STA ram_area_style
    LDA ram_area_data_low
    CLC
    ADC #$02
    STA ram_area_data_low
    LDA ram_area_data_high
    ADC #$00
    STA ram_area_data_high
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
    RTS

tbl_vs_world_area_pointer_offsets:
    .byte $00, $05, $0a, $0e, $13, $17, $1b, $20

tbl_vs_area_pointers:
    .byte $25, $29, $c0, $36, $66
    .byte $28, $29, $03, $37, $62
    .byte $24, $35, $20, $63
    .byte $22, $29, $41, $2c, $67
    .byte $2a, $31, $2d, $61
    .byte $2e, $23, $26, $60
    .byte $33, $29, $01, $27, $64
    .byte $30, $32, $21, $65

tbl_vs_enemy_data_offsets_by_area_type:
    .byte $23, $08, $20, $00

tbl_enemy_data_ptr:
    ; Castle streams: Vs 1, 2, 1, 4, 5, 6, Vs 7, and 3
    .word $0020, $000b, $0048, $0063, $0086, $00bb, $00d0, $010a
    ; Ground streams 1-6, Vs 7-8, 9-21, Vs 22, then original 7-8
    .word $0127, $0156, $0185, $01a2, $01b2, $01df, $0214, $0234
    .word $0257, $0278, $02a2, $02a3, $02d1, $02da, $02ff, $0322
    .word $0335, $0336, $0370, $039b, $03cf, $03ef, $03f8, $0429
    ; Underground streams 1-3
    .word $0442, $0457, $0484
    ; Water streams 1, Vs 2, 3, and original 2
    .word $04b6, $04e3, $04f4, $0525

tbl_vs_area_object_data_offsets_by_area_type:
    .byte $39, $05, $00, $04

tbl_area_object_data_ptr:
    ; Water streams 1, Vs 2, 3, and original 2
    .word $151c, $1545, $1622, $163f
    ; Ground streams 1-6, Vs 7-8, 9-21, Vs 22, then original 7-8
    .word $09cb, $0a2e, $0a93, $0aec, $0b83, $0c20, $0c85, $0cde
    .word $0d63, $0dce, $0dd7, $0e16, $0e2b, $0e8e, $0ef3, $0f60
    .word $0f91, $1022, $10a5, $111a, $1193, $11be, $1243, $1298
    ; Underground streams 1-3
    .word $131d, $13ca, $1477
    ; Castle streams: Vs 1, 2, 1, 4, 5, 6, Vs 7, and 3
    .word $0563, $062e, $06b3, $071e, $07c1, $0850, $08d9, $0948
