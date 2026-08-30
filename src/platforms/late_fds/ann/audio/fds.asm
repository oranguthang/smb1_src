; All Night Nippon FDS wavetable preparation and note decoding

sub_ann_prepare_fds_wave:
    LDA zp_ann_fds_wave_id
    BNE $cf35
    RTS
    LDY #$00
    INY
    LSR
    BCC $cf37
    LDA $d24b, Y
    TAY
    LDA tbl_ann_fds_wave_offsets, Y
    STA ram_ann_fds_wave_address
    LDA $d24d, Y
    STA ram_ann_fds_wave_address + 1
    LDA $d24e, Y
    STA ram_ann_fds_wave_envelope_start
    LDA $d24f, Y
    STA ram_ann_fds_wave_volume_address
    LDA $d250, Y
    STA ram_ann_fds_wave_volume_address + 1
    LDA $d251, Y
    STA ram_ann_fds_wave_mod_address
    LDA $d252, Y
    STA ram_ann_fds_wave_mod_address + 1
    LDA $d253, Y
    STA ram_ann_fds_wave_mod_offset
    JSR $cf72
    LDA #$02
    STA FDS_SND_WAVE_VOLUME
    RTS
    LDA #$80
    STA FDS_SND_WAVE_VOLUME
    LDA #$00
    STA FDS_SND_WAVE_RAM
    LDY #$00
    LDX #$3f
    LDA (ram_ann_fds_wave_address), Y
    STA $4041, Y
    INY
    CPY #$20
    BEQ $cf90
    STA FDS_SND_WAVE_RAM, X
    DEX
    BNE $cf80
    LDA ram_ann_fds_music_current
    AND #$40
    BEQ $cf9b
    LDA #$00
    BEQ $cf9d
    LDA #$03
    STA FDS_SND_WAVE_VOLUME

sub_ann_load_fds_modulation:
    LDA #$80
    STA FDS_SND_MOD_FREQ_HI
    LDA #$00
    STA FDS_SND_MOD_COUNT
    LDX #$20
    LDY ram_ann_fds_wave_mod_offset
    STY zp_ann_fds_mod_offset
    LDA zp_ann_fds_mod_offset
    LSR
    TAY
    LDA tbl_ann_fds_modulation_a, Y
    BCS $cfbe
    LSR
    LSR
    LSR
    LSR
    AND #$0f
    STA FDS_SND_MOD_WRITE
    INC zp_ann_fds_mod_offset
    DEX
    BNE $cfb1
    RTS

tbl_ann_fds_modulation_a:
    .byte $07, $07, $07, $07, $01, $01, $01, $01, $01, $01, $01, $01, $07, $07, $07, $07

tbl_ann_fds_modulation_b:
    .byte $77, $77, $77, $77, $11, $11, $11, $11, $11, $11, $11, $11, $77, $77, $77, $77

sub_ann_decompress_fds_note:
    TAX
    ROR
    TXA
    ROL
    ROL
    ROL

sub_ann_load_fds_note_length:
    AND #$07
    CLC
    ADC ram_ann_fds_note_length_offset
    TAY
    LDA tbl_ann_fds_note_lengths, Y
    RTS
