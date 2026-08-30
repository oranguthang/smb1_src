tbl_smb2_main_solid_metatile_range_upper_bounds:
    .byte $10, $62, $88, $c5

sub_smb2_main_check_solid_metatiles:
    JSR sub_smb2_main_get_metatile_attributes  ; find appropriate offset based on metatile's 2 MSB
    CMP tbl_smb2_main_solid_metatile_range_upper_bounds,x  ; compare current metatile with solid metatiles
    RTS

tbl_smb2_main_climbable_metatile_range_upper_bounds:
    .byte $21, $6f, $8d, $c7

sub_smb2_main_check_climbable_metatiles:
    JSR sub_smb2_main_get_metatile_attributes  ; find appropriate offset based on metatile's 2 MSB
    CMP tbl_smb2_main_climbable_metatile_range_upper_bounds,x  ; compare current metatile with climbable metatiles
    RTS

sub_smb2_main_check_coin_metatiles:
    CMP #$c3  ; check for regular coin
    BEQ bra_smb2_main_return_coin_metatile_found  ; branch if found
    CMP #$c4  ; check for underwater coin
    BEQ bra_smb2_main_return_coin_metatile_found  ; branch if found
    CLC  ; otherwise clear carry and leave
    RTS
bra_smb2_main_return_coin_metatile_found:
    LDA #Sfx_CoinGrab
    STA Square2SoundQueue  ; load coin grab sound and leave
    RTS

sub_smb2_main_get_metatile_attributes:
    TAY  ; save metatile value into Y
    AND #%11000000  ; mask out all but 2 MSB
    ASL
    ROL  ; shift and rotate d7-d6 to d1-d0
    ROL
    TAX  ; use as offset for metatile data
    TYA  ; get original metatile value back
bra_smb2_main_exit_player_background_metatile_lookup:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $06-$07 - address from block buffer routine

off_smb2_main_enemy_background_collision_states:
    .byte $01, $01, $02, $02, $02, $05

off_smb2_main_enemy_background_collision_x_speeds:
    .byte $10, $f0

sub_smb2_main_detect_enemy_background_collision:
    LDA Enemy_State,x  ; check enemy state for d6 set
    AND #%00100000
    BNE bra_smb2_main_exit_player_background_metatile_lookup  ; if set, branch to leave
    JSR sub_smb2_main_adjust_enemy_y_for_floor_check  ; otherwise, do a subroutine here
    BCC bra_smb2_main_exit_player_background_metatile_lookup  ; if enemy vertical coord + 62 < 68, branch to leave
    LDY Enemy_ID,x
    CPY #Spiny  ; if enemy object is not spiny, branch elsewhere
    BNE bra_smb2_main_dispatch_enemy_background_collision_behavior
    LDA Enemy_Y_Position,x
    CMP #$25  ; if enemy vertical coordinate < 36 branch to leave
    BCC bra_smb2_main_exit_player_background_metatile_lookup

bra_smb2_main_dispatch_enemy_background_collision_behavior:
    CPY #GreenParatroopaJump  ; check for some other enemy object
    BNE bra_smb2_main_check_hammer_bro_background_collision  ; branch if not found
    JMP sub_smb2_main_enemy_jump  ; otherwise jump elsewhere
bra_smb2_main_check_hammer_bro_background_collision:
    CPY #HammerBro  ; check for hammer bro
    BNE bra_smb2_main_check_enemy_background_collision_eligibility  ; branch if not found
    JMP loc_smb2_main_handle_hammer_bro_background_collision  ; otherwise jump elsewhere
bra_smb2_main_exit_enemy_background_check:
    RTS
bra_smb2_main_check_enemy_background_collision_eligibility:
    CPY #Spiny  ; if enemy object is spiny, branch
    BEQ bra_smb2_main_check_metatile_under_enemy
    CPY #PowerUpObject  ; if special power-up object, branch
    BEQ bra_smb2_main_check_metatile_under_enemy
    CPY #UpsideDownPiranhaP  ; if enemy object is upside-down piranha plant
    BEQ bra_smb2_main_exit_enemy_background_check  ; then branch to leave
    CPY #$07  ; if enemy object =>$07, branch to leave
    BCS bra_smb2_main_exit_enemy_background_check
bra_smb2_main_check_metatile_under_enemy:
    JSR sub_smb2_main_check_metatile_under_enemy  ; if enemy object < $07, or = $12 or $2e, do this sub
    BNE bra_smb2_main_handle_enemy_floor_collision  ; if block underneath enemy, branch

bra_smb2_main_handle_enemy_without_floor_collision:
    JMP bra_smb2_main_check_red_koopa_edge  ; otherwise skip and do something else

; --------------------------------
; $02 - vertical coordinate from block buffer routine

bra_smb2_main_handle_enemy_floor_collision:
    JSR sub_smb2_main_check_non_solid_enemy_metatile  ; if something is underneath enemy, find out what
    BEQ bra_smb2_main_handle_enemy_without_floor_collision  ; if blank $26, coins, or hidden blocks, jump, enemy falls through
    CMP #$20
    BNE bra_smb2_main_land_enemy_on_metatile  ; check for blank metatile $20 and branch if not found
    LDA Enemy_ID,x
    CMP #$15  ; if enemy object => $15, branch ahead
    BCS sub_smb2_main_check_enemy_stun_eligibility
    CMP #Goomba  ; if enemy object not goomba, branch ahead of this routine
    BNE bra_smb2_main_award_block_hit_enemy_points
    JSR sub_smb2_main_kill_enemy_above_block  ; if enemy object IS goomba, do this sub

bra_smb2_main_award_block_hit_enemy_points:
    LDA #$01  ; award 100 points for hitting block beneath enemy
    JSR sub_smb2_main_setup_floatey_number

sub_smb2_main_check_enemy_stun_eligibility:
    LDA Enemy_ID,x
    CMP #$09  ; perform many comparisons on enemy object identifier
    BCC sub_smb2_main_no_demote  ; if the enemy object identifier is equal to the values
    CMP #$11  ; $0e-$10 it will be demoted, in practice $0e and $10
    BCS sub_smb2_main_no_demote  ; are values used by green paratroopas
    CMP #PiranhaPlant
    BEQ sub_smb2_main_no_demote  ; enemy objects $0a-$0d will not be demoted
    CMP #UpsideDownPiranhaP
    BEQ sub_smb2_main_no_demote
    CMP #$0a  ; demote enemy object $09 even though it is not used
    BCC bra_smb2_main_demote_stunned_enemy
    CMP #PiranhaPlant
    BCC sub_smb2_main_no_demote
bra_smb2_main_demote_stunned_enemy:
    AND #%00000001  ; erase all but LSB, essentially turning enemy object
    STA Enemy_ID,x  ; into green or red koopa troopa to demote them
sub_smb2_main_no_demote:
    CMP #PowerUpObject
    BEQ bra_smb2_main_bounce_off  ; if power-up object, branch to bounce it
    CMP #Goomba
    BEQ bra_smb2_main_bounce_off  ; redundant, already checked for goomba
    LDA #$02
    STA Enemy_State,x  ; set enemy state to 2 (stunned)
bra_smb2_main_bounce_off:
    DEC Enemy_Y_Position,x
    DEC Enemy_Y_Position,x  ; subtract two pixels from enemy's vertical position
    LDA Enemy_ID,x
    CMP #Bloober  ; check for bloober object
    BEQ bra_smb2_main_use_water_stun_y_speed
    LDA #$fd  ; set default vertical speed
    LDY AreaType
    BNE bra_smb2_main_store_stunned_enemy_y_speed  ; if area type not water, set as speed, otherwise
bra_smb2_main_use_water_stun_y_speed:
    LDA #$ff  ; change the vertical speed
bra_smb2_main_store_stunned_enemy_y_speed:
    STA Enemy_Y_Speed,x  ; set vertical speed now
    LDY #$01
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between player and enemy object
    BPL bra_smb2_main_check_stunned_bullet_bill  ; branch if enemy is to the right of player
    INY  ; increment Y if not
bra_smb2_main_check_stunned_bullet_bill:
    LDA Enemy_ID,x
    CMP #BulletBill_CannonVar  ; check for bullet bill (cannon variant)
    BEQ bra_smb2_main_preserve_bullet_bill_direction
    CMP #BulletBill_FrenzyVar  ; check for bullet bill (frenzy variant)
    BEQ bra_smb2_main_preserve_bullet_bill_direction  ; branch if either found, direction does not change
    STY Enemy_MovingDir,x  ; store as moving direction
bra_smb2_main_preserve_bullet_bill_direction:
    DEY  ; decrement and use as offset
    LDA off_smb2_main_enemy_background_collision_x_speeds,y  ; get proper horizontal speed
    STA Enemy_X_Speed,x  ; and store, then leave
loc_smb2_main_exit_enemy_background_collision:
    RTS

; --------------------------------
; $04 - low nybble of vertical coordinate from block buffer routine

bra_smb2_main_land_enemy_on_metatile:
    LDA $04  ; check lower nybble of vertical coordinate saved earlier
    SEC
    SBC #$08  ; subtract eight pixels
    CMP #$05  ; used to determine whether enemy landed from falling
    BCS bra_smb2_main_check_red_koopa_edge  ; branch if lower nybble in range of $0d-$0f before subtract
    LDA Enemy_State,x
    AND #%01000000  ; branch if d6 in enemy state is set
    BNE bra_smb2_main_land_enemy_and_initialize_state
    LDA Enemy_State,x
    ASL  ; branch if d7 in enemy state is not set
    BCC bra_smb2_main_check_landed_enemy_state
bra_smb2_main_run_enemy_side_collision_check:
    JMP loc_smb2_main_check_enemy_side_collisions  ; if lower nybble < $0d, d7 set but d6 not set, jump here

bra_smb2_main_check_landed_enemy_state:
    LDA Enemy_State,x  ; if enemy in normal state, branch back to jump here
    BEQ bra_smb2_main_run_enemy_side_collision_check
    CMP #$05  ; if in state used by spiny's egg
    BEQ bra_smb2_main_update_landed_enemy_direction  ; then branch elsewhere
    CMP #$03  ; if already in state used by koopas and buzzy beetles
    BCS bra_smb2_main_exit_landed_enemy_state_check  ; or in higher numbered state, branch to leave
    LDA Enemy_State,x  ; load enemy state again (why?)
    CMP #$02  ; if not in $02 state (used by koopas and buzzy beetles)
    BNE bra_smb2_main_update_landed_enemy_direction  ; then branch elsewhere
    LDA #$10  ; load default timer here
    LDY Enemy_ID,x  ; check enemy identifier for spiny
    CPY #Spiny
    BNE bra_smb2_main_store_stunned_enemy_timer  ; branch if not found
    LDA #$00  ; set timer for $00 if spiny
bra_smb2_main_store_stunned_enemy_timer:
    STA EnemyIntervalTimer,x  ; set timer here
    LDA #$03  ; set state here, apparently used to render
    STA Enemy_State,x  ; upside-down koopas and buzzy beetles
    JSR sub_smb2_main_enemy_landing  ; then land it properly
bra_smb2_main_exit_landed_enemy_state_check:
    RTS  ; then leave

bra_smb2_main_update_landed_enemy_direction:
    LDA Enemy_ID,x  ; check enemy identifier for goomba
    CMP #Goomba  ; branch if found
    BEQ bra_smb2_main_land_enemy_and_initialize_state
    CMP #Spiny  ; check for spiny
    BNE bra_smb2_main_face_landed_enemy_toward_player  ; branch if not found
    LDA #$01
    STA Enemy_MovingDir,x  ; send enemy moving to the right by default
    LDA #$08
    STA Enemy_X_Speed,x  ; set horizontal speed accordingly
    LDA FrameCounter
    AND #%00000111  ; if timed appropriately, spiny will skip over
    BEQ bra_smb2_main_land_enemy_and_initialize_state  ; trying to face the player
bra_smb2_main_face_landed_enemy_toward_player:
    LDY #$01  ; load 1 for enemy to face the left (inverted here)
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between player and enemy
    BPL bra_smb2_main_compare_new_enemy_direction  ; if enemy to the right of player, branch
    INY  ; if to the left, increment by one for enemy to face right (inverted)
bra_smb2_main_compare_new_enemy_direction:
    TYA
    CMP Enemy_MovingDir,x  ; compare direction in A with current direction in memory
    BNE bra_smb2_main_land_enemy_and_initialize_state
    JSR sub_smb2_main_handle_enemy_bump_or_hammer_bro_jump  ; if equal, not facing in correct dir, do sub to turn around

bra_smb2_main_land_enemy_and_initialize_state:
    JSR sub_smb2_main_enemy_landing  ; land enemy properly
    LDA Enemy_State,x
    AND #%10000000  ; if d7 of enemy state is set, branch
    BNE bra_smb2_main_clear_moving_shell_fall_bit
    LDA #$00  ; otherwise initialize enemy state and leave
    STA Enemy_State,x  ; note this will also turn spiny's egg into spiny
    RTS

bra_smb2_main_clear_moving_shell_fall_bit:
    LDA Enemy_State,x  ; nullify d6 of enemy state, save other bits
    AND #%10111111  ; and store, then leave
    STA Enemy_State,x
    RTS

; --------------------------------

bra_smb2_main_check_red_koopa_edge:
    LDA Enemy_ID,x  ; check for red koopa troopa $03
    CMP #RedKoopa
    BNE bra_smb2_main_update_landed_enemy_state  ; branch if not found
    LDA Enemy_State,x
    BEQ sub_smb2_main_handle_enemy_bump_or_hammer_bro_jump  ; if enemy found and in normal state, branch
bra_smb2_main_update_landed_enemy_state:
    LDA Enemy_State,x  ; save enemy state into Y
    TAY
    ASL  ; check for d7 set
    BCC bra_smb2_main_map_landed_enemy_state  ; branch if not set
    LDA Enemy_State,x
    ORA #%01000000  ; set d6
    JMP loc_smb2_main_store_landed_enemy_state  ; jump ahead of this part
bra_smb2_main_map_landed_enemy_state:
    LDA off_smb2_main_enemy_background_collision_states,y  ; load new enemy state with old as offset
loc_smb2_main_store_landed_enemy_state:
    STA Enemy_State,x  ; set as new state

; --------------------------------
; $00 - used to store bitmask (not used but initialized here)
; $eb - used in DoEnemySideCheck as counter and to compare moving directions

loc_smb2_main_check_enemy_side_collisions:
    LDA Enemy_Y_Position,x  ; if enemy within status bar, branch to leave
    CMP #$20  ; because there's nothing there that impedes movement
    BCC bra_smb2_main_exit_enemy_side_collision
    LDY #$16  ; start by finding block to the left of enemy ($00,$14)
    LDA #$02  ; set value here in what is also used as
    STA $eb  ; OAM data offset
bra_smb2_main_check_enemy_side_collision_loop:
    LDA $eb  ; check value
    CMP Enemy_MovingDir,x  ; compare value against moving direction
    BNE bra_smb2_main_check_next_enemy_side  ; branch if different and do not seek block there
    LDA #$01  ; set flag in A for save horizontal coordinate
    JSR sub_smb2_main_check_enemy_block_buffer  ; find block to left or right of enemy object
    BEQ bra_smb2_main_check_next_enemy_side  ; if nothing found, branch
    JSR sub_smb2_main_check_non_solid_enemy_metatile  ; check for non-solid blocks
    BNE sub_smb2_main_handle_enemy_bump_or_hammer_bro_jump  ; branch if not found
bra_smb2_main_check_next_enemy_side:
    DEC $eb  ; move to the next direction
    INY
    CPY #$18  ; increment Y, loop only if Y < $18, thus we check
    BCC bra_smb2_main_check_enemy_side_collision_loop  ; enemy ($00, $14) and ($10, $14) pixel coordinates
bra_smb2_main_exit_enemy_side_collision:
    RTS

sub_smb2_main_handle_enemy_bump_or_hammer_bro_jump:
    CPX #$05  ; check if we're on the special use slot
    BEQ bra_smb2_main_handle_enemy_side_obstruction  ; and if so, branch ahead and do not play sound
    LDA Enemy_State,x  ; if enemy state d7 not set, branch
    ASL  ; ahead and do not play sound
    BCC bra_smb2_main_handle_enemy_side_obstruction
    LDA #Sfx_Bump  ; otherwise, play bump sound
    STA Square1SoundQueue  ; sound will never be played if branching from ChkForRedKoopa
bra_smb2_main_handle_enemy_side_obstruction:
    LDA Enemy_ID,x  ; check for hammer bro
    CMP #$05
    BNE bra_smb2_main_reverse_enemy_direction  ; branch if not found
    LDA #$00
    STA $00  ; initialize value here for bitmask
    LDY #$fa  ; load default vertical speed for jumping
    JMP bra_smb2_main_start_hammer_bro_jump  ; jump to code that makes hammer bro jump

bra_smb2_main_reverse_enemy_direction:
    JMP bra_smb2_main_reverse_enemy_x_speed  ; jump to turn the enemy around

; --------------------------------
; $00 - used to hold horizontal difference between player and enemy

sub_smb2_main_player_enemy_diff:
    LDA Enemy_X_Position,x  ; get distance between enemy object's
    SEC  ; horizontal coordinate and the player's
    SBC Player_X_Position  ; horizontal coordinate
    STA $00  ; and store here
    LDA Enemy_PageLoc,x
    SBC Player_PageLoc  ; subtract borrow, then leave
    RTS

; --------------------------------

sub_smb2_main_enemy_landing:
    JSR sub_smb2_main_clear_enemy_vertical_motion  ; do something here to vertical speed and something else
    LDA Enemy_Y_Position,x
    AND #%11110000  ; save high nybble of vertical coordinate, and
    ORA #%00001000  ; set d3, then store, probably used to set enemy object
    STA Enemy_Y_Position,x  ; neatly on whatever it's landing on
    RTS

sub_smb2_main_adjust_enemy_y_for_floor_check:
    LDA Enemy_Y_Position,x  ; add 62 pixels to enemy object's
    CLC  ; vertical coordinate
    ADC #$3e
    CMP #$44  ; compare against a certain range
    RTS  ; and leave with flags set for conditional branch

sub_smb2_main_enemy_jump:
    JSR sub_smb2_main_adjust_enemy_y_for_floor_check  ; do a sub here
    BCC bra_smb2_main_move_enemy_from_side_obstruction  ; if enemy vertical coord + 62 < 68, branch to leave
    LDA Enemy_Y_Speed,x
    CLC  ; add two to vertical speed
    ADC #$02
    CMP #$03  ; if green paratroopa not falling, branch ahead
    BCC bra_smb2_main_move_enemy_from_side_obstruction
    JSR sub_smb2_main_check_metatile_under_enemy  ; otherwise, check to see if green paratroopa is
    BEQ bra_smb2_main_move_enemy_from_side_obstruction  ; standing on anything, then branch to same place if not
    JSR sub_smb2_main_check_non_solid_enemy_metatile  ; check for non-solid blocks
    BEQ bra_smb2_main_move_enemy_from_side_obstruction  ; branch if found
    JSR sub_smb2_main_enemy_landing  ; change vertical coordinate and speed
    LDA #$fd
    STA Enemy_Y_Speed,x  ; make the paratroopa jump again
bra_smb2_main_move_enemy_from_side_obstruction:
    JMP loc_smb2_main_check_enemy_side_collisions  ; check for horizontal blockage, then leave

; --------------------------------

loc_smb2_main_handle_hammer_bro_background_collision:
    JSR sub_smb2_main_check_metatile_under_enemy  ; check to see if hammer bro is standing on anything
    BEQ bra_smb2_main_set_hammer_bro_airborne
    CMP #$20  ; check for blank metatile $20 and branch if not found
    BNE bra_smb2_main_land_hammer_bro

sub_smb2_main_kill_enemy_above_block:
    JSR sub_smb2_main_shell_or_block_defeat  ; do this sub to kill enemy
    LDA #$fc  ; alter vertical speed of enemy and leave
    STA Enemy_Y_Speed,x
    RTS

bra_smb2_main_land_hammer_bro:
    LDA EnemyFrameTimer,x  ; check timer used by hammer bro
    BNE bra_smb2_main_set_hammer_bro_airborne  ; branch if not expired
    LDA Enemy_State,x
    AND #%10001000  ; save d7 and d3 from enemy state, nullify other bits
    STA Enemy_State,x  ; and store
    JSR sub_smb2_main_enemy_landing  ; modify vertical coordinate, speed and something else
    JMP loc_smb2_main_check_enemy_side_collisions  ; then check for horizontal blockage and leave

bra_smb2_main_set_hammer_bro_airborne:
    LDA Enemy_State,x  ; if hammer bro is not standing on anything, set d0
    ORA #$01  ; in the enemy state to indicate jumping or falling, then leave
    STA Enemy_State,x
    RTS

sub_smb2_main_check_metatile_under_enemy:
    LDA #$00  ; set flag in A for save vertical coordinate
    LDY #$15  ; set Y to check the bottom middle (8,18) of enemy object
    JMP sub_smb2_main_check_enemy_block_buffer  ; hop to it!

sub_smb2_main_check_non_solid_enemy_metatile:
    CMP #$23  ; blank metatile used for vines?
    BEQ bra_smb2_main_return_enemy_floor_metatile_test
    CMP #$c3  ; regular coin?
    BEQ bra_smb2_main_return_enemy_floor_metatile_test
    CMP #$c4  ; underwater coin?
    BEQ bra_smb2_main_return_enemy_floor_metatile_test
    CMP #$5e  ; hidden coin block?
    BEQ bra_smb2_main_return_enemy_floor_metatile_test
    CMP #$5f  ; hidden 1-up block?
    BEQ bra_smb2_main_return_enemy_floor_metatile_test
    CMP #$60  ; hidden poison shroom block?
    BEQ bra_smb2_main_return_enemy_floor_metatile_test
    CMP #$61  ; hidden power-up block?
bra_smb2_main_return_enemy_floor_metatile_test:
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_handle_fireball_background_collision:
    LDA Fireball_Y_Position,x  ; check fireball's vertical coordinate
    CMP #$18
    BCC bra_smb2_main_clear_fireball_bounce_flag  ; if within the status bar area of the screen, branch ahead
    JSR sub_smb2_main_check_fireball_block_buffer  ; do fireball to background collision detection on bottom of it
    BEQ bra_smb2_main_clear_fireball_bounce_flag  ; if nothing underneath fireball, branch
    JSR sub_smb2_main_check_non_solid_enemy_metatile  ; check for non-solid metatiles
    BEQ bra_smb2_main_clear_fireball_bounce_flag  ; branch if any found
    LDA Fireball_Y_Speed,x  ; if fireball's vertical speed set to move upwards,
    BMI bra_smb2_main_start_fireball_explosion  ; branch to set exploding bit in fireball's state
    LDA FireballBouncingFlag,x  ; if bouncing flag already set,
    BNE bra_smb2_main_start_fireball_explosion  ; branch to set exploding bit in fireball's state
    LDA #$fd
    STA Fireball_Y_Speed,x  ; otherwise set vertical speed to move upwards (give it bounce)
    LDA #$01
    STA FireballBouncingFlag,x  ; set bouncing flag
    LDA Fireball_Y_Position,x
    AND #$f8  ; modify vertical coordinate to land it properly
    STA Fireball_Y_Position,x  ; store as new vertical coordinate
    RTS  ; leave

bra_smb2_main_clear_fireball_bounce_flag:
    LDA #$00
    STA FireballBouncingFlag,x  ; clear bouncing flag by default
    RTS  ; leave

bra_smb2_main_start_fireball_explosion:
    LDA #$80
    STA Fireball_State,x  ; set exploding flag in fireball's state
    LDA #Sfx_Bump
    STA Square1SoundQueue  ; load bump sound
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00 - used to hold one of bitmasks, or offset
; $01 - used for relative X coordinate, also used to store middle screen page location
; $02 - used for relative Y coordinate, also used to store middle screen coordinate

; this data added to relative coordinates of sprite objects
; stored in order: left edge, top edge, right edge, bottom edge
