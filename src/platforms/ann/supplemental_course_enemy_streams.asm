; ANN NSMDATA2 ENEMY STREAMS

; Each label preserves the semantic source boundary inside the private asset
off_ann_supplemental_enemy_castle_4_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $000, $035

off_ann_supplemental_enemy_castle_2_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $035, $027

off_ann_supplemental_enemy_castle_5:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $05c, $015

off_ann_supplemental_enemy_castle_8_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $071, $040

off_ann_supplemental_enemy_overworld_2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $0b1, $01d

off_ann_supplemental_enemy_overworld_4:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $0ce, $027

off_ann_supplemental_enemy_overworld_7_vs:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $0f5, $023

off_ann_supplemental_enemy_overworld_8_vs:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $118, $01d

off_ann_supplemental_enemy_overworld_11:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $135, $024

off_ann_supplemental_enemy_overworld_26:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $159, $006

off_ann_supplemental_enemy_overworld_14:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $15f, $023

off_ann_supplemental_enemy_overworld_15:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $182, $009

off_ann_supplemental_enemy_overworld_17:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $18b, $03a

off_ann_supplemental_enemy_overworld_18:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $1c5, $02b

off_ann_supplemental_enemy_overworld_19:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $1f0, $030

off_ann_supplemental_enemy_overworld_20:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $220, $01c

off_ann_supplemental_enemy_overworld_27:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $23c, $006

off_ann_supplemental_enemy_underground_4:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $242, $019

off_ann_supplemental_enemy_water_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $25b, $011

off_ann_supplemental_enemy_water_2_vs:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $26c, $02e

off_ann_supplemental_enemy_water_4_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/supplemental_course_enemy_streams.bin", $29a, $00e

.assert * - off_ann_supplemental_enemy_castle_4_smb2 = $2a8, error, "ANN DATA2 enemy streams must be 680 bytes"
