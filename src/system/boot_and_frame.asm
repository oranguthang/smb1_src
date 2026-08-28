; -------------------------------------------------------------------------------------

; Initialize CPU, PPU, APU, RAM, OAM, nametables, and NMI scheduling

; Outputs:
; The selected warm/cold RAM range is cleared and the machine enters the
; permanent foreground loop with NMI enabled

; Clobbers:
; A, X, Y
vec_reset_handler:
.if con_revision_profile <> con_revision_profile_fds_smb
    SEI  ; pretty standard 6502 type init here
.endif
    CLD
    LDA #%00010000  ; init PPU control register 1
    STA PPU_CTRL_REG1
    LDX #$ff  ; reset stack pointer
    TXS
bra_wait_for_first_vblank:
    LDA PPU_STATUS  ; wait two frames
    BPL bra_wait_for_first_vblank
bra_wait_for_second_vblank:
    LDA PPU_STATUS
    BPL bra_wait_for_second_vblank
    LDY #con_cold_boot_offset  ; load default cold boot pointer
    LDX #$05  ; this is where we check for a warm boot
bra_check_warm_boot_state:
    LDA ram_top_score_display,x  ; check each score digit in the top score
    CMP #10  ; to see if we have a valid digit
    BCS bra_initialize_after_boot_check  ; if not, give up and proceed with cold boot
    DEX
    BPL bra_check_warm_boot_state
.if con_revision_profile <> con_revision_profile_vs
    LDA ram_warm_boot_validation  ; second checkpoint, check to see if
    CMP #$a5  ; another location has a specific value
    BNE bra_initialize_after_boot_check
    LDY #con_warm_boot_offset  ; if passed both, load warm boot pointer
.endif
bra_initialize_after_boot_check:
    JSR sub_initialize_memory  ; clear memory using pointer in Y
    STA SND_DELTA_REG+1  ; reset delta counter load register
    STA ram_oper_mode  ; reset primary mode of operation
    LDA #$a5  ; set warm boot flag
.if con_revision_profile <> con_revision_profile_vs
    STA ram_warm_boot_validation
.endif
    STA ram_pseudo_random_bit_reg  ; set seed for pseudorandom register
    LDA #%00001111
    STA SND_MASTERCTRL_REG  ; enable all sound channels except dmc
    LDA #%00000110
    STA PPU_CTRL_REG2  ; turn off clipping for OAM and background
    JSR sub_move_all_sprites_offscreen
    JSR sub_initialize_name_tables  ; initialize both name tables
    INC ram_disable_screen_flag  ; set flag to disable screen output
.if con_revision_profile = con_revision_profile_fds_smb
    LDA #con_fds_control_io_mask+con_fds_control_read_mode+con_fds_control_transfer_reset+con_fds_control_motor_on
    STA FDS_CONTROL
.elseif con_revision_profile = con_revision_profile_vs
    JSR sub_vs_select_low_chr_bank
    LDA #$00
    LDX #$00
bra_clear_vs_ram_arenas:
    STA ram_vs_arena1,x
    STA ram_vs_arena0,x
    INX
    BNE bra_clear_vs_ram_arenas
    LDA #con_vs_request_chr_high+con_vs_request_irq_release
    STA VS_REQUEST
    LDA #$1e
    STA PPU_ADDRESS
    LDA #$00
    STA PPU_ADDRESS
    LDA PPU_DATA  ; discard the buffered CHR read
    LDY #<ram_vs_saved_data
bra_load_vs_saved_data:
    LDA PPU_DATA
    STA ram_vs_arena0,y
    INY
    BNE bra_load_vs_saved_data
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
    LDY #$05
bra_restore_vs_top_score:
    LDA ram_vs_saved_top_score,y
    STA ram_top_score_display,y
    DEY
    BPL bra_restore_vs_top_score
    JSR sub_vs_read_dip_switches
.endif
.if con_revision_profile = con_revision_profile_fds_smb
    CLI
.endif
    LDA ram_mirror_ppu_ctrl_reg1
    ORA #%10000000  ; enable NMIs
    JSR sub_write_ppu_reg1
loc_wait_forever_after_reset_failure:
    JMP loc_wait_forever_after_reset_failure  ; endless loop, need I say more?

; -------------------------------------------------------------------------------------
; $00 - vram buffer address table low, also used for pseudorandom bit
; $01 - vram buffer address table high

tbl_vram_buffer_addresses_low:
.if con_revision_profile = con_revision_profile_vs
    .byte $01, $a5, $c9, $ed, $11, $00, $41, $41, $4d, $35
    .byte $3d, $45, $55, $69, $7d, $a9, $b2, $c6, $de, $f6
    .byte $0c, $22, $36, $4a, $5b, $72, $8a, $a2, $00, $00
    .byte $00, $e4, $e4, $e4, $e4, $e4, $e4, $e4, $dc
.else
    .byte <ram_vram_buffer1, <off_water_area_palette_packet, <off_ground_area_palette_packet
    .byte <off_underground_area_palette_packet, <off_castle_area_palette_packet, <ram_vram_buffer1_offset
    .byte <ram_vram_buffer2, <ram_vram_buffer2, <off_bowser_palette_packet
    .byte <off_day_snow_palette_packet, <off_night_snow_palette_packet, <off_mushroom_palette_packet
    .byte <off_mario_thanks_message, <off_luigi_thanks_message, <off_mushroom_retainer_saved_message
    .byte <off_princess_saved_message_1, <off_princess_saved_message_2, <off_world_select_message_1
    .byte <off_world_select_message_2
.endif

tbl_vram_buffer_addresses_high:
.if con_revision_profile = con_revision_profile_vs
    .byte $03, $8e, $8e, $8e, $8f, $03, $03, $03, $8f, $8f
    .byte $8f, $8f, $8f, $8f, $8f, $8f, $8f, $8f, $8f, $8f
    .byte $90, $90, $90, $90, $90, $90, $90, $90, $63, $60
    .byte $60, $80, $80, $80, $80, $80, $80, $80, $80
.else
    .byte >ram_vram_buffer1, >off_water_area_palette_packet, >off_ground_area_palette_packet
    .byte >off_underground_area_palette_packet, >off_castle_area_palette_packet, >ram_vram_buffer1_offset
    .byte >ram_vram_buffer2, >ram_vram_buffer2, >off_bowser_palette_packet
    .byte >off_day_snow_palette_packet, >off_night_snow_palette_packet, >off_mushroom_palette_packet
    .byte >off_mario_thanks_message, >off_luigi_thanks_message, >off_mushroom_retainer_saved_message
    .byte >off_princess_saved_message_1, >off_princess_saved_message_2, >off_world_select_message_1
    .byte >off_world_select_message_2
.endif

.if con_revision_profile = con_revision_profile_vs
off_vs_palette_1f:
    .byte $3f, $04, $04, $14, $36, $0a, $28, $00

off_vs_palette_1e:
    .byte $3f, $00, $20, $14, $36, $08, $26, $14, $3e, $12, $06, $14
    .byte $0a, $12, $3f, $14, $0c, $07, $32, $14, $33, $39, $00, $14
    .byte $36, $39, $1b, $14, $0d, $39, $33, $14, $33, $39, $00, $00
.endif

tbl_vram_buffer_offset_addresses:
    .byte <ram_vram_buffer1_offset, <ram_vram_buffer2_offset

; Run the complete vblank and per-frame scheduler

; Outputs:
; OAM DMA and buffered PPU writes are submitted; sound, input, timers,
; pseudorandom state, sprite preparation, scrolling, and the active operating
; mode are advanced

; Clobbers:
; A, X, Y
vec_nmi_handler:
.if con_revision_profile = con_revision_profile_fds_smb
    CLI
.endif
    LDA ram_mirror_ppu_ctrl_reg1  ; disable NMIs in mirror reg
    AND #%01111111  ; save all other bits
    STA ram_mirror_ppu_ctrl_reg1
    AND #%01111110  ; alter name table address to be $2800
    STA PPU_CTRL_REG1  ; (essentially $2000) but save other bits
    LDA ram_mirror_ppu_ctrl_reg2  ; disable OAM and background display by default
    AND #%11100110
    LDY ram_disable_screen_flag  ; get screen disable flag
    BNE bra_apply_rendering_mask  ; if set, used bits as-is
    LDA ram_mirror_ppu_ctrl_reg2  ; otherwise reenable bits and save them
    ORA #%00011110
bra_apply_rendering_mask:
    STA ram_mirror_ppu_ctrl_reg2  ; save bits for later but not in register at the moment
    AND #%11100111  ; disable screen for now
    STA PPU_CTRL_REG2
    LDX PPU_STATUS  ; reset flip-flop and reset scroll registers to zero
    LDA #$00
    JSR sub_initialize_ppu_scroll
    STA PPU_SPR_ADDR  ; reset spr-ram address register
    LDA #$02  ; perform spr-ram DMA access on $0200-$02ff
    STA SPR_DMA
    LDX ram_vram_buffer_addr_ctrl  ; load control for pointer to buffer contents
    LDA tbl_vram_buffer_addresses_low,x  ; set indirect at $00 to pointer
    STA $00
    LDA tbl_vram_buffer_addresses_high,x
    STA $01
    JSR sub_update_screen  ; update screen with buffer contents
    LDY #$00
    LDX ram_vram_buffer_addr_ctrl  ; check for usage of $0341
    CPX #$06
    BNE bra_select_vram_buffer_offset
    INY  ; get offset based on usage
bra_select_vram_buffer_offset:
    LDX tbl_vram_buffer_offset_addresses,y
    LDA #$00  ; clear buffer header at last location
    STA ram_vram_buffer1_offset,x
    STA ram_vram_buffer1,x
    STA ram_vram_buffer_addr_ctrl  ; reinit address control to $0301
    LDA ram_mirror_ppu_ctrl_reg2  ; copy mirror of $2001 to register
    STA PPU_CTRL_REG2
    JSR sub_sound_engine  ; play sound
.if con_revision_profile = con_revision_profile_vs
    JSR sub_vs_process_coin_service
    JSR sub_vs_update_credit_display
    JSR sub_vs_update_saved_data
.endif
    JSR sub_read_joypads  ; read joypads
.if con_revision_profile <> con_revision_profile_vs
    JSR sub_pause_routine  ; handle pause
.endif
    JSR sub_update_top_score
.if con_revision_profile <> con_revision_profile_vs
    LDA ram_game_pause_status  ; check for pause status
    LSR
    BCS bra_advance_frame_state
.endif
    LDA ram_timer_control  ; if master timer control not set, decrement
    BEQ bra_decrement_frame_timers  ; all frame and interval timers
    DEC ram_timer_control
    BNE bra_finish_timer_updates
bra_decrement_frame_timers:
    LDX #$14  ; load end offset for end of frame timers
    DEC ram_interval_timer_control  ; decrement interval timer control,
    BPL bra_decrement_frame_timers_loop  ; if not expired, only frame timers will decrement
loc_interval_timer_reload:
    LDA #con_interval_timer_reload
    STA ram_interval_timer_control  ; if control for interval timers expired,
    LDX #$23  ; interval timers will decrement along with frame timers
bra_decrement_frame_timers_loop:
    LDA ram_timers,x  ; check current timer
    BEQ bra_advance_timer_slot  ; if current timer expired, branch to skip,
    DEC ram_timers,x  ; otherwise decrement the current timer
bra_advance_timer_slot:
    DEX  ; move onto next timer
    BPL bra_decrement_frame_timers_loop  ; do this until all timers are dealt with
bra_finish_timer_updates:
    INC ram_frame_counter  ; increment frame counter
bra_advance_frame_state:
    LDX #$00
    LDY #$07
    LDA ram_pseudo_random_bit_reg  ; get first memory location of LSFR bytes
    AND #%00000010  ; mask out all but d1
    STA $00  ; save here
    LDA ram_pseudo_random_bit_reg+1  ; get second memory location
    AND #%00000010  ; mask out all but d1
    EOR $00  ; perform exclusive-OR on d1 from first and second bytes
    CLC  ; if neither or both are set, carry will be clear
    BEQ bra_rotate_pseudorandom_register
    SEC  ; if one or the other is set, carry will be set
bra_rotate_pseudorandom_register:
    ROR ram_pseudo_random_bit_reg,x  ; rotate carry into d7, and rotate last bit into carry
    INX  ; increment to next byte
    DEY  ; decrement for loop
    BNE bra_rotate_pseudorandom_register
    LDA ram_sprite0_hit_detect_flag  ; check for flag here
    BEQ bra_skip_sprite_0_synchronization
bra_wait_for_sprite_0_clear:
    LDA PPU_STATUS  ; wait for sprite 0 flag to clear, which will
    AND #%01000000  ; not happen until vblank has ended
    BNE bra_wait_for_sprite_0_clear
.if con_revision_profile <> con_revision_profile_vs
    LDA ram_game_pause_status  ; if in pause mode, do not bother with sprites at all
    LSR
    BCS bra_wait_for_sprite_0_hit
.endif
    JSR sub_move_sprites_offscreen
    JSR sub_sprite_shuffler
bra_wait_for_sprite_0_hit:
    LDA PPU_STATUS  ; do sprite #0 hit detection
    AND #%01000000
    BEQ bra_wait_for_sprite_0_hit
    LDY #$14  ; small delay, to wait until we hit horizontal blank time
bra_sprite_0_hblank_delay:
    DEY
    BNE bra_sprite_0_hblank_delay
bra_skip_sprite_0_synchronization:
    LDA ram_horizontal_scroll  ; set scroll registers from variables
    STA PPU_SCROLL_REG
    LDA ram_vertical_scroll
    STA PPU_SCROLL_REG
    LDA ram_mirror_ppu_ctrl_reg1  ; load saved mirror of $2000
    PHA
    STA PPU_CTRL_REG1
.if con_revision_profile <> con_revision_profile_vs
    LDA ram_game_pause_status  ; if in pause mode, do not perform operation mode stuff
    LSR
    BCS bra_finish_nmi_frame
.endif
    JSR sub_oper_mode_execution_tree  ; otherwise do one of many, many possible subroutines
bra_finish_nmi_frame:
    LDA PPU_STATUS  ; reset flip-flop
    PLA
    ORA #%10000000  ; reactivate NMIs
    STA PPU_CTRL_REG1
    RTI  ; we are done until the next frame!

; -------------------------------------------------------------------------------------

.if con_revision_profile = con_revision_profile_vs
vec_irq_handler:
    LDA VS_STATUS
    BMI bra_exit_vs_irq
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
bra_exit_vs_irq:
    PLA
    PLA
    PLA
    RTS

sub_vs_select_low_chr_bank:
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
    RTS
.else
sub_pause_routine:
    LDA ram_oper_mode  ; are we in victory mode?
    CMP #con_mode_victory  ; if so, go ahead
    BEQ bra_check_pause_debounce_timer
    CMP #con_mode_game  ; are we in game mode?
    BNE bra_exit_pause_handler  ; if not, leave
    LDA ram_oper_mode_task  ; if we are in game mode, are we running game engine?
    CMP #$03
    BNE bra_exit_pause_handler  ; if not, leave
bra_check_pause_debounce_timer:
    LDA ram_game_pause_timer  ; check if pause timer is still counting down
    BEQ bra_check_pause_start_button
    DEC ram_game_pause_timer  ; if so, decrement and leave
    RTS
bra_check_pause_start_button:
    LDA ram_saved_joypad1_bits  ; check to see if start is pressed
    AND #con_btn_start  ; on controller 1
    BEQ bra_clear_pause_debounce_timer
    LDA ram_game_pause_status  ; check to see if timer flag is set
    AND #%10000000  ; and if so, do not reset timer (residual,
    BNE bra_exit_pause_handler  ; joypad reading routine makes this unnecessary)
    LDA #$2b  ; set pause timer
    STA ram_game_pause_timer
    LDA ram_game_pause_status
    TAY
    INY  ; set pause sfx queue for next pause mode
    STY ram_pause_sound_queue
    EOR #%00000001  ; invert d0 and set d7
    ORA #%10000000
    BNE bra_toggle_pause_mode  ; unconditional branch
bra_clear_pause_debounce_timer:
    LDA ram_game_pause_status  ; clear timer flag if timer is at zero and start button
    AND #%01111111  ; is not pressed
bra_toggle_pause_mode:
    STA ram_game_pause_status
bra_exit_pause_handler:
    RTS
.endif

; -------------------------------------------------------------------------------------
; $00 - used for preset value

sub_sprite_shuffler:
    LDY ram_area_type  ; load level type, likely residual code
    LDA #$28  ; load preset value which will put it at
    STA $00  ; sprite #10
    LDX #$0e  ; start at the end of OAM data offsets
bra_shuffle_enemy_oam_offsets:
    LDA ram_spr_data_offset,x  ; check for offset value against
    CMP $00  ; the preset value
    BCC bra_advance_sprite_shuffle_slot  ; if less, skip this part
    LDY ram_spr_shuffle_amt_offset  ; get current offset to preset value we want to add
    CLC
    ADC ram_spr_shuffle_amt,y  ; get shuffle amount, add to current sprite offset
    BCC bra_store_shuffled_sprite_offset  ; if not exceeded $ff, skip second add
    CLC
    ADC $00  ; otherwise add preset value $28 to offset
bra_store_shuffled_sprite_offset:
    STA ram_spr_data_offset,x  ; store new offset here or old one if branched to here
bra_advance_sprite_shuffle_slot:
    DEX  ; move backwards to next one
    BPL bra_shuffle_enemy_oam_offsets
    LDX ram_spr_shuffle_amt_offset  ; load offset
    INX
    CPX #$03  ; check if offset + 1 goes to 3
    BNE bra_store_sprite_shuffle_index  ; if offset + 1 not 3, store
    LDX #$00  ; otherwise, init to 0
bra_store_sprite_shuffle_index:
    STX ram_spr_shuffle_amt_offset
    LDX #$08  ; load offsets for values and storage
    LDY #$02
bra_store_misc_oam_offset:
    LDA ram_spr_data_offset+5,y  ; load one of three OAM data offsets
    STA ram_misc_spr_data_offset-2,x  ; store first one unmodified, but
    CLC  ; add eight to the second and eight
    ADC #$08  ; more to the third one
    STA ram_misc_spr_data_offset-1,x  ; note that due to the way X is set up,
    CLC  ; this code loads into the misc sprite offsets
    ADC #$08
    STA ram_misc_spr_data_offset,x
    DEX
    DEX
    DEX
    DEY
    BPL bra_store_misc_oam_offset  ; do this until all misc spr offsets are loaded
    RTS

; -------------------------------------------------------------------------------------

sub_oper_mode_execution_tree:
    LDA ram_oper_mode  ; this is the heart of the entire program,
    JSR sub_dispatch_inline_handler  ; most of what goes on starts here

    .word handler_run_title_screen_mode
.if con_revision_profile = con_revision_profile_vs
    .word handler_run_vs_player_select_mode
.endif
    .word handler_run_game_mode
    .word handler_run_victory_mode
    .word handler_run_game_over_mode

; -------------------------------------------------------------------------------------

sub_move_all_sprites_offscreen:
    LDY #$00  ; this routine moves all sprites off the screen
.if con_revision_profile = con_revision_profile_vs
    JMP loc_move_sprites_offscreen_from_y
.else
    .byte $2c  ; BIT instruction opcode
.endif

sub_move_sprites_offscreen:
    LDY #$04  ; this routine moves all but sprite 0
loc_move_sprites_offscreen_from_y:
    LDA #$f8  ; off the screen
bra_hide_remaining_sprites_loop:
    STA ram_sprite_y_position,y  ; write 248 into OAM data's Y coordinate
    INY  ; which will move it off the screen
    INY
    INY
    INY
    BNE bra_hide_remaining_sprites_loop
    RTS
