handler_smb2_main_attract_mode_subs:
    LDA OperMode_Task
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_attract_mode_disk_routines
    .word handler_smb2_main_initialize_game
    .word handler_smb2_main_run_screen_task
    .word handler_smb2_main_primary_game_setup
    .word handler_smb2_main_game_menu
    .word handler_smb2_main_hard_worlds_checkpoint

handler_smb2_main_hard_worlds_checkpoint:
    LDA DiskIOTask
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_disk_screen
    .word handler_smb2_main_load_hard_worlds
    .word handler_smb2_main_wait_for_eject
    .word handler_smb2_main_wait_for_reinsert
    .word handler_smb2_main_reset_disk_vars

handler_smb2_main_load_hard_worlds:
    LDA HardWorldFlag  ; if this is not set, skip this
    BEQ bra_smb2_main_finish_hard_world_load
    LDA #$03
    STA FileListNumber  ; set filelist number to load SM2DATA4
    JSR sub_smb2_main_load_files
    BNE bra_smb2_main_returned_error  ; if returned with error number, branch
    JSR sub_smb2_main_check_file_count  ; check to see if loaded the correct number of files
    BNE bra_smb2_main_bad_file_count  ; if not, branch to set error code
bra_smb2_main_finish_hard_world_load:
    JSR sub_smb2_main_load_area_pointer  ; update area pointer to get world 1 or A
    LDA HardWorldFlag  ; if this is not set, skip this
    BEQ bra_smb2_main_finish_halfway_page_check  ; otherwise run sub in SM2DATA4 to change halfway pages
    JSR sub_smb2_data4_change_halfway_pages  ; for worlds A thru D
bra_smb2_main_finish_halfway_page_check:
    INC Hidden1UpFlag
    INC FetchNewGameTimerFlag
    INC OperMode
    LDA #$00
    STA DiskIOTask
    STA OperMode_Task
    STA DemoTimer
    RTS

handler_smb2_main_attract_mode_disk_routines:
    LDA DiskIOTask
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_disk_screen
    .word handler_smb2_main_load_worlds1_thru4
    .word handler_smb2_main_wait_for_eject
    .word handler_smb2_main_wait_for_reinsert
    .word handler_smb2_main_reset_disk_vars

handler_smb2_main_load_worlds1_thru4:
    LDA NotColdFlag  ; if not set, just cold booted, thus no need to check world info
    BEQ bra_smb2_main_init_world_pos
    LDA HardWorldFlag  ; if player was playing worlds A-D, skip ahead
    BNE bra_smb2_main_select_worlds_1_through_4_files  ; otherwise check the world number
    LDA WorldNumber
    CMP #World5  ; if world number was less than 5, files still in memory
    BCC bra_smb2_main_init_world_pos  ; thus skip to the end, no need to load them again
bra_smb2_main_select_worlds_1_through_4_files:
    LDA #$00  ; set filelist number to reload SM2MAIN, SM2CHAR1 and SM2SAVE
    STA FileListNumber
    JSR sub_smb2_main_load_files  ; now reload those files
    BNE bra_smb2_main_returned_error  ; if returned with error number, branch
    JSR sub_smb2_main_check_file_count  ; check to see if loaded the correct number of files
    BEQ bra_smb2_main_init_world_pos  ; if so, branch to init player's world info

bra_smb2_main_bad_file_count:
    LDA #$40  ; otherwise, set error number

bra_smb2_main_returned_error:
    INC DiskIOTask  ; move on to next subtask
    JMP loc_smb2_main_disk_error_handler

bra_smb2_main_init_world_pos:
    LDA #$01  ; set flag to check player's world info
    STA NotColdFlag  ; before erasing it
    LSR
    STA WorldNumber  ; reset world number
    STA HardWorldFlag  ; force worlds 1-8 by default
    JMP sub_smb2_main_reset_disk_io_task  ; end disk subroutines

handler_smb2_main_game_mode_disk_routines:
    LDA DiskIOTask
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_disk_screen
    .word handler_smb2_main_load_worlds5_thru8
    .word handler_smb2_main_wait_for_eject
    .word handler_smb2_main_wait_for_reinsert
    .word handler_smb2_main_reset_disk_vars

handler_smb2_main_load_worlds5_thru8:
    LDA WorldNumber  ; if in worlds 1-4 or A-D
    CMP #World5  ; then leave without loading anything
    BCC sub_smb2_main_reset_disk_io_task
    LDA FileListNumber  ; if worlds 5-8 were already loaded, leave
    BNE sub_smb2_main_reset_disk_io_task  ; as there's no need to load anything
    LDA #$01
    STA FileListNumber  ; otherwise set filelist number to load SM2DATA2
    JSR sub_smb2_main_load_files  ; and load it
    BNE bra_smb2_main_returned_error  ; if returned with error number, branch
    JSR sub_smb2_main_check_file_count  ; check to see if loaded the correct number of files
    BNE bra_smb2_main_bad_file_count  ; if not, branch to return error 40/$32

sub_smb2_main_reset_disk_io_task:
    LDA #$00  ; reset disk-related task number for next time
    STA DiskIOTask
bra_smb2_main_vm_delay:
    INC OperMode_Task  ; move on to next task in the current mode
    RTS

handler_smb2_main_start_vm_delay:
    LDA #$10  ; start world end delay
    STA WorldEndTimer
    BNE bra_smb2_main_vm_delay

handler_smb2_main_continue_vm_delay:
    LDA WorldEndTimer  ; wait for delay to end, then move on
    BEQ bra_smb2_main_vm_delay
    RTS

handler_smb2_main_victory_mode_disk_routines:
    LDA DiskIOTask
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_disk_screen
    .word handler_smb2_main_load_ending
    .word handler_smb2_main_wait_for_eject
    .word handler_smb2_main_wait_for_reinsert
    .word handler_smb2_main_reset_disk_vars

handler_smb2_main_load_ending:
    LDA #$02  ; set filelist number to load SM2DATA3, SM2CHAR2 and SM2SAVE
    STA FileListNumber
    JSR sub_smb2_main_load_files  ; load them now
    BNE bra_smb2_main_returned_error
    JSR sub_smb2_main_check_file_count  ; check to see if loaded the correct number of files
    BEQ bra_smb2_main_add_beaten_game  ; if so, continue
    LDA #$00  ; otherwise reset count of games beaten
    STA tbl_smb2_main_games_beaten_count
bra_smb2_main_add_beaten_game:
    LDA tbl_smb2_main_games_beaten_count  ; get the new count of games beaten we loaded (or reset)
    CLC  ; add one to it, to a maximum of 24/$18
    ADC #$01
    CMP #25
    BCC bra_smb2_main_store_games_beaten_count
    LDA #24  ; sorry, only 24 stars allowed
bra_smb2_main_store_games_beaten_count:
    STA tbl_smb2_main_games_beaten_count
    JSR sub_smb2_main_initialize_name_tables
    JSR sub_smb2_main_reset_disk_io_task  ; end disk subroutines
    JMP loc_smb2_data3_write_name_to_victory_msg

sub_smb2_main_check_file_count:
    TYA  ; save number of files loaded to A
    LDY FileListNumber  ; use file list number as offset
    CMP tbl_smb2_main_file_count,y  ; compare to number of files supposed to be loaded
    RTS

; disk ID string copy used in FDS BIOS load routine
; to compare to original at the disk info block
tbl_smb2_main_disk_id_string:
    .byte $01, $53, $4d, $42, $20
    .byte $00, $00, $00, $00, $00

tbl_smb2_main_file_list_addr_low:
    .byte <tbl_smb2_main_world14_list, <tbl_smb2_main_world58_list, <tbl_smb2_main_ending_list, <tbl_smb2_main_world_ad_list
tbl_smb2_main_file_list_addr_high:
    .byte >tbl_smb2_main_world14_list, >tbl_smb2_main_world58_list, >tbl_smb2_main_ending_list, >tbl_smb2_main_world_ad_list

; file lists used by FDS bios to load files
; value $ff is end terminator
tbl_smb2_main_world14_list:
    .byte $01, $05, $0f, $ff
tbl_smb2_main_world58_list:
    .byte $20, $ff
tbl_smb2_main_ending_list:
    .byte $10, $30, $0f, $ff
tbl_smb2_main_world_ad_list:
    .byte $40, $ff

tbl_smb2_main_file_count:
    .byte $03, $01, $03, $01

sub_smb2_main_load_files:
    LDX FileListNumber  ; get address to file list
    LDA tbl_smb2_main_file_list_addr_low,x
    STA tbl_smb2_main_list_pointer
    LDA tbl_smb2_main_file_list_addr_high,x
    STA tbl_smb2_main_list_pointer+1
    JSR sub_smb2_main_fdsbios_loadfiles  ; now load the files

; used by FDS BIOS routine
    .word tbl_smb2_main_disk_id_string
tbl_smb2_main_list_pointer:
    .word tbl_smb2_main_world14_list  ; overwritten in RAM

; execution continues here
    RTS

off_smb2_main_disk_screen_palette:
    .byte $3f, $00, $04
    .byte $0f, $30, $30, $0f
    .byte $00

handler_smb2_main_disk_screen:
    LDA #$00
    STA Mirror_PPU_MASK
    STA PPU_MASK
    INC DisableScreenFlag
    LDA #$1a
    STA VRAM_Buffer_AddrCtrl
    JMP bra_smb2_main_next_disk_io_task

handler_smb2_main_wait_for_eject:
    LDA #$00
    STA NameTableSelect
    STA DisableScreenFlag
    LDA FDS_DRIVE_STATUS  ; check disk inserted flag
    LSR  ; execute this routine until disk is ejected
    BCC bra_smb2_main_this_disk_io_task  ; note this routine is run on an error

bra_smb2_main_next_disk_io_task:
    INC DiskIOTask  ; move on to next subtask involving the disk drive
bra_smb2_main_this_disk_io_task:
    RTS  ; or not, if branched here

handler_smb2_main_wait_for_reinsert:
    LDA FDS_DRIVE_STATUS  ; check disk inserted flag
    LSR  ; execute this routine until disk is reinserted
    BCC bra_smb2_main_next_disk_io_task  ; note this routine is run after the one
    BCS bra_smb2_main_this_disk_io_task  ; that checks for an ejected disk

handler_smb2_main_reset_disk_vars:
    LDA #$00
    STA DiskIOTask  ; reset disk-related variables
    STA FileListNumber
    RTS

off_smb2_main_disk_error_main_msg:
    .byte $21, $e6, $08
    .byte $24, $24, $24, $24, $24, $24, $24, $24
    .byte $21, $f4, $06
    .byte $0e, $1b, $1b, $24, $00, $01
    .byte $00

; disk error message offsets
; note these actually point to the last byte
tbl_smb2_main_disk_error_msg_offsets:
    .byte $07, $0f, $17, $1f

off_smb2_main_disk_error_msgs:
; "        "
    .byte $24, $24, $24, $24, $24, $24, $24, $24
; "DISK SET"
    .byte $0d, $12, $1c, $14, $24, $1c, $0e, $1d
; "BATTERY "
    .byte $0b, $0a, $1d, $1d, $0e, $1b, $22, $24
; "A B SIDE"
    .byte $0a, $24, $0b, $24, $1c, $12, $0d, $0e

loc_smb2_main_disk_error_handler:
    PHA
    AND #$0f
    STA off_smb2_main_disk_error_main_msg+$13  ; write lower nybble of error number as digit
    PLA
    PHA
    LSR
    LSR
    LSR
    LSR
    STA off_smb2_main_disk_error_main_msg+$12  ; now write the upper nybble of error number
    LDY #$03
    PLA
    CMP #$07  ; if a/b side error was found, branch
    BEQ bra_smb2_main_load_error
    DEY
    CMP #$02  ; if battery low error was found, branch
    BEQ bra_smb2_main_load_error
    DEY
    CMP #$01  ; if disk not set error was found, branch
    BEQ bra_smb2_main_load_error
    DEY  ; otherwise print blank for any other error or no error
bra_smb2_main_load_error:
    LDX tbl_smb2_main_disk_error_msg_offsets,y  ; get offset to error message
    LDY #$07  ; use to load error message to vram string
bra_smb2_main_copy_disk_error_message_loop:
    LDA off_smb2_main_disk_error_msgs,x
    STA off_smb2_main_disk_error_main_msg+3,y
    DEX
    DEY
    BPL bra_smb2_main_copy_disk_error_message_loop
    LDA #$19
    STA VRAM_Buffer_AddrCtrl  ; print error message on next NMI
    JSR sub_smb2_main_move_all_sprites_offscreen  ; init the screen
    JMP sub_smb2_main_initialize_name_tables

off_smb2_main_game_over_cursor_data:
    .byte $5b, $02, $48

tbl_smb2_main_game_over_cursor_y:
    .byte $77, $8f

loc_smb2_main_game_over_menu:
    LDA SavedJoypadBits  ; if player pressed the start button
    AND #Start_Button  ; then either continue or start over
    BNE bra_smb2_main_continue_or_retry
    LDA SavedJoypadBits
    AND #Select_Button  ; if player pressed the select button
    BEQ bra_smb2_main_update_continue_selection  ; then branch to select "continue" or "retry"
    LDX SelectTimer  ; if select timer not expired while
    BNE bra_smb2_main_update_continue_selection  ; pressing select, skip this
    LSR
    STA SelectTimer  ; otherwise set the select timer
    LDA ContinueMenuSelect
    EOR #$01  ; and toggle between the two choices
    STA ContinueMenuSelect
bra_smb2_main_update_continue_selection:
    LDY #$02
bra_smb2_main_draw_continue_selection_loop:
    LDA off_smb2_main_game_over_cursor_data,y  ; set up cursor sprite tile, attribute
    STA Sprite_Data+1,y  ; and X position in sprite OAM data
    DEY
    BPL bra_smb2_main_draw_continue_selection_loop
    LDY ContinueMenuSelect
    LDA tbl_smb2_main_game_over_cursor_y,y  ; set Y position based on the selection
    STA Sprite_Data
    RTS

bra_smb2_main_continue_or_retry:
    LDA ContinueMenuSelect  ; if player selected "continue"
    BEQ bra_smb2_main_continue  ; then branch to continue
    LDA #$00
    STA CompletedWorlds  ; otherwise init completed worlds flags
    JMP sub_smb2_main_terminate_game  ; and end the game

bra_smb2_main_continue:
    LDY #$02
    STY NumberofLives  ; give three lives
    STA LevelNumber
    STA AreaNumber  ; put at x-1 of the current world
    STA CoinTally
    LDY #$0b
bra_smb2_main_initialize_continue_score_loop:
    STA ScoreAndCoinDisplay,y  ; reset score
    DEY
    BPL bra_smb2_main_initialize_continue_score_loop
    INC Hidden1UpFlag  ; allow 1-up to be found again
    JMP loc_smb2_main_restart_game

; -------------------------------------------------------------------------------------

; jump, fall and friction physics data used with mario and luigi
; note luigi's higher jump, but with lesser friction
