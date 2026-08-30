bra_smb2_main_continue_music_playback:
    JMP loc_smb2_main_handle_square_2_music  ; if we have music, start with square 2 channel

sub_smb2_main_music_handler:
    LDA EventMusicQueue  ; check event music queue
    BNE bra_smb2_main_load_event_music
    LDA AreaMusicQueue  ; check area music queue
    BNE bra_smb2_main_load_area_music
    LDA EventMusicBuffer  ; check both buffers
    ORA AreaMusicBuffer
    BNE bra_smb2_main_continue_music_playback
    RTS  ; no music, then leave

bra_smb2_main_load_event_music:
    STA EventMusicBuffer  ; copy event music queue contents to buffer
    CMP #DeathMusic  ; is it death music?
    BNE bra_smb2_main_prepare_event_music  ; if not, jump elsewhere
    JSR sub_smb2_main_stop_square_1_sound_effect  ; stop sfx in square 1 and 2
    JSR sub_smb2_main_stop_square_2_sound_effect  ; but clear only square 1's sfx buffer
bra_smb2_main_prepare_event_music:
    LDX AreaMusicBuffer
    STX AreaMusicBuffer_Alt  ; save current area music buffer to be re-obtained later
    LDY #$00
    STY NoteLengthTblAdder  ; default value for additional length byte offset
    STY AreaMusicBuffer  ; clear area music buffer
    CMP #TimeRunningOutMusic  ; is it time running out music?
    BNE bra_smb2_main_find_event_music_header
    LDX #$08  ; load offset to be added to length byte of header
    STX NoteLengthTblAdder
    BNE bra_smb2_main_find_event_music_header  ; unconditional branch

bra_smb2_main_load_area_music:
    CMP #$04  ; is it underground music?
    BNE bra_smb2_main_prepare_area_music  ; no, do not stop square 1 sfx
    JSR sub_smb2_main_stop_square_1_sound_effect
bra_smb2_main_prepare_area_music:
    LDY #$10  ; start counter used only by ground level music
bra_smb2_main_store_ground_music_header_offset:
    STY GroundMusicHeaderOfs

loc_smb2_main_restart_area_music:
    LDY #$00  ; clear event music buffer
    STY EventMusicBuffer
    STA AreaMusicBuffer  ; copy area music queue contents to buffer
    CMP #$01  ; is it ground level music?
    BNE bra_smb2_main_find_area_music_header
    INC GroundMusicHeaderOfs  ; increment but only if playing ground level music
    LDY GroundMusicHeaderOfs  ; is it time to loopback ground level music?
    CPY #$32
    BNE bra_smb2_main_load_music_header  ; branch ahead with alternate offset
    LDY #$11
    BNE bra_smb2_main_store_ground_music_header_offset  ; unconditional branch

bra_smb2_main_find_area_music_header:
    LDY #$08  ; load Y for offset of area music
    STY MusicOffset_Square2  ; residual instruction here

bra_smb2_main_find_event_music_header:
    INY  ; increment Y pointer based on previously loaded queue contents
    LSR  ; bit shift and increment until we find a set bit for music
    BCC bra_smb2_main_find_event_music_header

bra_smb2_main_load_music_header:
    LDA MusicHeaderOffsetData,y  ; load offset for header
    TAY
    LDA off_smb2_main_music_header_offsets,y  ; now load the header
    STA NoteLenLookupTblOfs
    LDA off_smb2_main_music_header_offsets+1,y
    STA MusicDataLow
    LDA off_smb2_main_music_header_offsets+2,y
    STA MusicDataHigh
    LDA off_smb2_main_music_header_offsets+3,y
    STA MusicOffset_Triangle
    LDA off_smb2_main_music_header_offsets+4,y
    STA MusicOffset_Square1
    LDA off_smb2_main_music_header_offsets+5,y
    STA MusicOffset_Noise
    STA NoiseDataLoopbackOfs
    LDA #$01  ; initialize music note counters
    STA Squ2_NoteLenCounter
    STA Squ1_NoteLenCounter
    STA Tri_NoteLenCounter
    STA Noise_BeatLenCounter
    LDA #$00  ; initialize music data offset for square 2
    STA MusicOffset_Square2
    STA AltRegContentFlag  ; initialize alternate control reg data used by square 1
    LDA #$0b  ; disable triangle channel and reenable it
    STA SND_MASTERCTRL_REG
    LDA #$0f
    STA SND_MASTERCTRL_REG

loc_smb2_main_handle_square_2_music:
    DEC Squ2_NoteLenCounter  ; decrement square 2 note length
    BNE bra_smb2_main_update_square_2_music_envelope  ; is it time for more data?  if not, branch to end tasks
    LDY MusicOffset_Square2  ; increment square 2 music offset and fetch data
    INC MusicOffset_Square2
    LDA (MusicData),y
    BEQ bra_smb2_main_handle_end_of_music_data  ; if zero, the data is a null terminator
    BPL bra_smb2_main_handle_square_2_note  ; if non-negative, data is a note
    BNE bra_smb2_main_handle_square_2_length  ; otherwise it is length data

bra_smb2_main_handle_end_of_music_data:
    LDA EventMusicBuffer  ; check secondary buffer for time running out music
    CMP #TimeRunningOutMusic
    BNE bra_smb2_main_handle_regular_music_end
    LDA AreaMusicBuffer_Alt  ; load previously saved contents of primary buffer
    BNE bra_smb2_main_restart_area_music  ; and start playing the song again if there is one
bra_smb2_main_handle_regular_music_end:
    AND #VictoryMusic  ; check for victory music (the only secondary that loops)
    BNE bra_smb2_main_restart_victory_music
    LDA AreaMusicBuffer  ; check primary buffer for any music except pipe intro
    AND #%01011111
    BNE bra_smb2_main_restart_area_music  ; if any area music except pipe intro, music loops
    LDA #$00  ; clear primary and secondary buffers and initialize
    STA AreaMusicBuffer  ; control regs of square and triangle channels
    STA EventMusicBuffer
    STA SND_TRIANGLE_REG
    LDA #$90
    STA SND_SQUARE1_REG
    STA SND_SQUARE2_REG
    RTS

bra_smb2_main_restart_area_music:
    JMP loc_smb2_main_restart_area_music

bra_smb2_main_restart_victory_music:
    JMP bra_smb2_main_load_event_music

bra_smb2_main_handle_square_2_length:
    JSR sub_smb2_main_process_length_data  ; store length of note
    STA Squ2_NoteLenBuffer
    LDY MusicOffset_Square2  ; fetch another byte (MUST NOT BE LENGTH BYTE!)
    INC MusicOffset_Square2
    LDA (MusicData),y

bra_smb2_main_handle_square_2_note:
    LDX Square2SoundBuffer  ; is there a sound playing on this channel?
    BNE bra_smb2_main_reload_square_2_note_counter
    JSR sub_smb2_main_set_square_2_frequency  ; no, then play the note
    BEQ bra_smb2_main_store_square_2_envelope_state  ; check to see if note is rest
    JSR sub_smb2_main_load_control_regs  ; if not, load control regs for square 2
bra_smb2_main_store_square_2_envelope_state:
    STA Squ2_EnvelopeDataCtrl  ; save contents of A
    JSR sub_smb2_main_store_square_2_registers  ; dump X and Y into square 2 control regs
bra_smb2_main_reload_square_2_note_counter:
    LDA Squ2_NoteLenBuffer  ; save length in square 2 note counter
    STA Squ2_NoteLenCounter

bra_smb2_main_update_square_2_music_envelope:
    LDA Square2SoundBuffer  ; is there a sound playing on square 2?
    BNE bra_smb2_main_handle_square_1_music
    LDA EventMusicBuffer  ; check for death music or d4 set on secondary buffer
    AND #%10010001  ; note that regs for death music or d4 are loaded by default
    BNE bra_smb2_main_handle_square_1_music
    LDY Squ2_EnvelopeDataCtrl  ; check for contents saved from LoadControlRegs
    BEQ bra_smb2_main_load_square_2_envelope
    DEC Squ2_EnvelopeDataCtrl  ; decrement unless already zero
bra_smb2_main_load_square_2_envelope:
    JSR sub_smb2_main_load_envelope_data  ; do a load of envelope data to replace default
    STA SND_SQUARE2_REG  ; based on offset set by first load unless playing
    LDX #$7f  ; death music or d4 set on secondary buffer
    STX SND_SQUARE2_REG+1

bra_smb2_main_handle_square_1_music:
    LDY MusicOffset_Square1  ; is there a nonzero offset here?
    BEQ bra_smb2_main_handle_triangle_music  ; if not, skip ahead to the triangle channel
    DEC Squ1_NoteLenCounter  ; decrement square 1 note length
    BNE bra_smb2_main_update_square_1_music_envelope  ; is it time for more data?

bra_smb2_main_fetch_square_1_music_data:
    LDY MusicOffset_Square1  ; increment square 1 music offset and fetch data
    INC MusicOffset_Square1
    LDA (MusicData),y
    BNE bra_smb2_main_handle_square_1_note  ; if nonzero, then skip this part
    LDA #$83
    STA SND_SQUARE1_REG  ; store some data into control regs for square 1
    LDA #$94  ; and fetch another byte of data, used to give
    STA SND_SQUARE1_REG+1  ; death music its unique sound
    STA AltRegContentFlag
    BNE bra_smb2_main_fetch_square_1_music_data  ; unconditional branch

bra_smb2_main_handle_square_1_note:
    JSR sub_smb2_main_alternate_length_handler
    STA Squ1_NoteLenCounter  ; save contents of A in square 1 note counter
    LDY Square1SoundBuffer  ; is there a sound playing on square 1?
    BNE bra_smb2_main_handle_triangle_music
    TXA
    AND #%00111110  ; change saved data to appropriate note format
    JSR sub_smb2_main_set_square_1_frequency  ; play the note
    BEQ bra_smb2_main_store_square_1_envelope_state
    JSR sub_smb2_main_load_control_regs
bra_smb2_main_store_square_1_envelope_state:
    STA Squ1_EnvelopeDataCtrl  ; save envelope offset
    JSR sub_smb2_main_store_square_1_registers

bra_smb2_main_update_square_1_music_envelope:
    LDA Square1SoundBuffer  ; is there a sound playing on square 1?
    BNE bra_smb2_main_handle_triangle_music
    LDA EventMusicBuffer  ; check for death music or d4 set on secondary buffer
    AND #%10010001
    BNE bra_smb2_main_load_square_1_sweep_register
    LDY Squ1_EnvelopeDataCtrl  ; check saved envelope offset
    BEQ bra_smb2_main_load_square_1_envelope
    DEC Squ1_EnvelopeDataCtrl  ; decrement unless already zero
bra_smb2_main_load_square_1_envelope:
    JSR sub_smb2_main_load_envelope_data  ; do a load of envelope data
    STA SND_SQUARE1_REG  ; based on offset set by first load
bra_smb2_main_load_square_1_sweep_register:
    LDA AltRegContentFlag  ; check for alternate control reg data
    BNE bra_smb2_main_store_square_1_sweep_register
    LDA #$7f  ; load this value if zero, the alternate value
bra_smb2_main_store_square_1_sweep_register:
    STA SND_SQUARE1_REG+1  ; if nonzero, and let's move on

bra_smb2_main_handle_triangle_music:
    LDA MusicOffset_Triangle
    DEC Tri_NoteLenCounter  ; decrement triangle note length
    BNE bra_smb2_main_handle_noise_music  ; is it time for more data?
    LDY MusicOffset_Triangle  ; increment triangle music offset and fetch data
    INC MusicOffset_Triangle
    LDA (MusicData),y
    BEQ bra_smb2_main_store_triangle_control_register  ; if zero, skip all this and move on to noise
    BPL bra_smb2_main_handle_triangle_note  ; if non-negative, data is note
    JSR sub_smb2_main_process_length_data  ; otherwise, it is length data
    STA Tri_NoteLenBuffer  ; save contents of A
    LDA #$1f
    STA SND_TRIANGLE_REG  ; load some default data for triangle control reg
    LDY MusicOffset_Triangle  ; fetch another byte
    INC MusicOffset_Triangle
    LDA (MusicData),y
    BEQ bra_smb2_main_store_triangle_control_register  ; check once more for nonzero data

bra_smb2_main_handle_triangle_note:
    JSR sub_smb2_main_set_triangle_frequency
    LDX Tri_NoteLenBuffer  ; save length in triangle note counter
    STX Tri_NoteLenCounter
    LDA EventMusicBuffer
    AND #%01101110  ; check for death music or d4 set on secondary buffer
    BNE bra_smb2_main_select_triangle_note_sustain  ; if playing any other secondary, skip primary buffer check
    LDA AreaMusicBuffer  ; check primary buffer for water or castle level music
    AND #%00001010
    BEQ bra_smb2_main_handle_noise_music  ; if playing any other primary, or death or d4, go on to noise routine
bra_smb2_main_select_triangle_note_sustain:
    TXA  ; if playing water or castle music or any secondary
    CMP #$12  ; besides death music or d4 set, check length of note
    BCS bra_smb2_main_use_long_triangle_sustain
    LDA EventMusicBuffer  ; check for win castle music again if not playing a long note
    AND #EndOfCastleMusic
    BEQ bra_smb2_main_use_medium_triangle_sustain
    LDA #$0f  ; load value $0f if playing the win castle music and playing a short
    BNE bra_smb2_main_store_triangle_control_register  ; note, load value $1f if playing water or castle level music or any
bra_smb2_main_use_medium_triangle_sustain:
    LDA #$1f  ; secondary besides death and d4 except win castle or win castle and playing
    BNE bra_smb2_main_store_triangle_control_register  ; a short note, and load value $ff if playing a long note on water, castle
bra_smb2_main_use_long_triangle_sustain:
    LDA #$ff  ; or any secondary (including win castle) except death and d4

bra_smb2_main_store_triangle_control_register:
    STA SND_TRIANGLE_REG  ; save final contents of A into control reg for triangle

bra_smb2_main_handle_noise_music:
    LDA AreaMusicBuffer  ; check if playing underground or castle music
    AND #%11110011
    BEQ bra_smb2_main_exit_music_handler  ; if so, skip the noise routine
    DEC Noise_BeatLenCounter  ; decrement noise beat length
    BNE bra_smb2_main_exit_music_handler  ; is it time for more data?

bra_smb2_main_fetch_noise_beat_data:
    LDY MusicOffset_Noise  ; increment noise beat offset and fetch data
    INC MusicOffset_Noise
    LDA (MusicData),y  ; get noise beat data, if nonzero, branch to handle
    BNE bra_smb2_main_handle_noise_beat
    LDA NoiseDataLoopbackOfs  ; if data is zero, reload original noise beat offset
    STA MusicOffset_Noise  ; and loopback next time around
    BNE bra_smb2_main_fetch_noise_beat_data  ; unconditional branch

bra_smb2_main_handle_noise_beat:
    JSR sub_smb2_main_alternate_length_handler
    STA Noise_BeatLenCounter  ; store length in noise beat counter
    TXA
    AND #%00111110  ; reload data and erase length bits
    BEQ bra_smb2_main_silence_noise_beat  ; if no beat data, silence
    CMP #$30  ; check the beat data and play the appropriate
    BEQ bra_smb2_main_play_long_noise_beat  ; noise accordingly
    CMP #$20
    BEQ bra_smb2_main_play_strong_noise_beat
    AND #%00010000
    BEQ bra_smb2_main_silence_noise_beat
    LDA #$1c  ; short beat data
    LDX #$03
    LDY #$18
    BNE bra_smb2_main_store_noise_beat_registers

bra_smb2_main_play_strong_noise_beat:
    LDA #$1c  ; strong beat data
    LDX #$0c
    LDY #$18
    BNE bra_smb2_main_store_noise_beat_registers

bra_smb2_main_play_long_noise_beat:
    LDA #$1c  ; long beat data
    LDX #$03
    LDY #$58
    BNE bra_smb2_main_store_noise_beat_registers

bra_smb2_main_silence_noise_beat:
    LDA #$10  ; silence

bra_smb2_main_store_noise_beat_registers:
    STA SND_NOISE_REG  ; load beat data into noise regs
    STX SND_NOISE_REG+2
    STY SND_NOISE_REG+3

bra_smb2_main_exit_music_handler:
    RTS

sub_smb2_main_alternate_length_handler:
    TAX  ; save a copy of original byte into X
    ROR  ; save LSB from original byte into carry
    TXA  ; reload original byte and rotate three times
    ROL  ; turning xx00000x into 00000xxx, with the
    ROL  ; bit in carry as the MSB here
    ROL

sub_smb2_main_process_length_data:
    AND #%00000111  ; clear all but the three LSBs
    CLC
    ADC NoteLenLookupTblOfs  ; add offset loaded from first header byte
    ADC NoteLengthTblAdder  ; add extra if time running out music
    TAY
    LDA tbl_smb2_main_music_note_lengths,y  ; load length
    RTS

sub_smb2_main_load_control_regs:
    LDA EventMusicBuffer  ; check secondary buffer for win castle music
    AND #EndOfCastleMusic
    BEQ bra_smb2_main_select_regular_music_control
    LDA #$04  ; this value is only used for win castle music
    BNE bra_smb2_main_finish_music_control_registers  ; unconditional branch
bra_smb2_main_select_regular_music_control:
    LDA AreaMusicBuffer
    AND #%01111101  ; check primary buffer for water music
    BEQ bra_smb2_main_select_water_music_control
    LDA #$08  ; this is the default value for all other music
    BNE bra_smb2_main_finish_music_control_registers
bra_smb2_main_select_water_music_control:
    LDA #$28  ; this value is used for water music and all other event music
bra_smb2_main_finish_music_control_registers:
    LDX #$82  ; load contents of other sound regs for square 2
    LDY #$7f
    RTS

sub_smb2_main_load_envelope_data:
    LDA EventMusicBuffer  ; check secondary buffer for win castle music
    AND #EndOfCastleMusic
    BEQ bra_smb2_main_load_area_music_envelope
    LDA off_smb2_main_castle_clear_music_envelope,y  ; load data from offset for win castle music
    RTS

bra_smb2_main_load_area_music_envelope:
    LDA AreaMusicBuffer  ; check primary buffer for water music
    AND #%01111101
    BEQ bra_smb2_main_load_water_or_event_music_envelope
    LDA off_smb2_main_area_music_envelope_values,y  ; load default data from offset for all other music
    RTS

bra_smb2_main_load_water_or_event_music_envelope:
    LDA off_smb2_main_water_and_event_music_envelope_values,y  ; load data from offset for water music and all other event music
    RTS

off_smb2_main_music_header_offsets:
    .byte tbl_smb2_main_music_header_death-MHD
    .byte tbl_smb2_main_music_header_game_over-MHD
    .byte tbl_smb2_main_music_header_game_over-MHD
    .byte tbl_smb2_main_music_header_castle_clear-MHD
    .byte tbl_smb2_main_music_header_game_over-MHD
    .byte tbl_smb2_main_music_header_end_of_level-MHD
    .byte tbl_smb2_main_music_header_time_running_out-MHD
    .byte tbl_smb2_main_music_header_silence-MHD

    .byte tbl_smb2_main_music_header_ground_part_1-MHD  ; area music
    .byte tbl_smb2_main_music_header_water-MHD
    .byte tbl_smb2_main_music_header_underground-MHD
    .byte tbl_smb2_main_music_header_castle-MHD
    .byte tbl_smb2_main_music_header_star_cloud-MHD
    .byte tbl_smb2_main_music_header_ground_lead_in-MHD
    .byte tbl_smb2_main_music_header_star_cloud-MHD
    .byte tbl_smb2_main_music_header_silence-MHD

    .byte tbl_smb2_main_music_header_ground_lead_in-MHD  ; ground level music layout
    .byte tbl_smb2_main_music_header_ground_part_1-MHD, tbl_smb2_main_music_header_ground_part_1-MHD
    .byte tbl_smb2_main_music_header_ground_part_2_a-MHD, tbl_smb2_main_music_header_ground_part_2_b-MHD, tbl_smb2_main_music_header_ground_part_2_a-MHD, tbl_smb2_main_music_header_ground_part_2_c-MHD
    .byte tbl_smb2_main_music_header_ground_part_2_a-MHD, tbl_smb2_main_music_header_ground_part_2_b-MHD, tbl_smb2_main_music_header_ground_part_2_a-MHD, tbl_smb2_main_music_header_ground_part_2_c-MHD
    .byte tbl_smb2_main_music_header_ground_part_3_a-MHD, tbl_smb2_main_music_header_ground_part_3_b-MHD, tbl_smb2_main_music_header_ground_part_3_a-MHD, tbl_smb2_main_music_header_ground_lead_in-MHD
    .byte tbl_smb2_main_music_header_ground_part_1-MHD, tbl_smb2_main_music_header_ground_part_1-MHD
    .byte tbl_smb2_main_music_header_ground_part_4_a-MHD, tbl_smb2_main_music_header_ground_part_4_b-MHD, tbl_smb2_main_music_header_ground_part_4_a-MHD, tbl_smb2_main_music_header_ground_part_4_c-MHD
    .byte tbl_smb2_main_music_header_ground_part_4_a-MHD, tbl_smb2_main_music_header_ground_part_4_b-MHD, tbl_smb2_main_music_header_ground_part_4_a-MHD, tbl_smb2_main_music_header_ground_part_4_c-MHD
    .byte tbl_smb2_main_music_header_ground_part_3_a-MHD, tbl_smb2_main_music_header_ground_part_3_b-MHD, tbl_smb2_main_music_header_ground_part_3_a-MHD, tbl_smb2_main_music_header_ground_lead_in-MHD
    .byte tbl_smb2_main_music_header_ground_part_4_a-MHD, tbl_smb2_main_music_header_ground_part_4_b-MHD, tbl_smb2_main_music_header_ground_part_4_a-MHD, tbl_smb2_main_music_header_ground_part_4_c-MHD

; music headers
; header format is as follows:
; 1 byte - length byte offset
; 2 bytes -  music data address
; 1 byte - triangle data offset
; 1 byte - square 1 data offset
; 1 byte - noise data offset (not used by secondary music)

tbl_smb2_main_music_header_time_running_out:
    .byte $08, <off_smb2_main_music_stream_time_running_out, >off_smb2_main_music_stream_time_running_out, $27, $18
tbl_smb2_main_music_header_star_cloud:
    .byte $20, <off_smb2_main_music_stream_star_cloud, >off_smb2_main_music_stream_star_cloud, $2e, $1a, $40
tbl_smb2_main_music_header_end_of_level:
    .byte $20, <off_smb2_main_music_stream_end_of_level, >off_smb2_main_music_stream_end_of_level, $3d, $21
tbl_smb2_main_music_header_residual:
    .byte $20, $fb, $dc, $3f, $1d
tbl_smb2_main_music_header_underground:
    .byte $18, <off_smb2_main_music_stream_underground, >off_smb2_main_music_stream_underground, $00, $00
tbl_smb2_main_music_header_silence:
    .byte $08, <off_smb2_main_music_stream_silence, >off_smb2_main_music_stream_silence, $00
tbl_smb2_main_music_header_castle:
    .byte $00, <off_smb2_main_music_stream_castle, >off_smb2_main_music_stream_castle, $93, $62
tbl_smb2_main_music_header_game_over:
    .byte $18, <off_smb2_main_music_stream_game_over, >off_smb2_main_music_stream_game_over, $1e, $14
tbl_smb2_main_music_header_water:
    .byte $08, <off_smb2_main_music_stream_water, >off_smb2_main_music_stream_water, $a0, $70, $68
tbl_smb2_main_music_header_castle_clear:
    .byte $08, <off_smb2_main_music_stream_castle_clear, >off_smb2_main_music_stream_castle_clear, $4c, $24
tbl_smb2_main_music_header_ground_part_1:
    .byte $18, <off_smb2_main_music_stream_ground_part_1, >off_smb2_main_music_stream_ground_part_1, $2d, $1c, $b8
tbl_smb2_main_music_header_ground_part_2_a:
    .byte $18, <off_smb2_main_music_stream_ground_part_2_a, >off_smb2_main_music_stream_ground_part_2_a, $20, $12, $70
tbl_smb2_main_music_header_ground_part_2_b:
    .byte $18, <off_smb2_main_music_stream_ground_part_2_b, >off_smb2_main_music_stream_ground_part_2_b, $1b, $10, $44
tbl_smb2_main_music_header_ground_part_2_c:
    .byte $18, <off_smb2_main_music_stream_ground_part_2_c, >off_smb2_main_music_stream_ground_part_2_c, $11, $0a, $1c
tbl_smb2_main_music_header_ground_part_3_a:
    .byte $18, <off_smb2_main_music_stream_ground_part_3_a, >off_smb2_main_music_stream_ground_part_3_a, $2d, $10, $58
tbl_smb2_main_music_header_ground_part_3_b:
    .byte $18, <off_smb2_main_music_stream_ground_part_3_b, >off_smb2_main_music_stream_ground_part_3_b, $14, $0d, $3f
tbl_smb2_main_music_header_ground_lead_in:
    .byte $18, <off_smb2_main_music_stream_ground_lead_in, >off_smb2_main_music_stream_ground_lead_in, $15, $0d, $21
tbl_smb2_main_music_header_ground_part_4_a:
    .byte $18, <off_smb2_main_music_stream_ground_part_4_a, >off_smb2_main_music_stream_ground_part_4_a, $18, $10, $7a
tbl_smb2_main_music_header_ground_part_4_b:
    .byte $18, <off_smb2_main_music_stream_ground_part_4_b, >off_smb2_main_music_stream_ground_part_4_b, $19, $0f, $54
tbl_smb2_main_music_header_ground_part_4_c:
    .byte $18, <off_smb2_main_music_stream_ground_part_4_c, >off_smb2_main_music_stream_ground_part_4_c, $1e, $12, $2b
tbl_smb2_main_music_header_death:
    .byte $18, <off_smb2_main_music_stream_death, >off_smb2_main_music_stream_death, $1e, $0f, $2d

; --------------------------------

; MUSIC DATA
; square 2/triangle format
; d7 - length byte flag (0-note, 1-length)
; if d7 is set to 0 and d6-d0 is nonzero:
; d6-d0 - note offset in frequency look-up table (must be even)
; if d7 is set to 1:
; d6-d3 - unused
; d2-d0 - length offset in length look-up table
; value of $00 in square 2 data is used as null terminator, affects all sound channels
; value of $00 in triangle data causes routine to skip note

; square 1 format
; d7-d6, d0 - length offset in length look-up table (bit order is d0,d7,d6)
; d5-d1 - note offset in frequency look-up table
; value of $00 in square 1 data is flag alternate control reg data to be loaded

; noise format
; d7-d6, d0 - length offset in length look-up table (bit order is d0,d7,d6)
; d5-d4 - beat type (0 - rest, 1 - short, 2 - strong, 3 - long)
; d3-d1 - unused
; value of $00 in noise data is used as null terminator, affects only noise

; all music data is organized into sections (unless otherwise stated):
; square 2, square 1, triangle, noise
