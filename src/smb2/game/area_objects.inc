handler_smb2_main_draw_high_bridge:
    LDA #$06  ; start on the seventh row from top of screen
    .byte $2c  ; BIT instruction opcode

handler_smb2_main_draw_middle_bridge:
    LDA #$07  ; start on the eighth row
    .byte $2c  ; BIT instruction opcode

handler_smb2_main_draw_low_bridge:
    LDA #$09  ; start on the tenth row
    PHA  ; save whatever row to the stack for now
    JSR sub_smb2_main_check_large_area_object_length  ; get low nybble and save as length
    PLA
    TAX  ; render bridge railing
    LDA #$0b
    STA MetatileBuffer,x
    INX
    LDY #$00  ; now render the bridge itself
    LDA #$64
    JMP sub_smb2_main_render_under_part

; --------------------------------

handler_smb2_main_residual_flag_balls:
    JSR sub_smb2_main_get_large_area_object_attributes  ; get low nybble from object byte
    LDX #$02  ; render flag balls on third row from top
    LDA #$6f  ; of screen downwards based on low nybble
    JMP sub_smb2_main_render_under_part

; --------------------------------

handler_smb2_main_draw_flagpole_object:
    LDA #$21  ; render flagpole ball on top
    STA MetatileBuffer
    LDX #$01  ; now render the flagpole shaft
    LDY #$08
    LDA #$22
    JSR sub_smb2_main_render_under_part
    LDA #$62  ; render solid block at the bottom
    STA MetatileBuffer+10
    JSR sub_smb2_main_get_area_object_x_position
    SEC  ; get pixel coordinate of where the flagpole is,
    SBC #$08  ; subtract eight pixels and use as horizontal
    STA Enemy_X_Position+5  ; coordinate for the flag
    LDA CurrentPageLoc
    SBC #$00  ; subtract borrow from page location and use as
    STA Enemy_PageLoc+5  ; page location for the flag
    LDA #$30
    STA Enemy_Y_Position+5  ; set vertical coordinate for flag
    LDA #$b0
    STA FlagpoleFNum_Y_Pos  ; set initial vertical coordinate for flagpole's floatey number
    LDA #FlagpoleFlagObject
    STA Enemy_ID+5  ; set flag identifier, note that identifier and coordinates
    INC Enemy_Flag+5  ; use last space in enemy object buffer
    RTS

; --------------------------------

handler_smb2_main_draw_endless_rope:
    LDX #$00  ; render rope from the top to the bottom of screen
    LDY #$0f
    JMP loc_smb2_main_draw_rope_segment

handler_smb2_main_draw_balance_platform_rope:
    TXA  ; save object buffer offset for now
    PHA
    LDX #$01  ; blank out all from second row to the bottom
    LDY #$0f  ; with blank used for balance platform rope
    LDA #$44
    JSR sub_smb2_main_render_under_part
    PLA  ; get back object buffer offset
    TAX
    JSR sub_smb2_main_get_large_area_object_attributes  ; get vertical length from lower nybble
    LDX #$01
loc_smb2_main_draw_rope_segment:
    LDA #$40  ; render the actual rope
    JMP sub_smb2_main_render_under_part

; --------------------------------

off_smb2_main_coin_metatiles_by_area_type:
    .byte $c4, $c3, $c3, $c3

handler_smb2_main_draw_coin_row:
    LDY AreaType  ; get area type
    LDA off_smb2_main_coin_metatiles_by_area_type,y  ; load appropriate coin metatile
    JMP loc_smb2_main_draw_horizontal_object_row

; --------------------------------

tbl_smb2_main_castle_object_rows:
    .byte $06, $07, $08

tbl_smb2_main_castle_object_metatiles:
    .byte $c6, $0c, $89

handler_smb2_main_draw_castle_bridge:
    LDY #$0c  ; load length of 13 columns
    JSR sub_smb2_main_check_fixed_large_area_object_length
    JMP handler_smb2_main_draw_chain

handler_smb2_main_draw_axe:
    LDA #$08  ; load bowser's palette into sprite portion of palette
    STA VRAM_Buffer_AddrCtrl

handler_smb2_main_draw_chain:
    LDY $00  ; get value loaded earlier from decoder
    LDX tbl_smb2_main_castle_object_rows-2,y  ; get appropriate row and metatile for object
    LDA tbl_smb2_main_castle_object_metatiles-2,y
    JMP loc_smb2_main_draw_single_column_object

handler_smb2_main_draw_empty_block:
    JSR sub_smb2_main_get_large_area_object_attributes  ; get row location
    LDX $07
    LDA #$c5
loc_smb2_main_draw_single_column_object:
    LDY #$00  ; column length of 1
    JMP sub_smb2_main_render_under_part

; --------------------------------

tbl_smb2_main_solid_block_metatiles:
    .byte $6a, $62, $62, $63

tbl_smb2_main_brick_metatiles:
    .byte $1f, $4f, $50, $50
    .byte $88  ; used only by row of bricks object

handler_smb2_main_draw_brick_row:
    LDY AreaType  ; load area type obtained from area offset pointer
    LDA CloudTypeOverride  ; check for cloud type override
    BEQ bra_smb2_main_draw_brick_row_metatiles
    LDY #$04  ; if cloud type, override area type
bra_smb2_main_draw_brick_row_metatiles:
    LDA tbl_smb2_main_brick_metatiles,y  ; get appropriate metatile
    JMP loc_smb2_main_draw_horizontal_object_row  ; and go render it

handler_smb2_main_draw_solid_block_row:
    LDY AreaType  ; load area type obtained from area offset pointer
    LDA tbl_smb2_main_solid_block_metatiles,y  ; get metatile
loc_smb2_main_draw_horizontal_object_row:
    PHA  ; store metatile here
    JSR sub_smb2_main_check_large_area_object_length  ; get row number, load length
loc_smb2_main_draw_metatile_row:
    LDX $07
    LDY #$00  ; set vertical height of 1
    PLA
    JMP sub_smb2_main_render_under_part  ; render object

handler_smb2_main_draw_brick_column:
    LDY AreaType  ; load area type obtained from area offset
    LDA tbl_smb2_main_brick_metatiles,y  ; get metatile (no cloud override as for row)
    JMP loc_smb2_main_prepare_vertical_object

handler_smb2_main_draw_solid_block_column:
    LDY AreaType  ; load area type obtained from area offset
    LDA tbl_smb2_main_solid_block_metatiles,y  ; get metatile
loc_smb2_main_prepare_vertical_object:
    PHA  ; save metatile to stack for now
    JSR sub_smb2_main_get_large_area_object_attributes  ; get length and row
    PLA  ; restore metatile
    LDX $07  ; get starting row
    JMP sub_smb2_main_render_under_part  ; now render the column

; --------------------------------

handler_smb2_main_draw_bullet_bill_cannon:
    JSR sub_smb2_main_get_large_area_object_attributes  ; get row and length of bullet bill cannon
    LDX $07  ; start at first row
    LDA #$65  ; render bullet bill cannon
    STA MetatileBuffer,x
    INX
    DEY  ; done yet?
    BMI bra_smb2_main_register_bullet_bill_cannon
    LDA #$66  ; if not, render middle part
    STA MetatileBuffer,x
    INX
    DEY  ; done yet?
    BMI bra_smb2_main_register_bullet_bill_cannon
    LDA #$67  ; if not, render bottom until length expires
    JSR sub_smb2_main_render_under_part
bra_smb2_main_register_bullet_bill_cannon:
    LDX Cannon_Offset  ; get offset for data used by cannons and whirlpools
    JSR sub_smb2_main_get_area_object_y_position  ; get proper vertical coordinate for cannon
    STA Cannon_Y_Position,x  ; and store it here
    LDA CurrentPageLoc
    STA Cannon_PageLoc,x  ; store page number for cannon here
    JSR sub_smb2_main_get_area_object_x_position  ; get proper horizontal coordinate for cannon
    STA Cannon_X_Position,x  ; and store it here
    INX
    CPX #$06  ; increment and check offset
    BCC bra_smb2_main_store_cannon_slot_offset  ; if not yet reached sixth cannon, branch to save offset
    LDX #$00  ; otherwise initialize it
bra_smb2_main_store_cannon_slot_offset:
    STX Cannon_Offset  ; save new offset and leave
    RTS

; --------------------------------

off_smb2_main_staircase_heights:
    .byte $07, $07, $06, $05, $04, $03, $02, $01, $00

off_smb2_main_staircase_start_rows:
    .byte $03, $03, $04, $05, $06, $07, $08, $09, $0a

handler_smb2_main_draw_staircase:
    JSR sub_smb2_main_check_large_area_object_length  ; check and load length
    BCC bra_smb2_main_render_next_stair_step  ; if length already loaded, skip init part
    LDA #$09  ; start past the end for the bottom
    STA StaircaseControl  ; of the staircase
bra_smb2_main_render_next_stair_step:
    DEC StaircaseControl  ; move onto next step (or first if starting)
    LDY StaircaseControl
    LDX off_smb2_main_staircase_start_rows,y  ; get starting row and height to render
    LDA off_smb2_main_staircase_heights,y
    TAY
    LDA #$62  ; now render solid block staircase
    JMP sub_smb2_main_render_under_part

; --------------------------------

handler_smb2_main_draw_jumpspring:
    JSR sub_smb2_main_get_large_area_object_attributes
    JSR sub_smb2_main_find_empty_enemy_slot  ; find empty space in enemy object buffer
    BCS bra_smb2_main_skip_jumpspring_setup  ; if none, cancel (potentially problematic!)
    JSR sub_smb2_main_get_area_object_x_position  ; get horizontal coordinate for jumpspring
    STA Enemy_X_Position,x  ; and store
    LDA CurrentPageLoc  ; store page location of jumpspring
    STA Enemy_PageLoc,x
    JSR sub_smb2_main_get_area_object_y_position  ; get vertical coordinate for jumpspring
    STA Enemy_Y_Position,x  ; and store
    STA Jumpspring_FixedYPos,x  ; store as permanent coordinate here
    LDA #JumpspringObject
    STA Enemy_ID,x  ; write jumpspring object to enemy object buffer
    LDY #$01
    STY Enemy_Y_HighPos,x  ; store vertical high byte
    INC Enemy_Flag,x  ; set flag for enemy object buffer
    LDX $07
    LDA #$68  ; draw metatiles in two rows where jumpspring is
    STA MetatileBuffer,x
    LDA #$69
    STA MetatileBuffer+1,x
bra_smb2_main_skip_jumpspring_setup:
    RTS

; --------------------------------
; $07 - used to save ID of brick object

handler_smb2_main_draw_hidden_extra_life_block:
    LDA Hidden1UpFlag  ; if flag not set, do not render object
    BEQ bra_smb2_main_finish_item_block_decode
    LDA #$00  ; if set, init for the next one
    STA Hidden1UpFlag
    JMP handler_smb2_main_draw_item_brick  ; jump to code shared with unbreakable bricks

handler_smb2_main_draw_question_block:
    JSR sub_smb2_main_get_area_object_id  ; get value from level decoder routine
    JMP loc_smb2_main_draw_question_or_brick_block  ; go to render it

handler_smb2_main_draw_coin_brick:
    LDA #$00  ; initialize multi-coin timer flag
    STA BrickCoinTimerFlag

handler_smb2_main_draw_item_brick:
    JSR sub_smb2_main_get_area_object_id  ; save area object ID
    STY $07
    LDA #$00  ; load default adder for bricks with lines
    LDY AreaType  ; check level type for ground level
    DEY
    BEQ bra_smb2_main_select_ground_brick_metatile  ; if ground type, do not start with 6
    LDA #$06  ; otherwise use adder for bricks without lines
bra_smb2_main_select_ground_brick_metatile:
    CLC  ; add object ID to adder
    ADC $07
    TAY  ; use as offset for metatile
loc_smb2_main_draw_question_or_brick_block:
    LDA tbl_smb2_main_brick_and_question_block_metatiles,y  ; get appropriate metatile for brick (question block
    PHA  ; if branched to here from question block routine)
    JSR sub_smb2_main_get_large_area_object_attributes  ; get row from location byte
    JMP loc_smb2_main_draw_metatile_row  ; now render the object

sub_smb2_main_get_area_object_id:
    LDA $00  ; get value saved from area parser routine
    SEC
    SBC #$00  ; possibly residual code
    TAY  ; save to Y
bra_smb2_main_finish_item_block_decode:
    RTS

; --------------------------------

tbl_smb2_main_hole_metatiles:
    .byte $87, $00, $00, $00

handler_smb2_main_empty_hole:
    JSR sub_smb2_main_check_large_area_object_length  ; get lower nybble and save as length
    BCC bra_smb2_main_render_hole_metatiles  ; skip this part if length already loaded
    LDA AreaType  ; check for water type level
    BNE bra_smb2_main_render_hole_metatiles  ; if not water type, skip this part
    LDX Whirlpool_Offset  ; get offset for data used by cannons and whirlpools
    JSR sub_smb2_main_get_area_object_x_position  ; get proper vertical coordinate of where we're at
    SEC
    SBC #$10  ; subtract 16 pixels
    STA Whirlpool_LeftExtent,x  ; store as left extent of whirlpool
    LDA CurrentPageLoc  ; get page location of where we're at
    SBC #$00  ; subtract borrow
    STA Whirlpool_PageLoc,x  ; save as page location of whirlpool
    INY
    INY  ; increment length by 2
    TYA
    ASL  ; multiply by 16 to get size of whirlpool
    ASL  ; note that whirlpool will always be
    ASL  ; two blocks bigger than actual size of hole
    ASL  ; and extend one block beyond each edge
    STA Whirlpool_Length,x  ; save size of whirlpool here
    INX
    CPX #$05  ; increment and check offset
    BCC bra_smb2_main_store_whirlpool_slot_offset  ; if not yet reached fifth whirlpool, branch to save offset
    LDX #$00  ; otherwise initialize it
bra_smb2_main_store_whirlpool_slot_offset:
    STX Whirlpool_Offset  ; save new offset here
bra_smb2_main_render_hole_metatiles:
    LDX AreaType  ; get appropriate metatile, then
    LDA tbl_smb2_main_hole_metatiles,x  ; render the hole proper
    LDX #$08
    LDY #$0f  ; start at ninth row and go to bottom, run RenderUnderPart

; --------------------------------

sub_smb2_main_render_under_part:
    STY AreaObjectHeight  ; store vertical length to render
    LDY MetatileBuffer,x  ; check current spot to see if there's something
    BEQ bra_smb2_main_write_under_part_metatile  ; we need to keep, if nothing, go ahead
    CPY #$17
    BEQ bra_smb2_main_advance_under_part_row  ; if middle part (tree ledge), wait until next row
    CPY #$8b
    BEQ bra_smb2_main_advance_under_part_row  ; if middle part (cloud ledge), wait until next row
    CPY #$c0
    BEQ bra_smb2_main_write_under_part_metatile  ; if question block w/ coin, overwrite
    CPY #$c0
    BCS bra_smb2_main_advance_under_part_row  ; if any other metatile with palette 3, wait until next row
bra_smb2_main_write_under_part_metatile:
    STA MetatileBuffer,x  ; render contents of A from routine that called this
bra_smb2_main_advance_under_part_row:
    INX
    CPX #$0d  ; stop rendering if we're at the bottom of the screen
    BCS bra_smb2_main_exit_render_under_part
    LDY AreaObjectHeight  ; decrement, and stop rendering if there is no more length
    DEY
    BPL sub_smb2_main_render_under_part
bra_smb2_main_exit_render_under_part:
    RTS

sub_smb2_main_check_large_area_object_length:
    JSR sub_smb2_main_get_large_area_object_attributes  ; get row location and size (length if branched to from here)

sub_smb2_main_check_fixed_large_area_object_length:
    LDA AreaObjectLength,x  ; check for set length counter
    CLC  ; clear carry flag for not just starting
    BPL bra_smb2_main_exit_object_length_setup  ; if counter not set, load it, otherwise leave alone
    TYA  ; save length into length counter
    STA AreaObjectLength,x
    SEC  ; set carry flag if just starting
bra_smb2_main_exit_object_length_setup:
    RTS

sub_smb2_main_get_large_area_object_attributes:
    LDY AreaObjOffsetBuffer,x  ; get offset saved from area obj decoding routine
    LDA (AreaData),y  ; get first byte of level object
    AND #%00001111
    STA $07  ; save row location
    INY
    LDA (AreaData),y  ; get next byte, save lower nybble (length or height)
    AND #%00001111  ; as Y, then leave
    TAY
    RTS

; --------------------------------

sub_smb2_main_get_area_object_x_position:
    LDA CurrentColumnPos  ; multiply current offset where we're at by 16
    ASL  ; to obtain horizontal pixel coordinate
    ASL
    ASL
    ASL
    RTS

; --------------------------------

sub_smb2_main_get_area_object_y_position:
    LDA $07  ; multiply value by 16
    ASL
    ASL  ; this will give us the proper vertical pixel coordinate
    ASL
    ASL
    CLC
    ADC #32  ; add 32 pixels for the status bar
    RTS

; -------------------------------------------------------------------------------------
; $06-$07 - used to store block buffer address used as indirect

tbl_smb2_main_block_buffer_addresses:
    .byte <Block_Buffer_1, <Block_Buffer_2
    .byte >Block_Buffer_1, >Block_Buffer_2

sub_smb2_main_get_block_buffer_addr:
    PHA  ; take value of A, save
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    TAY  ; use nybble as pointer to high byte
    LDA tbl_smb2_main_block_buffer_addresses+2,y  ; of indirect here
    STA $07
    PLA
    AND #%00001111  ; pull from stack, mask out high nybble
    CLC
    ADC tbl_smb2_main_block_buffer_addresses,y  ; add to low byte
    STA $06  ; store here and leave
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_game_mode_subs:
    LDA OperMode_Task
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_game_mode_disk_routines
    .word handler_smb2_main_initialize_area
    .word handler_smb2_main_run_screen_task
    .word handler_smb2_main_secondary_game_setup
    .word sub_smb2_main_game_core_routine

sub_smb2_main_game_core_routine:
    JSR sub_smb2_main_game_routines  ; execute one of many possible subs
    LDA OperMode_Task  ; check major task of operating mode
    CMP #$04  ; if we are supposed to be here,
    BCS bra_smb2_main_run_game_engine  ; branch to the game engine itself
    RTS

bra_smb2_main_run_game_engine:
    JSR sub_smb2_main_process_fireballs_and_bubbles  ; process fireballs and air bubbles
    LDX #$00
bra_smb2_main_process_enemy_slots:
    STX ObjectOffset  ; put incremented offset in X as enemy object offset
    JSR sub_smb2_main_enemies_and_loops_core  ; process enemy objects
    JSR sub_smb2_main_floatey_numbers_routine  ; process floatey numbers
    INX
    CPX #$06  ; do these two subroutines until the whole buffer is done
    BNE bra_smb2_main_process_enemy_slots
    JSR sub_smb2_main_get_player_offscreen_bits  ; get offscreen bits for player object
    JSR sub_smb2_main_relative_player_position  ; get relative coordinates for player object
    JSR sub_smb2_main_render_player_graphics  ; draw the player
    JSR sub_smb2_main_update_block_object_metatile  ; replace block objects with metatiles if necessary
    LDX #$01
    STX ObjectOffset  ; set offset for second
    JSR sub_smb2_main_block_objects_core  ; process second block object
    DEX
    STX ObjectOffset  ; set offset for first
    JSR sub_smb2_main_block_objects_core  ; process first block object
    JSR sub_smb2_main_misc_objects_core  ; process misc objects (hammer, jumping coins)
    JSR sub_smb2_main_process_cannons  ; process bullet bill cannons
    JSR sub_smb2_main_process_whirlpool_pull  ; process whirlpools
    JSR sub_smb2_main_flagpole_routine  ; process the flagpole
    JSR sub_smb2_main_run_game_timer  ; count down the game timer
    JSR sub_smb2_main_color_rotation  ; cycle one of the background colors
    LDA FileListNumber
    BEQ bra_smb2_main_no_wind  ; if in worlds 1-4, skip ahead
    JSR sub_smb2_data4_simulate_wind  ; otherwise, simulate wind where needed
bra_smb2_main_no_wind:
    LDA Player_Y_HighPos
    CMP #$02  ; if player is below the screen, don't bother with the music
    BPL bra_smb2_main_update_invincibility_palette
    LDA StarInvincibleTimer  ; if star mario invincibility timer at zero,
    BEQ bra_smb2_main_reset_star_palette  ; skip this part
    CMP #$04
    BNE bra_smb2_main_update_invincibility_palette  ; if not yet at a certain point, continue
    LDA IntervalTimerControl  ; if interval timer not yet expired,
    BNE bra_smb2_main_update_invincibility_palette  ; branch ahead, don't bother with the music
    JSR sub_smb2_main_get_area_music  ; to re-attain appropriate level music
bra_smb2_main_update_invincibility_palette:
    LDY StarInvincibleTimer  ; get invincibility timer
    LDA FrameCounter  ; get frame counter
    CPY #$08  ; if timer still above certain point,
    BCS bra_smb2_main_select_palette_cycle_rate  ; branch to cycle player's palette quickly
    LSR  ; otherwise, divide by 8 to cycle every eighth frame
    LSR
bra_smb2_main_select_palette_cycle_rate:
    LSR  ; if branched here, divide by 2 to cycle every other frame
    JSR sub_smb2_main_cycle_player_palette  ; do sub to cycle the palette (note: shares fire flower code)
    JMP loc_smb2_main_save_button_history  ; then skip this sub to finish up the game engine
bra_smb2_main_reset_star_palette:
    JSR sub_smb2_main_reset_star_palette_cycle  ; do sub to clear player's palette bits in attributes
loc_smb2_main_save_button_history:
    LDA A_B_Buttons  ; save current A and B button
    STA PreviousA_B_Buttons  ; into temp variable to be used on next frame
    LDA #$00
    STA Left_Right_Buttons  ; nullify left and right buttons temp variable
sub_smb2_main_update_scroll_variables:
    LDA VRAM_Buffer_AddrCtrl
    CMP #$06  ; if vram address controller set to 6
    BEQ bra_smb2_main_exit_game_engine  ; then branch to leave
    LDA AreaParserTaskNum  ; otherwise check number of tasks
    BNE bra_smb2_main_run_area_parser
    LDA ScrollThirtyTwo  ; get horizontal scroll in 0-31 or $00-$20 range
    CMP #$20  ; check to see if exceeded $21
    BMI bra_smb2_main_exit_game_engine  ; branch to leave if not
    LDA ScrollThirtyTwo
    SBC #$20  ; otherwise subtract $20 to set appropriately
    STA ScrollThirtyTwo  ; and store
    LDA #$00  ; reset vram buffer offset used in conjunction with
    STA VRAM_Buffer2_Offset  ; level graphics buffer in second VRAM buffer
bra_smb2_main_run_area_parser:
    JSR sub_smb2_main_area_parser_task_handler  ; update the name table with more level graphics
bra_smb2_main_exit_game_engine:
    RTS  ; and after all that, we're finally done!

sub_smb2_main_scroll_handler:
    LDA Player_X_Scroll  ; load value saved here
    CLC
    ADC Platform_X_Scroll  ; add value used by left/right platforms
    STA Player_X_Scroll  ; save as new value here to impose force on scroll
    LDA ScrollLock  ; check scroll lock flag
    BNE bra_smb2_main_clear_scroll_amount  ; skip a bunch of code here if set
    LDA Player_Pos_ForScroll
    CMP #$50  ; check player's horizontal screen position
    BCC bra_smb2_main_clear_scroll_amount  ; if less than 80 pixels to the right, branch
    LDA SideCollisionTimer  ; if timer related to player's side collision
    BNE bra_smb2_main_clear_scroll_amount  ; not expired, branch
    LDY Player_X_Scroll  ; get value and decrement by one
    DEY  ; if value originally set to zero or otherwise
    BMI bra_smb2_main_clear_scroll_amount  ; negative for left movement, branch
    INY
    CPY #$02  ; if value $01, branch and do not decrement
    BCC bra_smb2_main_check_player_near_screen_middle
    DEY  ; otherwise decrement by one
bra_smb2_main_check_player_near_screen_middle:
    LDA Player_Pos_ForScroll
    CMP #$70  ; check player's horizontal screen position
    BCC sub_smb2_main_scroll_screen  ; if less than 112 pixels to the right, branch
    LDY Player_X_Scroll  ; otherwise get original value undecremented

sub_smb2_main_scroll_screen:
    LDA IRQAckFlag
    BNE sub_smb2_main_scroll_screen  ; loop if IRQ has not yet happened
    TYA
    STA ScrollAmount  ; save value here
    CLC
    ADC ScrollThirtyTwo  ; add to value already set here
    STA ScrollThirtyTwo  ; save as new value here
    TYA
    CLC
    ADC ScreenLeft_X_Pos  ; add to left side coordinate
    STA ScreenLeft_X_Pos  ; save as new left side coordinate
    STA HorizontalScroll  ; save here also
    LDA ScreenLeft_PageLoc
    ADC #$00  ; add carry to page location for left
    STA ScreenLeft_PageLoc  ; side of the screen
    AND #$01  ; get LSB of page location
    STA NameTableSelect  ; save as name table select for later use
    JSR sub_smb2_main_get_screen_position
    LDA #$08
    STA ScrollIntervalTimer  ; set scroll timer (residual, not used elsewhere)
    JMP loc_smb2_main_clamp_player_to_screen  ; skip this part
bra_smb2_main_clear_scroll_amount:
    LDA #$00
    STA ScrollAmount  ; initialize value here
loc_smb2_main_clamp_player_to_screen:
    LDX #$00  ; set X for player offset
    JSR sub_smb2_main_get_horizontal_offscreen_bits  ; get horizontal offscreen bits for player
    STA $00  ; save them here
    LDY #$00  ; load default offset (left side)
    ASL  ; if d7 of offscreen bits are set,
    BCS bra_smb2_main_clamp_player_to_screen_edge  ; branch with default offset
    INY  ; otherwise use different offset (right side)
    LDA $00
    AND #%00100000  ; check offscreen bits for d5 set
    BEQ bra_smb2_main_clear_platform_scroll  ; if not set, branch ahead of this part
bra_smb2_main_clamp_player_to_screen_edge:
    LDA ScreenEdge_X_Pos,y  ; get left or right side coordinate based on offset
    SEC
    SBC off_smb2_main_screen_edge_x_offsets,y  ; subtract amount based on offset
    STA Player_X_Position  ; store as player position to prevent movement further
    LDA ScreenEdge_PageLoc,y  ; get left or right page location based on offset
    SBC #$00  ; subtract borrow
    STA Player_PageLoc  ; save as player's page location
    LDA Left_Right_Buttons  ; check saved controller bits
    CMP off_smb2_main_offscreen_joypad_direction_bits,y  ; against bits based on offset
    BEQ bra_smb2_main_clear_platform_scroll  ; if not equal, branch
    LDA #$00
    STA Player_X_Speed  ; otherwise nullify horizontal speed of player
bra_smb2_main_clear_platform_scroll:
    LDA #$00  ; nullify platform force imposed on scroll
    STA Platform_X_Scroll
    RTS

off_smb2_main_screen_edge_x_offsets:
    .byte $00, $10

off_smb2_main_offscreen_joypad_direction_bits:
    .byte $01, $02

; -------------------------------------------------------------------------------------
