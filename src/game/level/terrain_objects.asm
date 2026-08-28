; --------------------------------

handler_water_hole:
    JSR sub_check_large_area_object_length  ; get low nybble and save as length
    LDA #$86  ; render waves
    STA ram_metatile_buffer+10
    LDX #$0b
    LDY #$01  ; now render the water underneath
    LDA #$87
    JMP sub_render_under_part

; --------------------------------

handler_draw_high_question_block_row:
    LDA #$03  ; start on the fourth row
.if con_revision_profile = con_revision_profile_vs
    JMP loc_draw_question_block_row
.else
    .byte $2c  ; BIT instruction opcode
.endif

handler_draw_low_question_block_row:
    LDA #$07  ; start on the eighth row
loc_draw_question_block_row:
    PHA  ; save whatever row to the stack for now
    JSR sub_check_large_area_object_length  ; get low nybble and save as length
    PLA
    TAX  ; render question boxes with coins
    LDA #$c0
    STA ram_metatile_buffer,x
    RTS

; --------------------------------

handler_draw_high_bridge:
    LDA #$06  ; start on the seventh row from top of screen
.if con_revision_profile = con_revision_profile_vs
    JMP loc_draw_bridge
.else
    .byte $2c  ; BIT instruction opcode
.endif

handler_draw_middle_bridge:
    LDA #$07  ; start on the eighth row
.if con_revision_profile = con_revision_profile_vs
    JMP loc_draw_bridge
.else
    .byte $2c  ; BIT instruction opcode
.endif

handler_draw_low_bridge:
    LDA #$09  ; start on the tenth row
loc_draw_bridge:
    PHA  ; save whatever row to the stack for now
    JSR sub_check_large_area_object_length  ; get low nybble and save as length
    PLA
    TAX  ; render bridge railing
    LDA #$0b
    STA ram_metatile_buffer,x
    INX
    LDY #$00  ; now render the bridge itself
    LDA #$63
    JMP sub_render_under_part

; --------------------------------

handler_residual_flag_balls:
    JSR sub_get_large_area_object_attributes  ; get low nybble from object byte
    LDX #$02  ; render flag balls on third row from top
    LDA #$6d  ; of screen downwards based on low nybble
    JMP sub_render_under_part

; --------------------------------

handler_draw_flagpole_object:
    LDA #$24  ; render flagpole ball on top
    STA ram_metatile_buffer
    LDX #$01  ; now render the flagpole shaft
    LDY #$08
    LDA #$25
    JSR sub_render_under_part
    LDA #$61  ; render solid block at the bottom
    STA ram_metatile_buffer+10
    JSR sub_get_area_object_x_position
    SEC  ; get pixel coordinate of where the flagpole is,
    SBC #$08  ; subtract eight pixels and use as horizontal
    STA ram_enemy_x_position+5  ; coordinate for the flag
    LDA ram_current_page_loc
    SBC #$00  ; subtract borrow from page location and use as
    STA ram_enemy_page_loc+5  ; page location for the flag
    LDA #$30
    STA ram_enemy_y_position+5  ; set vertical coordinate for flag
    LDA #$b0
    STA ram_flagpole_f_num_y_pos  ; set initial vertical coordinate for flagpole's floatey number
    LDA #con_flagpole_flag_object
    STA ram_enemy_id+5  ; set flag identifier, note that identifier and coordinates
    INC ram_enemy_flag+5  ; use last space in enemy object buffer
    RTS

; --------------------------------

handler_draw_endless_rope:
    LDX #$00  ; render rope from the top to the bottom of screen
    LDY #$0f
    JMP loc_draw_rope_segment

handler_draw_balance_platform_rope:
    TXA  ; save object buffer offset for now
    PHA
    LDX #$01  ; blank out all from second row to the bottom
    LDY #$0f  ; with blank used for balance platform rope
    LDA #$44
    JSR sub_render_under_part
    PLA  ; get back object buffer offset
    TAX
    JSR sub_get_large_area_object_attributes  ; get vertical length from lower nybble
    LDX #$01
loc_draw_rope_segment:
    LDA #$40  ; render the actual rope
    JMP sub_render_under_part

; --------------------------------

tbl_coin_metatiles_by_area_type:
    .byte $c3, $c2, $c2, $c2

handler_draw_coin_row:
    LDY ram_area_type  ; get area type
    LDA tbl_coin_metatiles_by_area_type,y  ; load appropriate coin metatile
    JMP loc_draw_horizontal_object_row

; --------------------------------

tbl_castle_object_rows:
    .byte $06, $07, $08

tbl_castle_object_metatiles:
    .byte $c5, $0c, $89

handler_draw_castle_bridge:
    LDY #$0c  ; load length of 13 columns
    JSR sub_check_fixed_large_area_object_length
    JMP handler_draw_chain

handler_draw_axe:
    LDA #$08  ; load bowser's palette into sprite portion of palette
    STA ram_vram_buffer_addr_ctrl

handler_draw_chain:
    LDY $00  ; get value loaded earlier from decoder
    LDX tbl_castle_object_rows-2,y  ; get appropriate row and metatile for object
    LDA tbl_castle_object_metatiles-2,y
    JMP loc_draw_single_column_object

handler_draw_empty_block:
    JSR sub_get_large_area_object_attributes  ; get row location
    LDX $07
    LDA #$c4
loc_draw_single_column_object:
    LDY #$00  ; column length of 1
    JMP sub_render_under_part

; --------------------------------

tbl_solid_block_metatiles:
    .byte $69, $61, $61, $62

tbl_brick_metatiles:
    .byte $22, $51, $52, $52
    .byte $88  ; used only by row of bricks object

handler_draw_brick_row:
    LDY ram_area_type  ; load area type obtained from area offset pointer
    LDA ram_cloud_type_override  ; check for cloud type override
    BEQ bra_draw_brick_row_metatiles
    LDY #$04  ; if cloud type, override area type
bra_draw_brick_row_metatiles:
    LDA tbl_brick_metatiles,y  ; get appropriate metatile
    JMP loc_draw_horizontal_object_row  ; and go render it

handler_draw_solid_block_row:
    LDY ram_area_type  ; load area type obtained from area offset pointer
    LDA tbl_solid_block_metatiles,y  ; get metatile
loc_draw_horizontal_object_row:
    PHA  ; store metatile here
    JSR sub_check_large_area_object_length  ; get row number, load length
loc_draw_metatile_row:
    LDX $07
    LDY #$00  ; set vertical height of 1
    PLA
    JMP sub_render_under_part  ; render object

handler_draw_brick_column:
    LDY ram_area_type  ; load area type obtained from area offset
    LDA tbl_brick_metatiles,y  ; get metatile (no cloud override as for row)
    JMP loc_prepare_vertical_object

handler_draw_solid_block_column:
    LDY ram_area_type  ; load area type obtained from area offset
    LDA tbl_solid_block_metatiles,y  ; get metatile
loc_prepare_vertical_object:
    PHA  ; save metatile to stack for now
    JSR sub_get_large_area_object_attributes  ; get length and row
    PLA  ; restore metatile
    LDX $07  ; get starting row
    JMP sub_render_under_part  ; now render the column

; --------------------------------

handler_draw_bullet_bill_cannon:
    JSR sub_get_large_area_object_attributes  ; get row and length of bullet bill cannon
    LDX $07  ; start at first row
    LDA #$64  ; render bullet bill cannon
    STA ram_metatile_buffer,x
    INX
    DEY  ; done yet?
    BMI bra_register_bullet_bill_cannon
    LDA #$65  ; if not, render middle part
    STA ram_metatile_buffer,x
    INX
    DEY  ; done yet?
    BMI bra_register_bullet_bill_cannon
    LDA #$66  ; if not, render bottom until length expires
    JSR sub_render_under_part
bra_register_bullet_bill_cannon:
    LDX ram_cannon_offset  ; get offset for data used by cannons and whirlpools
    JSR sub_get_area_object_y_position  ; get proper vertical coordinate for cannon
    STA ram_cannon_y_position,x  ; and store it here
    LDA ram_current_page_loc
    STA ram_cannon_page_loc,x  ; store page number for cannon here
    JSR sub_get_area_object_x_position  ; get proper horizontal coordinate for cannon
    STA ram_cannon_x_position,x  ; and store it here
    INX
    CPX #$06  ; increment and check offset
    BCC bra_store_cannon_slot_offset  ; if not yet reached sixth cannon, branch to save offset
    LDX #$00  ; otherwise initialize it
bra_store_cannon_slot_offset:
    STX ram_cannon_offset  ; save new offset and leave
    RTS

; --------------------------------

tbl_staircase_heights:
    .byte $07, $07, $06, $05, $04, $03, $02, $01, $00

tbl_staircase_start_rows:
    .byte $03, $03, $04, $05, $06, $07, $08, $09, $0a

handler_draw_staircase:
    JSR sub_check_large_area_object_length  ; check and load length
    BCC bra_render_next_stair_step  ; if length already loaded, skip init part
    LDA #$09  ; start past the end for the bottom
    STA ram_staircase_control  ; of the staircase
bra_render_next_stair_step:
    DEC ram_staircase_control  ; move onto next step (or first if starting)
    LDY ram_staircase_control
    LDX tbl_staircase_start_rows,y  ; get starting row and height to render
    LDA tbl_staircase_heights,y
    TAY
    LDA #$61  ; now render solid block staircase
    JMP sub_render_under_part

; --------------------------------

handler_draw_jumpspring:
    JSR sub_get_large_area_object_attributes
    JSR sub_find_empty_enemy_slot  ; find empty space in enemy object buffer
.if con_revision_profile = con_revision_profile_pal
    BCS bra_exit_draw_jumpspring  ; leave when every enemy slot is occupied
.elseif con_revision_profile = con_revision_profile_vs
    BCS bra_exit_draw_jumpspring
.endif
    JSR sub_get_area_object_x_position  ; get horizontal coordinate for jumpspring
    STA ram_enemy_x_position,x  ; and store
    LDA ram_current_page_loc  ; store page location of jumpspring
    STA ram_enemy_page_loc,x
    JSR sub_get_area_object_y_position  ; get vertical coordinate for jumpspring
    STA ram_enemy_y_position,x  ; and store
    STA ram_jumpspring_fixed_y_pos,x  ; store as permanent coordinate here
    LDA #con_jumpspring_object
    STA ram_enemy_id,x  ; write jumpspring object to enemy object buffer
    LDY #$01
    STY ram_enemy_y_high_pos,x  ; store vertical high byte
    INC ram_enemy_flag,x  ; set flag for enemy object buffer
    LDX $07
    LDA #$67  ; draw metatiles in two rows where jumpspring is
    STA ram_metatile_buffer,x
    LDA #$68
    STA ram_metatile_buffer+1,x
bra_exit_draw_jumpspring:
    RTS

; --------------------------------
; $07 - used to save ID of brick object

handler_draw_hidden_extra_life_block:
    LDA ram_hidden1_up_flag  ; if flag not set, do not render object
    BEQ bra_finish_item_block_decode
    LDA #$00  ; if set, init for the next one
    STA ram_hidden1_up_flag
    JMP handler_draw_item_brick  ; jump to code shared with unbreakable bricks

handler_draw_question_block:
    JSR sub_get_area_object_id  ; get value from level decoder routine
    JMP loc_draw_question_or_brick_block  ; go to render it

handler_draw_coin_brick:
    LDA #$00  ; initialize multi-coin timer flag
    STA ram_brick_coin_timer_flag

handler_draw_item_brick:
    JSR sub_get_area_object_id  ; save area object ID
    STY $07
    LDA #$00  ; load default adder for bricks with lines
    LDY ram_area_type  ; check level type for ground level
    DEY
    BEQ bra_select_ground_brick_metatile  ; if ground type, do not start with 5
    LDA #$05  ; otherwise use adder for bricks without lines
bra_select_ground_brick_metatile:
    CLC  ; add object ID to adder
    ADC $07
    TAY  ; use as offset for metatile
loc_draw_question_or_brick_block:
    LDA tbl_brick_and_question_block_metatiles,y  ; get appropriate metatile for brick (question block
    PHA  ; if branched to here from question block routine)
    JSR sub_get_large_area_object_attributes  ; get row from location byte
    JMP loc_draw_metatile_row  ; now render the object

sub_get_area_object_id:
    LDA $00  ; get value saved from area parser routine
    SEC
    SBC #$00  ; possibly residual code
    TAY  ; save to Y
bra_finish_item_block_decode:
    RTS

; --------------------------------

tbl_hole_metatiles:
    .byte $87, $00, $00, $00

handler_empty_hole:
    JSR sub_check_large_area_object_length  ; get lower nybble and save as length
    BCC bra_render_hole_metatiles  ; skip this part if length already loaded
    LDA ram_area_type  ; check for water type level
    BNE bra_render_hole_metatiles  ; if not water type, skip this part
    LDX ram_whirlpool_offset  ; get offset for data used by cannons and whirlpools
    JSR sub_get_area_object_x_position  ; get proper vertical coordinate of where we're at
    SEC
    SBC #$10  ; subtract 16 pixels
    STA ram_whirlpool_left_extent,x  ; store as left extent of whirlpool
    LDA ram_current_page_loc  ; get page location of where we're at
    SBC #$00  ; subtract borrow
    STA ram_whirlpool_page_loc,x  ; save as page location of whirlpool
    INY
    INY  ; increment length by 2
    TYA
    ASL  ; multiply by 16 to get size of whirlpool
    ASL  ; note that whirlpool will always be
    ASL  ; two blocks bigger than actual size of hole
    ASL  ; and extend one block beyond each edge
    STA ram_whirlpool_length,x  ; save size of whirlpool here
    INX
    CPX #$05  ; increment and check offset
    BCC bra_store_whirlpool_slot_offset  ; if not yet reached fifth whirlpool, branch to save offset
    LDX #$00  ; otherwise initialize it
bra_store_whirlpool_slot_offset:
    STX ram_whirlpool_offset  ; save new offset here
bra_render_hole_metatiles:
    LDX ram_area_type  ; get appropriate metatile, then
    LDA tbl_hole_metatiles,x  ; render the hole proper
    LDX #$08
    LDY #$0f  ; start at ninth row and go to bottom, run sub_render_under_part

; --------------------------------

sub_render_under_part:
    STY ram_area_object_height  ; store vertical length to render
    LDY ram_metatile_buffer,x  ; check current spot to see if there's something
    BEQ bra_write_under_part_metatile  ; we need to keep, if nothing, go ahead
    CPY #$17
    BEQ bra_advance_under_part_row  ; if middle part (tree ledge), wait until next row
    CPY #$1a
    BEQ bra_advance_under_part_row  ; if middle part (mushroom ledge), wait until next row
    CPY #$c0
    BEQ bra_write_under_part_metatile  ; if question block w/ coin, overwrite
    CPY #$c0
    BCS bra_advance_under_part_row  ; if any other metatile with palette 3, wait until next row
    CPY #$54
    BNE bra_write_under_part_metatile  ; if cracked rock terrain, overwrite
    CMP #$50
    BEQ bra_advance_under_part_row  ; if stem top of mushroom, wait until next row
bra_write_under_part_metatile:
    STA ram_metatile_buffer,x  ; render contents of A from routine that called this
bra_advance_under_part_row:
    INX
    CPX #$0d  ; stop rendering if we're at the bottom of the screen
    BCS bra_exit_render_under_part
    LDY ram_area_object_height  ; decrement, and stop rendering if there is no more length
    DEY
    BPL sub_render_under_part
bra_exit_render_under_part:
    RTS

; --------------------------------

sub_check_large_area_object_length:
    JSR sub_get_large_area_object_attributes  ; get row location and size (length if branched to from here)

sub_check_fixed_large_area_object_length:
    LDA ram_area_object_length,x  ; check for set length counter
    CLC  ; clear carry flag for not just starting
    BPL bra_exit_object_length_setup  ; if counter not set, load it, otherwise leave alone
    TYA  ; save length into length counter
    STA ram_area_object_length,x
    SEC  ; set carry flag if just starting
bra_exit_object_length_setup:
    RTS

sub_get_large_area_object_attributes:
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDY ram_area_obj_offset_buffer,x  ; get offset saved from area obj decoding routine
    LDA (ram_area_data),y  ; get first byte of level object
    AND #%00001111
    STA $07  ; save row location
    INY
    LDA (ram_area_data),y  ; get next byte, save lower nybble (length or height)
    AND #%00001111  ; as Y, then leave
    TAY
    RTS

; --------------------------------

sub_get_area_object_x_position:
    LDA ram_current_column_pos  ; multiply current offset where we're at by 16
    ASL  ; to obtain horizontal pixel coordinate
    ASL
    ASL
    ASL
    RTS

; --------------------------------

sub_get_area_object_y_position:
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

tbl_block_buffer_addresses:
    .byte <ram_block_buffer_1, <ram_block_buffer_2
    .byte >ram_block_buffer_1, >ram_block_buffer_2

sub_get_block_buffer_addr:
    PHA  ; take value of A, save
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    TAY  ; use nybble as pointer to high byte
    LDA tbl_block_buffer_addresses+2,y  ; of indirect here
    STA $07
    PLA
    AND #%00001111  ; pull from stack, mask out high nybble
    CLC
    ADC tbl_block_buffer_addresses,y  ; add to low byte
    STA $06  ; store here and leave
    RTS

; -------------------------------------------------------------------------------------

; unused space
.if con_revision_profile <> con_revision_profile_pal
    .if con_revision_profile <> con_revision_profile_vs .and con_revision_profile <> con_revision_profile_fds_smb
        .byte $ff, $ff
    .endif
.endif
