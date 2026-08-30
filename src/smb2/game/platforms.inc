handler_smb2_main_move_vertical_platform:
    LDA Enemy_Y_Speed,x  ; if platform moving up or down, skip ahead to
    ORA Enemy_Y_MoveForce,x  ; check on other position
    BNE bra_smb2_main_select_vertical_platform_direction
    STA Enemy_YMF_Dummy,x  ; initialize dummy variable
    LDA Enemy_Y_Position,x
    CMP YPlatformTopYPos,x  ; if current vertical position => top position, branch
    BCS bra_smb2_main_select_vertical_platform_direction  ; ahead of all this
    LDA FrameCounter
    AND #%00000111  ; check for every eighth frame
    BNE bra_smb2_main_finish_idle_vertical_platform_adjustment
    INC Enemy_Y_Position,x  ; increase vertical position every eighth frame
bra_smb2_main_finish_idle_vertical_platform_adjustment:
    JMP loc_smb2_main_position_player_on_vertical_platform  ; skip ahead to last part

bra_smb2_main_select_vertical_platform_direction:
    LDA Enemy_Y_Position,x  ; if current vertical position < central position, branch
    CMP YPlatformCenterYPos,x  ; to slow ascent/move downwards
    BCC bra_smb2_main_move_vertical_platform_down
    JSR sub_smb2_main_move_platform_up  ; otherwise start slowing descent/moving upwards
    JMP loc_smb2_main_position_player_on_vertical_platform
bra_smb2_main_move_vertical_platform_down:
    JSR sub_smb2_main_move_platform_down  ; start slowing ascent/moving downwards

loc_smb2_main_position_player_on_vertical_platform:
    LDA PlatformCollisionFlag,x  ; if collision flag not set here, branch
    BMI bra_smb2_main_exit_vertical_platform  ; to leave
    JSR sub_smb2_main_position_player_on_vertical_platform  ; otherwise position player appropriately
bra_smb2_main_exit_vertical_platform:
    RTS  ; leave

; --------------------------------
; $00 - used as adder to position player hotizontally

handler_smb2_main_move_horizontal_platform:
    LDA #$0e  ; load preset maximum value for secondary counter
    JSR sub_smb2_main_update_platform_x_movement_counters  ; do a sub to increment counters for movement
    JSR sub_smb2_main_move_with_x_movement_counters  ; do a sub to move platform accordingly, and return value
    LDA PlatformCollisionFlag,x  ; if no collision with player,
    BMI bra_smb2_main_exit_horizontal_platform  ; branch ahead to leave

sub_smb2_main_position_player_on_horizontal_platform:
    LDA Player_X_Position
    CLC  ; add saved value from second subroutine to
    ADC $00  ; current player's position to position
    STA Player_X_Position  ; player accordingly in horizontal position
    LDA Player_PageLoc  ; get player's page location
    LDY $00  ; check to see if saved value here is positive or negative
    BMI bra_smb2_main_adjust_player_page_for_left_platform_motion  ; if negative, branch to subtract
    ADC #$00  ; otherwise add carry to page location
    JMP loc_smb2_main_store_horizontal_platform_effect  ; jump to skip subtraction
bra_smb2_main_adjust_player_page_for_left_platform_motion:
    SBC #$00  ; subtract borrow from page location
loc_smb2_main_store_horizontal_platform_effect:
    STA Player_PageLoc  ; save result to player's page location
    STY Platform_X_Scroll  ; put saved value from second sub here to be used later
    JSR sub_smb2_main_position_player_on_vertical_platform  ; position player vertically and appropriately
bra_smb2_main_exit_horizontal_platform:
    RTS  ; and we are done here

; --------------------------------

handler_smb2_main_move_drop_platform:
    LDA PlatformCollisionFlag,x  ; if no collision between platform and player
    BMI bra_smb2_main_exit_drop_platform  ; occurred, just leave without moving anything
    JSR sub_smb2_main_move_drop_platform  ; otherwise do a sub to move platform down very quickly
    JSR sub_smb2_main_position_player_on_vertical_platform  ; do a sub to position player appropriately
bra_smb2_main_exit_drop_platform:
    RTS  ; leave

; --------------------------------
; $00 - residual value from sub

handler_smb2_main_move_right_platform:
    JSR sub_smb2_main_move_enemy_horizontally  ; move platform with current horizontal speed, if any
    STA $00  ; store saved value here (residual code)
    LDA PlatformCollisionFlag,x  ; check collision flag, if no collision between player
    BMI bra_smb2_main_exit_right_moving_platform  ; and platform, branch ahead, leave speed unaltered
    LDA #$10
    STA Enemy_X_Speed,x  ; otherwise set new speed (gets moving if motionless)
    JSR sub_smb2_main_position_player_on_horizontal_platform  ; use saved value from earlier sub to position player
bra_smb2_main_exit_right_moving_platform:
    RTS  ; then leave

; --------------------------------

handler_smb2_main_move_large_lift_platform:
    JSR sub_smb2_main_move_lift_platforms  ; execute common to all large and small lift platforms
    JMP loc_smb2_main_position_player_on_vertical_platform  ; branch to position player correctly

sub_smb2_main_move_small_platform:
    JSR sub_smb2_main_move_lift_platforms  ; execute common to all large and small lift platforms
    JMP loc_smb2_main_check_small_platform_collision  ; branch to position player correctly

sub_smb2_main_move_lift_platforms:
    LDA TimerControl  ; if master timer control set, skip all of this
    BNE bra_smb2_main_exit_lift_platform  ; and branch to leave
    LDA Enemy_YMF_Dummy,x
    CLC  ; add contents of movement amount to whatever's here
    ADC Enemy_Y_MoveForce,x
    STA Enemy_YMF_Dummy,x
    LDA Enemy_Y_Position,x  ; add whatever vertical speed is set to current
    ADC Enemy_Y_Speed,x  ; vertical position plus carry to move up or down
    STA Enemy_Y_Position,x  ; and then leave
    RTS

loc_smb2_main_check_small_platform_collision:
    LDA PlatformCollisionFlag,x  ; get bounding box counter saved in collision flag
    BEQ bra_smb2_main_exit_lift_platform  ; if none found, leave player position alone
    JSR sub_smb2_main_position_player_on_small_platform  ; use to position player correctly
bra_smb2_main_exit_lift_platform:
    RTS  ; then leave

; -------------------------------------------------------------------------------------
; $00 - page location of extended left boundary
; $01 - extended left boundary position
; $02 - page location of extended right boundary
; $03 - extended right boundary position

sub_smb2_main_offscreen_bounds_check:
    LDA Enemy_ID,x  ; check for cheep-cheep object
    CMP #FlyingCheepCheep  ; branch to leave if found
    BEQ bra_smb2_main_exit_offscreen_bounds_check
    LDA ScreenLeft_X_Pos  ; get horizontal coordinate for left side of screen
    LDY Enemy_ID,x
    CPY #HammerBro  ; check for hammer bro object
    BEQ bra_smb2_main_limit_left_offscreen_bound
    CPY #UpsideDownPiranhaP  ; check for upside-down piranha plant object
    BEQ bra_smb2_main_limit_left_offscreen_bound
    CPY #PiranhaPlant  ; check for piranha plant object
    BNE bra_smb2_main_extend_left_offscreen_bound  ; these three will be erased sooner than others if too far left
bra_smb2_main_limit_left_offscreen_bound:
    ADC #$38  ; add 56 pixels to coordinate if hammer bro or piranha plant
bra_smb2_main_extend_left_offscreen_bound:
    SBC #$48  ; subtract 72 pixels regardless of enemy object
    STA $01  ; store result here
    LDA ScreenLeft_PageLoc
    SBC #$00  ; subtract borrow from page location of left side
    STA $00  ; store result here
    LDA ScreenRight_X_Pos  ; add 72 pixels to the right side horizontal coordinate
    ADC #$48
    STA $03  ; store result here
    LDA ScreenRight_PageLoc
    ADC #$00  ; then add the carry to the page location
    STA $02  ; and store result here
    LDA Enemy_X_Position,x  ; compare horizontal coordinate of the enemy object
    CMP $01  ; to modified horizontal left edge coordinate to get carry
    LDA Enemy_PageLoc,x
    SBC $00  ; then subtract it from the page coordinate of the enemy object
    BMI bra_smb2_main_erase_far_offscreen_enemy  ; if enemy object is too far left, branch to erase it
    LDA Enemy_X_Position,x  ; compare horizontal coordinate of the enemy object
    CMP $03  ; to modified horizontal right edge coordinate to get carry
    LDA Enemy_PageLoc,x
    SBC $02  ; then subtract it from the page coordinate of the enemy object
    BMI bra_smb2_main_exit_offscreen_bounds_check  ; if enemy object is on the screen, leave, do not erase enemy
    LDA Enemy_State,x  ; if at this point, enemy is offscreen to the right, so check
    CMP #HammerBro  ; if in state used by spiny's egg, do not erase
    BEQ bra_smb2_main_exit_offscreen_bounds_check
    CPY #PiranhaPlant  ; if piranha plant, do not erase
    BEQ bra_smb2_main_exit_offscreen_bounds_check
    CPY #UpsideDownPiranhaP  ; if upside-down piranha plant, do not erase
    BEQ bra_smb2_main_exit_offscreen_bounds_check
    CPY #FlagpoleFlagObject  ; if flagpole flag, do not erase
    BEQ bra_smb2_main_exit_offscreen_bounds_check
    CPY #StarFlagObject  ; if star flag, do not erase
    BEQ bra_smb2_main_exit_offscreen_bounds_check
    CPY #JumpspringObject  ; if jumpspring, do not erase
    BEQ bra_smb2_main_exit_offscreen_bounds_check  ; erase all others too far to the right
bra_smb2_main_erase_far_offscreen_enemy:
    JSR sub_smb2_main_erase_enemy_object  ; erase object if necessary
bra_smb2_main_exit_offscreen_bounds_check:
    RTS  ; leave

; unused space
    .byte $ff

; -------------------------------------------------------------------------------------
; $01 - enemy buffer offset

sub_smb2_main_fireball_enemy_collision:
    LDA Fireball_State,x  ; check to see if fireball state is set at all
    BEQ bra_smb2_main_exit_fireball_enemy_collision  ; branch to leave if not
    ASL
    BCS bra_smb2_main_exit_fireball_enemy_collision  ; branch to leave also if d7 in state is set
    LDA FrameCounter
    LSR  ; get LSB of frame counter
    BCS bra_smb2_main_exit_fireball_enemy_collision  ; branch to leave if set (do routine every other frame)
    TXA
    ASL  ; multiply fireball offset by four
    ASL
    CLC
    ADC #$1c  ; then add $1c or 28 bytes to it
    TAY  ; to use fireball's bounding box coordinates
    LDX #$04

bra_smb2_main_check_fireball_enemy_collision_loop:
    STX $01  ; store enemy object offset here
    TYA
    PHA  ; push fireball offset to the stack
    LDA Enemy_State,x
    AND #%00100000  ; check to see if d5 is set in enemy state
    BNE bra_smb2_main_advance_fireball_enemy_collision  ; if so, skip to next enemy slot
    LDA Enemy_Flag,x  ; check to see if buffer flag is set
    BEQ bra_smb2_main_advance_fireball_enemy_collision  ; if not, skip to next enemy slot
    LDA Enemy_ID,x  ; check enemy identifier
    CMP #$24
    BCC bra_smb2_main_defeat_goomba_with_fireball  ; if < $24, branch to check further
    CMP #$2b
    BCC bra_smb2_main_advance_fireball_enemy_collision  ; if in range $24-$2a, skip to next enemy slot
bra_smb2_main_defeat_goomba_with_fireball:
    CMP #Goomba  ; check for goomba identifier
    BNE bra_smb2_main_defeat_non_goomba_with_fireball  ; if not found, continue with code
    LDA Enemy_State,x  ; otherwise check for defeated state
    CMP #$02  ; if stomped or otherwise defeated,
    BCS bra_smb2_main_advance_fireball_enemy_collision  ; skip to next enemy slot
bra_smb2_main_defeat_non_goomba_with_fireball:
    LDA EnemyOffscrBitsMasked,x  ; if any masked offscreen bits set,
    BNE bra_smb2_main_advance_fireball_enemy_collision  ; skip to next enemy slot
    TXA
    ASL  ; otherwise multiply enemy offset by four
    ASL
    CLC
    ADC #$04  ; add 4 bytes to it
    TAX  ; to use enemy's bounding box coordinates
    JSR sub_smb2_main_sprite_object_collision_core  ; do fireball-to-enemy collision detection
    LDX ObjectOffset  ; return fireball's original offset
    BCC bra_smb2_main_advance_fireball_enemy_collision  ; if carry clear, no collision, thus do next enemy slot
    LDA #%10000000
    STA Fireball_State,x  ; set d7 in enemy state
    LDX $01  ; get enemy offset
    JSR sub_smb2_main_handle_enemy_fireball_collision  ; jump to handle fireball to enemy collision
bra_smb2_main_advance_fireball_enemy_collision:
    PLA  ; pull fireball offset from stack
    TAY  ; put it in Y
    LDX $01  ; get enemy object offset
    DEX  ; decrement it
    BPL bra_smb2_main_check_fireball_enemy_collision_loop  ; loop back until collision detection done on all enemies

bra_smb2_main_exit_fireball_enemy_collision:
    LDX ObjectOffset  ; get original fireball offset and leave
    RTS

tbl_smb2_main_bowser_disguise_enemy_ids:
    .byte Goomba, GreenKoopa, BuzzyBeetle, Spiny, Lakitu, Bloober, HammerBro, Bowser, Bowser

sub_smb2_main_handle_enemy_fireball_collision:
    JSR sub_smb2_main_relative_enemy_position  ; get relative coordinate of enemy
    LDX $01  ; get current enemy object offset
    LDA Enemy_Flag,x  ; check buffer flag for d7 set
    BPL bra_smb2_main_check_buzzy_beetle_fireball_immunity  ; branch if not set to continue
    AND #%00001111  ; otherwise mask out high nybble and
    TAX  ; use low nybble as enemy offset
    LDA Enemy_ID,x
    CMP #Bowser  ; check enemy identifier for bowser
    BEQ bra_smb2_main_damage_bowser_with_fireball  ; branch if found
    LDX $01  ; otherwise retrieve current enemy offset

bra_smb2_main_check_buzzy_beetle_fireball_immunity:
    LDA Enemy_ID,x
    CMP #BuzzyBeetle  ; check for buzzy beetle
    BEQ bra_smb2_main_exit_enemy_fireball_collision  ; branch if found to leave (buzzy beetles fireproof)
    CMP #Bowser  ; check for bowser one more time (necessary if d7 of flag was clear)
    BNE bra_smb2_main_check_other_fireball_enemy_targets  ; if not found, branch to check other enemies

bra_smb2_main_damage_bowser_with_fireball:
    DEC BowserHitPoints  ; decrement bowser's hit points
    BNE bra_smb2_main_exit_enemy_fireball_collision  ; if bowser still has hit points, branch to leave
    JSR sub_smb2_main_clear_enemy_vertical_motion  ; otherwise do sub to init vertical speed and movement force
    STA Enemy_X_Speed,x  ; initialize horizontal speed
    STA EnemyFrenzyBuffer  ; init enemy frenzy buffer
    LDA #$fe
    STA Enemy_Y_Speed,x  ; set vertical speed to make defeated bowser jump a little
    LDY WorldNumber  ; use world number as offset
    LDA tbl_smb2_main_bowser_disguise_enemy_ids,y  ; get enemy identifier to replace bowser with
    STA Enemy_ID,x  ; set as new enemy identifier
    LDA #$20  ; set A to use starting value for state
    CPY #$03  ; check to see if using offset of 3 or more
    BCS bra_smb2_main_store_defeated_bowser_state  ; branch if so
    ORA #$03  ; otherwise add 3 to enemy state
bra_smb2_main_store_defeated_bowser_state:
    STA Enemy_State,x  ; set defeated enemy state
    LDA #Sfx_BowserFall
    STA Square2SoundQueue  ; load bowser defeat sound
    LDX $01  ; get enemy offset
    LDA #$09  ; award 5000 points to player for defeating bowser
    BNE bra_smb2_main_award_enemy_defeat_score  ; unconditional branch to award points

bra_smb2_main_check_other_fireball_enemy_targets:
    CMP #BulletBill_FrenzyVar
    BEQ bra_smb2_main_exit_enemy_fireball_collision  ; branch to leave if bullet bill (frenzy variant)
    CMP #Podoboo
    BEQ bra_smb2_main_exit_enemy_fireball_collision  ; branch to leave if podoboo
    CMP #$15
    BCS bra_smb2_main_exit_enemy_fireball_collision  ; branch to leave if identifier => $15

sub_smb2_main_shell_or_block_defeat:
    LDA Enemy_ID,x  ; check for both kinds of piranha plant
    CMP #UpsideDownPiranhaP
    BEQ bra_smb2_main_defeat_piranha_plant
    CMP #PiranhaPlant
    BNE bra_smb2_main_stun_enemy_from_attack  ; branch if not found
bra_smb2_main_defeat_piranha_plant:
    TAY
    LDA Enemy_Y_Position,x
    ADC #$18  ; add 24 pixels to enemy object's vertical position
    CPY #UpsideDownPiranhaP  ; to put defeated piranha plant back in pipe
    BNE bra_smb2_main_set_destination_y_position
    SBC #$31  ; subtract 49 pixels to vertical position to put
bra_smb2_main_set_destination_y_position:
    STA Enemy_Y_Position,x  ; defeated upside down piranha plant back in pipe
bra_smb2_main_stun_enemy_from_attack:
    JSR sub_smb2_main_check_enemy_stun_eligibility  ; do yet another sub
    LDA Enemy_State,x
    AND #%00011111  ; mask out 2 MSB of enemy object's state
    ORA #%00100000  ; set d5 to defeat enemy and save as new state
    STA Enemy_State,x
    LDA #$02  ; award 200 points by default
    LDY Enemy_ID,x  ; check for hammer bro
    CPY #HammerBro
    BNE bra_smb2_main_award_goomba_fireball_points  ; branch if not found
    LDA #$06  ; award 1000 points for hammer bro

bra_smb2_main_award_goomba_fireball_points:
    CPY #Goomba  ; check for goomba
    BNE bra_smb2_main_award_enemy_defeat_score  ; branch if not found
    LDA #$01  ; award 100 points for goomba

bra_smb2_main_award_enemy_defeat_score:
    JSR sub_smb2_main_setup_floatey_number  ; update necessary score variables
    LDA #Sfx_EnemySmack  ; play smack enemy sound
    STA Square1SoundQueue
bra_smb2_main_exit_enemy_fireball_collision:
    RTS  ; and now let's leave

; -------------------------------------------------------------------------------------

sub_smb2_main_player_hammer_collision:
    LDA FrameCounter  ; get frame counter
    LSR  ; shift d0 into carry
    BCC bra_smb2_main_exit_player_hammer_collision  ; branch to leave if d0 not set to execute every other frame
    LDA Player_OffscreenBits  ; if player offscreen bits, master timer control
    ORA TimerControl  ; or any offscreen bits for hammer are set
    ORA Misc_OffscreenBits  ; then branch to leave
    BNE bra_smb2_main_exit_player_hammer_collision
    TXA
    ASL  ; multiply misc object offset by four
    ASL
    CLC
    ADC #$24  ; add 36 or $24 bytes to get proper offset
    TAY  ; for misc object bounding box coordinates
    JSR sub_smb2_main_player_collision_core  ; do player-to-hammer collision detection
    LDX ObjectOffset  ; get misc object offset
    BCC bra_smb2_main_clear_hammer_collision_flag  ; if no collision, then branch
    LDA Misc_Collision_Flag,x  ; otherwise read collision flag
    BNE bra_smb2_main_exit_player_hammer_collision  ; if collision flag already set, branch to leave
    LDA #$01
    STA Misc_Collision_Flag,x  ; otherwise set collision flag now
    LDA Misc_X_Speed,x
    EOR #$ff  ; get two's compliment of
    CLC  ; hammer's horizontal speed
    ADC #$01
    STA Misc_X_Speed,x  ; set to send hammer flying the opposite direction
    LDA StarInvincibleTimer  ; if star mario invincibility timer set,
    BNE bra_smb2_main_exit_player_hammer_collision  ; branch to leave
    JMP sub_smb2_main_injure_player  ; otherwise jump to hurt player, do not return
bra_smb2_main_clear_hammer_collision_flag:
    LDA #$00  ; clear collision flag
    STA Misc_Collision_Flag,x
bra_smb2_main_exit_player_hammer_collision:
    RTS

; -------------------------------------------------------------------------------------

loc_smb2_main_handle_power_up_collision:
    JSR sub_smb2_main_erase_enemy_object  ; erase the power-up object
    LDA PowerUpType
    CMP #$04  ; check power-up type
    BNE bra_smb2_main_safe  ; if not a poison shroom, branch
    JMP sub_smb2_main_injure_player  ; otherwise injure the player properly
bra_smb2_main_safe:
    LDA #$06
    JSR sub_smb2_main_setup_floatey_number  ; award 1000 points to player by default
    LDA #Sfx_PowerUpGrab
    STA Square2SoundQueue  ; play the power-up sound
    LDA PowerUpType  ; check power-up type
    CMP #$02
    BCC bra_smb2_main_apply_mushroom_or_flower_power_up  ; if mushroom or fire flower, branch
    CMP #$03
    BEQ bra_smb2_main_award_extra_life_power_up  ; if 1-up mushroom, branch
    LDA #$23  ; otherwise set star mario invincibility
    STA StarInvincibleTimer  ; timer, and load the star mario music
    LDA #StarPowerMusic  ; into the area music queue, then leave
    STA AreaMusicQueue
    RTS

bra_smb2_main_apply_mushroom_or_flower_power_up:
    LDA PlayerStatus  ; if player status = small, branch
    BEQ bra_smb2_main_upgrade_player_to_super
    CMP #$01  ; if player status not super, leave
    BNE bra_smb2_main_exit_power_up_collection
    LDX ObjectOffset  ; get enemy offset, not necessary
    LDA #$02  ; set player status to fiery
    STA PlayerStatus
    JSR sub_smb2_main_get_player_colors  ; run sub to change colors of player
    LDX ObjectOffset  ; get enemy offset again, and again not necessary
    LDA #$0c  ; set value to be used by subroutine tree (fiery)
    JMP loc_smb2_main_start_player_power_up_transition  ; jump to set values accordingly

bra_smb2_main_award_extra_life_power_up:
    LDA #$0b  ; change 1000 points into 1-up instead
    STA FloateyNum_Control,x  ; and then leave
    RTS

bra_smb2_main_upgrade_player_to_super:
    LDA #$01  ; set player status to super
    STA PlayerStatus
    LDA #$09  ; set value to be used by subroutine tree (super)

loc_smb2_main_start_player_power_up_transition:
    LDY #$00  ; set value to be used as new player state
    JSR sub_smb2_main_set_player_routine_state  ; set values to stop certain things in motion
bra_smb2_main_exit_power_up_collection:
    RTS

; --------------------------------
