; -------------------------------------------------------------------------------------

handler_run_screen_task:
    LDA ram_screen_routine_task  ; run one of the following subroutines
    JSR sub_dispatch_inline_handler

    .word handler_initialize_screen
    .word handler_setup_intermediate_screen
    .word handler_write_top_status_line
    .word handler_write_bottom_status_line
    .word handler_display_time_up_screen
    .word handler_reset_sprites_after_screen_delay
    .word handler_display_intermediate_screen
    .word handler_reset_sprites_after_screen_delay
    .word handler_render_initial_area_columns
    .word handler_select_area_palette
    .word handler_prepare_background_and_player_colors
    .word handler_select_mushroom_area_palette
    .word handler_copy_title_screen_from_chr
    .word handler_clear_title_buffers_and_draw_icon
    .word handler_write_title_top_score

; -------------------------------------------------------------------------------------

handler_initialize_screen:
    JSR sub_move_all_sprites_offscreen  ; initialize all sprites including sprite #0
    JSR sub_initialize_name_tables  ; and erase both name and attribute tables
    LDA ram_oper_mode
    BEQ bra_advance_screen_task  ; if mode still 0, do not load
    LDX #$03  ; into buffer pointer
    JMP loc_store_vram_buffer_control_from_x

; -------------------------------------------------------------------------------------

handler_setup_intermediate_screen:
    LDA ram_background_color_ctrl  ; save current background color control
    PHA  ; and player status to stack
    LDA ram_player_status
    PHA
    LDA #$00  ; set background color to black
    STA ram_player_status  ; and player status to not fiery
    LDA #$02  ; this is the ONLY time background color control
    STA ram_background_color_ctrl  ; is set to less than 4
    JSR sub_get_player_colors
    PLA  ; we only execute this routine for
    STA ram_player_status  ; the intermediate lives display
    PLA  ; and once we're done, we return bg
    STA ram_background_color_ctrl  ; color ctrl and player status from stack
    JMP loc_advance_screen_task  ; then move onto the next task

; -------------------------------------------------------------------------------------

tbl_area_palette_buffer_controls:
    .byte $01, $02, $03, $04

handler_select_area_palette:
    LDY ram_area_type  ; select appropriate palette to load
    LDX tbl_area_palette_buffer_controls,y  ; based on area type
loc_store_vram_buffer_control_from_x:
    STX ram_vram_buffer_addr_ctrl  ; store offset into buffer control
bra_advance_screen_task:
    JMP loc_advance_screen_task  ; move onto next task

; -------------------------------------------------------------------------------------
; $00 - used as temp counter in sub_get_player_colors

tbl_background_color_buffer_controls:
    .byte $00, $09, $0a, $04

tbl_background_colors:
.if con_revision_profile = con_revision_profile_vs
    .byte $1a, $1a, $14, $14  ; Vs. colors selected by area type
    .byte $14, $1a, $14, $14  ; Vs. colors selected by background control
.else
    .byte $22, $22, $0f, $0f  ; used by area type if bg color ctrl not set
    .byte $0f, $22, $0f, $0f  ; used by background color control if set
.endif

tbl_player_palette_colors:
.if con_revision_profile = con_revision_profile_vs
    .byte $1a, $33, $39, $00  ; mario's Vs. palette
    .byte $1a, $36, $39, $1b  ; luigi's Vs. palette
    .byte $1a, $0d, $39, $33  ; fiery Vs. palette
.else
    .byte $22, $16, $27, $18  ; mario's colors
    .byte $22, $30, $27, $19  ; luigi's colors
    .byte $22, $37, $27, $16  ; fiery (used by both)
.endif

handler_prepare_background_and_player_colors:
    LDY ram_background_color_ctrl  ; check background color control
    BEQ bra_prepare_player_colors  ; if not set, increment task and fetch palette
    LDA tbl_background_color_buffer_controls-4,y  ; put appropriate palette into vram
    STA ram_vram_buffer_addr_ctrl  ; note that if set to 5-7, $0301 will not be read
bra_prepare_player_colors:
    INC ram_screen_routine_task  ; increment to next subtask and plod on through

sub_get_player_colors:
    LDX ram_vram_buffer1_offset  ; get current buffer offset
    LDY #$00
    LDA ram_current_player  ; check which player is on the screen
    BEQ bra_check_fiery_player_palette
    LDY #$04  ; load offset for luigi
bra_check_fiery_player_palette:
    LDA ram_player_status  ; check player status
    CMP #$02
    BNE bra_copy_player_palette_colors  ; if fiery, load alternate offset for fiery player
    LDY #$08
bra_copy_player_palette_colors:
    LDA #$03  ; do four colors
    STA $00
bra_copy_player_palette_colors_loop:
    LDA tbl_player_palette_colors,y  ; fetch player colors and store them
    STA ram_vram_buffer1+3,x  ; in the buffer
    INY
    INX
    DEC $00
    BPL bra_copy_player_palette_colors_loop
    LDX ram_vram_buffer1_offset  ; load original offset from before
    LDY ram_background_color_ctrl  ; if this value is four or greater, it will be set
    BNE bra_store_background_color  ; therefore use it as offset to background color
    LDY ram_area_type  ; otherwise use area type bits from area offset as offset
bra_store_background_color:
    LDA tbl_background_colors,y  ; to background color instead
    STA ram_vram_buffer1+3,x
    LDA #$3f  ; set for sprite palette address
    STA ram_vram_buffer1,x  ; save to buffer
    LDA #$10
    STA ram_vram_buffer1+1,x
    LDA #$04  ; write length byte to buffer
    STA ram_vram_buffer1+2,x
    LDA #$00  ; now the null terminator
    STA ram_vram_buffer1+7,x
    TXA  ; move the buffer pointer ahead 7 bytes
    CLC  ; in case we want to write anything else later
    ADC #$07
loc_store_primary_vram_buffer_offset:
    STA ram_vram_buffer1_offset  ; store as new vram buffer offset
    RTS

; -------------------------------------------------------------------------------------

handler_select_mushroom_area_palette:
    LDA ram_area_style  ; check for mushroom level style
    CMP #$01
    BNE bra_finish_alternate_palette_selection
    LDA #$0b  ; if found, load appropriate palette
loc_store_vram_buffer_control_from_a:
    STA ram_vram_buffer_addr_ctrl
bra_finish_alternate_palette_selection:
    JMP loc_advance_screen_task  ; now onto the next task

; -------------------------------------------------------------------------------------

handler_write_top_status_line:
    LDA #$00  ; select main status bar
    JSR sub_write_game_text  ; output it
    JMP loc_advance_screen_task  ; onto the next task

; -------------------------------------------------------------------------------------

handler_write_bottom_status_line:
    JSR sub_get_status_bar_nibbles  ; write player's score and coin tally to screen
    LDX ram_vram_buffer1_offset
    LDA #$20  ; write address for world-area number on screen
    STA ram_vram_buffer1,x
    LDA #$73
    STA ram_vram_buffer1+1,x
    LDA #$03  ; write length for it
    STA ram_vram_buffer1+2,x
    LDY ram_world_number  ; first the world number
    INY
    TYA
    STA ram_vram_buffer1+3,x
    LDA #$28  ; next the dash
    STA ram_vram_buffer1+4,x
    LDY ram_level_number  ; next the level number
    INY  ; increment for proper number display
    TYA
    STA ram_vram_buffer1+5,x
    LDA #$00  ; put null terminator on
    STA ram_vram_buffer1+6,x
    TXA  ; move the buffer offset up by 6 bytes
    CLC
    ADC #$06
    STA ram_vram_buffer1_offset
    JMP loc_advance_screen_task

; -------------------------------------------------------------------------------------

handler_display_time_up_screen:
    LDA ram_game_timer_expired_flag  ; if game timer not expired, increment task
    BEQ bra_skip_time_up_screen  ; control 2 tasks forward, otherwise, stay here
    LDA #$00
    STA ram_game_timer_expired_flag  ; reset timer expiration flag
    LDA #$02  ; output time-up screen to buffer
    JMP loc_output_intermediate_screen
bra_skip_time_up_screen:
    INC ram_screen_routine_task  ; increment control task 2 tasks forward
    JMP loc_advance_screen_task

; -------------------------------------------------------------------------------------

handler_display_intermediate_screen:
    LDA ram_oper_mode  ; check primary mode of operation
    BEQ bra_skip_intermediate_screen  ; if in title screen mode, skip this
.if con_revision_profile = con_revision_profile_vs
    CMP #con_vs_mode_game_over  ; are we in the Vs. game over mode?
.else
    CMP #con_mode_game_over  ; are we in game over mode?
.endif
    BEQ bra_display_game_over_screen  ; if so, proceed to display game over screen
    LDA ram_alt_entrance_control  ; otherwise check for mode of alternate entry
    BNE bra_skip_intermediate_screen  ; and branch if found
    LDY ram_area_type  ; check if we are on castle level
    CPY #$03  ; and if so, branch (possibly residual)
    BEQ bra_display_world_lives_screen
    LDA ram_disable_intermediate  ; if this flag is set, skip intermediate lives display
    BNE bra_skip_intermediate_screen  ; and jump to specific task, otherwise
bra_display_world_lives_screen:
    JSR sub_draw_player_intermediate  ; put player in appropriate place for
    LDA #$01  ; lives display, then output lives display to buffer
loc_output_intermediate_screen:
    JSR sub_write_game_text
    JSR sub_reset_screen_timer
    LDA #$00
    STA ram_disable_screen_flag  ; reenable screen output
    RTS
bra_display_game_over_screen:
    LDA #$12  ; set screen timer
    STA ram_screen_timer
    LDA #$03  ; output game over screen to buffer
    JSR sub_write_game_text
    JMP loc_advance_operation_mode_task
bra_skip_intermediate_screen:
    LDA #$08  ; set for specific task and leave
    STA ram_screen_routine_task
    RTS

; -------------------------------------------------------------------------------------

handler_render_initial_area_columns:
    INC ram_disable_screen_flag  ; turn off screen
bra_run_initial_area_parser_tasks:
    JSR sub_area_parser_task_handler  ; render column set of current area
    LDA ram_area_parser_task_num  ; check number of tasks
    BNE bra_run_initial_area_parser_tasks  ; if tasks still not all done, do another one
    DEC ram_column_sets  ; do we need to render more column sets?
    BPL bra_queue_rendered_area_columns
    INC ram_screen_routine_task  ; if not, move on to the next task
bra_queue_rendered_area_columns:
    LDA #$06  ; set vram buffer to output rendered column set
    STA ram_vram_buffer_addr_ctrl  ; on next NMI
    RTS

; -------------------------------------------------------------------------------------

; $00 - vram buffer address table low
; $01 - vram buffer address table high

.if con_revision_profile = con_revision_profile_vs
tbl_vs_title_chr_addresses_high:
    .byte $1e, $1a, $1a, $1a, $1b, $1b, $1c, $1c

tbl_vs_title_chr_addresses_low:
    .byte $a0, $00, $60, $c0, $10, $80, $00, $80

.endif

handler_copy_title_screen_from_chr:
    LDA ram_oper_mode  ; are we in title screen mode?
    BNE loc_advance_operation_mode_task  ; if not, exit
.if con_revision_profile = con_revision_profile_vs
    LDY #$00
sub_load_vs_title_chr_screen:
    LDA #$06  ; select the Vs. title-screen CHR bank
    STA VS_REQUEST
    LDA tbl_vs_title_chr_addresses_high,y
    STA PPU_ADDRESS
    LDA tbl_vs_title_chr_addresses_low,y
    STA PPU_ADDRESS
    LDA #$63  ; put address $6300 into the indirect at $00
    STA $01
    LDY #$00
    STY $00
    LDA PPU_DATA  ; do one garbage read before copying CHR data
bra_copy_vs_title_screen_data:
    LDA PPU_DATA
    STA ($00),y
    INY
    BNE bra_check_vs_title_screen_copy_end
    INC $01
bra_check_vs_title_screen_copy_end:
    LDA $01
    CMP #$64
    BNE bra_copy_vs_title_screen_data
    CPY #$5a
    BCC bra_copy_vs_title_screen_data
    LDA #$02  ; restore the Vs. program bank
    STA VS_REQUEST
    LDA #$1c  ; select the copied title-screen packet
    JMP loc_store_vram_buffer_control_from_a
.else
    LDA #>con_title_screen_data_offset  ; load address $1ec0 into
    STA PPU_ADDRESS  ; the vram address register
    LDA #<con_title_screen_data_offset
    STA PPU_ADDRESS
    LDA #$03  ; put address $0300 into
    STA $01  ; the indirect at $00
    LDY #$00
    STY $00
    LDA PPU_DATA  ; do one garbage read
bra_copy_title_screen_data:
    LDA PPU_DATA  ; get title screen from chr-rom
    STA ($00),y  ; store 256 bytes into buffer
    INY
    BNE bra_check_title_screen_copy_end  ; if not past 256 bytes, do not increment
    INC $01  ; otherwise increment high byte of indirect
bra_check_title_screen_copy_end:
    LDA $01  ; check high byte?
    CMP #$04  ; at $0400?
    BNE bra_copy_title_screen_data  ; if not, loop back and do another
    CPY #$3a  ; check if offset points past end of data
    BCC bra_copy_title_screen_data  ; if not, loop back and do another
    LDA #$05  ; set buffer transfer control to $0300,
    JMP loc_store_vram_buffer_control_from_a  ; increment task and exit
.endif

; -------------------------------------------------------------------------------------

handler_clear_title_buffers_and_draw_icon:
    LDA ram_oper_mode  ; check game mode
    BNE loc_advance_operation_mode_task  ; if not title screen mode, leave
    LDX #$00  ; otherwise, clear buffer space
bra_clear_title_screen_buffers:
    STA ram_vram_buffer1-1,x
    STA ram_vram_buffer1-1+$100,x
    DEX
    BNE bra_clear_title_screen_buffers
.if con_revision_profile <> con_revision_profile_vs
    JSR sub_draw_mushroom_icon  ; draw player select icon
.endif
loc_advance_screen_task:
    INC ram_screen_routine_task  ; move onto next task
    RTS

; -------------------------------------------------------------------------------------

handler_write_title_top_score:
    LDA #$fa  ; run display routine to display top score on title
    JSR sub_update_number
loc_advance_operation_mode_task:
    INC ram_oper_mode_task  ; move onto next mode
    RTS

; -------------------------------------------------------------------------------------

tbl_game_text_packets:
off_top_status_bar_packet:
    .byte $20, $43, $05, $16, $0a, $1b, $12, $18  ; "MARIO"
    .byte $20, $52, $0b, $20, $18, $1b, $15, $0d  ; "WORLD  TIME"
    .byte $24, $24, $1d, $12, $16, $0e
    .byte $20, $68, $05, $00, $24, $24, $2e, $29  ; score trailing digit and coin display
    .byte $23, $c0, $7f, $aa  ; attribute table data, clears name table 0 to palette 2
    .byte $23, $c2, $01, $ea  ; attribute table data, used for coin icon in status bar
    .byte $ff  ; end of data block

off_world_lives_display_packet:
    .byte $21, $cd, $07, $24, $24  ; cross with spaces used on
    .byte $29, $24, $24, $24, $24  ; lives display
    .byte $21, $4b, $09, $20, $18  ; "WORLD  - " used on lives display
    .byte $1b, $15, $0d, $24, $24, $28, $24
    .byte $22, $0c, $47, $24  ; !(ASSUME) DATA-001 - possible TIME UP clear packet
    .byte $23, $dc, $01, $ba  ; attribute table data for crown if more than 9 lives
    .byte $ff

off_two_player_time_up_packet:
    .byte $21, $cd, $05, $16, $0a, $1b, $12, $18  ; "MARIO"
off_one_player_time_up_packet:
    .byte $22, $0c, $07, $1d, $12, $16, $0e, $24, $1e, $19  ; "TIME UP"
    .byte $ff

off_two_player_game_over_packet:
    .byte $21, $cd, $05, $16, $0a, $1b, $12, $18  ; "MARIO"
off_one_player_game_over_packet:
    .byte $22, $0b, $09, $10, $0a, $16, $0e, $24  ; "GAME OVER"
    .byte $18, $1f, $0e, $1b
    .byte $ff

off_warp_zone_welcome_packet:
    .byte $25, $84, $15, $20, $0e, $15, $0c, $18, $16  ; "WELCOME TO WARP ZONE!"
    .byte $0e, $24, $1d, $18, $24, $20, $0a, $1b, $19
    .byte $24, $23, $18, $17, $0e, $2b
    .byte $26, $25, $01, $24  ; placeholder for left pipe
    .byte $26, $2d, $01, $24  ; placeholder for middle pipe
    .byte $26, $35, $01, $24  ; placeholder for right pipe
    .byte $27, $d9, $46, $aa  ; attribute data
    .byte $27, $e1, $45, $aa
    .byte $ff

tbl_luigi_name_tiles:
    .byte $15, $1e, $12, $10, $12  ; "LUIGI", no address or length

tbl_warp_zone_number_tiles:
    .byte $04, $03, $02, $00  ; warp zone numbers, note spaces on middle
    .byte $24, $05, $24, $00  ; zone, partly responsible for
.if con_revision_profile = con_revision_profile_vs
    .byte $24, $06, $24, $00  ; the Vs. warp-zone layout
.else
    .byte $08, $07, $06, $00  ; the minus world
.endif

tbl_game_text_packet_offsets:
    .byte off_top_status_bar_packet-tbl_game_text_packets, off_top_status_bar_packet-tbl_game_text_packets
    .byte off_world_lives_display_packet-tbl_game_text_packets, off_world_lives_display_packet-tbl_game_text_packets
    .byte off_two_player_time_up_packet-tbl_game_text_packets, off_one_player_time_up_packet-tbl_game_text_packets
    .byte off_two_player_game_over_packet-tbl_game_text_packets, off_one_player_game_over_packet-tbl_game_text_packets
    .byte off_warp_zone_welcome_packet-tbl_game_text_packets, off_warp_zone_welcome_packet-tbl_game_text_packets

sub_write_game_text:
    PHA  ; save text number to stack
    ASL
    TAY  ; multiply by 2 and use as offset
    CPY #$04  ; if set to do top status bar or world/lives display,
    BCC bra_load_game_text_packet  ; branch to use current offset as-is
    CPY #$08  ; if set to do time-up or game over,
    BCC bra_select_player_count_game_text  ; branch to check players
    LDY #$08  ; otherwise warp zone, therefore set offset
bra_select_player_count_game_text:
    LDA ram_number_of_players  ; check for number of players
    BNE bra_load_game_text_packet  ; if there are two, use current offset to also print name
    INY  ; otherwise increment offset by one to not print name
bra_load_game_text_packet:
    LDX tbl_game_text_packet_offsets,y  ; get offset to message we want to print
    LDY #$00
bra_copy_game_text_packet:
    LDA tbl_game_text_packets,x  ; load message data
    CMP #$ff  ; check for terminator
    BEQ bra_finish_game_text_packet  ; branch to end text if found
    STA ram_vram_buffer1,y  ; otherwise write data to buffer
    INX  ; and increment increment
    INY
    BNE bra_copy_game_text_packet  ; do this for 256 bytes if no terminator found
bra_finish_game_text_packet:
    LDA #$00  ; put null terminator at end
    STA ram_vram_buffer1,y
    PLA  ; pull original text number from stack
    TAX
    CMP #$04  ; are we printing warp zone?
    BCS bra_print_warp_zone_numbers
    DEX  ; are we printing the world/lives display?
    BNE bra_check_game_text_player_name  ; if not, branch to check player's name
    LDA ram_numberof_lives  ; otherwise, check number of lives
    CLC  ; and increment by one for display
    ADC #$01
    CMP #10  ; more than 9 lives?
    BCC bra_store_world_lives_values
    SBC #10  ; if so, subtract 10 and put a crown tile
    LDY #$9f  ; next to the difference...strange things happen if
    STY ram_vram_buffer1+7  ; the number of lives exceeds 19
bra_store_world_lives_values:
    STA ram_vram_buffer1+8
    LDY ram_world_number  ; write world and level numbers (incremented for display)
    INY  ; to the buffer in the spaces surrounding the dash
    STY ram_vram_buffer1+19
    LDY ram_level_number
    INY
    STY ram_vram_buffer1+21  ; we're done here
    RTS

bra_check_game_text_player_name:
    LDA ram_number_of_players  ; check number of players
    BEQ bra_exit_player_name_replacement  ; if only 1 player, leave
    LDA ram_current_player  ; load current player
    DEX  ; check to see if current message number is for time up
    BNE bra_check_luigi_name_replacement
    LDY ram_oper_mode  ; check for game over mode
.if con_revision_profile = con_revision_profile_vs
    CPY #con_vs_mode_game_over
    BEQ bra_check_luigi_name_replacement
    LDY ram_off_scr_numberof_lives
    BMI bra_check_luigi_name_replacement
.else
    CPY #con_mode_game_over
    BEQ bra_check_luigi_name_replacement
.endif
    EOR #%00000001  ; if not, must be time up, invert d0 to do other player
bra_check_luigi_name_replacement:
    LSR
    BCC bra_exit_player_name_replacement  ; if mario is current player, do not change the name
    LDY #$04
bra_replace_mario_name_with_luigi:
    LDA tbl_luigi_name_tiles,y  ; otherwise, replace "MARIO" with "LUIGI"
    STA ram_vram_buffer1+3,y
    DEY
    BPL bra_replace_mario_name_with_luigi  ; do this until each letter is replaced
bra_exit_player_name_replacement:
    RTS

bra_print_warp_zone_numbers:
    SBC #$04  ; subtract 4 and then shift to the left
    ASL  ; twice to get proper warp zone number
    ASL  ; offset
    TAX
    LDY #$00
bra_print_warp_zone_numbers_loop:
    LDA tbl_warp_zone_number_tiles,x  ; print warp zone numbers into the
    STA ram_vram_buffer1+27,y  ; placeholders from earlier
    INX
    INY  ; put a number in every fourth space
    INY
    INY
    INY
    CPY #$0c
    BCC bra_print_warp_zone_numbers_loop
    LDA #$2c  ; load new buffer pointer at end of message
    JMP loc_store_primary_vram_buffer_offset

; -------------------------------------------------------------------------------------

handler_reset_sprites_after_screen_delay:
    LDA ram_screen_timer  ; check if screen timer has expired
    BNE bra_exit_screen_timer_reset  ; if not, branch to leave
    JSR sub_move_all_sprites_offscreen  ; otherwise reset sprites now

sub_reset_screen_timer:
    LDA #$07  ; reset timer again
    STA ram_screen_timer
    INC ram_screen_routine_task  ; move onto next task
bra_exit_screen_timer_reset:
    RTS
