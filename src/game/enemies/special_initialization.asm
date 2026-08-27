; --------------------------------

tbl_firebar_spin_speeds:
    .byte con_firebar_slow_speed, con_firebar_fast_speed
    .byte con_firebar_slow_speed, con_firebar_fast_speed
    .byte con_firebar_slow_speed

tbl_firebar_spin_directions:
    .byte $00, $00, $10, $10, $00

handler_initialize_long_firebar:
    JSR sub_duplicate_enemy_object  ; create enemy object for long firebar

handler_initialize_short_firebar:
    LDA #$00  ; initialize low byte of spin state
    STA ram_firebar_spin_state_low,x
    LDA ram_enemy_id,x  ; subtract $1b from enemy identifier
    SEC  ; to get proper offset for firebar data
    SBC #$1b
    TAY
    LDA tbl_firebar_spin_speeds,y  ; get spinning speed of firebar
    STA ram_firebar_spin_speed,x
    LDA tbl_firebar_spin_directions,y  ; get spinning direction of firebar
    STA ram_firebar_spin_direction,x
    LDA ram_enemy_y_position,x
    CLC  ; add four pixels to vertical coordinate
    ADC #$04
    STA ram_enemy_y_position,x
    LDA ram_enemy_x_position,x
    CLC  ; add four pixels to horizontal coordinate
    ADC #$04
    STA ram_enemy_x_position,x
    LDA ram_enemy_page_loc,x
    ADC #$00  ; add carry to page location
    STA ram_enemy_page_loc,x
    JMP loc_set_tall_special_enemy_bounding_box  ; set bounding box control (not used) and leave

; --------------------------------
; $00-$01 - used to hold pseudorandom bits

tbl_flying_cheep_cheep_x_offsets:
    .byte $80, $30, $40, $80
    .byte $30, $50, $50, $70
    .byte $20, $40, $80, $a0
    .byte $70, $40, $90, $68

tbl_flying_cheep_cheep_x_speeds:
.if con_revision_profile = con_revision_profile_pal
    .byte $11, $07, $08, $0a
    .byte $23, $28, $15, $10
    .byte $22, $2c, $1f, $1b
.else
    .byte $0e, $05, $06, $0e
    .byte $1c, $20, $10, $0c
    .byte $1e, $22, $18, $14
.endif

tbl_flying_cheep_cheep_spawn_delays:
    .byte $10, $60, $20, $48

handler_initialize_flying_cheep_cheep:
    LDA ram_frenzy_enemy_timer  ; if timer here not expired yet, branch to leave
    BNE bra_exit_enemy_initialization
    JSR sub_initialize_small_enemy_bounding_box  ; jump to set bounding box size $09 and init other values
    LDA ram_pseudo_random_bit_reg+1,x
    AND #%00000011  ; set pseudorandom offset here
    TAY
    LDA tbl_flying_cheep_cheep_spawn_delays,y  ; load timer with pseudorandom offset
    STA ram_frenzy_enemy_timer
    LDY #$03  ; load Y with default value
    LDA ram_secondary_hard_mode
    BEQ bra_set_flying_cheep_cheep_slot_limit  ; if secondary hard mode flag not set, do not increment Y
    INY  ; otherwise, increment Y to allow as many as four onscreen
bra_set_flying_cheep_cheep_slot_limit:
    STY $00  ; store whatever pseudorandom bits are in Y
    CPX $00  ; compare enemy object buffer offset with Y
    BCS bra_exit_enemy_initialization  ; if X => Y, branch to leave
    LDA ram_pseudo_random_bit_reg,x
    AND #%00000011  ; get last two bits of LSFR, first part
    STA $00  ; and store in two places
    STA $01
    LDA #con_flying_cheep_cheep_y_speed  ; set vertical speed for cheep-cheep
    STA ram_enemy_y_speed,x
    LDA #$00  ; load default value
    LDY ram_player_x_speed  ; check player's horizontal speed
    BEQ bra_build_flying_cheep_cheep_random_seed  ; if player not moving left or right, skip this part
    LDA #$04
    CPY #con_flying_cheep_cheep_player_speed_offset  ; if moving to the right but not very quickly,
    BCC bra_build_flying_cheep_cheep_random_seed  ; do not change A
    ASL  ; otherwise, multiply A by 2
bra_build_flying_cheep_cheep_random_seed:
    PHA  ; save to stack
    CLC
    ADC $00  ; add to last two bits of LSFR we saved earlier
    STA $00  ; save it there
    LDA ram_pseudo_random_bit_reg+1,x
    AND #%00000011  ; if neither of the last two bits of second LSFR set,
    BEQ bra_select_flying_cheep_cheep_random_offset  ; skip this part and save contents of $00
    LDA ram_pseudo_random_bit_reg+2,x
    AND #%00001111  ; otherwise overwrite with lower nybble of
    STA $00  ; third LSFR part
bra_select_flying_cheep_cheep_random_offset:
    PLA  ; get value from stack we saved earlier
    CLC
    ADC $01  ; add to last two bits of LSFR we saved in other place
    TAY  ; use as pseudorandom offset here
    LDA tbl_flying_cheep_cheep_x_speeds,y  ; get horizontal speed using pseudorandom offset
    STA ram_enemy_x_speed,x
    LDA #$01  ; set to move towards the right
    STA ram_enemy_moving_dir,x
    LDA ram_player_x_speed  ; if player moving left or right, branch ahead of this part
    BNE bra_choose_flying_cheep_cheep_spawn_side
    LDY $00  ; get first LSFR or third LSFR lower nybble
    TYA  ; and check for d1 set
    AND #%00000010
    BEQ bra_choose_flying_cheep_cheep_spawn_side  ; if d1 not set, branch
    LDA ram_enemy_x_speed,x
    EOR #$ff  ; if d1 set, change horizontal speed
    CLC  ; into two's compliment, thus moving in the opposite
    ADC #$01  ; direction
    STA ram_enemy_x_speed,x
    INC ram_enemy_moving_dir,x  ; increment to move towards the left
bra_choose_flying_cheep_cheep_spawn_side:
    TYA  ; get first LSFR or third LSFR lower nybble again
    AND #%00000010
    BEQ bra_spawn_flying_cheep_cheep_left_of_player  ; check for d1 set again, branch again if not set
    LDA ram_player_x_position  ; get player's horizontal position
    CLC
    ADC tbl_flying_cheep_cheep_x_offsets,y  ; if d1 set, add value obtained from pseudorandom offset
    STA ram_enemy_x_position,x  ; and save as enemy's horizontal position
    LDA ram_player_page_loc  ; get player's page location
    ADC #$00  ; add carry and jump past this part
    JMP loc_finish_flying_cheep_cheep_spawn
bra_spawn_flying_cheep_cheep_left_of_player:
    LDA ram_player_x_position  ; get player's horizontal position
    SEC
    SBC tbl_flying_cheep_cheep_x_offsets,y  ; if d1 not set, subtract value obtained from pseudorandom
    STA ram_enemy_x_position,x  ; offset and save as enemy's horizontal position
    LDA ram_player_page_loc  ; get player's page location
    SBC #$00  ; subtract borrow
loc_finish_flying_cheep_cheep_spawn:
    STA ram_enemy_page_loc,x  ; save as enemy's page location
    LDA #$01
    STA ram_enemy_flag,x  ; set enemy's buffer flag
    STA ram_enemy_y_high_pos,x  ; set enemy's high vertical byte
    LDA #$f8
    STA ram_enemy_y_position,x  ; put enemy below the screen, and we are done
    RTS

; --------------------------------

handler_initialize_bowser:
    JSR sub_duplicate_enemy_object  ; jump to create another bowser object
    STX ram_bowser_front_offset  ; save offset of first here
    LDA #$00
    STA ram_bowser_body_controls  ; initialize bowser's body controls
    STA ram_bridge_collapse_offset  ; and bridge collapse offset
    LDA ram_enemy_x_position,x
    STA ram_bowser_orig_x_pos  ; store original horizontal position here
    LDA #$df
    STA ram_bowser_fire_breath_timer  ; store something here
    STA ram_enemy_moving_dir,x  ; and in moving direction
    LDA #$20
    STA ram_bowser_feet_counter  ; set bowser's feet timer and in enemy timer
    STA ram_enemy_frame_timer,x
    LDA #$05
    STA ram_bowser_hit_points  ; give bowser 5 hit points
    LSR
    STA ram_bowser_movement_speed  ; set default movement speed here
    RTS

; --------------------------------

sub_duplicate_enemy_object:
    LDY #$ff  ; start at beginning of enemy slots
bra_find_duplicate_enemy_slot:
    INY  ; increment one slot
    LDA ram_enemy_flag,y  ; check enemy buffer flag for empty slot
    BNE bra_find_duplicate_enemy_slot  ; if set, branch and keep checking
    STY ram_duplicate_obj_offset  ; otherwise set offset here
    TXA  ; transfer original enemy buffer offset
    ORA #%10000000  ; store with d7 set as flag in new enemy
    STA ram_enemy_flag,y  ; slot as well as enemy offset
    LDA ram_enemy_page_loc,x
    STA ram_enemy_page_loc,y  ; copy page location and horizontal coordinates
    LDA ram_enemy_x_position,x  ; from original enemy to new enemy
    STA ram_enemy_x_position,y
    LDA #$01
    STA ram_enemy_flag,x  ; set flag as normal for original enemy
    STA ram_enemy_y_high_pos,y  ; set high vertical byte for new enemy
    LDA ram_enemy_y_position,x
    STA ram_enemy_y_position,y  ; copy vertical coordinate from original to new
bra_exit_special_enemy_initialization:
    RTS  ; and then leave

; --------------------------------

tbl_bowser_flame_target_y_positions:
    .byte $90, $80, $70, $90

tbl_bowser_flame_y_force_adjustments:
    .byte $ff, $01

handler_initialize_bowser_flame:
    LDA ram_frenzy_enemy_timer  ; if timer not expired yet, branch to leave
    BNE bra_exit_special_enemy_initialization
    STA ram_enemy_y_move_force,x  ; reset something here
    LDA ram_noise_sound_queue
    ORA #con_sfx_bowser_flame  ; load bowser's flame sound into queue
    STA ram_noise_sound_queue
    LDY ram_bowser_front_offset  ; get bowser's buffer offset
    LDA ram_enemy_id,y  ; check for bowser
    CMP #con_bowser
    BEQ bra_spawn_flame_from_bowser_mouth  ; branch if found
    JSR sub_set_flame_timer  ; get timer data based on flame counter
    CLC
    ADC #$20  ; add 32 frames by default
    LDY ram_secondary_hard_mode
    BEQ bra_set_bowser_flame_spawn_delay  ; if secondary mode flag not set, use as timer setting
    SEC
    SBC #$10  ; otherwise subtract 16 frames for secondary hard mode
bra_set_bowser_flame_spawn_delay:
    STA ram_frenzy_enemy_timer  ; set timer accordingly
    LDA ram_pseudo_random_bit_reg,x
    AND #%00000011  ; get 2 LSB from first part of LSFR
    STA ram_bowser_flame_p_random_ofs,x  ; set here
    TAY  ; use as offset
    LDA tbl_bowser_flame_target_y_positions,y  ; load vertical position based on pseudorandom offset

sub_put_at_right_extent:
    STA ram_enemy_y_position,x  ; set vertical position
    LDA ram_screen_right_x_pos
    CLC
    ADC #$20  ; place enemy 32 pixels beyond right side of screen
    STA ram_enemy_x_position,x
    LDA ram_screen_right_page_loc
    ADC #$00  ; add carry
    STA ram_enemy_page_loc,x
    JMP loc_finish_bowser_flame_initialization  ; skip this part to finish setting values

bra_spawn_flame_from_bowser_mouth:
    LDA ram_enemy_x_position,y  ; get bowser's horizontal position
    SEC
    SBC #$0e  ; subtract 14 pixels
    STA ram_enemy_x_position,x  ; save as flame's horizontal position
    LDA ram_enemy_page_loc,y
    STA ram_enemy_page_loc,x  ; copy page location from bowser to flame
    LDA ram_enemy_y_position,y
    CLC  ; add 8 pixels to bowser's vertical position
    ADC #$08
    STA ram_enemy_y_position,x  ; save as flame's vertical position
    LDA ram_pseudo_random_bit_reg,x
    AND #%00000011  ; get 2 LSB from first part of LSFR
    STA ram_enemy_ymf_dummy,x  ; save here
    TAY  ; use as offset
    LDA tbl_bowser_flame_target_y_positions,y  ; get value here using bits as offset
    LDY #$00  ; load default offset
    CMP ram_enemy_y_position,x  ; compare value to flame's current vertical position
    BCC bra_set_bowser_flame_y_force  ; if less, do not increment offset
    INY  ; otherwise increment now
bra_set_bowser_flame_y_force:
    LDA tbl_bowser_flame_y_force_adjustments,y  ; get value here and save
    STA ram_enemy_y_move_force,x  ; to vertical movement force
    LDA #$00
    STA ram_enemy_frenzy_buffer  ; clear enemy frenzy buffer

loc_finish_bowser_flame_initialization:
    LDA #$08  ; set $08 for bounding box control
    STA ram_enemy_bound_box_ctrl,x
    LDA #$01  ; set high byte of vertical and
    STA ram_enemy_y_high_pos,x  ; enemy buffer flag
    STA ram_enemy_flag,x
    LSR
    STA ram_enemy_x_move_force,x  ; initialize horizontal movement force, and
    STA ram_enemy_state,x  ; enemy state
    RTS

; --------------------------------

tbl_fireworks_x_offsets:
    .byte $00, $30, $60, $60, $00, $20

tbl_fireworks_y_positions:
    .byte $60, $40, $70, $40, $60, $30

handler_initialize_fireworks:
    LDA ram_frenzy_enemy_timer  ; if timer not expired yet, branch to leave
    BNE bra_exit_fireworks_initialization
    LDA #$20  ; otherwise reset timer
    STA ram_frenzy_enemy_timer
    DEC ram_fireworks_counter  ; decrement for each explosion
    LDY #$06  ; start at last slot
bra_find_star_flag_for_fireworks:
    DEY
    LDA ram_enemy_id,y  ; check for presence of star flag object
    CMP #con_star_flag_object  ; if there isn't a star flag object,
    BNE bra_find_star_flag_for_fireworks  ; routine goes into infinite loop = crash
    LDA ram_enemy_x_position,y
    SEC  ; get horizontal coordinate of star flag object, then
    SBC #$30  ; subtract 48 pixels from it and save to
    PHA  ; the stack
    LDA ram_enemy_page_loc,y
    SBC #$00  ; subtract the carry from the page location
    STA $00  ; of the star flag object
    LDA ram_fireworks_counter  ; get fireworks counter
    CLC
    ADC ram_enemy_state,y  ; add state of star flag object (possibly not necessary)
    TAY  ; use as offset
    PLA  ; get saved horizontal coordinate of star flag - 48 pixels
    CLC
    ADC tbl_fireworks_x_offsets,y  ; add number based on offset of fireworks counter
    STA ram_enemy_x_position,x  ; store as the fireworks object horizontal coordinate
    LDA $00
    ADC #$00  ; add carry and store as page location for
    STA ram_enemy_page_loc,x  ; the fireworks object
    LDA tbl_fireworks_y_positions,y  ; get vertical position using same offset
    STA ram_enemy_y_position,x  ; and store as vertical coordinate for fireworks object
    LDA #$01
    STA ram_enemy_y_high_pos,x  ; store in vertical high byte
    STA ram_enemy_flag,x  ; and activate enemy buffer flag
    LSR
    STA ram_explosion_gfx_counter,x  ; initialize explosion counter
    LDA #$08
    STA ram_explosion_timer_counter,x  ; set explosion timing counter
bra_exit_fireworks_initialization:
    RTS

; --------------------------------

tbl_enemy_slot_bit_masks:
    .byte %00000001, %00000010, %00000100, %00001000, %00010000, %00100000, %01000000, %10000000

tbl_frenzy_enemy_y_positions:
    .byte $40, $30, $90, $50, $20, $60, $a0, $70

tbl_swimming_cheep_cheep_ids:
    .byte $0a, $0b

handler_spawn_bullet_bill_or_cheep_cheep:
    LDA ram_frenzy_enemy_timer  ; if timer not expired yet, branch to leave
    BNE bra_exit_frenzy_enemy_spawn
    LDA ram_area_type  ; are we in a water-type level?
    BNE bra_spawn_bullet_bill_frenzy  ; if not, branch elsewhere
    CPX #$03  ; are we past third enemy slot?
    BCS bra_exit_frenzy_enemy_spawn  ; if so, branch to leave
    LDY #$00  ; load default offset
    LDA ram_pseudo_random_bit_reg,x
    CMP #$aa  ; check first part of LSFR against preset value
    BCC bra_select_swimming_cheep_cheep_variant  ; if less than preset, do not increment offset
    INY  ; otherwise increment
bra_select_swimming_cheep_cheep_variant:
    LDA ram_world_number  ; check world number
    CMP #con_world2
    BEQ bra_load_swimming_cheep_cheep_id  ; if we're on world 2, do not increment offset
    INY  ; otherwise increment
bra_load_swimming_cheep_cheep_id:
    TYA
    AND #%00000001  ; mask out all but last bit of offset
    TAY
    LDA tbl_swimming_cheep_cheep_ids,y  ; load identifier for cheep-cheeps
bra_store_generated_frenzy_enemy_id:
    STA ram_enemy_id,x  ; store whatever's in A as enemy identifier
    LDA ram_bit_m_filter
    CMP #$ff  ; if not all bits set, skip init part and compare bits
    BNE bra_select_frenzy_enemy_y_slot
    LDA #$00  ; initialize vertical position filter
    STA ram_bit_m_filter
bra_select_frenzy_enemy_y_slot:
    LDA ram_pseudo_random_bit_reg,x  ; get first part of LSFR
    AND #%00000111  ; mask out all but 3 LSB
loc_find_unused_frenzy_enemy_y_slot:
    TAY  ; use as offset
    LDA tbl_enemy_slot_bit_masks,y  ; load bitmask
    BIT ram_bit_m_filter  ; perform AND on filter without changing it
    BEQ bra_reserve_frenzy_enemy_y_slot
    INY  ; increment offset
    TYA
    AND #%00000111  ; mask out all but 3 LSB thus keeping it 0-7
    JMP loc_find_unused_frenzy_enemy_y_slot  ; do another check
bra_reserve_frenzy_enemy_y_slot:
    ORA ram_bit_m_filter  ; add bit to already set bits in filter
    STA ram_bit_m_filter  ; and store
    LDA tbl_frenzy_enemy_y_positions,y  ; load vertical position using offset
    JSR sub_put_at_right_extent  ; set vertical position and other values
    STA ram_enemy_ymf_dummy,x  ; initialize dummy variable
    LDA #$20  ; set timer
    STA ram_frenzy_enemy_timer
    JMP sub_checkpoint_enemy_id  ; process our new enemy object

bra_spawn_bullet_bill_frenzy:
    LDY #$ff  ; start at beginning of enemy slots
bra_find_active_frenzy_bullet_bill:
    INY  ; move onto the next slot
    CPY #$05  ; branch to play sound if we've done all slots
    BCS bra_fire_frenzy_bullet_bill
    LDA ram_enemy_flag,y  ; if enemy buffer flag not set,
    BEQ bra_find_active_frenzy_bullet_bill  ; loop back and check another slot
    LDA ram_enemy_id,y
    CMP #con_bullet_bill_frenzy_var  ; check enemy identifier for
    BNE bra_find_active_frenzy_bullet_bill  ; bullet bill object (frenzy variant)
bra_exit_frenzy_enemy_spawn:
    RTS  ; if found, leave

bra_fire_frenzy_bullet_bill:
    LDA ram_square2_sound_queue
    ORA #con_sfx_blast  ; play fireworks/gunfire sound
    STA ram_square2_sound_queue
    LDA #con_bullet_bill_frenzy_var  ; load identifier for bullet bill object
    BNE bra_store_generated_frenzy_enemy_id  ; unconditional branch

; --------------------------------
; $00 - used to store Y position of group enemies
; $01 - used to store enemy ID
; $02 - used to store page location of right side of screen
; $03 - used to store X position of right side of screen

loc_spawn_enemy_group:
    LDY #$00  ; load value for green koopa troopa
    SEC
    SBC #$37  ; subtract $37 from second byte read
    PHA  ; save result in stack for now
    CMP #$04  ; was byte in $3b-$3e range?
    BCS bra_store_group_enemy_type  ; if so, branch
    PHA  ; save another copy to stack
    LDY #con_goomba  ; load value for goomba enemy
    LDA ram_primary_hard_mode  ; if primary hard mode flag not set,
    BEQ bra_restore_group_enemy_type  ; branch, otherwise change to value
    LDY #con_buzzy_beetle  ; for buzzy beetle
bra_restore_group_enemy_type:
    PLA  ; get second copy from stack
bra_store_group_enemy_type:
    STY $01  ; save enemy id here
    LDY #$b0  ; load default y coordinate
    AND #$02  ; check to see if d1 was set
    BEQ bra_store_group_enemy_y_position  ; if so, move y coordinate up,
    LDY #$70  ; otherwise branch and use default
bra_store_group_enemy_y_position:
    STY $00  ; save y coordinate here
    LDA ram_screen_right_page_loc  ; get page number of right edge of screen
    STA $02  ; save here
    LDA ram_screen_right_x_pos  ; get pixel coordinate of right edge
    STA $03  ; save here
    LDY #$02  ; load two enemies by default
    PLA  ; get first copy from stack
    LSR  ; check to see if d0 was set
    BCC bra_store_group_enemy_count  ; if not, use default value
    INY  ; otherwise increment to three enemies
bra_store_group_enemy_count:
    STY ram_numberof_group_enemies  ; save number of enemies here
bra_spawn_enemy_group_loop:
    LDX #$ff  ; start at beginning of enemy buffers
bra_find_enemy_group_slot:
    INX  ; increment and branch if past
    CPX #$05  ; end of buffers
    BCS bra_finish_enemy_group_command
    LDA ram_enemy_flag,x  ; check to see if enemy is already
    BNE bra_find_enemy_group_slot  ; stored in buffer, and branch if so
    LDA $01
    STA ram_enemy_id,x  ; store enemy object identifier
    LDA $02
    STA ram_enemy_page_loc,x  ; store page location for enemy object
    LDA $03
    STA ram_enemy_x_position,x  ; store x coordinate for enemy object
    CLC
    ADC #$18  ; add 24 pixels for next enemy
    STA $03
    LDA $02  ; add carry to page location for
    ADC #$00  ; next enemy
    STA $02
    LDA $00  ; store y coordinate for enemy object
    STA ram_enemy_y_position,x
    LDA #$01  ; activate flag for buffer, and
    STA ram_enemy_y_high_pos,x  ; put enemy within the screen vertically
    STA ram_enemy_flag,x
    JSR sub_checkpoint_enemy_id  ; process each enemy object separately
    DEC ram_numberof_group_enemies  ; do this until we run out of enemy objects
    BNE bra_spawn_enemy_group_loop
bra_finish_enemy_group_command:
    JMP loc_advance_enemy_stream_two_bytes  ; jump to increment data offset and leave

; --------------------------------

sub_initialize_piranha_plant:
    LDA #$01  ; set initial speed
    STA ram_piranha_plant_y_speed,x
    LSR
    STA ram_enemy_state,x  ; initialize enemy state and what would normally
    STA ram_piranha_plant_move_flag,x  ; be used as vertical speed, but not in this case
    LDA ram_enemy_y_position,x
    STA ram_piranha_plant_down_y_pos,x  ; save original vertical coordinate here
    SEC
    SBC #$18
    STA ram_piranha_plant_up_y_pos,x  ; save original vertical coordinate - 24 pixels here
    LDA #$09
    JMP loc_set_special_enemy_bounding_box  ; set specific value for bounding box control

; --------------------------------

handler_initialize_enemy_frenzy:
    LDA ram_enemy_id,x  ; load enemy identifier
    STA ram_enemy_frenzy_buffer  ; save in enemy frenzy buffer
    SEC
    SBC #$12  ; subtract 12 and use as offset for jump engine
    JSR sub_dispatch_inline_handler

; frenzy object jump table
    .word handler_spawn_lakitu_or_spiny
    .word handler_no_frenzy_initialization
    .word handler_initialize_flying_cheep_cheep
    .word handler_initialize_bowser_flame
    .word handler_initialize_fireworks
    .word handler_spawn_bullet_bill_or_cheep_cheep

; --------------------------------

handler_no_frenzy_initialization:
    RTS

; --------------------------------

handler_end_enemy_frenzy:
    LDY #$05  ; start at last slot
bra_find_lakitu_to_end_frenzy:
    LDA ram_enemy_id,y  ; check enemy identifiers
    CMP #con_lakitu  ; for lakitu
    BNE bra_check_next_lakitu_slot
    LDA #$01  ; if found, set state
    STA ram_enemy_state,y
bra_check_next_lakitu_slot:
    DEY  ; move onto the next slot
    BPL bra_find_lakitu_to_end_frenzy  ; do this until all slots are checked
    LDA #$00
    STA ram_enemy_frenzy_buffer  ; empty enemy frenzy buffer
    STA ram_enemy_flag,x  ; disable enemy buffer flag for this object
    RTS

; --------------------------------

handler_initialize_jumping_green_paratroopa:
    LDA #$02  ; set for movement to the left
    STA ram_enemy_moving_dir,x
    LDA #con_hammer_bro_chase_x_speed  ; set horizontal speed
    STA ram_enemy_x_speed,x
loc_set_tall_special_enemy_bounding_box:
    LDA #$03  ; set specific value for bounding box control
loc_set_special_enemy_bounding_box:
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box control then leave
    RTS

; --------------------------------

handler_initialize_balance_platform:
    DEC ram_enemy_y_position,x  ; raise vertical position by two pixels
    DEC ram_enemy_y_position,x
    LDY ram_secondary_hard_mode  ; if secondary hard mode flag not set,
    BNE bra_link_balance_platform  ; branch ahead
    LDY #$02  ; otherwise set value here
    JSR sub_offset_platform_x_position  ; do a sub to add or subtract pixels
bra_link_balance_platform:
    LDY #$ff  ; set default value here for now
    LDA ram_bal_platform_alignment  ; get current balance platform alignment
    STA ram_enemy_state,x  ; set platform alignment to object state here
    BPL bra_store_balance_platform_alignment  ; if old alignment $ff, put $ff as alignment for negative
    TXA  ; if old contents already $ff, put
    TAY  ; object offset as alignment to make next positive
bra_store_balance_platform_alignment:
    STY ram_bal_platform_alignment  ; store whatever value's in Y here
    LDA #$00
    STA ram_enemy_moving_dir,x  ; init moving direction
    TAY  ; init Y
    JSR sub_offset_platform_x_position  ; do a sub to add 8 pixels, then run shared code here

; --------------------------------

handler_initialize_drop_platform:
    LDA #$ff
    STA ram_platform_collision_flag,x  ; set some value here
    JMP loc_initialize_platform  ; then jump ahead to execute more code

; --------------------------------

handler_initialize_horizontal_platform:
    LDA #$00
    STA ram_x_move_secondary_counter,x  ; init one of the moving counters
    JMP loc_initialize_platform  ; jump ahead to execute more code

; --------------------------------

handler_initialize_vertical_platform:
    LDY #$40  ; set default value here
    LDA ram_enemy_y_position,x  ; check vertical position
    BPL bra_compute_vertical_platform_center  ; if above a certain point, skip this part
    EOR #$ff
    CLC  ; otherwise get two's compliment
    ADC #$01
    LDY #$c0  ; get alternate value to add to vertical position
bra_compute_vertical_platform_center:
    STA ram_y_platform_top_y_pos,x  ; save as top vertical position
    TYA
    CLC  ; load value from earlier, add number of pixels
    ADC ram_enemy_y_position,x  ; to vertical position
    STA ram_y_platform_center_y_pos,x  ; save result as central vertical position

; --------------------------------

loc_initialize_platform:
    JSR sub_clear_enemy_vertical_motion  ; do a sub to init certain other values
loc_set_platform_bounding_box:
    LDA #$05  ; set default bounding box size control
    LDY ram_area_type
    CPY #$03  ; check for castle-type level
    BEQ bra_store_platform_bounding_box  ; use default value if found
    LDY ram_secondary_hard_mode  ; otherwise check for secondary hard mode flag
    BNE bra_store_platform_bounding_box  ; if set, use default value
    LDA #$06  ; use alternate value if not castle or secondary not set
bra_store_platform_bounding_box:
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box size control here and leave
    RTS

; --------------------------------

handler_initialize_large_lift_up:
    JSR sub_initialize_platform_lift_up  ; execute code for platforms going up
    JMP loc_set_large_lift_bounding_box  ; overwrite bounding box for large platforms

handler_initialize_large_lift_down:
    JSR sub_initialize_platform_lift_down  ; execute code for platforms going down

loc_set_large_lift_bounding_box:
    JMP loc_set_platform_bounding_box  ; jump to overwrite bounding box size control

; --------------------------------

sub_initialize_platform_lift_up:
    LDA #$10  ; set movement amount here
    STA ram_enemy_y_move_force,x
    LDA #$ff  ; set moving speed for platforms going up
    STA ram_enemy_y_speed,x
    JMP loc_initialize_small_lift  ; skip ahead to part we should be executing

; --------------------------------

sub_initialize_platform_lift_down:
    LDA #$f0  ; set movement amount here
    STA ram_enemy_y_move_force,x
    LDA #$00  ; set moving speed for platforms going down
    STA ram_enemy_y_speed,x

; --------------------------------

loc_initialize_small_lift:
    LDY #$01
    JSR sub_offset_platform_x_position  ; do a sub to add 12 pixels due to preset value
    LDA #$04
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box control for small platforms
    RTS

; --------------------------------

tbl_platform_x_offsets_low:
    .byte $08,$0c,$f8

tbl_platform_x_offsets_high:
    .byte $00,$00,$ff

sub_offset_platform_x_position:
    LDA ram_enemy_x_position,x  ; get horizontal coordinate
    CLC
    ADC tbl_platform_x_offsets_low,y  ; add or subtract pixels depending on offset
    STA ram_enemy_x_position,x  ; store as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    ADC tbl_platform_x_offsets_high,y  ; add or subtract page location depending on offset
    STA ram_enemy_page_loc,x  ; store as new page location
    RTS  ; and go back

; --------------------------------

handler_end_enemy_initialization:
    RTS
