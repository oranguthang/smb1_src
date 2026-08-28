; ANN NSMDATA2 AREA STREAMS

; Each label preserves the semantic source boundary inside the private asset
off_ann_supplemental_area_castle_4_smb2:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $000, $075

off_ann_supplemental_area_castle_2_smb2:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $075, $08d

off_ann_supplemental_area_castle_5:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $102, $08b

off_ann_supplemental_area_castle_8_smb2:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $18d, $0d3

off_ann_supplemental_area_overworld_2:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $260, $06d

off_ann_supplemental_area_overworld_4:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $2cd, $091

off_ann_supplemental_area_overworld_7_vs:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $35e, $049

off_ann_supplemental_area_overworld_8_vs:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $3a7, $06d

off_ann_supplemental_area_overworld_11:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $414, $041

off_ann_supplemental_area_overworld_26:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $455, $015

off_ann_supplemental_area_overworld_14:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $46a, $067

off_ann_supplemental_area_overworld_15:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $4d1, $075

off_ann_supplemental_area_overworld_17:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $546, $095

off_ann_supplemental_area_overworld_18:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $5db, $077

off_ann_supplemental_area_overworld_19:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $652, $07d

off_ann_supplemental_area_overworld_20:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $6cf, $061

off_ann_supplemental_area_overworld_27:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $730, $02b

off_ann_supplemental_area_underground_4:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $75b, $059

off_ann_supplemental_area_water_1:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $7b4, $041

off_ann_supplemental_area_water_2_vs:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $7f5, $0c9

off_ann_supplemental_area_water_4_smb2:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_course_area_streams.bin", $8be, $019

.assert * - off_ann_supplemental_area_castle_4_smb2 = $8d7, error, "ANN DATA2 area streams must be 2263 bytes"
