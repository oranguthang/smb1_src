handler_smb2_main_alter_area_attributes:
    LDY AreaObjOffsetBuffer,x  ; load offset for level object data saved in buffer
    INY  ; load second byte
    LDA (AreaData),y
    PHA  ; save in stack for now
    AND #%01000000
    BNE bra_smb2_main_update_scenery_or_background_color  ; branch if d6 is set
    PLA
    PHA  ; pull and push offset to copy to A
    AND #%00001111  ; mask out high nybble and store as
    STA TerrainControl  ; new terrain height type bits
    PLA
    AND #%00110000  ; pull and mask out all but d5 and d4
    LSR  ; move bits to lower nybble and store
    LSR  ; as new background scenery bits
    LSR
    LSR
    STA BackgroundScenery  ; then leave
    RTS
bra_smb2_main_update_scenery_or_background_color:
    PLA
    AND #%00000111  ; mask out all but 3 LSB
    CMP #$04  ; if four or greater, set color control bits
    BCC bra_smb2_main_store_altered_foreground_scenery  ; and nullify foreground scenery bits
    STA BackgroundColorCtrl
    LDA #$00
bra_smb2_main_store_altered_foreground_scenery:
    STA ForegroundScenery  ; otherwise set new foreground scenery bits
    RTS

; --------------------------------

handler_smb2_main_warp_zone_scroll_lock:
    LDX #$80  ; use base number for warp to world 2
    LDA HardWorldFlag  ; if on worlds A-D, skip ahead to next part
    BNE bra_smb2_main_warp_worlds_a_thru_d  ; note d7 is set in all entries to prevent zero condition
    LDA WorldNumber  ; from happening in warp zone code elsewhere
    BNE bra_smb2_main_warp_worlds2_thru8  ; if not on world 1, branch to handle a different way
    LDY AreaType  ; check to see if on ground level type
    DEY  ; branch if so to add one to the number
    BEQ bra_smb2_main_w1_warp2
    LDA AreaAddrsLOffset  ; if on first underground level, branch to use base number
    BEQ bra_smb2_main_w1_warp1
    INX  ; otherwise add two to the number and use it
bra_smb2_main_w1_warp2:
    INX
bra_smb2_main_w1_warp1:
    JMP bra_smb2_main_use_base_world_number

bra_smb2_main_warp_worlds_a_thru_d:
    LDA #$87  ; use base number for worlds A-D
    CLC
    ADC LevelNumber  ; add level number itself to it
    BNE bra_smb2_main_dump_warp_ctrl  ; then branch to use it

bra_smb2_main_warp_worlds2_thru8:
    LDX #$83  ; use base number for worlds 2-8
    LDA WorldNumber
    CMP #World3  ; branch if on world 3 to use
    BEQ bra_smb2_main_use_base_world_number
    INX  ; otherwise add one to the number
    CMP #World5  ; if not on world 5, branch to add 3 more
    BNE bra_smb2_main_w678_warp
    LDA AreaAddrsLOffset
    CMP #$0b  ; if on the 12th ground area, branch to use
    BEQ bra_smb2_main_use_base_world_number  ; (in normal map data this corresponds to world 5-1)
    LDY AreaType  ; check to see if on ground level type
    DEY  ; branch if so to add 2 more to the number
    BEQ bra_smb2_main_w5_warp3
    JMP loc_smb2_main_w5_warp2  ; otherwise add 1 more

bra_smb2_main_w678_warp:
    INX  ; add 1, 2, or 3 to base number or use as-is
bra_smb2_main_w5_warp3:
    INX  ; depending on where branched
loc_smb2_main_w5_warp2:
    INX
bra_smb2_main_use_base_world_number:
    TXA

bra_smb2_main_dump_warp_ctrl:
    STA WarpZoneControl  ; set warp zone control
    JSR sub_smb2_main_write_warp_zone_message
    LDA #$0d  ; kill piranha plants
    JSR sub_smb2_main_kill_enemies

handler_smb2_main_toggle_scroll_lock:
    LDA ScrollLock  ; invert scroll lock to turn it on
    EOR #%00000001
    STA ScrollLock
    RTS

; --------------------------------
; $00 - used to store enemy identifier in KillEnemies

sub_smb2_main_kill_enemies:
    STA $00  ; store identifier here
    LDA #$00
    LDX #$04  ; check for identifier in enemy object buffer
bra_smb2_main_kill_matching_enemy_loop:
    LDY Enemy_ID,x
    CPY $00  ; if not found, branch
    BNE bra_smb2_main_advance_enemy_kill_loop
    STA Enemy_Flag,x  ; if found, deactivate enemy object flag
bra_smb2_main_advance_enemy_kill_loop:
    DEX  ; do this until all slots are checked
    BPL bra_smb2_main_kill_matching_enemy_loop
    RTS

; --------------------------------

off_smb2_main_area_frenzy_enemy_ids:
    .byte FlyCheepCheepFrenzy, BBill_CCheep_Frenzy, Stop_Frenzy

handler_smb2_main_set_area_frenzy:
    LDX $00  ; use area object identifier bit as offset
    LDA off_smb2_main_area_frenzy_enemy_ids-8,x  ; note that it starts at 8, thus weird address here
    LDY #$05
bra_smb2_main_check_existing_frenzy_enemy:
    DEY  ; check regular slots of enemy object buffer
    BMI bra_smb2_main_store_area_frenzy_queue  ; if all slots checked and enemy object not found, branch to store
    CMP Enemy_ID,y  ; check for enemy object in buffer versus frenzy object
    BNE bra_smb2_main_check_existing_frenzy_enemy
    LDA #$00  ; if enemy object already present, nullify queue and leave
bra_smb2_main_store_area_frenzy_queue:
    STA EnemyFrenzyQueue  ; store enemy into frenzy queue
    RTS

; --------------------------------
; $06 - used by CloudLedge to store length

handler_smb2_main_set_area_style:
    LDA AreaStyle  ; load level object style and jump to the right sub
    JSR sub_smb2_main_dispatch_inline_handler
    .word handler_smb2_main_draw_tree_ledge  ; also used for cloud bonus levels
    .word handler_smb2_main_cloud_ledge
    .word handler_smb2_main_draw_bullet_bill_cannon

handler_smb2_main_draw_tree_ledge:
    JSR sub_smb2_main_get_large_area_object_attributes  ; get row and length of green ledge
    LDA AreaObjectLength,x  ; check length counter for expiration
    BEQ bra_smb2_main_render_tree_ledge_end
    BPL bra_smb2_main_render_tree_ledge_middle
    TYA
    STA AreaObjectLength,x  ; store lower nybble into buffer flag as length of ledge
    LDA CurrentPageLoc
    ORA CurrentColumnPos  ; are we at the start of the level?
    BEQ bra_smb2_main_render_tree_ledge_middle
    LDA #$16  ; render start of tree ledge
    JMP bra_smb2_main_render_ledge_without_stem
bra_smb2_main_render_tree_ledge_middle:
    LDX $07
    LDA #$17  ; render middle of tree ledge
    STA MetatileBuffer,x  ; note that this is also used if ledge position is
    LDA #$4c  ; at the start of level for continuous effect
    JMP loc_smb2_main_render_ledge_stem  ; now render the part underneath
bra_smb2_main_render_tree_ledge_end:
    LDA #$18  ; render end of tree ledge
    JMP bra_smb2_main_render_ledge_without_stem

; note: This is the style utilized by world 8-3 and part of world 8-2, and not to
; be confused with the cloud-type bonus levels full of coins found throughout the game
handler_smb2_main_cloud_ledge:
    JSR sub_smb2_main_check_large_area_object_length  ; get cloud dimensions
    STY $06  ; store length here for now
    BCC bra_smb2_main_end_cloud
    LDA AreaObjectLength,x  ; divide length by 2 and store elsewhere
    LSR
    STA MushroomLedgeHalfLen,x
    LDA #$8a  ; render start of cloud
    JMP bra_smb2_main_render_ledge_without_stem
bra_smb2_main_end_cloud:
    LDA #$8c  ; if at the end, render end of cloud
    LDY AreaObjectLength,x
    BEQ bra_smb2_main_render_ledge_without_stem
    LDA MushroomLedgeHalfLen,x  ; get divided length and store where length
    STA $06  ; was stored originally
    LDX $07
    LDA #$8b
    STA MetatileBuffer,x  ; render middle of cloud
    RTS

loc_smb2_main_render_ledge_stem:
    INX
    LDY #$0f  ; set $0f to render all way down
    JMP sub_smb2_main_render_under_part  ; now render the support of the tree ledge
bra_smb2_main_render_ledge_without_stem:
    LDX $07  ; load row of ledge
    LDY #$00  ; set 0 for no bottom on this part
    JMP sub_smb2_main_render_under_part

; --------------------------------

; tiles used by pulleys and rope object
tbl_smb2_main_pulley_rope_metatiles:
    .byte $42, $41, $43

handler_smb2_main_draw_pulley_rope:
    JSR sub_smb2_main_check_large_area_object_length  ; get length of pulley/rope object
    LDY #$00  ; initialize metatile offset
    BCS bra_smb2_main_render_pulley_rope_metatile  ; if starting, render left pulley
    INY
    LDA AreaObjectLength,x  ; if not at the end, render rope
    BNE bra_smb2_main_render_pulley_rope_metatile
    INY  ; otherwise render right pulley
bra_smb2_main_render_pulley_rope_metatile:
    LDA tbl_smb2_main_pulley_rope_metatiles,y
    STA MetatileBuffer  ; render at the top of the screen
loc_smb2_main_exit_mushroom_ledge:
    RTS  ; and leave

; --------------------------------
; $06 - used to store upper limit of rows for CastleObject

tbl_smb2_main_castle_structure_metatiles:
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

handler_smb2_main_draw_castle_structure:
    JSR sub_smb2_main_get_large_area_object_attributes  ; save lower nybble as starting row
    STY $07  ; if starting row is above $0a, game will crash!!!
    LDY #$04
    JSR sub_smb2_main_check_fixed_large_area_object_length  ; load length of castle if not already loaded
    TXA
    PHA  ; save obj buffer offset to stack
    LDY AreaObjectLength,x  ; use current length as offset for castle data
    LDX $07  ; begin at starting row
    LDA #$0b
    STA $06  ; load upper limit of number of rows to print
bra_smb2_main_render_castle_column_loop:
    LDA tbl_smb2_main_castle_structure_metatiles,y  ; load current byte using offset
    STA MetatileBuffer,x
    INX  ; store in buffer and increment buffer offset
    LDA $06
    BEQ bra_smb2_main_check_castle_floor_row  ; have we reached upper limit yet?
    INY  ; if not, increment column-wise
    INY  ; to byte in next row
    INY
    INY
    INY
    DEC $06  ; move closer to upper limit
bra_smb2_main_check_castle_floor_row:
    CPX #$0b  ; have we reached the row just before floor?
    BNE bra_smb2_main_render_castle_column_loop  ; if not, go back and do another row
    PLA
    TAX  ; get obj buffer offset from before
    LDA CurrentPageLoc
    BEQ bra_smb2_main_exit_castle_object  ; if we're at page 0, we do not need to do anything else
    LDA AreaObjectLength,x  ; check length
    CMP #$01  ; if length almost about to expire, put brick at floor
    BEQ bra_smb2_main_place_castle_player_stop_block
    LDY $07  ; check starting row for tall castle ($00)
    BNE bra_smb2_main_check_short_castle_column
    CMP #$03  ; if found, then check to see if we're at the second column
    BEQ bra_smb2_main_place_castle_player_stop_block
bra_smb2_main_check_short_castle_column:
    CMP #$02  ; if not tall castle, check to see if we're at the third column
    BNE bra_smb2_main_exit_castle_object  ; if we aren't and the castle is tall, don't create flag yet
    JSR sub_smb2_main_get_area_object_x_position  ; otherwise, obtain and save horizontal pixel coordinate
    PHA
    JSR sub_smb2_main_find_empty_enemy_slot  ; find an empty place on the enemy object buffer
    PLA
    STA Enemy_X_Position,x  ; then write horizontal coordinate for star flag
    LDA CurrentPageLoc
    STA Enemy_PageLoc,x  ; set page location for star flag
    LDA #$01
    STA Enemy_Y_HighPos,x  ; set vertical high byte
    STA Enemy_Flag,x  ; set flag for buffer
    LDA #$90
    STA Enemy_Y_Position,x  ; set vertical coordinate
    LDA #StarFlagObject  ; set star flag value in buffer itself
    STA Enemy_ID,x
    RTS
bra_smb2_main_place_castle_player_stop_block:
    LDY #$50  ; put brick at floor to stop player at end of level
    STY MetatileBuffer+10  ; this is only done if we're on the second column
bra_smb2_main_exit_castle_object:
    RTS

; --------------------------------

handler_smb2_main_draw_water_pipe:
    JSR sub_smb2_main_get_large_area_object_attributes  ; get row and lower nybble
    LDY AreaObjectLength,x  ; get length (residual code, water pipe is 1 col thick)
    LDX $07  ; get row
    LDA #$6d
    STA MetatileBuffer,x  ; draw something here and below it
    LDA #$6e
    STA MetatileBuffer+1,x
    RTS

; --------------------------------
; $05 - used to store length of vertical shaft in RenderSidewaysPipe
; $06 - used to store leftover horizontal length in RenderSidewaysPipe
; and vertical length in VerticalPipe and GetPipeHeight

handler_smb2_main_draw_intro_pipe:
    LDY #$03  ; check if length set, if not set, set it
    JSR sub_smb2_main_check_fixed_large_area_object_length
    LDY #$0a  ; set fixed value and render the sideways part
    JSR sub_smb2_main_render_sideways_pipe
    BCS bra_smb2_main_exit_intro_pipe  ; if carry flag set, not time to draw vertical pipe part
    LDX #$06  ; blank everything above the vertical pipe part
bra_smb2_main_clear_above_intro_pipe_loop:
    LDA #$00  ; all the way to the top of the screen
    STA MetatileBuffer,x  ; because otherwise it will look like exit pipe
    DEX
    BPL bra_smb2_main_clear_above_intro_pipe_loop
    LDA off_smb2_main_vertical_pipe_metatiles,y  ; draw the end of the vertical pipe part
    STA MetatileBuffer+7
bra_smb2_main_exit_intro_pipe:
    RTS

off_smb2_main_side_pipe_shaft_metatiles:
    .byte $15, $14  ; used to control whether or not vertical pipe shaft
    .byte $00, $00  ; is drawn, and if so, controls the metatile number
tbl_smb2_main_side_pipe_top_metatiles:
    .byte $15, $1b  ; top part of sideways part of pipe
    .byte $1a, $19
tbl_smb2_main_side_pipe_bottom_metatiles:
    .byte $15, $1e  ; bottom part of sideways part of pipe
    .byte $1d, $1c

handler_smb2_main_draw_exit_pipe:
    LDY #$03  ; check if length set, if not set, set it
    JSR sub_smb2_main_check_fixed_large_area_object_length
    JSR sub_smb2_main_get_large_area_object_attributes  ; get vertical length, then plow on through RenderSidewaysPipe

sub_smb2_main_render_sideways_pipe:
    DEY  ; decrement twice to make room for shaft at bottom
    DEY  ; and store here for now as vertical length
    STY $05
    LDY AreaObjectLength,x  ; get length left over and store here
    STY $06
    LDX $05  ; get vertical length plus one, use as buffer offset
    INX
    LDA off_smb2_main_side_pipe_shaft_metatiles,y  ; check for value $00 based on horizontal offset
    CMP #$00
    BEQ bra_smb2_main_render_side_pipe_end  ; if found, do not draw the vertical pipe shaft
    LDX #$00
    LDY $05  ; init buffer offset and get vertical length
    JSR sub_smb2_main_render_under_part  ; and render vertical shaft using tile number in A
    CLC  ; clear carry flag to be used by IntroPipe
bra_smb2_main_render_side_pipe_end:
    LDY $06  ; render side pipe part at the bottom
    LDA tbl_smb2_main_side_pipe_top_metatiles,y
    STA MetatileBuffer,x  ; note that the pipe parts are stored
    LDA tbl_smb2_main_side_pipe_bottom_metatiles,y  ; backwards horizontally
    STA MetatileBuffer+1,x
    RTS

off_smb2_main_vertical_pipe_metatiles:
    .byte $11, $10  ; used by pipes that lead somewhere
    .byte $15, $14
    .byte $13, $12  ; used by decoration pipes
    .byte $15, $14

handler_smb2_main_draw_vertical_pipe:
    JSR sub_smb2_main_get_pipe_height
    LDA $00  ; check to see if value was nullified earlier
    BEQ bra_smb2_main_skip_piranha_plant  ; (if d3, the usage control bit of second byte, was set)
    INY
    INY
    INY
    INY  ; add four if usage control bit was not set
bra_smb2_main_skip_piranha_plant:
    TYA  ; save value in stack
    PHA
    LDY AreaObjectLength,x  ; if on second column of pipe, branch
    BEQ bra_smb2_main_render_vertical_pipe  ; (because we only need to do this once)
    JSR sub_smb2_main_find_empty_enemy_slot  ; check for an empty moving data buffer space
    BCS bra_smb2_main_render_vertical_pipe  ; if not found, too many enemies, thus skip
    LDA #PiranhaPlant
    JSR sub_smb2_main_setup_piranha_plant

bra_smb2_main_render_vertical_pipe:
    PLA  ; get value saved earlier and use as Y
    TAY
    LDX $07  ; get buffer offset
    LDA off_smb2_main_vertical_pipe_metatiles,y  ; draw the appropriate pipe with the Y we loaded earlier
    STA MetatileBuffer,x  ; render the top of the pipe
    INX
    LDA off_smb2_main_vertical_pipe_metatiles+2,y  ; render the rest of the pipe
    LDY $06  ; subtract one from length and render the part underneath
    DEY
    JMP sub_smb2_main_render_under_part

sub_smb2_main_get_pipe_height:
    LDY #$01  ; check for length loaded, if not, load
    JSR sub_smb2_main_check_fixed_large_area_object_length  ; pipe length of 2 (horizontal)
    JSR sub_smb2_main_get_large_area_object_attributes
    TYA  ; get saved lower nybble as height
    AND #$07  ; save only the three lower bits as
    STA $06  ; vertical length, then load Y with
    LDY AreaObjectLength,x  ; length left over
    RTS

sub_smb2_main_setup_piranha_plant:
    STA Enemy_ID,x
    JSR sub_smb2_main_get_area_object_x_position  ; get horizontal pixel coordinate
    CLC
    ADC #$08  ; add eight to put the piranha plant in the center
    STA Enemy_X_Position,x  ; store as enemy's horizontal coordinate
    LDA CurrentPageLoc  ; add carry to current page number
    ADC #$00
    STA Enemy_PageLoc,x  ; store as enemy's page coordinate
    LDA #$01
    STA Enemy_Y_HighPos,x
    STA Enemy_Flag,x  ; activate enemy flag
    JSR sub_smb2_main_get_area_object_y_position  ; get piranha plant's vertical coordinate and store here
    STA Enemy_Y_Position,x
    JMP handler_smb2_main_initialize_piranha_plant

sub_smb2_main_find_empty_enemy_slot:
    LDX #$00  ; start at first enemy slot
bra_smb2_main_find_empty_enemy_slot_loop:
    CLC  ; clear carry flag by default
    LDA Enemy_Flag,x  ; check enemy buffer for nonzero
    BEQ bra_smb2_main_exit_empty_enemy_slot_search  ; if zero, leave
    INX
    CPX #$05  ; if nonzero, check next value
    BNE bra_smb2_main_find_empty_enemy_slot_loop
bra_smb2_main_exit_empty_enemy_slot_search:
    RTS  ; if all values nonzero, carry flag is set

; --------------------------------

handler_smb2_main_water_hole:
    JSR sub_smb2_main_check_large_area_object_length  ; get low nybble and save as length
    LDA #$86  ; render waves
    STA MetatileBuffer+10
    LDX #$0b
    LDY #$01  ; now render the water underneath
    LDA #$87
    JMP sub_smb2_main_render_under_part

handler_smb2_main_draw_high_question_block_row:
    LDA #$03  ; start on the fourth row
    .byte $2c  ; BIT instruction opcode

handler_smb2_main_draw_low_question_block_row:
    LDA #$07  ; start on the eighth row
    PHA  ; save whatever row to the stack for now
    JSR sub_smb2_main_check_large_area_object_length  ; get low nybble and save as length
    PLA
    TAX  ; render question boxes with coins
    LDA #$c0
    STA MetatileBuffer,x
    RTS

; --------------------------------
