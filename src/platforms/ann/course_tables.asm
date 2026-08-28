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
    .addr $c745  ; Castle 1
    .addr $c762  ; Castle 2
    .addr $c77b  ; Castle 3
    .addr $c79e  ; Castle 4
    .addr $c62c  ; Castle 5
    .addr $c641  ; Lost Levels castle 8
    .addr $c5d0  ; Lost Levels castle 4
    .addr $c605  ; Lost Levels castle 2
    .addr $c7c7  ; Overworld 1
    .addr $c681  ; Overworld 2
    .addr $c7e8  ; Overworld 3
    .addr $c69e  ; Overworld 4
    .addr $c7f8  ; Overworld 5
    .addr $c829  ; Overworld 6
    .addr $c847  ; Overworld 7
    .addr $c860  ; Overworld 8
    .addr $c867  ; Overworld 9
    .addr off_ann_empty_enemy_stream  ; Overworld 10
    .addr $c705  ; Overworld 11
    .addr $c896  ; Overworld 12
    .addr $c89c  ; Overworld 13
    .addr $c72f  ; Overworld 14
    .addr $c752  ; Overworld 15
    .addr $c8c0  ; Overworld 16
    .addr $c75b  ; Overworld 17
    .addr $c795  ; Overworld 18
    .addr $c7c0  ; Overworld 19
    .addr $c7f0  ; Overworld 20
    .addr $c8c1  ; Overworld 21
    .addr $c8c7  ; Overworld 22
    .addr $c6c5  ; Vs. overworld 7
    .addr $c6e8  ; Vs. overworld 8
    .addr off_ann_empty_enemy_stream  ; ANN overworld 10
    .addr $c729  ; ANN overworld 26
    .addr $c80c  ; ANN overworld 27
    .addr $c8eb  ; Overworld 22 ending
    .addr $c8ec  ; Underground 1
    .addr $c919  ; Underground 2
    .addr $c947  ; Underground 3
    .addr $c812  ; ANN underground 4
    .addr $c82b  ; Water 1
    .addr $c962  ; Water 2
    .addr $c86a  ; Lost Levels water 4
    .addr $c83c  ; Vs. water 2
    .addr off_ann_empty_enemy_stream  ; Empty water course

tbl_ann_course_area_pages:
    .byte $28, $08, $24, $00

tbl_ann_course_area_addresses:
    .addr $c97b  ; Castle 1
    .addr $c9d2  ; Castle 2
    .addr $ca53  ; Castle 3
    .addr $cac2  ; Castle 4
    .addr $c97a  ; Castle 5
    .addr $ca05  ; Lost Levels castle 8
    .addr $c878  ; Lost Levels castle 4
    .addr $c8ed  ; Lost Levels castle 2
    .addr $cb2d  ; Overworld 1
    .addr $cad8  ; Overworld 2
    .addr $cb8a  ; Overworld 3
    .addr $cb45  ; Overworld 4
    .addr $cbdd  ; Overworld 5
    .addr $cc4e  ; Overworld 6
    .addr $ccb3  ; Overworld 7
    .addr $cd08  ; Overworld 8
    .addr $cd85  ; Overworld 9
    .addr off_ann_course_10_area_data  ; Overworld 10
    .addr $cc8c  ; Overworld 11
    .addr $cde8  ; Overworld 12
    .addr $cdfd  ; Overworld 13
    .addr $cce2  ; Overworld 14
    .addr $cd49  ; Overworld 15
    .addr $ce54  ; Overworld 16
    .addr $cdbe  ; Overworld 17
    .addr $ce53  ; Overworld 18
    .addr $ceca  ; Overworld 19
    .addr $cf47  ; Overworld 20
    .addr $ce85  ; Overworld 21
    .addr $ceb0  ; Overworld 22
    .addr $cbd6  ; Vs. overworld 7
    .addr $cc1f  ; Vs. overworld 8
    .addr off_ann_course_28_area_data  ; Lost Levels overworld 28
    .addr $cccd  ; ANN overworld 26
    .addr $cfa8  ; ANN overworld 27
    .addr $cee7  ; Alternate overworld 10
    .addr $cef0  ; Underground 1
    .addr $cf91  ; Underground 2
    .addr $d036  ; Underground 3
    .addr $cfd3  ; ANN underground 4
    .addr $d02c  ; Water 1
    .addr $d0c3  ; Water 2
    .addr $d136  ; Lost Levels water 4
    .addr $d06d  ; Vs. water 2
    .addr off_ann_course_28_area_data_end  ; Empty water course
