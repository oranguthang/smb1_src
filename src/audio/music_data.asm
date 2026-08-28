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

.include "audio/music_streams.asm"
