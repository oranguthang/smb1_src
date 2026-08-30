; Shared late-FDS hard-course selection and area-header loader

con_late_fds_course_descriptor_page_mask = $1f
con_late_fds_area_foreground_color_mask = $07
con_late_fds_area_background_color_minimum = $04
con_late_fds_area_entrance_mask = $38
con_late_fds_area_timer_mask = $c0
con_late_fds_area_floor_mask = $0f
con_late_fds_area_background_mask = $30
con_late_fds_area_platform_mask = $c0
con_late_fds_area_cloud_platform = $03
con_late_fds_area_header_size = 2

handler_late_fds_get_hard_course_descriptor:
    LDY ram_late_fds_hard_course_number
    LDA tbl_late_fds_hard_course_world_offsets,y
    CLC
    ADC ram_late_fds_hard_course_sub
    TAY
    LDA tbl_late_fds_hard_course_area_offsets,y
    RTS

handler_late_fds_load_hard_course_streams:
    LDA ram_area_pointer
    JSR sub_late_fds_get_course_type
    TAY
    LDA ram_area_pointer
    AND #con_late_fds_course_descriptor_page_mask
    STA ram_area_addrs_l_offset
    LDA tbl_late_fds_hard_course_enemy_pages,y
    CLC
    ADC ram_area_addrs_l_offset
    ASL
    TAY
    LDA tbl_late_fds_hard_course_enemy_addresses+1,y
    STA ram_enemy_data_high
    LDA tbl_late_fds_hard_course_enemy_addresses,y
    STA ram_enemy_data_low
    LDY ram_area_type
    LDA tbl_late_fds_hard_course_area_pages,y
    CLC
    ADC ram_area_addrs_l_offset
    ASL
    TAY
    LDA tbl_late_fds_hard_course_area_addresses+1,y
    STA ram_area_data_high
    LDA tbl_late_fds_hard_course_area_addresses,y
    STA ram_area_data_low
    LDY #$00
    LDA (ram_area_data),y
    PHA
    AND #con_late_fds_area_foreground_color_mask
    CMP #con_late_fds_area_background_color_minimum
    BCC bra_late_fds_store_hard_course_foreground_scenery
    STA ram_background_color_ctrl
    LDA #$00

bra_late_fds_store_hard_course_foreground_scenery:
    STA ram_foreground_scenery
    PLA
    PHA
    AND #con_late_fds_area_entrance_mask
    LSR
    LSR
    LSR
    STA ram_player_entrance_ctrl
    PLA
    AND #con_late_fds_area_timer_mask
    CLC
    ROL
    ROL
    ROL
    STA ram_game_timer_setting
    INY
    LDA (ram_area_data),y
    PHA
    AND #con_late_fds_area_floor_mask
    STA ram_terrain_control
    PLA
    PHA
    AND #con_late_fds_area_background_mask
    LSR
    LSR
    LSR
    LSR
    STA ram_background_scenery
    PLA
    AND #con_late_fds_area_platform_mask
    CLC
    ROL
    ROL
    ROL
    CMP #con_late_fds_area_cloud_platform
    BNE bra_late_fds_store_hard_course_area_style
    STA ram_cloud_type_override
    LDA #$00

bra_late_fds_store_hard_course_area_style:
    STA ram_area_style
    LDA ram_area_data_low
    CLC
    ADC #con_late_fds_area_header_size
    STA ram_area_data_low
    LDA ram_area_data_high
    ADC #$00
    STA ram_area_data_high
    RTS
