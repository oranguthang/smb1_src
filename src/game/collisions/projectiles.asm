; -------------------------------------------------------------------------------------
; $01 - enemy buffer offset

.if con_revision_profile = con_revision_profile_vs
    .res 23, $ff  ; retained arcade alignment bytes
.endif
sub_fireball_enemy_collision:
    LDA ram_fireball_state,x  ; check to see if fireball state is set at all
    BEQ bra_exit_fireball_enemy_collision  ; branch to leave if not
    ASL
    BCS bra_exit_fireball_enemy_collision  ; branch to leave also if d7 in state is set
    LDA ram_frame_counter
    LSR  ; get LSB of frame counter
    BCS bra_exit_fireball_enemy_collision  ; branch to leave if set (do routine every other frame)
    TXA
    ASL  ; multiply fireball offset by four
    ASL
    CLC
    ADC #$1c  ; then add $1c or 28 bytes to it
    TAY  ; to use fireball's bounding box coordinates
    LDX #$04

bra_check_fireball_enemy_collision_loop:
    STX $01  ; store enemy object offset here
    TYA
    PHA  ; push fireball offset to the stack
    LDA ram_enemy_state,x
    AND #%00100000  ; check to see if d5 is set in enemy state
    BNE bra_advance_fireball_enemy_collision  ; if so, skip to next enemy slot
    LDA ram_enemy_flag,x  ; check to see if buffer flag is set
    BEQ bra_advance_fireball_enemy_collision  ; if not, skip to next enemy slot
    LDA ram_enemy_id,x  ; check enemy identifier
    CMP #$24
    BCC bra_defeat_goomba_with_fireball  ; if < $24, branch to check further
    CMP #$2b
    BCC bra_advance_fireball_enemy_collision  ; if in range $24-$2a, skip to next enemy slot
bra_defeat_goomba_with_fireball:
    CMP #con_goomba  ; check for goomba identifier
    BNE bra_defeat_non_goomba_with_fireball  ; if not found, continue with code
    LDA ram_enemy_state,x  ; otherwise check for defeated state
    CMP #$02  ; if stomped or otherwise defeated,
    BCS bra_advance_fireball_enemy_collision  ; skip to next enemy slot
bra_defeat_non_goomba_with_fireball:
    LDA ram_enemy_offscr_bits_masked,x  ; if any masked offscreen bits set,
    BNE bra_advance_fireball_enemy_collision  ; skip to next enemy slot
    TXA
    ASL  ; otherwise multiply enemy offset by four
    ASL
    CLC
    ADC #$04  ; add 4 bytes to it
    TAX  ; to use enemy's bounding box coordinates
    JSR sub_sprite_object_collision_core  ; do fireball-to-enemy collision detection
    LDX ram_object_offset  ; return fireball's original offset
    BCC bra_advance_fireball_enemy_collision  ; if carry clear, no collision, thus do next enemy slot
    LDA #%10000000
    STA ram_fireball_state,x  ; set d7 in enemy state
    LDX $01  ; get enemy offset
    JSR sub_handle_enemy_fireball_collision  ; jump to handle fireball to enemy collision
bra_advance_fireball_enemy_collision:
    PLA  ; pull fireball offset from stack
    TAY  ; put it in Y
    LDX $01  ; get enemy object offset
    DEX  ; decrement it
    BPL bra_check_fireball_enemy_collision_loop  ; loop back until collision detection done on all enemies

bra_exit_fireball_enemy_collision:
    LDX ram_object_offset  ; get original fireball offset and leave
    RTS

tbl_bowser_disguise_enemy_ids:
    .byte con_goomba, con_green_koopa, con_buzzy_beetle, con_spiny, con_lakitu, con_bloober, con_hammer_bro, con_bowser

sub_handle_enemy_fireball_collision:
    JSR sub_relative_enemy_position  ; get relative coordinate of enemy
    LDX $01  ; get current enemy object offset
    LDA ram_enemy_flag,x  ; check buffer flag for d7 set
    BPL bra_check_buzzy_beetle_fireball_immunity  ; branch if not set to continue
    AND #%00001111  ; otherwise mask out high nybble and
    TAX  ; use low nybble as enemy offset
    LDA ram_enemy_id,x
    CMP #con_bowser  ; check enemy identifier for bowser
    BEQ bra_damage_bowser_with_fireball  ; branch if found
    LDX $01  ; otherwise retrieve current enemy offset

bra_check_buzzy_beetle_fireball_immunity:
    LDA ram_enemy_id,x
    CMP #con_buzzy_beetle  ; check for buzzy beetle
    BEQ bra_exit_enemy_fireball_collision  ; branch if found to leave (buzzy beetles fireproof)
    CMP #con_bowser  ; check for bowser one more time (necessary if d7 of flag was clear)
    BNE bra_check_other_fireball_enemy_targets  ; if not found, branch to check other enemies

bra_damage_bowser_with_fireball:
    DEC ram_bowser_hit_points  ; decrement bowser's hit points
    BNE bra_exit_enemy_fireball_collision  ; if bowser still has hit points, branch to leave
    JSR sub_clear_enemy_vertical_motion  ; otherwise do sub to init vertical speed and movement force
    STA ram_enemy_x_speed,x  ; initialize horizontal speed
    STA ram_enemy_frenzy_buffer  ; init enemy frenzy buffer
    LDA #$fe
    STA ram_enemy_y_speed,x  ; set vertical speed to make defeated bowser jump a little
    LDY ram_world_number  ; use world number as offset
    LDA tbl_bowser_disguise_enemy_ids,y  ; get enemy identifier to replace bowser with
    STA ram_enemy_id,x  ; set as new enemy identifier
    LDA #$20  ; set A to use starting value for state
    CPY #$03  ; check to see if using offset of 3 or more
    BCS bra_store_defeated_bowser_state  ; branch if so
    ORA #$03  ; otherwise add 3 to enemy state
bra_store_defeated_bowser_state:
    STA ram_enemy_state,x  ; set defeated enemy state
    LDA #con_sfx_bowser_fall
    STA ram_square2_sound_queue  ; load bowser defeat sound
    LDX $01  ; get enemy offset
    LDA #$09  ; award 5000 points to player for defeating bowser
    BNE bra_award_enemy_defeat_score  ; unconditional branch to award points

bra_check_other_fireball_enemy_targets:
    CMP #con_bullet_bill_frenzy_var
    BEQ bra_exit_enemy_fireball_collision  ; branch to leave if bullet bill (frenzy variant)
    CMP #con_podoboo
    BEQ bra_exit_enemy_fireball_collision  ; branch to leave if podoboo
    CMP #$15
    BCS bra_exit_enemy_fireball_collision  ; branch to leave if identifier => $15

sub_shell_or_block_defeat:
    LDA ram_enemy_id,x  ; check for piranha plant
    CMP #con_piranha_plant
    BNE bra_stun_enemy_from_attack  ; branch if not found
    LDA ram_enemy_y_position,x
    ADC #$18  ; add 24 pixels to enemy object's vertical position
    STA ram_enemy_y_position,x
bra_stun_enemy_from_attack:
    JSR sub_check_enemy_stun_eligibility  ; do yet another sub
    LDA ram_enemy_state,x
    AND #%00011111  ; mask out 2 MSB of enemy object's state
    ORA #%00100000  ; set d5 to defeat enemy and save as new state
    STA ram_enemy_state,x
    LDA #$02  ; award 200 points by default
    LDY ram_enemy_id,x  ; check for hammer bro
    CPY #con_hammer_bro
    BNE bra_award_goomba_fireball_points  ; branch if not found
    LDA #$06  ; award 1000 points for hammer bro

bra_award_goomba_fireball_points:
    CPY #con_goomba  ; check for goomba
    BNE bra_award_enemy_defeat_score  ; branch if not found
    LDA #$01  ; award 100 points for goomba

bra_award_enemy_defeat_score:
    JSR sub_setup_floatey_number  ; update necessary score variables
    LDA #con_sfx_enemy_smack  ; play smack enemy sound
    STA ram_square1_sound_queue
bra_exit_enemy_fireball_collision:
    RTS  ; and now let's leave

; -------------------------------------------------------------------------------------

sub_player_hammer_collision:
    LDA ram_frame_counter  ; get frame counter
    LSR  ; shift d0 into carry
    BCC bra_exit_player_hammer_collision  ; branch to leave if d0 not set to execute every other frame
    LDA ram_timer_control  ; if either master timer control
    ORA ram_misc_offscreen_bits  ; or any offscreen bits for hammer are set,
    BNE bra_exit_player_hammer_collision  ; branch to leave
    TXA
    ASL  ; multiply misc object offset by four
    ASL
    CLC
    ADC #$24  ; add 36 or $24 bytes to get proper offset
    TAY  ; for misc object bounding box coordinates
    JSR sub_player_collision_core  ; do player-to-hammer collision detection
    LDX ram_object_offset  ; get misc object offset
    BCC bra_clear_hammer_collision_flag  ; if no collision, then branch
    LDA ram_misc_collision_flag,x  ; otherwise read collision flag
    BNE bra_exit_player_hammer_collision  ; if collision flag already set, branch to leave
    LDA #$01
    STA ram_misc_collision_flag,x  ; otherwise set collision flag now
    LDA ram_misc_x_speed,x
    EOR #$ff  ; get two's compliment of
    CLC  ; hammer's horizontal speed
    ADC #$01
    STA ram_misc_x_speed,x  ; set to send hammer flying the opposite direction
    LDA ram_star_invincible_timer  ; if star mario invincibility timer set,
    BNE bra_exit_player_hammer_collision  ; branch to leave
    JMP sub_injure_player  ; otherwise jump to hurt player, do not return
bra_clear_hammer_collision_flag:
    LDA #$00  ; clear collision flag
    STA ram_misc_collision_flag,x
bra_exit_player_hammer_collision:
    RTS

; -------------------------------------------------------------------------------------

loc_handle_power_up_collision:
    JSR sub_erase_enemy_object  ; erase the power-up object
    LDA #$06
    JSR sub_setup_floatey_number  ; award 1000 points to player by default
    LDA #con_sfx_power_up_grab
    STA ram_square2_sound_queue  ; play the power-up sound
    LDA ram_power_up_type  ; check power-up type
    CMP #$02
    BCC bra_apply_mushroom_or_flower_power_up  ; if mushroom or fire flower, branch
    CMP #$03
    BEQ bra_award_extra_life_power_up  ; if 1-up mushroom, branch
    LDA #$23  ; otherwise set star mario invincibility
    STA ram_star_invincible_timer  ; timer, and load the star mario music
.if con_revision_profile = con_revision_profile_vs
    LDA #con_cloud_music  ; the arcade star reuses the cloud-theme request
.else
    LDA #con_star_power_music  ; into the area music queue, then leave
.endif
    STA ram_area_music_queue
    RTS

bra_apply_mushroom_or_flower_power_up:
    LDA ram_player_status  ; if player status = small, branch
    BEQ bra_upgrade_player_to_super
    CMP #$01  ; if player status not super, leave
    BNE bra_exit_power_up_collection
    LDX ram_object_offset  ; get enemy offset, not necessary
    LDA #$02  ; set player status to fiery
    STA ram_player_status
    JSR sub_get_player_colors  ; run sub to change colors of player
    LDX ram_object_offset  ; get enemy offset again, and again not necessary
    LDA #$0c  ; set value to be used by subroutine tree (fiery)
    JMP loc_start_player_power_up_transition  ; jump to set values accordingly

bra_award_extra_life_power_up:
    LDA #$0b  ; change 1000 points into 1-up instead
    STA ram_floatey_num_control,x  ; and then leave
    RTS

bra_upgrade_player_to_super:
    LDA #$01  ; set player status to super
    STA ram_player_status
    LDA #$09  ; set value to be used by subroutine tree (super)

loc_start_player_power_up_transition:
    LDY #$00  ; set value to be used as new player state
    JSR sub_set_player_routine_state  ; set values to stop certain things in motion
bra_exit_power_up_collection:
    RTS
