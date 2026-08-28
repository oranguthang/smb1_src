; -------------------------------------------------------------------------------------

; Shared platform dispatcher and enemy-slot cleanup

sub_dispatch_large_platform_movement:
    LDA ram_enemy_id,x  ; subtract $24 to get proper offset for jump table
    SEC
    SBC #$24
    JSR sub_dispatch_inline_handler

    .word handler_move_balance_platform  ; table used by objects $24-$2a
    .word handler_move_vertical_platform
    .word handler_move_large_lift_platform
    .word handler_move_large_lift_platform
    .word handler_move_horizontal_platform
    .word handler_move_drop_platform
    .word handler_move_right_platform

; --------------------------------

sub_erase_enemy_object:
    LDA #$00  ; clear all enemy object variables
    STA ram_enemy_flag,x
    STA ram_enemy_id,x
    STA ram_enemy_state,x
    STA ram_floatey_num_control,x
    STA ram_enemy_interval_timer,x
    STA ram_shell_chain_counter,x
    STA ram_enemy_spr_attrib,x
    STA ram_enemy_frame_timer,x
    RTS
