; Map ANN worlds and area types to enemy and scenery streams

tbl_ann_course_world_offsets:
    .byte $00, $05, $0a, $0e, $13, $17, $1b, $20

tbl_ann_course_area_offsets:
    .byte $25, $3b, $c0, $26, $60  ; World 1
    .byte $28, $29, $01, $27, $62  ; World 2
    .byte $24, $35, $20, $63  ; World 3
    .byte $22, $29, $41, $2c, $61  ; World 4
    .byte $2a, $31, $36, $67  ; World 5
    .byte $2e, $23, $2d, $66  ; World 6
    .byte $33, $29, $03, $37, $64  ; World 7
    .byte $30, $32, $21, $65  ; World 8

tbl_ann_course_loopback_offsets:
    .byte $12, $36, $0e, $0e, $0e, $32, $32, $32, $0c, $54

tbl_ann_course_enemy_pages:
    .byte $28, $08, $24, $00

tbl_ann_course_enemy_addresses:
    .addr off_ann_enemy_castle_1  ; Castle 1
    .addr off_ann_enemy_castle_2  ; Castle 2
    .addr off_ann_enemy_castle_3  ; Castle 3
    .addr off_ann_enemy_castle_4  ; Castle 4
    .addr off_ann_supplemental_enemy_castle_5  ; Castle 5
    .addr off_ann_supplemental_enemy_castle_8_smb2  ; Lost Levels castle 8
    .addr off_ann_supplemental_enemy_castle_4_smb2  ; Lost Levels castle 4
    .addr off_ann_supplemental_enemy_castle_2_smb2  ; Lost Levels castle 2
    .addr off_ann_enemy_overworld_1  ; Overworld 1
    .addr off_ann_supplemental_enemy_overworld_2  ; Overworld 2
    .addr off_ann_enemy_overworld_3  ; Overworld 3
    .addr off_ann_supplemental_enemy_overworld_4  ; Overworld 4
    .addr off_ann_enemy_overworld_5  ; Overworld 5
    .addr off_ann_enemy_overworld_6  ; Overworld 6
    .addr off_ann_enemy_overworld_7  ; Overworld 7
    .addr off_ann_enemy_overworld_8  ; Overworld 8
    .addr off_ann_enemy_overworld_9  ; Overworld 9
    .addr off_ann_empty_enemy_stream  ; Overworld 10
    .addr off_ann_supplemental_enemy_overworld_11  ; Overworld 11
    .addr off_ann_enemy_overworld_12  ; Overworld 12
    .addr off_ann_enemy_overworld_13  ; Overworld 13
    .addr off_ann_supplemental_enemy_overworld_14  ; Overworld 14
    .addr off_ann_supplemental_enemy_overworld_15  ; Overworld 15
    .addr off_ann_enemy_overworld_16  ; Overworld 16
    .addr off_ann_supplemental_enemy_overworld_17  ; Overworld 17
    .addr off_ann_supplemental_enemy_overworld_18  ; Overworld 18
    .addr off_ann_supplemental_enemy_overworld_19  ; Overworld 19
    .addr off_ann_supplemental_enemy_overworld_20  ; Overworld 20
    .addr off_ann_enemy_overworld_21  ; Overworld 21
    .addr off_ann_enemy_overworld_22  ; Overworld 22
    .addr off_ann_supplemental_enemy_overworld_7_vs  ; Vs. overworld 7
    .addr off_ann_supplemental_enemy_overworld_8_vs  ; Vs. overworld 8
    .addr off_ann_empty_enemy_stream  ; ANN overworld 10
    .addr off_ann_supplemental_enemy_overworld_26  ; ANN overworld 26
    .addr off_ann_supplemental_enemy_overworld_27  ; ANN overworld 27
    .addr off_ann_enemy_overworld_22_end  ; Overworld 22 ending
    .addr off_ann_enemy_underground_1  ; Underground 1
    .addr off_ann_enemy_underground_2  ; Underground 2
    .addr off_ann_enemy_underground_3  ; Underground 3
    .addr off_ann_supplemental_enemy_underground_4  ; ANN underground 4
    .addr off_ann_supplemental_enemy_water_1  ; Water 1
    .addr off_ann_enemy_water_2  ; Water 2
    .addr off_ann_supplemental_enemy_water_4_smb2  ; Lost Levels water 4
    .addr off_ann_supplemental_enemy_water_2_vs  ; Vs. water 2
    .addr off_ann_empty_enemy_stream  ; Empty water course

tbl_ann_course_area_pages:
    .byte $28, $08, $24, $00

tbl_ann_course_area_addresses:
    .addr off_ann_area_castle_1  ; Castle 1
    .addr off_ann_area_castle_2  ; Castle 2
    .addr off_ann_area_castle_3  ; Castle 3
    .addr off_ann_area_castle_4  ; Castle 4
    .addr off_ann_supplemental_area_castle_5  ; Castle 5
    .addr off_ann_supplemental_area_castle_8_smb2  ; Lost Levels castle 8
    .addr off_ann_supplemental_area_castle_4_smb2  ; Lost Levels castle 4
    .addr off_ann_supplemental_area_castle_2_smb2  ; Lost Levels castle 2
    .addr off_ann_area_overworld_1  ; Overworld 1
    .addr off_ann_supplemental_area_overworld_2  ; Overworld 2
    .addr off_ann_area_overworld_3  ; Overworld 3
    .addr off_ann_supplemental_area_overworld_4  ; Overworld 4
    .addr off_ann_area_overworld_5  ; Overworld 5
    .addr off_ann_area_overworld_6  ; Overworld 6
    .addr off_ann_area_overworld_7  ; Overworld 7
    .addr off_ann_area_overworld_8  ; Overworld 8
    .addr off_ann_area_overworld_9  ; Overworld 9
    .addr off_ann_course_10_area_data  ; Overworld 10
    .addr off_ann_supplemental_area_overworld_11  ; Overworld 11
    .addr off_ann_area_overworld_12  ; Overworld 12
    .addr off_ann_area_overworld_13  ; Overworld 13
    .addr off_ann_supplemental_area_overworld_14  ; Overworld 14
    .addr off_ann_supplemental_area_overworld_15  ; Overworld 15
    .addr off_ann_area_overworld_16  ; Overworld 16
    .addr off_ann_supplemental_area_overworld_17  ; Overworld 17
    .addr off_ann_supplemental_area_overworld_18  ; Overworld 18
    .addr off_ann_supplemental_area_overworld_19  ; Overworld 19
    .addr off_ann_supplemental_area_overworld_20  ; Overworld 20
    .addr off_ann_area_overworld_21  ; Overworld 21
    .addr off_ann_area_overworld_22  ; Overworld 22
    .addr off_ann_supplemental_area_overworld_7_vs  ; Vs. overworld 7
    .addr off_ann_supplemental_area_overworld_8_vs  ; Vs. overworld 8
    .addr off_ann_course_28_area_data  ; Lost Levels overworld 28
    .addr off_ann_supplemental_area_overworld_26  ; ANN overworld 26
    .addr off_ann_supplemental_area_overworld_27  ; ANN overworld 27
    .addr off_ann_area_overworld_10_b  ; Alternate overworld 10
    .addr off_ann_area_underground_1  ; Underground 1
    .addr off_ann_area_underground_2  ; Underground 2
    .addr off_ann_area_underground_3  ; Underground 3
    .addr off_ann_supplemental_area_underground_4  ; ANN underground 4
    .addr off_ann_supplemental_area_water_1  ; Water 1
    .addr off_ann_area_water_2  ; Water 2
    .addr off_ann_supplemental_area_water_4_smb2  ; Lost Levels water 4
    .addr off_ann_supplemental_area_water_2_vs  ; Vs. water 2
    .addr off_ann_course_28_area_data_end  ; Empty water course
