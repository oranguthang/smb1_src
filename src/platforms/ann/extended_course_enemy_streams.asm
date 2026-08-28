; ANN NSMDATA4 ENEMY STREAMS

; Each label preserves the semantic source boundary inside the private asset
off_ann_extended_enemy_castle_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $000, $025

off_ann_extended_enemy_castle_2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $025, $027

off_ann_extended_enemy_castle_3:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $04c, $03f

off_ann_extended_enemy_castle_4:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $08b, $02f

off_ann_extended_enemy_overworld_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $0ba, $03b

off_ann_extended_enemy_overworld_2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $0f5, $013

off_ann_extended_enemy_overworld_12_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $108, $031

off_ann_extended_enemy_overworld_7_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $139, $025

off_ann_extended_enemy_overworld_5:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $15e, $023

off_ann_extended_enemy_overworld_6:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $181, $01f

off_ann_extended_enemy_overworld_7:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $1a0, $019

off_ann_extended_enemy_overworld_19_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $1b9, $029

off_ann_extended_enemy_overworld_9:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $1e2, $021

off_ann_extended_enemy_overworld_10:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $203, $017

off_ann_extended_enemy_overworld_11:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $21a, $010

off_ann_extended_enemy_overworld_12:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $22a, $00f

off_ann_extended_enemy_underground_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $239, $01a

off_ann_extended_enemy_underground_2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $253, $017

off_ann_extended_enemy_water_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_enemy_streams.bin", $26a, $024

.assert * - off_ann_extended_enemy_castle_1 = $28e, error, "ANN DATA4 enemy streams must be 654 bytes"
