off_smb2_main_bowser_flame_delays:
    .byte $bf, $40, $bf, $bf, $bf, $40, $40, $bf

sub_smb2_main_set_flame_timer:
    LDY BowserFlameTimerCtrl  ; load counter as offset
    INC BowserFlameTimerCtrl  ; increment
    LDA BowserFlameTimerCtrl  ; mask out all but 3 LSB
    AND #%00000111  ; to keep in range of 0-7
    STA BowserFlameTimerCtrl
    LDA off_smb2_main_bowser_flame_delays,y  ; load value to be used then leave
bra_smb2_main_exit_bowser_flame_handler:
    RTS

sub_smb2_main_process_bowser_flame:
    LDA TimerControl  ; if master timer control flag set,
    BNE bra_smb2_main_draw_bowser_flame  ; skip all of this
    LDA #$40  ; load default movement force
    LDY SecondaryHardMode
    BEQ bra_smb2_main_apply_bowser_flame_speed  ; if secondary hard mode flag not set, use default
    LDA #$60  ; otherwise load alternate movement force to go faster
bra_smb2_main_apply_bowser_flame_speed:
    STA $00  ; store value here
    LDA Enemy_X_MoveForce,x
    SEC  ; subtract value from movement force
    SBC $00
    STA Enemy_X_MoveForce,x  ; save new value
    LDA Enemy_X_Position,x
    SBC #$01  ; subtract one from horizontal position to move
    STA Enemy_X_Position,x  ; to the left
    LDA Enemy_PageLoc,x
    SBC #$00  ; subtract borrow from page location
    STA Enemy_PageLoc,x
    LDY BowserFlamePRandomOfs,x  ; get some value here and use as offset
    LDA Enemy_Y_Position,x  ; load vertical coordinate
    CMP off_smb2_main_bowser_flame_target_y_positions,y  ; compare against coordinate data using $0417,x as offset
    BEQ bra_smb2_main_draw_bowser_flame  ; if equal, branch and do not modify coordinate
    CLC
    ADC Enemy_Y_MoveForce,x  ; otherwise add value here to coordinate and store
    STA Enemy_Y_Position,x  ; as new vertical coordinate
bra_smb2_main_draw_bowser_flame:
    JSR sub_smb2_main_relative_enemy_position  ; get new relative coordinates
    LDA Enemy_State,x  ; if bowser's flame not in normal state,
    BNE bra_smb2_main_exit_bowser_flame_handler  ; branch to leave
    LDA #$51  ; otherwise, continue
    STA $00  ; write first tile number
    LDY #$02  ; load attributes without vertical flip by default
    LDA FrameCounter
    AND #%00000010  ; invert vertical flip bit every 2 frames
    BEQ bra_smb2_main_store_bowser_flame_attributes  ; if d1 not set, write default value
    LDY #$82  ; otherwise write value with vertical flip bit set
bra_smb2_main_store_bowser_flame_attributes:
    STY $01  ; set bowser's flame sprite attributes here
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDX #$00

bra_smb2_main_draw_bowser_flame_loop:
    LDA Enemy_Rel_YPos  ; get Y relative coordinate of current enemy object
    STA Sprite_Y_Position,y  ; write into Y coordinate of OAM data
    LDA $00
    STA Sprite_Tilenumber,y  ; write current tile number into OAM data
    INC $00  ; increment tile number to draw more bowser's flame
    LDA $01
    STA Sprite_Attributes,y  ; write saved attributes into OAM data
    LDA Enemy_Rel_XPos
    STA Sprite_X_Position,y  ; write X relative coordinate of current enemy object
    CLC
    ADC #$08
    STA Enemy_Rel_XPos  ; then add eight to it and store
    INY
    INY
    INY
    INY  ; increment Y four times to move onto the next OAM
    INX  ; move onto the next OAM, and branch if three
    CPX #$03  ; have not yet been done
    BCC bra_smb2_main_draw_bowser_flame_loop
    LDX ObjectOffset  ; reload original enemy offset
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; get offscreen information
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA Enemy_OffscreenBits  ; get enemy object offscreen bits
    LSR  ; move d0 to carry and result to stack
    PHA
    BCC bra_smb2_main_check_bowser_flame_third_sprite  ; branch if carry not set
    LDA #$f8  ; otherwise move sprite offscreen, this part likely
    STA Sprite_Y_Position+12,y  ; residual since flame is only made of three sprites
bra_smb2_main_check_bowser_flame_third_sprite:
    PLA  ; get bits from stack
    LSR  ; move d1 to carry and move bits back to stack
    PHA
    BCC bra_smb2_main_check_bowser_flame_second_sprite  ; branch if carry not set again
    LDA #$f8  ; otherwise move third sprite offscreen
    STA Sprite_Y_Position+8,y
bra_smb2_main_check_bowser_flame_second_sprite:
    PLA  ; get bits from stack again
    LSR  ; move d2 to carry and move bits back to stack again
    PHA
    BCC bra_smb2_main_check_bowser_flame_first_sprite  ; branch if carry not set yet again
    LDA #$f8  ; otherwise move second sprite offscreen
    STA Sprite_Y_Position+4,y
bra_smb2_main_check_bowser_flame_first_sprite:
    PLA  ; get bits from stack one last time
    LSR  ; move d3 to carry
    BCC bra_smb2_main_exit_bowser_flame_draw  ; branch if carry not set one last time
    LDA #$f8
    STA Sprite_Y_Position,y  ; otherwise move first sprite offscreen
bra_smb2_main_exit_bowser_flame_draw:
    RTS  ; leave

; --------------------------------

handler_smb2_main_run_fireworks:
    DEC ExplosionTimerCounter,x  ; decrement explosion timing counter here
    BNE bra_smb2_main_draw_fireworks_explosion  ; if not expired, skip this part
    LDA #$08
    STA ExplosionTimerCounter,x  ; reset counter
    INC ExplosionGfxCounter,x  ; increment explosion graphics counter
    LDA ExplosionGfxCounter,x
    CMP #$03  ; check explosion graphics counter
    BCS bra_smb2_main_finish_fireworks_explosion  ; if at a certain point, branch to kill this object
bra_smb2_main_draw_fireworks_explosion:
    JSR sub_smb2_main_relative_enemy_position  ; get relative coordinates of explosion
    LDA Enemy_Rel_YPos  ; copy relative coordinates
    STA Fireball_Rel_YPos  ; from the enemy object to the fireball object
    LDA Enemy_Rel_XPos  ; first vertical, then horizontal
    STA Fireball_Rel_XPos
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA ExplosionGfxCounter,x  ; get explosion graphics counter
    JSR sub_smb2_main_draw_explosion_fireworks  ; do a sub to draw the explosion then leave
    RTS

bra_smb2_main_finish_fireworks_explosion:
    LDA #$00  ; disable enemy buffer flag
    STA Enemy_Flag,x
    LDA #Sfx_Blast  ; play fireworks/gunfire sound
    STA Square2SoundQueue
    LDA #$05  ; set part of score modifier for 500 points
    STA DigitModifier+4
    JMP loc_smb2_main_award_end_area_points  ; jump to award points accordingly then leave

; --------------------------------

tbl_smb2_main_star_flag_sprite_y_offsets:
    .byte $00, $00, $08, $08

tbl_smb2_main_star_flag_sprite_x_offsets:
    .byte $00, $08, $00, $08

off_smb2_main_star_flag_sprite_tiles:
    .byte $54, $55, $56, $57

handler_smb2_main_run_star_flag:
    LDA #$00  ; initialize enemy frenzy buffer
    STA EnemyFrenzyBuffer
    LDA StarFlagTaskControl  ; check star flag object task number here
    CMP #$05  ; if greater than 5, branch to exit
    BCS bra_smb2_main_exit_star_flag
    JSR sub_smb2_main_dispatch_inline_handler  ; otherwise jump to appropriate sub

    .word bra_smb2_main_exit_star_flag
    .word handler_smb2_main_set_fireworks_count
    .word handler_smb2_main_award_game_timer_points
    .word handler_smb2_main_raise_star_flag_and_launch_fireworks
    .word handler_smb2_main_wait_for_area_end_music

handler_smb2_main_set_fireworks_count:
    LDA GameTimerDisplay+2  ; check to see if last digit of timer matches
    CMP CoinDisplay+1  ; the last digit in the coin tally
    BNE bra_smb2_main_skip_fireworks  ; if not, skip the fireworks
    AND #$01
    BEQ bra_smb2_main_write_even_score_digits  ; if so, check to see if they are both odd or even
    LDY #$03
    LDA #$03  ; if they are both odd, set state and counter
    BNE bra_smb2_main_store_fireworks_count  ; for 3 fireworks to go off
bra_smb2_main_write_even_score_digits:
    LDY #$00  ; if they are both even, set state and counter
    LDA #$06  ; for 6 fireworks to go off
    BNE bra_smb2_main_store_fireworks_count
bra_smb2_main_skip_fireworks:
    LDY #$00
    LDA #$ff  ; otherwise set value for no fireworks
bra_smb2_main_store_fireworks_count:
    STA FireworksCounter  ; set fireworks counter here
    STY Enemy_State,x  ; set whatever state we have in star flag object

bra_smb2_main_advance_star_flag_task_after_count:
    INC StarFlagTaskControl  ; increment star flag object task number

bra_smb2_main_exit_star_flag:
    RTS  ; leave

handler_smb2_main_award_game_timer_points:
    LDA GameTimerDisplay  ; check all game timer digits for any intervals left
    ORA GameTimerDisplay+1
    ORA GameTimerDisplay+2
    BEQ bra_smb2_main_advance_star_flag_task_after_count  ; if no time left on game timer at all, branch to next task
sub_smb2_main_award_timer_castle:
    LDA FrameCounter
    AND #%00000100  ; check frame counter for d2 set (skip ahead
    BEQ bra_smb2_main_skip_game_timer_tick_sound  ; for four frames every four frames) branch if not set
    LDA #Sfx_TimerTick
    STA Square2SoundQueue  ; load timer tick sound
bra_smb2_main_skip_game_timer_tick_sound:
    LDY #$17  ; set offset here to subtract from game timer's last digit
    LDA #$ff  ; set adder here to $ff, or -1, to subtract one
    STA DigitModifier+5  ; from the last digit of the game timer
    JSR sub_smb2_main_digits_math_routine  ; subtract digit
    LDA #$05  ; set now to add 50 points
    STA DigitModifier+5  ; per game timer interval subtracted

loc_smb2_main_award_end_area_points:
    LDY #$0b  ; load offset for score, then jump to handle the awarding
    JSR sub_smb2_main_digits_math_routine
    LDA #$02  ; now update the score on the screen
    JMP sub_smb2_main_write_digits

handler_smb2_main_raise_star_flag_and_launch_fireworks:
    LDA Enemy_Y_Position,x  ; check star flag's vertical position
    CMP #$72  ; against preset value
    BCC bra_smb2_main_queue_next_fireworks_explosion  ; if star flag higher vertically, branch to other code
    DEC Enemy_Y_Position,x  ; otherwise, raise star flag by one pixel
    JMP sub_smb2_main_draw_star_flag  ; and skip this part here
bra_smb2_main_queue_next_fireworks_explosion:
    LDA FireworksCounter  ; check fireworks counter
    BEQ bra_smb2_main_draw_star_flag_and_set_delay  ; if no fireworks left to go off, skip this part
    BMI bra_smb2_main_draw_star_flag_and_set_delay  ; if no fireworks set to go off, skip this part
    LDA #Fireworks
    STA EnemyFrenzyBuffer  ; otherwise set fireworks object in frenzy queue

sub_smb2_main_draw_star_flag:
    JSR sub_smb2_main_relative_enemy_position  ; get relative coordinates of star flag
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDX #$03  ; do four sprites
bra_smb2_main_draw_star_flag_sprite_loop:
    LDA Enemy_Rel_YPos  ; get relative vertical coordinate
    CLC
    ADC tbl_smb2_main_star_flag_sprite_y_offsets,x  ; add Y coordinate adder data
    STA Sprite_Y_Position,y  ; store as Y coordinate
    LDA off_smb2_main_star_flag_sprite_tiles,x  ; get tile number
    STA Sprite_Tilenumber,y  ; store as tile number
    LDA #$22  ; set palette and background priority bits
    STA Sprite_Attributes,y  ; store as attributes
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    CLC
    ADC tbl_smb2_main_star_flag_sprite_x_offsets,x  ; add X coordinate adder data
    STA Sprite_X_Position,y  ; store as X coordinate
    INY
    INY  ; increment OAM data offset four bytes
    INY  ; for next sprite
    INY
    DEX  ; move onto next sprite
    BPL bra_smb2_main_draw_star_flag_sprite_loop  ; do this until all sprites are done
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

bra_smb2_main_draw_star_flag_and_set_delay:
    JSR sub_smb2_main_draw_star_flag  ; do sub to draw star flag
    LDA #$06
    STA EnemyIntervalTimer,x  ; set interval timer here

bra_smb2_main_advance_star_flag_task_after_delay:
    INC StarFlagTaskControl  ; move onto next task
    RTS

handler_smb2_main_wait_for_area_end_music:
    JSR sub_smb2_main_draw_star_flag  ; do sub to draw star flag
    LDA EnemyIntervalTimer,x  ; if interval timer set in previous task
    BNE bra_smb2_main_exit_star_flag_delay  ; not yet expired, branch to leave
    LDA EventMusicBuffer  ; if event music buffer empty,
    BEQ bra_smb2_main_advance_star_flag_task_after_delay  ; branch to increment task

bra_smb2_main_exit_star_flag_delay:
    RTS  ; otherwise leave

; --------------------------------
; $00 - used to store horizontal difference between player and piranha plant

handler_smb2_main_move_piranha_plant:
    LDA Enemy_State,x  ; check enemy state
    BNE bra_smb2_main_finish_piranha_plant_update  ; if set at all, branch to leave
    LDA EnemyFrameTimer,x  ; check enemy's timer here
    BNE bra_smb2_main_finish_piranha_plant_update  ; branch to end if not yet expired
    LDA PiranhaPlant_MoveFlag,x  ; check movement flag
    BNE bra_smb2_main_select_piranha_plant_limit  ; if moving, skip to part ahead
    LDA PiranhaPlant_Y_Speed,x  ; if currently rising, branch
    BMI bra_smb2_main_reverse_piranha_plant_speed  ; to move enemy upwards out of pipe
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between player and
    BPL bra_smb2_main_check_player_near_piranha_pipe  ; piranha plant, and branch if enemy to right of player
    LDA $00  ; otherwise get saved horizontal difference
    EOR #$ff
    CLC  ; and change to two's compliment
    ADC #$01
    STA $00  ; save as new horizontal difference

bra_smb2_main_check_player_near_piranha_pipe:
    LDA $00  ; get saved horizontal difference
    CMP #$21
    BCC bra_smb2_main_finish_piranha_plant_update  ; if player within a certain distance, branch to leave

bra_smb2_main_reverse_piranha_plant_speed:
    LDA PiranhaPlant_Y_Speed,x  ; get vertical speed
    EOR #$ff
    CLC  ; change to two's compliment
    ADC #$01
    STA PiranhaPlant_Y_Speed,x  ; save as new vertical speed
    INC PiranhaPlant_MoveFlag,x  ; increment to set movement flag

bra_smb2_main_select_piranha_plant_limit:
    LDA PiranhaPlantDownYPos,x  ; get original vertical coordinate (lowest point)
    LDY PiranhaPlant_Y_Speed,x  ; get vertical speed
    BPL bra_smb2_main_move_piranha_plant  ; branch if moving downwards
    LDA PiranhaPlantUpYPos,x  ; otherwise get other vertical coordinate (highest point)

bra_smb2_main_move_piranha_plant:
    STA $00  ; save vertical coordinate here
    LDA off_smb2_main_enemy_sprite_attributes+PiranhaPlant
    CMP #$22  ; check for red piranha plants
    BEQ bra_smb2_main_use_red_piranha_plant  ; if found, skip to next part to execute code on every frame
    LDA FrameCounter  ; get frame counter
    LSR
    BCC bra_smb2_main_finish_piranha_plant_update  ; branch to leave if d0 set (execute code every other frame)
bra_smb2_main_use_red_piranha_plant:
    LDA TimerControl  ; get master timer control
    BNE bra_smb2_main_finish_piranha_plant_update  ; branch to leave if set (likely not necessary)
    LDA Enemy_Y_Position,x  ; get current vertical coordinate
    CLC
    ADC PiranhaPlant_Y_Speed,x  ; add vertical speed to move up or down
    STA Enemy_Y_Position,x  ; save as new vertical coordinate
    CMP $00  ; compare against low or high coordinate
    BNE bra_smb2_main_finish_piranha_plant_update  ; branch to leave if not yet reached
    LDA #$00
    STA PiranhaPlant_MoveFlag,x  ; otherwise clear movement flag
    LDA #$40
    STA EnemyFrameTimer,x  ; set timer to delay piranha plant movement

bra_smb2_main_finish_piranha_plant_update:
    LDA #%00100000  ; set background priority bit in sprite
    STA Enemy_SprAttrib,x  ; attributes to give illusion of being inside pipe
    RTS  ; then leave

; -------------------------------------------------------------------------------------
; $07 - spinning speed

sub_smb2_main_firebar_spin:
    STA $07  ; save spinning speed here
    LDA FirebarSpinDirection,x  ; check spinning direction
    BNE bra_smb2_main_spin_firebar_counterclockwise  ; if moving counter-clockwise, branch to other part
    LDY #$18  ; possibly residual ldy
    LDA FirebarSpinState_Low,x
    CLC  ; add spinning speed to what would normally be
    ADC $07  ; the horizontal speed
    STA FirebarSpinState_Low,x
    LDA FirebarSpinState_High,x  ; add carry to what would normally be the vertical speed
    ADC #$00
    RTS

bra_smb2_main_spin_firebar_counterclockwise:
    LDY #$08  ; possibly residual ldy
    LDA FirebarSpinState_Low,x
    SEC  ; subtract spinning speed to what would normally be
    SBC $07  ; the horizontal speed
    STA FirebarSpinState_Low,x
    LDA FirebarSpinState_High,x  ; add carry to what would normally be the vertical speed
    SBC #$00
    RTS

; -------------------------------------------------------------------------------------
; $00 - used to hold collision flag, Y movement force + 5 or low byte of name table for rope
; $01 - used to hold high byte of name table for rope
; $02 - used to hold page location of rope

handler_smb2_main_move_balance_platform:
    LDA Enemy_Y_HighPos,x  ; check high byte of vertical position
    CMP #$03
    BNE bra_smb2_main_check_balance_platform_state
    JMP sub_smb2_main_erase_enemy_object  ; if far below screen, kill the object
bra_smb2_main_check_balance_platform_state:
    LDA Enemy_State,x  ; get object's state (set to $ff or other platform offset)
    BPL bra_smb2_main_update_balance_platform_pair  ; if doing other balance platform, branch to handle it
bra_smb2_main_exit_balance_platform:
    RTS

bra_smb2_main_update_balance_platform_pair:
    TAY  ; save offset from state as Y
    LDA Enemy_ID,y
    CMP #$24  ; check to see if other object is balance platform
    BNE bra_smb2_main_exit_balance_platform  ; if not, branch to leave
    LDA PlatformCollisionFlag,x  ; get collision flag of platform
    STA $00  ; store here
    LDA Enemy_MovingDir,x  ; get moving direction
    BEQ bra_smb2_main_check_current_balance_platform_fall
    JMP loc_smb2_main_fall_balance_platform_pair  ; if set, jump here

bra_smb2_main_check_current_balance_platform_fall:
    LDA #$2d  ; check if platform is above a certain point
    CMP Enemy_Y_Position,x
    BCC bra_smb2_main_check_other_balance_platform_fall  ; if not, branch elsewhere
    CPY $00  ; if collision flag is set to same value as
    BEQ bra_smb2_main_begin_balance_platform_fall  ; enemy state, branch to make platforms fall
    CLC
    ADC #$02  ; otherwise add 2 pixels to vertical position
    STA Enemy_Y_Position,x  ; of current platform and branch elsewhere
    JMP sub_smb2_main_stop_platforms  ; to make platforms stop

bra_smb2_main_begin_balance_platform_fall:
    JMP loc_smb2_main_initialize_balance_platform_fall  ; make platforms fall

bra_smb2_main_check_other_balance_platform_fall:
    CMP Enemy_Y_Position,y  ; check if other platform is above a certain point
    BCC bra_smb2_main_move_balance_platform_pair  ; if not, branch elsewhere
    CPX $00  ; if collision flag is set to same value as
    BEQ bra_smb2_main_begin_balance_platform_fall  ; enemy state, branch to make platforms fall
    CLC
    ADC #$02  ; otherwise add 2 pixels to vertical position
    STA Enemy_Y_Position,y  ; of other platform and branch elsewhere
    JMP sub_smb2_main_stop_platforms  ; jump to stop movement and do not return

bra_smb2_main_move_balance_platform_pair:
    LDA Enemy_Y_Position,x  ; save vertical position to stack
    PHA
    LDA PlatformCollisionFlag,x  ; get collision flag
    BPL bra_smb2_main_handle_balance_platform_collision  ; branch if collision
    LDA Enemy_Y_MoveForce,x
    CLC  ; add $05 to contents of moveforce, whatever they be
    ADC #$05
    STA $00  ; store here
    LDA Enemy_Y_Speed,x
    ADC #$00  ; add carry to vertical speed
    BMI bra_smb2_main_move_balance_platform_down  ; branch if moving downwards
    BNE bra_smb2_main_move_balance_platform_up  ; branch elsewhere if moving upwards
    LDA $00
    CMP #$0b  ; check if there's still a little force left
    BCC bra_smb2_main_stop_balance_platforms  ; if not enough, branch to stop movement
    BCS bra_smb2_main_move_balance_platform_up  ; otherwise keep branch to move upwards
bra_smb2_main_handle_balance_platform_collision:
    CMP ObjectOffset  ; if collision flag matches
    BEQ bra_smb2_main_move_balance_platform_down  ; current enemy object offset, branch
bra_smb2_main_move_balance_platform_up:
    JSR sub_smb2_main_move_platform_up  ; do a sub to move upwards
    JMP loc_smb2_main_move_other_balance_platform  ; jump ahead to remaining code
bra_smb2_main_stop_balance_platforms:
    JSR sub_smb2_main_stop_platforms  ; do a sub to stop movement
    JMP loc_smb2_main_move_other_balance_platform  ; jump ahead to remaining code
bra_smb2_main_move_balance_platform_down:
    JSR sub_smb2_main_move_platform_down  ; do a sub to move downwards

loc_smb2_main_move_other_balance_platform:
    LDY Enemy_State,x  ; get offset of other platform
    PLA  ; get old vertical coordinate from stack
    SEC
    SBC Enemy_Y_Position,x  ; get difference of old vs. new coordinate
    CLC
    ADC Enemy_Y_Position,y  ; add difference to vertical coordinate of other
    STA Enemy_Y_Position,y  ; platform to move it in the opposite direction
    LDA PlatformCollisionFlag,x  ; if no collision, skip this part here
    BMI bra_smb2_main_update_balance_platform_rope
    TAX  ; put offset which collision occurred here
    JSR sub_smb2_main_position_player_on_vertical_platform  ; and use it to position player accordingly

bra_smb2_main_update_balance_platform_rope:
    LDY ObjectOffset  ; get enemy object offset
    LDA Enemy_Y_Speed,y  ; check to see if current platform is
    ORA Enemy_Y_MoveForce,y  ; moving at all
    BEQ bra_smb2_main_exit_platform_rope_update  ; if not, skip all of this and branch to leave
    LDX VRAM_Buffer1_Offset  ; get vram buffer offset
    CPX #$20  ; if offset beyond a certain point, go ahead
    BCS bra_smb2_main_exit_platform_rope_update  ; and skip this, branch to leave
    LDA Enemy_Y_Speed,y
    PHA  ; save two copies of vertical speed to stack
    PHA
    JSR sub_smb2_main_setup_platform_rope  ; do a sub to figure out where to put new bg tiles
    LDA $01  ; write name table address to vram buffer
    STA VRAM_Buffer1,x  ; first the high byte, then the low
    LDA $00
    STA VRAM_Buffer1+1,x
    LDA #$02  ; set length for 2 bytes
    STA VRAM_Buffer1+2,x
    LDA Enemy_Y_Speed,y  ; if platform moving upwards, branch
    BMI bra_smb2_main_erase_current_platform_rope  ; to do something else
    LDA #$a2
    STA VRAM_Buffer1+3,x  ; otherwise put tile numbers for left
    LDA #$a3  ; and right sides of rope in vram buffer
    STA VRAM_Buffer1+4,x
    JMP loc_smb2_main_update_other_platform_rope  ; jump to skip this part
bra_smb2_main_erase_current_platform_rope:
    LDA #$24  ; put blank tiles in vram buffer
    STA VRAM_Buffer1+3,x  ; to erase rope
    STA VRAM_Buffer1+4,x

loc_smb2_main_update_other_platform_rope:
    LDA Enemy_State,y  ; get offset of other platform from state
    TAY  ; use as Y here
    PLA  ; pull second copy of vertical speed from stack
    EOR #$ff  ; invert bits to reverse speed
    JSR sub_smb2_main_setup_platform_rope  ; do sub again to figure out where to put bg tiles
    LDA $01  ; write name table address to vram buffer
    STA VRAM_Buffer1+5,x  ; this time we're doing putting tiles for
    LDA $00  ; the other platform
    STA VRAM_Buffer1+6,x
    LDA #$02
    STA VRAM_Buffer1+7,x  ; set length again for 2 bytes
    PLA  ; pull first copy of vertical speed from stack
    BPL bra_smb2_main_erase_other_platform_rope  ; if moving upwards (note inversion earlier), skip this
    LDA #$a2
    STA VRAM_Buffer1+8,x  ; otherwise put tile numbers for left
    LDA #$a3  ; and right sides of rope in vram
    STA VRAM_Buffer1+9,x  ; transfer buffer
    JMP loc_smb2_main_finish_platform_rope_packet  ; jump to skip this part
bra_smb2_main_erase_other_platform_rope:
    LDA #$24  ; put blank tiles in vram buffer
    STA VRAM_Buffer1+8,x  ; to erase rope
    STA VRAM_Buffer1+9,x
loc_smb2_main_finish_platform_rope_packet:
    LDA #$00  ; put null terminator at the end
    STA VRAM_Buffer1+10,x
    LDA VRAM_Buffer1_Offset  ; add ten bytes to the vram buffer offset
    CLC  ; and store
    ADC #10
    STA VRAM_Buffer1_Offset
bra_smb2_main_exit_platform_rope_update:
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

sub_smb2_main_setup_platform_rope:
    PHA  ; save second/third copy to stack
    LDA Enemy_X_Position,y  ; get horizontal coordinate
    CLC
    ADC #$08  ; add eight pixels
    LDX SecondaryHardMode  ; if secondary hard mode flag set,
    BNE bra_smb2_main_use_platform_rope_x_position  ; use coordinate as-is
    CLC
    ADC #$10  ; otherwise add sixteen more pixels
bra_smb2_main_use_platform_rope_x_position:
    PHA  ; save modified horizontal coordinate to stack
    LDA Enemy_PageLoc,y
    ADC #$00  ; add carry to page location
    STA $02  ; and save here
    PLA  ; pull modified horizontal coordinate
    AND #%11110000  ; from the stack, mask out low nybble
    LSR  ; and shift three bits to the right
    LSR
    LSR
    STA $00  ; store result here as part of name table low byte
    LDX Enemy_Y_Position,y  ; get vertical coordinate
    PLA  ; get second/third copy of vertical speed from stack
    BPL bra_smb2_main_calculate_platform_rope_vram_address  ; skip this part if moving downwards or not at all
    TXA
    CLC
    ADC #$08  ; add eight to vertical coordinate and
    TAX  ; save as X
bra_smb2_main_calculate_platform_rope_vram_address:
    TXA  ; move vertical coordinate to A
    LDX VRAM_Buffer1_Offset  ; get vram buffer offset
    ASL
    ROL  ; rotate d7 to d0 and d6 into carry
    PHA  ; save modified vertical coordinate to stack
    ROL  ; rotate carry to d0, thus d7 and d6 are at 2 LSB
    AND #%00000011  ; mask out all bits but d7 and d6, then set
    ORA #%00100000  ; d5 to get appropriate high byte of name table
    STA $01  ; address, then store
    LDA $02  ; get saved page location from earlier
    AND #$01  ; mask out all but LSB
    ASL
    ASL  ; shift twice to the left and save with the
    ORA $01  ; rest of the bits of the high byte, to get
    STA $01  ; the proper name table and the right place on it
    PLA  ; get modified vertical coordinate from stack
    AND #%11100000  ; mask out low nybble and LSB of high nybble
    CLC
    ADC $00  ; add to horizontal part saved here
    STA $00  ; save as name table low byte
    LDA Enemy_Y_Position,y
    CMP #$e8  ; if vertical position not below the
    BCC bra_smb2_main_exit_platform_rope_address_setup  ; bottom of the screen, we're done, branch to leave
    LDA $00
    AND #%10111111  ; mask out d6 of low byte of name table address
    STA $00
bra_smb2_main_exit_platform_rope_address_setup:
    RTS  ; leave!

loc_smb2_main_initialize_balance_platform_fall:
    TYA  ; move offset of other platform from Y to X
    TAX
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; get offscreen bits
    LDA #$06
    JSR sub_smb2_main_setup_floatey_number  ; award 1000 points to player
    LDA Player_Rel_XPos
    STA FloateyNum_X_Pos,x  ; put floatey number coordinates where player is
    LDA Player_Y_Position
    STA FloateyNum_Y_Pos,x
    LDA #$01  ; set moving direction as flag for
    STA Enemy_MovingDir,x  ; falling platforms

sub_smb2_main_stop_platforms:
    JSR sub_smb2_main_clear_enemy_vertical_motion  ; initialize vertical speed and low byte
    STA Enemy_Y_Speed,y  ; for both platforms and leave
    STA Enemy_Y_MoveForce,y
    RTS

loc_smb2_main_fall_balance_platform_pair:
    TYA  ; save offset for other platform to stack
    PHA
    JSR sub_smb2_main_move_falling_platform  ; make current platform fall
    PLA
    TAX  ; pull offset from stack and save to X
    JSR sub_smb2_main_move_falling_platform  ; make other platform fall
    LDX ObjectOffset
    LDA PlatformCollisionFlag,x  ; if player not standing on either platform,
    BMI bra_smb2_main_exit_balance_platform_fall  ; skip this part
    TAX  ; transfer collision flag offset as offset to X
    JSR sub_smb2_main_position_player_on_vertical_platform  ; and position player appropriately
bra_smb2_main_exit_balance_platform_fall:
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------
