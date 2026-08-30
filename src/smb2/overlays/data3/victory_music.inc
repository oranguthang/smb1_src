tbl_smb2_data3_music_header_offset_data:
    .byte tbl_smb2_data3_victory_part_1a_header-MHD, tbl_smb2_data3_victory_part_1a_header-MHD, tbl_smb2_data3_victory_part_1b_header-MHD, tbl_smb2_data3_victory_part_1a_header-MHD
    .byte tbl_smb2_data3_victory_part_2a_header-MHD, tbl_smb2_data3_victory_part_2b_header-MHD, tbl_smb2_data3_victory_part_2a_header-MHD, tbl_smb2_data3_victory_part_2b_header-MHD
    .byte tbl_smb2_data3_victory_part_2c_header-MHD, tbl_smb2_data3_victory_part_2a_header-MHD, tbl_smb2_data3_victory_part_2d_header-MHD

; header format here is as follows:
; 1 byte - length byte offset
; 2 bytes - music data address
; 1 byte - triangle data offset
; 1 byte - square 1 data offset
; 1 byte - noise data offset
; these two are unique to the sound engine in this file
; 1 byte - FDS channel data offset
; 1 byte - waveform ID

off_smb2_data3_music_header_offsets:
tbl_smb2_data3_victory_part_1a_header:
    .byte $00, <off_smb2_data3_victory_m_p1_a_data, >off_smb2_data3_victory_m_p1_a_data, $3e, $14, $b0, $24, $01
tbl_smb2_data3_victory_part_1b_header:
    .byte $00, <off_smb2_data3_victory_m_p1_b_data, >off_smb2_data3_victory_m_p1_b_data, $50, $21, $61, $31, $02
tbl_smb2_data3_victory_part_2a_header:
    .byte $00, <off_smb2_data3_victory_m_p2_a_data, >off_smb2_data3_victory_m_p2_a_data, $43, $1c, $b5, $29, $01
tbl_smb2_data3_victory_part_2c_header:
    .byte $00, <off_smb2_data3_victory_m_p2_c_data, >off_smb2_data3_victory_m_p2_c_data, $50, $20, $61, $31, $02
tbl_smb2_data3_victory_part_2d_header:
    .byte $08, <off_smb2_data3_victory_m_p2_d_data, >off_smb2_data3_victory_m_p2_d_data, $09, $04, $1e, $06, $01
tbl_smb2_data3_victory_part_2b_header:
    .byte $08, <off_smb2_data3_victory_m_p2_b_data, >off_smb2_data3_victory_m_p2_b_data, $3a, $10, $9e, $28, $01

; residual data, probably from an old header
    .byte $00, $4b, $d0

; music data format here is the same as in sm2main file
; with a few exceptions: the value $00 does nothing special
; for square 1, and noise data format plays only one kind of
; beat for d5-d1 = nonzero, or rest for d5-d1 = 0

off_smb2_data3_victory_m_p1_a_data:
; square 2
    .byte $84, $12, $86, $0c, $84, $62, $10, $86
    .byte $12, $84, $1c, $22, $1e, $22, $26, $18
    .byte $1e, $04, $1c, $00
; square 1
    .byte $e2, $e0, $e2, $9d, $1f, $21, $a3, $2d
    .byte $74, $f4, $31, $35, $37, $2b, $b1, $2d
; FDS sound
    .byte $83, $16, $14, $16, $86, $10, $84, $12
    .byte $14, $86, $16, $84, $20, $81, $28, $83
    .byte $28, $84, $24, $28, $2a, $1e, $86, $24
    .byte $84, $20
; triangle
    .byte $84, $12, $14, $04, $18, $1a, $1c, $14
    .byte $26, $22, $1e, $1c, $18, $1e, $22, $0c
    .byte $14

off_smb2_data3_victory_m_p1_b_data:
; square 2
    .byte $81, $22, $83, $22, $86, $24, $85, $18
    .byte $82, $1e, $80, $1e, $83, $1c, $83, $18
    .byte $84, $1c, $81, $26, $83, $26, $86, $26
    .byte $85, $1e, $82, $24, $86, $22, $84, $1e
    .byte $00
; square 1
    .byte $74, $f4, $b5, $6b, $b0, $30, $ec, $ea
    .byte $2d, $76, $f6, $b7, $6d, $b0, $b5, $31
; FDS sound
    .byte $81, $10, $83, $10, $86, $10, $85, $08
    .byte $82, $0c, $80, $0c, $83, $0a, $08, $84
    .byte $0a, $81, $12, $83, $12, $86, $12, $85
    .byte $0a, $82, $0c, $86, $10, $84, $0c
; triangle
    .byte $84, $12, $1c, $20, $24, $2a, $26, $24
    .byte $26, $22, $1e, $22, $24, $1e, $22, $0c
    .byte $1e
; noise (also used by part 1A)
    .byte $11, $11, $d0, $d0, $d0, $11, $00

off_smb2_data3_victory_m_p2_a_data:
; square 2
    .byte $83, $2c, $2a, $2c, $86, $26, $84, $28
    .byte $2a, $86, $2c, $84, $36, $81, $40, $83
    .byte $40, $84, $3a, $40, $3e, $34, $00

off_smb2_data3_victory_m_p2_b_data:
; square 2
    .byte $86, $3a, $84, $36, $00
; square 1 of part 2A
    .byte $1d, $95, $19, $1b, $9d, $27, $2d, $29
    .byte $2d, $31, $23
; square 1 of part 2B
    .byte $a9, $27
; FDS sound of part 2A
    .byte $83, $20, $1e, $20, $86, $1a, $84, $1c
    .byte $1e, $86, $20, $84, $2a, $81, $32, $83
    .byte $32, $84, $2e, $32, $34, $28
; FDS sound of part 2B
    .byte $86, $2e, $84, $2a
; triangle of part 2A
    .byte $84, $1c, $1e, $04, $22, $24, $26, $1e
    .byte $30, $2c, $28, $26, $22, $28
; triangle of part 2B
    .byte $2c, $14, $1e

off_smb2_data3_victory_m_p2_c_data:
; square 2
    .byte $81, $40, $83, $40, $86, $40, $85, $34
    .byte $82, $3a, $80, $3a, $83, $36, $34, $84
    .byte $36, $81, $3e, $83, $3e, $86, $3e, $85
    .byte $36, $82, $3a, $86, $40, $84, $3a, $00
; square 1
    .byte $6c, $ec, $af, $63, $a8, $29, $c4, $e6
    .byte $e2, $27, $70, $f0, $b1, $69, $ae, $ad
    .byte $29
; FDS sound
    .byte $81, $1a, $83, $1a, $86, $1a, $85, $10
    .byte $82, $16, $80, $16, $83, $12, $10, $84
    .byte $12, $81, $1c, $83, $1c, $86, $1c, $85
    .byte $12, $82, $16, $86, $1a, $84, $16
; triangle
    .byte $84, $1c, $26, $2a, $2e, $34, $30, $2e
    .byte $30, $2c, $28, $2c, $2e, $28, $2c, $14
    .byte $28
; noise of part 2A, 2B and 2C
    .byte $11, $11, $d0, $d0, $d0, $11, $00

off_smb2_data3_victory_m_p2_d_data:
; square 2
    .byte $87, $3a, $36, $00
; square 1
    .byte $e9, $e7
; FDS sound
    .byte $87, $2e, $2a
; triangle
    .byte $83, $16, $1c, $22, $28, $2e, $34, $84
    .byte $3a, $83, $34, $22, $34, $84, $36, $83
    .byte $1e, $1e, $1e, $86, $1e
; noise of part 2D
    .byte $11, $11, $d0, $d0, $d0, $11, $00

off_smb2_data3_waveform_data2:
    .byte $10, $2c, $2e, $27, $29, $2b, $2a, $28
    .byte $25, $29, $2f, $2d, $2c, $2a, $22, $24
    .byte $34, $3f, $31, $2d, $3a, $3b, $27, $12
    .byte $0a, $1f, $2c, $27, $23, $28, $22, $1e

off_smb2_data3_volume_envelope_data_2:
    .byte $a0, $04, $18, $60
off_smb2_data3_volume_envelope_data_1:
    .byte $94, $02, $44, $30, $0a, $50, $a0, $02
    .byte $36, $35, $80, $34

tbl_smb2_data3_fds_freq_lookup_tbl:
    .byte $01, $44, $01, $58, $01, $99, $02, $22
    .byte $02, $42, $02, $65, $02, $b0, $02, $d9
    .byte $03, $04, $03, $32, $03, $63, $03, $96
    .byte $03, $cd, $04, $07, $04, $44, $04, $85
    .byte $04, $ca, $05, $13, $05, $60, $05, $b2
    .byte $06, $08, $06, $64, $06, $c6, $07, $2d
    .byte $07, $9a, $08, $0e, $08, $88, $09, $95
    .byte $0a, $26, $00, $00

off_smb2_data3_victory_music_envelope_data:
    .byte $97, $98, $9a, $9b, $9b, $9a, $9a, $99
    .byte $99, $98, $98, $97, $97, $96, $96, $95

; header format here is as follows:
; 2 bytes - waveform data address
; 1 byte  - master envelope timing (used with both volume envelope and sweep/modulation)
; 2 bytes - volume envelope data address
; 2 bytes - sweep envelope/mod frequency data address
; 1 byte  - modulation table data offset * 2

tbl_smb2_data3_waveform_header_offsets:
    .byte tbl_smb2_data3_waveform_1_header-tbl_smb2_data3_waveform_header_offsets, tbl_smb2_data3_waveform_2_header-tbl_smb2_data3_waveform_header_offsets

off_smb2_data3_waveform_header_data:
tbl_smb2_data3_waveform_1_header:
    .byte <off_smb2_data3_waveform_data1, >off_smb2_data3_waveform_data1, $44, <off_smb2_data3_volume_envelope_data_1
    .byte >off_smb2_data3_volume_envelope_data_1, <off_smb2_data3_sweep_mod_data1, >off_smb2_data3_sweep_mod_data1, (tbl_smb2_data3_mod_table2-tbl_smb2_data3_mod_table_data) * 2
tbl_smb2_data3_waveform_2_header:
    .byte <off_smb2_data3_waveform_data2, >off_smb2_data3_waveform_data2, $60, <off_smb2_data3_volume_envelope_data_2
    .byte >off_smb2_data3_volume_envelope_data_2, <off_smb2_data3_sweep_mod_data2, >off_smb2_data3_sweep_mod_data2, (tbl_smb2_data3_mod_table1-tbl_smb2_data3_mod_table_data) * 2
    .byte $00

off_smb2_data3_waveform_data1:
    .byte $01, $02, $03, $04, $06, $07, $09, $0b
    .byte $0e, $10, $13, $18, $20, $2b, $34, $3c
    .byte $3f, $3f, $3e, $3d, $3a, $36, $32, $2f
    .byte $2c, $29, $26, $24, $21, $1e, $18, $19

off_smb2_data3_sweep_mod_data1:
    .byte $80, $1b, $81, $0a, $00, $04, $82, $10, $00, $60
off_smb2_data3_sweep_mod_data2:
    .byte $80, $02, $80, $00, $00, $60

tbl_smb2_data3_music_note_lengths:
    .byte $24, $12, $0d, $09, $1b, $28, $36, $12
    .byte $24, $12, $0d, $09, $1b, $28, $36, $6c
