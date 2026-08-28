; ANN status, intermission, game-over, and warp text packets

off_ann_game_text_packets:
    .byte $20, $43, $05, $16, $0a, $1b, $12, $18, $20, $52, $0b, $20, $18, $1b, $15, $0d
    .byte $24, $24, $1d, $12, $16, $0e, $20, $68, $05, $00, $24, $24, $2e, $29, $23, $c0
    .byte $7f, $aa, $23, $c2, $01, $ea, $ff, $21, $cd, $07, $24, $24, $29, $24, $24, $24
    .byte $24, $21, $4b, $09, $20, $18, $1b, $15, $0d, $24, $24, $28, $24, $22, $0c, $47
    .byte $24, $23, $dc, $01, $ba, $ff, $22, $0c, $07, $1d, $12, $16, $0e, $24, $1e, $19
    .byte $ff, $21, $6b, $09, $10, $0a, $16, $0e, $24, $18, $1f, $0e, $1b, $21, $eb, $08
    .byte $0c, $18, $17, $1d, $12, $17, $1e, $0e, $22, $0c, $47, $24, $22, $4b, $05, $1b
    .byte $0e, $1d, $1b, $22, $ff

off_ann_warp_zone_packet:
    .byte $25, $84, $15, $20, $0e, $15, $0c, $18, $16, $0e, $24, $1d, $18, $24, $20, $0a
    .byte $1b, $19, $24, $23, $18, $17, $0e, $2b, $26, $25, $01, $24, $26, $2d, $01, $24
    .byte $26, $35, $01, $24, $27, $d9, $46, $aa, $27, $e1, $45, $aa, $00

tbl_ann_warp_zone_number_tiles:
    .byte $04, $03, $02, $00, $24, $05, $24, $00
    .byte $08, $07, $06, $00, $24, $0b, $24, $00
    .byte $24, $0c, $24, $00, $24, $0d, $24, $00

tbl_ann_game_text_packet_offsets:
    .byte $00, $27, $46, $51

handler_write_ann_game_text:
    PHA
    TAY
    LDX tbl_ann_game_text_packet_offsets,y
    LDY #$00
bra_copy_ann_game_text_packet:
    LDA off_ann_game_text_packets,x
    CMP #$ff
    BEQ bra_finish_ann_game_text_packet
    STA ram_vram_buffer1,y
    INX
    INY
    BNE bra_copy_ann_game_text_packet
bra_finish_ann_game_text_packet:
    LDA #$00
    STA ram_vram_buffer1,y
    PLA
    BEQ bra_exit_ann_game_text
    TAX
    DEX
    BNE bra_exit_ann_game_text
    LDA ram_numberof_lives
    CLC
    ADC #$01
    CMP #10
    BCC bra_store_ann_world_lives_values
    SBC #10
    LDY #$9f
    STY ram_vram_buffer1+7
bra_store_ann_world_lives_values:
    STA ram_vram_buffer1+8
    JSR sub_calculate_ann_course_display_number
    STA ram_vram_buffer1+19
    LDY ram_level_number
    INY
    STY ram_vram_buffer1+21
bra_exit_ann_game_text:
    RTS

handler_draw_ann_warp_text:
    PHA
    LDY #$ff
bra_copy_ann_warp_zone_packet:
    INY
    LDA off_ann_warp_zone_packet,y
    STA ram_vram_buffer1,y
    BNE bra_copy_ann_warp_zone_packet
    PLA
    SEC
    SBC #$80
    ASL
    ASL
    TAX
    LDY #$00
bra_copy_ann_warp_zone_numbers:
    LDA tbl_ann_warp_zone_number_tiles,x
    STA ram_vram_buffer1+27,y
    INX
    INY
    INY
    INY
    INY
    CPY #$0c
    BCC bra_copy_ann_warp_zone_numbers
    LDA #$2c
    JMP loc_store_primary_vram_buffer_offset
