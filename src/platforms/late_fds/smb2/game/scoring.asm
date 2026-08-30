off_smb2_main_floating_score_tiles:
    .byte $ff, $ff  ; dummy
    .byte $f6, $fb  ; "100"
    .byte $f7, $fb  ; "200"
    .byte $f8, $fb  ; "400"
    .byte $f9, $fb  ; "500"
    .byte $fa, $fb  ; "800"
    .byte $f6, $50  ; "1000"
    .byte $f7, $50  ; "2000"
    .byte $f8, $50  ; "4000"
    .byte $f9, $50  ; "5000"
    .byte $fa, $50  ; "8000"
    .byte $fd, $fe  ; "1-UP"

; high nybble is digit number, low nybble is number to
; add to the digit of the player's score
off_smb2_main_victory_score_digit_updates:
    .byte $ff  ; dummy
    .byte $41, $42, $44, $45, $48
    .byte $31, $32, $34, $35, $38, $00

sub_smb2_main_floatey_numbers_routine:
    LDA FloateyNum_Control,x  ; load control for floatey number
    BEQ bra_smb2_main_end_exit  ; if zero, branch to leave
    CMP #$0b  ; if less than $0b, branch
    BCC bra_smb2_main_check_floating_score_timer
    LDA #$0b  ; otherwise set to $0b, thus keeping
    STA FloateyNum_Control,x  ; it in range
bra_smb2_main_check_floating_score_timer:
    TAY  ; use as Y
    LDA FloateyNum_Timer,x  ; check value here
    BNE bra_smb2_main_decrement_floating_score_timer  ; if nonzero, branch ahead
    STA FloateyNum_Control,x  ; initialize floatey number control and leave
    RTS
bra_smb2_main_decrement_floating_score_timer:
    DEC FloateyNum_Timer,x  ; decrement value here
    CMP #$2b  ; if not reached a certain point, branch
    BNE bra_smb2_main_check_tall_enemy_collision_shape
    CPY #$0b  ; check offset for $0b
    BNE bra_smb2_main_award_floating_score  ; branch ahead if not found
    INC NumberofLives  ; give player one extra life (1-up)
    LDA #Sfx_ExtraLife
    STA Square2SoundQueue  ; and play the 1-up sound
bra_smb2_main_award_floating_score:
    LDA off_smb2_main_victory_score_digit_updates,y  ; load point value here
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    TAX  ; use as X offset, essentially the digit
    LDA off_smb2_main_victory_score_digit_updates,y  ; load again and this time
    AND #%00001111  ; mask out the high nybble
    STA DigitModifier,x  ; store as amount to add to the digit
    JSR sub_smb2_main_add_to_score  ; update the score accordingly
bra_smb2_main_check_tall_enemy_collision_shape:
    LDY Enemy_SprDataOffset,x  ; get OAM data offset for enemy object
    LDA Enemy_ID,x  ; get enemy object identifier
    CMP #Spiny
    BEQ bra_smb2_main_update_floating_score_position  ; branch if spiny
    CMP #PiranhaPlant
    BEQ bra_smb2_main_update_floating_score_position  ; branch if piranha plant
    CMP #HammerBro
    BEQ bra_smb2_main_use_alternate_score_oam_offset  ; branch elsewhere if hammer bro
    CMP #GreyCheepCheep
    BEQ bra_smb2_main_update_floating_score_position  ; branch if cheep-cheep of either color
    CMP #RedCheepCheep
    BEQ bra_smb2_main_update_floating_score_position
    CMP #TallEnemy
    BCS bra_smb2_main_use_alternate_score_oam_offset  ; branch elsewhere if enemy object => $09
    LDA Enemy_State,x
    CMP #$02  ; if enemy state defeated or otherwise
    BCS bra_smb2_main_update_floating_score_position  ; $02 or greater, branch beyond this part
bra_smb2_main_use_alternate_score_oam_offset:
    LDX SprDataOffset_Ctrl  ; load some kind of control bit
    LDY Alt_SprDataOffset,x  ; get alternate OAM data offset
    LDX ObjectOffset  ; get enemy object offset again
bra_smb2_main_update_floating_score_position:
    LDA FloateyNum_Y_Pos,x  ; get vertical coordinate for
    CMP #$18  ; floatey number, if coordinate in the
    BCC bra_smb2_main_render_floating_score_sprites  ; status bar, branch
    SBC #$01
    STA FloateyNum_Y_Pos,x  ; otherwise subtract one and store as new
bra_smb2_main_render_floating_score_sprites:
    LDA FloateyNum_Y_Pos,x  ; get vertical coordinate
    SBC #$08  ; subtract eight and dump into the
    JSR sub_smb2_main_fill_two_sprite_fields  ; left and right sprite's Y coordinates
    LDA FloateyNum_X_Pos,x  ; get horizontal coordinate
    STA Sprite_X_Position,y  ; store into X coordinate of left sprite
    CLC
    ADC #$08  ; add eight pixels and store into X
    STA Sprite_X_Position+4,y  ; coordinate of right sprite
    LDA #$02
    STA Sprite_Attributes,y  ; set palette control in attribute bytes
    STA Sprite_Attributes+4,y  ; of left and right sprites
    LDA FloateyNum_Control,x
    ASL  ; multiply our floatey number control by 2
    TAX  ; and use as offset for look-up table
    LDA off_smb2_main_floating_score_tiles,x
    STA Sprite_Tilenumber,y  ; display first half of number of points
    LDA off_smb2_main_floating_score_tiles+1,x
    STA Sprite_Tilenumber+4,y  ; display the second half
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_run_screen_task:
    LDA ScreenRoutineTask
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_initialize_screen
    .word handler_smb2_main_setup_intermediate_screen
    .word handler_smb2_main_write_top_status_line
    .word handler_smb2_main_write_bottom_status_line
    .word handler_smb2_main_display_time_up_screen
    .word handler_smb2_main_reset_sprites_after_screen_delay
    .word handler_smb2_main_display_intermediate_screen
    .word handler_smb2_main_demo_reset
    .word handler_smb2_main_reset_sprites_after_screen_delay
    .word handler_smb2_main_render_initial_area_columns
    .word handler_smb2_main_select_area_palette
    .word handler_smb2_main_prepare_background_and_player_colors
    .word handler_smb2_main_select_mushroom_area_palette
    .word handler_smb2_main_copy_title_screen_from_chr
    .word handler_smb2_main_clear_title_buffers_and_draw_icon
    .word handler_smb2_main_write_title_top_score

handler_smb2_main_initialize_screen:
    JSR sub_smb2_main_move_all_sprites_offscreen  ; initialize all sprites including sprite #0
    JSR sub_smb2_main_initialize_name_tables  ; and erase both name and attribute tables
    LDA OperMode
    BEQ bra_smb2_main_advance_screen_task  ; if in attact mode, do not set pointer control
handler_smb2_main_init_screen_palette:
    LDX #$03  ; otherwise set for underground palette
    JMP loc_smb2_main_store_vram_buffer_control_from_x

handler_smb2_main_setup_intermediate_screen:
    LDA BackgroundColorCtrl  ; save current background color control
    PHA  ; and player status to stack
    LDA PlayerStatus
    PHA
    LDA #$00  ; set background color to black
    STA PlayerStatus  ; and player status to not fiery
    LDA #$02  ; this is the ONLY time background color control
    STA BackgroundColorCtrl  ; is set to less than 4
    JSR sub_smb2_main_get_player_colors
    PLA  ; set up colors for intermediate lives display
    STA PlayerStatus
    PLA  ; return bg color control and player status
    STA BackgroundColorCtrl
    JMP bra_smb2_main_advance_screen_task_variant_2  ; then move onto the next task

off_smb2_main_area_palette_buffer_controls:
    .byte $01, $02, $03, $04

handler_smb2_main_select_area_palette:
    LDY AreaType  ; select appropriate palette to load
    LDX off_smb2_main_area_palette_buffer_controls,y  ; based on area type
loc_smb2_main_store_vram_buffer_control_from_x:
    STX VRAM_Buffer_AddrCtrl  ; store offset into buffer control
bra_smb2_main_advance_screen_task:
    JMP bra_smb2_main_advance_screen_task_variant_2  ; move onto next task

; -------------------------------------------------------------------------------------
; $00 - used as temp counter in GetPlayerColors

tbl_smb2_main_background_color_buffer_controls:
    .byte $00, $09, $0a, $04

tbl_smb2_main_background_colors:
    .byte $22, $22, $0f, $0f  ; used by area type if bg color ctrl not set
    .byte $0f, $22, $0f, $0f  ; used by background color control if set

tbl_smb2_main_player_palette_colors:
    .byte $22, $16, $27, $18  ; player's normal colors, may be overwritten
    .byte $22, $37, $27, $16  ; player's colors after grabbing fire flower

handler_smb2_main_prepare_background_and_player_colors:
    LDY BackgroundColorCtrl  ; check background color control
    BEQ bra_smb2_main_prepare_player_colors  ; if not set, increment task and fetch palette
    LDA tbl_smb2_main_background_color_buffer_controls-4,y  ; put appropriate palette into vram
    STA VRAM_Buffer_AddrCtrl  ; note that if set to 5-7, first VRAM buffer will not be read
bra_smb2_main_prepare_player_colors:
    INC ScreenRoutineTask  ; increment to next subtask and plod on through

sub_smb2_main_get_player_colors:
    LDX VRAM_Buffer1_Offset  ; get current buffer offset
    LDY #$00
loc_smb2_main_check_fiery_player_palette:
    LDA PlayerStatus  ; check player status
    CMP #$02
    BNE bra_smb2_main_copy_player_palette_colors  ; if fiery, load alternate offset for fiery player
    LDY #$04
bra_smb2_main_copy_player_palette_colors:
    LDA #$03  ; do four colors
    STA $00
bra_smb2_main_copy_player_palette_colors_loop:
    LDA tbl_smb2_main_player_palette_colors,y  ; fetch player colors and store them
    STA VRAM_Buffer1+3,x  ; in the buffer
    INY
    INX
    DEC $00
    BPL bra_smb2_main_copy_player_palette_colors_loop
    LDX VRAM_Buffer1_Offset  ; load original offset from before
    LDY BackgroundColorCtrl  ; if this value is four or greater, it will be set
    BNE bra_smb2_main_store_background_color  ; therefore use it as offset to background color
    LDY AreaType  ; otherwise use area type bits from area offset as offset
bra_smb2_main_store_background_color:
    LDA tbl_smb2_main_background_colors,y  ; to background color instead
    STA VRAM_Buffer1+3,x
    LDA #$3f  ; set for sprite palette address
    STA VRAM_Buffer1,x  ; save to buffer
    LDA #$10
    STA VRAM_Buffer1+1,x
    LDA #$04  ; write length byte to buffer
    STA VRAM_Buffer1+2,x
    LDA #$00  ; now the null terminator
    STA VRAM_Buffer1+7,x
    TXA  ; move the buffer pointer ahead 7 bytes
    CLC  ; in case we want to write anything else later
    ADC #$07
loc_smb2_main_store_primary_vram_buffer_offset:
    STA VRAM_Buffer1_Offset  ; store as new vram buffer offset
    RTS

handler_smb2_main_select_mushroom_area_palette:
    LDA AreaStyle  ; check for mushroom level style
    CMP #$01
    BNE bra_smb2_main_finish_alternate_palette_selection
    LDA #$0b  ; if found, load appropriate palette
loc_smb2_main_store_vram_buffer_control_from_a:
    STA VRAM_Buffer_AddrCtrl
bra_smb2_main_finish_alternate_palette_selection:
    JMP bra_smb2_main_advance_screen_task_variant_2  ; now onto the next task

handler_smb2_main_write_top_status_line:
    LDA #$00  ; select main status bar
    JSR sub_smb2_main_write_game_text  ; output it
    JMP bra_smb2_main_advance_screen_task_variant_2  ; onto the next task

handler_smb2_main_write_bottom_status_line:
    JSR sub_smb2_main_write_score_and_coin_tally  ; write player's score and coin tally to screen
    LDX VRAM_Buffer1_Offset
    LDA #$20  ; write address for world-area number on screen
    STA VRAM_Buffer1,x
    LDA #$73
    STA VRAM_Buffer1+1,x
    LDA #$03  ; write length for it
    STA VRAM_Buffer1+2,x
    JSR sub_smb2_main_get_world_num_for_display  ; first the world number
    STA VRAM_Buffer1+3,x
    LDA #$28  ; next the dash
    STA VRAM_Buffer1+4,x
    LDY LevelNumber  ; next the level number
    INY  ; increment for proper number display
    TYA
    STA VRAM_Buffer1+5,x
    LDA #$00  ; put null terminator at the end
    STA VRAM_Buffer1+6,x
    TXA  ; move the buffer offset up by 6 bytes
    CLC
    ADC #$06
    STA VRAM_Buffer1_Offset
    JMP bra_smb2_main_advance_screen_task_variant_2

sub_smb2_main_get_world_num_for_display:
    LDY WorldNumber
    LDA HardWorldFlag  ; if not in worlds A-D, branch to use digits 1-8
    BEQ bra_smb2_main_format_world_number_for_display
    TYA
    AND #$03  ; otherwise mask out any world numbers higher than 4
    CLC  ; and add 9 to get the proper letter A thru D
    ADC #$09
    TAY
bra_smb2_main_format_world_number_for_display:
    INY  ; increment the world number/letter because
    TYA  ; the internal world number counts from 0, not 1
    RTS

handler_smb2_main_display_time_up_screen:
    LDA GameTimerExpiredFlag  ; if game timer not expired, increment task
    BEQ bra_smb2_main_inc_subtaskby2  ; control 2 tasks forward, otherwise, stay here
    LDA #$00
    STA GameTimerExpiredFlag  ; reset timer expiration flag
    LDA #$02  ; output time-up screen to buffer
sub_smb2_main_other_inter:
    JSR sub_smb2_main_write_game_text
    JSR sub_smb2_main_reset_screen_timer
    LDA #$00
    STA DisableScreenFlag
    RTS

bra_smb2_main_inc_subtaskby2:
    INC ScreenRoutineTask
bra_smb2_main_advance_screen_task_variant_2:
    INC ScreenRoutineTask
    RTS

handler_smb2_main_display_intermediate_screen:
    LDA OperMode  ; check primary mode of operation
    BEQ bra_smb2_main_skip_intermediate_screen  ; if in attract mode, do not display intermediate screens
    CMP #GameOverMode  ; are we in game over mode?
    BEQ bra_smb2_main_display_game_over_screen  ; if so, proceed to display game over screen
    LDA AltEntranceControl  ; otherwise check for mode of alternate entry
    BNE bra_smb2_main_skip_intermediate_screen  ; and branch if found
    LDY AreaType  ; check if we are on castle level
    CPY #$03  ; and if so, branch (possibly residual)
    BEQ bra_smb2_main_display_world_lives_screen
    LDA DisableIntermediate  ; if this flag is set, skip intermediate lives display
    BNE bra_smb2_main_skip_intermediate_screen  ; and jump to specific task, otherwise
bra_smb2_main_display_world_lives_screen:
    JSR sub_smb2_main_draw_player_intermediate  ; put player in appropriate place for
    LDA #$01  ; lives display, then output lives display to buffer
loc_smb2_main_output_intermediate_screen:
    JSR sub_smb2_main_other_inter
    LDA WorldNumber  ; if on any world besides 9, do next task
    CMP #World9
    BNE bra_smb2_main_advance_screen_task_variant_2
    INC DisableScreenFlag  ; disable screen output
    RTS

bra_smb2_main_display_game_over_screen:
    LDA #$03  ; output game over screen to buffer
    JSR sub_smb2_main_write_game_text
    LDA WorldNumber
    CMP #World9
    BEQ bra_smb2_main_advance_screen_task_variant_2
    JMP bra_smb2_main_inc_mode_task

bra_smb2_main_skip_intermediate_screen:
    LDA #$09  ; skip ahead in screen routine list
    STA ScreenRoutineTask  ; to execute area parser
    RTS

handler_smb2_main_render_initial_area_columns:
    INC DisableScreenFlag  ; turn off screen
bra_smb2_main_run_initial_area_parser_tasks:
    JSR sub_smb2_main_area_parser_task_handler  ; render column set of current area
    LDA AreaParserTaskNum  ; check number of tasks
    BNE bra_smb2_main_run_initial_area_parser_tasks  ; if tasks still not all done, do another one
    DEC ColumnSets  ; do we need to render more column sets?
    BPL bra_smb2_main_queue_rendered_area_columns
    INC ScreenRoutineTask  ; if not, move on to the next task
bra_smb2_main_queue_rendered_area_columns:
    LDA #$06  ; set vram buffer to output rendered column set
    STA VRAM_Buffer_AddrCtrl  ; on next NMI
    RTS

tbl_smb2_main_game_text_packets:
tbl_smb2_main_top_status_bar_packet:
    .byte $20, $43, $05, $16, $0a, $1b, $12, $18  ; "MARIO"
    .byte $20, $52, $0b, $20, $18, $1b, $15, $0d  ; "WORLD  TIME"
    .byte $24, $24, $1d, $12, $16, $0e
    .byte $20, $68, $05, $00, $24, $24, $2e, $29  ; score trailing digit and coin display
    .byte $23, $c0, $7f, $aa  ; attribute table data, clears name table 0 to palette 2
    .byte $23, $c2, $01, $ea  ; attribute table data, used for coin icon in status bar
    .byte $ff  ; end of data block

tbl_smb2_main_world_lives_display_packet:
    .byte $21, $cd, $07, $24, $24  ; cross with spaces used on
    .byte $29, $24, $24, $24, $24  ; lives display
    .byte $21, $4b, $09, $20, $18  ; "WORLD  - " used on lives display
    .byte $1b, $15, $0d, $24, $24, $28, $24
    .byte $22, $0c, $47, $24  ; possibly used to clear time up
    .byte $23, $dc, $01, $ba  ; attribute table data for crown if more than 9 lives
    .byte $ff

tbl_smb2_main_time_up:
    .byte $22, $0c, $07, $1d, $12, $16, $0e, $24, $1e, $19  ; "TIME UP"
    .byte $ff

tbl_smb2_main_game_over:
    .byte $21, $6b, $09, $10, $0a, $16, $0e, $24  ; "GAME OVER"
    .byte $18, $1f, $0e, $1b
    .byte $21, $eb, $08, $0c, $18, $17, $1d, $12, $17, $1e, $0e  ; "CONTINUE"
    .byte $22, $0c, $47, $24
    .byte $22, $4b, $05, $1b, $0e, $1d, $1b, $22  ; "RETRY"
    .byte $ff

tbl_smb2_main_warp_zone:
    .byte $25, $84, $15
    .byte $20, $0e, $15, $0c, $18, $16, $0e, $24, $1d, $18  ; "WELCOME TO WARP ZONE!"
    .byte $24, $20, $0a, $1b, $19, $24, $23, $18, $17, $0e
    .byte $2b
    .byte $26, $2d, $01, $24  ; blank filler for world number
    .byte $27, $d9, $46, $aa  ; attribute data
    .byte $27, $e1, $45, $aa
    .byte $00

tbl_smb2_main_warp_zone_number_tiles:
    .byte $02, $03, $04, $01, $06, $07, $08, $05, $0b, $0c, $0d

tbl_smb2_main_game_text_packet_offsets:
    .byte <(tbl_smb2_main_top_status_bar_packet-tbl_smb2_main_game_text_packets)
    .byte <(tbl_smb2_main_world_lives_display_packet-tbl_smb2_main_game_text_packets)
    .byte <(tbl_smb2_main_time_up-tbl_smb2_main_game_text_packets)
    .byte <(tbl_smb2_main_game_over-tbl_smb2_main_game_text_packets)

sub_smb2_main_write_game_text:
    PHA  ; save text number to stack and use as offset
    TAY
    LDX tbl_smb2_main_game_text_packet_offsets,y  ; get offset to game text we want to print
    LDY #$00
bra_smb2_main_copy_game_text_packet:
    LDA tbl_smb2_main_game_text_packets,x  ; load game text data
    CMP #$ff  ; check for terminator
    BEQ bra_smb2_main_finish_game_text_packet  ; branch to end text if found
    STA VRAM_Buffer1,y  ; otherwise write data to buffer
    INX  ; and increment increment
    INY
    BNE bra_smb2_main_copy_game_text_packet  ; do this for 256 bytes if no terminator found
bra_smb2_main_finish_game_text_packet:
    LDA #$00  ; put null terminator at end
    STA VRAM_Buffer1,y
    PLA  ; pull original text number from stack
    BEQ bra_smb2_main_exit_game_timer_update  ; if printing top status bar, branch to leave
    TAX
    DEX  ; if printing anything else besides world/lives display
    BNE bra_smb2_main_exit_game_timer_update  ; then branch to leave
    LDA NumberofLives  ; otherwise, check number of lives
    CLC  ; and increment by one for display
    ADC #$01
    CMP #10  ; more than 9 lives?
    BCC bra_smb2_main_store_world_lives_values
    SBC #10  ; if so, subtract 10 and put a crown tile
    LDY #$9f  ; next to the difference...strange things happen if
    STY VRAM_Buffer1+7  ; the number of lives exceeds 19
bra_smb2_main_store_world_lives_values:
    STA VRAM_Buffer1+8
    JSR sub_smb2_main_get_world_num_for_display  ; get world number or letter
    STA VRAM_Buffer1+19
    LDY LevelNumber
    INY
    STY VRAM_Buffer1+21  ; we're done here
bra_smb2_main_exit_game_timer_update:
    RTS

sub_smb2_main_write_warp_zone_message:
    PHA  ; save warp zone control temporarily
    LDY #$ff
bra_smb2_main_write_warp_zone_message_loop:
    INY
    LDA tbl_smb2_main_warp_zone,y  ; write warp zone message to VRAM buffer
    STA VRAM_Buffer1,y
    BNE bra_smb2_main_write_warp_zone_message_loop
    PLA
    SEC
    SBC #$80  ; clear d7 of warp zone control, use as offset
    TAX
    LDA tbl_smb2_main_warp_zone_number_tiles,x  ; replace blank tile with world number
    STA VRAM_Buffer1+27  ; that the warp zone leads to
    LDA #$24  ; set VRAM offset after the contents
    JMP loc_smb2_main_store_primary_vram_buffer_offset  ; in case anything else needs to go in there

handler_smb2_main_reset_sprites_after_screen_delay:
    LDA ScreenTimer  ; check if screen timer has expired
    BNE bra_smb2_main_exit_screen_timer_reset  ; if not, branch to leave
    JSR sub_smb2_main_move_all_sprites_offscreen  ; otherwise reset sprites now

sub_smb2_main_reset_screen_timer:
    LDA #$07  ; reset timer again
    STA ScreenTimer
    INC ScreenRoutineTask  ; move onto next task
bra_smb2_main_exit_screen_timer_reset:
    RTS

; -------------------------------------------------------------------------------------
; $00 - temp vram buffer offset
; $01 - temp metatile buffer offset
; $02 - temp metatile graphics table offset
; $03 - used to store attribute bits
; $04 - used to determine attribute table row
; $05 - used to determine attribute table column
; $06 - metatile graphics table address low
; $07 - metatile graphics table address high

handler_smb2_main_render_area_column:
    LDA CurrentColumnPos  ; store LSB of where we're at
    AND #$01
    STA $05
    LDY VRAM_Buffer2_Offset  ; store vram buffer offset
    STY $00
    LDA CurrentNTAddr_Low  ; get current name table address we're supposed to render
    STA VRAM_Buffer2+1,y
    LDA CurrentNTAddr_High
    STA VRAM_Buffer2,y
    LDA #$9a  ; store length byte of 26 here with d7 set
    STA VRAM_Buffer2+2,y  ; to increment by 32 (in columns)
    LDA #$00  ; init attribute row
    STA $04
    TAX
bra_smb2_main_draw_metatile_column_loop:
    STX $01  ; store init value of 0 or incremented offset for buffer
    LDA MetatileBuffer,x  ; get first metatile number, and mask out all but 2 MSB
    AND #%11000000
    STA $03  ; store attribute table bits here
    ASL  ; note that metatile format is:
    ROL  ; %xx000000 - attribute table bits,
    ROL  ; %00xxxxxx - metatile number
    TAY  ; rotate bits to d1-d0 and use as offset here
    LDA tbl_smb2_main_metatile_graphics_pointers_low,y  ; get address to graphics table from here
    STA $06
    LDA tbl_smb2_main_metatile_graphics_pointers_high,y
    STA $07
    LDA MetatileBuffer,x  ; get metatile number again
    ASL  ; multiply by 4 and use as tile offset
    ASL
    STA $02
    LDA AreaParserTaskNum  ; get current task number for level processing and
    AND #%00000001  ; mask out all but LSB, then invert LSB, multiply by 2
    EOR #%00000001  ; to get the correct column position in the metatile,
    ASL  ; then add to the tile offset so we can draw either side
    ADC $02  ; of the metatiles
    TAY
    LDX $00  ; use vram buffer offset from before as X
    LDA ($06),y
    STA VRAM_Buffer2+3,x  ; get first tile number (top left or top right) and store
    INY
    LDA ($06),y  ; now get the second (bottom left or bottom right) and store
    STA VRAM_Buffer2+4,x
    LDY $04  ; get current attribute row
    LDA $05  ; get LSB of current column where we're at, and
    BNE bra_smb2_main_position_right_metatile_attributes  ; branch if set (clear = left attrib, set = right)
    LDA $01  ; get current row we're rendering
    LSR  ; branch if LSB set (clear = top left, set = bottom left)
    BCS bra_smb2_main_position_lower_left_metatile_attributes
    ROL $03  ; rotate attribute bits 3 to the left
    ROL $03  ; thus in d1-d0, for upper left square
    ROL $03
    JMP loc_smb2_main_merge_metatile_attributes
bra_smb2_main_position_right_metatile_attributes:
    LDA $01  ; get LSB of current row we're rendering
    LSR  ; branch if set (clear = top right, set = bottom right)
    BCS bra_smb2_main_advance_metatile_attribute_row
    LSR $03  ; shift attribute bits 4 to the right
    LSR $03  ; thus in d3-d2, for upper right square
    LSR $03
    LSR $03
    JMP loc_smb2_main_merge_metatile_attributes
bra_smb2_main_position_lower_left_metatile_attributes:
    LSR $03  ; shift attribute bits 2 to the right
    LSR $03  ; thus in d5-d4 for lower left square
bra_smb2_main_advance_metatile_attribute_row:
    INC $04  ; move onto next attribute row
loc_smb2_main_merge_metatile_attributes:
    LDA AttributeBuffer,y  ; get previously saved bits from before
    ORA $03  ; if any, and put new bits, if any, onto
    STA AttributeBuffer,y  ; the old, and store
    INC $00  ; increment vram buffer offset by 2
    INC $00
    LDX $01  ; get current gfx buffer row, and check for
    INX  ; the bottom of the screen
    CPX #$0d
    BCC bra_smb2_main_draw_metatile_column_loop  ; if not there yet, loop back
    LDY $00  ; get current vram buffer offset, increment by 3
    INY  ; (for name table address and length bytes)
    INY
    INY
    LDA #$00
    STA VRAM_Buffer2,y  ; put null terminator at end of data for name table
    STY VRAM_Buffer2_Offset  ; store new buffer offset
    INC CurrentNTAddr_Low  ; increment name table address low
    LDA CurrentNTAddr_Low  ; check current low byte
    AND #%00011111  ; if no wraparound, just skip this part
    BNE bra_smb2_main_finish_area_column_render
    LDA #$80  ; if wraparound occurs, make sure low byte stays
    STA CurrentNTAddr_Low  ; just under the status bar
    LDA CurrentNTAddr_High  ; and then invert d2 of the name table address high
    EOR #%00000100  ; to move onto the next appropriate name table
    STA CurrentNTAddr_High
bra_smb2_main_finish_area_column_render:
    JMP loc_smb2_main_select_secondary_vram_buffer  ; jump to set VRAM address controller

sub_smb2_main_render_attribute_tables:
    LDA CurrentNTAddr_Low  ; get low byte of next name table address
    AND #%00011111  ; to be written to, mask out all but 5 LSB,
    SEC  ; subtract four
    SBC #$04
    AND #%00011111  ; mask out bits again and store
    STA $01
    LDA CurrentNTAddr_High  ; get high byte and branch if borrow not set
    BCS bra_smb2_main_compute_attribute_table_address_high
    EOR #%00000100  ; otherwise invert d2
bra_smb2_main_compute_attribute_table_address_high:
    AND #%00000100  ; mask out all other bits
    ORA #$23  ; add $2300 (for attribute table) to the high byte
    STA $00
    LDA $01  ; get low byte - 4, divide by 4, add offset for
    LSR  ; attribute table and store
    LSR
    ADC #$c0  ; we should now have the appropriate block of
    STA $01  ; attribute table in our temp address
    LDX #$00
    LDY VRAM_Buffer2_Offset  ; get buffer offset
bra_smb2_main_write_attribute_table_buffer:
    LDA $00
    STA VRAM_Buffer2,y  ; store high byte of attribute table address
    LDA $01
    CLC  ; get low byte, add 8 because we want to start
    ADC #$08  ; below the status bar, and store
    STA VRAM_Buffer2+1,y
    STA $01  ; also store in temp again
    LDA AttributeBuffer,x  ; fetch current attribute table byte and store
    STA VRAM_Buffer2+3,y  ; in the buffer
    LDA #$01
    STA VRAM_Buffer2+2,y  ; store length of 1 in buffer
    LSR
    STA AttributeBuffer,x  ; clear current byte in attribute buffer
    INY  ; increment buffer offset by 4 bytes
    INY
    INY
    INY
    INX  ; increment attribute offset and check to see
    CPX #$07  ; if we're at the end yet
    BCC bra_smb2_main_write_attribute_table_buffer
    STA VRAM_Buffer2,y  ; put null terminator at the end
    STY VRAM_Buffer2_Offset  ; store offset in case we want to do any more
loc_smb2_main_select_secondary_vram_buffer:
    LDA #$06
    STA VRAM_Buffer_AddrCtrl  ; set VRAM address controller to second VRAM buffer
    RTS

; -------------------------------------------------------------------------------------
; $00 - used as temporary counter in ColorRotation
