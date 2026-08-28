; Profile-specific music streams, note tables, and envelope data

.if con_revision_profile = con_revision_profile_vs
    .define con_music_data_asset "../../assets/generated/platforms/vs_smb/source/vs_music_data.bin"
con_music_common_offset = $048
con_music_victory_offset = $558
con_music_victory_size = $035
con_music_note_periods_offset = $5d7
con_music_note_lengths_offset = $63d
con_music_note_lengths_size = $038
con_music_water_envelope_offset = $675
con_music_bowser_envelope_offset = $69d
con_music_brick_envelope_offset = $6bd
con_music_brick_envelope_size = $014
.elseif con_revision_profile = con_revision_profile_ann
    .define con_music_data_asset "../../assets/generated/platforms/ann_fds/source/ann_music_data.bin"
con_music_common_offset = $000
con_music_victory_offset = $510
con_music_victory_size = $000
con_music_note_periods_offset = $510
con_music_note_lengths_offset = $576
con_music_note_lengths_size = $030
con_music_castle_clear_envelope_offset = $5a6
con_music_area_envelope_offset = $5aa
con_music_water_envelope_offset = $5b2
con_music_bowser_envelope_offset = $5da
con_music_brick_envelope_offset = $5fa
con_music_brick_envelope_size = $010
.elseif con_revision_profile = con_revision_profile_pal
    .define con_music_data_asset "../../assets/generated/revisions/pal/source/pal_music_data.bin"
con_music_common_offset = $000
con_music_victory_offset = $510
con_music_victory_size = $037
con_music_note_periods_offset = $547
con_music_note_lengths_offset = $5ad
con_music_note_lengths_size = $030
con_music_castle_clear_envelope_offset = $5dd
con_music_area_envelope_offset = $5e1
con_music_water_envelope_offset = $5e9
con_music_bowser_envelope_offset = $611
con_music_brick_envelope_offset = $631
con_music_brick_envelope_size = $010
.else
    .define con_music_data_asset "../../assets/generated/source/base_music_data.bin"
con_music_common_offset = $000
con_music_victory_offset = $510
con_music_victory_size = $038
con_music_note_periods_offset = $548
con_music_note_lengths_offset = $5ae
con_music_note_lengths_size = $030
con_music_castle_clear_envelope_offset = $5de
con_music_area_envelope_offset = $5e2
con_music_water_envelope_offset = $5ea
con_music_bowser_envelope_offset = $612
con_music_brick_envelope_offset = $632
con_music_brick_envelope_size = $010
.endif

.if con_revision_profile = con_revision_profile_vs
off_music_stream_vs_star_a:
    .incbin con_music_data_asset, $000, $00b

off_music_stream_vs_star_b:
off_music_stream_vs_star_c:
    .incbin con_music_data_asset, $00b, $018

off_music_stream_vs_star_d:
    .incbin con_music_data_asset, $023, $025
.endif

off_music_stream_star_cloud:
    .incbin con_music_data_asset, con_music_common_offset + $000, $049

off_music_stream_ground_part_1:
    .incbin con_music_data_asset, con_music_common_offset + $049, $01b

off_music_stream_silence:
    .incbin con_music_data_asset, con_music_common_offset + $064, $02d

off_music_stream_ground_part_2_a:
    .incbin con_music_data_asset, con_music_common_offset + $091, $02c

off_music_stream_ground_part_2_b:
    .incbin con_music_data_asset, con_music_common_offset + $0bd, $028

off_music_stream_ground_part_2_c:
    .incbin con_music_data_asset, con_music_common_offset + $0e5, $025

off_music_stream_ground_part_3_a:
    .incbin con_music_data_asset, con_music_common_offset + $10a, $019

off_music_stream_ground_part_3_b:
    .incbin con_music_data_asset, con_music_common_offset + $123, $01e

off_music_stream_ground_lead_in:
    .incbin con_music_data_asset, con_music_common_offset + $141, $02c

off_music_stream_ground_part_4_a:
    .incbin con_music_data_asset, con_music_common_offset + $16d, $026

off_music_stream_ground_part_4_b:
    .incbin con_music_data_asset, con_music_common_offset + $193, $027

off_music_stream_death:
    .incbin con_music_data_asset, con_music_common_offset + $1ba, $002

off_music_stream_ground_part_4_c:
    .incbin con_music_data_asset, con_music_common_offset + $1bc, $030

off_music_stream_castle:
    .incbin con_music_data_asset, con_music_common_offset + $1ec, $0a1

off_music_stream_game_over:
    .incbin con_music_data_asset, con_music_common_offset + $28d, $02d

off_music_stream_time_running_out:
    .incbin con_music_data_asset, con_music_common_offset + $2ba, $03e

off_music_stream_end_of_level:
    .incbin con_music_data_asset, con_music_common_offset + $2f8, $014

off_music_stream_unused:
    .incbin con_music_data_asset, con_music_common_offset + $30c, $04d

off_music_stream_underground:
    .incbin con_music_data_asset, con_music_common_offset + $359, $041

off_music_stream_water:
    .incbin con_music_data_asset, con_music_common_offset + $39a, $0ff

off_music_stream_castle_clear:
    .incbin con_music_data_asset, con_music_common_offset + $499, $077

off_music_stream_victory:
    .incbin con_music_data_asset, con_music_victory_offset, con_music_victory_size

.if con_revision_profile = con_revision_profile_vs
off_music_stream_vs_game_over:
    .incbin con_music_data_asset, $58d, $04a
.endif

tbl_music_note_periods:
    .incbin con_music_data_asset, con_music_note_periods_offset, $066

tbl_music_note_lengths:
    .incbin con_music_data_asset, con_music_note_lengths_offset, con_music_note_lengths_size

.if con_revision_profile <> con_revision_profile_vs
tbl_castle_clear_music_envelope:
    .incbin con_music_data_asset, con_music_castle_clear_envelope_offset, $004

tbl_area_music_envelope_values:
    .incbin con_music_data_asset, con_music_area_envelope_offset, $008
.endif

tbl_water_and_event_music_envelope_values:
    .incbin con_music_data_asset, con_music_water_envelope_offset, $028

tbl_bowser_flame_volume_envelope:
    .incbin con_music_data_asset, con_music_bowser_envelope_offset, $020

tbl_brick_shatter_volume_envelope:
    .incbin con_music_data_asset, con_music_brick_envelope_offset, con_music_brick_envelope_size
