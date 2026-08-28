; -------------------------------------------------------------------------------------
; $00 - used to hold collision flag, Y movement force + 5 or low byte of name table for rope
; $01 - used to hold high byte of name table for rope
; $02 - used to hold page location of rope

handler_move_balance_platform:
    LDA ram_enemy_y_high_pos,x  ; check high byte of vertical position
    CMP #$03
    BNE bra_check_balance_platform_state
    JMP sub_erase_enemy_object  ; if far below screen, kill the object
bra_check_balance_platform_state:
    LDA ram_enemy_state,x  ; get object's state (set to $ff or other platform offset)
    BPL bra_update_balance_platform_pair  ; if doing other balance platform, branch to leave
    RTS

bra_update_balance_platform_pair:
    TAY  ; save offset from state as Y
    LDA ram_platform_collision_flag,x  ; get collision flag of platform
    STA $00  ; store here
    LDA ram_enemy_moving_dir,x  ; get moving direction
    BEQ bra_check_current_balance_platform_fall
    JMP loc_fall_balance_platform_pair  ; if set, jump here

bra_check_current_balance_platform_fall:
    LDA #$2d  ; check if platform is above a certain point
    CMP ram_enemy_y_position,x
    BCC bra_check_other_balance_platform_fall  ; if not, branch elsewhere
    CPY $00  ; if collision flag is set to same value as
    BEQ bra_begin_balance_platform_fall  ; enemy state, branch to make platforms fall
    CLC
    ADC #$02  ; otherwise add 2 pixels to vertical position
    STA ram_enemy_y_position,x  ; of current platform and branch elsewhere
    JMP sub_stop_platforms  ; to make platforms stop

bra_begin_balance_platform_fall:
    JMP loc_initialize_balance_platform_fall  ; make platforms fall

bra_check_other_balance_platform_fall:
    CMP ram_enemy_y_position,y  ; check if other platform is above a certain point
    BCC bra_move_balance_platform_pair  ; if not, branch elsewhere
    CPX $00  ; if collision flag is set to same value as
    BEQ bra_begin_balance_platform_fall  ; enemy state, branch to make platforms fall
    CLC
    ADC #$02  ; otherwise add 2 pixels to vertical position
    STA ram_enemy_y_position,y  ; of other platform and branch elsewhere
    JMP sub_stop_platforms  ; jump to stop movement and do not return

bra_move_balance_platform_pair:
    LDA ram_enemy_y_position,x  ; save vertical position to stack
    PHA
    LDA ram_platform_collision_flag,x  ; get collision flag
    BPL bra_handle_balance_platform_collision  ; branch if collision
    LDA ram_enemy_y_move_force,x
    CLC  ; add $05 to contents of moveforce, whatever they be
    ADC #$05
    STA $00  ; store here
    LDA ram_enemy_y_speed,x
    ADC #$00  ; add carry to vertical speed
    BMI bra_move_balance_platform_down  ; branch if moving downwards
    BNE bra_move_balance_platform_up  ; branch elsewhere if moving upwards
    LDA $00
    CMP #$0b  ; check if there's still a little force left
    BCC bra_stop_balance_platforms  ; if not enough, branch to stop movement
    BCS bra_move_balance_platform_up  ; otherwise keep branch to move upwards
bra_handle_balance_platform_collision:
    CMP ram_object_offset  ; if collision flag matches
    BEQ bra_move_balance_platform_down  ; current enemy object offset, branch
bra_move_balance_platform_up:
    JSR sub_move_platform_up  ; do a sub to move upwards
    JMP loc_move_other_balance_platform  ; jump ahead to remaining code
bra_stop_balance_platforms:
    JSR sub_stop_platforms  ; do a sub to stop movement
    JMP loc_move_other_balance_platform  ; jump ahead to remaining code
bra_move_balance_platform_down:
    JSR sub_move_platform_down  ; do a sub to move downwards

loc_move_other_balance_platform:
    LDY ram_enemy_state,x  ; get offset of other platform
    PLA  ; get old vertical coordinate from stack
    SEC
    SBC ram_enemy_y_position,x  ; get difference of old vs. new coordinate
    CLC
    ADC ram_enemy_y_position,y  ; add difference to vertical coordinate of other
    STA ram_enemy_y_position,y  ; platform to move it in the opposite direction
    LDA ram_platform_collision_flag,x  ; if no collision, skip this part here
    BMI bra_update_balance_platform_rope
    TAX  ; put offset which collision occurred here
    JSR sub_position_player_on_vertical_platform  ; and use it to position player accordingly

bra_update_balance_platform_rope:
    LDY ram_object_offset  ; get enemy object offset
    LDA ram_enemy_y_speed,y  ; check to see if current platform is
    ORA ram_enemy_y_move_force,y  ; moving at all
    BEQ bra_exit_platform_rope_update  ; if not, skip all of this and branch to leave
    LDX ram_vram_buffer1_offset  ; get vram buffer offset
    CPX #$20  ; if offset beyond a certain point, go ahead
    BCS bra_exit_platform_rope_update  ; and skip this, branch to leave
    LDA ram_enemy_y_speed,y
    PHA  ; save two copies of vertical speed to stack
    PHA
    JSR sub_setup_platform_rope  ; do a sub to figure out where to put new bg tiles
    LDA $01  ; write name table address to vram buffer
    STA ram_vram_buffer1,x  ; first the high byte, then the low
    LDA $00
    STA ram_vram_buffer1+1,x
    LDA #$02  ; set length for 2 bytes
    STA ram_vram_buffer1+2,x
    LDA ram_enemy_y_speed,y  ; if platform moving upwards, branch
    BMI bra_erase_current_platform_rope  ; to do something else
    LDA #$a2
    STA ram_vram_buffer1+3,x  ; otherwise put tile numbers for left
    LDA #$a3  ; and right sides of rope in vram buffer
    STA ram_vram_buffer1+4,x
    JMP loc_update_other_platform_rope  ; jump to skip this part
bra_erase_current_platform_rope:
    LDA #$24  ; put blank tiles in vram buffer
    STA ram_vram_buffer1+3,x  ; to erase rope
    STA ram_vram_buffer1+4,x

loc_update_other_platform_rope:
    LDA ram_enemy_state,y  ; get offset of other platform from state
    TAY  ; use as Y here
    PLA  ; pull second copy of vertical speed from stack
    EOR #$ff  ; invert bits to reverse speed
    JSR sub_setup_platform_rope  ; do sub again to figure out where to put bg tiles
    LDA $01  ; write name table address to vram buffer
    STA ram_vram_buffer1+5,x  ; this time we're doing putting tiles for
    LDA $00  ; the other platform
    STA ram_vram_buffer1+6,x
    LDA #$02
    STA ram_vram_buffer1+7,x  ; set length again for 2 bytes
    PLA  ; pull first copy of vertical speed from stack
    BPL bra_erase_other_platform_rope  ; if moving upwards (note inversion earlier), skip this
    LDA #$a2
    STA ram_vram_buffer1+8,x  ; otherwise put tile numbers for left
    LDA #$a3  ; and right sides of rope in vram
    STA ram_vram_buffer1+9,x  ; transfer buffer
    JMP loc_finish_platform_rope_packet  ; jump to skip this part
bra_erase_other_platform_rope:
    LDA #$24  ; put blank tiles in vram buffer
    STA ram_vram_buffer1+8,x  ; to erase rope
    STA ram_vram_buffer1+9,x
loc_finish_platform_rope_packet:
    LDA #$00  ; put null terminator at the end
    STA ram_vram_buffer1+10,x
    LDA ram_vram_buffer1_offset  ; add ten bytes to the vram buffer offset
    CLC  ; and store
    ADC #10
    STA ram_vram_buffer1_offset
bra_exit_platform_rope_update:
    LDX ram_object_offset  ; get enemy object buffer offset and leave
    RTS

sub_setup_platform_rope:
    PHA  ; save second/third copy to stack
    LDA ram_enemy_x_position,y  ; get horizontal coordinate
    CLC
    ADC #$08  ; add eight pixels
    LDX ram_secondary_hard_mode  ; if secondary hard mode flag set,
    BNE bra_use_platform_rope_x_position  ; use coordinate as-is
    CLC
    ADC #$10  ; otherwise add sixteen more pixels
bra_use_platform_rope_x_position:
    PHA  ; save modified horizontal coordinate to stack
    LDA ram_enemy_page_loc,y
    ADC #$00  ; add carry to page location
    STA $02  ; and save here
    PLA  ; pull modified horizontal coordinate
    AND #%11110000  ; from the stack, mask out low nybble
    LSR  ; and shift three bits to the right
    LSR
    LSR
    STA $00  ; store result here as part of name table low byte
    LDX ram_enemy_y_position,y  ; get vertical coordinate
    PLA  ; get second/third copy of vertical speed from stack
    BPL bra_calculate_platform_rope_vram_address  ; skip this part if moving downwards or not at all
    TXA
    CLC
    ADC #$08  ; add eight to vertical coordinate and
    TAX  ; save as X
bra_calculate_platform_rope_vram_address:
    TXA  ; move vertical coordinate to A
    LDX ram_vram_buffer1_offset  ; get vram buffer offset
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
    LDA ram_enemy_y_position,y
    CMP #$e8  ; if vertical position not below the
    BCC bra_exit_platform_rope_address_setup  ; bottom of the screen, we're done, branch to leave
    LDA $00
    AND #%10111111  ; mask out d6 of low byte of name table address
    STA $00
bra_exit_platform_rope_address_setup:
    RTS  ; leave!

loc_initialize_balance_platform_fall:
    TYA  ; move offset of other platform from Y to X
    TAX
    JSR sub_get_enemy_offscreen_bits  ; get offscreen bits
    LDA #$06
    JSR sub_setup_floatey_number  ; award 1000 points to player
    LDA ram_player_rel_x_pos
    STA ram_floatey_num_x_pos,x  ; put floatey number coordinates where player is
    LDA ram_player_y_position
    STA ram_floatey_num_y_pos,x
    LDA #$01  ; set moving direction as flag for
    STA ram_enemy_moving_dir,x  ; falling platforms

sub_stop_platforms:
    JSR sub_clear_enemy_vertical_motion  ; initialize vertical speed and low byte
    STA ram_enemy_y_speed,y  ; for both platforms and leave
    STA ram_enemy_y_move_force,y
    RTS

loc_fall_balance_platform_pair:
    TYA  ; save offset for other platform to stack
    PHA
    JSR sub_move_falling_platform  ; make current platform fall
    PLA
    TAX  ; pull offset from stack and save to X
    JSR sub_move_falling_platform  ; make other platform fall
    LDX ram_object_offset
    LDA ram_platform_collision_flag,x  ; if player not standing on either platform,
    BMI bra_exit_balance_platform_fall  ; skip this part
    TAX  ; transfer collision flag offset as offset to X
    JSR sub_position_player_on_vertical_platform  ; and position player appropriately
bra_exit_balance_platform_fall:
    LDX ram_object_offset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------

handler_move_vertical_platform:
    LDA ram_enemy_y_speed,x  ; if platform moving up or down, skip ahead to
    ORA ram_enemy_y_move_force,x  ; check on other position
    BNE bra_select_vertical_platform_direction
    STA ram_enemy_ymf_dummy,x  ; initialize dummy variable
    LDA ram_enemy_y_position,x
    CMP ram_y_platform_top_y_pos,x  ; if current vertical position => top position, branch
    BCS bra_select_vertical_platform_direction  ; ahead of all this
    LDA ram_frame_counter
    AND #%00000111  ; check for every eighth frame
    BNE bra_finish_idle_vertical_platform_adjustment
    INC ram_enemy_y_position,x  ; increase vertical position every eighth frame
bra_finish_idle_vertical_platform_adjustment:
    JMP loc_position_player_on_vertical_platform  ; skip ahead to last part

bra_select_vertical_platform_direction:
    LDA ram_enemy_y_position,x  ; if current vertical position < central position, branch
    CMP ram_y_platform_center_y_pos,x  ; to slow ascent/move downwards
    BCC bra_move_vertical_platform_down
    JSR sub_move_platform_up  ; otherwise start slowing descent/moving upwards
    JMP loc_position_player_on_vertical_platform
bra_move_vertical_platform_down:
    JSR sub_move_platform_down  ; start slowing ascent/moving downwards

loc_position_player_on_vertical_platform:
    LDA ram_platform_collision_flag,x  ; if collision flag not set here, branch
    BMI bra_exit_vertical_platform  ; to leave
    JSR sub_position_player_on_vertical_platform  ; otherwise position player appropriately
bra_exit_vertical_platform:
    RTS  ; leave

; --------------------------------
; $00 - used as adder to position player hotizontally

handler_move_horizontal_platform:
    LDA #$0e  ; load preset maximum value for secondary counter
    JSR sub_update_platform_x_movement_counters  ; do a sub to increment counters for movement
    JSR sub_move_with_x_movement_counters  ; do a sub to move platform accordingly, and return value
    LDA ram_platform_collision_flag,x  ; if no collision with player,
    BMI bra_exit_horizontal_platform  ; branch ahead to leave

sub_position_player_on_horizontal_platform:
    LDA ram_player_x_position
    CLC  ; add saved value from second subroutine to
    ADC $00  ; current player's position to position
    STA ram_player_x_position  ; player accordingly in horizontal position
    LDA ram_player_page_loc  ; get player's page location
    LDY $00  ; check to see if saved value here is positive or negative
    BMI bra_adjust_player_page_for_left_platform_motion  ; if negative, branch to subtract
    ADC #$00  ; otherwise add carry to page location
    JMP loc_store_horizontal_platform_effect  ; jump to skip subtraction
bra_adjust_player_page_for_left_platform_motion:
    SBC #$00  ; subtract borrow from page location
loc_store_horizontal_platform_effect:
    STA ram_player_page_loc  ; save result to player's page location
    STY ram_platform_x_scroll  ; put saved value from second sub here to be used later
    JSR sub_position_player_on_vertical_platform  ; position player vertically and appropriately
bra_exit_horizontal_platform:
    RTS  ; and we are done here

; --------------------------------

handler_move_drop_platform:
    LDA ram_platform_collision_flag,x  ; if no collision between platform and player
    BMI bra_exit_drop_platform  ; occurred, just leave without moving anything
    JSR sub_move_drop_platform  ; otherwise do a sub to move platform down very quickly
    JSR sub_position_player_on_vertical_platform  ; do a sub to position player appropriately
bra_exit_drop_platform:
    RTS  ; leave

; --------------------------------
; $00 - residual value from sub

handler_move_right_platform:
    JSR sub_move_enemy_horizontally  ; move platform with current horizontal speed, if any
    STA $00  ; store saved value here (residual code)
    LDA ram_platform_collision_flag,x  ; check collision flag, if no collision between player
    BMI bra_exit_right_moving_platform  ; and platform, branch ahead, leave speed unaltered
    LDA #con_right_platform_x_speed
    STA ram_enemy_x_speed,x  ; otherwise set new speed (gets moving if motionless)
    JSR sub_position_player_on_horizontal_platform  ; use saved value from earlier sub to position player
bra_exit_right_moving_platform:
    RTS  ; then leave

; --------------------------------

handler_move_large_lift_platform:
    JSR sub_move_lift_platforms  ; execute common to all large and small lift platforms
    JMP loc_position_player_on_vertical_platform  ; branch to position player correctly

sub_move_small_platform:
    JSR sub_move_lift_platforms  ; execute common to all large and small lift platforms
    JMP loc_check_small_platform_collision  ; branch to position player correctly

sub_move_lift_platforms:
    LDA ram_timer_control  ; if master timer control set, skip all of this
    BNE bra_exit_lift_platform  ; and branch to leave
    LDA ram_enemy_ymf_dummy,x
    CLC  ; add contents of movement amount to whatever's here
    ADC ram_enemy_y_move_force,x
    STA ram_enemy_ymf_dummy,x
    LDA ram_enemy_y_position,x  ; add whatever vertical speed is set to current
    ADC ram_enemy_y_speed,x  ; vertical position plus carry to move up or down
    STA ram_enemy_y_position,x  ; and then leave
    RTS

loc_check_small_platform_collision:
    LDA ram_platform_collision_flag,x  ; get bounding box counter saved in collision flag
    BEQ bra_exit_lift_platform  ; if none found, leave player position alone
    JSR sub_position_player_on_small_platform  ; use to position player correctly
bra_exit_lift_platform:
    RTS  ; then leave

; -------------------------------------------------------------------------------------
; $00 - page location of extended left boundary
; $01 - extended left boundary position
; $02 - page location of extended right boundary
; $03 - extended right boundary position

sub_offscreen_bounds_check:
    LDA ram_enemy_id,x  ; check for cheep-cheep object
    CMP #con_flying_cheep_cheep  ; branch to leave if found
    BEQ bra_exit_offscreen_bounds_check
    LDA ram_screen_left_x_pos  ; get horizontal coordinate for left side of screen
    LDY ram_enemy_id,x
    CPY #con_hammer_bro  ; check for hammer bro object
    BEQ bra_limit_left_offscreen_bound
    CPY #con_piranha_plant  ; check for piranha plant object
    BNE bra_extend_left_offscreen_bound  ; these two will be erased sooner than others if too far left
bra_limit_left_offscreen_bound:
    ADC #$38  ; add 56 pixels to coordinate if hammer bro or piranha plant
bra_extend_left_offscreen_bound:
    SBC #$48  ; subtract 72 pixels regardless of enemy object
    STA $01  ; store result here
    LDA ram_screen_left_page_loc
    SBC #$00  ; subtract borrow from page location of left side
    STA $00  ; store result here
    LDA ram_screen_right_x_pos  ; add 72 pixels to the right side horizontal coordinate
    ADC #$48
    STA $03  ; store result here
    LDA ram_screen_right_page_loc
    ADC #$00  ; then add the carry to the page location
    STA $02  ; and store result here
    LDA ram_enemy_x_position,x  ; compare horizontal coordinate of the enemy object
    CMP $01  ; to modified horizontal left edge coordinate to get carry
    LDA ram_enemy_page_loc,x
    SBC $00  ; then subtract it from the page coordinate of the enemy object
    BMI bra_erase_far_offscreen_enemy  ; if enemy object is too far left, branch to erase it
    LDA ram_enemy_x_position,x  ; compare horizontal coordinate of the enemy object
    CMP $03  ; to modified horizontal right edge coordinate to get carry
    LDA ram_enemy_page_loc,x
    SBC $02  ; then subtract it from the page coordinate of the enemy object
    BMI bra_exit_offscreen_bounds_check  ; if enemy object is on the screen, leave, do not erase enemy
    LDA ram_enemy_state,x  ; if at this point, enemy is offscreen to the right, so check
    CMP #con_hammer_bro  ; if in state used by spiny's egg, do not erase
    BEQ bra_exit_offscreen_bounds_check
    CPY #con_piranha_plant  ; if piranha plant, do not erase
    BEQ bra_exit_offscreen_bounds_check
    CPY #con_flagpole_flag_object  ; if flagpole flag, do not erase
    BEQ bra_exit_offscreen_bounds_check
    CPY #con_star_flag_object  ; if star flag, do not erase
    BEQ bra_exit_offscreen_bounds_check
    CPY #con_jumpspring_object  ; if jumpspring, do not erase
    BEQ bra_exit_offscreen_bounds_check  ; erase all others too far to the right
bra_erase_far_offscreen_enemy:
    JSR sub_erase_enemy_object  ; erase object if necessary
bra_exit_offscreen_bounds_check:
    RTS  ; leave

; -------------------------------------------------------------------------------------

; some unused space
.if con_revision_profile = con_revision_profile_pal
    .res 56, $ff
.endif
.if con_revision_profile <> con_revision_profile_vs .and con_revision_profile <> con_revision_profile_fds_smb
    .byte $ff, $ff, $ff
.endif
