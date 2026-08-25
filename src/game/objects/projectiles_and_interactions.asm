; -------------------------------------------------------------------------------------
; $00 - used to store downward movement force in sub_process_fireball_object
; $02 - used to store maximum vertical speed in sub_process_fireball_object
; $07 - used to store pseudorandom bit in sub_bubble_check

sub_process_fireballs_and_bubbles:
    LDA ram_player_status  ; check player's status
    CMP #$02
    BCC bra_process_air_bubble_slots  ; if not fiery, branch
    LDA ram_a_b_buttons
    AND #con_btn_b  ; check for b button pressed
    BEQ bra_process_fireball_slots  ; branch if not pressed
    AND ram_previous_a_b_buttons
    BNE bra_process_fireball_slots  ; if button pressed in previous frame, branch
    LDA ram_fireball_counter  ; load fireball counter
    AND #%00000001  ; get LSB and use as offset for buffer
    TAX
    LDA ram_fireball_state,x  ; load fireball state
    BNE bra_process_fireball_slots  ; if not inactive, branch
    LDY ram_player_y_high_pos  ; if player too high or too low, branch
    DEY
    BNE bra_process_fireball_slots
    LDA ram_crouching_flag  ; if player crouching, branch
    BNE bra_process_fireball_slots
    LDA ram_player_state  ; if player's state = climbing, branch
    CMP #$03
    BEQ bra_process_fireball_slots
    LDA #con_sfx_fireball  ; play fireball sound effect
    STA ram_square1_sound_queue
    LDA #$02  ; load state
    STA ram_fireball_state,x
    LDY ram_player_anim_timer_reload  ; copy animation frame timer setting
    STY ram_fireball_throwing_timer  ; into fireball throwing timer
    DEY
    STY ram_player_anim_timer  ; decrement and store in player's animation timer
    INC ram_fireball_counter  ; increment fireball counter

bra_process_fireball_slots:
    LDX #$00
    JSR sub_process_fireball_object  ; process first fireball object
    LDX #$01
    JSR sub_process_fireball_object  ; process second fireball object, then do air bubbles

bra_process_air_bubble_slots:
    LDA ram_area_type  ; if not water type level, skip the rest of this
    BNE bra_exit_bubble_processing
    LDX #$02  ; otherwise load counter and use as offset
bra_process_bubble_slots:
    STX ram_object_offset  ; store offset
    JSR sub_bubble_check  ; check timers and coordinates, create air bubble
    JSR sub_relative_bubble_position  ; get relative coordinates
    JSR sub_get_bubble_offscreen_bits  ; get offscreen information
    JSR sub_draw_bubble  ; draw the air bubble
    DEX
    BPL bra_process_bubble_slots  ; do this until all three are handled
bra_exit_bubble_processing:
    RTS  ; then leave

tbl_fireball_x_speeds:
    .byte $40, $c0

sub_process_fireball_object:
    STX ram_object_offset  ; store offset as current object
    LDA ram_fireball_state,x  ; check for d7 = 1
    ASL
    BCS bra_process_fireball_explosion  ; if so, branch to get relative coordinates and draw explosion
    LDY ram_fireball_state,x  ; if fireball inactive, branch to leave
    BEQ bra_skip_inactive_fireball
    DEY  ; if fireball state set to 1, skip this part and just run it
    BEQ bra_update_active_fireball
    LDA ram_player_x_position  ; get player's horizontal position
    ADC #$04  ; add four pixels and store as fireball's horizontal position
    STA ram_fireball_x_position,x
    LDA ram_player_page_loc  ; get player's page location
    ADC #$00  ; add carry and store as fireball's page location
    STA ram_fireball_page_loc,x
    LDA ram_player_y_position  ; get player's vertical position and store
    STA ram_fireball_y_position,x
    LDA #$01  ; set high byte of vertical position
    STA ram_fireball_y_high_pos,x
    LDY ram_player_facing_dir  ; get player's facing direction
    DEY  ; decrement to use as offset here
    LDA tbl_fireball_x_speeds,y  ; set horizontal speed of fireball accordingly
    STA ram_fireball_x_speed,x
    LDA #$04  ; set vertical speed of fireball
    STA ram_fireball_y_speed,x
    LDA #$07
    STA ram_fireball_bound_box_ctrl,x  ; set bounding box size control for fireball
    DEC ram_fireball_state,x  ; decrement state to 1 to skip this part from now on
bra_update_active_fireball:
    TXA  ; add 7 to offset to use
    CLC  ; as fireball offset for next routines
    ADC #$07
    TAX
    LDA #$50  ; set downward movement force here
    STA $00
    LDA #$03  ; set maximum speed here
    STA $02
    LDA #$00
    JSR sub_apply_object_gravity  ; do sub here to impose gravity on fireball and move vertically
    JSR sub_move_object_horizontally  ; do another sub to move it horizontally
    LDX ram_object_offset  ; return fireball offset to X
    JSR sub_relative_fireball_position  ; get relative coordinates
    JSR sub_get_fireball_offscreen_bits  ; get offscreen information
    JSR sub_get_fireball_bound_box  ; get bounding box coordinates
    JSR sub_handle_fireball_background_collision  ; do fireball to background collision detection
    LDA ram_f_ball_offscreen_bits  ; get fireball offscreen bits
    AND #%11001100  ; mask out certain bits
    BNE bra_erase_fireball  ; if any bits still set, branch to kill fireball
    JSR sub_fireball_enemy_collision  ; do fireball to enemy collision detection and deal with collisions
    JMP loc_draw_fireball  ; draw fireball appropriately and leave
bra_erase_fireball:
    LDA #$00  ; erase fireball state
    STA ram_fireball_state,x
bra_skip_inactive_fireball:
    RTS  ; leave

bra_process_fireball_explosion:
    JSR sub_relative_fireball_position
    JMP loc_draw_fireball_explosion

sub_bubble_check:
    LDA ram_pseudo_random_bit_reg+1,x  ; get part of LSFR
    AND #$01
    STA $07  ; store pseudorandom bit here
    LDA ram_bubble_y_position,x  ; get vertical coordinate for air bubble
    CMP #$f8  ; if offscreen coordinate not set,
    BNE bra_move_air_bubble  ; branch to move air bubble
    LDA ram_air_bubble_timer  ; if air bubble timer not expired,
    BNE bra_exit_bubble_motion  ; branch to leave, otherwise create new air bubble

sub_setup_bubble:
    LDY #$00  ; load default value here
    LDA ram_player_facing_dir  ; get player's facing direction
    LSR  ; move d0 to carry
    BCC bra_position_bubble  ; branch to use default value if facing left
    LDY #$08  ; otherwise load alternate value here
bra_position_bubble:
    TYA  ; use value loaded as adder
    ADC ram_player_x_position  ; add to player's horizontal position
    STA ram_bubble_x_position,x  ; save as horizontal position for airbubble
    LDA ram_player_page_loc
    ADC #$00  ; add carry to player's page location
    STA ram_bubble_page_loc,x  ; save as page location for airbubble
    LDA ram_player_y_position
    CLC  ; add eight pixels to player's vertical position
    ADC #$08
    STA ram_bubble_y_position,x  ; save as vertical position for air bubble
    LDA #$01
    STA ram_bubble_y_high_pos,x  ; set vertical high byte for air bubble
    LDY $07  ; get pseudorandom bit, use as offset
    LDA tbl_air_bubble_spawn_delays,y  ; get data for air bubble timer
    STA ram_air_bubble_timer  ; set air bubble timer
bra_move_air_bubble:
    LDY $07  ; get pseudorandom bit again, use as offset
    LDA ram_bubble_ymf_dummy,x
    SEC  ; subtract pseudorandom amount from dummy variable
    SBC tbl_air_bubble_y_force_adjustments,y
    STA ram_bubble_ymf_dummy,x  ; save dummy variable
    LDA ram_bubble_y_position,x
    SBC #$00  ; subtract borrow from airbubble's vertical coordinate
    CMP #$20  ; if below the status bar,
    BCS bra_move_air_bubble_vertically  ; branch to go ahead and use to move air bubble upwards
    LDA #$f8  ; otherwise set offscreen coordinate
bra_move_air_bubble_vertically:
    STA ram_bubble_y_position,x  ; store as new vertical coordinate for air bubble
bra_exit_bubble_motion:
    RTS  ; leave

tbl_air_bubble_y_force_adjustments:
    .byte $ff, $50

tbl_air_bubble_spawn_delays:
    .byte $40, $20

; -------------------------------------------------------------------------------------

sub_run_game_timer:
    LDA ram_oper_mode  ; get primary mode of operation
    BEQ bra_exit_game_timer  ; branch to leave if in title screen mode
    LDA ram_game_engine_subroutine
    CMP #$08  ; if routine number less than eight running,
    BCC bra_exit_game_timer  ; branch to leave
    CMP #$0b  ; if running death routine,
    BEQ bra_exit_game_timer  ; branch to leave
    LDA ram_player_y_high_pos
    CMP #$02  ; if player below the screen,
    BCS bra_exit_game_timer  ; branch to leave regardless of level type
    LDA ram_game_timer_ctrl_timer  ; if game timer control not yet expired,
    BNE bra_exit_game_timer  ; branch to leave
    LDA ram_game_timer_display
    ORA ram_game_timer_display+1  ; otherwise check game timer digits
    ORA ram_game_timer_display+2
    BEQ bra_trigger_time_up  ; if game timer digits at 000, branch to time-up code
    LDY ram_game_timer_display  ; otherwise check first digit
    DEY  ; if first digit not on 1,
    BNE bra_decrement_game_timer  ; branch to reset game timer control
    LDA ram_game_timer_display+1  ; otherwise check second and third digits
    ORA ram_game_timer_display+2
    BNE bra_decrement_game_timer  ; if timer not at 100, branch to reset game timer control
    LDA #con_time_running_out_music
    STA ram_event_music_queue  ; otherwise load time running out music
bra_decrement_game_timer:
    LDA #$18  ; reset game timer control
    STA ram_game_timer_ctrl_timer
    LDY #$23  ; set offset for last digit
    LDA #$ff  ; set value to decrement game timer digit
    STA ram_digit_modifier+5
    JSR sub_digits_math_routine  ; do sub to decrement game timer slowly
    LDA #$a4  ; set status nybbles to update game timer display
    JMP sub_print_status_bar_numbers  ; do sub to update the display
bra_trigger_time_up:
    STA ram_player_status  ; init player status (note A will always be zero here)
    JSR sub_force_injury  ; do sub to kill the player (note player is small here)
    INC ram_game_timer_expired_flag  ; set game timer expiration flag
bra_exit_game_timer:
    RTS  ; leave

; -------------------------------------------------------------------------------------

handler_run_warp_zone_object:
    LDA ram_scroll_lock  ; check for scroll lock flag
    BEQ bra_exit_game_timer  ; branch if not set to leave
    LDA ram_player_y_position  ; check to see if player's vertical coordinate has
    AND ram_player_y_high_pos  ; same bits set as in vertical high byte (why?)
    BNE bra_exit_game_timer  ; if so, branch to leave
    STA ram_scroll_lock  ; otherwise nullify scroll lock flag
    INC ram_warp_zone_control  ; increment warp zone flag to make warp pipes for warp zone
    JMP sub_erase_enemy_object  ; kill this object

; -------------------------------------------------------------------------------------
; $00 - used in bra_activate_whirlpool_pull to store whirlpool length / 2, page location of center of whirlpool
; and also to store movement force exerted on player
; $01 - used in sub_process_whirlpool_pull to store page location of right extent of whirlpool
; and in bra_activate_whirlpool_pull to store center of whirlpool
; $02 - used in sub_process_whirlpool_pull to store right extent of whirlpool and in
; bra_activate_whirlpool_pull to store maximum vertical speed

sub_process_whirlpool_pull:
    LDA ram_area_type  ; check for water type level
    BNE bra_exit_whirlpool_processing  ; branch to leave if not found
    STA ram_whirlpool_flag  ; otherwise initialize whirlpool flag
    LDA ram_timer_control  ; if master timer control set,
    BNE bra_exit_whirlpool_processing  ; branch to leave
    LDY #$04  ; otherwise start with last whirlpool data
bra_process_whirlpool_slots:
    LDA ram_whirlpool_left_extent,y  ; get left extent of whirlpool
    CLC
    ADC ram_whirlpool_length,y  ; add length of whirlpool
    STA $02  ; store result as right extent here
    LDA ram_whirlpool_page_loc,y  ; get page location
    BEQ bra_advance_whirlpool_slot  ; if none or page 0, branch to get next data
    ADC #$00  ; add carry
    STA $01  ; store result as page location of right extent here
    LDA ram_player_x_position  ; get player's horizontal position
    SEC
    SBC ram_whirlpool_left_extent,y  ; subtract left extent
    LDA ram_player_page_loc  ; get player's page location
    SBC ram_whirlpool_page_loc,y  ; subtract borrow
    BMI bra_advance_whirlpool_slot  ; if player too far left, branch to get next data
    LDA $02  ; otherwise get right extent
    SEC
    SBC ram_player_x_position  ; subtract player's horizontal coordinate
    LDA $01  ; get right extent's page location
    SBC ram_player_page_loc  ; subtract borrow
    BPL bra_activate_whirlpool_pull  ; if player within right extent, branch to whirlpool code
bra_advance_whirlpool_slot:
    DEY  ; move onto next whirlpool data
    BPL bra_process_whirlpool_slots  ; do this until all whirlpools are checked
bra_exit_whirlpool_processing:
    RTS  ; leave

bra_activate_whirlpool_pull:
    LDA ram_whirlpool_length,y  ; get length of whirlpool
    LSR  ; divide by 2
    STA $00  ; save here
    LDA ram_whirlpool_left_extent,y  ; get left extent of whirlpool
    CLC
    ADC $00  ; add length divided by 2
    STA $01  ; save as center of whirlpool
    LDA ram_whirlpool_page_loc,y  ; get page location
    ADC #$00  ; add carry
    STA $00  ; save as page location of whirlpool center
    LDA ram_frame_counter  ; get frame counter
    LSR  ; shift d0 into carry (to run on every other frame)
    BCC bra_apply_whirlpool_vertical_pull  ; if d0 not set, branch to last part of code
    LDA $01  ; get center
    SEC
    SBC ram_player_x_position  ; subtract player's horizontal coordinate
    LDA $00  ; get page location of center
    SBC ram_player_page_loc  ; subtract borrow
    BPL bra_pull_player_right_to_whirlpool  ; if player to the left of center, branch
    LDA ram_player_x_position  ; otherwise slowly pull player left, towards the center
    SEC
    SBC #$01  ; subtract one pixel
    STA ram_player_x_position  ; set player's new horizontal coordinate
    LDA ram_player_page_loc
    SBC #$00  ; subtract borrow
    JMP loc_store_whirlpool_player_page  ; jump to set player's new page location
bra_pull_player_right_to_whirlpool:
    LDA ram_player_collision_bits  ; get player's collision bits
    LSR  ; shift d0 into carry
    BCC bra_apply_whirlpool_vertical_pull  ; if d0 not set, branch
    LDA ram_player_x_position  ; otherwise slowly pull player right, towards the center
    CLC
    ADC #$01  ; add one pixel
    STA ram_player_x_position  ; set player's new horizontal coordinate
    LDA ram_player_page_loc
    ADC #$00  ; add carry
loc_store_whirlpool_player_page:
    STA ram_player_page_loc  ; set player's new page location
bra_apply_whirlpool_vertical_pull:
    LDA #$10
    STA $00  ; set vertical movement force
    LDA #$01
    STA ram_whirlpool_flag  ; set whirlpool flag to be used later
    STA $02  ; also set maximum vertical speed
    LSR
    TAX  ; set X for player offset
    JMP sub_apply_object_gravity  ; jump to put whirlpool effect on player vertically, do not return

; -------------------------------------------------------------------------------------

tbl_flagpole_score_modifiers:
    .byte $05, $02, $08, $04, $01

tbl_flagpole_score_digits:
    .byte $03, $03, $04, $04, $04

sub_flagpole_routine:
    LDX #$05  ; set enemy object offset
    STX ram_object_offset  ; to special use slot
    LDA ram_enemy_id,x
    CMP #con_flagpole_flag_object  ; if flagpole flag not found,
    BNE bra_exit_flagpole  ; branch to leave
    LDA ram_game_engine_subroutine
    CMP #$04  ; if flagpole slide routine not running,
    BNE bra_skip_flagpole_score_award  ; branch to near the end of code
    LDA ram_player_state
    CMP #$03  ; if player state not climbing,
    BNE bra_skip_flagpole_score_award  ; branch to near the end of code
    LDA ram_enemy_y_position,x  ; check flagpole flag's vertical coordinate
    CMP #$aa  ; if flagpole flag down to a certain point,
    BCS bra_award_flagpole_score  ; branch to end the level
    LDA ram_player_y_position  ; check player's vertical coordinate
    CMP #$a2  ; if player down to a certain point,
    BCS bra_award_flagpole_score  ; branch to end the level
    LDA ram_enemy_ymf_dummy,x
    ADC #$ff  ; add movement amount to dummy variable
    STA ram_enemy_ymf_dummy,x  ; save dummy variable
    LDA ram_enemy_y_position,x  ; get flag's vertical coordinate
    ADC #$01  ; add 1 plus carry to move flag, and
    STA ram_enemy_y_position,x  ; store vertical coordinate
    LDA ram_flagpole_f_num_ymf_dummy
    SEC  ; subtract movement amount from dummy variable
    SBC #$ff
    STA ram_flagpole_f_num_ymf_dummy  ; save dummy variable
    LDA ram_flagpole_f_num_y_pos
    SBC #$01  ; subtract one plus borrow to move floatey number,
    STA ram_flagpole_f_num_y_pos  ; and store vertical coordinate here
bra_skip_flagpole_score_award:
    JMP loc_render_flagpole_objects  ; jump to skip ahead and draw flag and floatey number
bra_award_flagpole_score:
    LDY ram_flagpole_score  ; get score offset from earlier (when player touched flagpole)
    LDA tbl_flagpole_score_modifiers,y  ; get amount to award player points
    LDX tbl_flagpole_score_digits,y  ; get digit with which to award points
    STA ram_digit_modifier,x  ; store in digit modifier
    JSR sub_add_to_score  ; do sub to award player points depending on height of collision
    LDA #$05
    STA ram_game_engine_subroutine  ; set to run end-of-level subroutine on next frame
loc_render_flagpole_objects:
    JSR sub_get_enemy_offscreen_bits  ; get offscreen information
    JSR sub_relative_enemy_position  ; get relative coordinates
    JSR sub_render_flagpole_graphics  ; draw flagpole flag and floatey number
bra_exit_flagpole:
    RTS

; -------------------------------------------------------------------------------------

tbl_jumpspring_y_positions:
    .byte $08, $10, $08, $00

handler_process_jumpspring:
    JSR sub_get_enemy_offscreen_bits  ; get offscreen information
    LDA ram_timer_control  ; check master timer control
    BNE bra_draw_jumpspring_object  ; branch to last section if set
    LDA ram_jumpspring_anim_ctrl  ; check jumpspring frame control
    BEQ bra_draw_jumpspring_object  ; branch to last section if not set
    TAY
    DEY  ; subtract one from frame control,
    TYA  ; the only way a poor nmos 6502 can
    AND #%00000010  ; mask out all but d1, original value still in Y
    BNE bra_move_player_up_with_jumpspring  ; if set, branch to move player up
    INC ram_player_y_position
    INC ram_player_y_position  ; move player's vertical position down two pixels
    JMP loc_position_jumpspring  ; skip to next part
bra_move_player_up_with_jumpspring:
    DEC ram_player_y_position  ; move player's vertical position up two pixels
    DEC ram_player_y_position
loc_position_jumpspring:
    LDA ram_jumpspring_fixed_y_pos,x  ; get permanent vertical position
    CLC
    ADC tbl_jumpspring_y_positions,y  ; add value using frame control as offset
    STA ram_enemy_y_position,x  ; store as new vertical position
    CPY #$01  ; check frame control offset (second frame is $00)
    BCC bra_apply_jumpspring_bounce  ; if offset not yet at third frame ($01), skip to next part
    LDA ram_a_b_buttons
    AND #con_btn_a  ; check saved controller bits for A button press
    BEQ bra_apply_jumpspring_bounce  ; skip to next part if A not pressed
    AND ram_previous_a_b_buttons  ; check for A button pressed in previous frame
    BNE bra_apply_jumpspring_bounce  ; skip to next part if so
    LDA #$f4
    STA ram_jumpspring_force  ; otherwise write new jumpspring force here
bra_apply_jumpspring_bounce:
    CPY #$03  ; check frame control offset again
    BNE bra_draw_jumpspring_object  ; skip to last part if not yet at fifth frame ($03)
    LDA ram_jumpspring_force
    STA ram_player_y_speed  ; store jumpspring force as player's new vertical speed
    LDA #$00
    STA ram_jumpspring_anim_ctrl  ; initialize jumpspring frame control
bra_draw_jumpspring_object:
    JSR sub_relative_enemy_position  ; get jumpspring's relative coordinates
    JSR sub_render_enemy_graphics  ; draw jumpspring
    JSR sub_offscreen_bounds_check  ; check to see if we need to kill it
    LDA ram_jumpspring_anim_ctrl  ; if frame control at zero, don't bother
    BEQ bra_exit_jumpspring  ; trying to animate it, just leave
    LDA ram_jumpspring_timer
    BNE bra_exit_jumpspring  ; if jumpspring timer not expired yet, leave
    LDA #$04
    STA ram_jumpspring_timer  ; otherwise initialize jumpspring timer
    INC ram_jumpspring_anim_ctrl  ; increment frame control to animate jumpspring
bra_exit_jumpspring:
    RTS  ; leave

; -------------------------------------------------------------------------------------

sub_setup_vine:
    LDA #con_vine_object  ; load identifier for vine object
    STA ram_enemy_id,x  ; store in buffer
    LDA #$01
    STA ram_enemy_flag,x  ; set flag for enemy object buffer
    LDA ram_block_page_loc,y
    STA ram_enemy_page_loc,x  ; copy page location from previous object
    LDA ram_block_x_position,y
    STA ram_enemy_x_position,x  ; copy horizontal coordinate from previous object
    LDA ram_block_y_position,y
    STA ram_enemy_y_position,x  ; copy vertical coordinate from previous object
    LDY ram_vine_flag_offset  ; load vine flag/offset to next available vine slot
    BNE bra_store_next_vine_object  ; if set at all, don't bother to store vertical
    STA ram_vine_start_y_position  ; otherwise store vertical coordinate here
bra_store_next_vine_object:
    TXA  ; store object offset to next available vine slot
    STA ram_vine_obj_offset,y  ; using vine flag as offset
    INC ram_vine_flag_offset  ; increment vine flag offset
    LDA #con_sfx_grow_vine
    STA ram_square2_sound_queue  ; load vine grow sound
    RTS

; -------------------------------------------------------------------------------------
; $06-$07 - used as address to block buffer data
; $02 - used as vertical high nybble of block buffer offset

tbl_vine_growth_heights:
    .byte $30, $60

handler_run_vine_object:
    CPX #$05  ; check enemy offset for special use slot
    BNE bra_exit_vine_handler  ; if not in last slot, branch to leave
    LDY ram_vine_flag_offset
    DEY  ; decrement vine flag in Y, use as offset
    LDA ram_vine_height
    CMP tbl_vine_growth_heights,y  ; if vine has reached certain height,
    BEQ bra_run_vine_subsystems  ; branch ahead to skip this part
    LDA ram_frame_counter  ; get frame counter
    LSR  ; shift d1 into carry
    LSR
    BCC bra_run_vine_subsystems  ; if d1 not set (2 frames every 4) skip this part
    LDA ram_enemy_y_position+5
    SBC #$01  ; subtract vertical position of vine
    STA ram_enemy_y_position+5  ; one pixel every frame it's time
    INC ram_vine_height  ; increment vine height
bra_run_vine_subsystems:
    LDA ram_vine_height  ; if vine still very small,
    CMP #$08  ; branch to leave
    BCC bra_exit_vine_handler
    JSR sub_relative_enemy_position  ; get relative coordinates of vine,
    JSR sub_get_enemy_offscreen_bits  ; and any offscreen bits
    LDY #$00  ; initialize offset used in draw vine sub
bra_draw_vine_segments_loop:
    JSR sub_draw_vine  ; draw vine
    INY  ; increment offset
    CPY ram_vine_flag_offset  ; if offset in Y and offset here
    BNE bra_draw_vine_segments_loop  ; do not yet match, loop back to draw more vine
    LDA ram_enemy_offscreen_bits
    AND #%00001100  ; mask offscreen bits
    BEQ bra_write_vine_climb_metatile  ; if none of the saved offscreen bits set, skip ahead
    DEY  ; otherwise decrement Y to get proper offset again
bra_erase_vine_objects_loop:
    LDX ram_vine_obj_offset,y  ; get enemy object offset for this vine object
    JSR sub_erase_enemy_object  ; kill this vine object
    DEY  ; decrement Y
    BPL bra_erase_vine_objects_loop  ; if any vine objects left, loop back to kill it
    STA ram_vine_flag_offset  ; initialize vine flag/offset
    STA ram_vine_height  ; initialize vine height
bra_write_vine_climb_metatile:
    LDA ram_vine_height  ; check vine height
    CMP #$20  ; if vine small (less than 32 pixels tall)
    BCC bra_exit_vine_handler  ; then branch ahead to leave
    LDX #$06  ; set offset in X to last enemy slot
    LDA #$01  ; set A to obtain horizontal in $04, but we don't care
    LDY #$1b  ; set Y to offset to get block at ($04, $10) of coordinates
    JSR sub_block_buffer_collision  ; do a sub to get block buffer address set, return contents
    LDY $02
    CPY #$d0  ; if vertical high nybble offset beyond extent of
    BCS bra_exit_vine_handler  ; current block buffer, branch to leave, do not write
    LDA ($06),y  ; otherwise check contents of block buffer at
    BNE bra_exit_vine_handler  ; current offset, if not empty, branch to leave
    LDA #$26
    STA ($06),y  ; otherwise, write climbing metatile to block buffer
bra_exit_vine_handler:
    LDX ram_object_offset  ; get enemy object offset and leave
    RTS
