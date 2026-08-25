; -------------------------------------------------------------------------------------
; (these apply to all area object subroutines in this section unless otherwise stated)
; $00 - used to store offset used to find object code
; $07 - starts with adder from area parser, used to store row offset

handler_alter_area_attributes:
    LDY ram_area_obj_offset_buffer,x  ; load offset for level object data saved in buffer
    INY  ; load second byte
    LDA (ram_area_data),y
    PHA  ; save in stack for now
    AND #%01000000
    BNE bra_update_scenery_or_background_color  ; branch if d6 is set
    PLA
    PHA  ; pull and push offset to copy to A
    AND #%00001111  ; mask out high nybble and store as
    STA ram_terrain_control  ; new terrain height type bits
    PLA
    AND #%00110000  ; pull and mask out all but d5 and d4
    LSR  ; move bits to lower nybble and store
    LSR  ; as new background scenery bits
    LSR
    LSR
    STA ram_background_scenery  ; then leave
    RTS
bra_update_scenery_or_background_color:
    PLA
    AND #%00000111  ; mask out all but 3 LSB
    CMP #$04  ; if four or greater, set color control bits
    BCC bra_store_altered_foreground_scenery  ; and nullify foreground scenery bits
    STA ram_background_color_ctrl
    LDA #$00
bra_store_altered_foreground_scenery:
    STA ram_foreground_scenery  ; otherwise set new foreground scenery bits
    RTS

; --------------------------------

handler_warp_zone_scroll_lock:
    LDX #$04  ; load value of 4 for game text routine as default
    LDA ram_world_number  ; warp zone (4-3-2), then check world number
    BEQ bra_activate_warp_zone
    INX  ; if world number > 1, increment for next warp zone (5)
    LDY ram_area_type  ; check area type
    DEY
    BNE bra_activate_warp_zone  ; if ground area type, increment for last warp zone
    INX  ; (8-7-6) and move on
bra_activate_warp_zone:
    TXA
    STA ram_warp_zone_control  ; store number here to be used by warp zone routine
    JSR sub_write_game_text  ; print text and warp zone numbers
    LDA #con_piranha_plant
    JSR sub_kill_enemies  ; load identifier for piranha plants and do sub

handler_toggle_scroll_lock:
    LDA ram_scroll_lock  ; invert scroll lock to turn it on
    EOR #%00000001
    STA ram_scroll_lock
    RTS

; --------------------------------
; $00 - used to store enemy identifier in sub_kill_enemies

sub_kill_enemies:
    STA $00  ; store identifier here
    LDA #$00
    LDX #$04  ; check for identifier in enemy object buffer
bra_kill_matching_enemy_loop:
    LDY ram_enemy_id,x
    CPY $00  ; if not found, branch
    BNE bra_advance_enemy_kill_loop
    STA ram_enemy_flag,x  ; if found, deactivate enemy object flag
bra_advance_enemy_kill_loop:
    DEX  ; do this until all slots are checked
    BPL bra_kill_matching_enemy_loop
    RTS

; --------------------------------

tbl_area_frenzy_enemy_ids:
    .byte con_fly_cheep_cheep_frenzy, con_b_bill_c_cheep_frenzy, con_stop_frenzy

handler_set_area_frenzy:
    LDX $00  ; use area object identifier bit as offset
    LDA tbl_area_frenzy_enemy_ids-8,x  ; note that it starts at 8, thus weird address here
    LDY #$05
bra_check_existing_frenzy_enemy:
    DEY  ; check regular slots of enemy object buffer
    BMI bra_store_area_frenzy_queue  ; if all slots checked and enemy object not found, branch to store
    CMP ram_enemy_id,y  ; check for enemy object in buffer versus frenzy object
    BNE bra_check_existing_frenzy_enemy
    LDA #$00  ; if enemy object already present, nullify queue and leave
bra_store_area_frenzy_queue:
    STA ram_enemy_frenzy_queue  ; store enemy into frenzy queue
    RTS

; --------------------------------
; $06 - used by handler_draw_mushroom_ledge to store length

handler_set_area_style:
    LDA ram_area_style  ; load level object style and jump to the right sub
    JSR sub_dispatch_inline_handler
    .word handler_draw_tree_ledge  ; also used for cloud type levels
    .word handler_draw_mushroom_ledge
    .word handler_draw_bullet_bill_cannon

handler_draw_tree_ledge:
    JSR sub_get_large_area_object_attributes  ; get row and length of green ledge
    LDA ram_area_object_length,x  ; check length counter for expiration
    BEQ bra_render_tree_ledge_end
    BPL bra_render_tree_ledge_middle
    TYA
    STA ram_area_object_length,x  ; store lower nybble into buffer flag as length of ledge
    LDA ram_current_page_loc
    ORA ram_current_column_pos  ; are we at the start of the level?
    BEQ bra_render_tree_ledge_middle
    LDA #$16  ; render start of tree ledge
    JMP loc_render_ledge_without_stem
bra_render_tree_ledge_middle:
    LDX $07
    LDA #$17  ; render middle of tree ledge
    STA ram_metatile_buffer,x  ; note that this is also used if ledge position is
    LDA #$4c  ; at the start of level for continuous effect
    JMP loc_render_ledge_stem  ; now render the part underneath
bra_render_tree_ledge_end:
    LDA #$18  ; render end of tree ledge
    JMP loc_render_ledge_without_stem

handler_draw_mushroom_ledge:
    JSR sub_check_large_area_object_length  ; get shroom dimensions
    STY $06  ; store length here for now
    BCC bra_render_mushroom_ledge_end
    LDA ram_area_object_length,x  ; divide length by 2 and store elsewhere
    LSR
    STA ram_mushroom_ledge_half_len,x
    LDA #$19  ; render start of mushroom
    JMP loc_render_ledge_without_stem
bra_render_mushroom_ledge_end:
    LDA #$1b  ; if at the end, render end of mushroom
    LDY ram_area_object_length,x
    BEQ loc_render_ledge_without_stem
    LDA ram_mushroom_ledge_half_len,x  ; get divided length and store where length
    STA $06  ; was stored originally
    LDX $07
    LDA #$1a
    STA ram_metatile_buffer,x  ; render middle of mushroom
    CPY $06  ; are we smack dab in the center?
    BNE bra_exit_mushroom_ledge  ; if not, branch to leave
    INX
    LDA #$4f
    STA ram_metatile_buffer,x  ; render stem top of mushroom underneath the middle
    LDA #$50
loc_render_ledge_stem:
    INX
    LDY #$0f  ; set $0f to render all way down
    JMP sub_render_under_part  ; now render the stem of mushroom
loc_render_ledge_without_stem:
    LDX $07  ; load row of ledge
    LDY #$00  ; set 0 for no bottom on this part
    JMP sub_render_under_part

; --------------------------------

; tiles used by pulleys and rope object
tbl_pulley_rope_metatiles:
    .byte $42, $41, $43

handler_draw_pulley_rope:
    JSR sub_check_large_area_object_length  ; get length of pulley/rope object
    LDY #$00  ; initialize metatile offset
    BCS bra_render_pulley_rope_metatile  ; if starting, render left pulley
    INY
    LDA ram_area_object_length,x  ; if not at the end, render rope
    BNE bra_render_pulley_rope_metatile
    INY  ; otherwise render right pulley
bra_render_pulley_rope_metatile:
    LDA tbl_pulley_rope_metatiles,y
    STA ram_metatile_buffer  ; render at the top of the screen
bra_exit_mushroom_ledge:
    RTS  ; and leave

; --------------------------------
; $06 - used to store upper limit of rows for handler_draw_castle_structure

tbl_castle_structure_metatiles:
    .byte $00, $45, $45, $45, $00
    .byte $00, $48, $47, $46, $00
    .byte $45, $49, $49, $49, $45
    .byte $47, $47, $4a, $47, $47
    .byte $47, $47, $4b, $47, $47
    .byte $49, $49, $49, $49, $49
    .byte $47, $4a, $47, $4a, $47
    .byte $47, $4b, $47, $4b, $47
    .byte $47, $47, $47, $47, $47
    .byte $4a, $47, $4a, $47, $4a
    .byte $4b, $47, $4b, $47, $4b

handler_draw_castle_structure:
    JSR sub_get_large_area_object_attributes  ; save lower nybble as starting row
    STY $07  ; if starting row is above $0a, game will crash!!!
    LDY #$04
    JSR sub_check_fixed_large_area_object_length  ; load length of castle if not already loaded
    TXA
    PHA  ; save obj buffer offset to stack
    LDY ram_area_object_length,x  ; use current length as offset for castle data
    LDX $07  ; begin at starting row
    LDA #$0b
    STA $06  ; load upper limit of number of rows to print
bra_render_castle_column_loop:
    LDA tbl_castle_structure_metatiles,y  ; load current byte using offset
    STA ram_metatile_buffer,x
    INX  ; store in buffer and increment buffer offset
    LDA $06
    BEQ bra_check_castle_floor_row  ; have we reached upper limit yet?
    INY  ; if not, increment column-wise
    INY  ; to byte in next row
    INY
    INY
    INY
    DEC $06  ; move closer to upper limit
bra_check_castle_floor_row:
    CPX #$0b  ; have we reached the row just before floor?
    BNE bra_render_castle_column_loop  ; if not, go back and do another row
    PLA
    TAX  ; get obj buffer offset from before
    LDA ram_current_page_loc
    BEQ bra_exit_castle_object  ; if we're at page 0, we do not need to do anything else
    LDA ram_area_object_length,x  ; check length
    CMP #$01  ; if length almost about to expire, put brick at floor
    BEQ bra_place_castle_player_stop_block
    LDY $07  ; check starting row for tall castle ($00)
    BNE bra_check_short_castle_column
    CMP #$03  ; if found, then check to see if we're at the second column
    BEQ bra_place_castle_player_stop_block
bra_check_short_castle_column:
    CMP #$02  ; if not tall castle, check to see if we're at the third column
    BNE bra_exit_castle_object  ; if we aren't and the castle is tall, don't create flag yet
    JSR sub_get_area_object_x_position  ; otherwise, obtain and save horizontal pixel coordinate
    PHA
    JSR sub_find_empty_enemy_slot  ; find an empty place on the enemy object buffer
    PLA
    STA ram_enemy_x_position,x  ; then write horizontal coordinate for star flag
    LDA ram_current_page_loc
    STA ram_enemy_page_loc,x  ; set page location for star flag
    LDA #$01
    STA ram_enemy_y_high_pos,x  ; set vertical high byte
    STA ram_enemy_flag,x  ; set flag for buffer
    LDA #$90
    STA ram_enemy_y_position,x  ; set vertical coordinate
    LDA #con_star_flag_object  ; set star flag value in buffer itself
    STA ram_enemy_id,x
    RTS
bra_place_castle_player_stop_block:
    LDY #$52  ; put brick at floor to stop player at end of level
    STY ram_metatile_buffer+10  ; this is only done if we're on the second column
bra_exit_castle_object:
    RTS

; --------------------------------

handler_draw_water_pipe:
    JSR sub_get_large_area_object_attributes  ; get row and lower nybble
    LDY ram_area_object_length,x  ; get length (residual code, water pipe is 1 col thick)
    LDX $07  ; get row
    LDA #$6b
    STA ram_metatile_buffer,x  ; draw something here and below it
    LDA #$6c
    STA ram_metatile_buffer+1,x
    RTS

; --------------------------------
; $05 - used to store length of vertical shaft in sub_render_sideways_pipe
; $06 - used to store leftover horizontal length in sub_render_sideways_pipe
; and vertical length in handler_draw_vertical_pipe and sub_get_pipe_height

handler_draw_intro_pipe:
    LDY #$03  ; check if length set, if not set, set it
    JSR sub_check_fixed_large_area_object_length
    LDY #$0a  ; set fixed value and render the sideways part
    JSR sub_render_sideways_pipe
    BCS bra_exit_intro_pipe  ; if carry flag set, not time to draw vertical pipe part
    LDX #$06  ; blank everything above the vertical pipe part
bra_clear_above_intro_pipe_loop:
    LDA #$00  ; all the way to the top of the screen
    STA ram_metatile_buffer,x  ; because otherwise it will look like exit pipe
    DEX
    BPL bra_clear_above_intro_pipe_loop
    LDA tbl_vertical_pipe_metatiles,y  ; draw the end of the vertical pipe part
    STA ram_metatile_buffer+7
bra_exit_intro_pipe:
    RTS

tbl_side_pipe_shaft_metatiles:
    .byte $15, $14  ; used to control whether or not vertical pipe shaft
    .byte $00, $00  ; is drawn, and if so, controls the metatile number
tbl_side_pipe_top_metatiles:
    .byte $15, $1e  ; top part of sideways part of pipe
    .byte $1d, $1c
tbl_side_pipe_bottom_metatiles:
    .byte $15, $21  ; bottom part of sideways part of pipe
    .byte $20, $1f

handler_draw_exit_pipe:
    LDY #$03  ; check if length set, if not set, set it
    JSR sub_check_fixed_large_area_object_length
    JSR sub_get_large_area_object_attributes  ; get vertical length, then plow on through sub_render_sideways_pipe

sub_render_sideways_pipe:
    DEY  ; decrement twice to make room for shaft at bottom
    DEY  ; and store here for now as vertical length
    STY $05
    LDY ram_area_object_length,x  ; get length left over and store here
    STY $06
    LDX $05  ; get vertical length plus one, use as buffer offset
    INX
    LDA tbl_side_pipe_shaft_metatiles,y  ; check for value $00 based on horizontal offset
    CMP #$00
    BEQ bra_render_side_pipe_end  ; if found, do not draw the vertical pipe shaft
    LDX #$00
    LDY $05  ; init buffer offset and get vertical length
    JSR sub_render_under_part  ; and render vertical shaft using tile number in A
    CLC  ; clear carry flag to be used by handler_draw_intro_pipe
bra_render_side_pipe_end:
    LDY $06  ; render side pipe part at the bottom
    LDA tbl_side_pipe_top_metatiles,y
    STA ram_metatile_buffer,x  ; note that the pipe parts are stored
    LDA tbl_side_pipe_bottom_metatiles,y  ; backwards horizontally
    STA ram_metatile_buffer+1,x
    RTS

tbl_vertical_pipe_metatiles:
    .byte $11, $10  ; used by pipes that lead somewhere
    .byte $15, $14
    .byte $13, $12  ; used by decoration pipes
    .byte $15, $14

handler_draw_vertical_pipe:
    JSR sub_get_pipe_height
    LDA $00  ; check to see if value was nullified earlier
    BEQ bra_skip_piranha_plant  ; (if d3, the usage control bit of second byte, was set)
    INY
    INY
    INY
    INY  ; add four if usage control bit was not set
bra_skip_piranha_plant:
    TYA  ; save value in stack
    PHA
    LDA ram_area_number
    ORA ram_world_number  ; if at world 1-1, do not add piranha plant ever
    BEQ bra_render_vertical_pipe
    LDY ram_area_object_length,x  ; if on second column of pipe, branch
    BEQ bra_render_vertical_pipe  ; (because we only need to do this once)
    JSR sub_find_empty_enemy_slot  ; check for an empty moving data buffer space
    BCS bra_render_vertical_pipe  ; if not found, too many enemies, thus skip
    JSR sub_get_area_object_x_position  ; get horizontal pixel coordinate
    CLC
    ADC #$08  ; add eight to put the piranha plant in the center
    STA ram_enemy_x_position,x  ; store as enemy's horizontal coordinate
    LDA ram_current_page_loc  ; add carry to current page number
    ADC #$00
    STA ram_enemy_page_loc,x  ; store as enemy's page coordinate
    LDA #$01
    STA ram_enemy_y_high_pos,x
    STA ram_enemy_flag,x  ; activate enemy flag
    JSR sub_get_area_object_y_position  ; get piranha plant's vertical coordinate and store here
    STA ram_enemy_y_position,x
    LDA #con_piranha_plant  ; write piranha plant's value into buffer
    STA ram_enemy_id,x
    JSR sub_init_piranha_plant
bra_render_vertical_pipe:
    PLA  ; get value saved earlier and use as Y
    TAY
    LDX $07  ; get buffer offset
    LDA tbl_vertical_pipe_metatiles,y  ; draw the appropriate pipe with the Y we loaded earlier
    STA ram_metatile_buffer,x  ; render the top of the pipe
    INX
    LDA tbl_vertical_pipe_metatiles+2,y  ; render the rest of the pipe
    LDY $06  ; subtract one from length and render the part underneath
    DEY
    JMP sub_render_under_part

sub_get_pipe_height:
    LDY #$01  ; check for length loaded, if not, load
    JSR sub_check_fixed_large_area_object_length  ; pipe length of 2 (horizontal)
    JSR sub_get_large_area_object_attributes
    TYA  ; get saved lower nybble as height
    AND #$07  ; save only the three lower bits as
    STA $06  ; vertical length, then load Y with
    LDY ram_area_object_length,x  ; length left over
    RTS

sub_find_empty_enemy_slot:
    LDX #$00  ; start at first enemy slot
bra_find_empty_enemy_slot_loop:
    CLC  ; clear carry flag by default
    LDA ram_enemy_flag,x  ; check enemy buffer for nonzero
    BEQ bra_exit_empty_enemy_slot_search  ; if zero, leave
    INX
    CPX #$05  ; if nonzero, check next value
    BNE bra_find_empty_enemy_slot_loop
bra_exit_empty_enemy_slot_search:
    RTS  ; if all values nonzero, carry flag is set
