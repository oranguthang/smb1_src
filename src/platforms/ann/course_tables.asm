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
    .addr $c62c  ; Castle 5
    .addr $c641  ; Lost Levels castle 8
    .addr $c5d0  ; Lost Levels castle 4
    .addr $c605  ; Lost Levels castle 2
    .addr off_ann_enemy_overworld_1  ; Overworld 1
    .addr $c681  ; Overworld 2
    .addr off_ann_enemy_overworld_3  ; Overworld 3
    .addr $c69e  ; Overworld 4
    .addr off_ann_enemy_overworld_5  ; Overworld 5
    .addr off_ann_enemy_overworld_6  ; Overworld 6
    .addr off_ann_enemy_overworld_7  ; Overworld 7
    .addr off_ann_enemy_overworld_8  ; Overworld 8
    .addr off_ann_enemy_overworld_9  ; Overworld 9
    .addr off_ann_empty_enemy_stream  ; Overworld 10
    .addr $c705  ; Overworld 11
    .addr off_ann_enemy_overworld_12  ; Overworld 12
    .addr off_ann_enemy_overworld_13  ; Overworld 13
    .addr $c72f  ; Overworld 14
    .addr $c752  ; Overworld 15
    .addr off_ann_enemy_overworld_16  ; Overworld 16
    .addr $c75b  ; Overworld 17
    .addr $c795  ; Overworld 18
    .addr $c7c0  ; Overworld 19
    .addr $c7f0  ; Overworld 20
    .addr off_ann_enemy_overworld_21  ; Overworld 21
    .addr off_ann_enemy_overworld_22  ; Overworld 22
    .addr $c6c5  ; Vs. overworld 7
    .addr $c6e8  ; Vs. overworld 8
    .addr off_ann_empty_enemy_stream  ; ANN overworld 10
    .addr $c729  ; ANN overworld 26
    .addr $c80c  ; ANN overworld 27
    .addr off_ann_enemy_overworld_22_end  ; Overworld 22 ending
    .addr off_ann_enemy_underground_1  ; Underground 1
    .addr off_ann_enemy_underground_2  ; Underground 2
    .addr off_ann_enemy_underground_3  ; Underground 3
    .addr $c812  ; ANN underground 4
    .addr $c82b  ; Water 1
    .addr off_ann_enemy_water_2  ; Water 2
    .addr $c86a  ; Lost Levels water 4
    .addr $c83c  ; Vs. water 2
    .addr off_ann_empty_enemy_stream  ; Empty water course

tbl_ann_course_area_pages:
    .byte $28, $08, $24, $00

tbl_ann_course_area_addresses:
    .addr off_ann_area_castle_1  ; Castle 1
    .addr off_ann_area_castle_2  ; Castle 2
    .addr off_ann_area_castle_3  ; Castle 3
    .addr off_ann_area_castle_4  ; Castle 4
    .addr $c97a  ; Castle 5
    .addr $ca05  ; Lost Levels castle 8
    .addr $c878  ; Lost Levels castle 4
    .addr $c8ed  ; Lost Levels castle 2
    .addr off_ann_area_overworld_1  ; Overworld 1
    .addr $cad8  ; Overworld 2
    .addr off_ann_area_overworld_3  ; Overworld 3
    .addr $cb45  ; Overworld 4
    .addr off_ann_area_overworld_5  ; Overworld 5
    .addr off_ann_area_overworld_6  ; Overworld 6
    .addr off_ann_area_overworld_7  ; Overworld 7
    .addr off_ann_area_overworld_8  ; Overworld 8
    .addr off_ann_area_overworld_9  ; Overworld 9
    .addr off_ann_course_10_area_data  ; Overworld 10
    .addr $cc8c  ; Overworld 11
    .addr off_ann_area_overworld_12  ; Overworld 12
    .addr off_ann_area_overworld_13  ; Overworld 13
    .addr $cce2  ; Overworld 14
    .addr $cd49  ; Overworld 15
    .addr off_ann_area_overworld_16  ; Overworld 16
    .addr $cdbe  ; Overworld 17
    .addr $ce53  ; Overworld 18
    .addr $ceca  ; Overworld 19
    .addr $cf47  ; Overworld 20
    .addr off_ann_area_overworld_21  ; Overworld 21
    .addr off_ann_area_overworld_22  ; Overworld 22
    .addr $cbd6  ; Vs. overworld 7
    .addr $cc1f  ; Vs. overworld 8
    .addr off_ann_course_28_area_data  ; Lost Levels overworld 28
    .addr $cccd  ; ANN overworld 26
    .addr $cfa8  ; ANN overworld 27
    .addr off_ann_area_overworld_10_b  ; Alternate overworld 10
    .addr off_ann_area_underground_1  ; Underground 1
    .addr off_ann_area_underground_2  ; Underground 2
    .addr off_ann_area_underground_3  ; Underground 3
    .addr $cfd3  ; ANN underground 4
    .addr $d02c  ; Water 1
    .addr off_ann_area_water_2  ; Water 2
    .addr $d136  ; Lost Levels water 4
    .addr $d06d  ; Vs. water 2
    .addr off_ann_course_28_area_data_end  ; Empty water course
