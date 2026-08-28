; --------------------------------

; music header offsets

.if con_revision_profile = con_revision_profile_vs
con_music_length_offset_d = $20
con_music_length_offset_e = $28
con_music_length_offset_victory = $18

tbl_castle_clear_music_envelope = *
    .byte $98, $99, $9a, $9b

tbl_area_music_envelope_values = *
    .byte $90, $94, $94, $95, $95, $96, $97, $97, $98
.else
con_music_length_offset_d = $18
con_music_length_offset_e = $20
con_music_length_offset_victory = $10
.endif

tbl_music_header_offsets:
    .byte off_music_header_death-con_music_header_data_base  ; event music
    .byte off_music_header_game_over-con_music_header_data_base
    .byte off_music_header_victory-con_music_header_data_base
    .byte off_music_header_castle_clear-con_music_header_data_base
.if con_revision_profile = con_revision_profile_vs
    .byte off_music_header_vs_game_over-con_music_header_data_base
.else
    .byte off_music_header_game_over-con_music_header_data_base
.endif
    .byte off_music_header_end_of_level-con_music_header_data_base
    .byte off_music_header_time_running_out-con_music_header_data_base
    .byte off_music_header_silence-con_music_header_data_base

    .byte off_music_header_ground_part_1-con_music_header_data_base  ; area music
    .byte off_music_header_water-con_music_header_data_base
    .byte off_music_header_underground-con_music_header_data_base
    .byte off_music_header_castle-con_music_header_data_base
    .byte off_music_header_star_cloud-con_music_header_data_base
    .byte off_music_header_ground_lead_in-con_music_header_data_base
    .byte off_music_header_star_cloud-con_music_header_data_base
    .byte off_music_header_silence-con_music_header_data_base

con_ground_music_header_start = * - con_music_header_data_base
    .byte off_music_header_ground_lead_in-con_music_header_data_base  ; ground level music layout
con_ground_music_header_loop = * - con_music_header_data_base
    .byte off_music_header_ground_part_1-con_music_header_data_base, off_music_header_ground_part_1-con_music_header_data_base
    .byte off_music_header_ground_part_2_a-con_music_header_data_base, off_music_header_ground_part_2_b-con_music_header_data_base, off_music_header_ground_part_2_a-con_music_header_data_base, off_music_header_ground_part_2_c-con_music_header_data_base
    .byte off_music_header_ground_part_2_a-con_music_header_data_base, off_music_header_ground_part_2_b-con_music_header_data_base, off_music_header_ground_part_2_a-con_music_header_data_base, off_music_header_ground_part_2_c-con_music_header_data_base
    .byte off_music_header_ground_part_3_a-con_music_header_data_base, off_music_header_ground_part_3_b-con_music_header_data_base, off_music_header_ground_part_3_a-con_music_header_data_base, off_music_header_ground_lead_in-con_music_header_data_base
    .byte off_music_header_ground_part_1-con_music_header_data_base, off_music_header_ground_part_1-con_music_header_data_base
    .byte off_music_header_ground_part_4_a-con_music_header_data_base, off_music_header_ground_part_4_b-con_music_header_data_base, off_music_header_ground_part_4_a-con_music_header_data_base, off_music_header_ground_part_4_c-con_music_header_data_base
    .byte off_music_header_ground_part_4_a-con_music_header_data_base, off_music_header_ground_part_4_b-con_music_header_data_base, off_music_header_ground_part_4_a-con_music_header_data_base, off_music_header_ground_part_4_c-con_music_header_data_base
    .byte off_music_header_ground_part_3_a-con_music_header_data_base, off_music_header_ground_part_3_b-con_music_header_data_base, off_music_header_ground_part_3_a-con_music_header_data_base, off_music_header_ground_lead_in-con_music_header_data_base
    .byte off_music_header_ground_part_4_a-con_music_header_data_base, off_music_header_ground_part_4_b-con_music_header_data_base, off_music_header_ground_part_4_a-con_music_header_data_base, off_music_header_ground_part_4_c-con_music_header_data_base
con_ground_music_header_loop_end = * - con_music_header_data_base

.if con_revision_profile = con_revision_profile_vs
    .byte off_music_header_victory-con_music_header_data_base, off_music_header_victory-con_music_header_data_base
    .byte off_music_header_vs_game_over-con_music_header_data_base
    .byte off_music_header_victory-con_music_header_data_base, off_music_header_victory-con_music_header_data_base

con_vs_star_music_header_loop = * - con_music_header_data_base
    .byte off_music_header_vs_star_a-con_music_header_data_base
    .byte off_music_header_vs_star_b-con_music_header_data_base
    .byte off_music_header_vs_star_d-con_music_header_data_base
    .byte off_music_header_vs_star_c-con_music_header_data_base
con_vs_star_music_header_loop_end = * - con_music_header_data_base
.endif

; music headers
; header format is as follows:
; 1 byte - length byte offset
; 2 bytes -  music data address
; 1 byte - triangle data offset
; 1 byte - square 1 data offset
; 1 byte - noise data offset (not used by secondary music)

.if con_revision_profile = con_revision_profile_vs
off_music_header_vs_star_a:
    .byte con_music_length_offset_d, <off_music_stream_vs_star_a, >off_music_stream_vs_star_a, $38, $07, $88
off_music_header_vs_star_b:
    .byte con_music_length_offset_d, <off_music_stream_vs_star_b, >off_music_stream_vs_star_b, $33, $06, $7d
off_music_header_vs_star_c:
    .byte con_music_length_offset_d, <off_music_stream_vs_star_c, >off_music_stream_vs_star_c, $33, $23, $7d
off_music_header_vs_star_d:
    .byte con_music_length_offset_d, <off_music_stream_vs_star_d, >off_music_stream_vs_star_d, $1f, $07, $65
.endif

off_music_header_time_running_out:
    .byte $08, <off_music_stream_time_running_out, >off_music_stream_time_running_out, $27, $18
off_music_header_star_cloud:
    .byte con_music_length_offset_e, <off_music_stream_star_cloud, >off_music_stream_star_cloud, $2e, $1a, $40
off_music_header_end_of_level:
    .byte con_music_length_offset_e, <off_music_stream_end_of_level, >off_music_stream_end_of_level, $3d, $21
unused_music_header_residual:
.if con_revision_profile = con_revision_profile_vs
    .byte con_music_length_offset_e, $7d, $fc, $3f, $1d
.else
    .byte $20, <off_music_stream_unused, >off_music_stream_unused, $3f, $1d
.endif
off_music_header_underground:
    .byte con_music_length_offset_d, <off_music_stream_underground, >off_music_stream_underground, $00, $00
off_music_header_silence:
    .byte $08, <off_music_stream_silence, >off_music_stream_silence, $00
off_music_header_castle:
    .byte $00, <off_music_stream_castle, >off_music_stream_castle, $93, $62
.if con_revision_profile = con_revision_profile_ann
off_music_header_victory = off_music_header_game_over
.else
off_music_header_victory:
    .byte con_music_length_offset_victory, <off_music_stream_victory, >off_music_stream_victory, $24, $14
.endif
.if con_revision_profile = con_revision_profile_vs
off_music_header_vs_game_over:
    .byte $18, <off_music_stream_vs_game_over, >off_music_stream_vs_game_over, $34, $23
.endif
off_music_header_game_over:
    .byte con_music_length_offset_d, <off_music_stream_game_over, >off_music_stream_game_over, $1e, $14
off_music_header_water:
    .byte $08, <off_music_stream_water, >off_music_stream_water, $a0, $70, $68
off_music_header_castle_clear:
    .byte $08, <off_music_stream_castle_clear, >off_music_stream_castle_clear, $4c, $24
off_music_header_ground_part_1:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_1, >off_music_stream_ground_part_1, $2d, $1c, $b8
off_music_header_ground_part_2_a:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_2_a, >off_music_stream_ground_part_2_a, $20, $12, $70
off_music_header_ground_part_2_b:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_2_b, >off_music_stream_ground_part_2_b, $1b, $10, $44
off_music_header_ground_part_2_c:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_2_c, >off_music_stream_ground_part_2_c, $11, $0a, $1c
off_music_header_ground_part_3_a:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_3_a, >off_music_stream_ground_part_3_a, $2d, $10, $58
off_music_header_ground_part_3_b:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_3_b, >off_music_stream_ground_part_3_b, $14, $0d, $3f
off_music_header_ground_lead_in:
    .byte con_music_length_offset_d, <off_music_stream_ground_lead_in, >off_music_stream_ground_lead_in, $15, $0d, $21
off_music_header_ground_part_4_a:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_4_a, >off_music_stream_ground_part_4_a, $18, $10, $7a
off_music_header_ground_part_4_b:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_4_b, >off_music_stream_ground_part_4_b, $19, $0f, $54
off_music_header_ground_part_4_c:
    .byte con_music_length_offset_d, <off_music_stream_ground_part_4_c, >off_music_stream_ground_part_4_c, $1e, $12, $2b
off_music_header_death:
    .byte con_music_length_offset_d, <off_music_stream_death, >off_music_stream_death, $1e, $0f, $2d

; --------------------------------

; MUSIC DATA
; square 2/triangle format
; d7 - length byte flag (0-note, 1-length)
; if d7 is set to 0 and d6-d0 is nonzero:
; d6-d0 - note offset in frequency look-up table (must be even)
; if d7 is set to 1:
; d6-d3 - unused
; d2-d0 - length offset in length look-up table
; value of $00 in square 2 data is used as null terminator, affects all sound channels
; value of $00 in triangle data causes routine to skip note

; square 1 format
; d7-d6, d0 - length offset in length look-up table (bit order is d0,d7,d6)
; d5-d1 - note offset in frequency look-up table
; value of $00 in square 1 data is flag alternate control reg data to be loaded

; noise format
; d7-d6, d0 - length offset in length look-up table (bit order is d0,d7,d6)
; d5-d4 - beat type (0 - rest, 1 - short, 2 - strong, 3 - long)
; d3-d1 - unused
; value of $00 in noise data is used as null terminator, affects only noise

; all music data is organized into sections (unless otherwise stated):
; square 2, square 1, triangle, noise

.if con_revision_profile = con_revision_profile_vs
off_music_stream_vs_star_a:
    .byte $85, $1c, $14, $84, $0c, $14, $00
    .byte $6d, $63, $1d, $27

off_music_stream_vs_star_b:
off_music_stream_vs_star_c:
    .byte $86, $04, $04, $80, $04, $00
    .byte $00, $44, $62, $62, $62, $62, $62, $23, $44
    .byte $54, $54, $54, $54, $54, $55, $8c, $0d, $07

off_music_stream_vs_star_d:
    .byte $85, $18, $14, $84, $12, $0c, $00
    .byte $6b, $67, $23, $1d

    .byte $00, $03, $03, $80, $01, $03, $82, $03, $80, $80
    .byte $85, $22, $1c, $84, $14, $1e
    .byte $80, $04, $04, $04
    .byte $85, $22, $1e, $84, $1c, $14
.endif

off_music_stream_star_cloud:
    .byte $84, $2c, $2c, $2c, $82, $04, $2c, $04, $85, $2c, $84, $2c, $2c
    .byte $2a, $2a, $2a, $82, $04, $2a, $04, $85, $2a, $84, $2a, $2a, $00

    .byte $1f, $1f, $1f, $98, $1f, $1f, $98, $9e, $98, $1f
    .byte $1d, $1d, $1d, $94, $1d, $1d, $94, $9c, $94, $1d

    .byte $86, $18, $85, $26, $30, $84, $04, $26, $30
    .byte $86, $14, $85, $22, $2c, $84, $04, $22, $2c

    .byte $21, $d0, $c4, $d0, $31, $d0, $c4, $d0, $00

off_music_stream_ground_part_1:
    .byte $85, $2c, $22, $1c, $84, $26, $2a, $82, $28, $26, $04
    .byte $87, $22, $34, $3a, $82, $40, $04, $36, $84, $3a, $34
    .byte $82, $2c, $30, $85, $2a

off_music_stream_silence:
    .byte $00

    .byte $5d, $55, $4d, $15, $19, $96, $15, $d5, $e3, $eb
    .byte $2d, $a6, $2b, $27, $9c, $9e, $59

    .byte $85, $22, $1c, $14, $84, $1e, $22, $82, $20, $1e, $04, $87
    .byte $1c, $2c, $34, $82, $36, $04, $30, $34, $04, $2c, $04, $26
    .byte $2a, $85, $22

off_music_stream_ground_part_2_a:
    .byte $84, $04, $82, $3a, $38, $36, $32, $04, $34
    .byte $04, $24, $26, $2c, $04, $26, $2c, $30, $00

    .byte $05, $b4, $b2, $b0, $2b, $ac, $84
    .byte $9c, $9e, $a2, $84, $94, $9c, $9e

    .byte $85, $14, $22, $84, $2c, $85, $1e
    .byte $82, $2c, $84, $2c, $1e

off_music_stream_ground_part_2_b:
    .byte $84, $04, $82, $3a, $38, $36, $32, $04, $34
    .byte $04, $64, $04, $64, $86, $64, $00

    .byte $05, $b4, $b2, $b0, $2b, $ac, $84
    .byte $37, $b6, $b6, $45

    .byte $85, $14, $1c, $82, $22, $84, $2c
    .byte $4e, $82, $4e, $84, $4e, $22

off_music_stream_ground_part_2_c:
    .byte $84, $04, $85, $32, $85, $30, $86, $2c, $04, $00

    .byte $05, $a4, $05, $9e, $05, $9d, $85

    .byte $84, $14, $85, $24, $28, $2c, $82
    .byte $22, $84, $22, $14

    .byte $21, $d0, $c4, $d0, $31, $d0, $c4, $d0, $00

off_music_stream_ground_part_3_a:
    .byte $82, $2c, $84, $2c, $2c, $82, $2c, $30
    .byte $04, $34, $2c, $04, $26, $86, $22, $00

    .byte $a4, $25, $25, $a4, $29, $a2, $1d, $9c, $95

off_music_stream_ground_part_3_b:
    .byte $82, $2c, $2c, $04, $2c, $04, $2c, $30, $85, $34, $04, $04, $00

    .byte $a4, $25, $25, $a4, $a8, $63, $04

; triangle data used by both sections of third part
    .byte $85, $0e, $1a, $84, $24, $85, $22, $14, $84, $0c

off_music_stream_ground_lead_in:
    .byte $82, $34, $84, $34, $34, $82, $2c, $84, $34, $86, $3a, $04, $00

    .byte $a0, $21, $21, $a0, $21, $2b, $05, $a3

    .byte $82, $18, $84, $18, $18, $82, $18, $18, $04, $86, $3a, $22

; noise data used by lead-in and third part sections
    .byte $31, $90, $31, $90, $31, $71, $31, $90, $90, $90, $00

off_music_stream_ground_part_4_a:
    .byte $82, $34, $84, $2c, $85, $22, $84, $24
    .byte $82, $26, $36, $04, $36, $86, $26, $00

    .byte $ac, $27, $5d, $1d, $9e, $2d, $ac, $9f

    .byte $85, $14, $82, $20, $84, $22, $2c
    .byte $1e, $1e, $82, $2c, $2c, $1e, $04

off_music_stream_ground_part_4_b:
    .byte $87, $2a, $40, $40, $40, $3a, $36
    .byte $82, $34, $2c, $04, $26, $86, $22, $00

    .byte $e3, $f7, $f7, $f7, $f5, $f1, $ac, $27, $9e, $9d

    .byte $85, $18, $82, $1e, $84, $22, $2a
    .byte $22, $22, $82, $2c, $2c, $22, $04

off_music_stream_death:
    .byte $86, $04  ; death music share data with fourth part c of ground level music

off_music_stream_ground_part_4_c:
    .byte $82, $2a, $36, $04, $36, $87, $36, $34, $30, $86, $2c, $04, $00

    .byte $00, $68, $6a, $6c, $45  ; death music only

    .byte $a2, $31, $b0, $f1, $ed, $eb, $a2, $1d, $9c, $95

    .byte $86, $04  ; death music only

    .byte $85, $22, $82, $22, $87, $22, $26, $2a, $84, $2c, $22, $86, $14

; noise data used by fourth part sections
    .byte $51, $90, $31, $11, $00

off_music_stream_castle:
    .byte $80, $22, $28, $22, $26, $22, $24, $22, $26
    .byte $22, $28, $22, $2a, $22, $28, $22, $26
    .byte $22, $28, $22, $26, $22, $24, $22, $26
    .byte $22, $28, $22, $2a, $22, $28, $22, $26
    .byte $20, $26, $20, $24, $20, $26, $20, $28
    .byte $20, $26, $20, $28, $20, $26, $20, $24
    .byte $20, $26, $20, $24, $20, $26, $20, $28
    .byte $20, $26, $20, $28, $20, $26, $20, $24
    .byte $28, $30, $28, $32, $28, $30, $28, $2e
    .byte $28, $30, $28, $2e, $28, $2c, $28, $2e
    .byte $28, $30, $28, $32, $28, $30, $28, $2e
    .byte $28, $30, $28, $2e, $28, $2c, $28, $2e, $00

    .byte $04, $70, $6e, $6c, $6e, $70, $72, $70, $6e
    .byte $70, $6e, $6c, $6e, $70, $72, $70, $6e
    .byte $6e, $6c, $6e, $70, $6e, $70, $6e, $6c
    .byte $6e, $6c, $6e, $70, $6e, $70, $6e, $6c
    .byte $76, $78, $76, $74, $76, $74, $72, $74
    .byte $76, $78, $76, $74, $76, $74, $72, $74

    .byte $84, $1a, $83, $18, $20, $84, $1e, $83, $1c, $28
    .byte $26, $1c, $1a, $1c

off_music_stream_game_over:
    .byte $82, $2c, $04, $04, $22, $04, $04, $84, $1c, $87
    .byte $26, $2a, $26, $84, $24, $28, $24, $80, $22, $00

    .byte $9c, $05, $94, $05, $0d, $9f, $1e, $9c, $98, $9d

    .byte $82, $22, $04, $04, $1c, $04, $04, $84, $14
    .byte $86, $1e, $80, $16, $80, $14

off_music_stream_time_running_out:
    .byte $81, $1c, $30, $04, $30, $30, $04, $1e, $32, $04, $32, $32
    .byte $04, $20, $34, $04, $34, $34, $04, $36, $04, $84, $36, $00

    .byte $46, $a4, $64, $a4, $48, $a6, $66, $a6, $4a, $a8, $68, $a8
    .byte $6a, $44, $2b

    .byte $81, $2a, $42, $04, $42, $42, $04, $2c, $64, $04, $64, $64
    .byte $04, $2e, $46, $04, $46, $46, $04, $22, $04, $84, $22

off_music_stream_end_of_level:
    .byte $87, $04, $06, $0c, $14, $1c, $22, $86, $2c, $22
    .byte $87, $04, $60, $0e, $14, $1a, $24, $86, $2c, $24
off_music_stream_unused:
    .byte $87, $04, $08, $10, $18, $1e, $28, $86, $30, $30
    .byte $80, $64, $00

    .byte $cd, $d5, $dd, $e3, $ed, $f5, $bb, $b5, $cf, $d5
    .byte $db, $e5, $ed, $f3, $bd, $b3, $d1, $d9, $df, $e9
    .byte $f1, $f7, $bf, $ff, $ff, $ff, $34
    .byte $00  ; unused byte

    .byte $86, $04, $87, $14, $1c, $22, $86, $34, $84, $2c
    .byte $04, $04, $04, $87, $14, $1a, $24, $86, $32, $84
    .byte $2c, $04, $86, $04, $87, $18, $1e, $28, $86, $36
    .byte $87, $30, $30, $30, $80, $2c

; square 2 and triangle use the same data, square 1 is unused
off_music_stream_underground:
    .byte $82, $14, $2c, $62, $26, $10, $28, $80, $04
    .byte $82, $14, $2c, $62, $26, $10, $28, $80, $04
    .byte $82, $08, $1e, $5e, $18, $60, $1a, $80, $04
    .byte $82, $08, $1e, $5e, $18, $60, $1a, $86, $04
    .byte $83, $1a, $18, $16, $84, $14, $1a, $18, $0e, $0c
    .byte $16, $83, $14, $20, $1e, $1c, $28, $26, $87
    .byte $24, $1a, $12, $10, $62, $0e, $80, $04, $04
    .byte $00

; noise data directly follows square 2 here unlike in other songs
off_music_stream_water:
    .byte $82, $18, $1c, $20, $22, $26, $28
    .byte $81, $2a, $2a, $2a, $04, $2a, $04, $83, $2a, $82, $22
    .byte $86, $34, $32, $34, $81, $04, $22, $26, $2a, $2c, $30
    .byte $86, $34, $83, $32, $82, $36, $84, $34, $85, $04, $81, $22
    .byte $86, $30, $2e, $30, $81, $04, $22, $26, $2a, $2c, $2e
    .byte $86, $30, $83, $22, $82, $36, $84, $34, $85, $04, $81, $22
    .byte $86, $3a, $3a, $3a, $82, $3a, $81, $40, $82, $04, $81, $3a
    .byte $86, $36, $36, $36, $82, $36, $81, $3a, $82, $04, $81, $36
    .byte $86, $34, $82, $26, $2a, $36
    .byte $81, $34, $34, $85, $34, $81, $2a, $86, $2c, $00

    .byte $84, $90, $b0, $84, $50, $50, $b0, $00

    .byte $98, $96, $94, $92, $94, $96, $58, $58, $58, $44
    .byte $5c, $44, $9f, $a3, $a1, $a3, $85, $a3, $e0, $a6
    .byte $23, $c4, $9f, $9d, $9f, $85, $9f, $d2, $a6, $23
    .byte $c4, $b5, $b1, $af, $85, $b1, $af, $ad, $85, $95
    .byte $9e, $a2, $aa, $6a, $6a, $6b, $5e, $9d

    .byte $84, $04, $04, $82, $22, $86, $22
    .byte $82, $14, $22, $2c, $12, $22, $2a, $14, $22, $2c
    .byte $1c, $22, $2c, $14, $22, $2c, $12, $22, $2a, $14
    .byte $22, $2c, $1c, $22, $2c, $18, $22, $2a, $16, $20
    .byte $28, $18, $22, $2a, $12, $22, $2a, $18, $22, $2a
    .byte $12, $22, $2a, $14, $22, $2c, $0c, $22, $2c, $14, $22, $34, $12
    .byte $22, $30, $10, $22, $2e, $16, $22, $34, $18, $26
    .byte $36, $16, $26, $36, $14, $26, $36, $12, $22, $36
    .byte $5c, $22, $34, $0c, $22, $22, $81, $1e, $1e, $85, $1e
    .byte $81, $12, $86, $14

off_music_stream_castle_clear:
    .byte $81, $2c, $22, $1c, $2c, $22, $1c, $85, $2c, $04
    .byte $81, $2e, $24, $1e, $2e, $24, $1e, $85, $2e, $04
    .byte $81, $32, $28, $22, $32, $28, $22, $85, $32
    .byte $87, $36, $36, $36, $84, $3a, $00

    .byte $5c, $54, $4c, $5c, $54, $4c
    .byte $5c, $1c, $1c, $5c, $5c, $5c, $5c
    .byte $5e, $56, $4e, $5e, $56, $4e
    .byte $5e, $1e, $1e, $5e, $5e, $5e, $5e
    .byte $62, $5a, $50, $62, $5a, $50
    .byte $62, $22, $22, $62, $e7, $e7, $e7, $2b

    .byte $86, $14, $81, $14, $80, $14, $14, $81, $14, $14, $14, $14
    .byte $86, $16, $81, $16, $80, $16, $16, $81, $16, $16, $16, $16
    .byte $81, $28, $22, $1a, $28, $22, $1a, $28, $80, $28, $28
    .byte $81, $28, $87, $2c, $2c, $2c, $84, $30

off_music_stream_victory:
.if con_revision_profile = con_revision_profile_vs
    .byte $84, $04, $86, $0c, $84, $62, $10, $86, $12, $84, $1c, $22
    .byte $1e, $22, $26, $18, $1e, $04, $1c, $00, $e2, $e0, $e2, $9d
    .byte $1f, $21, $a3, $2d, $74, $f4, $31, $35, $37, $2b, $b1, $2d
    .byte $84, $12, $14, $04, $18, $1a, $1c, $14, $26, $22, $1e, $1c
    .byte $18, $1e, $22, $0c, $14

off_music_stream_vs_game_over:
    .byte $81, $22, $83, $22, $86, $24, $85, $18, $82, $1e, $84, $1e
    .byte $83, $04, $83, $1c, $83, $18, $84, $1c, $81, $26, $83, $26
    .byte $86, $26, $85, $1e, $82, $24, $86, $22, $84, $1e, $00, $74
    .byte $f4, $b5, $6b, $b0, $31, $c4, $ec, $ea, $2d, $76, $f6, $b7
    .byte $6d, $b0, $b5, $31, $84, $12, $1c, $20, $24, $2a, $26, $24
    .byte $26, $22, $1e, $22, $24, $1e, $22, $0c, $1e

    .byte $ff, $ff, $ff, $ff, $ff

tbl_music_note_periods = *
    .byte $00, $88, $00, $2f, $00, $00, $02, $a6, $02, $80, $02, $5c
    .byte $02, $3a, $02, $1a, $01, $df, $01, $c4, $01, $ab, $01, $93
    .byte $01, $7c, $01, $67, $01, $53, $01, $40, $01, $2e, $01, $1d
    .byte $01, $0d, $00, $fe, $00, $ef, $00, $e2, $00, $d5, $00, $c9
    .byte $00, $be, $00, $b3, $00, $a9, $00, $a0, $00, $97, $00, $8e
    .byte $00, $86, $00, $77, $00, $7e, $00, $71, $00, $54, $00, $64
    .byte $00, $5f, $00, $59, $00, $50, $00, $47, $00, $43, $00, $3b
    .byte $00, $35, $00, $2a, $00, $23, $04, $75, $03, $57, $02, $f9
    .byte $02, $cf, $01, $fc, $00, $6a

tbl_music_note_lengths = *
    .byte $05, $0a, $14, $28, $50, $1e, $3c, $02
    .byte $04, $08, $10, $20, $40, $18, $30, $0c
    .byte $03, $06, $0c, $18, $30, $12, $24, $08
    .byte $51, $12, $0d, $09, $1b, $28, $36, $12
    .byte $36, $03, $09, $06, $12, $1b, $24, $0c
    .byte $24, $02, $06, $04, $0c, $12, $18, $08
    .byte $12, $01, $03, $02, $06, $09, $0c, $04

tbl_water_and_event_music_envelope_values = *
    .byte $90, $91, $92, $92, $93, $93, $93, $94
    .byte $94, $94, $94, $94, $94, $95, $95, $95
    .byte $95, $95, $95, $96, $96, $96, $96, $96
    .byte $96, $96, $96, $96, $96, $96, $96, $96
    .byte $96, $96, $96, $96, $95, $95, $94, $93

tbl_bowser_flame_volume_envelope = *
    .byte $15, $16, $16, $17, $17, $18, $19, $19
    .byte $1a, $1a, $1c, $1d, $1d, $1e, $1e, $1f
    .byte $1f, $1f, $1f, $1e, $1d, $1c, $1e, $1f
    .byte $1f, $1e, $1d, $1c, $1a, $18, $16, $14

tbl_brick_shatter_volume_envelope = *
    .byte $15, $16, $16, $17, $17, $18, $19, $19
    .byte $1a, $1a, $1c, $1d, $1d, $1e, $1e, $1f

    .byte $ff, $ff, $ff, $ff
.else
    .if con_revision_profile = con_revision_profile_ann
; ANN has no separate victory stream
    .else
        .byte $83, $04, $84, $0c, $83, $62, $10, $84, $12
        .byte $83, $1c, $22, $1e, $22, $26, $18, $1e, $04, $1c, $00

        .byte $e3, $e1, $e3, $1d, $de, $e0, $23
        .byte $ec, $75, $74, $f0, $f4, $f6, $ea, $31, $2d

        .byte $83, $12, $14, $04, $18, $1a, $1c, $14
        .byte $26, $22, $1e, $1c, $18, $1e, $22, $0c, $14

; unused space
        .if con_revision_profile = con_revision_profile_pal
            .byte $ff, $ff
        .else
            .byte $ff, $ff, $ff
        .endif
    .endif

tbl_music_note_periods:
    .if con_revision_profile = con_revision_profile_pal
        .byte $00, $88, $00, $2b, $00, $00, $02, $72
        .byte $02, $4f, $02, $2e, $02, $0e, $01, $f1
        .byte $01, $ba, $01, $a1, $01, $8a, $01, $74
        .byte $01, $5f, $01, $4b, $01, $39, $01, $27
        .byte $01, $17, $01, $07, $00, $f8, $00, $ea
        .byte $00, $dd, $00, $d1, $00, $c5, $00, $ba
        .byte $00, $af, $00, $a5, $00, $9c, $00, $94
        .byte $00, $8b, $00, $83, $00, $7c, $00, $6e
        .byte $00, $74, $00, $68, $00, $4e, $00, $5c
        .byte $00, $58, $00, $52, $00, $4a, $00, $42
        .byte $00, $3e, $00, $36, $00, $31, $00, $27
        .byte $00, $20, $04, $1d, $03, $15, $02, $be
        .byte $02, $98, $01, $d5, $00, $62
    .else
        .byte $00, $88, $00, $2f, $00, $00
        .byte $02, $a6, $02, $80, $02, $5c, $02, $3a
        .byte $02, $1a, $01, $df, $01, $c4, $01, $ab
        .byte $01, $93, $01, $7c, $01, $67, $01, $53
        .byte $01, $40, $01, $2e, $01, $1d, $01, $0d
        .byte $00, $fe, $00, $ef, $00, $e2, $00, $d5
        .byte $00, $c9, $00, $be, $00, $b3, $00, $a9
        .byte $00, $a0, $00, $97, $00, $8e, $00, $86
        .byte $00, $77, $00, $7e, $00, $71, $00, $54
        .byte $00, $64, $00, $5f, $00, $59, $00, $50
        .byte $00, $47, $00, $43, $00, $3b, $00, $35
        .byte $00, $2a, $00, $23, $04, $75, $03, $57
        .byte $02, $f9, $02, $cf, $01, $fc, $00, $6a
    .endif

tbl_music_note_lengths:
    .if con_revision_profile = con_revision_profile_pal
        .byte $04, $08, $10, $20, $40, $18, $30, $0c
        .byte $03, $06, $0c, $18, $30, $12, $24, $08
        .byte $03, $06, $0c, $18, $30, $12, $24, $08
        .byte $24, $02, $06, $04, $0c, $12, $18, $08
        .byte $1b, $01, $05, $03, $09, $0d, $12, $06
        .byte $12, $01, $03, $02, $06, $09, $0c, $04
    .else
        .byte $05, $0a, $14, $28, $50, $1e, $3c, $02
        .byte $04, $08, $10, $20, $40, $18, $30, $0c
        .byte $03, $06, $0c, $18, $30, $12, $24, $08
        .byte $36, $03, $09, $06, $12, $1b, $24, $0c
        .byte $24, $02, $06, $04, $0c, $12, $18, $08
        .byte $12, $01, $03, $02, $06, $09, $0c, $04
    .endif

tbl_castle_clear_music_envelope:
    .byte $98, $99, $9a, $9b

tbl_area_music_envelope_values:
    .byte $90, $94, $94, $95, $95, $96, $97, $98

tbl_water_and_event_music_envelope_values:
    .byte $90, $91, $92, $92, $93, $93, $93, $94
    .byte $94, $94, $94, $94, $94, $95, $95, $95
    .byte $95, $95, $95, $96, $96, $96, $96, $96
    .byte $96, $96, $96, $96, $96, $96, $96, $96
    .byte $96, $96, $96, $96, $95, $95, $94, $93

tbl_bowser_flame_volume_envelope:
    .byte $15, $16, $16, $17, $17, $18, $19, $19
    .byte $1a, $1a, $1c, $1d, $1d, $1e, $1e, $1f
    .byte $1f, $1f, $1f, $1e, $1d, $1c, $1e, $1f
    .byte $1f, $1e, $1d, $1c, $1a, $18, $16, $14

tbl_brick_shatter_volume_envelope:
    .byte $15, $16, $16, $17, $17, $18, $19, $19
    .byte $1a, $1a, $1c, $1d, $1d, $1e, $1e, $1f
.endif
