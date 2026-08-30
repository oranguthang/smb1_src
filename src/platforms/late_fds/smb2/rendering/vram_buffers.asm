tbl_smb2_main_vram_addr_table:
    .word VRAM_Buffer1, off_smb2_main_water_area_palette_packet, off_smb2_main_ground_area_palette_packet, off_smb2_main_underground_area_palette_packet
    .word off_smb2_main_castle_area_palette_packet, off_smb2_main_title_screen_gfx_data, VRAM_Buffer2, VRAM_Buffer2
    .word off_smb2_main_bowser_palette_packet, off_smb2_main_day_snow_palette_packet, off_smb2_main_night_snow_palette_packet, off_smb2_main_mushroom_palette_packet
    .word off_smb2_main_thank_you_message, off_smb2_main_mushroom_retainer_msg, unused_smb2_data3_unused_attrib_data, off_smb2_data3_final_room_palette
    .word off_smb2_data3_thank_you_message_final, off_smb2_data3_peace_is_paved_msg, off_smb2_data3_with_kingdom_saved_msg, off_smb2_data3_hurrah_msg
    .word off_smb2_data3_our_only_hero_msg, off_smb2_data3_this_ends_your_trip_msg, off_smb2_data3_of_a_long_friendship_msg, off_smb2_data3_points_added_msg
    .word off_smb2_data3_for_each_player_left_msg, off_smb2_main_disk_error_main_msg, off_smb2_main_disk_screen_palette, tbl_smb2_data3_princess_peachs_room
    .word tbl_smb2_main_menu_cursor_template, off_smb2_data3_fantasy_world9_msg, off_smb2_data3_super_player_msg

tbl_smb2_main_vram_buffer_offset_addresses:
    .byte <VRAM_Buffer1_Offset, <VRAM_Buffer2_Offset

; -------------------------------------------------------------------------------------

handler_smb2_main_nmi_handler:
    LDA Mirror_PPU_CTRL  ; alter name table address to be $2800
    AND #%01111110  ; (essentially $2000) and disable another NMI
    STA Mirror_PPU_CTRL  ; from interrupting this one
    STA PPU_CTRL
    SEI
    LDA IRQUpdateFlag
    BEQ bra_smb2_main_skip_irq
    LDA #$58
    STA FDS_IRQTIMER_LOW  ; set FDS IRQ timer to occur at the end of the status bar
    LDA #$16
    STA FDS_IRQTIMER_HIGH
    LDA #$02
    STA FDS_IRQTIMER_CTRL  ; enable it
    INC IRQAckFlag  ; reset flag to wait for next IRQ
bra_smb2_main_skip_irq:
    LDA Mirror_PPU_MASK
    AND #%11100110  ; disable OAM and background display by default
    LDY DisableScreenFlag  ; if screen disabled, skip this
    BNE bra_smb2_main_apply_screen_enable_state
    LDA Mirror_PPU_MASK  ; otherwise reenable bits and save them
    ORA #%00011110
bra_smb2_main_apply_screen_enable_state:
    STA Mirror_PPU_MASK
    AND #%11100111  ; turn screen off regardless of mirror reg
    STA PPU_MASK
    LDX PPU_STATUS
    LDA #$00
    JSR sub_smb2_main_initialize_ppu_scroll
    STA PPU_SPR_ADDR
    LDA #$02  ; dump OAM data to PPU's sprite RAM
    STA SPR_DMA
    LDA VRAM_Buffer_AddrCtrl
    ASL
    TAX
    LDA tbl_smb2_main_vram_addr_table,x  ; get pointer to VRAM data
    STA $00
    INX
    LDA tbl_smb2_main_vram_addr_table,x
    STA $01
    JSR sub_smb2_main_update_screen  ; now update the screen with it
    LDY #$00
    LDX VRAM_Buffer_AddrCtrl
    CPX #$06  ; if pointer number was set to 6 (for
    BNE bra_smb2_main_init_vram_vars  ; second VRAM buffer), increment Y to get
    INY  ; offset for second VRAM buffer
bra_smb2_main_init_vram_vars:
    LDX tbl_smb2_main_vram_buffer_offset_addresses,y  ; get pointer to correct buffer offset
    LDA #$00  ; erase the VRAM buffer offset, init first VRAM buffer
    STA VRAM_Buffer1_Offset,x  ; by writing end terminator at the first byte, and
    STA VRAM_Buffer1,x  ; init address control to point at first VRAM buffer
    STA VRAM_Buffer_AddrCtrl
    LDA Mirror_PPU_MASK
    STA PPU_MASK  ; dump PPU control register 2
    CLI
loc_smb2_main_sound_engine_jsr_code:
    JSR sub_smb2_main_sound_engine  ; run subs that need to be run on every frame
    JSR sub_smb2_main_read_joypads
    JSR sub_smb2_main_pause_routine
    JSR sub_smb2_main_update_top_score
    LDA GamePauseStatus  ; check d0 of game pause flags
    LSR  ; if set, branch to skip
    BCS bra_smb2_main_seed_lfsr
    LDA TimerControl  ; if master timer control not set, branch
    BEQ bra_smb2_main_check_interval_tc  ; to decrement frame and interval timers
    DEC TimerControl  ; otherwise count this timer down
    BNE bra_smb2_main_inc_frame_cntr
bra_smb2_main_check_interval_tc:
    LDX #$14  ; set offset to decrement only frame timers
    DEC IntervalTimerControl  ; if interval timer control not expired, branch
    BPL bra_smb2_main_decr_the_timers  ; to skip and thus decrement only frame timers
    LDA #$14
    STA IntervalTimerControl  ; otherwise reset interval timer control to 20 frames
    LDX #$23  ; and load offset to decrement frame and interval timers
bra_smb2_main_decr_the_timers:
    LDA Timers,x  ; if current timer is already expired, skip it
    BEQ bra_smb2_main_decrement_timer_loop  ; otherwise decrement it
    DEC Timers,x
bra_smb2_main_decrement_timer_loop:
    DEX  ; loop until all timers that need to be counted down are
    BPL bra_smb2_main_decr_the_timers
bra_smb2_main_inc_frame_cntr:
    INC FrameCounter
bra_smb2_main_seed_lfsr:
    LDX #$00
    LDY #$07
    LDA PseudoRandomBitReg  ; get d1 of first byte
    AND #$02
    STA $00
    LDA PseudoRandomBitReg+1  ; get d1 of second byte, XOR it with the first byte
    AND #$02
    EOR $00
    CLC
    BEQ bra_smb2_main_rotate_lfsr  ; prepare to rotate the result in
    SEC
bra_smb2_main_rotate_lfsr:
    ROR PseudoRandomBitReg,x  ; basically, rotate the operation result into d7
    INX  ; then rotate the entire LFSR
    DEY
    BNE bra_smb2_main_rotate_lfsr
    LDA GamePauseStatus  ; if d0 of game pause flag is set, skip this part
    LSR
    BCS bra_smb2_main_wait_for_irq
    LDA IRQUpdateFlag
    BEQ bra_smb2_main_check_invalid_world_num
    JSR sub_smb2_main_move_sprites_offscreen
    JSR sub_smb2_main_sprite_shuffler
bra_smb2_main_check_invalid_world_num:
    LDA WorldNumber  ; if world number somehow goes past 9, just end the game
    CMP #$09
    BCC bra_smb2_main_execution_tree
    JSR sub_smb2_main_terminate_game
bra_smb2_main_execution_tree:
    JSR sub_smb2_main_oper_mode_execution_tree  ; run one of the program's four modes
bra_smb2_main_wait_for_irq:
    LDA IRQAckFlag  ; wait for IRQ
    BNE bra_smb2_main_wait_for_irq
    LDA PPU_STATUS
    LDA Mirror_PPU_CTRL  ; reenable NMIs
    ORA #$80
    STA Mirror_PPU_CTRL  ; then park it at endless loop until next NMI
    STA PPU_CTRL
    RTI

handler_smb2_main_irq_handler:
    SEI
    PHP  ; save regs
    PHA
    TXA
    PHA
    TYA
    PHA
    LDA FDS_STATUS  ; get disk status register, acknowledge IRQs
    PHA
    AND #$02  ; if byte transfer flag set, branch elsewhere
    BNE bra_smb2_main_delay_no_scr
    PLA
    AND #$01  ; if IRQ timer flag not set, branch to leave
    BEQ bra_smb2_main_exit_irq
    LDA Mirror_PPU_CTRL
    AND #$f7  ; mask out sprite address high reg of ctrl reg mirror
    ORA NameTableSelect  ; mask in whatever's set here
    STA Mirror_PPU_CTRL  ; update the register and its mirror
    STA PPU_CTRL
    LDA #$00
    STA FDS_IRQTIMER_CTRL  ; disable IRQ timer for the rest of the frame
    LDA HorizontalScroll
    STA PPU_SCROLL  ; set scroll regs for the screen under the status bar
    LDA VerticalScroll  ; to achieve the split screen effect
    STA PPU_SCROLL
    LDA #$00
    STA IRQAckFlag  ; indicate IRQ was acknowledged
    JMP bra_smb2_main_exit_irq  ; skip over the next part to end IRQ
bra_smb2_main_delay_no_scr:
    PLA  ; throw away disk status reg byte
    JSR sub_smb2_main_fdsbios_delay  ; run delay subroutine in FDS bios
bra_smb2_main_exit_irq:
    PLA
    TAY  ; return regs, reenable IRQs and leave
    PLA
    TAX
    PLA
    PLP
    CLI
    RTI

; -------------------------------------------------------------------------------------

sub_smb2_main_pause_routine:
    LDA OperMode  ; are we in victory mode?
    CMP #VictoryMode  ; if so, go ahead
    BEQ bra_smb2_main_check_pause_debounce_timer
    CMP #GameMode  ; are we in game mode?
    BNE bra_smb2_main_exit_pause_handler  ; if not, leave
    LDA OperMode_Task  ; if we are in game mode, are we running game engine?
    CMP #$04
    BNE bra_smb2_main_exit_pause_handler  ; if not, leave
bra_smb2_main_check_pause_debounce_timer:
    LDA GamePauseTimer  ; check if pause timer is still counting down
    BEQ bra_smb2_main_check_pause_start_button
    DEC GamePauseTimer  ; if so, decrement and leave
    RTS
bra_smb2_main_check_pause_start_button:
    LDA SavedJoypad1Bits  ; check to see if start is pressed
    AND #Start_Button
    BEQ bra_smb2_main_clear_pause_debounce_timer
    LDA GamePauseStatus  ; check to see if timer flag is set
    AND #%10000000  ; and if so, do not reset timer (residual,
    BNE bra_smb2_main_exit_pause_handler  ; joypad reading routine makes this unnecessary)
    LDA #$2b  ; set pause timer
    STA GamePauseTimer
    LDA GamePauseStatus
    TAY
    INY  ; set pause sfx queue for next pause mode
    STY PauseSoundQueue
    EOR #%00000001  ; invert d0 and set d7
    ORA #%10000000
    BNE bra_smb2_main_toggle_pause_mode  ; unconditional branch
bra_smb2_main_clear_pause_debounce_timer:
    LDA GamePauseStatus  ; clear timer flag if timer is at zero and start button
    AND #%01111111  ; is not pressed
bra_smb2_main_toggle_pause_mode:
    STA GamePauseStatus
bra_smb2_main_exit_pause_handler:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used for preset value

sub_smb2_main_sprite_shuffler:
    LDY AreaType  ; residual code, this value is never used
    LDA #$28  ; load preset value which will put it at
    STA $00  ; sprite #10
    LDX #$0e  ; start at the end of OAM data offsets
bra_smb2_main_shuffle_enemy_oam_offsets:
    LDA SprDataOffset,x  ; check for offset value against
    CMP $00  ; the preset value
    BCC bra_smb2_main_advance_sprite_shuffle_slot  ; if less, skip this part
    LDY SprShuffleAmtOffset  ; get current offset to preset value we want to add
    CLC
    ADC SprShuffleAmt,y  ; get shuffle amount, add to current sprite offset
    BCC bra_smb2_main_store_shuffled_sprite_offset  ; if not exceeded $ff, skip second add
    CLC
    ADC $00  ; otherwise add preset value $28 to offset
bra_smb2_main_store_shuffled_sprite_offset:
    STA SprDataOffset,x  ; store new offset here or old one if branched to here
bra_smb2_main_advance_sprite_shuffle_slot:
    DEX  ; move backwards to next one
    BPL bra_smb2_main_shuffle_enemy_oam_offsets
    LDX SprShuffleAmtOffset  ; load offset
    INX
    CPX #$03  ; check if offset + 1 goes to 3
    BNE bra_smb2_main_store_sprite_shuffle_index  ; if offset + 1 not 3, store
    LDX #$00  ; otherwise, init to 0
bra_smb2_main_store_sprite_shuffle_index:
    STX SprShuffleAmtOffset
    LDX #$08  ; load offsets for values and storage
    LDY #$02
bra_smb2_main_store_misc_oam_offset:
    LDA SprDataOffset+5,y  ; load one of three OAM data offsets
    STA Misc_SprDataOffset-2,x  ; store first one unmodified, but
    CLC  ; add eight to the second and eight
    ADC #$08  ; more to the third one
    STA Misc_SprDataOffset-1,x  ; note that due to the way X is set up,
    CLC  ; this code loads into the misc sprite offsets
    ADC #$08
    STA Misc_SprDataOffset,x
    DEX
    DEX
    DEX
    DEY
    BPL bra_smb2_main_store_misc_oam_offset  ; do this until all misc spr offsets are loaded
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_oper_mode_execution_tree:
    LDA OperMode  ; this is the heart of the entire program,
    JSR sub_smb2_main_dispatch_inline_handler  ; most of what goes on starts here

    .word handler_smb2_main_attract_mode_subs
    .word handler_smb2_main_game_mode_subs
    .word handler_smb2_main_victory_mode_main
    .word handler_smb2_main_game_over_subs

; -------------------------------------------------------------------------------------

sub_smb2_main_move_all_sprites_offscreen:
    LDY #$00  ; this routine moves all sprites off the screen
    .byte $2c  ; BIT instruction opcode

sub_smb2_main_move_sprites_offscreen:
    LDY #$04  ; this routine moves all but sprite 0
    LDA #$f8  ; off the screen
bra_smb2_main_hide_remaining_sprites_loop:
    STA Sprite_Y_Position,y  ; write 248 into OAM data's Y coordinate
    INY  ; which will move it off the screen
    INY
    INY
    INY
    BNE bra_smb2_main_hide_remaining_sprites_loop
bra_smb2_main_vm_exit:
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_victory_mode_main:
    JSR sub_smb2_main_victory_mode_subroutines  ; run victory mode subroutines in order
    LDA OperMode_Task  ; if running bridge collapse subroutine
    BEQ bra_smb2_main_skip_bridge_player_draw  ; then skip most of this
    LDX WorldNumber
    CPX #World8  ; if not on world 8, skip, don't bother checking
    BNE bra_smb2_main_not_w8  ; to see which subroutine we're on
    CMP #$05
    BEQ bra_smb2_main_vm_exit  ; if running disk subroutines, branch to leave
    CMP #$0d  ; because the screen will be blank during this
    BEQ bra_smb2_main_vm_exit
bra_smb2_main_not_w8:
    LDX #$00
    STX ObjectOffset  ; run code for a single enemy object
    JSR sub_smb2_main_enemies_and_loops_core  ; (either the mushroom retainer or door/princess)
bra_smb2_main_skip_bridge_player_draw:
    JSR sub_smb2_main_relative_player_position  ; draw the player as usual
    JMP sub_smb2_main_render_player_graphics

sub_smb2_main_victory_mode_subroutines:
    LDA WorldNumber  ; run different list of subroutines if on world 8
    CMP #World8
    BEQ bra_smb2_main_victory_mode_subs_for_w8  ; note that world D will also run second set of subs
    LDA OperMode_Task  ; after running the first two subs in the first set
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_bridge_collapse
    .word handler_smb2_main_setup_victory_mode
    .word handler_smb2_main_player_victory_walk
    .word handler_smb2_main_print_victory_messages
    .word handler_smb2_main_end_castle_award
    .word handler_smb2_main_end_world1_thru7

bra_smb2_main_victory_mode_subs_for_w8:
    LDA OperMode_Task
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_bridge_collapse
    .word handler_smb2_main_setup_victory_mode
    .word handler_smb2_main_player_victory_walk
    .word handler_smb2_main_start_vm_delay
    .word handler_smb2_main_continue_vm_delay
    .word handler_smb2_main_victory_mode_disk_routines
    .word handler_smb2_data3_screen_subs_for_final_room  ; all these subs are in SM2DATA3
    .word handler_smb2_data3_print_victory_msgs_for_world8
    .word handler_smb2_main_end_castle_award  ; except this one
    .word handler_smb2_data3_award_extra_lives
    .word handler_smb2_data3_fade_to_blue
    .word handler_smb2_data3_erase_lives_lines
    .word handler_smb2_data3_run_mushroom_retainers
    .word handler_smb2_data3_ending_disk_routines

; -------------------------------------------------------------------------------------

tbl_smb2_main_world_bits:
    .byte $01, $02, $04, $08, $10, $20, $40, $80

handler_smb2_main_setup_victory_mode:
    LDX ScreenRight_PageLoc  ; get page location of right side of screen
    INX  ; increment to next page
    STX DestinationPageLoc
    LDY WorldNumber
    LDA tbl_smb2_main_world_bits,y
    ORA CompletedWorlds  ; set bit according to the world the player was in
    STA CompletedWorlds
    LDA HardWorldFlag  ; if not playing worlds A-D, branch to skip this
    BEQ bra_smb2_main_w1_thru8
    LDA WorldNumber  ; otherwise, if not on world D, branch to skip this
    CMP #World4  ; (note worlds A-D use values 0-3 in this variable)
    BCC bra_smb2_main_w1_thru8
    LDA #World8  ; if on world D, set world number to 8 to satisfy
    STA WorldNumber  ; end of game condition in later victory mode subs
bra_smb2_main_w1_thru8:
    LDA #EndOfCastleMusic
    STA EventMusicQueue  ; play win castle music

bra_smb2_main_inc_mode_task:
    INC OperMode_Task
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_copy_title_screen_from_chr:
    LDA OperMode  ; if not in attract mode, do not draw title screen
    BNE bra_smb2_main_inc_mode_task  ; yes, this routine is run in other modes
    LDA #$05
    JMP loc_smb2_main_store_vram_buffer_control_from_a  ; otherwise set up VRAM address controller accordingly

; -------------------------------------------------------------------------------------

handler_smb2_main_player_victory_walk:
    LDY #$00  ; set value here to not walk player by default
    STY VictoryWalkControl
    LDA Player_PageLoc  ; get player's page location
    CMP DestinationPageLoc  ; compare with destination page location
    BNE bra_smb2_main_move_player_during_victory  ; if page locations don't match, branch
    LDA Player_X_Position  ; otherwise get player's horizontal position
    CMP #$60  ; compare with preset horizontal position
    BCS bra_smb2_main_finish_player_victory_walk  ; if still on other page, branch ahead
bra_smb2_main_move_player_during_victory:
    INC VictoryWalkControl  ; otherwise increment value and Y
    INY  ; note Y will be used to walk the player
bra_smb2_main_finish_player_victory_walk:
    TYA  ; put contents of Y in A and
    JSR sub_smb2_main_auto_control_player  ; use A to move player to the right or not
    LDA ScreenLeft_PageLoc  ; check page location of left side of screen
    CMP DestinationPageLoc  ; against set value here
    BEQ bra_smb2_main_finish_victory_walk  ; branch if equal to change modes if necessary
    LDA ScrollFractional
    CLC  ; do fixed point math on fractional part of scroll
    ADC #$80
    STA ScrollFractional  ; save fractional movement amount
    LDA #$01  ; set 1 pixel per frame
    ADC #$00  ; add carry from previous addition
    TAY  ; use as scroll amount
    JSR sub_smb2_main_scroll_screen  ; do sub to scroll the screen
    JSR sub_smb2_main_update_scroll_variables  ; do another sub to update screen and scroll variables
    INC VictoryWalkControl  ; increment value to stay in this routine
bra_smb2_main_finish_victory_walk:
    LDA VictoryWalkControl  ; load value set here
    BEQ bra_smb2_main_advance_victory_mode_task  ; if zero, branch to change modes
    RTS  ; otherwise leave

handler_smb2_main_print_victory_messages:
    LDA MsgFractional  ; load message counter fractional
    BNE bra_smb2_main_advance_victory_message_timer  ; if not yet wrapped, branch to increment it
    LDA MsgCounter  ; otherwise load message counter
    BEQ bra_smb2_main_select_victory_message  ; if set to zero, branch to print first message
    CMP #$08  ; if at 8 or above, branch elsewhere
    BCS bra_smb2_main_advance_victory_message_timer
    CMP #$01  ; if at zero, branch (note, this branch is never
    BCC bra_smb2_main_advance_victory_message_timer  ; taken because we already branched at zero earlier)
bra_smb2_main_select_victory_message:
    TAY
    BEQ bra_smb2_main_print_msgs
    CPY #$03
    BCS bra_smb2_main_set_victory_end_timer  ; wait until a specific point to set the timer
    CPY #$02
    BCS bra_smb2_main_advance_victory_message_timer  ; skip printing of messages after the first two
bra_smb2_main_print_msgs:
    TYA  ; put primary message counter in A
    CLC  ; add 12 to counter, thus giving an appropriate value
    ADC #$0c
    STA VRAM_Buffer_AddrCtrl  ; write message counter to vram address controller
bra_smb2_main_advance_victory_message_timer:
    LDA MsgFractional
    CLC
    ADC #$04  ; add four to fractional
    STA MsgFractional
    LDA MsgCounter
    ADC #$00  ; carry the one if fractional wraps
    STA MsgCounter
    CMP #$06  ; check message counter one more time
bra_smb2_main_set_victory_end_timer:
    BCC bra_smb2_main_exit_victory_messages  ; if not reached 6 yet, branch to leave
    LDA #$08
    STA WorldEndTimer  ; otherwise set world end timer
bra_smb2_main_advance_victory_mode_task:
    INC OperMode_Task  ; move onto next task in mode
bra_smb2_main_exit_victory_messages:
    RTS

handler_smb2_main_end_castle_award:
    LDA WorldEndTimer  ; if world end timer has not yet reached a certain point
    CMP #$06  ; then go ahead and skip all of this
    BCS bra_smb2_main_exit_end_castle_award
    JSR sub_smb2_main_award_timer_castle
    LDA GameTimerDisplay  ; if game timer points not all awarded, skip this part
    ORA GameTimerDisplay+1
    ORA GameTimerDisplay+2
    BNE bra_smb2_main_exit_end_castle_award
    LDA #$30
    STA SelectTimer  ; set select timer (used for world 8 ending only)
    LDA #$06
    STA WorldEndTimer  ; another short delay, then on to the next task
    INC OperMode_Task
bra_smb2_main_exit_end_castle_award:
    RTS

handler_smb2_main_end_world1_thru7:
    LDA WorldEndTimer  ; skip this until world end timer expires
    BNE bra_smb2_main_end_exit
loc_smb2_main_next_world:
    LDA #$00
    STA AreaNumber  ; reset area/level numbers to start the next world
    STA LevelNumber
    STA OperMode_Task
    LDA WorldNumber
    CLC
    ADC #$01  ; add one, but only up to world 9
    CMP #World9
    BCC bra_smb2_main_no_past9
    LDA #World9  ; make world 9 loop forever (or until game is over)
bra_smb2_main_no_past9:
    STA WorldNumber  ; update the world number
    JSR sub_smb2_main_load_area_pointer  ; get pointer for the next area
    INC FetchNewGameTimerFlag  ; and get a new game timer
    LDA #$01
    STA OperMode  ; and oh yeah, go back to game mode also
bra_smb2_main_end_exit:
    RTS

; -------------------------------------------------------------------------------------

; data is used as tiles for numbers
; that appear when you defeat enemies
