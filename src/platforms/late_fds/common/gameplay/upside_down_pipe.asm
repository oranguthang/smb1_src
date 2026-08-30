; Shared late-FDS upside-down pipe and piranha-plant runtime

handler_late_fds_upside_down_pipe_high:
    LDA #$01
    PHA
    BNE bra_late_fds_render_upside_down_pipe_body

handler_late_fds_upside_down_pipe_low:
    LDA #$04
    PHA

bra_late_fds_render_upside_down_pipe_body:
    JSR sub_late_fds_get_pipe_height
    PLA
    STA $07
    TYA
    PHA
    LDY ram_area_object_length,x
    BEQ bra_late_fds_finish_upside_down_pipe
    JSR sub_late_fds_find_empty_enemy_slot
    BCS bra_late_fds_finish_upside_down_pipe
    LDA #con_late_fds_upside_down_piranha_object
    JSR sub_late_fds_initialize_upside_down_piranha
    LDA $06
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC ram_enemy_y_position,x
    SEC
    SBC #$0a
    STA ram_enemy_y_position,x
    STA ram_piranha_plant_down_y_pos,x
    CLC
    ADC #$18
    STA ram_piranha_plant_up_y_pos,x
    INC ram_piranha_plant_move_flag,x

bra_late_fds_finish_upside_down_pipe:
    PLA
    TAY
    PHA
    LDX $07
    LDA tbl_late_fds_vertical_pipe_metatiles+2,y
    LDY $06
    DEY
    JSR sub_late_fds_render_under_part
    PLA
    TAY
    LDA tbl_late_fds_vertical_pipe_metatiles,y
    STA ram_metatile_buffer,x
    RTS

unused_late_fds_upside_down_pipe_return:
    RTS

handler_late_fds_move_upside_down_piranha_plant:
    LDA ram_enemy_state,x
    BNE bra_late_fds_exit_upside_down_piranha_movement
    LDA ram_enemy_frame_timer,x
    BNE bra_late_fds_exit_upside_down_piranha_movement
    LDA ram_piranha_plant_move_flag,x
    BNE bra_late_fds_select_upside_down_piranha_limit
    LDA ram_piranha_plant_y_speed,x
    EOR #$ff
    CLC
    ADC #$01
    STA ram_piranha_plant_y_speed,x
    INC ram_piranha_plant_move_flag,x

bra_late_fds_select_upside_down_piranha_limit:
    LDA ram_piranha_plant_up_y_pos,x
    LDY ram_piranha_plant_y_speed,x
    BPL bra_late_fds_move_upside_down_piranha
    LDA ram_piranha_plant_down_y_pos,x

bra_late_fds_move_upside_down_piranha:
    STA $00
    LDA ram_timer_control
    BNE bra_late_fds_exit_upside_down_piranha_movement
    LDA ram_enemy_y_position,x
    CLC
    ADC ram_piranha_plant_y_speed,x
    STA ram_enemy_y_position,x
    CMP $00
    BNE bra_late_fds_exit_upside_down_piranha_movement
    LDA #$00
    STA ram_piranha_plant_move_flag,x
    LDA #$20
    STA ram_enemy_frame_timer,x

bra_late_fds_exit_upside_down_piranha_movement:
    RTS
