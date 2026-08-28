; ANN NSMDATA4 AREA STREAMS

; Each label preserves the semantic source boundary inside the private asset
off_ann_extended_area_castle_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $000, $073

off_ann_extended_area_castle_2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $073, $07d

off_ann_extended_area_castle_3:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $0f0, $093

off_ann_extended_area_castle_4:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $183, $08f

off_ann_extended_area_overworld_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $212, $089

off_ann_extended_area_overworld_2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $29b, $053

off_ann_extended_area_overworld_12_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $2ee, $08b

off_ann_extended_area_overworld_7_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $379, $063

off_ann_extended_area_overworld_5:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $3dc, $073

off_ann_extended_area_overworld_6:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $44f, $05b

off_ann_extended_area_overworld_7:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $4aa, $077

off_ann_extended_area_overworld_19_smb2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $521, $06f

off_ann_extended_area_overworld_9:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $590, $04d

off_ann_extended_area_overworld_10:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $5dd, $06f

off_ann_extended_area_overworld_11:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $64c, $023

off_ann_extended_area_overworld_12:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $66f, $01d

off_ann_extended_area_underground_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $68c, $075

off_ann_extended_area_underground_2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $701, $05f

off_ann_extended_area_water_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/extended_course_area_streams.bin", $760, $079

.assert * - off_ann_extended_area_castle_1 = $7d9, error, "ANN DATA4 area streams must be 2009 bytes"
