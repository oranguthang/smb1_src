; Dispatch ANN disk-loading phases and report FDS BIOS errors

con_ann_course_5 = 4
con_ann_disk_file_main = 0
con_ann_disk_file_data2 = 1
con_ann_disk_file_data3 = 2
con_ann_disk_file_data4 = 3
con_ann_disk_error_wrong_file_count = $40
con_ann_disk_error_set = $01
con_ann_disk_error_battery = $02
con_ann_disk_error_side = $07
con_ann_disk_victory_cutoff = 20
con_ann_disk_error_text_packet = $19
con_ann_disk_error_palette_packet = $1a

handler_run_ann_disk_loader:
    LDA ram_oper_mode_task
    JSR sub_dispatch_inline_handler
    .word handler_ann_disk_loader_main
    .word handler_ann_title_init_0
    .word handler_advance_ann_disk_game_task
    .word handler_run_screen_task
    .word handler_ann_title_init_1
    .word handler_ann_title_process
    .word handler_ann_disk_loader_data4

handler_ann_disk_loader_data4:
    LDA ram_fds_disk_loader_task
    JSR sub_dispatch_inline_handler
    .word handler_show_ann_disk_prompt
    .word handler_load_ann_disk_data4
    .word handler_wait_for_ann_disk_eject
    .word handler_wait_for_ann_disk_insert
    .word handler_reset_ann_disk_loader

handler_load_ann_disk_data4:
    LDA ram_ann_hard_mode
    BEQ :+
    LDA #con_ann_disk_file_data4
    STA ram_ann_disk_file_id
    JSR sub_load_ann_disk_files
    BNE bra_handle_ann_disk_load_error
    JSR sub_check_ann_disk_file_count
    BNE bra_handle_ann_disk_file_count_error
    :
    JSR sub_ann_load_course
    LDA ram_ann_hard_mode
    BEQ :+
    JSR sub_ann_initialize_life_down_extension
    :
    INC ram_hidden1_up_flag
    INC ram_ann_player_first_start
    INC ram_oper_mode
    LDA #$00
    STA ram_fds_disk_loader_task
    STA ram_oper_mode_task
    STA ram_demo_timer
    RTS

handler_ann_disk_loader_main:
    LDA ram_fds_disk_loader_task
    JSR sub_dispatch_inline_handler
    .word handler_show_ann_disk_prompt
    .word handler_load_ann_main_disk
    .word handler_wait_for_ann_disk_eject
    .word handler_wait_for_ann_disk_insert
    .word handler_reset_ann_disk_loader

handler_load_ann_main_disk:
    LDA ram_ann_disk_main_request
    BEQ bra_finish_ann_main_disk_load
    LDA ram_ann_hard_mode
    BNE :+
    LDA ram_ann_course_number
    CMP #con_ann_course_5
    BCC bra_finish_ann_main_disk_load
    :
    LDA #con_ann_disk_file_main
    STA ram_ann_disk_file_id
    JSR sub_load_ann_disk_files
    BNE :+
    JSR sub_check_ann_disk_file_count
    BEQ bra_finish_ann_main_disk_load
bra_handle_ann_disk_file_count_error:
    LDA #con_ann_disk_error_wrong_file_count
    :
bra_handle_ann_disk_load_error:
    INC ram_fds_disk_loader_task
    JMP handler_print_ann_disk_error

bra_finish_ann_main_disk_load:
    LDA #$01
    STA ram_ann_disk_main_request
    LSR
    STA ram_ann_course_number
    STA ram_ann_hard_mode
    JMP sub_advance_ann_disk_loader

handler_ann_disk_loader_data2:
    LDA ram_fds_disk_loader_task
    JSR sub_dispatch_inline_handler
    .word handler_show_ann_disk_prompt
    .word handler_load_ann_disk_data2
    .word handler_wait_for_ann_disk_eject
    .word handler_wait_for_ann_disk_insert
    .word handler_reset_ann_disk_loader

handler_load_ann_disk_data2:
    LDA ram_ann_course_number
    CMP #con_ann_course_5
    BCC sub_advance_ann_disk_loader
    LDA ram_ann_disk_file_id
    BNE sub_advance_ann_disk_loader
    LDA #con_ann_disk_file_data2
    STA ram_ann_disk_file_id
    JSR sub_load_ann_disk_files
    BNE bra_handle_ann_disk_load_error
    JSR sub_check_ann_disk_file_count
    BNE bra_handle_ann_disk_file_count_error

sub_advance_ann_disk_loader:
    LDA #$00
    STA ram_fds_disk_loader_task

handler_advance_ann_disk_game_task:
    INC ram_oper_mode_task
    RTS

handler_ann_victory_disk_init:
    LDA #$10
    STA ram_world_end_timer
    BNE handler_advance_ann_disk_game_task

handler_ann_victory_disk_check:
    LDA ram_world_end_timer
    BEQ handler_advance_ann_disk_game_task
    RTS

handler_ann_victory_disk_data:
    LDA ram_fds_disk_loader_task
    JSR sub_dispatch_inline_handler
    .word handler_show_ann_disk_prompt
    .word handler_load_ann_disk_data3
    .word handler_wait_for_ann_disk_eject
    .word handler_wait_for_ann_disk_insert
    .word handler_reset_ann_disk_loader

handler_load_ann_disk_data3:
    LDA #con_ann_disk_file_data3
    STA ram_ann_disk_file_id
    JSR sub_load_ann_disk_files
    BNE bra_handle_ann_disk_load_error
    JSR sub_check_ann_disk_file_count
    BEQ :+
    LDA #$00
    STA off_ann_save_data
    :
    LDA off_ann_save_data
    CLC
    ADC #$01
    CMP #con_ann_disk_victory_cutoff+1
    BCC :+
    LDA #con_ann_disk_victory_cutoff
    :
    STA off_ann_save_data
    LDA #$01
    STA ram_ann_primary_hard_mode
    JSR sub_initialize_name_tables
    JSR sub_advance_ann_disk_loader
    JMP handler_ann_ending_text_player_setup

sub_check_ann_disk_file_count:
    TYA
    LDY ram_ann_disk_file_id
    CMP tbl_ann_disk_file_counts,y
    RTS

tbl_ann_disk_header_id:
    .byte $01, $4e, $53, $4d, $20, $00

off_ann_current_disk_side:
    .byte $00, $00, $00, $00

tbl_ann_disk_file_list_lo:
    .byte <tbl_ann_main_disk_files
    .byte <tbl_ann_data2_disk_files
    .byte <tbl_ann_data3_disk_files
    .byte <tbl_ann_data4_disk_files

tbl_ann_disk_file_list_hi:
    .byte >tbl_ann_main_disk_files
    .byte >tbl_ann_data2_disk_files
    .byte >tbl_ann_data3_disk_files
    .byte >tbl_ann_data4_disk_files

tbl_ann_main_disk_files:
    .byte $01, $05, $0f, $ff

tbl_ann_data2_disk_files:
    .byte $20, $ff

tbl_ann_data3_disk_files:
    .byte $10, $30, $0f, $ff

tbl_ann_data4_disk_files:
    .byte $40, $ff

tbl_ann_disk_file_counts:
    .byte $03, $01, $03, $01

sub_load_ann_disk_files:
    LDX ram_ann_disk_file_id
    LDA tbl_ann_disk_file_list_lo,x
    STA off_ann_disk_file_table_ptr
    LDA tbl_ann_disk_file_list_hi,x
    STA off_ann_disk_file_table_ptr+1
    JSR sub_fds_bios_load_files
    .word tbl_ann_disk_header_id
off_ann_disk_file_table_ptr:
    .word tbl_ann_main_disk_files
    RTS

off_ann_disk_error_palette_packet:
    .byte $3f, $00, $04, $0f, $30, $30, $0f, $00

handler_show_ann_disk_prompt:
    LDA #$00
    STA ram_mirror_ppu_ctrl_reg2
    STA PPU_CTRL_REG2
    INC ram_disable_screen_flag
    LDA #con_ann_disk_error_palette_packet
    STA ram_vram_buffer_addr_ctrl
    JMP :+

handler_wait_for_ann_disk_eject:
    LDA #$00
    STA ram_ann_ppu_background_select
    STA ram_disable_screen_flag
    LDA FDS_DRIVE_STATUS
    LSR
    BCC :++
    :
    INC ram_fds_disk_loader_task
    :
    RTS

handler_wait_for_ann_disk_insert:
    LDA FDS_DRIVE_STATUS
    LSR
    BCC :--
    BCS :-

handler_reset_ann_disk_loader:
    LDA #$00
    STA ram_fds_disk_loader_task
    STA ram_ann_disk_file_id
    RTS

off_ann_disk_error_text_packet:
    .byte $21, $e6, $08
off_ann_disk_error_text:
    .byte $24, $24, $24, $24, $24, $24, $24, $24
    .byte $21, $f4, $06, $0e, $1b, $1b, $24, $00, $01, $00

tbl_ann_disk_error_text_offsets:
    .byte $07, $0f, $17, $1f

tbl_ann_disk_error_text:
    .byte $24, $24, $24, $24, $24, $24, $24, $24
    .byte $0d, $12, $1c, $14, $24, $1c, $0e, $1d
    .byte $0b, $0a, $1d, $1d, $0e, $1b, $22, $24
    .byte $0a, $24, $0b, $24, $1c, $12, $0d, $0e

handler_print_ann_disk_error:
    PHA
    AND #%00001111
    STA off_ann_disk_error_text+16
    PLA
    PHA
    LSR
    LSR
    LSR
    LSR
    STA off_ann_disk_error_text+15
    LDY #$03
    PLA
    CMP #con_ann_disk_error_side
    BEQ :+
    DEY
    CMP #con_ann_disk_error_battery
    BEQ :+
    DEY
    CMP #con_ann_disk_error_set
    BEQ :+
    DEY
    :
    LDX tbl_ann_disk_error_text_offsets,y
    LDY #$07
    :
    LDA tbl_ann_disk_error_text,x
    STA off_ann_disk_error_text,y
    DEX
    DEY
    BPL :-
    LDA #con_ann_disk_error_text_packet
    STA ram_vram_buffer_addr_ctrl
    JSR sub_move_all_sprites_offscreen
    JMP sub_initialize_name_tables
