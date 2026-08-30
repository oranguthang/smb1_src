bra_smb2_main_process_small_platform_collisions:
    LDX ObjectOffset  ; return enemy object buffer offset to X, then continue

sub_smb2_main_process_large_platform_collision:
    LDA BoundingBox_DR_YPos,y  ; get difference by subtracting the top
    SEC  ; of the player's bounding box from the bottom
    SBC BoundingBox_UL_YPos  ; of the platform's bounding box
    CMP #$04  ; if difference too large or negative,
    BCS bra_smb2_main_check_platform_top_collision  ; branch, do not alter vertical speed of player
    LDA Player_Y_Speed  ; check to see if player's vertical speed is moving down
    BPL bra_smb2_main_check_platform_top_collision  ; if so, don't mess with it
    LDA #$01  ; otherwise, set vertical
    STA Player_Y_Speed  ; speed of player to kill jump

bra_smb2_main_check_platform_top_collision:
    LDA BoundingBox_DR_YPos  ; get difference by subtracting the top
    SEC  ; of the platform's bounding box from the bottom
    SBC BoundingBox_UL_YPos,y  ; of the player's bounding box
    CMP #$06
    BCS bra_smb2_main_check_platform_side_collisions  ; if difference not close enough, skip all of this
    LDA Player_Y_Speed
    BMI bra_smb2_main_check_platform_side_collisions  ; if player's vertical speed moving upwards, skip this
    LDA $00  ; get saved bounding box counter from earlier
    LDY Enemy_ID,x
    CPY #$2b  ; if either of the two small platform objects are found,
    BEQ bra_smb2_main_store_platform_collision_flag  ; regardless of which one, branch to use bounding box counter
    CPY #$2c  ; as contents of collision flag
    BEQ bra_smb2_main_store_platform_collision_flag
    TXA  ; otherwise use enemy object buffer offset

bra_smb2_main_store_platform_collision_flag:
    LDX ObjectOffset  ; get enemy object buffer offset
    STA PlatformCollisionFlag,x  ; save either bounding box counter or enemy offset here
    LDA #$00
    STA Player_State  ; set player state to normal then leave
    RTS

bra_smb2_main_check_platform_side_collisions:
    LDA #$01  ; set value here to indicate possible horizontal
    STA $00  ; collision on left side of platform
    LDA BoundingBox_DR_XPos  ; get difference by subtracting platform's left edge
    SEC  ; from player's right edge
    SBC BoundingBox_UL_XPos,y
    CMP #$08  ; if difference close enough, skip all of this
    BCC bra_smb2_main_handle_platform_side_collision
    INC $00  ; otherwise increment value set here for right side collision
    LDA BoundingBox_DR_XPos,y  ; get difference by subtracting player's left edge
    CLC  ; from platform's right edge
    SBC BoundingBox_UL_XPos
    CMP #$09  ; if difference not close enough, skip subroutine
    BCS bra_smb2_main_exit_platform_side_collision  ; and instead branch to leave (no collision)
bra_smb2_main_handle_platform_side_collision:
    JSR sub_smb2_main_impede_player_move  ; deal with horizontal collision
bra_smb2_main_exit_platform_side_collision:
    LDX ObjectOffset  ; return with enemy object buffer offset
    RTS

; -------------------------------------------------------------------------------------

off_smb2_main_small_platform_player_y_offsets:
    .byte $80, $00

sub_smb2_main_position_player_on_small_platform:
    TAY  ; use bounding box counter saved in collision flag
    LDA Enemy_Y_Position,x  ; for offset
    CLC  ; add positioning data using offset to the vertical
    ADC off_smb2_main_small_platform_player_y_offsets-1,y  ; coordinate
    .byte $2c  ; BIT instruction opcode

sub_smb2_main_position_player_on_vertical_platform:
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    LDY GameEngineSubroutine
    CPY #$0b  ; if certain routine being executed on this frame,
    BEQ bra_smb2_main_exit_player_platform_position  ; skip all of this
    LDY Enemy_Y_HighPos,x
    CPY #$01  ; if vertical high byte offscreen, skip this
    BNE bra_smb2_main_exit_player_platform_position
    SEC  ; subtract 32 pixels from vertical coordinate
    SBC #$20  ; for the player object's height
    STA Player_Y_Position  ; save as player's new vertical coordinate
    TYA
    SBC #$00  ; subtract borrow and store as player's
    STA Player_Y_HighPos  ; new vertical high byte
    LDA #$00
    STA Player_Y_Speed  ; initialize vertical speed and low byte of force
    STA Player_Y_MoveForce  ; and then leave
bra_smb2_main_exit_player_platform_position:
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_check_player_vertical:
    LDA Player_OffscreenBits  ; if player object is not offscreen
    AND #$f0  ; then branch with clear carry flag
    CLC
    BEQ bra_smb2_main_exit_vertical_platform_player_position  ; otherwise fall through and set carry flag
    SEC  ; to symbolize that player is offscreen
bra_smb2_main_exit_vertical_platform_player_position:
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_get_enemy_bounding_box_offset:
    LDA ObjectOffset  ; get enemy object buffer offset

sub_smb2_main_get_enemy_bounding_box_offset_from_x:
    ASL  ; multiply A by four, then add four
    ASL  ; to skip player's bounding box
    CLC
    ADC #$04
    TAY  ; send to Y
    LDA Enemy_OffscreenBits  ; get offscreen bits for enemy object
    AND #%00001111  ; save low nybble
    CMP #%00001111  ; check for all bits set
    RTS

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold many values, essentially temp variables
; $04 - holds lower nybble of vertical coordinate from block buffer routine
; $eb - used to hold block buffer adder

tbl_smb2_main_player_background_collision_upper_extents:
    .byte $20, $10

sub_smb2_main_handle_player_background_collision:
    LDA DisableCollisionDet  ; if collision detection disabled flag set,
    BNE bra_smb2_main_exit_player_background_collision  ; branch to leave
    LDA GameEngineSubroutine
    CMP #$0b  ; if running routine #11 or $0b
    BEQ bra_smb2_main_exit_player_background_collision  ; branch to leave
    CMP #$04
    BCC bra_smb2_main_exit_player_background_collision  ; if running routines $00-$03 branch to leave
    LDA #$01  ; load default player state for swimming
    LDY SwimmingFlag  ; if swimming flag set,
    BNE bra_smb2_main_store_default_player_state  ; branch ahead to set default state
    LDA Player_State  ; if player in normal state,
    BEQ bra_smb2_main_set_player_falling_state  ; branch to set default state for falling
    CMP #$03
    BNE bra_smb2_main_check_player_collision_screen_range  ; if in any other state besides climbing, skip to next part
bra_smb2_main_set_player_falling_state:
    LDA #$02  ; load default player state for falling
bra_smb2_main_store_default_player_state:
    STA Player_State  ; set whatever player state is appropriate
bra_smb2_main_check_player_collision_screen_range:
    LDA Player_Y_HighPos
    CMP #$01  ; check player's vertical high byte for still on the screen
    BNE bra_smb2_main_exit_player_background_collision  ; branch to leave if not
    LDA #$ff
    STA Player_CollisionBits  ; initialize player's collision flag
    LDA Player_Y_Position
    CMP #$cf  ; check player's vertical coordinate
    BCC bra_smb2_main_select_player_collision_shape  ; if not too close to the bottom of screen, continue
bra_smb2_main_exit_player_background_collision:
    RTS  ; otherwise leave

bra_smb2_main_select_player_collision_shape:
    LDY #$02  ; load default offset
    LDA CrouchingFlag
    BNE bra_smb2_main_load_player_block_buffer_offset  ; if player crouching, skip ahead
    LDA PlayerSize
    BNE bra_smb2_main_load_player_block_buffer_offset  ; if player small, skip ahead
    DEY  ; otherwise decrement offset for big player not crouching
    LDA SwimmingFlag
    BNE bra_smb2_main_load_player_block_buffer_offset  ; if swimming flag set, skip ahead
    DEY  ; otherwise decrement offset
bra_smb2_main_load_player_block_buffer_offset:
    LDA off_smb2_main_block_buffer_object_offsets,y  ; get value using offset
    STA $eb  ; store value here
    TAY  ; put value into Y, as offset for block buffer routine
    LDX PlayerSize  ; get player's size as offset
    LDA CrouchingFlag
    BEQ bra_smb2_main_check_player_head_collision  ; if player not crouching, branch ahead
    INX  ; otherwise increment size as offset
bra_smb2_main_check_player_head_collision:
    LDA Player_Y_Position  ; get player's vertical coordinate
    CMP tbl_smb2_main_player_background_collision_upper_extents,x  ; compare with upper extent value based on offset
    BCC bra_smb2_main_check_player_feet  ; if player is too high, skip this part
    JSR sub_smb2_main_check_player_head_block_buffer  ; do player-to-bg collision detection on top of
    BEQ bra_smb2_main_check_player_feet  ; player, and branch if nothing above player's head
    JSR sub_smb2_main_check_coin_metatiles  ; check to see if player touched coin with their head
    BCS bra_smb2_main_award_touched_coin  ; if so, branch to some other part of code
    LDY Player_Y_Speed  ; check player's vertical speed
    BPL bra_smb2_main_check_player_feet  ; if player not moving upwards, branch elsewhere
    LDY $04  ; check lower nybble of vertical coordinate returned
    CPY #$04  ; from collision detection routine
    BCC bra_smb2_main_check_player_feet  ; if low nybble < 4, branch
    JSR sub_smb2_main_check_solid_metatiles  ; check to see what player's head bumped on
    BCS bra_smb2_main_handle_solid_head_collision  ; if player collided with solid metatile, branch
    LDY AreaType  ; otherwise check area type
    BEQ bra_smb2_main_cancel_player_upward_speed  ; if water level, branch ahead
    LDY BlockBounceTimer  ; if block bounce timer not expired,
    BNE bra_smb2_main_cancel_player_upward_speed  ; branch ahead, do not process collision
    JSR sub_smb2_main_player_head_collision  ; otherwise do a sub to process collision
    JMP bra_smb2_main_check_player_feet  ; jump ahead to skip these other parts here

bra_smb2_main_handle_solid_head_collision:
    CMP #$23  ; if climbing metatile,
    BEQ bra_smb2_main_cancel_player_upward_speed  ; branch ahead and do not play sound
    LDA #Sfx_Bump
    STA Square1SoundQueue  ; otherwise load bump sound
bra_smb2_main_cancel_player_upward_speed:
    LDA #$01  ; set player's vertical speed to nullify
    STA Player_Y_Speed  ; jump or swim

bra_smb2_main_check_player_feet:
    LDY $eb  ; get block buffer adder offset
    LDA Player_Y_Position
    CMP #$cf  ; check to see how low player is
    BCS bra_smb2_main_check_player_side_metatiles  ; if player is too far down on screen, skip all of this
    JSR sub_smb2_main_check_player_feet_block_buffer  ; do player-to-bg collision detection on bottom left of player
    JSR sub_smb2_main_check_coin_metatiles  ; check to see if player touched coin with their left foot
    BCS bra_smb2_main_award_touched_coin  ; if so, branch to some other part of code
    PHA  ; save bottom left metatile to stack
    JSR sub_smb2_main_check_player_feet_block_buffer  ; do player-to-bg collision detection on bottom right of player
    STA $00  ; save bottom right metatile here
    PLA
    STA $01  ; pull bottom left metatile and save here
    BNE bra_smb2_main_handle_player_foot_metatile  ; if anything here, skip this part
    LDA $00  ; otherwise check for anything in bottom right metatile
    BEQ bra_smb2_main_check_player_side_metatiles  ; and skip ahead if not
    JSR sub_smb2_main_check_coin_metatiles  ; check to see if player touched coin with their right foot
    BCC bra_smb2_main_handle_player_foot_metatile  ; if not, skip unconditional jump and continue code

bra_smb2_main_award_touched_coin:
    JMP bra_smb2_main_handle_coin_metatile  ; follow the code to erase coin and award to player 1 coin

bra_smb2_main_handle_player_foot_metatile:
    JSR sub_smb2_main_check_climbable_metatiles  ; check to see if player landed on climbable metatiles
    BCS bra_smb2_main_check_player_side_metatiles  ; if so, branch
    LDY Player_Y_Speed  ; check player's vertical speed
    BMI bra_smb2_main_check_player_side_metatiles  ; if player moving upwards, branch
    CMP #$c6
    BNE bra_smb2_main_continue_player_floor_check  ; if player did not touch axe, skip ahead
    JMP loc_smb2_main_handle_axe_metatile  ; otherwise jump to set modes of operation
bra_smb2_main_continue_player_floor_check:
    JSR sub_smb2_main_check_invisible_metatiles  ; do sub to check for hidden coin or 1-up blocks
    BEQ bra_smb2_main_check_player_side_metatiles  ; if either found, branch
    LDY JumpspringAnimCtrl  ; if jumpspring animating right now,
    BNE bra_smb2_main_set_player_ground_state  ; branch ahead
    LDY $04  ; check lower nybble of vertical coordinate returned
    CPY #$05  ; from collision detection routine
    BCC bra_smb2_main_land_player_on_metatile  ; if lower nybble < 5, branch
    LDA Player_MovingDir
    STA $00  ; use player's moving direction as temp variable
    JMP sub_smb2_main_impede_player_move  ; jump to impede player's movement in that direction
bra_smb2_main_land_player_on_metatile:
    JSR sub_smb2_main_check_jumpspring_landing  ; do sub to check for jumpspring metatiles and deal with it
    LDA #$f0
    AND Player_Y_Position  ; mask out lower nybble of player's vertical position
    STA Player_Y_Position  ; and store as new vertical position to land player properly
    JSR sub_smb2_main_handle_pipe_entry  ; do sub to process potential pipe entry
    LDA #$00
    STA Player_Y_Speed  ; initialize vertical speed and fractional
    STA Player_Y_MoveForce  ; movement force to stop player's vertical movement
    STA StompChainCounter  ; initialize enemy stomp counter
bra_smb2_main_set_player_ground_state:
    LDA #$00
    STA Player_State  ; set player's state to normal

bra_smb2_main_check_player_side_metatiles:
    LDY $eb  ; get block buffer adder offset
    INY
    INY  ; increment offset 2 bytes to use adders for side collisions
    LDA #$02  ; set value here to be used as counter
    STA $00

bra_smb2_main_check_player_side_metatiles_loop:
    INY  ; move onto the next one
    STY $eb  ; store it
    LDA Player_Y_Position
    CMP #$20  ; check player's vertical position
    BCC bra_smb2_main_check_lower_player_side  ; if player is in status bar area, branch ahead to skip this part
    CMP #$e4
    BCS bra_smb2_main_exit_player_side_collision  ; branch to leave if player is too far down
    JSR sub_smb2_main_check_player_side_block_buffer  ; do player-to-bg collision detection on one half of player
    BEQ bra_smb2_main_check_lower_player_side  ; branch ahead if nothing found
    CMP #$19  ; otherwise check for pipe metatiles
    BEQ bra_smb2_main_check_lower_player_side  ; if collided with sideways pipe (top), branch ahead
    CMP #$6d
    BEQ bra_smb2_main_check_lower_player_side  ; if collided with water pipe (top), branch ahead
    JSR sub_smb2_main_check_climbable_metatiles  ; do sub to see if player bumped into anything climbable
    BCC bra_smb2_main_handle_player_side_metatile  ; if not, branch to alternate section of code
bra_smb2_main_check_lower_player_side:
    LDY $eb  ; load block adder offset
    INY  ; increment it
    LDA Player_Y_Position  ; get player's vertical position
    CMP #$08
    BCC bra_smb2_main_exit_player_side_collision  ; if too high, branch to leave
    CMP #$d0
    BCS bra_smb2_main_exit_player_side_collision  ; if too low, branch to leave
    JSR sub_smb2_main_check_player_side_block_buffer  ; do player-to-bg collision detection on other half of player
    BNE bra_smb2_main_handle_player_side_metatile  ; if something found, branch
    DEC $00  ; otherwise decrement counter
    BNE bra_smb2_main_check_player_side_metatiles_loop  ; run code until both sides of player are checked
bra_smb2_main_exit_player_side_collision:
    RTS  ; leave

bra_smb2_main_handle_player_side_metatile:
    JSR sub_smb2_main_check_invisible_metatiles  ; check for hidden or coin 1-up blocks
    BEQ bra_smb2_main_exit_player_side_metatile_check  ; branch to leave if either found
    JSR sub_smb2_main_check_climbable_metatiles  ; check for climbable metatiles
    BCC bra_smb2_main_continue_player_side_check  ; if not found, skip and continue with code
    JMP loc_smb2_main_handle_climbing_metatile  ; otherwise jump to handle climbing
bra_smb2_main_continue_player_side_check:
    JSR sub_smb2_main_check_coin_metatiles  ; check to see if player touched coin
    BCS bra_smb2_main_handle_coin_metatile  ; if so, execute code to erase coin and award to player 1 coin
    JSR sub_smb2_main_check_jumpspring_metatiles  ; check for jumpspring metatiles
    BCC bra_smb2_main_check_side_pipe_bottom  ; if not found, branch ahead to continue cude
    LDA JumpspringAnimCtrl  ; otherwise check jumpspring animation control
    BNE bra_smb2_main_exit_player_side_metatile_check  ; branch to leave if set
    JMP bra_smb2_main_stop_player_horizontal_movement  ; otherwise jump to impede player's movement
bra_smb2_main_check_side_pipe_bottom:
    LDY Player_State  ; get player's state
    CPY #$00  ; check for player's state set to normal
    BNE bra_smb2_main_stop_player_horizontal_movement  ; if not, branch to impede player's movement
    LDY PlayerFacingDir  ; get player's facing direction
    DEY
    BNE bra_smb2_main_stop_player_horizontal_movement  ; if facing left, branch to impede movement
    CMP #$6e  ; otherwise check for pipe metatiles
    BEQ bra_smb2_main_start_side_pipe_entry  ; if collided with sideways pipe (bottom), branch
    CMP #$1c  ; if collided with water pipe (bottom), continue
    BNE bra_smb2_main_stop_player_horizontal_movement  ; otherwise branch to impede player's movement
bra_smb2_main_start_side_pipe_entry:
    LDA Player_SprAttrib  ; check player's attributes
    BNE bra_smb2_main_put_player_behind_pipe  ; if already set, branch, do not play sound again
    LDY #Sfx_PipeDown_Injury
    STY Square1SoundQueue  ; otherwise load pipedown/injury sound
bra_smb2_main_put_player_behind_pipe:
    ORA #%00100000
    STA Player_SprAttrib  ; set background priority bit in player attributes
    LDA Player_X_Position
    AND #%00001111  ; get lower nybble of player's horizontal coordinate
    BEQ bra_smb2_main_check_pipe_entry_game_task  ; if at zero, branch ahead to skip this part
    LDY #$00  ; set default offset for timer setting data
    LDA ScreenLeft_PageLoc  ; load page location for left side of screen
    BEQ bra_smb2_main_set_area_change_timer  ; if at page zero, use default offset
    INY  ; otherwise increment offset
bra_smb2_main_set_area_change_timer:
    LDA off_smb2_main_area_change_delays,y  ; set timer for change of area as appropriate
    STA ChangeAreaTimer
bra_smb2_main_check_pipe_entry_game_task:
    LDA GameEngineSubroutine  ; get number of game engine routine running
    CMP #$07
    BEQ bra_smb2_main_exit_player_side_metatile_check  ; if running player entrance routine or
    CMP #$08  ; player control routine, go ahead and branch to leave
    BNE bra_smb2_main_exit_player_side_metatile_check
    LDA #$02
    STA GameEngineSubroutine  ; otherwise set sideways pipe entry routine to run
    RTS  ; and leave

; --------------------------------
; $02 - high nybble of vertical coordinate from block buffer
; $04 - low nybble of horizontal coordinate from block buffer
; $06-$07 - block buffer address

bra_smb2_main_stop_player_horizontal_movement:
    JSR sub_smb2_main_impede_player_move  ; stop player's movement
bra_smb2_main_exit_player_side_metatile_check:
    RTS  ; leave

off_smb2_main_area_change_delays:
    .byte $a0, $34

bra_smb2_main_handle_coin_metatile:
    JSR sub_smb2_main_erase_coin_or_axe_metatile  ; do sub to erase coin metatile from block buffer
    INC CoinTallyFor1Ups  ; increment coin tally used for 1-up blocks
    JMP sub_smb2_main_give_one_coin  ; update coin amount and tally on the screen

loc_smb2_main_handle_axe_metatile:
    LDA #$00
    STA OperMode_Task  ; reset secondary mode
    LDA #$02
    STA OperMode  ; set primary mode to victory mode
    JSR sub_smb2_main_load_mario_physics
    LDA #$18
    STA Player_X_Speed  ; set horizontal speed and continue to erase axe metatile
sub_smb2_main_erase_coin_or_axe_metatile:
    LDY $02  ; load vertical high nybble offset for block buffer
    LDA #$00  ; load blank metatile
    STA ($06),y  ; store to remove old contents from block buffer
    JMP sub_smb2_main_remove_coin_axe  ; update the screen accordingly

; --------------------------------
; $02 - high nybble of vertical coordinate from block buffer
; $04 - low nybble of horizontal coordinate from block buffer
; $06-$07 - block buffer address

tbl_smb2_main_climb_x_position_offsets:
    .byte $f9, $07

tbl_smb2_main_climb_page_offsets:
    .byte $ff, $00

off_smb2_main_flagpole_score_y_positions:
    .byte $18, $22, $50, $68, $90

loc_smb2_main_handle_climbing_metatile:
    LDY $04  ; check low nybble of horizontal coordinate returned from
    CPY #$06  ; collision detection routine against certain values, this
    BCC bra_smb2_main_exit_climbing_handler  ; makes actual physical part of vine or flagpole thinner
    CPY #$0a  ; than 16 pixels
    BCC bra_smb2_main_check_flagpole_metatile
bra_smb2_main_exit_climbing_handler:
    RTS  ; leave if too far left or too far right

bra_smb2_main_check_flagpole_metatile:
    CMP #$21  ; check climbing metatiles
    BEQ bra_smb2_main_handle_flagpole_collision  ; branch if flagpole ball found
    CMP #$22
    BNE bra_smb2_main_handle_vine_collision  ; branch to alternate code if flagpole shaft not found

bra_smb2_main_handle_flagpole_collision:
    LDA GameEngineSubroutine
    CMP #$05  ; check for end-of-level routine running
    BEQ bra_smb2_main_attach_player_to_vine  ; if running, branch to end of climbing code
    LDA #$01
    STA PlayerFacingDir  ; set player's facing direction to right
    INC ScrollLock  ; set scroll lock flag
    LDA GameEngineSubroutine
    CMP #$04  ; check for flagpole slide routine running
    BEQ bra_smb2_main_start_flagpole_routine  ; if running, branch to end of flagpole code here
    LDA #BulletBill_CannonVar  ; load identifier for bullet bills (cannon variant)
    JSR sub_smb2_main_kill_enemies  ; get rid of them
    LDA #Silence
    STA EventMusicQueue  ; silence music
    LSR
    STA FlagpoleSoundQueue  ; load flagpole sound into flagpole sound queue
    LDX #$04  ; start at end of vertical coordinate data
    LDA Player_Y_Position
    STA FlagpoleCollisionYPos  ; store player's vertical coordinate here to be used later

bra_smb2_main_select_flagpole_score_y_position:
    CMP off_smb2_main_flagpole_score_y_positions,x  ; compare with current vertical coordinate data
    BCS bra_smb2_main_store_flagpole_score_index  ; if player's => current, branch to use current offset
    DEX  ; otherwise decrement offset to use
    BNE bra_smb2_main_select_flagpole_score_y_position  ; do this until all data is checked (use last one if all checked)
bra_smb2_main_store_flagpole_score_index:
    STX FlagpoleScore  ; store offset here to be used later
    LDA CoinDisplay
    CMP CoinDisplay+1  ; check to see if coin tally digits are the same
    BNE bra_smb2_main_start_flagpole_routine  ; if not, branch to use flagpole score data as-is
    CMP GameTimerDisplay+2  ; check to see if the last digit of game timer matches
    BNE bra_smb2_main_start_flagpole_routine  ; the two digits, if not, branch to use data as-is
    LDA #$05
    STA FlagpoleScore  ; otherwise, set to give player an extra life
bra_smb2_main_start_flagpole_routine:
    LDA #$04
    STA GameEngineSubroutine  ; set value to run flagpole slide routine
    JMP bra_smb2_main_attach_player_to_vine  ; jump to end of climbing code

bra_smb2_main_handle_vine_collision:
    CMP #$23  ; check for climbing metatile used on vines
    BNE bra_smb2_main_attach_player_to_vine
    LDA Player_Y_Position  ; check player's vertical coordinate
    CMP #$20  ; for being in status bar area
    BCS bra_smb2_main_attach_player_to_vine  ; branch if not that far up
    LDA #$01
    STA GameEngineSubroutine  ; otherwise set to run autoclimb routine next frame

bra_smb2_main_attach_player_to_vine:
    LDA #$03  ; set player state to climbing
    STA Player_State
    LDA #$00  ; nullify player's horizontal speed
    STA Player_X_Speed  ; and fractional horizontal movement force
    STA Player_X_MoveForce
    LDA Player_X_Position  ; get player's horizontal coordinate
    SEC
    SBC ScreenLeft_X_Pos  ; subtract from left side horizontal coordinate
    CMP #$10
    BCS bra_smb2_main_align_player_x_to_vine  ; if 16 or more pixels difference, do not alter facing direction
    LDA #$02
    STA PlayerFacingDir  ; otherwise force player to face left
bra_smb2_main_align_player_x_to_vine:
    LDY PlayerFacingDir  ; get current facing direction, use as offset
    LDA $06  ; get low byte of block buffer address
    ASL
    ASL  ; move low nybble to high
    ASL
    ASL
    CLC
    ADC tbl_smb2_main_climb_x_position_offsets-1,y  ; add pixels depending on facing direction
    STA Player_X_Position  ; store as player's horizontal coordinate
    LDA $06  ; get low byte of block buffer address again
    BNE bra_smb2_main_exit_player_vine_position  ; if not zero, branch
    LDA ScreenRight_PageLoc  ; load page location of right side of screen
    CLC
    ADC tbl_smb2_main_climb_page_offsets-1,y  ; add depending on facing location
    STA Player_PageLoc  ; store as player's page location
bra_smb2_main_exit_player_vine_position:
    RTS  ; finally, we're done!

; --------------------------------

sub_smb2_main_check_invisible_metatiles:
    CMP #$5e  ; check for hidden coin block
    BEQ bra_smb2_main_return_invisible_metatile_test
    CMP #$5f  ; check for hidden 1-up block
    BEQ bra_smb2_main_return_invisible_metatile_test
    CMP #$60  ; check for hidden poison shroom block
    BEQ bra_smb2_main_return_invisible_metatile_test
    CMP #$61  ; check for hidden power-up block
bra_smb2_main_return_invisible_metatile_test:
    RTS  ; leave with zero flag set if any of these found

; --------------------------------
; $00-$01 - used to hold bottom right and bottom left metatiles (in that order)
; $00 - used as flag by ImpedePlayerMove to restrict specific movement

sub_smb2_main_check_jumpspring_landing:
    JSR sub_smb2_main_check_jumpspring_metatiles  ; do sub to check if player landed on jumpspring
    BCC bra_smb2_main_exit_jumpspring_landing_check  ; if carry not set, jumpspring not found, therefore leave
    LDA #$70
    STA VerticalForce  ; otherwise set vertical movement force for player
    STA VerticalForceDown
    LDA #$f9
    STA JumpspringForce  ; set default jumpspring force
    LDA #$03
    STA JumpspringTimer  ; set jumpspring timer to be used later
    LSR
    STA JumpspringAnimCtrl  ; set jumpspring animation control to start animating
bra_smb2_main_exit_jumpspring_landing_check:
    RTS  ; and leave

sub_smb2_main_check_jumpspring_metatiles:
    CMP #$68  ; check for top jumpspring metatile
    BEQ bra_smb2_main_return_jumpspring_metatile_found  ; branch to set carry if found
    CMP #$69  ; check for bottom jumpspring metatile
    CLC  ; clear carry flag
    BNE bra_smb2_main_return_no_jumpspring_metatile  ; branch to use cleared carry if not found
bra_smb2_main_return_jumpspring_metatile_found:
    SEC  ; set carry if found
bra_smb2_main_return_no_jumpspring_metatile:
    RTS  ; leave

sub_smb2_main_handle_pipe_entry:
    LDA Up_Down_Buttons  ; check saved controller bits from earlier
    AND #%00000100  ; for pressing down
    BEQ bra_smb2_main_exit_pipe_entry_check  ; if not pressing down, branch to leave
    LDA $00
    CMP #$11  ; check right foot metatile for warp pipe right metatile
    BNE bra_smb2_main_exit_pipe_entry_check  ; branch to leave if not found
    LDA $01
    CMP #$10  ; check left foot metatile for warp pipe left metatile
    BNE bra_smb2_main_exit_pipe_entry_check  ; branch to leave if not found
    LDA #$30
    STA ChangeAreaTimer  ; set timer for change of area
    LDA #$03
    STA GameEngineSubroutine  ; set to run vertical pipe entry routine on next frame
    LDA #Sfx_PipeDown_Injury
    STA Square1SoundQueue  ; load pipedown/injury sound
    LDA #%00100000
    STA Player_SprAttrib  ; set background priority bit in player's attributes
    LDA WarpZoneControl  ; check warp zone control
    BEQ bra_smb2_main_exit_pipe_entry_check  ; branch to leave if none found
    AND #%00001111  ; mask out all but lower nybble
    TAX  ; save as offset, then use to load warp zone destination
    LDA tbl_smb2_main_warp_zone_number_tiles,x
    LDY HardWorldFlag  ; if playing worlds A-D, branch to skip this part
    BEQ bra_smb2_main_set_w_dest
    SEC
    SBC #$09  ; otherwise subtract 9 to get correct world number
bra_smb2_main_set_w_dest:
    TAY
    DEY  ; decrement for use as world number
    STY WorldNumber  ; store as world number and offset
    LDX tbl_smb2_main_world_area_pointer_offsets,y  ; get offset to where this world's area offsets are
    LDA tbl_smb2_main_area_pointers,x  ; get area offset based on world offset
    STA AreaPointer  ; store area offset here to be used to change areas
    LDA #Silence
    STA EventMusicQueue  ; silence music
    LDA #$00
    STA EntrancePage  ; initialize starting page number
    STA AreaNumber  ; initialize area number used for area address offset
    STA LevelNumber  ; initialize level number used for world display
    STA AltEntranceControl  ; initialize mode of entry
    INC Hidden1UpFlag  ; set flag for hidden 1-up blocks
    INC FetchNewGameTimerFlag  ; set flag to load new game timer
bra_smb2_main_exit_pipe_entry_check:
    RTS  ; leave!!!

sub_smb2_main_impede_player_move:
    LDA #$00  ; initialize value here
    LDY Player_X_Speed  ; get player's horizontal speed
    LDX $00  ; check value set earlier for
    DEX  ; left side collision
    BNE bra_smb2_main_impede_player_right  ; if right side collision, skip this part
    INX  ; return value to X
    CPY #$00  ; if player moving to the left,
    BMI bra_smb2_main_exit_impede_player_move  ; branch to invert bit and leave
    LDA #$ff  ; otherwise load A with value to be used later
    JMP loc_smb2_main_clear_player_x_speed  ; and jump to affect movement
bra_smb2_main_impede_player_right:
    LDX #$02  ; return $02 to X
    CPY #$01  ; if player moving to the right,
    BPL bra_smb2_main_exit_impede_player_move  ; branch to invert bit and leave
    LDA #$01  ; otherwise load A with value to be used here
loc_smb2_main_clear_player_x_speed:
    LDY #$10
    STY SideCollisionTimer  ; set timer of some sort
    LDY #$00
    STY Player_X_Speed  ; nullify player's horizontal speed
    CMP #$00  ; if value set in A not set to $ff,
    BPL bra_smb2_main_apply_platform_collision_force  ; branch ahead, do not decrement Y
    DEY  ; otherwise decrement Y now
bra_smb2_main_apply_platform_collision_force:
    STY $00  ; store Y as high bits of horizontal adder
    CLC
    ADC Player_X_Position  ; add contents of A to player's horizontal
    STA Player_X_Position  ; position to move player left or right
    LDA Player_PageLoc
    ADC $00  ; add high bits and carry to
    STA Player_PageLoc  ; page location if necessary
bra_smb2_main_exit_impede_player_move:
    TXA  ; invert contents of X
    EOR #$ff
    AND Player_CollisionBits  ; mask out bit that was set here
    STA Player_CollisionBits  ; store to clear bit
    RTS

; --------------------------------
