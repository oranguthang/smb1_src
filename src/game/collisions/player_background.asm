; -------------------------------------------------------------------------------------
; $00-$01 - used to hold many values, essentially temp variables
; $04 - holds lower nybble of vertical coordinate from block buffer routine
; $eb - used to hold block buffer adder

tbl_player_background_collision_upper_extents:
    .byte $20, $10

; Resolve player contact with head, feet, side, climb, coin, and pipe metatiles

; Inputs:
; Player position, bounding box, motion state, size, and block buffer

; Outputs:
; Player state, position, velocity, collision bits, and gameplay events may
; change

; Clobbers:
; A, X, Y
sub_handle_player_background_collision:
    LDA ram_disable_collision_det  ; if collision detection disabled flag set,
    BNE bra_exit_player_background_collision  ; branch to leave
    LDA ram_game_engine_subroutine
    CMP #$0b  ; if running routine #11 or $0b
    BEQ bra_exit_player_background_collision  ; branch to leave
    CMP #$04
    BCC bra_exit_player_background_collision  ; if running routines $00-$03 branch to leave
    LDA #$01  ; load default player state for swimming
    LDY ram_swimming_flag  ; if swimming flag set,
    BNE bra_store_default_player_state  ; branch ahead to set default state
    LDA ram_player_state  ; if player in normal state,
    BEQ bra_set_player_falling_state  ; branch to set default state for falling
    CMP #$03
    BNE bra_check_player_collision_screen_range  ; if in any other state besides climbing, skip to next part
bra_set_player_falling_state:
    LDA #$02  ; load default player state for falling
bra_store_default_player_state:
    STA ram_player_state  ; set whatever player state is appropriate
bra_check_player_collision_screen_range:
    LDA ram_player_y_high_pos
    CMP #$01  ; check player's vertical high byte for still on the screen
    BNE bra_exit_player_background_collision  ; branch to leave if not
    LDA #$ff
    STA ram_player_collision_bits  ; initialize player's collision flag
    LDA ram_player_y_position
    CMP #$cf  ; check player's vertical coordinate
    BCC bra_select_player_collision_shape  ; if not too close to the bottom of screen, continue
bra_exit_player_background_collision:
    RTS  ; otherwise leave

bra_select_player_collision_shape:
    LDY #$02  ; load default offset
    LDA ram_crouching_flag
    BNE bra_load_player_block_buffer_offset  ; if player crouching, skip ahead
    LDA ram_player_size
    BNE bra_load_player_block_buffer_offset  ; if player small, skip ahead
    DEY  ; otherwise decrement offset for big player not crouching
    LDA ram_swimming_flag
    BNE bra_load_player_block_buffer_offset  ; if swimming flag set, skip ahead
    DEY  ; otherwise decrement offset
bra_load_player_block_buffer_offset:
    LDA tbl_block_buffer_object_offsets,y  ; get value using offset
    STA $eb  ; store value here
    TAY  ; put value into Y, as offset for block buffer routine
    LDX ram_player_size  ; get player's size as offset
    LDA ram_crouching_flag
    BEQ bra_check_player_head_collision  ; if player not crouching, branch ahead
    INX  ; otherwise increment size as offset
bra_check_player_head_collision:
    LDA ram_player_y_position  ; get player's vertical coordinate
    CMP tbl_player_background_collision_upper_extents,x  ; compare with upper extent value based on offset
    BCC loc_check_player_feet  ; if player is too high, skip this part
    JSR sub_check_player_head_block_buffer  ; do player-to-bg collision detection on top of
    BEQ loc_check_player_feet  ; player, and branch if nothing above player's head
    JSR sub_check_coin_metatiles  ; check to see if player touched coin with their head
    BCS loc_award_touched_coin  ; if so, branch to some other part of code
    LDY ram_player_y_speed  ; check player's vertical speed
    BPL loc_check_player_feet  ; if player not moving upwards, branch elsewhere
    LDY $04  ; check lower nybble of vertical coordinate returned
    CPY #$04  ; from collision detection routine
    BCC loc_check_player_feet  ; if low nybble < 4, branch
    JSR sub_check_solid_metatiles  ; check to see what player's head bumped on
    BCS bra_handle_solid_head_collision  ; if player collided with solid metatile, branch
    LDY ram_area_type  ; otherwise check area type
    BEQ bra_cancel_player_upward_speed  ; if water level, branch ahead
    LDY ram_block_bounce_timer  ; if block bounce timer not expired,
    BNE bra_cancel_player_upward_speed  ; branch ahead, do not process collision
    JSR sub_player_head_collision  ; otherwise do a sub to process collision
    JMP loc_check_player_feet  ; jump ahead to skip these other parts here

bra_handle_solid_head_collision:
    CMP #$26  ; if climbing metatile,
    BEQ bra_cancel_player_upward_speed  ; branch ahead and do not play sound
    LDA #con_sfx_bump
    STA ram_square1_sound_queue  ; otherwise load bump sound
bra_cancel_player_upward_speed:
.if con_revision_profile = con_revision_profile_pal
    LDY #$01  ; stop upward motion outside water
    LDA ram_area_type
    BNE bra_store_cancelled_player_y_speed
    DEY  ; preserve a zero vertical speed underwater
bra_store_cancelled_player_y_speed:
    STY ram_player_y_speed
.else
    LDA #$01  ; set player's vertical speed to nullify
    STA ram_player_y_speed  ; jump or swim
.endif

loc_check_player_feet:
    LDY $eb  ; get block buffer adder offset
    LDA ram_player_y_position
    CMP #$cf  ; check to see how low player is
    BCS bra_check_player_side_metatiles  ; if player is too far down on screen, skip all of this
    JSR sub_check_player_feet_block_buffer  ; do player-to-bg collision detection on bottom left of player
    JSR sub_check_coin_metatiles  ; check to see if player touched coin with their left foot
    BCS loc_award_touched_coin  ; if so, branch to some other part of code
    PHA  ; save bottom left metatile to stack
    JSR sub_check_player_feet_block_buffer  ; do player-to-bg collision detection on bottom right of player
    STA $00  ; save bottom right metatile here
    PLA
    STA $01  ; pull bottom left metatile and save here
    BNE bra_handle_player_foot_metatile  ; if anything here, skip this part
    LDA $00  ; otherwise check for anything in bottom right metatile
    BEQ bra_check_player_side_metatiles  ; and skip ahead if not
    JSR sub_check_coin_metatiles  ; check to see if player touched coin with their right foot
    BCC bra_handle_player_foot_metatile  ; if not, skip unconditional jump and continue code

loc_award_touched_coin:
    JMP loc_handle_coin_metatile  ; follow the code to erase coin and award to player 1 coin

bra_handle_player_foot_metatile:
    JSR sub_check_climbable_metatiles  ; check to see if player landed on climbable metatiles
    BCS bra_check_player_side_metatiles  ; if so, branch
    LDY ram_player_y_speed  ; check player's vertical speed
    BMI bra_check_player_side_metatiles  ; if player moving upwards, branch
    CMP #$c5
    BNE bra_continue_player_floor_check  ; if player did not touch axe, skip ahead
    JMP loc_handle_axe_metatile  ; otherwise jump to set modes of operation
bra_continue_player_floor_check:
    JSR sub_check_invisible_metatiles  ; do sub to check for hidden coin or 1-up blocks
    BEQ bra_check_player_side_metatiles  ; if either found, branch
    LDY ram_jumpspring_anim_ctrl  ; if jumpspring animating right now,
    BNE bra_set_player_ground_state  ; branch ahead
    LDY $04  ; check lower nybble of vertical coordinate returned
    CPY #con_player_ground_collision_limit  ; from collision detection routine
    BCC bra_land_player_on_metatile  ; if lower nybble < 5, branch
    LDA ram_player_moving_dir
    STA $00  ; use player's moving direction as temp variable
    JMP sub_impede_player_move  ; jump to impede player's movement in that direction
bra_land_player_on_metatile:
    JSR sub_check_jumpspring_landing  ; do sub to check for jumpspring metatiles and deal with it
    LDA #$f0
    AND ram_player_y_position  ; mask out lower nybble of player's vertical position
    STA ram_player_y_position  ; and store as new vertical position to land player properly
    JSR sub_handle_pipe_entry  ; do sub to process potential pipe entry
    LDA #$00
    STA ram_player_y_speed  ; initialize vertical speed and fractional
    STA ram_player_y_speed_fraction  ; movement force to stop player's vertical movement
    STA ram_stomp_chain_counter  ; initialize enemy stomp counter
bra_set_player_ground_state:
    LDA #$00
    STA ram_player_state  ; set player's state to normal

bra_check_player_side_metatiles:
    LDY $eb  ; get block buffer adder offset
    INY
    INY  ; increment offset 2 bytes to use adders for side collisions
    LDA #$02  ; set value here to be used as counter
    STA $00

bra_check_player_side_metatiles_loop:
    INY  ; move onto the next one
    STY $eb  ; store it
    LDA ram_player_y_position
    CMP #$20  ; check player's vertical position
    BCC bra_check_lower_player_side  ; if player is in status bar area, branch ahead to skip this part
    CMP #$e4
    BCS bra_exit_player_side_collision  ; branch to leave if player is too far down
    JSR sub_check_player_side_block_buffer  ; do player-to-bg collision detection on one half of player
    BEQ bra_check_lower_player_side  ; branch ahead if nothing found
    CMP #$1c  ; otherwise check for pipe metatiles
    BEQ bra_check_lower_player_side  ; if collided with sideways pipe (top), branch ahead
    CMP #$6b
    BEQ bra_check_lower_player_side  ; if collided with water pipe (top), branch ahead
    JSR sub_check_climbable_metatiles  ; do sub to see if player bumped into anything climbable
    BCC bra_handle_player_side_metatile  ; if not, branch to alternate section of code
bra_check_lower_player_side:
    LDY $eb  ; load block adder offset
    INY  ; increment it
    LDA ram_player_y_position  ; get player's vertical position
    CMP #$08
    BCC bra_exit_player_side_collision  ; if too high, branch to leave
    CMP #$d0
    BCS bra_exit_player_side_collision  ; if too low, branch to leave
    JSR sub_check_player_side_block_buffer  ; do player-to-bg collision detection on other half of player
    BNE bra_handle_player_side_metatile  ; if something found, branch
    DEC $00  ; otherwise decrement counter
    BNE bra_check_player_side_metatiles_loop  ; run code until both sides of player are checked
bra_exit_player_side_collision:
    RTS  ; leave

bra_handle_player_side_metatile:
    JSR sub_check_invisible_metatiles  ; check for hidden or coin 1-up blocks
    BEQ bra_exit_player_side_metatile_check  ; branch to leave if either found
    JSR sub_check_climbable_metatiles  ; check for climbable metatiles
    BCC bra_continue_player_side_check  ; if not found, skip and continue with code
    JMP loc_handle_climbing_metatile  ; otherwise jump to handle climbing
bra_continue_player_side_check:
    JSR sub_check_coin_metatiles  ; check to see if player touched coin
    BCS loc_handle_coin_metatile  ; if so, execute code to erase coin and award to player 1 coin
    JSR sub_check_jumpspring_metatiles  ; check for jumpspring metatiles
    BCC bra_check_side_pipe_bottom  ; if not found, branch ahead to continue cude
    LDA ram_jumpspring_anim_ctrl  ; otherwise check jumpspring animation control
    BNE bra_exit_player_side_metatile_check  ; branch to leave if set
    JMP loc_stop_player_horizontal_movement  ; otherwise jump to impede player's movement
bra_check_side_pipe_bottom:
    LDY ram_player_state  ; get player's state
    CPY #$00  ; check for player's state set to normal
    BNE loc_stop_player_horizontal_movement  ; if not, branch to impede player's movement
    LDY ram_player_facing_dir  ; get player's facing direction
    DEY
    BNE loc_stop_player_horizontal_movement  ; if facing left, branch to impede movement
    CMP #$6c  ; otherwise check for pipe metatiles
    BEQ bra_start_side_pipe_entry  ; if collided with sideways pipe (bottom), branch
    CMP #$1f  ; if collided with water pipe (bottom), continue
    BNE loc_stop_player_horizontal_movement  ; otherwise branch to impede player's movement
bra_start_side_pipe_entry:
    LDA ram_player_spr_attrib  ; check player's attributes
    BNE bra_put_player_behind_pipe  ; if already set, branch, do not play sound again
    LDY #con_sfx_pipe_down_injury
    STY ram_square1_sound_queue  ; otherwise load pipedown/injury sound
bra_put_player_behind_pipe:
    ORA #%00100000
    STA ram_player_spr_attrib  ; set background priority bit in player attributes
    LDA ram_player_x_position
    AND #%00001111  ; get lower nybble of player's horizontal coordinate
    BEQ bra_check_pipe_entry_game_task  ; if at zero, branch ahead to skip this part
    LDY #$00  ; set default offset for timer setting data
    LDA ram_screen_left_page_loc  ; load page location for left side of screen
    BEQ bra_set_area_change_timer  ; if at page zero, use default offset
    INY  ; otherwise increment offset
bra_set_area_change_timer:
    LDA tbl_area_change_delays,y  ; set timer for change of area as appropriate
    STA ram_change_area_timer
bra_check_pipe_entry_game_task:
    LDA ram_game_engine_subroutine  ; get number of game engine routine running
    CMP #$07
    BEQ bra_exit_player_side_metatile_check  ; if running player entrance routine or
    CMP #$08  ; player control routine, go ahead and branch to leave
    BNE bra_exit_player_side_metatile_check
    LDA #$02
    STA ram_game_engine_subroutine  ; otherwise set sideways pipe entry routine to run
    RTS  ; and leave

; --------------------------------
; $02 - high nybble of vertical coordinate from block buffer
; $04 - low nybble of horizontal coordinate from block buffer
; $06-$07 - block buffer address

loc_stop_player_horizontal_movement:
    JSR sub_impede_player_move  ; stop player's movement
bra_exit_player_side_metatile_check:
    RTS  ; leave

tbl_area_change_delays:
.if con_revision_profile = con_revision_profile_pal
    .byte $85, $2b
.else
    .byte $a0, $34
.endif

loc_handle_coin_metatile:
    JSR sub_erase_coin_or_axe_metatile  ; do sub to erase coin metatile from block buffer
    INC ram_coin_tally_for1_ups  ; increment coin tally used for 1-up blocks
    JMP sub_give_one_coin  ; update coin amount and tally on the screen

loc_handle_axe_metatile:
    LDA #$00
    STA ram_oper_mode_task  ; reset secondary mode
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_mode_victory
.else
    LDA #$02
.endif
    STA ram_oper_mode  ; set primary mode to autoctrl mode
.if con_revision_profile = con_revision_profile_ann
    JSR sub_ann_load_player_physics
.endif
    LDA #$18
    STA ram_player_x_speed  ; set horizontal speed and continue to erase axe metatile
sub_erase_coin_or_axe_metatile:
    LDY $02  ; load vertical high nybble offset for block buffer
    LDA #$00  ; load blank metatile
    STA ($06),y  ; store to remove old contents from block buffer
    JMP sub_remove_coin_axe  ; update the screen accordingly

; --------------------------------
; $02 - high nybble of vertical coordinate from block buffer
; $04 - low nybble of horizontal coordinate from block buffer
; $06-$07 - block buffer address

tbl_climb_x_position_offsets:
    .byte $f9, $07

tbl_climb_page_offsets:
    .byte $ff, $00

tbl_flagpole_score_y_positions:
    .byte $18, $22, $50, $68, $90

loc_handle_climbing_metatile:
    LDY $04  ; check low nybble of horizontal coordinate returned from
    CPY #$06  ; collision detection routine against certain values, this
    BCC bra_exit_climbing_handler  ; makes actual physical part of vine or flagpole thinner
    CPY #$0a  ; than 16 pixels
    BCC bra_check_flagpole_metatile
bra_exit_climbing_handler:
    RTS  ; leave if too far left or too far right

bra_check_flagpole_metatile:
    CMP #$24  ; check climbing metatiles
    BEQ bra_handle_flagpole_collision  ; branch if flagpole ball found
    CMP #$25
    BNE bra_handle_vine_collision  ; branch to alternate code if flagpole shaft not found

bra_handle_flagpole_collision:
    LDA ram_game_engine_subroutine
    CMP #$05  ; check for end-of-level routine running
    BEQ loc_attach_player_to_vine  ; if running, branch to end of climbing code
    LDA #$01
    STA ram_player_facing_dir  ; set player's facing direction to right
    INC ram_scroll_lock  ; set scroll lock flag
    LDA ram_game_engine_subroutine
    CMP #$04  ; check for flagpole slide routine running
    BEQ bra_start_flagpole_routine  ; if running, branch to end of flagpole code here
    LDA #con_bullet_bill_cannon_var  ; load identifier for bullet bills (cannon variant)
    JSR sub_kill_enemies  ; get rid of them
    LDA #con_silence
    STA ram_event_music_queue  ; silence music
    LSR
    STA ram_flagpole_sound_queue  ; load flagpole sound into flagpole sound queue
    LDX #$04  ; start at end of vertical coordinate data
    LDA ram_player_y_position
    STA ram_flagpole_collision_y_pos  ; store player's vertical coordinate here to be used later

bra_select_flagpole_score_y_position:
    CMP tbl_flagpole_score_y_positions,x  ; compare with current vertical coordinate data
    BCS bra_store_flagpole_score_index  ; if player's => current, branch to use current offset
    DEX  ; otherwise decrement offset to use
    BNE bra_select_flagpole_score_y_position  ; do this until all data is checked (use last one if all checked)
bra_store_flagpole_score_index:
    STX ram_flagpole_score  ; store offset here to be used later
.if con_revision_profile = con_revision_profile_ann
    LDA ram_ann_coin_display_second_last_digit
    CMP ram_ann_coin_display_last_digit
    BNE bra_start_flagpole_routine
    CMP ram_ann_game_timer_last_digit
    BNE bra_start_flagpole_routine
    LDA #con_ann_flagpole_one_up_score
    STA ram_flagpole_score
.endif
bra_start_flagpole_routine:
    LDA #$04
    STA ram_game_engine_subroutine  ; set value to run flagpole slide routine
    JMP loc_attach_player_to_vine  ; jump to end of climbing code

bra_handle_vine_collision:
    CMP #$26  ; check for climbing metatile used on vines
    BNE loc_attach_player_to_vine
    LDA ram_player_y_position  ; check player's vertical coordinate
    CMP #$20  ; for being in status bar area
    BCS loc_attach_player_to_vine  ; branch if not that far up
    LDA #$01
    STA ram_game_engine_subroutine  ; otherwise set to run autoclimb routine next frame

loc_attach_player_to_vine:
    LDA #$03  ; set player state to climbing
    STA ram_player_state
    LDA #$00  ; nullify player's horizontal speed
    STA ram_player_x_speed  ; and fractional horizontal movement force
    STA ram_player_x_speed_fraction
.if con_revision_profile = con_revision_profile_vs
    LDA ram_enemy_x_position+5  ; sample the arcade collision actor slot
.else
    LDA ram_player_x_position  ; get player's horizontal coordinate
.endif
    SEC
    SBC ram_screen_left_x_pos  ; subtract from left side horizontal coordinate
.if con_revision_profile = con_revision_profile_vs
    CMP #$0a
.else
    CMP #$10
.endif
    BCS bra_align_player_x_to_vine  ; if 16 or more pixels difference, do not alter facing direction
    LDA #$02
    STA ram_player_facing_dir  ; otherwise force player to face left
bra_align_player_x_to_vine:
    LDY ram_player_facing_dir  ; get current facing direction, use as offset
    LDA $06  ; get low byte of block buffer address
    ASL
    ASL  ; move low nybble to high
    ASL
    ASL
    CLC
    ADC tbl_climb_x_position_offsets-1,y  ; add pixels depending on facing direction
    STA ram_player_x_position  ; store as player's horizontal coordinate
    LDA $06  ; get low byte of block buffer address again
    BNE bra_exit_player_vine_position  ; if not zero, branch
    LDA ram_screen_right_page_loc  ; load page location of right side of screen
    CLC
    ADC tbl_climb_page_offsets-1,y  ; add depending on facing location
    STA ram_player_page_loc  ; store as player's page location
bra_exit_player_vine_position:
    RTS  ; finally, we're done!

; --------------------------------

sub_check_invisible_metatiles:
.if con_revision_profile = con_revision_profile_ann
    CMP #con_ann_invisible_blank_metatile
    BEQ bra_return_invisible_metatile_test
.endif
    CMP #$5f  ; check for hidden coin block
    BEQ bra_return_invisible_metatile_test  ; branch to leave if found
    CMP #$60  ; check for hidden 1-up block
bra_return_invisible_metatile_test:
    RTS  ; leave with zero flag set if either found

; --------------------------------
; $00-$01 - used to hold bottom right and bottom left metatiles (in that order)
; $00 - used as flag by sub_impede_player_move to restrict specific movement

sub_check_jumpspring_landing:
    JSR sub_check_jumpspring_metatiles  ; do sub to check if player landed on jumpspring
    BCC bra_exit_jumpspring_landing_check  ; if carry not set, jumpspring not found, therefore leave
    LDA #$70
    STA ram_player_active_gravity  ; otherwise set vertical movement force for player
.if con_revision_profile = con_revision_profile_ann
    STA ram_player_fall_gravity
.endif
    LDA #con_jumpspring_collision_y_speed
    STA ram_jumpspring_force  ; set default jumpspring force
    LDA #$03
    STA ram_jumpspring_timer  ; set jumpspring timer to be used later
    LSR
    STA ram_jumpspring_anim_ctrl  ; set jumpspring animation control to start animating
bra_exit_jumpspring_landing_check:
    RTS  ; and leave

sub_check_jumpspring_metatiles:
    CMP #$67  ; check for top jumpspring metatile
    BEQ bra_return_jumpspring_metatile_found  ; branch to set carry if found
    CMP #$68  ; check for bottom jumpspring metatile
    CLC  ; clear carry flag
    BNE bra_return_no_jumpspring_metatile  ; branch to use cleared carry if not found
bra_return_jumpspring_metatile_found:
    SEC  ; set carry if found
bra_return_no_jumpspring_metatile:
    RTS  ; leave

sub_handle_pipe_entry:
    LDA ram_up_down_buttons  ; check saved controller bits from earlier
    AND #%00000100  ; for pressing down
    BEQ bra_exit_pipe_entry_check  ; if not pressing down, branch to leave
    LDA $00
    CMP #$11  ; check right foot metatile for warp pipe right metatile
    BNE bra_exit_pipe_entry_check  ; branch to leave if not found
    LDA $01
    CMP #$10  ; check left foot metatile for warp pipe left metatile
    BNE bra_exit_pipe_entry_check  ; branch to leave if not found
    LDA #con_pipe_transition_timer
    STA ram_change_area_timer  ; set timer for change of area
    LDA #$03
    STA ram_game_engine_subroutine  ; set to run vertical pipe entry routine on next frame
    LDA #con_sfx_pipe_down_injury
    STA ram_square1_sound_queue  ; load pipedown/injury sound
    LDA #%00100000
    STA ram_player_spr_attrib  ; set background priority bit in player's attributes
    LDA ram_warp_zone_control  ; check warp zone control
    BEQ bra_exit_pipe_entry_check  ; branch to leave if none found
.if con_revision_profile = con_revision_profile_ann
    AND #%00000111
.else
    AND #%00000011  ; mask out all but 2 LSB
.endif
    ASL
    ASL  ; multiply by four
    TAX  ; save as offset to warp zone numbers (starts at left pipe)
    LDA ram_player_x_position  ; get player's horizontal position
    CMP #$60
    BCC bra_select_warp_zone_world  ; if player at left, not near middle, use offset and skip ahead
    INX  ; otherwise increment for middle pipe
    CMP #$a0
    BCC bra_select_warp_zone_world  ; if player at middle, but not too far right, use offset and skip
    INX  ; otherwise increment for last pipe
bra_select_warp_zone_world:
.if con_revision_profile = con_revision_profile_ann
    LDA tbl_warp_zone_number_tiles,x
    LDY ram_ann_hard_mode
    BEQ bra_store_ann_warp_zone_world
    SEC
    SBC #$09
bra_store_ann_warp_zone_world:
    TAY
.else
    LDY tbl_warp_zone_number_tiles,x  ; get warp zone numbers
.endif
    DEY  ; decrement for use as world number
    STY ram_world_number  ; store as world number and offset
    LDX tbl_world_area_pointer_offsets,y  ; get offset to where this world's area offsets are
    LDA tbl_area_pointers,x  ; get area offset based on world offset
    STA ram_area_pointer  ; store area offset here to be used to change areas
    LDA #con_silence
    STA ram_event_music_queue  ; silence music
    LDA #$00
    STA ram_entrance_page  ; initialize starting page number
    STA ram_area_number  ; initialize area number used for area address offset
    STA ram_level_number  ; initialize level number used for world display
    STA ram_alt_entrance_control  ; initialize mode of entry
.if con_revision_profile <> con_revision_profile_vs
    INC ram_hidden1_up_flag  ; set flag for hidden 1-up blocks
.endif
    INC ram_fetch_new_game_timer_flag  ; set flag to load new game timer
bra_exit_pipe_entry_check:
    RTS  ; leave!!!

sub_impede_player_move:
    LDA #$00  ; initialize value here
    LDY ram_player_x_speed  ; get player's horizontal speed
    LDX $00  ; check value set earlier for
    DEX  ; left side collision
    BNE bra_impede_player_right  ; if right side collision, skip this part
    INX  ; return value to X
    CPY #$00  ; if player moving to the left,
    BMI bra_exit_impede_player_move  ; branch to invert bit and leave
    LDA #$ff  ; otherwise load A with value to be used later
    JMP loc_clear_player_x_speed  ; and jump to affect movement
bra_impede_player_right:
    LDX #$02  ; return $02 to X
    CPY #$01  ; if player moving to the right,
    BPL bra_exit_impede_player_move  ; branch to invert bit and leave
    LDA #$01  ; otherwise load A with value to be used here
loc_clear_player_x_speed:
    LDY #$10
    STY ram_side_collision_timer  ; set timer of some sort
    LDY #$00
    STY ram_player_x_speed  ; nullify player's horizontal speed
    CMP #$00  ; if value set in A not set to $ff,
    BPL bra_apply_platform_collision_force  ; branch ahead, do not decrement Y
    DEY  ; otherwise decrement Y now
bra_apply_platform_collision_force:
    STY $00  ; store Y as high bits of horizontal adder
    CLC
    ADC ram_player_x_position  ; add contents of A to player's horizontal
    STA ram_player_x_position  ; position to move player left or right
    LDA ram_player_page_loc
    ADC $00  ; add high bits and carry to
    STA ram_player_page_loc  ; page location if necessary
bra_exit_impede_player_move:
    TXA  ; invert contents of X
    EOR #$ff
    AND ram_player_collision_bits  ; mask out bit that was set here
    STA ram_player_collision_bits  ; store to clear bit
    RTS

; --------------------------------

tbl_solid_metatile_range_upper_bounds:
    .byte $10, $61, $88, $c4

sub_check_solid_metatiles:
    JSR sub_get_metatile_attributes  ; find appropriate offset based on metatile's 2 MSB
    CMP tbl_solid_metatile_range_upper_bounds,x  ; compare current metatile with solid metatiles
    RTS

tbl_climbable_metatile_range_upper_bounds:
    .byte $24, $6d, $8a, $c6

sub_check_climbable_metatiles:
    JSR sub_get_metatile_attributes  ; find appropriate offset based on metatile's 2 MSB
    CMP tbl_climbable_metatile_range_upper_bounds,x  ; compare current metatile with climbable metatiles
    RTS

sub_check_coin_metatiles:
    CMP #$c2  ; check for regular coin
    BEQ bra_return_coin_metatile_found  ; branch if found
    CMP #$c3  ; check for underwater coin
    BEQ bra_return_coin_metatile_found  ; branch if found
    CLC  ; otherwise clear carry and leave
    RTS
bra_return_coin_metatile_found:
    LDA #con_sfx_coin_grab
    STA ram_square2_sound_queue  ; load coin grab sound and leave
    RTS

sub_get_metatile_attributes:
    TAY  ; save metatile value into Y
    AND #%11000000  ; mask out all but 2 MSB
    ASL
    ROL  ; shift and rotate d7-d6 to d1-d0
    ROL
    TAX  ; use as offset for metatile data
    TYA  ; get original metatile value back
bra_exit_player_background_metatile_lookup:
    RTS  ; leave
