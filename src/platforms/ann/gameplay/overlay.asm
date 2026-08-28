; ANN OVERLAY GAMEPLAY EXTENSIONS

con_ann_piranha_plant_b_object = $04
con_ann_spring_special_acceleration = $e0

handler_ann_draw_flipped_vertical_pipe_a:
    LDA #$01
    PHA
    BNE bra_ann_draw_flipped_vertical_pipe

handler_ann_draw_flipped_vertical_pipe_b:
    LDA #$04
    PHA

bra_ann_draw_flipped_vertical_pipe:
    JSR sub_get_pipe_height
    PLA
    STA $07
    TYA
    PHA
    LDY ram_area_object_length,x
    BEQ bra_ann_render_flipped_vertical_pipe
    JSR sub_find_empty_enemy_slot
    BCS bra_ann_render_flipped_vertical_pipe
    LDA #con_ann_piranha_plant_b_object
    JSR sub_initialize_ann_pipe_piranha_plant
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

bra_ann_render_flipped_vertical_pipe:
    PLA
    TAY
    PHA
    LDX $07
    LDA tbl_vertical_pipe_metatiles+2,y
    LDY $06
    DEY
    JSR sub_render_under_part
    PLA
    TAY
    LDA tbl_vertical_pipe_metatiles,y
    STA ram_metatile_buffer,x
    RTS

unused_ann_flipped_pipe_return:
    RTS

handler_ann_piranha_plant_b:
    LDA ram_enemy_state,x
    BNE bra_exit_ann_piranha_plant_b
    LDA ram_enemy_frame_timer,x
    BNE bra_exit_ann_piranha_plant_b
    LDA ram_piranha_plant_move_flag,x
    BNE bra_select_ann_piranha_plant_b_limit
    LDA ram_piranha_plant_y_speed,x
    EOR #$ff
    CLC
    ADC #$01
    STA ram_piranha_plant_y_speed,x
    INC ram_piranha_plant_move_flag,x

bra_select_ann_piranha_plant_b_limit:
    LDA ram_piranha_plant_up_y_pos,x
    LDY ram_piranha_plant_y_speed,x
    BPL bra_move_ann_piranha_plant_b
    LDA ram_piranha_plant_down_y_pos,x

bra_move_ann_piranha_plant_b:
    STA $00
    LDA ram_timer_control
    BNE bra_exit_ann_piranha_plant_b
    LDA ram_enemy_y_position,x
    CLC
    ADC ram_piranha_plant_y_speed,x
    STA ram_enemy_y_position,x
    CMP $00
    BNE bra_exit_ann_piranha_plant_b
    LDA #$00
    STA ram_piranha_plant_move_flag,x
    LDA #$20
    STA ram_enemy_frame_timer,x

bra_exit_ann_piranha_plant_b:
    RTS

sub_ann_hard_mode_spring:
    LDY ram_world_number
    CPY #$01
    BEQ bra_use_ann_special_spring_acceleration
    CPY #$02
    BNE bra_exit_ann_hard_mode_spring

bra_use_ann_special_spring_acceleration:
    LDA #con_ann_spring_special_acceleration

bra_exit_ann_hard_mode_spring:
    RTS

sub_ann_hard_mode_render_spring:
    LDY ram_world_number
    CPY #$01
    BEQ bra_shift_ann_spring_render_frame
    CPY #$02
    BNE bra_exit_ann_hard_mode_render_spring

bra_shift_ann_spring_render_frame:
    LSR

bra_exit_ann_hard_mode_render_spring:
    RTS

.assert * - handler_ann_draw_flipped_vertical_pipe_a = $a9, error, "ANN overlay gameplay code must be 169 bytes"
