tbl_smb2_main_residual_x_speeds:
    .byte $18, $e8

off_smb2_main_kicked_shell_x_speeds:
    .byte $30, $d0

off_smb2_main_demoted_koopa_x_speeds:
    .byte $08, $f8

sub_smb2_main_player_enemy_collision:
    LDA FrameCounter  ; check counter for d0 set
    LSR
    BCS bra_smb2_main_exit_power_up_collection  ; if set, branch to leave
    JSR sub_smb2_main_check_player_vertical  ; if player object is completely offscreen or
    BCS bra_smb2_main_exit_player_enemy_collision_early  ; if down past 224th pixel row, branch to leave
    LDA EnemyOffscrBitsMasked,x  ; if current enemy is offscreen by any amount,
    BNE bra_smb2_main_exit_player_enemy_collision_early  ; go ahead and branch to leave
    LDA GameEngineSubroutine
    CMP #$08  ; if not set to run player control routine
    BNE bra_smb2_main_exit_player_enemy_collision_early  ; on next frame, branch to leave
    LDA Enemy_State,x
    AND #%00100000  ; if enemy state has d5 set, branch to leave
    BNE bra_smb2_main_exit_player_enemy_collision_early
    JSR sub_smb2_main_get_enemy_bounding_box_offset  ; get bounding box offset for current enemy object
    JSR sub_smb2_main_player_collision_core  ; do collision detection on player vs. enemy
    LDX ObjectOffset  ; get enemy object buffer offset
    BCS bra_smb2_main_check_power_up_collision  ; if collision, branch past this part here
    LDA Enemy_CollisionBits,x
    AND #%11111110  ; otherwise, clear d0 of current enemy object's
    STA Enemy_CollisionBits,x  ; collision bit
bra_smb2_main_exit_player_enemy_collision_early:
    RTS

bra_smb2_main_check_power_up_collision:
    LDY Enemy_ID,x
    CPY #PowerUpObject  ; check for power-up object
    BNE bra_smb2_main_handle_enemy_collision  ; if not found, branch to next part
    JMP loc_smb2_main_handle_power_up_collision  ; otherwise, unconditional jump backwards
bra_smb2_main_handle_enemy_collision:
    LDA StarInvincibleTimer  ; if star mario invincibility timer expired,
    BEQ bra_smb2_main_resolve_player_enemy_collision  ; perform task here, otherwise kill enemy like
    JMP sub_smb2_main_shell_or_block_defeat  ; hit with a shell, or from beneath

off_smb2_main_kicked_shell_points:
    .byte $0a, $06, $04

bra_smb2_main_resolve_player_enemy_collision:
    LDA Enemy_CollisionBits,x  ; check enemy collision bits for d0 set
    AND #%00000001  ; or for being offscreen at all
    ORA EnemyOffscrBitsMasked,x
    BNE bra_smb2_main_exit_player_enemy_collision  ; branch to leave if either is true
    LDA #$01
    ORA Enemy_CollisionBits,x  ; otherwise set d0 now
    STA Enemy_CollisionBits,x
    CPY #Spiny  ; branch if spiny
    BEQ bra_smb2_main_check_player_injury_collision
    CPY #BulletBill_CannonVar  ; branch if bullet bill
    BEQ bra_smb2_main_check_player_injury_collision
    CPY #PiranhaPlant  ; branch if piranha plant
    BEQ sub_smb2_main_injure_player
    CPY #UpsideDownPiranhaP  ; branch if upside-down piranha plant
    BEQ sub_smb2_main_injure_player
    CPY #Podoboo  ; branch if podoboo
    BEQ sub_smb2_main_injure_player
    CPY #$15  ; branch if object => $15
    BCS sub_smb2_main_injure_player
    LDA AreaType  ; branch if water type level
    BEQ sub_smb2_main_injure_player
    LDA Enemy_State,x  ; branch if d7 of enemy state was set
    ASL
    BCS bra_smb2_main_check_player_injury_collision
    LDA Enemy_State,x  ; mask out all but 3 LSB of enemy state
    AND #%00000111
    CMP #$02  ; branch if enemy is in normal or falling state
    BCC bra_smb2_main_check_player_injury_collision
    LDA Enemy_ID,x  ; branch to leave if goomba in defeated state
    CMP #Goomba
    BEQ bra_smb2_main_exit_player_enemy_collision
    LDA #Sfx_EnemySmack  ; play smack enemy sound
    STA Square1SoundQueue
    LDA Enemy_State,x  ; set d7 in enemy state, thus become moving shell
    ORA #%10000000
    STA Enemy_State,x
    JSR sub_smb2_main_enemy_face_player  ; set moving direction and get offset
    LDA off_smb2_main_kicked_shell_x_speeds,y  ; load and set horizontal speed data with offset
    STA Enemy_X_Speed,x
    LDA #$03  ; add three to whatever the stomp counter contains
    CLC  ; to give points for kicking the shell
    ADC StompChainCounter
    LDY EnemyIntervalTimer,x  ; check shell enemy's timer
    CPY #$03  ; if above a certain point, branch using the points
    BCS bra_smb2_main_award_kicked_shell_points  ; data obtained from the stomp counter + 3
    LDA off_smb2_main_kicked_shell_points,y  ; otherwise, set points based on proximity to timer expiration
bra_smb2_main_award_kicked_shell_points:
    JSR sub_smb2_main_setup_floatey_number  ; set values for floatey number now
bra_smb2_main_exit_player_enemy_collision:
    RTS  ; leave!!!

bra_smb2_main_check_player_injury_collision:
    LDY Player_Y_Speed  ; check player's vertical speed
    DEY  ; branch elsewhere if player is not moving downwards
    BPL bra_smb2_main_enemy_stomped
loc_smb2_main_check_player_injury_immunity:
    LDA Enemy_ID,x  ; branch if enemy object < $07
    CMP #Bloober
    BCC bra_smb2_main_check_stomp_and_injury_timers
    LDA Player_Y_Position  ; add 12 pixels to player's vertical position
    CLC
    ADC #$0c
    CMP Enemy_Y_Position,x  ; compare modified player's position to enemy's position
    BCC bra_smb2_main_enemy_stomped  ; branch if this player's position above (less than) enemy's
bra_smb2_main_check_stomp_and_injury_timers:
    LDA StompTimer  ; check stomp timer
    BNE bra_smb2_main_enemy_stomped  ; branch if set
    LDA InjuryTimer  ; check to see if injured invincibility timer still
    BNE bra_smb2_main_exit_player_injury_collision  ; counting down, and branch elsewhere to leave if so
    LDA Player_Rel_XPos
    CMP Enemy_Rel_XPos  ; if player's relative position to the left of enemy's
    BCC bra_smb2_main_check_left_side_enemy_injury  ; relative position, branch here
    JMP loc_smb2_main_check_enemy_facing_right  ; otherwise do a jump here
bra_smb2_main_check_left_side_enemy_injury:
    LDA Enemy_MovingDir,x  ; if enemy moving towards the left,
    CMP #$01  ; branch, otherwise do a jump here
    BNE sub_smb2_main_injure_player  ; to turn the enemy around
    JMP bra_smb2_main_turn_enemy_then_injure_player

sub_smb2_main_injure_player:
    LDA InjuryTimer  ; check again to see if either of the two
    ORA StarInvincibleTimer  ; invincibility timers have expired, branch if not
    BNE bra_smb2_main_exit_player_injury_collision

sub_smb2_main_force_injury:
    LDX PlayerStatus  ; check player's status
    BEQ bra_smb2_main_kill_player_from_enemy_collision  ; branch if small
    STA PlayerStatus  ; otherwise set player's status to small
    LDA #$08
    STA InjuryTimer  ; set injured invincibility timer
    ASL
    STA Square1SoundQueue  ; play pipedown/injury sound
    JSR sub_smb2_main_get_player_colors  ; change player's palette if necessary
    LDA #$0a  ; set subroutine to run on next frame
bra_smb2_main_set_player_injury_or_death_task:
    LDY #$01  ; set new player state
sub_smb2_main_set_player_routine_state:
    STA GameEngineSubroutine  ; load new value to run subroutine on next frame
    STY Player_State  ; store new player state
    LDY #$ff
    STY TimerControl  ; set master timer control flag to halt timers
    INY
    STY ScrollAmount  ; initialize scroll speed

bra_smb2_main_exit_player_injury_collision:
    LDX ObjectOffset  ; get enemy offset and leave
    RTS

bra_smb2_main_kill_player_from_enemy_collision:
    STX Player_X_Speed  ; halt player's horizontal movement by initializing speed
    INX
    STX EventMusicQueue  ; set event music queue to death music
    LDA #$fc
    STA Player_Y_Speed  ; set new vertical speed
    LDA #$0b  ; set subroutine to run on next frame
    BNE bra_smb2_main_set_player_injury_or_death_task  ; branch to set player's state and other things

off_smb2_main_stomped_enemy_points:
    .byte $02, $06, $05, $06

bra_smb2_main_enemy_stomped:
    LDA Enemy_ID,x  ; check for spiny, branch to hurt player
    CMP #Spiny  ; if found
    BEQ sub_smb2_main_injure_player
    LDA #Sfx_EnemyStomp  ; otherwise play stomp/swim sound
    STA Square1SoundQueue
    LDA Enemy_ID,x
    LDY #$00  ; initialize points data offset for stomped enemies
    CMP #FlyingCheepCheep  ; branch for cheep-cheep
    BEQ bra_smb2_main_award_stomped_enemy_points
    CMP #BulletBill_FrenzyVar  ; branch for either bullet bill object
    BEQ bra_smb2_main_award_stomped_enemy_points
    CMP #BulletBill_CannonVar
    BEQ bra_smb2_main_award_stomped_enemy_points
    CMP #Podoboo  ; branch for podoboo (this branch is logically impossible
    BEQ bra_smb2_main_award_stomped_enemy_points  ; for cpu to take due to earlier checking of podoboo)
    INY  ; increment points data offset
    CMP #HammerBro  ; branch for hammer bro
    BEQ bra_smb2_main_award_stomped_enemy_points
    INY  ; increment points data offset
    CMP #Lakitu  ; branch for lakitu
    BEQ bra_smb2_main_award_stomped_enemy_points
    INY  ; increment points data offset
    CMP #Bloober  ; branch if NOT bloober
    BNE bra_smb2_main_check_koopa_demotion

bra_smb2_main_award_stomped_enemy_points:
    LDA off_smb2_main_stomped_enemy_points,y  ; load points data using offset in Y
    JSR sub_smb2_main_setup_floatey_number  ; run sub to set floatey number controls
    LDA Enemy_MovingDir,x
    PHA  ; save enemy movement direction to stack
    JSR sub_smb2_main_no_demote  ; run sub to kill enemy
    PLA
    STA Enemy_MovingDir,x  ; return enemy movement direction from stack
    LDA #%00100000
    STA Enemy_State,x  ; set d5 in enemy state
    JSR sub_smb2_main_clear_enemy_vertical_motion  ; nullify vertical speed, physics-related thing,
    STA Enemy_X_Speed,x  ; and horizontal speed
    JMP sub_smb2_main_set_bounce

bra_smb2_main_check_koopa_demotion:
    CMP #$09  ; branch elsewhere if enemy object < $09
    BCC bra_smb2_main_handle_stomped_shell_enemy
    JSR sub_smb2_main_set_bounce
    AND #%00000001  ; demote koopa paratroopas to ordinary troopas
    STA Enemy_ID,x
    LDA #$00  ; return enemy to normal state
    STA Enemy_State,x
    LDA #$03  ; award 400 points to the player
    JSR sub_smb2_main_setup_floatey_number
    JSR sub_smb2_main_clear_enemy_vertical_motion  ; nullify physics-related thing and vertical speed
    JSR sub_smb2_main_enemy_face_player  ; turn enemy around if necessary
    LDA off_smb2_main_demoted_koopa_x_speeds,y
    STA Enemy_X_Speed,x  ; set appropriate moving speed based on direction
    RTS

off_smb2_main_enemy_revival_delays:
    .byte $10, $0b

bra_smb2_main_handle_stomped_shell_enemy:
    LDA #$04  ; set defeated state for enemy
    STA Enemy_State,x
    INC StompChainCounter  ; increment the stomp counter
    LDA StompChainCounter  ; add whatever is in the stomp counter
    CLC  ; to whatever is in the stomp timer
    ADC StompTimer
    JSR sub_smb2_main_setup_floatey_number  ; award points accordingly
    INC StompTimer  ; increment stomp timer of some sort
    LDY PrimaryHardMode  ; check primary hard mode flag
    LDA off_smb2_main_enemy_revival_delays,y  ; load timer setting according to flag
    STA EnemyIntervalTimer,x  ; set as enemy timer to revive stomped enemy
sub_smb2_main_set_bounce:
    LDY #$fa  ; set a regular bounce rate for all other enemies
    LDA Enemy_ID,x
    CMP #RedParatroopa  ; set a higher bounce rate for red paratroopas
    BEQ bra_smb2_main_set_high_enemy_bounce  ; and green paratroopas that fly
    CMP #GreenParatroopaFly
    BNE bra_smb2_main_set_low_enemy_bounce
bra_smb2_main_set_high_enemy_bounce:
    LDY #$f8  ; set player's vertical speed for bounce
bra_smb2_main_set_low_enemy_bounce:
    STY Player_Y_Speed  ; and then leave!!!
    RTS

loc_smb2_main_check_enemy_facing_right:
    LDA Enemy_MovingDir,x  ; check to see if enemy is moving to the right
    CMP #$01
    BNE bra_smb2_main_turn_enemy_then_injure_player  ; if not, branch
    JMP sub_smb2_main_injure_player  ; otherwise go back to hurt player
bra_smb2_main_turn_enemy_then_injure_player:
    JSR sub_smb2_main_enemy_turn_around  ; turn the enemy around, if necessary
    JMP sub_smb2_main_injure_player  ; go back to hurt player

sub_smb2_main_enemy_face_player:
    LDY #$01  ; set to move right by default
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between player and enemy
    BPL bra_smb2_main_store_enemy_facing_direction  ; if enemy is to the right of player, do not increment
    INY  ; otherwise, increment to set to move to the left
bra_smb2_main_store_enemy_facing_direction:
    STY Enemy_MovingDir,x  ; set moving direction here
    DEY  ; then decrement to use as a proper offset
    RTS

sub_smb2_main_setup_floatey_number:
    STA FloateyNum_Control,x  ; set number of points control for floatey numbers
    LDA #$30
    STA FloateyNum_Timer,x  ; set timer for floatey numbers
    LDA Enemy_Y_Position,x
    STA FloateyNum_Y_Pos,x  ; set vertical coordinate
    LDA Enemy_Rel_XPos
    STA FloateyNum_X_Pos,x  ; set horizontal coordinate and leave
bra_smb2_main_exit_floating_score_setup:
    RTS

; -------------------------------------------------------------------------------------
; $01 - used to hold enemy offset for second enemy

tbl_smb2_main_bit_set_masks:
    .byte %10000000, %01000000, %00100000, %00010000, %00001000, %00000100, %00000010

tbl_smb2_main_bit_clear_masks:
    .byte %01111111, %10111111, %11011111, %11101111, %11110111, %11111011, %11111101

sub_smb2_main_enemies_collision:
    LDA FrameCounter  ; check counter for d0 set
    LSR
    BCC bra_smb2_main_exit_floating_score_setup  ; if d0 not set, leave
    LDA AreaType
    BEQ bra_smb2_main_exit_floating_score_setup  ; if water area type, leave
    LDA Enemy_ID,x
    CMP #$15  ; if enemy object => $15, branch to leave
    BCS bra_smb2_main_exit_enemy_collision_scan
    CMP #Lakitu  ; if lakitu, branch to leave
    BEQ bra_smb2_main_exit_enemy_collision_scan
    CMP #PiranhaPlant  ; if piranha plant, branch to leave
    BEQ bra_smb2_main_exit_enemy_collision_scan
    CMP #UpsideDownPiranhaP  ; if upside-down piranha plant, branch to leave
    BEQ bra_smb2_main_exit_enemy_collision_scan
    LDA EnemyOffscrBitsMasked,x  ; if masked offscreen bits nonzero, branch to leave
    BNE bra_smb2_main_exit_enemy_collision_scan
    JSR sub_smb2_main_get_enemy_bounding_box_offset  ; otherwise, do sub, get appropriate bounding box offset for
    DEX  ; first enemy we're going to compare, then decrement for second
    BMI bra_smb2_main_exit_enemy_collision_scan  ; branch to leave if there are no other enemies
bra_smb2_main_check_enemy_collision_pairs_loop:
    STX $01  ; save enemy object buffer offset for second enemy here
    TYA  ; save first enemy's bounding box offset to stack
    PHA
    LDA Enemy_Flag,x  ; check enemy object enable flag
    BEQ bra_smb2_main_advance_enemy_collision_pair  ; branch if flag not set
    LDA Enemy_ID,x
    CMP #$15  ; check for enemy object => $15
    BCS bra_smb2_main_advance_enemy_collision_pair  ; branch if true
    CMP #Lakitu
    BEQ bra_smb2_main_advance_enemy_collision_pair  ; branch if enemy object is lakitu
    CMP #PiranhaPlant
    BEQ bra_smb2_main_advance_enemy_collision_pair  ; branch if enemy object is piranha plant
    CMP #UpsideDownPiranhaP
    BEQ bra_smb2_main_advance_enemy_collision_pair  ; branch if enemy object is upside-down piranha plant
    LDA EnemyOffscrBitsMasked,x
    BNE bra_smb2_main_advance_enemy_collision_pair  ; branch if masked offscreen bits set
    TXA  ; get second enemy object's bounding box offset
    ASL  ; multiply by four, then add four
    ASL
    CLC
    ADC #$04
    TAX  ; use as new contents of X
    JSR sub_smb2_main_sprite_object_collision_core  ; do collision detection using the two enemies here
    LDX ObjectOffset  ; use first enemy offset for X
    LDY $01  ; use second enemy offset for Y
    BCC bra_smb2_main_clear_enemy_collision_pair  ; if carry clear, no collision, branch ahead of this
    LDA Enemy_State,x
    ORA Enemy_State,y  ; check both enemy states for d7 set
    AND #%10000000
    BNE bra_smb2_main_record_enemy_collision_pair  ; branch if at least one of them is set
    LDA Enemy_CollisionBits,y  ; load first enemy's collision-related bits
    AND tbl_smb2_main_bit_set_masks,x  ; check to see if bit connected to second enemy is
    BNE bra_smb2_main_advance_enemy_collision_pair  ; already set, and move onto next enemy slot if set
    LDA Enemy_CollisionBits,y
    ORA tbl_smb2_main_bit_set_masks,x  ; if the bit is not set, set it now
    STA Enemy_CollisionBits,y
bra_smb2_main_record_enemy_collision_pair:
    JSR sub_smb2_main_process_enemy_collision  ; react according to the nature of collision
    JMP bra_smb2_main_advance_enemy_collision_pair  ; move onto next enemy slot

bra_smb2_main_clear_enemy_collision_pair:
    LDA Enemy_CollisionBits,y  ; load first enemy's collision-related bits
    AND tbl_smb2_main_bit_clear_masks,x  ; clear bit connected to second enemy
    STA Enemy_CollisionBits,y  ; then move onto next enemy slot

bra_smb2_main_advance_enemy_collision_pair:
    PLA  ; get first enemy's bounding box offset from the stack
    TAY  ; use as Y again
    LDX $01  ; get and decrement second enemy's object buffer offset
    DEX
    BPL bra_smb2_main_check_enemy_collision_pairs_loop  ; loop until all enemy slots have been checked

bra_smb2_main_exit_enemy_collision_scan:
    LDX ObjectOffset  ; get enemy object buffer offset
    RTS  ; leave

sub_smb2_main_process_enemy_collision:
    LDA Enemy_State,y  ; check both enemy states for d5 set
    ORA Enemy_State,x
    AND #%00100000  ; if d5 is set in either state, or both, branch
    BNE bra_smb2_main_exit_enemy_collision_processing  ; to leave and do nothing else at this point
    LDA Enemy_State,x
    CMP #$06  ; if second enemy state < $06, branch elsewhere
    BCC bra_smb2_main_process_second_enemy_collision
    LDA Enemy_ID,x  ; check second enemy identifier for hammer bro
    CMP #HammerBro  ; if hammer bro found in alt state, branch to leave
    BEQ bra_smb2_main_exit_enemy_collision_processing
    LDA Enemy_State,y  ; check first enemy state for d7 set
    ASL
    BCC bra_smb2_main_resolve_shell_enemy_collision  ; branch if d7 is clear
    LDA #$06
    JSR sub_smb2_main_setup_floatey_number  ; award 1000 points for killing enemy
    JSR sub_smb2_main_shell_or_block_defeat  ; then kill enemy, then load
    LDY $01  ; original offset of second enemy

bra_smb2_main_resolve_shell_enemy_collision:
    TYA  ; move Y to X
    TAX
    JSR sub_smb2_main_shell_or_block_defeat  ; kill second enemy
    LDX ObjectOffset
    LDA ShellChainCounter,x  ; get chain counter for shell
    CLC
    ADC #$04  ; add four to get appropriate point offset
    LDX $01
    JSR sub_smb2_main_setup_floatey_number  ; award appropriate number of points for second enemy
    LDX ObjectOffset  ; load original offset of first enemy
    INC ShellChainCounter,x  ; increment chain counter for additional enemies

bra_smb2_main_exit_enemy_collision_processing:
    RTS  ; leave!!!

bra_smb2_main_process_second_enemy_collision:
    LDA Enemy_State,y  ; if first enemy state < $06, branch elsewhere
    CMP #$06
    BCC bra_smb2_main_select_second_enemy_offset
    LDA Enemy_ID,y  ; check first enemy identifier for hammer bro
    CMP #HammerBro  ; if hammer bro found in alt state, branch to leave
    BEQ bra_smb2_main_exit_enemy_collision_processing
    JSR sub_smb2_main_shell_or_block_defeat  ; otherwise, kill first enemy
    LDY $01
    LDA ShellChainCounter,y  ; get chain counter for shell
    CLC
    ADC #$04  ; add four to get appropriate point offset
    LDX ObjectOffset
    JSR sub_smb2_main_setup_floatey_number  ; award appropriate number of points for first enemy
    LDX $01  ; load original offset of second enemy
    INC ShellChainCounter,x  ; increment chain counter for additional enemies
    RTS  ; leave!!!

bra_smb2_main_select_second_enemy_offset:
    TYA  ; move Y ($01) to X
    TAX
    JSR sub_smb2_main_enemy_turn_around  ; do the sub here using value from $01
    LDX ObjectOffset  ; then do it again using value from $08

sub_smb2_main_enemy_turn_around:
    LDA Enemy_ID,x  ; check for specific enemies
    CMP #PiranhaPlant
    BEQ bra_smb2_main_exit_enemy_turn_around  ; if piranha plant, leave
    CMP #UpsideDownPiranhaP
    BEQ bra_smb2_main_exit_enemy_turn_around  ; if upside-down piranha plant, leave
    CMP #Lakitu
    BEQ bra_smb2_main_exit_enemy_turn_around  ; if lakitu, leave
    CMP #HammerBro
    BEQ bra_smb2_main_exit_enemy_turn_around  ; if hammer bro, leave
    CMP #Spiny
    BEQ bra_smb2_main_reverse_enemy_x_speed  ; if spiny, turn it around
    CMP #GreenParatroopaJump
    BEQ bra_smb2_main_reverse_enemy_x_speed  ; if green paratroopa, turn it around
    CMP #$07
    BCS bra_smb2_main_exit_enemy_turn_around  ; if any OTHER enemy object => $07, leave
bra_smb2_main_reverse_enemy_x_speed:
    LDA Enemy_X_Speed,x  ; load horizontal speed
    EOR #$ff  ; get two's compliment for horizontal speed
    TAY
    INY
    STY Enemy_X_Speed,x  ; store as new horizontal speed
    LDA Enemy_MovingDir,x
    EOR #%00000011  ; invert moving direction and store, then leave
    STA Enemy_MovingDir,x  ; thus effectively turning the enemy around
bra_smb2_main_exit_enemy_turn_around:
    RTS  ; leave!!!

; -------------------------------------------------------------------------------------
; $00 - vertical position of platform

sub_smb2_main_large_platform_collision:
    LDA #$ff  ; save value here
    STA PlatformCollisionFlag,x
    LDA TimerControl  ; check master timer control
    BNE bra_smb2_main_exit_large_platform_collision  ; if set, branch to leave
    LDA Enemy_State,x  ; if d7 set in object state,
    BMI bra_smb2_main_exit_large_platform_collision  ; branch to leave
    LDA Enemy_ID,x
    CMP #$24  ; check enemy object identifier for
    BNE sub_smb2_main_check_player_large_platform_collision  ; balance platform, branch if not found
    LDA Enemy_State,x
    TAX  ; set state as enemy offset here
    JSR sub_smb2_main_check_player_large_platform_collision  ; perform code with state offset, then original offset, in X

sub_smb2_main_check_player_large_platform_collision:
    JSR sub_smb2_main_check_player_vertical  ; figure out if player is below a certain point
    BCS bra_smb2_main_exit_large_platform_collision  ; or offscreen, branch to leave if true
    TXA
    JSR sub_smb2_main_get_enemy_bounding_box_offset_from_x  ; get bounding box offset in Y
    LDA Enemy_Y_Position,x  ; store vertical coordinate in
    STA $00  ; temp variable for now
    TXA  ; send offset we're on to the stack
    PHA
    JSR sub_smb2_main_player_collision_core  ; do player-to-platform collision detection
    PLA  ; retrieve offset from the stack
    TAX
    BCC bra_smb2_main_exit_large_platform_collision  ; if no collision, branch to leave
    JSR sub_smb2_main_process_large_platform_collision  ; otherwise collision, perform sub
bra_smb2_main_exit_large_platform_collision:
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------
; $00 - counter for bounding boxes

sub_smb2_main_small_platform_collision:
    LDA TimerControl  ; if master timer control set,
    BNE bra_smb2_main_exit_small_platform_collision  ; branch to leave
    STA PlatformCollisionFlag,x  ; otherwise initialize collision flag
    JSR sub_smb2_main_check_player_vertical  ; do a sub to see if player is below a certain point
    BCS bra_smb2_main_exit_small_platform_collision  ; or entirely offscreen, and branch to leave if true
    LDA #$02
    STA $00  ; load counter here for 2 bounding boxes

bra_smb2_main_check_next_small_platform:
    LDX ObjectOffset  ; get enemy object offset
    JSR sub_smb2_main_get_enemy_bounding_box_offset  ; get bounding box offset in Y
    AND #%00000010  ; if d1 of offscreen lower nybble bits was set
    BNE bra_smb2_main_exit_small_platform_collision  ; then branch to leave
    LDA BoundingBox_UL_YPos,y  ; check top of platform's bounding box for being
    CMP #$20  ; above a specific point
    BCC bra_smb2_main_shift_platform_bounding_box  ; if so, branch, don't do collision detection
    JSR sub_smb2_main_player_collision_core  ; otherwise, perform player-to-platform collision detection
    BCS bra_smb2_main_process_small_platform_collisions  ; skip ahead if collision

bra_smb2_main_shift_platform_bounding_box:
    LDA BoundingBox_UL_YPos,y  ; move bounding box vertical coordinates
    CLC  ; 128 pixels downwards
    ADC #$80
    STA BoundingBox_UL_YPos,y
    LDA BoundingBox_DR_YPos,y
    CLC
    ADC #$80
    STA BoundingBox_DR_YPos,y
    DEC $00  ; decrement counter we set earlier
    BNE bra_smb2_main_check_next_small_platform  ; loop back until both bounding boxes are checked
bra_smb2_main_exit_small_platform_collision:
    LDX ObjectOffset  ; get enemy object buffer offset, then leave
    RTS

; --------------------------------
