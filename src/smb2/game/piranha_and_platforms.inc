handler_smb2_main_initialize_piranha_plant:
    LDA #$22  ; set default attribute and range data here
    STA $00  ; range data is used to detect how close player is
    LDA #$13  ; to the piranha plant to keep it inside the pipe
    STA $01  ; default data makes red piranha plants
    LDA HardWorldFlag
    BNE bra_smb2_main_patch_piranha_plant  ; use default data if in worlds A-D
    LDA WorldNumber
    CMP #$03
    BCS bra_smb2_main_patch_piranha_plant  ; use default data if in worlds 4-8
    DEC $00
    LDA #$21  ; otherwise make green piranha plant instead
    STA $01
bra_smb2_main_patch_piranha_plant:
    LDA $00
    STA off_smb2_main_enemy_sprite_attributes+PiranhaPlant  ; patch over attribute and range data
    LDA $01
    STA bra_smb2_main_check_player_near_piranha_pipe+3
    LDA #$01  ; set initial speed
    STA PiranhaPlant_Y_Speed,x
    LSR
    STA Enemy_State,x  ; initialize enemy state and what would normally
    STA PiranhaPlant_MoveFlag,x  ; be used as vertical speed, but not in this case
    LDA Enemy_Y_Position,x
    STA PiranhaPlantDownYPos,x  ; save original vertical coordinate here
    SEC
    SBC #$18
    STA PiranhaPlantUpYPos,x  ; save original vertical coordinate - 24 pixels here
    LDA #$09
    JMP loc_smb2_main_set_special_enemy_bounding_box  ; set specific value for bounding box control

; --------------------------------

handler_smb2_main_initialize_enemy_frenzy:
    LDA Enemy_ID,x  ; load enemy identifier
    STA EnemyFrenzyBuffer  ; save in enemy frenzy buffer
    SEC
    SBC #$12  ; subtract 12 and use as offset for jump engine
    JSR sub_smb2_main_dispatch_inline_handler

; frenzy object jump table
    .word handler_smb2_main_spawn_lakitu_or_spiny
    .word handler_smb2_main_no_frenzy_initialization
    .word handler_smb2_main_initialize_flying_cheep_cheep
    .word handler_smb2_main_initialize_bowser_flame
    .word handler_smb2_main_initialize_fireworks
    .word handler_smb2_main_spawn_bullet_bill_or_cheep_cheep

handler_smb2_main_no_frenzy_initialization:
    RTS

handler_smb2_main_end_enemy_frenzy:
    LDY #$05  ; start at last slot
bra_smb2_main_find_lakitu_to_end_frenzy:
    LDA Enemy_ID,y  ; check enemy identifiers
    CMP #Lakitu  ; for lakitu
    BNE bra_smb2_main_check_next_lakitu_slot
    LDA #$01  ; if found, set state
    STA Enemy_State,y
bra_smb2_main_check_next_lakitu_slot:
    DEY  ; move onto the next slot
    BPL bra_smb2_main_find_lakitu_to_end_frenzy  ; do this until all slots are checked
    LDA #$00
    STA EnemyFrenzyBuffer  ; empty enemy frenzy buffer
    STA Enemy_Flag,x  ; disable enemy buffer flag for this object
    RTS

; --------------------------------

handler_smb2_main_initialize_jumping_green_paratroopa:
    LDA #$02  ; set for movement to the left
    STA Enemy_MovingDir,x
    LDA #$f4  ; set horizontal speed
    STA Enemy_X_Speed,x
loc_smb2_main_set_tall_special_enemy_bounding_box:
    LDA #$03  ; set specific value for bounding box control
loc_smb2_main_set_special_enemy_bounding_box:
    STA Enemy_BoundBoxCtrl,x  ; set bounding box control then leave
    RTS

; --------------------------------

handler_smb2_main_initialize_balance_platform:
    DEC Enemy_Y_Position,x  ; raise vertical position by two pixels
    DEC Enemy_Y_Position,x
    LDY SecondaryHardMode  ; if secondary hard mode flag not set,
    BNE bra_smb2_main_link_balance_platform  ; branch ahead
    LDY #$02  ; otherwise set value here
    JSR sub_smb2_main_offset_platform_x_position  ; do a sub to add or subtract pixels
bra_smb2_main_link_balance_platform:
    LDY #$ff  ; set default value here for now
    LDA BalPlatformAlignment  ; get current balance platform alignment
    STA Enemy_State,x  ; set platform alignment to object state here
    BPL bra_smb2_main_store_balance_platform_alignment  ; if old alignment $ff, put $ff as alignment for negative
    TXA  ; if old contents already $ff, put
    TAY  ; object offset as alignment to make next positive
bra_smb2_main_store_balance_platform_alignment:
    STY BalPlatformAlignment  ; store whatever value's in Y here
    LDA #$00
    STA Enemy_MovingDir,x  ; init moving direction
    TAY  ; init Y
    JSR sub_smb2_main_offset_platform_x_position  ; do a sub to add 8 pixels, then run shared code here

; --------------------------------

handler_smb2_main_initialize_drop_platform:
    LDA #$ff
    STA PlatformCollisionFlag,x  ; set some value here
    JMP loc_smb2_main_initialize_platform  ; then jump ahead to execute more code

; --------------------------------

handler_smb2_main_initialize_horizontal_platform:
    LDA #$00
    STA XMoveSecondaryCounter,x  ; init one of the moving counters
    JMP loc_smb2_main_initialize_platform  ; jump ahead to execute more code

; --------------------------------

handler_smb2_main_initialize_vertical_platform:
    LDY #$40  ; set default value here
    LDA Enemy_Y_Position,x  ; check vertical position
    BPL bra_smb2_main_compute_vertical_platform_center  ; if above a certain point, skip this part
    EOR #$ff
    CLC  ; otherwise get two's compliment
    ADC #$01
    LDY #$c0  ; get alternate value to add to vertical position
bra_smb2_main_compute_vertical_platform_center:
    STA YPlatformTopYPos,x  ; save as top vertical position
    TYA
    CLC  ; load value from earlier, add number of pixels
    ADC Enemy_Y_Position,x  ; to vertical position
    STA YPlatformCenterYPos,x  ; save result as central vertical position

; --------------------------------

loc_smb2_main_initialize_platform:
    JSR sub_smb2_main_clear_enemy_vertical_motion  ; do a sub to init certain other values
loc_smb2_main_set_platform_bounding_box:
    LDA #$05  ; set default bounding box size control
    LDY AreaType
    CPY #$03  ; check for castle-type level
    BEQ bra_smb2_main_store_platform_bounding_box  ; use default value if found
    LDY SecondaryHardMode  ; otherwise check for secondary hard mode flag
    BNE bra_smb2_main_store_platform_bounding_box  ; if set, use default value
    LDA #$06  ; use alternate value if not castle or secondary not set
bra_smb2_main_store_platform_bounding_box:
    STA Enemy_BoundBoxCtrl,x  ; set bounding box size control here and leave
    RTS

; --------------------------------

handler_smb2_main_initialize_large_lift_up:
    JSR sub_smb2_main_initialize_platform_lift_up  ; execute code for platforms going up
    JMP loc_smb2_main_set_large_lift_bounding_box  ; overwrite bounding box for large platforms

handler_smb2_main_initialize_large_lift_down:
    JSR sub_smb2_main_initialize_platform_lift_down  ; execute code for platforms going down

loc_smb2_main_set_large_lift_bounding_box:
    JMP loc_smb2_main_set_platform_bounding_box  ; jump to overwrite bounding box size control

; --------------------------------

sub_smb2_main_initialize_platform_lift_up:
    LDA #$10  ; set movement amount here
    STA Enemy_Y_MoveForce,x
    LDA #$ff  ; set moving speed for platforms going up
    STA Enemy_Y_Speed,x
    JMP loc_smb2_main_initialize_small_lift  ; skip ahead to part we should be executing

; --------------------------------

sub_smb2_main_initialize_platform_lift_down:
    LDA #$f0  ; set movement amount here
    STA Enemy_Y_MoveForce,x
    LDA #$00  ; set moving speed for platforms going down
    STA Enemy_Y_Speed,x

; --------------------------------

loc_smb2_main_initialize_small_lift:
    LDY #$01
    JSR sub_smb2_main_offset_platform_x_position  ; do a sub to add 12 pixels due to preset value
    LDA #$04
    STA Enemy_BoundBoxCtrl,x  ; set bounding box control for small platforms
    RTS

; --------------------------------

off_smb2_main_platform_x_offsets_low:
    .byte $08,$0c,$f8

off_smb2_main_platform_x_offsets_high:
    .byte $00,$00,$ff

sub_smb2_main_offset_platform_x_position:
    LDA Enemy_X_Position,x  ; get horizontal coordinate
    CLC
    ADC off_smb2_main_platform_x_offsets_low,y  ; add or subtract pixels depending on offset
    STA Enemy_X_Position,x  ; store as new horizontal coordinate
    LDA Enemy_PageLoc,x
    ADC off_smb2_main_platform_x_offsets_high,y  ; add or subtract page location depending on offset
    STA Enemy_PageLoc,x  ; store as new page location
    RTS  ; and go back

; --------------------------------

handler_smb2_main_end_enemy_initialization:
    RTS

; -------------------------------------------------------------------------------------

loc_smb2_main_run_enemy_objects_core:
    LDX ObjectOffset  ; get offset for enemy object buffer
    LDA #$00  ; load value 0 for jump engine by default
    LDY Enemy_ID,x
    CPY #$15  ; if enemy object < $15, use default value
    BCC bra_smb2_main_dispatch_enemy_object_handler
    TYA  ; otherwise subtract $14 from the value and use
    SBC #$14  ; as value for jump engine
bra_smb2_main_dispatch_enemy_object_handler:
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_run_normal_enemy  ; for objects $00-$14

    .word handler_smb2_main_run_bowser_flame  ; for objects $15-$1f
    .word handler_smb2_main_run_fireworks
    .word handler_smb2_main_no_enemy_object_handler
    .word handler_smb2_main_no_enemy_object_handler
    .word handler_smb2_main_no_enemy_object_handler
    .word handler_smb2_main_no_enemy_object_handler
    .word handler_smb2_main_run_firebar
    .word handler_smb2_main_run_firebar
    .word handler_smb2_main_run_firebar
    .word handler_smb2_main_run_firebar
    .word handler_smb2_main_run_firebar

    .word handler_smb2_main_run_firebar  ; for objects $20-$2f
    .word handler_smb2_main_run_firebar
    .word handler_smb2_main_run_firebar
    .word handler_smb2_main_no_enemy_object_handler
    .word handler_smb2_main_run_large_platform
    .word handler_smb2_main_run_large_platform
    .word handler_smb2_main_run_large_platform
    .word handler_smb2_main_run_large_platform
    .word handler_smb2_main_run_large_platform
    .word handler_smb2_main_run_large_platform
    .word handler_smb2_main_run_large_platform
    .word handler_smb2_main_run_small_platform
    .word handler_smb2_main_run_small_platform
    .word handler_smb2_main_run_bowser
    .word handler_smb2_main_process_power_up_object
    .word handler_smb2_main_run_vine_object

    .word handler_smb2_main_no_enemy_object_handler  ; for objects $30-$35
    .word handler_smb2_main_run_star_flag
    .word handler_smb2_main_process_jumpspring
    .word handler_smb2_main_no_enemy_object_handler
    .word handler_smb2_main_run_warp_zone_object
    .word sub_smb2_main_run_retainer_obj

; --------------------------------

handler_smb2_main_no_enemy_object_handler:
    RTS

; --------------------------------

sub_smb2_main_run_retainer_obj:
    JSR sub_smb2_main_get_enemy_offscreen_bits
    JSR sub_smb2_main_relative_enemy_position
    JMP sub_smb2_main_render_enemy_graphics

; --------------------------------

handler_smb2_main_run_normal_enemy:
    LDA #$00  ; init sprite attributes
    STA Enemy_SprAttrib,x
    JSR sub_smb2_main_get_enemy_offscreen_bits
    JSR sub_smb2_main_relative_enemy_position
    JSR sub_smb2_main_render_enemy_graphics
    JSR sub_smb2_main_get_enemy_bound_box
    JSR sub_smb2_main_detect_enemy_background_collision
    JSR sub_smb2_main_enemies_collision
    JSR sub_smb2_main_player_enemy_collision
    LDY TimerControl  ; if master timer control set, skip to last routine
    BNE bra_smb2_main_finish_normal_enemy_handler
    JSR sub_smb2_main_dispatch_enemy_movement
bra_smb2_main_finish_normal_enemy_handler:
    JMP sub_smb2_main_offscreen_bounds_check

sub_smb2_main_dispatch_enemy_movement:
    LDA Enemy_ID,x
    JSR sub_smb2_main_dispatch_inline_handler

    .word sub_smb2_main_move_normal_enemy  ; only objects $00-$14 use this table
    .word sub_smb2_main_move_normal_enemy
    .word sub_smb2_main_move_normal_enemy
    .word sub_smb2_main_move_normal_enemy
    .word handler_smb2_data4_move_upside_down_piranha_plant
    .word handler_smb2_main_move_hammer_bro
    .word sub_smb2_main_move_normal_enemy
    .word handler_smb2_main_move_blooper
    .word handler_smb2_main_move_frenzy_bullet_bill
    .word handler_smb2_main_no_enemy_movement
    .word handler_smb2_main_move_swimming_cheep_cheep
    .word handler_smb2_main_move_swimming_cheep_cheep
    .word handler_smb2_main_move_podoboo
    .word handler_smb2_main_move_piranha_plant
    .word sub_smb2_main_move_jumping_enemy
    .word handler_smb2_main_move_red_paratroopa
    .word handler_smb2_main_move_flying_green_paratroopa
    .word handler_smb2_main_move_lakitu
    .word sub_smb2_main_move_normal_enemy
    .word handler_smb2_main_no_enemy_movement  ; dummy
    .word handler_smb2_main_move_flying_cheep_cheep

; --------------------------------

handler_smb2_main_no_enemy_movement:
    RTS

; --------------------------------

handler_smb2_main_run_bowser_flame:
    JSR sub_smb2_main_process_bowser_flame
    JSR sub_smb2_main_get_enemy_offscreen_bits
    JSR sub_smb2_main_relative_enemy_position
    JSR sub_smb2_main_get_enemy_bound_box
    JSR sub_smb2_main_player_enemy_collision
    JMP sub_smb2_main_offscreen_bounds_check

; --------------------------------

handler_smb2_main_run_firebar:
    JSR sub_smb2_main_process_firebar
    JMP sub_smb2_main_offscreen_bounds_check

; --------------------------------

handler_smb2_main_run_small_platform:
    JSR sub_smb2_main_get_enemy_offscreen_bits
    JSR sub_smb2_main_relative_enemy_position
    JSR sub_smb2_main_small_platform_bound_box
    JSR sub_smb2_main_small_platform_collision
    JSR sub_smb2_main_relative_enemy_position
    JSR sub_smb2_main_draw_small_platform
    JSR sub_smb2_main_move_small_platform
    JMP sub_smb2_main_offscreen_bounds_check

; --------------------------------

handler_smb2_main_run_large_platform:
    JSR sub_smb2_main_get_enemy_offscreen_bits
    JSR sub_smb2_main_relative_enemy_position
    JSR sub_smb2_main_large_platform_bound_box
    JSR sub_smb2_main_large_platform_collision
    LDA TimerControl  ; if master timer control set,
    BNE bra_smb2_main_render_large_platform  ; skip subroutine tree
    JSR sub_smb2_main_dispatch_large_platform_movement
bra_smb2_main_render_large_platform:
    JSR sub_smb2_main_relative_enemy_position
    JSR sub_smb2_main_draw_large_platform
    JMP sub_smb2_main_offscreen_bounds_check

; --------------------------------

sub_smb2_main_dispatch_large_platform_movement:
    LDA Enemy_ID,x  ; subtract $24 to get proper offset for jump table
    SEC
    SBC #$24
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_move_balance_platform  ; table used by objects $24-$2a
    .word handler_smb2_main_move_vertical_platform
    .word handler_smb2_main_move_large_lift_platform
    .word handler_smb2_main_move_large_lift_platform
    .word handler_smb2_main_move_horizontal_platform
    .word handler_smb2_main_move_drop_platform
    .word handler_smb2_main_move_right_platform

; -------------------------------------------------------------------------------------

sub_smb2_main_erase_enemy_object:
    LDA #$00  ; clear all enemy object variables
    STA Enemy_Flag,x
    STA Enemy_ID,x
    STA Enemy_State,x
    STA FloateyNum_Control,x
    STA EnemyIntervalTimer,x
    STA ShellChainCounter,x
    STA Enemy_SprAttrib,x
    STA EnemyFrameTimer,x
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_move_podoboo:
    LDA EnemyIntervalTimer,x  ; check enemy timer
    BNE bra_smb2_main_apply_podoboo_gravity  ; branch to move enemy if not expired
    JSR sub_smb2_main_initialize_podoboo  ; otherwise set up podoboo again
    LDA PseudoRandomBitReg+1,x  ; get part of LSFR
    ORA #%10000000  ; set d7
    STA Enemy_Y_MoveForce,x  ; store as movement force
    AND #%00001111  ; mask out high nybble
    ORA #$06  ; set for at least six intervals
    STA EnemyIntervalTimer,x  ; store as new enemy timer
    LDA #$f9
    STA Enemy_Y_Speed,x  ; set vertical speed to move podoboo upwards
bra_smb2_main_apply_podoboo_gravity:
    JMP sub_smb2_main_move_enemy_with_gravity  ; branch to impose gravity on podoboo

; --------------------------------
; $00 - used in HammerBroJumpCode as bitmask

off_smb2_main_hammer_bro_throw_delays:
    .byte $30, $1c

off_smb2_main_enemy_x_speed_adjustments:
    .byte $00, $e8, $00, $18

tbl_smb2_main_revived_enemy_x_speeds:
    .byte $08, $f8, $0c, $f4

handler_smb2_main_move_hammer_bro:
    LDA Enemy_State,x  ; check hammer bro's enemy state for d5 set
    AND #%00100000
    BEQ bra_smb2_main_update_hammer_bro_actions  ; if not set, go ahead with code
    JMP bra_smb2_main_move_defeated_enemy  ; otherwise jump to something else
bra_smb2_main_update_hammer_bro_actions:
    LDA HammerBroJumpTimer,x  ; check jump timer
    BEQ bra_smb2_main_update_hammer_bro_jump  ; if expired, branch to jump
    DEC HammerBroJumpTimer,x  ; otherwise decrement jump timer
    LDA Enemy_OffscreenBits
    AND #%00001100  ; check offscreen bits
    BNE bra_smb2_main_move_hammer_bro_horizontally  ; if hammer bro a little offscreen, skip to movement code
    LDA HammerThrowingTimer,x  ; check hammer throwing timer
    BNE bra_smb2_main_decrement_hammer_bro_throw_timer  ; if not expired, skip ahead, do not throw hammer
    LDY SecondaryHardMode  ; otherwise get secondary hard mode flag
    LDA off_smb2_main_hammer_bro_throw_delays,y  ; get timer data using flag as offset
    STA HammerThrowingTimer,x  ; set as new timer
    JSR sub_smb2_main_spawn_hammer_object  ; do a sub here to spawn hammer object
    BCC bra_smb2_main_decrement_hammer_bro_throw_timer  ; if carry clear, hammer not spawned, skip to decrement timer
    LDA Enemy_State,x
    ORA #%00001000  ; set d3 in enemy state for hammer throw
    STA Enemy_State,x
    JMP bra_smb2_main_move_hammer_bro_horizontally  ; jump to move hammer bro
bra_smb2_main_decrement_hammer_bro_throw_timer:
    DEC HammerThrowingTimer,x  ; decrement timer
    JMP bra_smb2_main_move_hammer_bro_horizontally  ; jump to move hammer bro

off_smb2_main_hammer_bro_jump_delays:
    .byte $20, $37

bra_smb2_main_update_hammer_bro_jump:
    LDA Enemy_State,x  ; get hammer bro's enemy state
    AND #%00000111  ; mask out all but 3 LSB
    CMP #$01  ; check for d0 set (for jumping)
    BEQ bra_smb2_main_move_hammer_bro_horizontally  ; if set, branch ahead to moving code
    LDA #$00  ; load default value here
    STA $00  ; save into temp variable for now
    LDY #$fa  ; set default vertical speed
    LDA Enemy_Y_Position,x  ; check hammer bro's vertical coordinate
    BMI bra_smb2_main_start_hammer_bro_jump  ; if on the bottom half of the screen, use current speed
    LDY #$fd  ; otherwise set alternate vertical speed
    CMP #$70  ; check to see if hammer bro is above the middle of screen
    INC $00  ; increment preset value to $01
    BCC bra_smb2_main_start_hammer_bro_jump  ; if above the middle of the screen, use current speed and $01
    DEC $00  ; otherwise return value to $00
    LDA PseudoRandomBitReg+1,x  ; get part of LSFR, mask out all but LSB
    AND #$01
    BNE bra_smb2_main_start_hammer_bro_jump  ; if d0 of LSFR set, branch and use current speed and $00
    LDY #$fa  ; otherwise reset to default vertical speed
bra_smb2_main_start_hammer_bro_jump:
    STY Enemy_Y_Speed,x  ; set vertical speed for jumping
    LDA Enemy_State,x  ; set d0 in enemy state for jumping
    ORA #$01
    STA Enemy_State,x
    LDA $00  ; load preset value here to use as bitmask
    AND PseudoRandomBitReg+2,x  ; and do bit-wise comparison with part of LSFR
    TAY  ; then use as offset
    LDA SecondaryHardMode  ; check secondary hard mode flag
    BNE bra_smb2_main_set_hammer_bro_jump_delay
    TAY  ; if secondary hard mode flag clear, set offset to 0
bra_smb2_main_set_hammer_bro_jump_delay:
    LDA off_smb2_main_hammer_bro_jump_delays,y  ; get jump length timer data using offset from before
    STA EnemyFrameTimer,x  ; save in enemy timer
    LDA PseudoRandomBitReg+1,x
    ORA #%11000000  ; get contents of part of LSFR, set d7 and d6, then
    STA HammerBroJumpTimer,x  ; store in jump timer

bra_smb2_main_move_hammer_bro_horizontally:
    LDY #$fc  ; move hammer bro a little to the left
    LDA FrameCounter
    AND #%01000000  ; change hammer bro's direction every 64 frames
    BNE bra_smb2_main_store_hammer_bro_x_speed
    LDY #$04  ; if d6 set in counter, move him a little to the right
bra_smb2_main_store_hammer_bro_x_speed:
    STY Enemy_X_Speed,x  ; store horizontal speed
    LDY #$01  ; set to face right by default
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between player and hammer bro
    BMI bra_smb2_main_store_hammer_bro_facing  ; if enemy to the left of player, skip this part
    INY  ; set to face left
    LDA EnemyIntervalTimer,x  ; check walking timer
    BNE bra_smb2_main_store_hammer_bro_facing  ; if not yet expired, skip to set moving direction
    LDA #$f8
    STA Enemy_X_Speed,x  ; otherwise, make the hammer bro walk left towards player
bra_smb2_main_store_hammer_bro_facing:
    STY Enemy_MovingDir,x  ; set moving direction

sub_smb2_main_move_normal_enemy:
    LDY #$00  ; init Y to leave horizontal movement as-is
    LDA Enemy_State,x
    AND #%01000000  ; check enemy state for d6 set, if set skip
    BNE bra_smb2_main_move_falling_enemy  ; to move enemy vertically, then horizontally if necessary
    LDA Enemy_State,x
    ASL  ; check enemy state for d7 set
    BCS bra_smb2_main_apply_enemy_horizontal_movement  ; if set, branch to move enemy horizontally
    LDA Enemy_State,x
    AND #%00100000  ; check enemy state for d5 set
    BNE bra_smb2_main_move_defeated_enemy  ; if set, branch to move defeated enemy object
    LDA Enemy_State,x
    AND #%00000111  ; check d2-d0 of enemy state for any set bits
    BEQ bra_smb2_main_apply_enemy_horizontal_movement  ; if enemy in normal state, branch to move enemy horizontally
    CMP #$05
    BEQ bra_smb2_main_move_falling_enemy  ; if enemy in state used by spiny's egg, go ahead here
    CMP #$03
    BCS bra_smb2_main_revive_stunned_enemy  ; if enemy in states $03 or $04, skip ahead to yet another part
bra_smb2_main_move_falling_enemy:
    JSR sub_smb2_main_move_enemy_downward_fast  ; do a sub here to move enemy downwards
    LDY #$00
    LDA Enemy_State,x  ; check for enemy state $02
    CMP #$02
    BEQ bra_smb2_main_move_falling_enemy_horizontally  ; if found, branch to move enemy horizontally
    AND #%01000000  ; check for d6 set
    BEQ bra_smb2_main_apply_enemy_horizontal_movement  ; if not set, branch to something else
    LDA Enemy_ID,x
    CMP #PowerUpObject  ; check for power-up object
    BEQ bra_smb2_main_apply_enemy_horizontal_movement
    BNE bra_smb2_main_slow_enemy_horizontal_movement  ; if any other object where d6 set, jump to set Y
bra_smb2_main_move_falling_enemy_horizontally:
    JMP sub_smb2_main_move_enemy_horizontally  ; jump here to move enemy horizontally for <> $2e and d6 set

bra_smb2_main_slow_enemy_horizontal_movement:
    LDY #$01  ; if branched here, increment Y to slow horizontal movement
bra_smb2_main_apply_enemy_horizontal_movement:
    LDA Enemy_X_Speed,x  ; get current horizontal speed
    PHA  ; save to stack
    BPL bra_smb2_main_adjust_enemy_x_speed_temporarily  ; if not moving or moving right, skip, leave Y alone
    INY
    INY  ; otherwise increment Y to next data
bra_smb2_main_adjust_enemy_x_speed_temporarily:
    CLC
    ADC off_smb2_main_enemy_x_speed_adjustments,y  ; add value here to slow enemy down if necessary
    STA Enemy_X_Speed,x  ; save as horizontal speed temporarily
    JSR sub_smb2_main_move_enemy_horizontally  ; then do a sub to move horizontally
    PLA
    STA Enemy_X_Speed,x  ; get old horizontal speed from stack and return to
    RTS  ; original memory location, then leave

bra_smb2_main_revive_stunned_enemy:
    LDA EnemyIntervalTimer,x  ; if enemy timer not expired yet,
    BNE bra_smb2_main_check_stunned_goomba_timeout  ; skip ahead to something else
    STA Enemy_State,x  ; otherwise initialize enemy state to normal
    LDA FrameCounter
    AND #$01  ; get d0 of frame counter
    TAY  ; use as Y and increment for movement direction
    INY
    STY Enemy_MovingDir,x  ; store as pseudorandom movement direction
    DEY  ; decrement for use as pointer
    LDA PrimaryHardMode  ; check primary hard mode flag
    BEQ bra_smb2_main_set_revived_enemy_x_speed  ; if not set, use pointer as-is
    INY
    INY  ; otherwise increment 2 bytes to next data
bra_smb2_main_set_revived_enemy_x_speed:
    LDA tbl_smb2_main_revived_enemy_x_speeds,y  ; load and store new horizontal speed
    STA Enemy_X_Speed,x  ; and leave
    RTS

bra_smb2_main_move_defeated_enemy:
    JSR sub_smb2_main_move_enemy_downward_fast  ; execute sub to move defeated enemy downwards
    JMP sub_smb2_main_move_enemy_horizontally  ; now move defeated enemy horizontally

bra_smb2_main_check_stunned_goomba_timeout:
    CMP #$0e  ; check to see if enemy timer has reached
    BNE bra_smb2_main_exit_stunned_enemy_update  ; a certain point, and branch to leave if not
    LDA Enemy_ID,x
    CMP #Goomba  ; check for goomba object
    BNE bra_smb2_main_exit_stunned_enemy_update  ; branch if not found
    JSR sub_smb2_main_erase_enemy_object  ; otherwise, kill this goomba object
bra_smb2_main_exit_stunned_enemy_update:
    RTS  ; leave!

; --------------------------------
