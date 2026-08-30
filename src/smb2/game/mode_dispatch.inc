handler_smb2_main_game_over_subs:
    LDA OperMode_Task
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_setup_game_over
    .word handler_smb2_main_run_screen_task
    .word handler_smb2_main_run_game_over_screen

; -------------------------------------------------------------------------------------

handler_smb2_main_setup_game_over:
    LDA #$00
    STA ScreenRoutineTask
    STA IRQUpdateFlag
    STA ContinueMenuSelect  ; set continue as default choice
    LDA #$02
    STA EventMusicQueue  ; play game over music
    INC DisableScreenFlag
    INC OperMode_Task
    RTS

handler_smb2_main_run_game_over_screen:
    LDA #$00
    STA DisableScreenFlag
    LDA WorldNumber  ; if on world 9, branch on to end the game
    CMP #World9
    BEQ bra_smb2_main_w9_end
    JMP loc_smb2_main_game_over_menu  ; otherwise run game over menu
bra_smb2_main_w9_end:
    LDA ScreenTimer
    BNE bra_smb2_main_exit_game_over_routine

sub_smb2_main_terminate_game:
    LDA #Silence  ; silence music
    STA EventMusicQueue
    LDA #$00
    STA OperMode_Task  ; reset to attract mode and leave
    STA ScreenTimer
    STA OperMode
bra_smb2_main_exit_game_over_routine:
    RTS

loc_smb2_main_restart_game:
    JSR sub_smb2_main_load_area_pointer  ; update level pointer with
    LDA #$01  ; actual world and area numbers, then
    STA PlayerSize  ; reset player's size, status, and
    INC FetchNewGameTimerFlag  ; set game timer flag to reload
    LDA #$00  ; game timer from header
    STA TimerControl  ; also set flag for timers to count again
    STA PlayerStatus
    STA GameEngineSubroutine  ; reset task for game core
    STA OperMode_Task  ; set modes and leave
    LDA #$01  ; if in game over mode, switch back to
    STA OperMode  ; game mode, because game is still on
loc_smb2_main_exit_game_restart:
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_do_nothing:
    LDA #$ff  ; this is residual code, this value is
    STA $06c9  ; not used anywhere in the program
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_area_parser_task_handler:
    LDY AreaParserTaskNum  ; check number of tasks here
    BNE bra_smb2_main_run_area_parser_tasks  ; if already set, go ahead
    LDY #$08
    STY AreaParserTaskNum  ; otherwise, set eight by default
bra_smb2_main_run_area_parser_tasks:
    DEY
    TYA
    JSR sub_smb2_main_area_parser_tasks
    DEC AreaParserTaskNum  ; if all tasks not complete do not
    BNE bra_smb2_main_exit_area_parser_task  ; render attribute table yet
    JSR sub_smb2_main_render_attribute_tables
bra_smb2_main_exit_area_parser_task:
    RTS

sub_smb2_main_area_parser_tasks:
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_advance_area_parser_column
    .word handler_smb2_main_render_area_column
    .word handler_smb2_main_render_area_column
    .word handler_smb2_main_build_area_column
    .word handler_smb2_main_advance_area_parser_column
    .word handler_smb2_main_render_area_column
    .word handler_smb2_main_render_area_column
    .word handler_smb2_main_build_area_column

; -------------------------------------------------------------------------------------

handler_smb2_main_advance_area_parser_column:
    INC CurrentColumnPos  ; increment column where we're at
    LDA CurrentColumnPos
    AND #%00001111  ; mask out higher nybble
    BNE bra_smb2_main_advance_block_buffer_column
    STA CurrentColumnPos  ; if no bits left set, wrap back to zero (0-f)
    INC CurrentPageLoc  ; and increment page number where we're at
bra_smb2_main_advance_block_buffer_column:
    INC BlockBufferColumnPos  ; increment column offset where we're at
    LDA BlockBufferColumnPos
    AND #%00011111  ; mask out all but 5 LSB (0-1f)
    STA BlockBufferColumnPos  ; and save
    RTS

; -------------------------------------------------------------------------------------
; $00 - used as counter, store for low nybble for background, ceiling byte for terrain
; $01 - used to store floor byte for terrain
; $07 - used to store terrain metatile
; $06-$07 - used to store block buffer address

tbl_smb2_main_background_scenery_data_offsets:
    .byte $00, $30, $60

off_smb2_main_background_scenery_patterns:
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

tbl_smb2_main_background_scenery_metatiles:
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

tbl_smb2_main_foreground_scenery_data_offsets:
    .byte $00, $0d, $1a

off_smb2_main_foreground_scenery_metatiles:
    .byte $86, $87, $87, $87, $87, $87, $87  ; in water
    .byte $87, $87, $87, $87, $6a, $6a

    .byte $00, $00, $00, $00, $00, $45, $47  ; wall
    .byte $47, $47, $47, $47, $00, $00

    .byte $00, $00, $00, $00, $00, $00, $00  ; over water
    .byte $00, $00, $00, $00, $86, $87

tbl_smb2_main_terrain_metatiles:
    .byte $6a, $6b, $50, $63

tbl_smb2_main_terrain_render_masks:
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

handler_smb2_main_build_area_column:
    LDA BackloadingFlag  ; check to see if we are starting right of start
    BEQ bra_smb2_main_render_scenery_and_terrain  ; if not, go ahead and render background, foreground and terrain
    JSR sub_smb2_main_process_area_data  ; otherwise skip ahead and load level data

bra_smb2_main_render_scenery_and_terrain:
    LDX #$0c
    LDA #$00
bra_smb2_main_clear_metatile_buffer_loop:
    STA MetatileBuffer,x  ; clear out metatile buffer
    DEX
    BPL bra_smb2_main_clear_metatile_buffer_loop
    LDY BackgroundScenery  ; do we need to render the background scenery?
    BEQ bra_smb2_main_render_foreground_scenery  ; if not, skip to check the foreground
    LDA CurrentPageLoc  ; otherwise check for every third page
bra_smb2_main_reduce_page_modulo_3:
    CMP #$03
    BMI bra_smb2_main_render_background_scenery  ; if less than three we're there
    SEC
    SBC #$03  ; if 3 or more, subtract 3 and
    BPL bra_smb2_main_reduce_page_modulo_3  ; do an unconditional branch
bra_smb2_main_render_background_scenery:
    ASL  ; move results to higher nybble
    ASL
    ASL
    ASL
    ADC tbl_smb2_main_background_scenery_data_offsets-1,y  ; add to it offset loaded from here
    ADC CurrentColumnPos  ; add to the result our current column position
    TAX
    LDA off_smb2_main_background_scenery_patterns,x  ; load data from sum of offsets
    BEQ bra_smb2_main_render_foreground_scenery  ; if zero, no scenery for that part
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
bra_smb2_main_copy_background_scenery_metatiles:
    LDA tbl_smb2_main_background_scenery_metatiles,x  ; load metatile data from offset of (lsb - 1) * 3
    STA MetatileBuffer,y  ; store into buffer from offset of (msb / 16)
    INX
    INY
    CPY #$0b  ; if at this location, leave loop
    BEQ bra_smb2_main_render_foreground_scenery
    DEC $00  ; decrement until counter expires, barring exception
    BNE bra_smb2_main_copy_background_scenery_metatiles
bra_smb2_main_render_foreground_scenery:
    LDX ForegroundScenery  ; check for foreground data needed or not
    BEQ bra_smb2_main_render_terrain  ; if not, skip this part
    LDY tbl_smb2_main_foreground_scenery_data_offsets-1,x  ; load offset from location offset by header value, then
    LDX #$00  ; reinit X
bra_smb2_main_copy_foreground_scenery_metatiles:
    LDA off_smb2_main_foreground_scenery_metatiles,y  ; load data until counter expires
    BEQ bra_smb2_main_skip_empty_foreground_metatile  ; do not store if zero found
    STA MetatileBuffer,x
bra_smb2_main_skip_empty_foreground_metatile:
    INY
    INX
    CPX #$0d  ; store up to end of metatile buffer
    BNE bra_smb2_main_copy_foreground_scenery_metatiles
bra_smb2_main_render_terrain:
    LDY AreaType  ; check world type for water level
    BNE bra_smb2_main_select_terrain_metatile  ; if not water level, skip this part
    LDA WorldNumber  ; check world number, if not world number eight
    CMP #World8  ; then skip this part
    BNE bra_smb2_main_select_terrain_metatile
    LDA #$63  ; if set as water level and world number eight,
    JMP bra_smb2_main_store_terrain_metatile  ; use castle wall metatile as terrain type
bra_smb2_main_select_terrain_metatile:
    LDA tbl_smb2_main_terrain_metatiles,y  ; otherwise get appropriate metatile for area type
    LDY CloudTypeOverride  ; check for cloud type override
    BEQ bra_smb2_main_store_terrain_metatile  ; if not set, keep value otherwise
    LDA #$88  ; use cloud block terrain
bra_smb2_main_store_terrain_metatile:
    STA $07  ; store value here
    LDX #$00  ; initialize X, use as metatile buffer offset
    LDA TerrainControl  ; use yet another value from the header
    ASL  ; multiply by 2 and use as yet another offset
    TAY
bra_smb2_main_render_terrain_byte:
    LDA tbl_smb2_main_terrain_render_masks,y  ; get one of the terrain rendering bit data
    STA $00
    INY  ; increment Y and use as offset next time around
    STY $01
    LDA CloudTypeOverride  ; skip if value here is zero
    BEQ bra_smb2_main_apply_terrain_row_bits
    CPX #$00  ; otherwise, check if we're doing the ceiling byte
    BEQ bra_smb2_main_apply_terrain_row_bits
    LDA $00  ; if not, mask out all but d3
    AND #%00001000
    STA $00
bra_smb2_main_apply_terrain_row_bits:
    LDY #$00  ; start at beginning of bitmasks
bra_smb2_main_apply_terrain_bitmask:
    LDA tbl_smb2_main_enemy_slot_bit_masks,y  ; load bitmask, then perform AND on contents of first byte
    BIT $00
    BEQ bra_smb2_main_advance_terrain_row  ; if not set, skip this part (do not write terrain to buffer)
    LDA $07
    STA MetatileBuffer,x  ; load terrain type metatile number and store into buffer here
bra_smb2_main_advance_terrain_row:
    INX  ; continue until end of buffer
    CPX #$0d
    BEQ bra_smb2_main_render_block_buffer_column  ; if we're at the end, break out of this loop
    LDA AreaType  ; check world type for underground area
    CMP #$02
    BNE bra_smb2_main_advance_terrain_bit  ; if not underground, skip this part
    CPX #$0b
    BNE bra_smb2_main_advance_terrain_bit  ; if we're at the bottom of the screen, override
    LDA #$6b  ; old terrain type with ground level terrain type
    STA $07
bra_smb2_main_advance_terrain_bit:
    INY  ; increment bitmasks offset in Y
    CPY #$08
    BNE bra_smb2_main_apply_terrain_bitmask  ; if not all bits checked, loop back
    LDY $01
    BNE bra_smb2_main_render_terrain_byte  ; unconditional branch, use Y to load next byte
bra_smb2_main_render_block_buffer_column:
    JSR sub_smb2_main_process_area_data  ; do the area data loading routine now
    LDA BlockBufferColumnPos
    JSR sub_smb2_main_get_block_buffer_addr  ; get block buffer address from where we're at
    LDX #$00
    LDY #$00  ; init index regs and start at beginning of smaller buffer
bra_smb2_main_validate_block_buffer_metatile:
    STY $00
    LDA MetatileBuffer,x  ; load stored metatile number
    AND #%11000000  ; mask out all but 2 MSB
    ASL
    ROL  ; make %xx000000 into %000000xx
    ROL
    TAY  ; use as offset in Y
    LDA MetatileBuffer,x  ; reload original unmasked value here
    CMP tbl_smb2_main_block_buffer_low_bounds,y  ; check for certain values depending on bits set
    BCS bra_smb2_main_store_block_buffer_metatile  ; if equal or greater, branch
    LDA #$00  ; if less, init value before storing
bra_smb2_main_store_block_buffer_metatile:
    LDY $00  ; get offset for block buffer
    STA ($06),y  ; store value into block buffer
    TYA
    CLC  ; add 16 (move down one row) to offset
    ADC #$10
    TAY
    INX  ; increment column value
    CPX #$0d
    BCC bra_smb2_main_validate_block_buffer_metatile  ; continue until we pass last row, then leave
    RTS

; numbers lower than these with the same attribute bits
; will not be stored in the block buffer
tbl_smb2_main_block_buffer_low_bounds:
    .byte $10, $4f, $88, $c0

; -------------------------------------------------------------------------------------
; $00 - used to store area object identifier
; $07 - used as adder to find proper area object code

sub_smb2_main_process_area_data:
    LDX #$02  ; start at the end of area object buffer
bra_smb2_main_process_area_object_slots:
    STX ObjectOffset
    LDA #$00  ; reset flag
    STA BehindAreaParserFlag
    LDY AreaDataOffset  ; get offset of area data pointer
    LDA (AreaData),y  ; get first byte of area object
    CMP #$fd  ; if end-of-area, skip all this crap
    BEQ bra_smb2_main_decode_current_area_object
    LDA AreaObjectLength,x  ; check area object buffer flag
    BPL bra_smb2_main_decode_current_area_object  ; if buffer not negative, branch, otherwise
    INY
    LDA (AreaData),y  ; get second byte of area object
    ASL  ; check for page select bit (d7), branch if not set
    BCC bra_smb2_main_check_area_object_row_13
    LDA AreaObjectPageSel  ; check page select
    BNE bra_smb2_main_check_area_object_row_13
    INC AreaObjectPageSel  ; if not already set, set it now
    INC AreaObjectPageLoc  ; and increment page location
bra_smb2_main_check_area_object_row_13:
    DEY
    LDA (AreaData),y  ; reread first byte of level object
    AND #$0f  ; mask out high nybble
    CMP #$0d  ; row 13?
    BNE bra_smb2_main_check_area_object_row_14
    INY  ; if so, reread second byte of level object
    LDA (AreaData),y
    DEY  ; decrement to get ready to read first byte
    AND #%01000000  ; check for d6 set (if not, object is page control)
    BNE bra_smb2_main_check_object_behind_renderer
    LDA AreaObjectPageSel  ; if page select is set, do not reread
    BNE bra_smb2_main_check_object_behind_renderer
    INY  ; if d6 not set, reread second byte
    LDA (AreaData),y
    AND #%00011111  ; mask out all but 5 LSB and store in page control
    STA AreaObjectPageLoc
    INC AreaObjectPageSel  ; increment page select
    JMP loc_smb2_main_advance_area_object_stream
bra_smb2_main_check_area_object_row_14:
    CMP #$0e  ; row 14?
    BNE bra_smb2_main_check_object_behind_renderer
    LDA BackloadingFlag  ; check flag for saved page number and branch if set
    BNE bra_smb2_main_decode_current_area_object  ; to render the object (otherwise bg might not look right)
bra_smb2_main_check_object_behind_renderer:
    LDA AreaObjectPageLoc  ; check to see if current page of level object is
    CMP CurrentPageLoc  ; behind current page of renderer
    BCC bra_smb2_main_mark_object_behind_renderer  ; if so branch
bra_smb2_main_decode_current_area_object:
    JSR sub_smb2_main_decode_area_data  ; do sub and do not turn on flag
    JMP loc_smb2_main_update_area_object_length
bra_smb2_main_mark_object_behind_renderer:
    INC BehindAreaParserFlag  ; turn on flag if object is behind renderer
loc_smb2_main_advance_area_object_stream:
    JSR sub_smb2_main_advance_area_object_stream  ; increment buffer offset and move on
loc_smb2_main_update_area_object_length:
    LDX ObjectOffset  ; get buffer offset
    LDA AreaObjectLength,x  ; check object length for anything stored here
    BMI bra_smb2_main_advance_area_object_slot  ; if not, branch to handle loopback
    DEC AreaObjectLength,x  ; otherwise decrement length or get rid of it
bra_smb2_main_advance_area_object_slot:
    DEX  ; decrement buffer offset
    BPL bra_smb2_main_process_area_object_slots  ; and loopback unless exceeded buffer
    LDA BehindAreaParserFlag  ; check for flag set if objects were behind renderer
    BNE sub_smb2_main_process_area_data  ; branch if true to load more level data, otherwise
    LDA BackloadingFlag  ; check for flag set if starting right of page $00
    BNE sub_smb2_main_process_area_data  ; branch if true to load more level data, otherwise leave
bra_smb2_main_exit_area_parser:
    RTS

sub_smb2_main_advance_area_object_stream:
    INC AreaDataOffset  ; increment offset of level pointer
    INC AreaDataOffset
    LDA #$00  ; reset page select
    STA AreaObjectPageSel
    RTS

sub_smb2_main_decode_area_data:
    LDA AreaObjectLength,x  ; check current buffer flag
    BMI bra_smb2_main_select_area_object_data_offset
    LDY AreaObjOffsetBuffer,x  ; if not, get offset from buffer
bra_smb2_main_select_area_object_data_offset:
    LDX #$10  ; load offset of 16 for special row 15
    LDA (AreaData),y  ; get first byte of level object again
    CMP #$fd
    BEQ bra_smb2_main_exit_area_parser  ; if end of level, leave this routine
    AND #$0f  ; otherwise, mask out low nybble
    CMP #$0f  ; row 15?
    BEQ bra_smb2_main_classify_area_object_row_14  ; if so, keep the offset of 16
    LDX #$08  ; otherwise load offset of 8 for special row 12
    CMP #$0c  ; row 12?
    BEQ bra_smb2_main_classify_area_object_row_14  ; if so, keep the offset value of 8
    LDX #$00  ; otherwise nullify value by default
bra_smb2_main_classify_area_object_row_14:
    STX $07  ; store whatever value we just loaded here
    LDX ObjectOffset  ; get object offset again
    CMP #$0e  ; row 14?
    BNE bra_smb2_main_decode_area_object_row_13
    LDA #$00  ; if so, load offset with $00
    STA $07
    LDA #$36  ; and load A with another value
    BNE bra_smb2_main_dispatch_decoded_area_object  ; unconditional branch
bra_smb2_main_decode_area_object_row_13:
    CMP #$0d  ; row 13?
    BNE bra_smb2_main_classify_special_area_object_rows
    LDA #$28  ; if so, load offset with 40
    STA $07
    INY  ; get next byte
    LDA (AreaData),y
    AND #%01000000  ; mask out all but d6 (page control obj bit)
    BEQ bra_smb2_main_exit_area_object_decoder  ; if d6 clear, branch to leave (we handled this earlier)
    LDA (AreaData),y  ; otherwise, get byte again
    AND #%01111111  ; mask out d7
    CMP #$4b  ; check for loop command in low nybble
    BNE bra_smb2_main_decode_row_13_object_id  ; (plus d6 set for object other than page control)
    INC LoopCommand  ; if loop command, set loop command flag
bra_smb2_main_decode_row_13_object_id:
    AND #%00111111  ; mask out d7 and d6
    JMP bra_smb2_main_dispatch_decoded_area_object  ; and jump
bra_smb2_main_classify_special_area_object_rows:
    CMP #$0c  ; row 12-15?
    BCS bra_smb2_main_decode_special_row_object
    INY  ; if not, get second byte of level object
    LDA (AreaData),y
    AND #%01110000  ; mask out all but d6-d4
    BNE bra_smb2_main_decode_large_area_object  ; if any bits set, branch to handle large object
    LDA #$18
    STA $07  ; otherwise set offset of 24 for small object
    LDA (AreaData),y  ; reload second byte of level object
    AND #%00001111  ; mask out higher nybble and jump
    JMP bra_smb2_main_dispatch_decoded_area_object
bra_smb2_main_decode_large_area_object:
    STA $00  ; store value here (branch for large objects)
    CMP #$70  ; check for vertical pipe object
    BNE bra_smb2_main_finish_large_area_object_id
    LDA (AreaData),y  ; if not, reload second byte
    AND #%00001000  ; mask out all but d3 (usage control bit)
    BEQ bra_smb2_main_finish_large_area_object_id  ; if d3 clear, branch to get original value
    LDA #$00  ; otherwise, nullify value for warp pipe
    STA $00
bra_smb2_main_finish_large_area_object_id:
    LDA $00  ; get value and jump ahead
    JMP loc_smb2_main_shift_area_object_id
bra_smb2_main_decode_special_row_object:
    INY  ; branch here for rows 12-15
    LDA (AreaData),y
    AND #%01110000  ; get next byte and mask out all but d6-d4
loc_smb2_main_shift_area_object_id:
    LSR  ; move d6-d4 to lower nybble
    LSR
    LSR
    LSR
bra_smb2_main_dispatch_decoded_area_object:
    STA $00  ; store value here (branch for small objects and rows 13 and 14)
    LDA AreaObjectLength,x  ; is there something stored here already?
    BPL bra_smb2_main_dispatch_current_area_object  ; if so, branch to do its particular sub
    LDA AreaObjectPageLoc  ; otherwise check to see if the object we've loaded is on the
    CMP CurrentPageLoc  ; same page as the renderer, and if so, branch
    BEQ bra_smb2_main_initialize_current_area_object
    LDY AreaDataOffset  ; if not, get old offset of level pointer
    LDA (AreaData),y  ; and reload first byte
    AND #%00001111
    CMP #$0e  ; row 14?
    BNE bra_smb2_main_exit_area_object_decoder
    LDA BackloadingFlag  ; if so, check backloading flag
    BNE bra_smb2_main_store_area_object_stream_offset  ; if set, branch to render object, else leave
bra_smb2_main_exit_area_object_decoder:
    RTS
bra_smb2_main_initialize_current_area_object:
    LDA BackloadingFlag  ; check backloading flag to see if it's been initialized
    BEQ bra_smb2_main_compare_area_object_column  ; branch to column-wise check
    LDA #$00  ; if not, initialize both backloading and
    STA BackloadingFlag  ; behind-renderer flags and leave
    STA BehindAreaParserFlag
    STA ObjectOffset
handler_smb2_main_loop_command:
    RTS
bra_smb2_main_compare_area_object_column:
    LDY AreaDataOffset  ; get first byte again
    LDA (AreaData),y
    AND #%11110000  ; mask out low nybble and move high to low
    LSR
    LSR
    LSR
    LSR
    CMP CurrentColumnPos  ; is this where we're at?
    BNE bra_smb2_main_exit_area_object_decoder  ; if not, branch to leave
bra_smb2_main_store_area_object_stream_offset:
    LDA AreaDataOffset  ; if so, load area obj offset and store in buffer
    STA AreaObjOffsetBuffer,x
    JSR sub_smb2_main_advance_area_object_stream  ; do sub to increment to next object data
bra_smb2_main_dispatch_current_area_object:
    LDA $00  ; get stored value and add offset to it
    CLC  ; then use the jump engine with current contents of A
    ADC $07
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_draw_vertical_pipe
    .word handler_smb2_main_set_area_style
    .word handler_smb2_main_draw_brick_row
    .word handler_smb2_main_draw_solid_block_row
    .word handler_smb2_main_draw_coin_row
    .word handler_smb2_main_draw_brick_column
    .word handler_smb2_main_draw_solid_block_column
    .word handler_smb2_main_draw_vertical_pipe

    .word handler_smb2_main_empty_hole
    .word handler_smb2_main_draw_pulley_rope
    .word handler_smb2_main_draw_high_bridge
    .word handler_smb2_main_draw_middle_bridge
    .word handler_smb2_main_draw_low_bridge
    .word handler_smb2_main_water_hole
    .word handler_smb2_main_draw_high_question_block_row
    .word handler_smb2_main_draw_low_question_block_row

    .word handler_smb2_main_draw_endless_rope
    .word handler_smb2_main_draw_balance_platform_rope
    .word handler_smb2_main_draw_castle_structure
    .word handler_smb2_main_draw_staircase
    .word handler_smb2_main_draw_exit_pipe
    .word handler_smb2_main_residual_flag_balls
    .word handler_smb2_data4_upside_down_pipe_high
    .word handler_smb2_data4_upside_down_pipe_low

    .word handler_smb2_main_draw_question_block
    .word handler_smb2_main_draw_question_block
    .word handler_smb2_main_draw_question_block
    .word handler_smb2_main_draw_question_block
    .word handler_smb2_main_draw_hidden_extra_life_block
    .word handler_smb2_main_draw_question_block
    .word handler_smb2_main_draw_question_block
    .word handler_smb2_main_draw_item_brick
    .word handler_smb2_main_draw_item_brick
    .word handler_smb2_main_draw_item_brick
    .word handler_smb2_main_draw_item_brick
    .word handler_smb2_main_draw_coin_brick
    .word handler_smb2_main_draw_item_brick
    .word handler_smb2_main_draw_water_pipe
    .word handler_smb2_main_draw_empty_block
    .word handler_smb2_main_draw_jumpspring

    .word handler_smb2_main_draw_intro_pipe
    .word handler_smb2_main_draw_flagpole_object
    .word handler_smb2_main_draw_axe
    .word handler_smb2_main_draw_chain
    .word handler_smb2_main_draw_castle_bridge
    .word handler_smb2_main_warp_zone_scroll_lock
    .word handler_smb2_main_toggle_scroll_lock
    .word handler_smb2_main_toggle_scroll_lock
    .word handler_smb2_main_set_area_frenzy
    .word handler_smb2_main_set_area_frenzy
    .word handler_smb2_main_set_area_frenzy
    .word handler_smb2_main_loop_command
    .word handler_smb2_data4_wind_on  ; these two are in SM2DATA2 and SM2DATA4
    .word handler_smb2_data4_wind_off

    .word handler_smb2_main_alter_area_attributes

; -------------------------------------------------------------------------------------
; (these apply to all area object subroutines in this section unless otherwise stated)
; $00 - used to store offset used to find object code
; $07 - starts with adder from area parser, used to store row offset
