; SMB2J DISASSEMBLY (SM2DATA3 portion)

; -------------------------------------------------------------------------------------
; DEFINES

OperMode              = $0770
OperMode_Task         = $0772
ScreenRoutineTask     = $073c
DiskIOTask            = $07fc

VRAM_Buffer1          = $0301
VRAM_Buffer_AddrCtrl  = $0773
DisableScreenFlag     = $0774
SelectTimer           = $0780
ScreenTimer           = $07a0
WorldEndTimer         = $07a1
FantasyW9MsgFlag      = $07f5

IRQUpdateFlag        = $0722
IRQAckFlag           = $077b

FDSBIOS_DELAY     = $e149
FDSBIOS_LOADFILES = $e1f8
sub_smb2_data3_fds_bios_write_file = $e239
NameTableSelect   = $077a
CompletedWorlds   = $07fa
HardWorldFlag     = $07fb
FileListNumber    = $07f7

GamePauseStatus   = $0776

ObjectOffset        = $08
Enemy_ID            = $16
Enemy_Y_Position    = $cf
Enemy_Rel_XPos      = $03ae
Enemy_SprDataOffset = $06e5

SelectedPlayer      = $0753
NumberofLives       = $075a
DigitModifier       = $0134
WorldNumber         = $075f

; sound related defines
Squ2_NoteLenBuffer      = $0610
Squ2_NoteLenCounter     = $0611
Squ2_EnvelopeDataCtrl   = $0612
Squ1_NoteLenCounter     = $0613
Squ1_EnvelopeDataCtrl   = $0614
Tri_NoteLenBuffer       = $0615
Tri_NoteLenCounter      = $0616
Noise_BeatLenCounter    = $0617
FDSSND_LenBuffer        = $05f2
FDSSND_LenCounter       = $05f1
FDSSND_MasterEnvTimer   = $05f3
FDSSND_ModTableNumber   = $05f6
FDSSND_MasterEnvSet     = $05f7
FDSSND_VolumeEnvTimer   = $05f8
FDSSND_VolumeEnvOffset  = $05f9
FDSSND_SweepModTimer    = $05fa
FDSSND_SweepModOffset   = $05fb

PauseSoundQueue       = $fa
Square1SoundQueue     = $ff
Square2SoundQueue     = $fe
NoiseSoundQueue       = $fd
AreaMusicQueue        = $fb
EventMusicQueue       = $fc

Square1SoundBuffer    = $f1
Square2SoundBuffer    = $f2
NoiseSoundBuffer      = $f3
AreaMusicBuffer       = $f4
EventMusicBuffer      = $07b1
PauseSoundBuffer      = $07b2
AltMusicBuffer        = $0608

PatternNumber         = $061d

MusicData             = $66
MusicDataLow          = $66
MusicDataHigh         = $67
WaveformData          = $68
FDSSND_VolumeEnvData  = $6a
FDSSND_SweepModData   = $6c
MusicOffset_Square2   = $060a
MusicOffset_Square1   = $060b
MusicOffset_Triangle  = $060c
MusicOffset_Noise     = $060d
MusicOffset_FDSSND    = $061f

NoteLenLookupTblOfs   = $f0
DAC_Counter           = $07c0
NoiseDataLoopbackOfs  = $061b
NoteLengthTblAdder    = $0609
AreaMusicBuffer_Alt   = $07c5
PauseModeFlag         = $07c6
GroundMusicHeaderOfs  = $07c7
AltRegContentFlag     = $07ca

WaveformID            = $060e

MsgCounter            = $0719
MsgFractional         = $0749

EndControlCntr        = $0761
BlueColorOfs          = $0762
BlueDelayFlag         = $0763
MushroomRetDelay      = $0764
MRetainerOffset       = $0762
CurrentFlashMRet      = $0763

MHD = tbl_smb2_data3_music_header_offset_data

GameOverMode          = 3

Sfx_ExtraLife          = %01000000
Sfx_CoinGrab           = %00000001
VictoryMusic           = %00000100

; imports from other files
.import sub_smb2_main_move_sprites_offscreen
.import tbl_smb2_main_music_note_periods
.import loc_smb2_main_next_world
.import handler_smb2_main_write_top_status_line
.import handler_smb2_main_write_bottom_status_line
.import handler_smb2_main_select_area_palette
.import handler_smb2_main_prepare_background_and_player_colors
.import loc_smb2_main_award_end_area_points
.import sub_smb2_main_dispatch_inline_handler
.import sub_smb2_main_handle_square_2_sound_effect
.import sub_smb2_main_print_status_bar_numbers
.import tbl_smb2_main_disk_id_string
.import sub_smb2_main_render_enemy_graphics
.import sub_smb2_main_sound_engine
.import handler_smb2_main_disk_screen
.import handler_smb2_main_wait_for_eject
.import handler_smb2_main_wait_for_reinsert
.import handler_smb2_main_reset_disk_vars
.import loc_smb2_main_disk_error_handler
.import handler_smb2_main_attract_mode_subs
.import loc_smb2_main_sound_engine_jsr_code
.import handler_smb2_main_init_screen_palette

; exports to other files
.export handler_smb2_data3_erase_lives_lines
.export handler_smb2_data3_run_mushroom_retainers
.export handler_smb2_data3_ending_disk_routines
.export handler_smb2_data3_award_extra_lives
.export handler_smb2_data3_print_victory_msgs_for_world8
.export handler_smb2_data3_fade_to_blue
.export handler_smb2_data3_screen_subs_for_final_room
.export loc_smb2_data3_write_name_to_victory_msg
.export unused_smb2_data3_unused_attrib_data
.export off_smb2_data3_final_room_palette
.export off_smb2_data3_thank_you_message_final
.export off_smb2_data3_peace_is_paved_msg
.export off_smb2_data3_with_kingdom_saved_msg
.export off_smb2_data3_hurrah_msg
.export off_smb2_data3_our_only_hero_msg
.export off_smb2_data3_this_ends_your_trip_msg
.export off_smb2_data3_of_a_long_friendship_msg
.export off_smb2_data3_points_added_msg
.export off_smb2_data3_for_each_player_left_msg
.export tbl_smb2_data3_princess_peachs_room
.export off_smb2_data3_fantasy_world9_msg
.export off_smb2_data3_super_player_msg
.export off_smb2_data3_e_castle_area9
.export off_smb2_data3_e_castle_area10
.export off_smb2_data3_e_ground_area25
.export off_smb2_data3_e_ground_area26
.export off_smb2_data3_e_ground_area27
.export off_smb2_data3_e_water_area6
.export off_smb2_data3_e_water_area7
.export off_smb2_data3_e_water_area8
.export off_smb2_data3_l_castle_area9
.export off_smb2_data3_l_castle_area10
.export off_smb2_data3_l_ground_area25
.export off_smb2_data3_l_ground_area26
.export off_smb2_data3_l_ground_area27
.export off_smb2_data3_l_water_area6
.export off_smb2_data3_l_water_area7
.export off_smb2_data3_l_water_area8

; -------------------------------------------------------------------------------------

loc_smb2_data3_print_world9_msgs:
    LDA OperMode  ; if in game over mode, branch
    CMP #GameOverMode  ; note this routine only runs after world 8 and replaces
    BEQ bra_smb2_data3_w9_game_over  ; the routine DemoReset in memory
    LDA FantasyW9MsgFlag  ; if world 9 flag was set earlier, skip this part
    BNE bra_smb2_data3_finish_fantasy_world_9_message
    LDA #$1d  ; otherwise set VRAM pointer to print
    STA VRAM_Buffer_AddrCtrl  ; the hidden fantasy "9 world" message
    LDA #$10
    STA ScreenTimer
    INC FantasyW9MsgFlag  ; and set flag to keep it from getting printed again
bra_smb2_data3_finish_fantasy_world_9_message:
    LDA #$00
    STA DisableScreenFlag  ; turn screen back on, move on to next screen sub
    JMP loc_smb2_data3_next_screen_task

bra_smb2_data3_w9_game_over:
    LDA #$20
    STA ScreenTimer
    LDA #$1e  ; set VRAM pointer to print world 9 goodbye message
    STA VRAM_Buffer_AddrCtrl
    JMP loc_smb2_data3_next_oper_task  ; move on to next task

handler_smb2_data3_screen_subs_for_final_room:
    LDA ScreenRoutineTask
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_init_screen_palette
    .word handler_smb2_main_write_top_status_line
    .word handler_smb2_main_write_bottom_status_line
    .word handler_smb2_data3_draw_final_room
    .word handler_smb2_main_select_area_palette
    .word handler_smb2_main_prepare_background_and_player_colors
    .word handler_smb2_data3_reveal_princess

handler_smb2_data3_draw_final_room:
    LDA #$1b  ; draw the princess's room
    STA VRAM_Buffer_AddrCtrl
    STA IRQUpdateFlag
loc_smb2_data3_next_screen_task:
    INC ScreenRoutineTask
    RTS

handler_smb2_data3_reveal_princess:
    LDA #$a2  ; print game timer
    JSR sub_smb2_main_print_status_bar_numbers
    LDA #>loc_smb2_data3_alternate_sound_engine
    STA loc_smb2_main_sound_engine_jsr_code+2  ; change sound engine address
    LDA #<loc_smb2_data3_alternate_sound_engine  ; to run the alt music engine on every NMI
    STA loc_smb2_main_sound_engine_jsr_code+1
    LDA #$01
    STA AreaMusicQueue  ; play the only song available to it
    LDA #$00  ; aka the victory music
    STA $0c  ; residual, this does nothing
    STA NameTableSelect
    STA IRQUpdateFlag  ; turn screen back on but without IRQs
    STA DisableScreenFlag
loc_smb2_data3_next_oper_task:
    INC OperMode_Task
    RTS

handler_smb2_data3_print_victory_msgs_for_world8:
    LDA MsgFractional  ; if fractional not looped to zero
    BNE bra_smb2_data3_increment_victory_message_counter  ; then branch to increment it
    LDY MsgCounter
    CPY #$0a  ; if message counter gone past a certain
    BCS bra_smb2_data3_end_victory_messages  ; point, branch to set timer and stop printing messages
    INY
    INY
    INY  ; add 3 to message counter to print the messages
    CPY #$05  ; for world 8 (as opposed to worlds 1-7)
    BNE bra_smb2_data3_print_victory_message
    LDA #VictoryMusic  ; residual code from original smb source, this will not
    STA EventMusicQueue  ; be checked due to alternate vector for sound engine
bra_smb2_data3_print_victory_message:
    TYA
    CLC
    ADC #$0c  ; get appropriate range for victory messages
    STA VRAM_Buffer_AddrCtrl
bra_smb2_data3_increment_victory_message_counter:
    LDA MsgFractional
    CLC
    ADC #$04  ; add four to counter's fractional
    STA MsgFractional
    LDA MsgCounter  ; add carry to the message counter itself
    ADC #$00
    STA MsgCounter
    RTS

bra_smb2_data3_end_victory_messages:
    LDA #$0c  ; set interval timer, then move onto next task
    STA WorldEndTimer
bra_smb2_data3_advance_after_extra_life_awards:
    INC OperMode_Task

sub_smb2_data3_erase_ending_counters:
    LDA #$00
    STA EndControlCntr
    STA MRetainerOffset
    STA CurrentFlashMRet
bra_smb2_data3_wait_for_extra_life_award:
    RTS

handler_smb2_data3_award_extra_lives:
    LDA WorldEndTimer  ; wait until timer expires before running this sub
    BNE bra_smb2_data3_wait_for_extra_life_award
    LDA NumberofLives  ; if counted all extra lives, branch
    BMI bra_smb2_data3_advance_after_extra_life_awards  ; to run another task in victory mode
    LDA SelectTimer
    BNE bra_smb2_data3_wait_for_extra_life_award  ; if short delay between each count of extra lives
    LDA #$30  ; not expired, wait, otherwise, reset the timer
    STA SelectTimer
    LDA #Sfx_ExtraLife
    STA Square2SoundQueue
    DEC NumberofLives  ; count down each extra life
    LDA #$01  ; give 100,000 points to player for each one
    STA DigitModifier+1
    JMP loc_smb2_main_award_end_area_points

off_smb2_data3_blue_trans_palette:
    .byte $3f, $00, $10
    .byte $0f, $30, $0f, $0f, $0f, $30, $10, $00, $0f, $21, $12, $21, $0f, $27, $17, $00
    .byte $00

tbl_smb2_data3_blue_tints:
    .byte $01, $02, $11, $21

tbl_smb2_data3_two_blank_rows:
    .byte $22, $86, $55, $24
    .byte $22, $a6, $55, $24
    .byte $00

handler_smb2_data3_fade_to_blue:
    INC EndControlCntr  ; increment a counter
    LDA BlueDelayFlag  ; if it's time to fade to blue, branch
    BNE bra_smb2_data3_blue_update_timing
    LDA EndControlCntr
    AND #$ff  ; otherwise wait until counter wraps
    BNE bra_smb2_data3_exit_blue_fade  ; then set the flag
    INC BlueDelayFlag
    JMP loc_smb2_data3_update_blue_transition  ; skip over next part if the flag was just set

bra_smb2_data3_blue_update_timing:
    LDA EndControlCntr
    AND #$0f  ; execute the next part only every 16 frames
    BNE bra_smb2_data3_exit_blue_fade
loc_smb2_data3_update_blue_transition:
    LDX #$13
bra_smb2_data3_write_blue_transition_palette_loop:
    LDA off_smb2_data3_blue_trans_palette,x  ; write palette to VRAM buffer
    STA VRAM_Buffer1,x
    DEX
    BPL bra_smb2_data3_write_blue_transition_palette_loop
    LDX #$0c
    LDY BlueColorOfs  ; get color offset
bra_smb2_data3_next_blue:
    LDA tbl_smb2_data3_blue_tints,y  ; set background color based on color offset
    STA VRAM_Buffer1+3,x
    DEX  ; be sure to set the same background color
    DEX  ; in all four palettes (even though only the first
    DEX  ; one is acknowledged)
    DEX
    BPL bra_smb2_data3_next_blue
    INC BlueColorOfs  ; increment to next color which will show up
    LDA BlueColorOfs  ; 16 frames later, thus causing a slow color change
    CMP #$04  ; if not changed to last color, leave
    BNE bra_smb2_data3_exit_blue_fade
    INC OperMode_Task  ; otherwise move on to the next task
bra_smb2_data3_exit_blue_fade:
    RTS

handler_smb2_data3_erase_lives_lines:
    LDX #$08  ; erase bottom two lines
bra_smb2_data3_erase_lives_lines_loop:
    LDA tbl_smb2_data3_two_blank_rows,x
    STA VRAM_Buffer1,x
    DEX
    BPL bra_smb2_data3_erase_lives_lines_loop
    INC OperMode_Task
    JSR sub_smb2_data3_erase_ending_counters  ; init ending counters
    LDA #$60
    STA MushroomRetDelay  ; wait before flashing each mushroom retainer in next sub
    RTS

handler_smb2_data3_run_mushroom_retainers:
    JSR sub_smb2_data3_mushroom_retainers_for_w8  ; draw and flash the seven mushroom retainers
    LDA AltMusicBuffer  ; if still playing victory music, branch to leave
    BNE bra_smb2_data3_exit_mushroom_retainer_sequence
    LDA HardWorldFlag  ; if on world D, branch elsewhere
    BNE bra_smb2_data3_back_to_normal
    INC OperMode_Task  ; otherwise just move onto the last task
bra_smb2_data3_exit_mushroom_retainer_sequence:
    RTS

handler_smb2_data3_ending_disk_routines:
    LDA DiskIOTask
    JSR sub_smb2_main_dispatch_inline_handler

    .word handler_smb2_main_disk_screen
    .word handler_smb2_data3_update_games_beaten
    .word handler_smb2_main_wait_for_eject
    .word handler_smb2_main_wait_for_reinsert
    .word handler_smb2_main_reset_disk_vars

off_smb2_data3_save_file_header:
    .byte $0f, "SM2SAVE "
    .word $d29f
    .byte $01, $00, $00
    .word $d29f
    .byte $00

handler_smb2_data3_update_games_beaten:
    LDA #$07  ; set file sequential position
    JSR sub_smb2_data3_fds_bios_write_file  ; save number of games beaten to SM2SAVE
    .word tbl_smb2_main_disk_id_string
    .word off_smb2_data3_save_file_header

; execution continues here
    BEQ bra_smb2_data3_back_to_normal  ; if no error, continue
    INC DiskIOTask  ; otherwise move on to next disk task
    JMP loc_smb2_main_disk_error_handler  ; and jump to disk error handler

bra_smb2_data3_back_to_normal:
    LDA #>sub_smb2_main_sound_engine  ; reset sound engine vector
    STA loc_smb2_main_sound_engine_jsr_code+2  ; to run the original one
    LDA #<sub_smb2_main_sound_engine
    STA loc_smb2_main_sound_engine_jsr_code+1
    LDA #$00
    STA DiskIOTask  ; erase task numbers
    STA OperMode_Task
    LDA HardWorldFlag  ; if in world D, branch to end the game
    BNE bra_smb2_data3_end_the_game
    LDA CompletedWorlds  ; if completed all worlds without skipping over any
    CMP #$ff  ; then branch elsewhere (note warping backwards may
    BEQ bra_smb2_data3_go_to_world9  ; allow player to complete skipped worlds)
bra_smb2_data3_end_the_game:
    LDA #$00
    STA CompletedWorlds  ; init completed worlds flag, go back to title screen mode
    STA OperMode
    JMP handler_smb2_main_attract_mode_subs  ; jump to title screen mode routines
bra_smb2_data3_go_to_world9:
    LDA #$00
    STA CompletedWorlds  ; init completed worlds flag
    STA NumberofLives  ; give the player one life
    STA FantasyW9MsgFlag
    JMP loc_smb2_main_next_world  ; run world 9

off_smb2_data3_flashing_mushroom_retainer_sprite_data_offsets:
    .byte $50, $b0, $e0, $68, $98, $c8

off_smb2_data3_mushroom_retainer_sprite_data_offsets:
    .byte $80, $50, $68, $80, $98, $b0, $c8

tbl_smb2_data3_mushroom_retainer_y_positions:
    .byte $e0, $b8, $90, $70, $68, $70, $90

tbl_smb2_data3_mushroom_retainer_x_positions:
    .byte $b8, $38, $48, $60, $80, $a0, $b8, $c8

sub_smb2_data3_mushroom_retainers_for_w8:
    LDA MushroomRetDelay  ; wait a bit unless waiting is already done
    BEQ bra_smb2_data3_draw_flashing_mushroom_retainers
    DEC MushroomRetDelay
    RTS

bra_smb2_data3_draw_flashing_mushroom_retainers:
    JSR sub_smb2_main_move_sprites_offscreen  ; init sprites
    LDX MRetainerOffset
    CPX #$07  ; if 7 mushroom retainers added, branch elsewhere
    BEQ bra_smb2_data3_flash_mushroom_retainers
    LDA EndControlCntr
    AND #$1f  ; execute this part once every 32 frames
    BNE bra_smb2_data3_draw_mushroom_retainers
    INC MRetainerOffset  ; add another mushroom retainer
    LDA #Sfx_CoinGrab
    STA Square2SoundQueue  ; play the coin grab sound
    JMP bra_smb2_data3_draw_mushroom_retainers

bra_smb2_data3_flash_mushroom_retainers:
    LDA EndControlCntr
    AND #$1f  ; execute this part once every 32 frames also
    BNE bra_smb2_data3_draw_mushroom_retainers  ; after the counter reaches a certain point
    INC CurrentFlashMRet
    LDA CurrentFlashMRet  ; increment what's now being used to select a
    CMP #$0b  ; mushroom retainer to flash, if not yet at $0b/11
    BCC bra_smb2_data3_draw_mushroom_retainers  ; then go ahead to next part
    LDA #$04
    STA CurrentFlashMRet  ; otherwise reset to 4
bra_smb2_data3_draw_mushroom_retainers:
    INC EndControlCntr  ; be sure to count frames
    LDA WorldNumber
    PHA  ; save world number and initial retainer offset
    LDA MRetainerOffset
    PHA
    TAX  ; use second counter as offset to one of the spr data offset lists
bra_smb2_data3_draw_mushroom_retainers_loop:
    LDA CurrentFlashMRet  ; if offset not yet at 4 (first time it starts at 0), branch to skip this
    CMP #$04  ; thus adding a delay between the appearance
    BCC bra_smb2_data3_setup_mushroom_retainer  ; of mushroom retainers and their "flashing"
    SBC #$04
    TAY  ; otherwise subtract 4 to get the offset proper
    LDA off_smb2_data3_flashing_mushroom_retainer_sprite_data_offsets,y  ; if the sprite obj data offset pointed at by the current flashing retainer
    CMP off_smb2_data3_mushroom_retainer_sprite_data_offsets,x  ; matches the one pointed at by the offset of the retainer being checked
    BEQ bra_smb2_data3_advance_mushroom_retainer  ; then branch to skip, do not draw that mushroom retainer
bra_smb2_data3_setup_mushroom_retainer:
    LDY off_smb2_data3_mushroom_retainer_sprite_data_offsets,x  ; get sprite data offset of the current mushroom retainer
    STY Enemy_SprDataOffset
    LDA #$35
    STA $16  ; set mushroom retainer object ID
    LDA tbl_smb2_data3_mushroom_retainer_y_positions,x
    STA Enemy_Y_Position  ; use enemy object 0 for mushroom retainer temporarily
    LDA tbl_smb2_data3_mushroom_retainer_x_positions,x
    STA Enemy_Rel_XPos
    LDX #$00  ; set world number and object offset for the graphics handler
    STX WorldNumber  ; to prevent graphics handler from drawing princess instead
    STX ObjectOffset
    JSR sub_smb2_main_render_enemy_graphics  ; now draw the mushroom retainer
bra_smb2_data3_advance_mushroom_retainer:
    DEC MRetainerOffset  ; move to next mushroom retainer using offset
    LDX MRetainerOffset
    BNE bra_smb2_data3_draw_mushroom_retainers_loop  ; if not drawn all retainers yet, loop to do so
    PLA
    STA MRetainerOffset  ; reset initial offset
    PLA
    STA WorldNumber  ; return world number to what it was to draw princess
    LDA #$30
    STA Enemy_SprDataOffset
    LDA #$b8  ; return original settings princess uses (note X position
    STA Enemy_Y_Position  ; will be returned later in enemy object core)
    RTS

off_smb2_data3_end_player_name_data:
    .byte $16, $0a, $1b, $12, $18
    .byte $15, $1e, $12, $10, $12

loc_smb2_data3_write_name_to_victory_msg:
    LDA #$00
    STA ScreenRoutineTask  ; init screen routine task
    LDX #$04
    LDA SelectedPlayer  ; check selected player
    BEQ bra_smb2_data3_select_victory_player_name  ; if mario, use by default
    LDX #$09  ; otherwise use luigi's name
bra_smb2_data3_select_victory_player_name:
    LDY #$04
bra_smb2_data3_write_victory_player_name_loop:
    LDA off_smb2_data3_end_player_name_data,x
    STA off_smb2_data3_thank_you_message_final+13,y  ; overwrite name of player in two
    STA off_smb2_data3_hurrah_msg+14,y  ; of the victory messages
    DEX
    DEY
    BPL bra_smb2_data3_write_victory_player_name_loop
    RTS

; -------------------------------------------------------------------------------------

unused_smb2_data3_unused_attrib_data:
    .byte $23, $c0, $48, $55
    .byte $23, $c2, $01, $d5
    .byte $00

off_smb2_data3_final_room_palette:
    .byte $3f, $00, $10
    .byte $0f, $0f, $0f, $0f, $0f, $30, $10, $00
    .byte $0f, $21, $12, $02, $0f, $27, $17, $00
    .byte $00

off_smb2_data3_thank_you_message_final:
    .byte $20, $e8, $10
    .byte $1d, $11, $0a, $17, $14, $24, $22, $18, $1e, $24
    .byte $16, $0a, $1b, $12, $18, $2b

    .byte $23, $c8, $48, $05
    .byte $00

off_smb2_data3_peace_is_paved_msg:
    .byte $21, $09, $0e
    .byte $19, $0e, $0a, $0c, $0e, $24, $12, $1c, $24
    .byte $19, $0a, $1f, $0e, $0d
    .byte $23, $d0, $58, $aa
    .byte $00

off_smb2_data3_with_kingdom_saved_msg:
    .byte $21, $47, $12
    .byte $20, $12, $1d, $11, $24, $14, $12, $17, $10, $0d, $18, $16, $24
    .byte $1c, $0a, $1f, $0e, $0d
    .byte $00

off_smb2_data3_hurrah_msg:
    .byte $21, $89, $10
    .byte $11, $1e, $1b, $1b, $0a, $11, $24, $1d, $18, $24, $24, $16, $0a
    .byte $1b, $12, $18
    .byte $00

off_smb2_data3_our_only_hero_msg:
    .byte $21, $ca, $0d
    .byte $18, $1e, $1b, $24, $18, $17, $15, $22, $24, $11, $0e, $1b, $18
    .byte $00

off_smb2_data3_this_ends_your_trip_msg:
    .byte $22, $07, $13
    .byte $1d, $11, $12, $1c, $24, $0e, $17, $0d, $1c, $24, $22, $18, $1e
    .byte $1b, $24, $1d, $1b, $12, $19
    .byte $00

off_smb2_data3_of_a_long_friendship_msg:
    .byte $22, $46, $14
    .byte $18, $0f, $24, $0a, $24, $15, $18, $17, $10, $24, $0f, $1b, $12
    .byte $0e, $17, $0d, $1c, $11, $12, $19
    .byte $00

off_smb2_data3_points_added_msg:
    .byte $22, $88, $10
    .byte $01, $00, $00, $00, $00, $00, $24, $19, $1d, $1c, $af, $0a, $0d
    .byte $0d, $0e, $0d

    .byte $23, $e8, $48, $ff
    .byte $00

off_smb2_data3_for_each_player_left_msg:
    .byte $22, $a6, $15
    .byte $0f, $18, $1b, $24, $0e, $0a, $0c, $11, $24, $19, $15, $0a, $22
    .byte $0e, $1b, $24, $15, $0e, $0f, $1d, $af
    .byte $00

tbl_smb2_data3_princess_peachs_room:
    .byte $20, $80, $60, $5e
    .byte $20, $a0, $60, $5d
    .byte $23, $40, $60, $5e
    .byte $23, $60, $60, $5d
    .byte $23, $80, $60, $5e
    .byte $23, $a0, $60, $5d
    .byte $23, $c0, $50, $55
    .byte $23, $f0, $50, $55
    .byte $00

off_smb2_data3_fantasy_world9_msg:
    .byte $22, $24, $18
    .byte $20, $0e, $24, $19, $1b, $0e, $1c, $0e, $17, $1d, $24, $0f, $0a
    .byte $17, $1d, $0a, $1c, $22, $24, $20, $18, $1b, $15, $0d

    .byte $22, $66, $13
    .byte $15, $0e, $1d, $f2, $1c, $24, $1d, $1b, $22, $24, $76, $09, $24
    .byte $20, $18, $1b, $15, $0d, $75

    .byte $22, $a9, $0e
    .byte $20, $12, $1d, $11, $24, $18, $17, $0e, $24, $10, $0a, $16, $0e
    .byte $af
    .byte $00

off_smb2_data3_super_player_msg:
    .byte $21, $e0, $60, $24
    .byte $22, $40, $60, $24
    .byte $22, $25, $16
    .byte $22, $18, $1e, $f2, $1b, $0e, $24, $0a, $24, $1c, $1e, $19, $0e
    .byte $1b, $24, $19, $15, $0a, $22, $0e, $1b, $2b
    .byte $22, $69, $0d
    .byte $20, $0e, $24, $11, $18, $19, $0e, $24, $20, $0e, $f2, $15, $15
    .byte $22, $a9, $0e
    .byte $1c, $0e, $0e, $24, $22, $18, $1e, $24, $0a, $10, $0a, $12, $17
    .byte $af
    .byte $22, $e8, $10
    .byte $16, $0a, $1b, $12, $18, $24, $0a, $17, $0d, $24, $1c, $1d, $0a
    .byte $0f, $0f, $af
    .byte $00

; -------------------------------------------------------------------------------------

; unused space
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff

; level 9-3
