; -------------------------------------------------------------------------------------

loc_run_enemy_objects_core:
    LDX ram_object_offset  ; get offset for enemy object buffer
    LDA #$00  ; load value 0 for jump engine by default
    LDY ram_enemy_id,x
    CPY #$15  ; if enemy object < $15, use default value
    BCC bra_dispatch_enemy_object_handler
    TYA  ; otherwise subtract $14 from the value and use
    SBC #$14  ; as value for jump engine
bra_dispatch_enemy_object_handler:
    JSR sub_dispatch_inline_handler

    .word handler_run_normal_enemy  ; for objects $00-$14

    .word handler_run_bowser_flame  ; for objects $15-$1f
    .word handler_run_fireworks
    .word handler_no_enemy_object_handler
    .word handler_no_enemy_object_handler
    .word handler_no_enemy_object_handler
    .word handler_no_enemy_object_handler
    .word handler_run_firebar
    .word handler_run_firebar
    .word handler_run_firebar
    .word handler_run_firebar
    .word handler_run_firebar

    .word handler_run_firebar  ; for objects $20-$2f
    .word handler_run_firebar
    .word handler_run_firebar
    .word handler_no_enemy_object_handler
    .word handler_run_large_platform
    .word handler_run_large_platform
    .word handler_run_large_platform
    .word handler_run_large_platform
    .word handler_run_large_platform
    .word handler_run_large_platform
    .word handler_run_large_platform
    .word handler_run_small_platform
    .word handler_run_small_platform
    .word handler_run_bowser
    .word handler_process_power_up_object
    .word handler_run_vine_object

    .word handler_no_enemy_object_handler  ; for objects $30-$35
    .word handler_run_star_flag
    .word handler_process_jumpspring
    .word handler_no_enemy_object_handler
    .word handler_run_warp_zone_object
    .word sub_run_retainer_obj

; --------------------------------

.if con_revision_profile = con_revision_profile_ann
handler_no_enemy_object_handler = handler_end_enemy_initialization
.else
handler_no_enemy_object_handler:
    RTS
.endif

; --------------------------------

sub_run_retainer_obj:
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JMP sub_render_enemy_graphics

; --------------------------------

handler_run_normal_enemy:
    LDA #$00  ; init sprite attributes
    STA ram_enemy_spr_attrib,x
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JSR sub_render_enemy_graphics
    JSR sub_get_enemy_bound_box
    JSR sub_detect_enemy_background_collision
    JSR sub_enemies_collision
    JSR sub_player_enemy_collision
    LDY ram_timer_control  ; if master timer control set, skip to last routine
    BNE bra_finish_normal_enemy_handler
    JSR sub_dispatch_enemy_movement
bra_finish_normal_enemy_handler:
    JMP sub_offscreen_bounds_check

sub_dispatch_enemy_movement:
    LDA ram_enemy_id,x
    JSR sub_dispatch_inline_handler

    .word sub_move_normal_enemy  ; only objects $00-$14 use this table
    .word sub_move_normal_enemy
    .word sub_move_normal_enemy
    .word sub_move_normal_enemy
.if con_revision_profile = con_revision_profile_ann
    .word handler_ann_piranha_plant_b
.else
    .word sub_move_normal_enemy
.endif
    .word handler_move_hammer_bro
    .word sub_move_normal_enemy
    .word handler_move_blooper
    .word handler_move_frenzy_bullet_bill
    .word handler_no_enemy_movement
    .word handler_move_swimming_cheep_cheep
    .word handler_move_swimming_cheep_cheep
    .word handler_move_podoboo
    .word handler_move_piranha_plant
    .word sub_move_jumping_enemy
    .word handler_move_red_paratroopa
    .word handler_move_flying_green_paratroopa
    .word handler_move_lakitu
    .word sub_move_normal_enemy
    .word handler_no_enemy_movement  ; dummy
    .word handler_move_flying_cheep_cheep

; --------------------------------

.if con_revision_profile = con_revision_profile_ann
handler_no_enemy_movement = handler_end_enemy_initialization
.else
handler_no_enemy_movement:
    RTS
.endif

; --------------------------------

handler_run_bowser_flame:
    JSR sub_process_bowser_flame
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JSR sub_get_enemy_bound_box
    JSR sub_player_enemy_collision
    JMP sub_offscreen_bounds_check

; --------------------------------

handler_run_firebar:
    JSR sub_process_firebar
    JMP sub_offscreen_bounds_check

; --------------------------------

handler_run_small_platform:
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JSR sub_small_platform_bound_box
    JSR sub_small_platform_collision
    JSR sub_relative_enemy_position
    JSR sub_draw_small_platform
    JSR sub_move_small_platform
    JMP sub_offscreen_bounds_check

; --------------------------------

handler_run_large_platform:
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JSR sub_large_platform_bound_box
    JSR sub_large_platform_collision
    LDA ram_timer_control  ; if master timer control set,
    BNE bra_render_large_platform  ; skip subroutine tree
    JSR sub_dispatch_large_platform_movement
bra_render_large_platform:
    JSR sub_relative_enemy_position
    JSR sub_draw_large_platform
    JMP sub_offscreen_bounds_check

; --------------------------------

.include "game/enemies/runtime_dispatch_helpers.asm"

; -------------------------------------------------------------------------------------

handler_move_podoboo:
    LDA ram_enemy_interval_timer,x  ; check enemy timer
    BNE bra_apply_podoboo_gravity  ; branch to move enemy if not expired
    JSR sub_initialize_podoboo  ; otherwise set up podoboo again
    LDA ram_pseudo_random_bit_reg+1,x  ; get part of LSFR
    ORA #%10000000  ; set d7
    STA ram_enemy_y_move_force,x  ; store as movement force
    AND #%00001111  ; mask out high nybble
    ORA #$06  ; set for at least six intervals
    STA ram_enemy_interval_timer,x  ; store as new enemy timer
    LDA #$f9
    STA ram_enemy_y_speed,x  ; set vertical speed to move podoboo upwards
bra_apply_podoboo_gravity:
    JMP sub_move_enemy_with_gravity  ; branch to impose gravity on podoboo

; --------------------------------
; $00 - used in bra_update_hammer_bro_jump as bitmask

tbl_hammer_bro_throw_delays:
    .byte $30, $1c

tbl_enemy_x_speed_adjustments:
    .byte $00, $e8, $00, $18

tbl_revived_enemy_x_speeds:
    .byte $08, $f8, $0c, $f4

handler_move_hammer_bro:
    LDA ram_enemy_state,x  ; check hammer bro's enemy state for d5 set
    AND #%00100000
    BEQ bra_update_hammer_bro_actions  ; if not set, go ahead with code
    JMP loc_move_defeated_enemy  ; otherwise jump to something else
bra_update_hammer_bro_actions:
    LDA ram_hammer_bro_jump_timer,x  ; check jump timer
    BEQ bra_update_hammer_bro_jump  ; if expired, branch to jump
    DEC ram_hammer_bro_jump_timer,x  ; otherwise decrement jump timer
    LDA ram_enemy_offscreen_bits
    AND #%00001100  ; check offscreen bits
    BNE loc_move_hammer_bro_horizontally  ; if hammer bro a little offscreen, skip to movement code
    LDA ram_hammer_throwing_timer,x  ; check hammer throwing timer
    BNE bra_decrement_hammer_bro_throw_timer  ; if not expired, skip ahead, do not throw hammer
    LDY ram_secondary_hard_mode  ; otherwise get secondary hard mode flag
    LDA tbl_hammer_bro_throw_delays,y  ; get timer data using flag as offset
    STA ram_hammer_throwing_timer,x  ; set as new timer
    JSR sub_spawn_hammer_object  ; do a sub here to spawn hammer object
    BCC bra_decrement_hammer_bro_throw_timer  ; if carry clear, hammer not spawned, skip to decrement timer
    LDA ram_enemy_state,x
    ORA #%00001000  ; set d3 in enemy state for hammer throw
    STA ram_enemy_state,x
    JMP loc_move_hammer_bro_horizontally  ; jump to move hammer bro
bra_decrement_hammer_bro_throw_timer:
    DEC ram_hammer_throwing_timer,x  ; decrement timer
    JMP loc_move_hammer_bro_horizontally  ; jump to move hammer bro

tbl_hammer_bro_jump_delays:
    .byte $20, $37

bra_update_hammer_bro_jump:
    LDA ram_enemy_state,x  ; get hammer bro's enemy state
    AND #%00000111  ; mask out all but 3 LSB
    CMP #$01  ; check for d0 set (for jumping)
    BEQ loc_move_hammer_bro_horizontally  ; if set, branch ahead to moving code
    LDA #$00  ; load default value here
    STA $00  ; save into temp variable for now
    LDY #$fa  ; set default vertical speed
    LDA ram_enemy_y_position,x  ; check hammer bro's vertical coordinate
    BMI loc_start_hammer_bro_jump  ; if on the bottom half of the screen, use current speed
    LDY #$fd  ; otherwise set alternate vertical speed
    CMP #$70  ; check to see if hammer bro is above the middle of screen
    INC $00  ; increment preset value to $01
    BCC loc_start_hammer_bro_jump  ; if above the middle of the screen, use current speed and $01
    DEC $00  ; otherwise return value to $00
    LDA ram_pseudo_random_bit_reg+1,x  ; get part of LSFR, mask out all but LSB
    AND #$01
    BNE loc_start_hammer_bro_jump  ; if d0 of LSFR set, branch and use current speed and $00
    LDY #$fa  ; otherwise reset to default vertical speed
loc_start_hammer_bro_jump:
    STY ram_enemy_y_speed,x  ; set vertical speed for jumping
    LDA ram_enemy_state,x  ; set d0 in enemy state for jumping
    ORA #$01
    STA ram_enemy_state,x
    LDA $00  ; load preset value here to use as bitmask
    AND ram_pseudo_random_bit_reg+2,x  ; and do bit-wise comparison with part of LSFR
    TAY  ; then use as offset
    LDA ram_secondary_hard_mode  ; check secondary hard mode flag
    BNE bra_set_hammer_bro_jump_delay
    TAY  ; if secondary hard mode flag clear, set offset to 0
bra_set_hammer_bro_jump_delay:
    LDA tbl_hammer_bro_jump_delays,y  ; get jump length timer data using offset from before
    STA ram_enemy_frame_timer,x  ; save in enemy timer
    LDA ram_pseudo_random_bit_reg+1,x
    ORA #%11000000  ; get contents of part of LSFR, set d7 and d6, then
    STA ram_hammer_bro_jump_timer,x  ; store in jump timer

loc_move_hammer_bro_horizontally:
    LDY #<-con_hammer_bro_x_speed  ; move hammer bro a little to the left
    LDA ram_frame_counter
    AND #%01000000  ; change hammer bro's direction every 64 frames
    BNE bra_store_hammer_bro_x_speed
    LDY #con_hammer_bro_x_speed  ; if d6 set in counter, move him a little to the right
bra_store_hammer_bro_x_speed:
    STY ram_enemy_x_speed,x  ; store horizontal speed
    LDY #$01  ; set to face right by default
    JSR sub_player_enemy_diff  ; get horizontal difference between player and hammer bro
    BMI bra_store_hammer_bro_facing  ; if enemy to the left of player, skip this part
    INY  ; set to face left
    LDA ram_enemy_interval_timer,x  ; check walking timer
    BNE bra_store_hammer_bro_facing  ; if not yet expired, skip to set moving direction
    LDA #con_hammer_bro_chase_x_speed
    STA ram_enemy_x_speed,x  ; otherwise, make the hammer bro walk left towards player
bra_store_hammer_bro_facing:
    STY ram_enemy_moving_dir,x  ; set moving direction

sub_move_normal_enemy:
    LDY #$00  ; init Y to leave horizontal movement as-is
    LDA ram_enemy_state,x
    AND #%01000000  ; check enemy state for d6 set, if set skip
    BNE bra_move_falling_enemy  ; to move enemy vertically, then horizontally if necessary
    LDA ram_enemy_state,x
    ASL  ; check enemy state for d7 set
    BCS bra_apply_enemy_horizontal_movement  ; if set, branch to move enemy horizontally
    LDA ram_enemy_state,x
    AND #%00100000  ; check enemy state for d5 set
    BNE loc_move_defeated_enemy  ; if set, branch to move defeated enemy object
    LDA ram_enemy_state,x
    AND #%00000111  ; check d2-d0 of enemy state for any set bits
    BEQ bra_apply_enemy_horizontal_movement  ; if enemy in normal state, branch to move enemy horizontally
    CMP #$05
    BEQ bra_move_falling_enemy  ; if enemy in state used by spiny's egg, go ahead here
    CMP #$03
    BCS bra_revive_stunned_enemy  ; if enemy in states $03 or $04, skip ahead to yet another part
bra_move_falling_enemy:
    JSR sub_move_enemy_downward_fast  ; do a sub here to move enemy downwards
    LDY #$00
    LDA ram_enemy_state,x  ; check for enemy state $02
    CMP #$02
    BEQ bra_move_falling_enemy_horizontally  ; if found, branch to move enemy horizontally
    AND #%01000000  ; check for d6 set
    BEQ bra_apply_enemy_horizontal_movement  ; if not set, branch to something else
    LDA ram_enemy_id,x
    CMP #con_power_up_object  ; check for power-up object
    BEQ bra_apply_enemy_horizontal_movement
    BNE bra_slow_enemy_horizontal_movement  ; if any other object where d6 set, jump to set Y
bra_move_falling_enemy_horizontally:
    JMP sub_move_enemy_horizontally  ; jump here to move enemy horizontally for <> $2e and d6 set

bra_slow_enemy_horizontal_movement:
    LDY #$01  ; if branched here, increment Y to slow horizontal movement
bra_apply_enemy_horizontal_movement:
    LDA ram_enemy_x_speed,x  ; get current horizontal speed
    PHA  ; save to stack
    BPL bra_adjust_enemy_x_speed_temporarily  ; if not moving or moving right, skip, leave Y alone
    INY
    INY  ; otherwise increment Y to next data
bra_adjust_enemy_x_speed_temporarily:
    CLC
    ADC tbl_enemy_x_speed_adjustments,y  ; add value here to slow enemy down if necessary
    STA ram_enemy_x_speed,x  ; save as horizontal speed temporarily
    JSR sub_move_enemy_horizontally  ; then do a sub to move horizontally
    PLA
    STA ram_enemy_x_speed,x  ; get old horizontal speed from stack and return to
    RTS  ; original memory location, then leave

bra_revive_stunned_enemy:
    LDA ram_enemy_interval_timer,x  ; if enemy timer not expired yet,
    BNE bra_check_stunned_goomba_timeout  ; skip ahead to something else
    STA ram_enemy_state,x  ; otherwise initialize enemy state to normal
    LDA ram_frame_counter
    AND #$01  ; get d0 of frame counter
    TAY  ; use as Y and increment for movement direction
    INY
    STY ram_enemy_moving_dir,x  ; store as pseudorandom movement direction
    DEY  ; decrement for use as pointer
.if con_revision_profile = con_revision_profile_ann
    LDA ram_ann_primary_hard_mode
    BEQ bra_set_revived_enemy_x_speed
    LDA ram_ann_hard_mode
    BNE bra_set_revived_enemy_x_speed
.else
    LDA ram_primary_hard_mode  ; check primary hard mode flag
    BEQ bra_set_revived_enemy_x_speed  ; if not set, use pointer as-is
.endif
    INY
    INY  ; otherwise increment 2 bytes to next data
bra_set_revived_enemy_x_speed:
    LDA tbl_revived_enemy_x_speeds,y  ; load and store new horizontal speed
    STA ram_enemy_x_speed,x  ; and leave
    RTS

loc_move_defeated_enemy:
    JSR sub_move_enemy_downward_fast  ; execute sub to move defeated enemy downwards
    JMP sub_move_enemy_horizontally  ; now move defeated enemy horizontally

bra_check_stunned_goomba_timeout:
    CMP #con_stunned_goomba_erase_timer  ; check to see if enemy timer has reached
    BNE bra_exit_stunned_enemy_update  ; a certain point, and branch to leave if not
    LDA ram_enemy_id,x
    CMP #con_goomba  ; check for goomba object
    BNE bra_exit_stunned_enemy_update  ; branch if not found
    JSR sub_erase_enemy_object  ; otherwise, kill this goomba object
bra_exit_stunned_enemy_update:
    RTS  ; leave!

; --------------------------------

sub_move_jumping_enemy:
    JSR sub_move_enemy_with_gravity  ; do a sub to impose gravity on green paratroopa
    JMP sub_move_enemy_horizontally  ; jump to move enemy horizontally

; --------------------------------

handler_move_red_paratroopa:
    LDA ram_enemy_y_speed,x
    ORA ram_enemy_y_move_force,x  ; check for any vertical force or speed
    BNE bra_select_red_paratroopa_vertical_direction  ; branch if any found
    STA ram_enemy_ymf_dummy,x  ; initialize something here
    LDA ram_enemy_y_position,x  ; check current vs. original vertical coordinate
    CMP ram_red_p_troopa_orig_x_pos,x
    BCS bra_select_red_paratroopa_vertical_direction  ; if current => original, skip ahead to more code
    LDA ram_frame_counter  ; get frame counter
    AND #%00000111  ; mask out all but 3 LSB
    BNE bra_exit_red_paratroopa_idle_correction  ; if any bits set, branch to leave
    INC ram_enemy_y_position,x  ; otherwise increment red paratroopa's vertical position
bra_exit_red_paratroopa_idle_correction:
    RTS  ; leave

bra_select_red_paratroopa_vertical_direction:
    LDA ram_enemy_y_position,x  ; check current vs. central vertical coordinate
    CMP ram_red_p_troopa_center_y_pos,x
    BCC bra_move_red_paratroopa_down  ; if current < central, jump to move downwards
    JMP loc_move_red_paratroopa_up  ; otherwise jump to move upwards
bra_move_red_paratroopa_down:
    JMP loc_move_red_paratroopa_down  ; move downwards

; --------------------------------
; $00 - used to store adder for movement, also used as adder for platform
; $01 - used to store maximum value for secondary counter

handler_move_flying_green_paratroopa:
    JSR sub_update_green_paratroopa_x_movement_counters  ; do sub to increment primary and secondary counters
    JSR sub_move_with_x_movement_counters  ; do sub to move green paratroopa accordingly, and horizontally
    LDY #$01  ; set Y to move green paratroopa down
    LDA ram_frame_counter
    AND #%00000011  ; check frame counter 2 LSB for any bits set
    BNE bra_exit_green_paratroopa_movement  ; branch to leave if set to move up/down every fourth frame
    LDA ram_frame_counter
    AND #%01000000  ; check frame counter for d6 set
    BNE bra_apply_green_paratroopa_y_sway  ; branch to move green paratroopa down if set
    LDY #$ff  ; otherwise set Y to move green paratroopa up
bra_apply_green_paratroopa_y_sway:
    STY $00  ; store adder here
    LDA ram_enemy_y_position,x
    CLC  ; add or subtract from vertical position
    ADC $00  ; to give green paratroopa a wavy flight
    STA ram_enemy_y_position,x
bra_exit_green_paratroopa_movement:
    RTS  ; leave!

sub_update_green_paratroopa_x_movement_counters:
    LDA #$13  ; load preset maximum value for secondary counter

sub_update_platform_x_movement_counters:
    STA $01  ; store value here
    LDA ram_frame_counter
    AND #%00000011  ; branch to leave if not on
    BNE bra_exit_x_movement_counter_update  ; every fourth frame
    LDY ram_x_move_secondary_counter,x  ; get secondary counter
    LDA ram_x_move_primary_counter,x  ; get primary counter
    LSR
    BCS bra_decrement_x_movement_amplitude  ; if d0 of primary counter set, branch elsewhere
    CPY $01  ; compare secondary counter to preset maximum value
    BEQ bra_advance_x_movement_phase  ; if equal, branch ahead of this part
    INC ram_x_move_secondary_counter,x  ; increment secondary counter and leave
bra_exit_x_movement_counter_update:
    RTS
bra_advance_x_movement_phase:
    INC ram_x_move_primary_counter,x  ; increment primary counter and leave
    RTS
bra_decrement_x_movement_amplitude:
    TYA  ; put secondary counter in A
    BEQ bra_advance_x_movement_phase  ; if secondary counter at zero, branch back
    DEC ram_x_move_secondary_counter,x  ; otherwise decrement secondary counter and leave
    RTS

sub_move_with_x_movement_counters:
    LDA ram_x_move_secondary_counter,x  ; save secondary counter to stack
    PHA
    LDY #$01  ; set value here by default
    LDA ram_x_move_primary_counter,x
    AND #%00000010  ; if d1 of primary counter is
    BNE bra_move_counter_driven_object_right  ; set, branch ahead of this part here
    LDA ram_x_move_secondary_counter,x
    EOR #$ff  ; otherwise change secondary
    CLC  ; counter to two's compliment
    ADC #$01
    STA ram_x_move_secondary_counter,x
    LDY #$02  ; load alternate value here
bra_move_counter_driven_object_right:
    STY ram_enemy_moving_dir,x  ; store as moving direction
    JSR sub_move_enemy_horizontally
    STA $00  ; save value obtained from sub here
    PLA  ; get secondary counter from stack
    STA ram_x_move_secondary_counter,x  ; and return to original place
    RTS

; --------------------------------

tbl_blooper_random_masks_by_hard_mode:
.if con_revision_profile = con_revision_profile_pal
    .byte %00000111, %00000001
.else
    .byte %00111111, %00000011
.endif

handler_move_blooper:
    LDA ram_enemy_state,x
    AND #%00100000  ; check enemy state for d5 set
    BNE bra_move_defeated_blooper  ; branch if set to move defeated bloober
    LDY ram_secondary_hard_mode  ; use secondary hard mode flag as offset
    LDA ram_pseudo_random_bit_reg+1,x  ; get LSFR
    AND tbl_blooper_random_masks_by_hard_mode,y  ; mask out bits in LSFR using bitmask loaded with offset
    BNE bra_update_blooper_swim  ; if any bits set, skip ahead to make swim
    TXA
    LSR  ; check to see if on second or fourth slot (1 or 3)
    BCC bra_face_blooper_toward_player  ; if not, branch to figure out moving direction
    LDY ram_player_moving_dir  ; otherwise, load player's moving direction and
    BCS bra_store_blooper_moving_direction  ; do an unconditional branch to set
bra_face_blooper_toward_player:
    LDY #$02  ; set left moving direction by default
    JSR sub_player_enemy_diff  ; get horizontal difference between player and bloober
    BPL bra_store_blooper_moving_direction  ; if enemy to the right of player, keep left
    DEY  ; otherwise decrement to set right moving direction
bra_store_blooper_moving_direction:
    STY ram_enemy_moving_dir,x  ; set moving direction of bloober, then continue on here

bra_update_blooper_swim:
    JSR sub_process_blooper_swim  ; execute sub to make bloober swim characteristically
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    SEC
    SBC ram_enemy_y_move_force,x  ; subtract movement force
    CMP #$20  ; check to see if position is above edge of status bar
    BCC bra_move_blooper_horizontally  ; if so, don't do it
    STA ram_enemy_y_position,x  ; otherwise, set new vertical position, make bloober swim
bra_move_blooper_horizontally:
    LDY ram_enemy_moving_dir,x  ; check moving direction
    DEY
    BNE bra_move_blooper_left  ; if moving to the left, branch to second part
    LDA ram_enemy_x_position,x
    CLC  ; add movement speed to horizontal coordinate
    ADC ram_blooper_move_speed,x
    STA ram_enemy_x_position,x  ; store result as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    ADC #$00  ; add carry to page location
    STA ram_enemy_page_loc,x  ; store as new page location and leave
    RTS

bra_move_blooper_left:
    LDA ram_enemy_x_position,x
    SEC  ; subtract movement speed from horizontal coordinate
    SBC ram_blooper_move_speed,x
    STA ram_enemy_x_position,x  ; store result as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    SBC #$00  ; subtract borrow from page location
    STA ram_enemy_page_loc,x  ; store as new page location and leave
    RTS

bra_move_defeated_blooper:
    JMP sub_move_enemy_downward_slow  ; jump to move defeated bloober downwards

sub_process_blooper_swim:
    LDA ram_blooper_move_counter,x  ; get enemy's movement counter
    AND #%00000010  ; check for d1 set
    BNE bra_check_blooper_float_down  ; branch if set
    LDA ram_frame_counter
    AND #%00000111  ; get 3 LSB of frame counter
    PHA  ; and save it to the stack
    LDA ram_blooper_move_counter,x  ; get enemy's movement counter
    LSR  ; check for d0 set
    BCS bra_slow_blooper_swim  ; branch if set
    PLA  ; pull 3 LSB of frame counter from the stack
    BNE bra_exit_blooper_swim_phase  ; branch to leave, execute code only every eighth frame
    LDA ram_enemy_y_move_force,x
    CLC  ; add to movement force to speed up swim
    ADC #$01
    STA ram_enemy_y_move_force,x  ; set movement force
    STA ram_blooper_move_speed,x  ; set as movement speed
    CMP #$02
    BNE bra_exit_blooper_swim_phase  ; if certain horizontal speed, branch to leave
    INC ram_blooper_move_counter,x  ; otherwise increment movement counter
bra_exit_blooper_swim_phase:
    RTS

bra_slow_blooper_swim:
    PLA  ; pull 3 LSB of frame counter from the stack
    BNE bra_exit_blooper_slowdown  ; branch to leave, execute code only every eighth frame
    LDA ram_enemy_y_move_force,x
    SEC  ; subtract from movement force to slow swim
    SBC #$01
    STA ram_enemy_y_move_force,x  ; set movement force
    STA ram_blooper_move_speed,x  ; set as movement speed
    BNE bra_exit_blooper_slowdown  ; if any speed, branch to leave
    INC ram_blooper_move_counter,x  ; otherwise increment movement counter
    LDA #$02
    STA ram_enemy_interval_timer,x  ; set enemy's timer
bra_exit_blooper_slowdown:
    RTS  ; leave

bra_check_blooper_float_down:
    LDA ram_enemy_interval_timer,x  ; get enemy timer
    BEQ bra_check_blooper_near_player_y  ; branch if expired

bra_float_blooper_down:
    LDA ram_frame_counter  ; get frame counter
    LSR  ; check for d0 set
    BCS bra_exit_blooper_float_down  ; branch to leave on every other frame
    INC ram_enemy_y_position,x  ; otherwise increment vertical coordinate
bra_exit_blooper_float_down:
    RTS  ; leave

bra_check_blooper_near_player_y:
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    ADC #con_blooper_player_y_offset  ; add vertical offset
    CMP ram_player_y_position  ; compare result with player's vertical coordinate
    BCC bra_float_blooper_down  ; if modified vertical less than player's, branch
    LDA #$00
    STA ram_blooper_move_counter,x  ; otherwise nullify movement counter
    RTS

; --------------------------------

handler_move_frenzy_bullet_bill:
    LDA ram_enemy_state,x  ; check bullet bill's enemy object state for d5 set
    AND #%00100000
    BEQ bra_move_active_frenzy_bullet_bill  ; if not set, continue with movement code
    JMP sub_move_enemy_with_gravity  ; otherwise jump to move defeated bullet bill downwards
bra_move_active_frenzy_bullet_bill:
    LDA #$e8  ; set bullet bill's horizontal speed
    STA ram_enemy_x_speed,x  ; and move it accordingly (note: this bullet bill
    JMP sub_move_enemy_horizontally  ; object occurs in frenzy object $17, not from cannons)

; --------------------------------
; $02 - used to hold preset values
; $03 - used to hold enemy state

tbl_swimming_cheep_cheep_x_forces:
    .byte $40, $80
    .byte $04, $04  ; residual data, not used

handler_move_swimming_cheep_cheep:
    LDA ram_enemy_state,x  ; check cheep-cheep's enemy object state
    AND #%00100000  ; for d5 set
    BEQ bra_move_active_swimming_cheep_cheep  ; if not set, continue with movement code
    JMP sub_move_enemy_downward_slow  ; otherwise jump to move defeated cheep-cheep downwards
bra_move_active_swimming_cheep_cheep:
    STA $03  ; save enemy state in $03
    LDA ram_enemy_id,x  ; get enemy identifier
    SEC
    SBC #$0a  ; subtract ten for cheep-cheep identifiers
    TAY  ; use as offset
    LDA tbl_swimming_cheep_cheep_x_forces,y  ; load value here
    STA $02
    LDA ram_enemy_x_move_force,x  ; load horizontal force
    SEC
    SBC $02  ; subtract preset value from horizontal force
    STA ram_enemy_x_move_force,x  ; store as new horizontal force
    LDA ram_enemy_x_position,x  ; get horizontal coordinate
    SBC #$00  ; subtract borrow (thus moving it slowly)
    STA ram_enemy_x_position,x  ; and save as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    SBC #$00  ; subtract borrow again, this time from the
    STA ram_enemy_page_loc,x  ; page location, then save
.if con_revision_profile = con_revision_profile_ann
    LDA #con_ann_swimming_cheep_cheep_y_force
.else
    LDA #$20
.endif
    STA $02  ; save new value here
    CPX #$02  ; check enemy object offset
    BCC bra_exit_swimming_cheep_cheep_movement  ; if in first or second slot, branch to leave
    LDA ram_cheep_cheep_move_m_flag,x  ; check movement flag
    CMP #$10  ; if movement speed set to $00,
    BCC bra_move_swimming_cheep_cheep_up  ; branch to move upwards
    LDA ram_enemy_ymf_dummy,x
    CLC
    ADC $02  ; add preset value to dummy variable to get carry
    STA ram_enemy_ymf_dummy,x  ; and save dummy
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    ADC $03  ; add carry to it plus enemy state to slowly move it downwards
    STA ram_enemy_y_position,x  ; save as new vertical coordinate
    LDA ram_enemy_y_high_pos,x
    ADC #$00  ; add carry to page location and
    JMP loc_check_swimming_cheep_cheep_y_range  ; jump to end of movement code

bra_move_swimming_cheep_cheep_up:
    LDA ram_enemy_ymf_dummy,x
    SEC
    SBC $02  ; subtract preset value to dummy variable to get borrow
    STA ram_enemy_ymf_dummy,x  ; and save dummy
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    SBC $03  ; subtract borrow to it plus enemy state to slowly move it upwards
    STA ram_enemy_y_position,x  ; save as new vertical coordinate
    LDA ram_enemy_y_high_pos,x
    SBC #$00  ; subtract borrow from page location

loc_check_swimming_cheep_cheep_y_range:
    STA ram_enemy_y_high_pos,x  ; save new page location here
    LDY #$00  ; load movement speed to upwards by default
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    SEC
    SBC ram_cheep_cheep_orig_y_pos,x  ; subtract original coordinate from current
    BPL bra_check_swimming_cheep_cheep_y_distance  ; if result positive, skip to next part
    LDY #$10  ; otherwise load movement speed to downwards
    EOR #$ff
    CLC  ; get two's compliment of result
    ADC #$01  ; to obtain total difference of original vs. current
bra_check_swimming_cheep_cheep_y_distance:
    CMP #$0f  ; if difference between original vs. current vertical
    BCC bra_exit_swimming_cheep_cheep_movement  ; coordinates < 15 pixels, leave movement speed alone
    TYA
    STA ram_cheep_cheep_move_m_flag,x  ; otherwise change movement speed
bra_exit_swimming_cheep_cheep_movement:
    RTS  ; leave
