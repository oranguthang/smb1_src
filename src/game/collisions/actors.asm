; --------------------------------

unused_residual_x_speeds:
    .byte $18, $e8

tbl_kicked_shell_x_speeds:
    .byte con_kicked_enemy_x_speed, <-con_kicked_enemy_x_speed

tbl_demoted_koopa_x_speeds:
    .byte $08, $f8

sub_player_enemy_collision:
    LDA ram_frame_counter  ; check counter for d0 set
    LSR
    BCS bra_exit_power_up_collection  ; if set, branch to leave
    JSR sub_check_player_vertical  ; if player object is completely offscreen or
    BCS bra_exit_player_enemy_collision_early  ; if down past 224th pixel row, branch to leave
    LDA ram_enemy_offscr_bits_masked,x  ; if current enemy is offscreen by any amount,
    BNE bra_exit_player_enemy_collision_early  ; go ahead and branch to leave
    LDA ram_game_engine_subroutine
    CMP #$08  ; if not set to run player control routine
    BNE bra_exit_player_enemy_collision_early  ; on next frame, branch to leave
    LDA ram_enemy_state,x
    AND #%00100000  ; if enemy state has d5 set, branch to leave
    BNE bra_exit_player_enemy_collision_early
    JSR sub_get_enemy_bounding_box_offset  ; get bounding box offset for current enemy object
    JSR sub_player_collision_core  ; do collision detection on player vs. enemy
    LDX ram_object_offset  ; get enemy object buffer offset
    BCS bra_check_power_up_collision  ; if collision, branch past this part here
    LDA ram_enemy_collision_bits,x
    AND #%11111110  ; otherwise, clear d0 of current enemy object's
    STA ram_enemy_collision_bits,x  ; collision bit
bra_exit_player_enemy_collision_early:
    RTS

bra_check_power_up_collision:
    LDY ram_enemy_id,x
    CPY #con_power_up_object  ; check for power-up object
    BNE bra_handle_enemy_collision  ; if not found, branch to next part
    JMP loc_handle_power_up_collision  ; otherwise, unconditional jump backwards
bra_handle_enemy_collision:
    LDA ram_star_invincible_timer  ; if star mario invincibility timer expired,
    BEQ bra_resolve_player_enemy_collision  ; perform task here, otherwise kill enemy like
    JMP sub_shell_or_block_defeat  ; hit with a shell, or from beneath

tbl_kicked_shell_points:
    .byte $0a, $06, $04

bra_resolve_player_enemy_collision:
    LDA ram_enemy_collision_bits,x  ; check enemy collision bits for d0 set
    AND #%00000001  ; or for being offscreen at all
    ORA ram_enemy_offscr_bits_masked,x
    BNE bra_exit_player_enemy_collision  ; branch to leave if either is true
    LDA #$01
    ORA ram_enemy_collision_bits,x  ; otherwise set d0 now
    STA ram_enemy_collision_bits,x
    CPY #con_spiny  ; branch if spiny
    BEQ bra_check_player_injury_collision
    CPY #con_piranha_plant  ; branch if piranha plant
    BEQ sub_injure_player
    CPY #con_podoboo  ; branch if podoboo
    BEQ sub_injure_player
    CPY #con_bullet_bill_cannon_var  ; branch if bullet bill
    BEQ bra_check_player_injury_collision
    CPY #$15  ; branch if object => $15
    BCS sub_injure_player
    LDA ram_area_type  ; branch if water type level
    BEQ sub_injure_player
    LDA ram_enemy_state,x  ; branch if d7 of enemy state was set
    ASL
    BCS bra_check_player_injury_collision
    LDA ram_enemy_state,x  ; mask out all but 3 LSB of enemy state
    AND #%00000111
    CMP #$02  ; branch if enemy is in normal or falling state
    BCC bra_check_player_injury_collision
    LDA ram_enemy_id,x  ; branch to leave if goomba in defeated state
    CMP #con_goomba
    BEQ bra_exit_player_enemy_collision
    LDA #con_sfx_enemy_smack  ; play smack enemy sound
    STA ram_square1_sound_queue
    LDA ram_enemy_state,x  ; set d7 in enemy state, thus become moving shell
    ORA #%10000000
    STA ram_enemy_state,x
    JSR sub_enemy_face_player  ; set moving direction and get offset
    LDA tbl_kicked_shell_x_speeds,y  ; load and set horizontal speed data with offset
    STA ram_enemy_x_speed,x
    LDA #$03  ; add three to whatever the stomp counter contains
    CLC  ; to give points for kicking the shell
    ADC ram_stomp_chain_counter
    LDY ram_enemy_interval_timer,x  ; check shell enemy's timer
    CPY #$03  ; if above a certain point, branch using the points
    BCS bra_award_kicked_shell_points  ; data obtained from the stomp counter + 3
    LDA tbl_kicked_shell_points,y  ; otherwise, set points based on proximity to timer expiration
bra_award_kicked_shell_points:
    JSR sub_setup_floatey_number  ; set values for floatey number now
bra_exit_player_enemy_collision:
    RTS  ; leave!!!

bra_check_player_injury_collision:
    LDA ram_player_y_speed  ; check player's vertical speed
    BMI bra_check_player_injury_immunity  ; perform procedure below if player moving upwards
    BNE loc_enemy_stomped  ; or not at all, and branch elsewhere if moving downwards
bra_check_player_injury_immunity:
.if con_revision_profile = con_revision_profile_pal
    LDA #$14  ; use the default PAL collision height
    LDY ram_enemy_id,x
    CPY #con_flying_cheep_cheep
    BNE bra_add_player_enemy_collision_height
    LDA #$07  ; flying cheep-cheeps use a shorter collision height
bra_add_player_enemy_collision_height:
    ADC ram_player_y_position
.else
    LDA ram_enemy_id,x  ; branch if enemy object < $07
    CMP #con_bloober
    BCC bra_check_stomp_and_injury_timers
    LDA ram_player_y_position  ; add 12 pixels to player's vertical position
    CLC
    ADC #$0c
.endif
    CMP ram_enemy_y_position,x  ; compare modified player's position to enemy's position
    BCC loc_enemy_stomped  ; branch if this player's position above (less than) enemy's
bra_check_stomp_and_injury_timers:
    LDA ram_stomp_timer  ; check stomp timer
    BNE loc_enemy_stomped  ; branch if set
    LDA ram_injury_timer  ; check to see if injured invincibility timer still
    BNE bra_exit_player_injury_collision  ; counting down, and branch elsewhere to leave if so
    LDA ram_player_rel_x_pos
    CMP ram_enemy_rel_x_pos  ; if player's relative position to the left of enemy's
    BCC bra_check_left_side_enemy_injury  ; relative position, branch here
    JMP loc_check_enemy_facing_right  ; otherwise do a jump here
bra_check_left_side_enemy_injury:
    LDA ram_enemy_moving_dir,x  ; if enemy moving towards the left,
    CMP #$01  ; branch, otherwise do a jump here
    BNE sub_injure_player  ; to turn the enemy around
    JMP loc_turn_enemy_then_injure_player

sub_injure_player:
    LDA ram_injury_timer  ; check again to see if injured invincibility timer is
    BNE bra_exit_player_injury_collision  ; at zero, and branch to leave if so

sub_force_injury:
    LDX ram_player_status  ; check player's status
    BEQ bra_kill_player_from_enemy_collision  ; branch if small
    STA ram_player_status  ; otherwise set player's status to small
    LDA #$08
    STA ram_injury_timer  ; set injured invincibility timer
.if con_revision_profile = con_revision_profile_pal
    LDA #con_sfx_pipe_down_injury
.else
    ASL
.endif
    STA ram_square1_sound_queue  ; play pipedown/injury sound
    JSR sub_get_player_colors  ; change player's palette if necessary
    LDA #$0a  ; set subroutine to run on next frame
bra_set_player_injury_or_death_task:
    LDY #$01  ; set new player state
sub_set_player_routine_state:
    STA ram_game_engine_subroutine  ; load new value to run subroutine on next frame
    STY ram_player_state  ; store new player state
    LDY #$ff
    STY ram_timer_control  ; set master timer control flag to halt timers
    INY
    STY ram_scroll_amount  ; initialize scroll speed

bra_exit_player_injury_collision:
    LDX ram_object_offset  ; get enemy offset and leave
    RTS

bra_kill_player_from_enemy_collision:
    STX ram_player_x_speed  ; halt player's horizontal movement by initializing speed
    INX
    STX ram_event_music_queue  ; set event music queue to death music
    LDA #$fc
    STA ram_player_y_speed  ; set new vertical speed
    LDA #$0b  ; set subroutine to run on next frame
    BNE bra_set_player_injury_or_death_task  ; branch to set player's state and other things

tbl_stomped_enemy_points:
    .byte $02, $06, $05, $06

loc_enemy_stomped:
    LDA ram_enemy_id,x  ; check for spiny, branch to hurt player
    CMP #con_spiny  ; if found
    BEQ sub_injure_player
    LDA #con_sfx_enemy_stomp  ; otherwise play stomp/swim sound
    STA ram_square1_sound_queue
    LDA ram_enemy_id,x
    LDY #$00  ; initialize points data offset for stomped enemies
    CMP #con_flying_cheep_cheep  ; branch for cheep-cheep
    BEQ bra_award_stomped_enemy_points
    CMP #con_bullet_bill_frenzy_var  ; branch for either bullet bill object
    BEQ bra_award_stomped_enemy_points
    CMP #con_bullet_bill_cannon_var
    BEQ bra_award_stomped_enemy_points
    CMP #con_podoboo  ; branch for podoboo (this branch is logically impossible
    BEQ bra_award_stomped_enemy_points  ; for cpu to take due to earlier checking of podoboo)
    INY  ; increment points data offset
    CMP #con_hammer_bro  ; branch for hammer bro
    BEQ bra_award_stomped_enemy_points
    INY  ; increment points data offset
    CMP #con_lakitu  ; branch for lakitu
    BEQ bra_award_stomped_enemy_points
    INY  ; increment points data offset
    CMP #con_bloober  ; branch if NOT bloober
    BNE bra_check_koopa_demotion

bra_award_stomped_enemy_points:
    LDA tbl_stomped_enemy_points,y  ; load points data using offset in Y
    JSR sub_setup_floatey_number  ; run sub to set floatey number controls
    LDA ram_enemy_moving_dir,x
    PHA  ; save enemy movement direction to stack
    JSR sub_set_stun  ; run sub to kill enemy
    PLA
    STA ram_enemy_moving_dir,x  ; return enemy movement direction from stack
    LDA #%00100000
    STA ram_enemy_state,x  ; set d5 in enemy state
    JSR sub_clear_enemy_vertical_motion  ; nullify vertical speed, physics-related thing,
    STA ram_enemy_x_speed,x  ; and horizontal speed
    LDA #$fd  ; set player's vertical speed, to give bounce
    STA ram_player_y_speed
    RTS

bra_check_koopa_demotion:
    CMP #$09  ; branch elsewhere if enemy object < $09
    BCC bra_handle_stomped_shell_enemy
    AND #%00000001  ; demote koopa paratroopas to ordinary troopas
    STA ram_enemy_id,x
    LDY #$00  ; return enemy to normal state
    STY ram_enemy_state,x
    LDA #$03  ; award 400 points to the player
    JSR sub_setup_floatey_number
    JSR sub_clear_enemy_vertical_motion  ; nullify physics-related thing and vertical speed
    JSR sub_enemy_face_player  ; turn enemy around if necessary
    LDA tbl_demoted_koopa_x_speeds,y
    STA ram_enemy_x_speed,x  ; set appropriate moving speed based on direction
    JMP loc_bounce_player_from_enemy  ; then move onto something else

tbl_enemy_revival_delays:
.if con_revision_profile = con_revision_profile_pal
    .byte $0d, $09
.else
    .byte $10, $0b
.endif

bra_handle_stomped_shell_enemy:
    LDA #$04  ; set defeated state for enemy
    STA ram_enemy_state,x
    INC ram_stomp_chain_counter  ; increment the stomp counter
    LDA ram_stomp_chain_counter  ; add whatever is in the stomp counter
    CLC  ; to whatever is in the stomp timer
    ADC ram_stomp_timer
    JSR sub_setup_floatey_number  ; award points accordingly
    INC ram_stomp_timer  ; increment stomp timer of some sort
    LDY ram_primary_hard_mode  ; check primary hard mode flag
    LDA tbl_enemy_revival_delays,y  ; load timer setting according to flag
    STA ram_enemy_interval_timer,x  ; set as enemy timer to revive stomped enemy
loc_bounce_player_from_enemy:
    LDA #$fc  ; set player's vertical speed for bounce
    STA ram_player_y_speed  ; and then leave!!!
    RTS

loc_check_enemy_facing_right:
    LDA ram_enemy_moving_dir,x  ; check to see if enemy is moving to the right
    CMP #$01
    BNE loc_turn_enemy_then_injure_player  ; if not, branch
    JMP sub_injure_player  ; otherwise go back to hurt player
loc_turn_enemy_then_injure_player:
    JSR sub_enemy_turn_around  ; turn the enemy around, if necessary
    JMP sub_injure_player  ; go back to hurt player

sub_enemy_face_player:
    LDY #$01  ; set to move right by default
    JSR sub_player_enemy_diff  ; get horizontal difference between player and enemy
    BPL bra_store_enemy_facing_direction  ; if enemy is to the right of player, do not increment
    INY  ; otherwise, increment to set to move to the left
bra_store_enemy_facing_direction:
    STY ram_enemy_moving_dir,x  ; set moving direction here
    DEY  ; then decrement to use as a proper offset
    RTS

sub_setup_floatey_number:
    STA ram_floatey_num_control,x  ; set number of points control for floatey numbers
    LDA #$30
    STA ram_floatey_num_timer,x  ; set timer for floatey numbers
    LDA ram_enemy_y_position,x
    STA ram_floatey_num_y_pos,x  ; set vertical coordinate
    LDA ram_enemy_rel_x_pos
    STA ram_floatey_num_x_pos,x  ; set horizontal coordinate and leave
bra_exit_floating_score_setup:
    RTS

; -------------------------------------------------------------------------------------
; $01 - used to hold enemy offset for second enemy

tbl_bit_set_masks:
    .byte %10000000, %01000000, %00100000, %00010000, %00001000, %00000100, %00000010

tbl_bit_clear_masks:
    .byte %01111111, %10111111, %11011111, %11101111, %11110111, %11111011, %11111101

sub_enemies_collision:
    LDA ram_frame_counter  ; check counter for d0 set
    LSR
    BCC bra_exit_floating_score_setup  ; if d0 not set, leave
    LDA ram_area_type
    BEQ bra_exit_floating_score_setup  ; if water area type, leave
    LDA ram_enemy_id,x
    CMP #$15  ; if enemy object => $15, branch to leave
    BCS bra_exit_enemy_collision_scan
    CMP #con_lakitu  ; if lakitu, branch to leave
    BEQ bra_exit_enemy_collision_scan
    CMP #con_piranha_plant  ; if piranha plant, branch to leave
    BEQ bra_exit_enemy_collision_scan
    LDA ram_enemy_offscr_bits_masked,x  ; if masked offscreen bits nonzero, branch to leave
    BNE bra_exit_enemy_collision_scan
    JSR sub_get_enemy_bounding_box_offset  ; otherwise, do sub, get appropriate bounding box offset for
    DEX  ; first enemy we're going to compare, then decrement for second
    BMI bra_exit_enemy_collision_scan  ; branch to leave if there are no other enemies
bra_check_enemy_collision_pairs_loop:
    STX $01  ; save enemy object buffer offset for second enemy here
    TYA  ; save first enemy's bounding box offset to stack
    PHA
    LDA ram_enemy_flag,x  ; check enemy object enable flag
    BEQ loc_advance_enemy_collision_pair  ; branch if flag not set
    LDA ram_enemy_id,x
    CMP #$15  ; check for enemy object => $15
    BCS loc_advance_enemy_collision_pair  ; branch if true
    CMP #con_lakitu
    BEQ loc_advance_enemy_collision_pair  ; branch if enemy object is lakitu
    CMP #con_piranha_plant
    BEQ loc_advance_enemy_collision_pair  ; branch if enemy object is piranha plant
    LDA ram_enemy_offscr_bits_masked,x
    BNE loc_advance_enemy_collision_pair  ; branch if masked offscreen bits set
    TXA  ; get second enemy object's bounding box offset
    ASL  ; multiply by four, then add four
    ASL
    CLC
    ADC #$04
    TAX  ; use as new contents of X
    JSR sub_sprite_object_collision_core  ; do collision detection using the two enemies here
    LDX ram_object_offset  ; use first enemy offset for X
    LDY $01  ; use second enemy offset for Y
    BCC bra_clear_enemy_collision_pair  ; if carry clear, no collision, branch ahead of this
    LDA ram_enemy_state,x
    ORA ram_enemy_state,y  ; check both enemy states for d7 set
    AND #%10000000
    BNE bra_record_enemy_collision_pair  ; branch if at least one of them is set
    LDA ram_enemy_collision_bits,y  ; load first enemy's collision-related bits
    AND tbl_bit_set_masks,x  ; check to see if bit connected to second enemy is
    BNE loc_advance_enemy_collision_pair  ; already set, and move onto next enemy slot if set
    LDA ram_enemy_collision_bits,y
    ORA tbl_bit_set_masks,x  ; if the bit is not set, set it now
    STA ram_enemy_collision_bits,y
bra_record_enemy_collision_pair:
    JSR sub_process_enemy_collision  ; react according to the nature of collision
    JMP loc_advance_enemy_collision_pair  ; move onto next enemy slot

bra_clear_enemy_collision_pair:
    LDA ram_enemy_collision_bits,y  ; load first enemy's collision-related bits
    AND tbl_bit_clear_masks,x  ; clear bit connected to second enemy
    STA ram_enemy_collision_bits,y  ; then move onto next enemy slot

loc_advance_enemy_collision_pair:
    PLA  ; get first enemy's bounding box offset from the stack
    TAY  ; use as Y again
    LDX $01  ; get and decrement second enemy's object buffer offset
    DEX
    BPL bra_check_enemy_collision_pairs_loop  ; loop until all enemy slots have been checked

bra_exit_enemy_collision_scan:
    LDX ram_object_offset  ; get enemy object buffer offset
    RTS  ; leave

sub_process_enemy_collision:
    LDA ram_enemy_state,y  ; check both enemy states for d5 set
    ORA ram_enemy_state,x
    AND #%00100000  ; if d5 is set in either state, or both, branch
    BNE bra_exit_enemy_collision_processing  ; to leave and do nothing else at this point
    LDA ram_enemy_state,x
    CMP #$06  ; if second enemy state < $06, branch elsewhere
    BCC bra_process_second_enemy_collision
    LDA ram_enemy_id,x  ; check second enemy identifier for hammer bro
    CMP #con_hammer_bro  ; if hammer bro found in alt state, branch to leave
    BEQ bra_exit_enemy_collision_processing
    LDA ram_enemy_state,y  ; check first enemy state for d7 set
    ASL
    BCC bra_resolve_shell_enemy_collision  ; branch if d7 is clear
    LDA #$06
    JSR sub_setup_floatey_number  ; award 1000 points for killing enemy
    JSR sub_shell_or_block_defeat  ; then kill enemy, then load
    LDY $01  ; original offset of second enemy

bra_resolve_shell_enemy_collision:
    TYA  ; move Y to X
    TAX
    JSR sub_shell_or_block_defeat  ; kill second enemy
    LDX ram_object_offset
    LDA ram_shell_chain_counter,x  ; get chain counter for shell
    CLC
    ADC #$04  ; add four to get appropriate point offset
    LDX $01
    JSR sub_setup_floatey_number  ; award appropriate number of points for second enemy
    LDX ram_object_offset  ; load original offset of first enemy
    INC ram_shell_chain_counter,x  ; increment chain counter for additional enemies

bra_exit_enemy_collision_processing:
    RTS  ; leave!!!

bra_process_second_enemy_collision:
    LDA ram_enemy_state,y  ; if first enemy state < $06, branch elsewhere
    CMP #$06
    BCC bra_select_second_enemy_offset
    LDA ram_enemy_id,y  ; check first enemy identifier for hammer bro
    CMP #con_hammer_bro  ; if hammer bro found in alt state, branch to leave
    BEQ bra_exit_enemy_collision_processing
    JSR sub_shell_or_block_defeat  ; otherwise, kill first enemy
    LDY $01
    LDA ram_shell_chain_counter,y  ; get chain counter for shell
    CLC
    ADC #$04  ; add four to get appropriate point offset
    LDX ram_object_offset
    JSR sub_setup_floatey_number  ; award appropriate number of points for first enemy
    LDX $01  ; load original offset of second enemy
    INC ram_shell_chain_counter,x  ; increment chain counter for additional enemies
    RTS  ; leave!!!

bra_select_second_enemy_offset:
    TYA  ; move Y ($01) to X
    TAX
    JSR sub_enemy_turn_around  ; do the sub here using value from $01
    LDX ram_object_offset  ; then do it again using value from $08

sub_enemy_turn_around:
    LDA ram_enemy_id,x  ; check for specific enemies
    CMP #con_piranha_plant
    BEQ bra_exit_enemy_turn_around  ; if piranha plant, leave
    CMP #con_lakitu
    BEQ bra_exit_enemy_turn_around  ; if lakitu, leave
    CMP #con_hammer_bro
    BEQ bra_exit_enemy_turn_around  ; if hammer bro, leave
    CMP #con_spiny
    BEQ loc_reverse_enemy_x_speed  ; if spiny, turn it around
    CMP #con_green_paratroopa_jump
    BEQ loc_reverse_enemy_x_speed  ; if green paratroopa, turn it around
    CMP #$07
    BCS bra_exit_enemy_turn_around  ; if any OTHER enemy object => $07, leave
loc_reverse_enemy_x_speed:
    LDA ram_enemy_x_speed,x  ; load horizontal speed
    EOR #$ff  ; get two's compliment for horizontal speed
    TAY
    INY
    STY ram_enemy_x_speed,x  ; store as new horizontal speed
    LDA ram_enemy_moving_dir,x
    EOR #%00000011  ; invert moving direction and store, then leave
    STA ram_enemy_moving_dir,x  ; thus effectively turning the enemy around
bra_exit_enemy_turn_around:
    RTS  ; leave!!!

; -------------------------------------------------------------------------------------
; $00 - vertical position of platform

sub_large_platform_collision:
    LDA #$ff  ; save value here
    STA ram_platform_collision_flag,x
    LDA ram_timer_control  ; check master timer control
    BNE bra_exit_large_platform_collision  ; if set, branch to leave
    LDA ram_enemy_state,x  ; if d7 set in object state,
    BMI bra_exit_large_platform_collision  ; branch to leave
    LDA ram_enemy_id,x
    CMP #$24  ; check enemy object identifier for
    BNE sub_check_player_large_platform_collision  ; balance platform, branch if not found
    LDA ram_enemy_state,x
    TAX  ; set state as enemy offset here
    JSR sub_check_player_large_platform_collision  ; perform code with state offset, then original offset, in X

sub_check_player_large_platform_collision:
    JSR sub_check_player_vertical  ; figure out if player is below a certain point
    BCS bra_exit_large_platform_collision  ; or offscreen, branch to leave if true
    TXA
    JSR sub_get_enemy_bounding_box_offset_from_x  ; get bounding box offset in Y
    LDA ram_enemy_y_position,x  ; store vertical coordinate in
    STA $00  ; temp variable for now
    TXA  ; send offset we're on to the stack
    PHA
    JSR sub_player_collision_core  ; do player-to-platform collision detection
    PLA  ; retrieve offset from the stack
    TAX
    BCC bra_exit_large_platform_collision  ; if no collision, branch to leave
    JSR sub_process_large_platform_collision  ; otherwise collision, perform sub
bra_exit_large_platform_collision:
    LDX ram_object_offset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------
; $00 - counter for bounding boxes

sub_small_platform_collision:
    LDA ram_timer_control  ; if master timer control set,
    BNE bra_exit_small_platform_collision  ; branch to leave
    STA ram_platform_collision_flag,x  ; otherwise initialize collision flag
    JSR sub_check_player_vertical  ; do a sub to see if player is below a certain point
    BCS bra_exit_small_platform_collision  ; or entirely offscreen, and branch to leave if true
    LDA #$02
    STA $00  ; load counter here for 2 bounding boxes

bra_check_next_small_platform:
    LDX ram_object_offset  ; get enemy object offset
    JSR sub_get_enemy_bounding_box_offset  ; get bounding box offset in Y
    AND #%00000010  ; if d1 of offscreen lower nybble bits was set
    BNE bra_exit_small_platform_collision  ; then branch to leave
    LDA ram_bounding_box_ul_y_pos,y  ; check top of platform's bounding box for being
    CMP #$20  ; above a specific point
    BCC bra_shift_platform_bounding_box  ; if so, branch, don't do collision detection
    JSR sub_player_collision_core  ; otherwise, perform player-to-platform collision detection
    BCS bra_process_small_platform_collisions  ; skip ahead if collision

bra_shift_platform_bounding_box:
    LDA ram_bounding_box_ul_y_pos,y  ; move bounding box vertical coordinates
    CLC  ; 128 pixels downwards
    ADC #$80
    STA ram_bounding_box_ul_y_pos,y
    LDA ram_bounding_box_dr_y_pos,y
    CLC
    ADC #$80
    STA ram_bounding_box_dr_y_pos,y
    DEC $00  ; decrement counter we set earlier
    BNE bra_check_next_small_platform  ; loop back until both bounding boxes are checked
bra_exit_small_platform_collision:
    LDX ram_object_offset  ; get enemy object buffer offset, then leave
    RTS

; --------------------------------

bra_process_small_platform_collisions:
    LDX ram_object_offset  ; return enemy object buffer offset to X, then continue

sub_process_large_platform_collision:
    LDA ram_bounding_box_dr_y_pos,y  ; get difference by subtracting the top
    SEC  ; of the player's bounding box from the bottom
    SBC ram_bounding_box_ul_y_pos  ; of the platform's bounding box
    CMP #$04  ; if difference too large or negative,
    BCS bra_check_platform_top_collision  ; branch, do not alter vertical speed of player
    LDA ram_player_y_speed  ; check to see if player's vertical speed is moving down
    BPL bra_check_platform_top_collision  ; if so, don't mess with it
    LDA #$01  ; otherwise, set vertical
    STA ram_player_y_speed  ; speed of player to kill jump

bra_check_platform_top_collision:
    LDA ram_bounding_box_dr_y_pos  ; get difference by subtracting the top
    SEC  ; of the platform's bounding box from the bottom
    SBC ram_bounding_box_ul_y_pos,y  ; of the player's bounding box
    CMP #$06
    BCS bra_check_platform_side_collisions  ; if difference not close enough, skip all of this
    LDA ram_player_y_speed
    BMI bra_check_platform_side_collisions  ; if player's vertical speed moving upwards, skip this
    LDA $00  ; get saved bounding box counter from earlier
    LDY ram_enemy_id,x
    CPY #$2b  ; if either of the two small platform objects are found,
    BEQ bra_store_platform_collision_flag  ; regardless of which one, branch to use bounding box counter
    CPY #$2c  ; as contents of collision flag
    BEQ bra_store_platform_collision_flag
    TXA  ; otherwise use enemy object buffer offset

bra_store_platform_collision_flag:
    LDX ram_object_offset  ; get enemy object buffer offset
    STA ram_platform_collision_flag,x  ; save either bounding box counter or enemy offset here
    LDA #$00
    STA ram_player_state  ; set player state to normal then leave
    RTS

bra_check_platform_side_collisions:
    LDA #$01  ; set value here to indicate possible horizontal
    STA $00  ; collision on left side of platform
    LDA ram_bounding_box_dr_x_pos  ; get difference by subtracting platform's left edge
    SEC  ; from player's right edge
    SBC ram_bounding_box_ul_x_pos,y
    CMP #$08  ; if difference close enough, skip all of this
    BCC bra_handle_platform_side_collision
    INC $00  ; otherwise increment value set here for right side collision
    LDA ram_bounding_box_dr_x_pos,y  ; get difference by subtracting player's left edge
    CLC  ; from platform's right edge
    SBC ram_bounding_box_ul_x_pos
    CMP #$09  ; if difference not close enough, skip subroutine
    BCS bra_exit_platform_side_collision  ; and instead branch to leave (no collision)
bra_handle_platform_side_collision:
    JSR sub_impede_player_move  ; deal with horizontal collision
bra_exit_platform_side_collision:
    LDX ram_object_offset  ; return with enemy object buffer offset
    RTS

; -------------------------------------------------------------------------------------

tbl_small_platform_player_y_offsets:
    .byte $80, $00

sub_position_player_on_small_platform:
    TAY  ; use bounding box counter saved in collision flag
    LDA ram_enemy_y_position,x  ; for offset
    CLC  ; add positioning data using offset to the vertical
    ADC tbl_small_platform_player_y_offsets-1,y  ; coordinate
    .byte $2c  ; BIT instruction opcode

sub_position_player_on_vertical_platform:
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    LDY ram_game_engine_subroutine
    CPY #$0b  ; if certain routine being executed on this frame,
    BEQ bra_exit_player_platform_position  ; skip all of this
    LDY ram_enemy_y_high_pos,x
    CPY #$01  ; if vertical high byte offscreen, skip this
    BNE bra_exit_player_platform_position
    SEC  ; subtract 32 pixels from vertical coordinate
    SBC #$20  ; for the player object's height
    STA ram_player_y_position  ; save as player's new vertical coordinate
    TYA
    SBC #$00  ; subtract borrow and store as player's
    STA ram_player_y_high_pos  ; new vertical high byte
    LDA #$00
    STA ram_player_y_speed  ; initialize vertical speed and low byte of force
    STA ram_player_y_speed_fraction  ; and then leave
bra_exit_player_platform_position:
    RTS

; -------------------------------------------------------------------------------------

sub_check_player_vertical:
    LDA ram_player_offscreen_bits  ; if player object is completely offscreen
    CMP #$f0  ; vertically, leave this routine
    BCS bra_exit_vertical_platform_player_position
    LDY ram_player_y_high_pos  ; if player high vertical byte is not
    DEY  ; within the screen, leave this routine
    BNE bra_exit_vertical_platform_player_position
    LDA ram_player_y_position  ; if on the screen, check to see how far down
    CMP #$d0  ; the player is vertically
bra_exit_vertical_platform_player_position:
    RTS

; -------------------------------------------------------------------------------------

sub_get_enemy_bounding_box_offset:
    LDA ram_object_offset  ; get enemy object buffer offset

sub_get_enemy_bounding_box_offset_from_x:
    ASL  ; multiply A by four, then add four
    ASL  ; to skip player's bounding box
    CLC
    ADC #$04
    TAY  ; send to Y
    LDA ram_enemy_offscreen_bits  ; get offscreen bits for enemy object
    AND #%00001111  ; save low nybble
    CMP #%00001111  ; check for all bits set
    RTS
