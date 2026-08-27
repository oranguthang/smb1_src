; -------------------------------------------------------------------------------------

; Advance the column-oriented area parser and rendering task state

; Outputs:
; Metatile, attribute, block-buffer, and parser task state may be updated

; Clobbers:
; A, X, Y
sub_area_parser_task_handler:
    LDY ram_area_parser_task_num  ; check number of tasks here
    BNE bra_run_area_parser_tasks  ; if already set, go ahead
    LDY #$08
    STY ram_area_parser_task_num  ; otherwise, set eight by default
bra_run_area_parser_tasks:
    DEY
    TYA
    JSR sub_area_parser_tasks
    DEC ram_area_parser_task_num  ; if all tasks not complete do not
    BNE bra_exit_area_parser_task  ; render attribute table yet
    JSR sub_render_attribute_tables
bra_exit_area_parser_task:
    RTS

sub_area_parser_tasks:
    JSR sub_dispatch_inline_handler

    .word handler_advance_area_parser_column
    .word handler_render_area_column
    .word handler_render_area_column
    .word handler_build_area_column
    .word handler_advance_area_parser_column
    .word handler_render_area_column
    .word handler_render_area_column
    .word handler_build_area_column

; -------------------------------------------------------------------------------------

handler_advance_area_parser_column:
    INC ram_current_column_pos  ; increment column where we're at
    LDA ram_current_column_pos
    AND #%00001111  ; mask out higher nybble
    BNE bra_advance_block_buffer_column
    STA ram_current_column_pos  ; if no bits left set, wrap back to zero (0-f)
    INC ram_current_page_loc  ; and increment page number where we're at
bra_advance_block_buffer_column:
    INC ram_block_buffer_column_pos  ; increment column offset where we're at
    LDA ram_block_buffer_column_pos
    AND #%00011111  ; mask out all but 5 LSB (0-1f)
    STA ram_block_buffer_column_pos  ; and save
    RTS

; -------------------------------------------------------------------------------------
; $00 - used as counter, store for low nybble for background, ceiling byte for terrain
; $01 - used to store floor byte for terrain
; $07 - used to store terrain metatile
; $06-$07 - used to store block buffer address

tbl_background_scenery_data_offsets:
    .byte $00, $30, $60

tbl_background_scenery_patterns:
    .byte $93, $00, $00, $11, $12, $12, $13, $00  ; clouds
    .byte $00, $51, $52, $53, $00, $00, $00, $00
    .byte $00, $00, $01, $02, $02, $03, $00, $00
    .byte $00, $00, $00, $00, $91, $92, $93, $00
    .byte $00, $00, $00, $51, $52, $53, $41, $42
    .byte $43, $00, $00, $00, $00, $00, $91, $92

    .byte $97, $87, $88, $89, $99, $00, $00, $00  ; mountains and bushes
    .byte $11, $12, $13, $a4, $a5, $a5, $a5, $a6
    .byte $97, $98, $99, $01, $02, $03, $00, $a4
    .byte $a5, $a6, $00, $11, $12, $12, $12, $13
    .byte $00, $00, $00, $00, $01, $02, $02, $03
    .byte $00, $a4, $a5, $a5, $a6, $00, $00, $00

    .byte $11, $12, $12, $13, $00, $00, $00, $00  ; trees and fences
    .byte $00, $00, $00, $9c, $00, $8b, $aa, $aa
    .byte $aa, $aa, $11, $12, $13, $8b, $00, $9c
    .byte $9c, $00, $00, $01, $02, $03, $11, $12
    .byte $12, $13, $00, $00, $00, $00, $aa, $aa
    .byte $9c, $aa, $00, $8b, $00, $01, $02, $03

tbl_background_scenery_metatiles:
    .byte $80, $83, $00  ; cloud left
    .byte $81, $84, $00  ; cloud middle
    .byte $82, $85, $00  ; cloud right
    .byte $02, $00, $00  ; bush left
    .byte $03, $00, $00  ; bush middle
    .byte $04, $00, $00  ; bush right
    .byte $00, $05, $06  ; mountain left
    .byte $07, $06, $0a  ; mountain middle
    .byte $00, $08, $09  ; mountain right
    .byte $4d, $00, $00  ; fence
    .byte $0d, $0f, $4e  ; tall tree
    .byte $0e, $4e, $4e  ; short tree

tbl_foreground_scenery_data_offsets:
    .byte $00, $0d, $1a

tbl_foreground_scenery_metatiles:
    .byte $86, $87, $87, $87, $87, $87, $87  ; in water
    .byte $87, $87, $87, $87, $69, $69

    .byte $00, $00, $00, $00, $00, $45, $47  ; wall
    .byte $47, $47, $47, $47, $00, $00

    .byte $00, $00, $00, $00, $00, $00, $00  ; over water
    .byte $00, $00, $00, $00, $86, $87

tbl_terrain_metatiles:
    .byte $69, $54, $52, $62

tbl_terrain_render_masks:
    .byte %00000000, %00000000  ; no ceiling or floor
    .byte %00000000, %00011000  ; no ceiling, floor 2
    .byte %00000001, %00011000  ; ceiling 1, floor 2
    .byte %00000111, %00011000  ; ceiling 3, floor 2
    .byte %00001111, %00011000  ; ceiling 4, floor 2
    .byte %11111111, %00011000  ; ceiling 8, floor 2
    .byte %00000001, %00011111  ; ceiling 1, floor 5
    .byte %00000111, %00011111  ; ceiling 3, floor 5
    .byte %00001111, %00011111  ; ceiling 4, floor 5
    .byte %10000001, %00011111  ; ceiling 1, floor 6
    .byte %00000001, %00000000  ; ceiling 1, no floor
    .byte %10001111, %00011111  ; ceiling 4, floor 6
    .byte %11110001, %00011111  ; ceiling 1, floor 9
    .byte %11111001, %00011000  ; ceiling 1, middle 5, floor 2
    .byte %11110001, %00011000  ; ceiling 1, middle 4, floor 2
    .byte %11111111, %00011111  ; completely solid top to bottom

handler_build_area_column:
    LDA ram_backloading_flag  ; check to see if we are starting right of start
    BEQ bra_render_scenery_and_terrain  ; if not, go ahead and render background, foreground and terrain
    JSR sub_process_area_data  ; otherwise skip ahead and load level data

bra_render_scenery_and_terrain:
    LDX #$0c
    LDA #$00
bra_clear_metatile_buffer_loop:
    STA ram_metatile_buffer,x  ; clear out metatile buffer
    DEX
    BPL bra_clear_metatile_buffer_loop
    LDY ram_background_scenery  ; do we need to render the background scenery?
    BEQ bra_render_foreground_scenery  ; if not, skip to check the foreground
    LDA ram_current_page_loc  ; otherwise check for every third page
bra_reduce_page_modulo_3:
    CMP #$03
    BMI bra_render_background_scenery  ; if less than three we're there
    SEC
    SBC #$03  ; if 3 or more, subtract 3 and
    BPL bra_reduce_page_modulo_3  ; do an unconditional branch
bra_render_background_scenery:
    ASL  ; move results to higher nybble
    ASL
    ASL
    ASL
    ADC tbl_background_scenery_data_offsets-1,y  ; add to it offset loaded from here
    ADC ram_current_column_pos  ; add to the result our current column position
    TAX
    LDA tbl_background_scenery_patterns,x  ; load data from sum of offsets
    BEQ bra_render_foreground_scenery  ; if zero, no scenery for that part
    PHA
    AND #$0f  ; save to stack and clear high nybble
    SEC
    SBC #$01  ; subtract one (because low nybble is $01-$0c)
    STA $00  ; save low nybble
    ASL  ; multiply by three (shift to left and add result to old one)
    ADC $00  ; note that since d7 was nulled, the carry flag is always clear
    TAX  ; save as offset for background scenery metatile data
    PLA  ; get high nybble from stack, move low
    LSR
    LSR
    LSR
    LSR
    TAY  ; use as second offset (used to determine height)
    LDA #$03  ; use previously saved memory location for counter
    STA $00
bra_copy_background_scenery_metatiles:
    LDA tbl_background_scenery_metatiles,x  ; load metatile data from offset of (lsb - 1) * 3
    STA ram_metatile_buffer,y  ; store into buffer from offset of (msb / 16)
    INX
    INY
    CPY #$0b  ; if at this location, leave loop
    BEQ bra_render_foreground_scenery
    DEC $00  ; decrement until counter expires, barring exception
    BNE bra_copy_background_scenery_metatiles
bra_render_foreground_scenery:
    LDX ram_foreground_scenery  ; check for foreground data needed or not
    BEQ bra_render_terrain  ; if not, skip this part
    LDY tbl_foreground_scenery_data_offsets-1,x  ; load offset from location offset by header value, then
    LDX #$00  ; reinit X
bra_copy_foreground_scenery_metatiles:
    LDA tbl_foreground_scenery_metatiles,y  ; load data until counter expires
    BEQ bra_skip_empty_foreground_metatile  ; do not store if zero found
    STA ram_metatile_buffer,x
bra_skip_empty_foreground_metatile:
    INY
    INX
    CPX #$0d  ; store up to end of metatile buffer
    BNE bra_copy_foreground_scenery_metatiles
bra_render_terrain:
    LDY ram_area_type  ; check world type for water level
    BNE bra_select_terrain_metatile  ; if not water level, skip this part
    LDA ram_world_number  ; check world number, if not world number eight
    CMP #con_world8  ; then skip this part
    BNE bra_select_terrain_metatile
    LDA #$62  ; if set as water level and world number eight,
    JMP loc_store_terrain_metatile  ; use castle wall metatile as terrain type
bra_select_terrain_metatile:
    LDA tbl_terrain_metatiles,y  ; otherwise get appropriate metatile for area type
    LDY ram_cloud_type_override  ; check for cloud type override
    BEQ loc_store_terrain_metatile  ; if not set, keep value otherwise
    LDA #$88  ; use cloud block terrain
loc_store_terrain_metatile:
    STA $07  ; store value here
    LDX #$00  ; initialize X, use as metatile buffer offset
    LDA ram_terrain_control  ; use yet another value from the header
    ASL  ; multiply by 2 and use as yet another offset
    TAY
bra_render_terrain_byte:
    LDA tbl_terrain_render_masks,y  ; get one of the terrain rendering bit data
    STA $00
    INY  ; increment Y and use as offset next time around
    STY $01
    LDA ram_cloud_type_override  ; skip if value here is zero
    BEQ bra_apply_terrain_row_bits
    CPX #$00  ; otherwise, check if we're doing the ceiling byte
    BEQ bra_apply_terrain_row_bits
    LDA $00  ; if not, mask out all but d3
    AND #%00001000
    STA $00
bra_apply_terrain_row_bits:
    LDY #$00  ; start at beginning of bitmasks
bra_apply_terrain_bitmask:
    LDA tbl_enemy_slot_bit_masks,y  ; load bitmask, then perform AND on contents of first byte
    BIT $00
    BEQ bra_advance_terrain_row  ; if not set, skip this part (do not write terrain to buffer)
    LDA $07
    STA ram_metatile_buffer,x  ; load terrain type metatile number and store into buffer here
bra_advance_terrain_row:
    INX  ; continue until end of buffer
    CPX #$0d
    BEQ bra_render_block_buffer_column  ; if we're at the end, break out of this loop
    LDA ram_area_type  ; check world type for underground area
    CMP #$02
    BNE bra_advance_terrain_bit  ; if not underground, skip this part
    CPX #$0b
    BNE bra_advance_terrain_bit  ; if we're at the bottom of the screen, override
    LDA #$54  ; old terrain type with ground level terrain type
    STA $07
bra_advance_terrain_bit:
    INY  ; increment bitmasks offset in Y
    CPY #$08
    BNE bra_apply_terrain_bitmask  ; if not all bits checked, loop back
    LDY $01
    BNE bra_render_terrain_byte  ; unconditional branch, use Y to load next byte
bra_render_block_buffer_column:
    JSR sub_process_area_data  ; do the area data loading routine now
    LDA ram_block_buffer_column_pos
    JSR sub_get_block_buffer_addr  ; get block buffer address from where we're at
    LDX #$00
    LDY #$00  ; init index regs and start at beginning of smaller buffer
bra_validate_block_buffer_metatile:
    STY $00
    LDA ram_metatile_buffer,x  ; load stored metatile number
    AND #%11000000  ; mask out all but 2 MSB
    ASL
    ROL  ; make %xx000000 into %000000xx
    ROL
    TAY  ; use as offset in Y
    LDA ram_metatile_buffer,x  ; reload original unmasked value here
    CMP tbl_block_buffer_low_bounds,y  ; check for certain values depending on bits set
    BCS bra_store_block_buffer_metatile  ; if equal or greater, branch
    LDA #$00  ; if less, init value before storing
bra_store_block_buffer_metatile:
    LDY $00  ; get offset for block buffer
    STA ($06),y  ; store value into block buffer
    TYA
    CLC  ; add 16 (move down one row) to offset
    ADC #$10
    TAY
    INX  ; increment column value
    CPX #$0d
    BCC bra_validate_block_buffer_metatile  ; continue until we pass last row, then leave
    RTS

; numbers lower than these with the same attribute bits
; will not be stored in the block buffer
tbl_block_buffer_low_bounds:
    .byte $10, $51, $88, $c0

; -------------------------------------------------------------------------------------
; $00 - used to store area object identifier
; $07 - used as adder to find proper area object code

sub_process_area_data:
.if con_revision_profile = con_revision_profile_vs
    JSR sub_vs_select_low_chr_bank
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDX #$02  ; start at the end of area object buffer
bra_process_area_object_slots:
    STX ram_object_offset
    LDA #$00  ; reset flag
    STA ram_behind_area_parser_flag
    LDY ram_area_data_offset  ; get offset of area data pointer
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y  ; get first byte of area object
    CMP #$fd  ; if end-of-area, skip all this crap
    BEQ bra_decode_current_area_object
    LDA ram_area_object_length,x  ; check area object buffer flag
    BPL bra_decode_current_area_object  ; if buffer not negative, branch, otherwise
    INY
    LDA (ram_area_data),y  ; get second byte of area object
    ASL  ; check for page select bit (d7), branch if not set
    BCC bra_check_area_object_row_13
    LDA ram_area_object_page_sel  ; check page select
    BNE bra_check_area_object_row_13
    INC ram_area_object_page_sel  ; if not already set, set it now
    INC ram_area_object_page_loc  ; and increment page location
bra_check_area_object_row_13:
    DEY
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y  ; reread first byte of level object
    AND #$0f  ; mask out high nybble
    CMP #$0d  ; row 13?
    BNE bra_check_area_object_row_14
    INY  ; if so, reread second byte of level object
    LDA (ram_area_data),y
    DEY  ; decrement to get ready to read first byte
    AND #%01000000  ; check for d6 set (if not, object is page control)
    BNE bra_check_object_behind_renderer
    LDA ram_area_object_page_sel  ; if page select is set, do not reread
    BNE bra_check_object_behind_renderer
    INY  ; if d6 not set, reread second byte
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y
    AND #%00011111  ; mask out all but 5 LSB and store in page control
    STA ram_area_object_page_loc
    INC ram_area_object_page_sel  ; increment page select
    JMP loc_advance_area_object_stream
bra_check_area_object_row_14:
    CMP #$0e  ; row 14?
    BNE bra_check_object_behind_renderer
    LDA ram_backloading_flag  ; check flag for saved page number and branch if set
    BNE bra_decode_current_area_object  ; to render the object (otherwise bg might not look right)
bra_check_object_behind_renderer:
    LDA ram_area_object_page_loc  ; check to see if current page of level object is
    CMP ram_current_page_loc  ; behind current page of renderer
    BCC bra_mark_object_behind_renderer  ; if so branch
bra_decode_current_area_object:
    JSR sub_decode_area_data  ; do sub and do not turn on flag
    JMP loc_update_area_object_length
bra_mark_object_behind_renderer:
    INC ram_behind_area_parser_flag  ; turn on flag if object is behind renderer
loc_advance_area_object_stream:
    JSR sub_advance_area_object_stream  ; increment buffer offset and move on
loc_update_area_object_length:
    LDX ram_object_offset  ; get buffer offset
    LDA ram_area_object_length,x  ; check object length for anything stored here
    BMI bra_advance_area_object_slot  ; if not, branch to handle loopback
    DEC ram_area_object_length,x  ; otherwise decrement length or get rid of it
bra_advance_area_object_slot:
    DEX  ; decrement buffer offset
.if con_revision_profile = con_revision_profile_vs
    BMI bra_finish_area_object_slots
    JMP bra_process_area_object_slots
bra_finish_area_object_slots:
.else
    BPL bra_process_area_object_slots  ; and loopback unless exceeded buffer
.endif
    LDA ram_behind_area_parser_flag  ; check for flag set if objects were behind renderer
.if con_revision_profile = con_revision_profile_vs
    BEQ bra_check_area_parser_backloading
    JMP sub_process_area_data
bra_check_area_parser_backloading:
.else
    BNE sub_process_area_data  ; branch if true to load more level data, otherwise
.endif
    LDA ram_backloading_flag  ; check for flag set if starting right of page $00
.if con_revision_profile = con_revision_profile_vs
    BEQ bra_exit_area_parser
    JMP sub_process_area_data
.else
    BNE sub_process_area_data  ; branch if true to load more level data, otherwise leave
.endif
bra_exit_area_parser:
.if con_revision_profile = con_revision_profile_vs
    JSR sub_vs_select_low_chr_bank
.endif
    RTS

sub_advance_area_object_stream:
    INC ram_area_data_offset  ; increment offset of level pointer
    INC ram_area_data_offset
    LDA #$00  ; reset page select
    STA ram_area_object_page_sel
    RTS

sub_decode_area_data:
    LDA ram_area_object_length,x  ; check current buffer flag
    BMI bra_select_area_object_data_offset
    LDY ram_area_obj_offset_buffer,x  ; if not, get offset from buffer
bra_select_area_object_data_offset:
    LDX #$10  ; load offset of 16 for special row 15
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y  ; get first byte of level object again
    CMP #$fd
    BEQ bra_exit_area_parser  ; if end of level, leave this routine
    AND #$0f  ; otherwise, mask out low nybble
    CMP #$0f  ; row 15?
    BEQ bra_classify_area_object_row_14  ; if so, keep the offset of 16
    LDX #$08  ; otherwise load offset of 8 for special row 12
    CMP #$0c  ; row 12?
    BEQ bra_classify_area_object_row_14  ; if so, keep the offset value of 8
    LDX #$00  ; otherwise nullify value by default
bra_classify_area_object_row_14:
    STX $07  ; store whatever value we just loaded here
    LDX ram_object_offset  ; get object offset again
    CMP #$0e  ; row 14?
    BNE bra_decode_area_object_row_13
    LDA #$00  ; if so, load offset with $00
    STA $07
    LDA #$2e  ; and load A with another value
    BNE loc_dispatch_decoded_area_object  ; unconditional branch
bra_decode_area_object_row_13:
    CMP #$0d  ; row 13?
    BNE bra_classify_special_area_object_rows
    LDA #$22  ; if so, load offset with 34
    STA $07
    INY  ; get next byte
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y
    AND #%01000000  ; mask out all but d6 (page control obj bit)
    BEQ bra_exit_area_object_decoder  ; if d6 clear, branch to leave (we handled this earlier)
    LDA (ram_area_data),y  ; otherwise, get byte again
    AND #%01111111  ; mask out d7
    CMP #$4b  ; check for loop command in low nybble
    BNE bra_decode_row_13_object_id  ; (plus d6 set for object other than page control)
    INC ram_loop_command  ; if loop command, set loop command flag
bra_decode_row_13_object_id:
    AND #%00111111  ; mask out d7 and d6
    JMP loc_dispatch_decoded_area_object  ; and jump
bra_classify_special_area_object_rows:
    CMP #$0c  ; row 12-15?
    BCS bra_decode_special_row_object
    INY  ; if not, get second byte of level object
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y
    AND #%01110000  ; mask out all but d6-d4
    BNE bra_decode_large_area_object  ; if any bits set, branch to handle large object
    LDA #$16
    STA $07  ; otherwise set offset of 24 for small object
    LDA (ram_area_data),y  ; reload second byte of level object
    AND #%00001111  ; mask out higher nybble and jump
    JMP loc_dispatch_decoded_area_object
bra_decode_large_area_object:
    STA $00  ; store value here (branch for large objects)
    CMP #$70  ; check for vertical pipe object
    BNE bra_finish_large_area_object_id
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y  ; if not, reload second byte
    AND #%00001000  ; mask out all but d3 (usage control bit)
    BEQ bra_finish_large_area_object_id  ; if d3 clear, branch to get original value
    LDA #$00  ; otherwise, nullify value for warp pipe
    STA $00
bra_finish_large_area_object_id:
    LDA $00  ; get value and jump ahead
    JMP loc_shift_area_object_id
bra_decode_special_row_object:
    INY  ; branch here for rows 12-15
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y
    AND #%01110000  ; get next byte and mask out all but d6-d4
loc_shift_area_object_id:
    LSR  ; move d6-d4 to lower nybble
    LSR
    LSR
    LSR
loc_dispatch_decoded_area_object:
    STA $00  ; store value here (branch for small objects and rows 13 and 14)
    LDA ram_area_object_length,x  ; is there something stored here already?
    BPL bra_dispatch_current_area_object  ; if so, branch to do its particular sub
    LDA ram_area_object_page_loc  ; otherwise check to see if the object we've loaded is on the
    CMP ram_current_page_loc  ; same page as the renderer, and if so, branch
    BEQ bra_initialize_current_area_object
    LDY ram_area_data_offset  ; if not, get old offset of level pointer
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y  ; and reload first byte
    AND #%00001111
    CMP #$0e  ; row 14?
    BNE bra_exit_area_object_decoder
    LDA ram_backloading_flag  ; if so, check backloading flag
    BNE bra_store_area_object_stream_offset  ; if set, branch to render object, else leave
bra_exit_area_object_decoder:
    RTS
bra_initialize_current_area_object:
    LDA ram_backloading_flag  ; check backloading flag to see if it's been initialized
    BEQ bra_compare_area_object_column  ; branch to column-wise check
    LDA #$00  ; if not, initialize both backloading and
    STA ram_backloading_flag  ; behind-renderer flags and leave
    STA ram_behind_area_parser_flag
    STA ram_object_offset
handler_loop_command:
    RTS
bra_compare_area_object_column:
    LDY ram_area_data_offset  ; get first byte again
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
.endif
    LDA (ram_area_data),y
    AND #%11110000  ; mask out low nybble and move high to low
    LSR
    LSR
    LSR
    LSR
    CMP ram_current_column_pos  ; is this where we're at?
    BNE bra_exit_area_object_decoder  ; if not, branch to leave
bra_store_area_object_stream_offset:
    LDA ram_area_data_offset  ; if so, load area obj offset and store in buffer
    STA ram_area_obj_offset_buffer,x
    JSR sub_advance_area_object_stream  ; do sub to increment to next object data
bra_dispatch_current_area_object:
    LDA $00  ; get stored value and add offset to it
    CLC  ; then use the jump engine with current contents of A
    ADC $07
    JSR sub_dispatch_inline_handler

; large objects (rows $00-$0b or 00-11, d6-d4 set)
    .word handler_draw_vertical_pipe  ; used by warp pipes
    .word handler_set_area_style
    .word handler_draw_brick_row
    .word handler_draw_solid_block_row
    .word handler_draw_coin_row
    .word handler_draw_brick_column
    .word handler_draw_solid_block_column
    .word handler_draw_vertical_pipe  ; used by decoration pipes

; objects for special row $0c or 12
    .word handler_empty_hole
    .word handler_draw_pulley_rope
    .word handler_draw_high_bridge
    .word handler_draw_middle_bridge
    .word handler_draw_low_bridge
    .word handler_water_hole
    .word handler_draw_high_question_block_row
    .word handler_draw_low_question_block_row

; objects for special row $0f or 15
    .word handler_draw_endless_rope
    .word handler_draw_balance_platform_rope
    .word handler_draw_castle_structure
    .word handler_draw_staircase
    .word handler_draw_exit_pipe
    .word handler_residual_flag_balls

; small objects (rows $00-$0b or 00-11, d6-d4 all clear)
    .word handler_draw_question_block  ; power-up
    .word handler_draw_question_block  ; coin
    .word handler_draw_question_block  ; hidden, coin
    .word handler_draw_hidden_extra_life_block  ; hidden, 1-up
    .word handler_draw_item_brick  ; brick, power-up
    .word handler_draw_item_brick  ; brick, vine
    .word handler_draw_item_brick  ; brick, star
    .word handler_draw_coin_brick  ; brick, coins
    .word handler_draw_item_brick  ; brick, 1-up
    .word handler_draw_water_pipe
    .word handler_draw_empty_block
    .word handler_draw_jumpspring

; objects for special row $0d or 13 (d6 set)
    .word handler_draw_intro_pipe
    .word handler_draw_flagpole_object
    .word handler_draw_axe
    .word handler_draw_chain
    .word handler_draw_castle_bridge
    .word handler_warp_zone_scroll_lock
    .word handler_toggle_scroll_lock
    .word handler_toggle_scroll_lock
    .word handler_set_area_frenzy  ; flying cheep-cheeps
    .word handler_set_area_frenzy  ; bullet bills or swimming cheep-cheeps
    .word handler_set_area_frenzy  ; stop frenzy
    .word handler_loop_command

; object for special row $0e or 14
    .word handler_alter_area_attributes
