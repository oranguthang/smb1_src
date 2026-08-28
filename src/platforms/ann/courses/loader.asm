; Select ANN course streams and decode their two-byte area headers

con_ann_course_enemy_end = $ff
con_ann_course_descriptor_type_mask = $60
con_ann_course_descriptor_page_mask = $1f
con_ann_area_foreground_color_mask = $07
con_ann_area_background_color_minimum = $04
con_ann_area_entrance_mask = $38
con_ann_area_timer_mask = $c0
con_ann_area_floor_mask = $0f
con_ann_area_background_mask = $30
con_ann_area_platform_mask = $c0
con_ann_area_cloud_platform = $03
con_ann_area_header_size = 2

off_ann_empty_enemy_stream:
    .byte con_ann_course_enemy_end

off_ann_course_10_area_data:
    .byte $38, $11, $0f, $26, $ad, $40, $3d, $c7, $fd

off_ann_course_28_area_data:
    .byte $90, $31, $39, $f1, $5f, $38, $6d, $c1
    .byte $af, $26, $8d, $c7
off_ann_course_28_area_data_end:
    .byte $fd

sub_ann_load_course:
    JSR sub_ann_get_course_descriptor
    STA ram_area_pointer

sub_ann_get_course_type:
    AND #con_ann_course_descriptor_type_mask
    ASL
    ROL
    ROL
    ROL
    STA ram_area_type
    RTS

sub_ann_get_course_descriptor:
    LDY ram_ann_course_number
    LDA tbl_ann_course_world_offsets,y
    CLC
    ADC ram_ann_course_sub
    TAY
    LDA tbl_ann_course_area_offsets,y
    RTS

sub_ann_load_course_streams:
    LDA ram_area_pointer
    JSR sub_ann_get_course_type
    TAY
    LDA ram_area_pointer
    AND #con_ann_course_descriptor_page_mask
    STA ram_area_addrs_l_offset
    LDA tbl_ann_course_enemy_pages,y
    CLC
    ADC ram_area_addrs_l_offset
    ASL
    TAY
    LDA tbl_ann_course_enemy_addresses+1,y
    STA ram_enemy_data_high
    LDA tbl_ann_course_enemy_addresses,y
    STA ram_enemy_data_low
    LDY ram_area_type
    LDA tbl_ann_course_area_pages,y
    CLC
    ADC ram_area_addrs_l_offset
    ASL
    TAY
    LDA tbl_ann_course_area_addresses+1,y
    STA ram_area_data_high
    LDA tbl_ann_course_area_addresses,y
    STA ram_area_data_low
    LDY #$00
    LDA (ram_area_data),y
    PHA
    AND #con_ann_area_foreground_color_mask
    CMP #con_ann_area_background_color_minimum
    BCC :+
    STA ram_background_color_ctrl
    LDA #$00
    :
    STA ram_foreground_scenery
    PLA
    PHA
    AND #con_ann_area_entrance_mask
    LSR
    LSR
    LSR
    STA ram_player_entrance_ctrl
    PLA
    AND #con_ann_area_timer_mask
    CLC
    ROL
    ROL
    ROL
    STA ram_game_timer_setting
    INY
    LDA (ram_area_data),y
    PHA
    AND #con_ann_area_floor_mask
    STA ram_terrain_control
    PLA
    PHA
    AND #con_ann_area_background_mask
    LSR
    LSR
    LSR
    LSR
    STA ram_background_scenery
    PLA
    AND #con_ann_area_platform_mask
    CLC
    ROL
    ROL
    ROL
    CMP #con_ann_area_cloud_platform
    BNE :+
    STA ram_cloud_type_override
    LDA #$00
    :
    STA ram_area_style
    LDA ram_area_data_low
    CLC
    ADC #con_ann_area_header_size
    STA ram_area_data_low
    LDA ram_area_data_high
    ADC #$00
    STA ram_area_data_high
    RTS
