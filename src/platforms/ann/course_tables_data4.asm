; ANN NSMDATA4 EXTENDED COURSE TABLES

con_ann_primary_enemy_overworld_10 = $c26f
con_ann_primary_area_overworld_10 = $c270
con_ann_primary_area_overworld_28 = $c279

tbl_ann_extended_course_world_offsets:
    .byte $00, $05, $0a, $0e
    .byte $00, $00, $00, $00

tbl_ann_extended_course_area_offsets:
    .byte $20, $2c, $40, $21, $60  ; Course 1
    .byte $22, $2c, $00, $23, $61  ; Course 2
    .byte $24, $25, $26, $62  ; Course 3
    .byte $27, $28, $29, $63  ; Course 4

tbl_ann_extended_course_enemy_pages:
    .byte $14, $04, $12, $00

tbl_ann_extended_course_enemy_addresses:
    .addr off_ann_data4_enemy_castle_1
    .addr off_ann_data4_enemy_castle_2
    .addr off_ann_data4_enemy_castle_3
    .addr off_ann_data4_enemy_castle_4
    .addr off_ann_data4_enemy_overworld_1
    .addr off_ann_data4_enemy_overworld_2
    .addr off_ann_data4_enemy_overworld_12_smb2
    .addr off_ann_data4_enemy_overworld_7_smb2
    .addr off_ann_data4_enemy_overworld_5
    .addr off_ann_data4_enemy_overworld_6
    .addr off_ann_data4_enemy_overworld_7
    .addr off_ann_data4_enemy_overworld_19_smb2
    .addr off_ann_data4_enemy_overworld_9
    .addr off_ann_data4_enemy_overworld_10
    .addr off_ann_data4_enemy_overworld_11
    .addr off_ann_data4_enemy_overworld_12
    .addr con_ann_primary_enemy_overworld_10
    .addr con_ann_primary_enemy_overworld_10
    .addr off_ann_data4_enemy_underground_1
    .addr off_ann_data4_enemy_underground_2
    .addr off_ann_data4_enemy_water_1

tbl_ann_extended_course_area_pages:
    .byte $14, $04, $12, $00

tbl_ann_extended_course_area_addresses:
    .addr off_ann_data4_area_castle_1
    .addr off_ann_data4_area_castle_2
    .addr off_ann_data4_area_castle_3
    .addr off_ann_data4_area_castle_4
    .addr off_ann_data4_area_overworld_1
    .addr off_ann_data4_area_overworld_2
    .addr off_ann_data4_area_overworld_12_smb2
    .addr off_ann_data4_area_overworld_7_smb2
    .addr off_ann_data4_area_overworld_5
    .addr off_ann_data4_area_overworld_6
    .addr off_ann_data4_area_overworld_7
    .addr off_ann_data4_area_overworld_19_smb2
    .addr off_ann_data4_area_overworld_9
    .addr off_ann_data4_area_overworld_10
    .addr off_ann_data4_area_overworld_11
    .addr off_ann_data4_area_overworld_12
    .addr con_ann_primary_area_overworld_10
    .addr con_ann_primary_area_overworld_28
    .addr off_ann_data4_area_underground_1
    .addr off_ann_data4_area_underground_2
    .addr off_ann_data4_area_water_1

.assert * - tbl_ann_extended_course_world_offsets = $76, error, "ANN DATA4 course tables must be 118 bytes"
