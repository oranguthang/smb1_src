; -------------------------------------------------------------------------------------
; $06-$07 - address from block buffer routine

tbl_enemy_background_collision_states:
    .byte $01, $01, $02, $02, $02, $05

tbl_enemy_background_collision_x_speeds:
    .byte $10, $f0

sub_detect_enemy_background_collision:
    LDA ram_enemy_state,x  ; check enemy state for d6 set
    AND #%00100000
    BNE bra_exit_player_background_metatile_lookup  ; if set, branch to leave
    JSR sub_adjust_enemy_y_for_floor_check  ; otherwise, do a subroutine here
    BCC bra_exit_player_background_metatile_lookup  ; if enemy vertical coord + 62 < 68, branch to leave
    LDY ram_enemy_id,x
    CPY #con_spiny  ; if enemy object is not spiny, branch elsewhere
    BNE bra_dispatch_enemy_background_collision_behavior
    LDA ram_enemy_y_position,x
    CMP #$25  ; if enemy vertical coordinate < 36 branch to leave
    BCC bra_exit_player_background_metatile_lookup

bra_dispatch_enemy_background_collision_behavior:
    CPY #con_green_paratroopa_jump  ; check for some other enemy object
    BNE bra_check_hammer_bro_background_collision  ; branch if not found
    JMP sub_enemy_jump  ; otherwise jump elsewhere
bra_check_hammer_bro_background_collision:
    CPY #con_hammer_bro  ; check for hammer bro
    BNE bra_check_enemy_background_collision_eligibility  ; branch if not found
    JMP loc_handle_hammer_bro_background_collision  ; otherwise jump elsewhere
bra_check_enemy_background_collision_eligibility:
    CPY #con_spiny  ; if enemy object is spiny, branch
    BEQ bra_check_metatile_under_enemy
    CPY #con_power_up_object  ; if special power-up object, branch
    BEQ bra_check_metatile_under_enemy
    CPY #$07  ; if enemy object =>$07, branch to leave
    BCS bra_exit_enemy_background_collision
bra_check_metatile_under_enemy:
    JSR sub_check_metatile_under_enemy  ; if enemy object < $07, or = $12 or $2e, do this sub
    BNE bra_handle_enemy_floor_collision  ; if block underneath enemy, branch

bra_handle_enemy_without_floor_collision:
    JMP loc_check_red_koopa_edge  ; otherwise skip and do something else

; --------------------------------
; $02 - vertical coordinate from block buffer routine

bra_handle_enemy_floor_collision:
    JSR sub_check_non_solid_enemy_metatile  ; if something is underneath enemy, find out what
    BEQ bra_handle_enemy_without_floor_collision  ; if blank $26, coins, or hidden blocks, jump, enemy falls through
    CMP #$23
    BNE bra_land_enemy_on_metatile  ; check for blank metatile $23 and branch if not found
    LDY $02  ; get vertical coordinate used to find block
    LDA #$00  ; store default blank metatile in that spot so we won't
    STA ($06),y  ; trigger this routine accidentally again
    LDA ram_enemy_id,x
    CMP #$15  ; if enemy object => $15, branch ahead
    BCS sub_check_enemy_stun_eligibility
    CMP #con_goomba  ; if enemy object not goomba, branch ahead of this routine
    BNE bra_award_block_hit_enemy_points
    JSR sub_kill_enemy_above_block  ; if enemy object IS goomba, do this sub

bra_award_block_hit_enemy_points:
    LDA #$01  ; award 100 points for hitting block beneath enemy
    JSR sub_setup_floatey_number

sub_check_enemy_stun_eligibility:
    CMP #$09  ; perform many comparisons on enemy object identifier
    BCC sub_set_stun
    CMP #$11  ; if the enemy object identifier is equal to the values
    BCS sub_set_stun  ; $09, $0e, $0f or $10, it will be modified, and not
    CMP #$0a  ; modified if not any of those values, note that piranha plant will
    BCC bra_demote_stunned_enemy  ; always fail this test because A will still have vertical
    CMP #con_piranha_plant  ; coordinate from previous addition, also these comparisons
    BCC sub_set_stun  ; are only necessary if branching from $d7a1
bra_demote_stunned_enemy:
    AND #%00000001  ; erase all but LSB, essentially turning enemy object
    STA ram_enemy_id,x  ; into green or red koopa troopa to demote them
sub_set_stun:
    LDA ram_enemy_state,x  ; load enemy state
    AND #%11110000  ; save high nybble
    ORA #%00000010
    STA ram_enemy_state,x  ; set d1 of enemy state
    DEC ram_enemy_y_position,x
    DEC ram_enemy_y_position,x  ; subtract two pixels from enemy's vertical position
    LDA ram_enemy_id,x
    CMP #con_bloober  ; check for bloober object
    BEQ bra_use_water_stun_y_speed
    LDA #$fd  ; set default vertical speed
    LDY ram_area_type
    BNE bra_store_stunned_enemy_y_speed  ; if area type not water, set as speed, otherwise
bra_use_water_stun_y_speed:
    LDA #$ff  ; change the vertical speed
bra_store_stunned_enemy_y_speed:
    STA ram_enemy_y_speed,x  ; set vertical speed now
    LDY #$01
    JSR sub_player_enemy_diff  ; get horizontal difference between player and enemy object
    BPL bra_check_stunned_bullet_bill  ; branch if enemy is to the right of player
    INY  ; increment Y if not
bra_check_stunned_bullet_bill:
    LDA ram_enemy_id,x
    CMP #con_bullet_bill_cannon_var  ; check for bullet bill (cannon variant)
    BEQ bra_preserve_bullet_bill_direction
    CMP #con_bullet_bill_frenzy_var  ; check for bullet bill (frenzy variant)
    BEQ bra_preserve_bullet_bill_direction  ; branch if either found, direction does not change
    STY ram_enemy_moving_dir,x  ; store as moving direction
bra_preserve_bullet_bill_direction:
    DEY  ; decrement and use as offset
    LDA tbl_enemy_background_collision_x_speeds,y  ; get proper horizontal speed
    STA ram_enemy_x_speed,x  ; and store, then leave
bra_exit_enemy_background_collision:
    RTS

; --------------------------------
; $04 - low nybble of vertical coordinate from block buffer routine

bra_land_enemy_on_metatile:
    LDA $04  ; check lower nybble of vertical coordinate saved earlier
    SEC
    SBC #$08  ; subtract eight pixels
    CMP #$05  ; used to determine whether enemy landed from falling
    BCS loc_check_red_koopa_edge  ; branch if lower nybble in range of $0d-$0f before subtract
    LDA ram_enemy_state,x
    AND #%01000000  ; branch if d6 in enemy state is set
    BNE bra_land_enemy_and_initialize_state
    LDA ram_enemy_state,x
    ASL  ; branch if d7 in enemy state is not set
    BCC bra_check_landed_enemy_state
bra_run_enemy_side_collision_check:
    JMP loc_check_enemy_side_collisions  ; if lower nybble < $0d, d7 set but d6 not set, jump here

bra_check_landed_enemy_state:
    LDA ram_enemy_state,x  ; if enemy in normal state, branch back to jump here
    BEQ bra_run_enemy_side_collision_check
    CMP #$05  ; if in state used by spiny's egg
    BEQ bra_update_landed_enemy_direction  ; then branch elsewhere
    CMP #$03  ; if already in state used by koopas and buzzy beetles
    BCS bra_exit_landed_enemy_state_check  ; or in higher numbered state, branch to leave
    LDA ram_enemy_state,x  ; load enemy state again (why?)
    CMP #$02  ; if not in $02 state (used by koopas and buzzy beetles)
    BNE bra_update_landed_enemy_direction  ; then branch elsewhere
    LDA #$10  ; load default timer here
    LDY ram_enemy_id,x  ; check enemy identifier for spiny
    CPY #con_spiny
    BNE bra_store_stunned_enemy_timer  ; branch if not found
    LDA #$00  ; set timer for $00 if spiny
bra_store_stunned_enemy_timer:
    STA ram_enemy_interval_timer,x  ; set timer here
    LDA #$03  ; set state here, apparently used to render
    STA ram_enemy_state,x  ; upside-down koopas and buzzy beetles
    JSR sub_enemy_landing  ; then land it properly
bra_exit_landed_enemy_state_check:
    RTS  ; then leave

bra_update_landed_enemy_direction:
    LDA ram_enemy_id,x  ; check enemy identifier for goomba
    CMP #con_goomba  ; branch if found
    BEQ bra_land_enemy_and_initialize_state
    CMP #con_spiny  ; check for spiny
    BNE bra_face_landed_enemy_toward_player  ; branch if not found
    LDA #$01
    STA ram_enemy_moving_dir,x  ; send enemy moving to the right by default
    LDA #$08
    STA ram_enemy_x_speed,x  ; set horizontal speed accordingly
    LDA ram_frame_counter
    AND #%00000111  ; if timed appropriately, spiny will skip over
    BEQ bra_land_enemy_and_initialize_state  ; trying to face the player
bra_face_landed_enemy_toward_player:
    LDY #$01  ; load 1 for enemy to face the left (inverted here)
    JSR sub_player_enemy_diff  ; get horizontal difference between player and enemy
    BPL bra_compare_new_enemy_direction  ; if enemy to the right of player, branch
    INY  ; if to the left, increment by one for enemy to face right (inverted)
bra_compare_new_enemy_direction:
    TYA
    CMP ram_enemy_moving_dir,x  ; compare direction in A with current direction in memory
    BNE bra_land_enemy_and_initialize_state
    JSR sub_handle_enemy_bump_or_hammer_bro_jump  ; if equal, not facing in correct dir, do sub to turn around

bra_land_enemy_and_initialize_state:
    JSR sub_enemy_landing  ; land enemy properly
    LDA ram_enemy_state,x
    AND #%10000000  ; if d7 of enemy state is set, branch
    BNE bra_clear_moving_shell_fall_bit
    LDA #$00  ; otherwise initialize enemy state and leave
    STA ram_enemy_state,x  ; note this will also turn spiny's egg into spiny
    RTS

bra_clear_moving_shell_fall_bit:
    LDA ram_enemy_state,x  ; nullify d6 of enemy state, save other bits
    AND #%10111111  ; and store, then leave
    STA ram_enemy_state,x
    RTS

; --------------------------------

loc_check_red_koopa_edge:
    LDA ram_enemy_id,x  ; check for red koopa troopa $03
    CMP #con_red_koopa
    BNE bra_update_landed_enemy_state  ; branch if not found
    LDA ram_enemy_state,x
    BEQ sub_handle_enemy_bump_or_hammer_bro_jump  ; if enemy found and in normal state, branch
bra_update_landed_enemy_state:
    LDA ram_enemy_state,x  ; save enemy state into Y
    TAY
    ASL  ; check for d7 set
    BCC bra_map_landed_enemy_state  ; branch if not set
    LDA ram_enemy_state,x
    ORA #%01000000  ; set d6
    JMP loc_store_landed_enemy_state  ; jump ahead of this part
bra_map_landed_enemy_state:
    LDA tbl_enemy_background_collision_states,y  ; load new enemy state with old as offset
loc_store_landed_enemy_state:
    STA ram_enemy_state,x  ; set as new state

; --------------------------------
; $00 - used to store bitmask (not used but initialized here)
; $eb - used in loc_check_enemy_side_collisions as counter and to compare moving directions

loc_check_enemy_side_collisions:
    LDA ram_enemy_y_position,x  ; if enemy within status bar, branch to leave
    CMP #$20  ; because there's nothing there that impedes movement
    BCC bra_exit_enemy_side_collision
    LDY #$16  ; start by finding block to the left of enemy ($00,$14)
    LDA #$02  ; set value here in what is also used as
    STA $eb  ; OAM data offset
bra_check_enemy_side_collision_loop:
    LDA $eb  ; check value
    CMP ram_enemy_moving_dir,x  ; compare value against moving direction
    BNE bra_check_next_enemy_side  ; branch if different and do not seek block there
    LDA #$01  ; set flag in A for save horizontal coordinate
    JSR sub_check_enemy_block_buffer  ; find block to left or right of enemy object
    BEQ bra_check_next_enemy_side  ; if nothing found, branch
    JSR sub_check_non_solid_enemy_metatile  ; check for non-solid blocks
    BNE sub_handle_enemy_bump_or_hammer_bro_jump  ; branch if not found
bra_check_next_enemy_side:
    DEC $eb  ; move to the next direction
    INY
    CPY #$18  ; increment Y, loop only if Y < $18, thus we check
    BCC bra_check_enemy_side_collision_loop  ; enemy ($00, $14) and ($10, $14) pixel coordinates
bra_exit_enemy_side_collision:
    RTS

sub_handle_enemy_bump_or_hammer_bro_jump:
    CPX #$05  ; check if we're on the special use slot
    BEQ bra_handle_enemy_side_obstruction  ; and if so, branch ahead and do not play sound
    LDA ram_enemy_state,x  ; if enemy state d7 not set, branch
    ASL  ; ahead and do not play sound
    BCC bra_handle_enemy_side_obstruction
    LDA #con_sfx_bump  ; otherwise, play bump sound
    STA ram_square1_sound_queue  ; sound will never be played if branching from loc_check_red_koopa_edge
bra_handle_enemy_side_obstruction:
    LDA ram_enemy_id,x  ; check for hammer bro
    CMP #$05
    BNE bra_reverse_enemy_direction  ; branch if not found
    LDA #$00
    STA $00  ; initialize value here for bitmask
    LDY #$fa  ; load default vertical speed for jumping
    JMP loc_start_hammer_bro_jump  ; jump to code that makes hammer bro jump

bra_reverse_enemy_direction:
    JMP loc_reverse_enemy_x_speed  ; jump to turn the enemy around

; --------------------------------
; $00 - used to hold horizontal difference between player and enemy

sub_player_enemy_diff:
    LDA ram_enemy_x_position,x  ; get distance between enemy object's
    SEC  ; horizontal coordinate and the player's
    SBC ram_player_x_position  ; horizontal coordinate
    STA $00  ; and store here
    LDA ram_enemy_page_loc,x
    SBC ram_player_page_loc  ; subtract borrow, then leave
    RTS

; --------------------------------

sub_enemy_landing:
    JSR sub_clear_enemy_vertical_motion  ; do something here to vertical speed and something else
    LDA ram_enemy_y_position,x
    AND #%11110000  ; save high nybble of vertical coordinate, and
    ORA #%00001000  ; set d3, then store, probably used to set enemy object
    STA ram_enemy_y_position,x  ; neatly on whatever it's landing on
    RTS

sub_adjust_enemy_y_for_floor_check:
    LDA ram_enemy_y_position,x  ; add 62 pixels to enemy object's
    CLC  ; vertical coordinate
    ADC #$3e
    CMP #$44  ; compare against a certain range
    RTS  ; and leave with flags set for conditional branch

sub_enemy_jump:
    JSR sub_adjust_enemy_y_for_floor_check  ; do a sub here
    BCC bra_move_enemy_from_side_obstruction  ; if enemy vertical coord + 62 < 68, branch to leave
    LDA ram_enemy_y_speed,x
    CLC  ; add two to vertical speed
    ADC #$02
    CMP #$03  ; if green paratroopa not falling, branch ahead
    BCC bra_move_enemy_from_side_obstruction
    JSR sub_check_metatile_under_enemy  ; otherwise, check to see if green paratroopa is
    BEQ bra_move_enemy_from_side_obstruction  ; standing on anything, then branch to same place if not
    JSR sub_check_non_solid_enemy_metatile  ; check for non-solid blocks
    BEQ bra_move_enemy_from_side_obstruction  ; branch if found
    JSR sub_enemy_landing  ; change vertical coordinate and speed
    LDA #$fd
    STA ram_enemy_y_speed,x  ; make the paratroopa jump again
bra_move_enemy_from_side_obstruction:
    JMP loc_check_enemy_side_collisions  ; check for horizontal blockage, then leave

; --------------------------------

loc_handle_hammer_bro_background_collision:
    JSR sub_check_metatile_under_enemy  ; check to see if hammer bro is standing on anything
    BEQ bra_set_hammer_bro_airborne
    CMP #$23  ; check for blank metatile $23 and branch if not found
    BNE bra_land_hammer_bro

sub_kill_enemy_above_block:
    JSR sub_shell_or_block_defeat  ; do this sub to kill enemy
    LDA #$fc  ; alter vertical speed of enemy and leave
    STA ram_enemy_y_speed,x
    RTS

bra_land_hammer_bro:
    LDA ram_enemy_frame_timer,x  ; check timer used by hammer bro
    BNE bra_set_hammer_bro_airborne  ; branch if not expired
    LDA ram_enemy_state,x
    AND #%10001000  ; save d7 and d3 from enemy state, nullify other bits
    STA ram_enemy_state,x  ; and store
    JSR sub_enemy_landing  ; modify vertical coordinate, speed and something else
    JMP loc_check_enemy_side_collisions  ; then check for horizontal blockage and leave

bra_set_hammer_bro_airborne:
    LDA ram_enemy_state,x  ; if hammer bro is not standing on anything, set d0
    ORA #$01  ; in the enemy state to indicate jumping or falling, then leave
    STA ram_enemy_state,x
    RTS

sub_check_metatile_under_enemy:
    LDA #$00  ; set flag in A for save vertical coordinate
    LDY #$15  ; set Y to check the bottom middle (8,18) of enemy object
    JMP sub_check_enemy_block_buffer  ; hop to it!

sub_check_non_solid_enemy_metatile:
    CMP #$26  ; blank metatile used for vines?
    BEQ bra_return_enemy_floor_metatile_test
    CMP #$c2  ; regular coin?
    BEQ bra_return_enemy_floor_metatile_test
    CMP #$c3  ; underwater coin?
    BEQ bra_return_enemy_floor_metatile_test
    CMP #$5f  ; hidden coin block?
    BEQ bra_return_enemy_floor_metatile_test
    CMP #$60  ; hidden 1-up block?
bra_return_enemy_floor_metatile_test:
    RTS

; -------------------------------------------------------------------------------------

sub_handle_fireball_background_collision:
    LDA ram_fireball_y_position,x  ; check fireball's vertical coordinate
    CMP #$18
    BCC bra_clear_fireball_bounce_flag  ; if within the status bar area of the screen, branch ahead
    JSR sub_check_fireball_block_buffer  ; do fireball to background collision detection on bottom of it
    BEQ bra_clear_fireball_bounce_flag  ; if nothing underneath fireball, branch
    JSR sub_check_non_solid_enemy_metatile  ; check for non-solid metatiles
    BEQ bra_clear_fireball_bounce_flag  ; branch if any found
    LDA ram_fireball_y_speed,x  ; if fireball's vertical speed set to move upwards,
    BMI bra_start_fireball_explosion  ; branch to set exploding bit in fireball's state
    LDA ram_fireball_bouncing_flag,x  ; if bouncing flag already set,
    BNE bra_start_fireball_explosion  ; branch to set exploding bit in fireball's state
    LDA #$fd
    STA ram_fireball_y_speed,x  ; otherwise set vertical speed to move upwards (give it bounce)
    LDA #$01
    STA ram_fireball_bouncing_flag,x  ; set bouncing flag
    LDA ram_fireball_y_position,x
    AND #$f8  ; modify vertical coordinate to land it properly
    STA ram_fireball_y_position,x  ; store as new vertical coordinate
    RTS  ; leave

bra_clear_fireball_bounce_flag:
    LDA #$00
    STA ram_fireball_bouncing_flag,x  ; clear bouncing flag by default
    RTS  ; leave

bra_start_fireball_explosion:
    LDA #$80
    STA ram_fireball_state,x  ; set exploding flag in fireball's state
    LDA #con_sfx_bump
    STA ram_square1_sound_queue  ; load bump sound
    RTS  ; leave
