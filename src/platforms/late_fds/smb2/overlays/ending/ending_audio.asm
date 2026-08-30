loc_smb2_data3_alternate_sound_engine:
    LDA GamePauseStatus  ; check to see if game is paused
    BEQ bra_smb2_data3_run_alt_sound_routines  ; branch to play sfx and music if not
    LDA #$80
    STA FDSSND_VOLUMECTRL  ; otherwise, silence everything
    LSR
    STA SND_MASTERCTRL_REG
    RTS

bra_smb2_data3_run_alt_sound_routines:
    LDA #$ff  ; disable irqs from apu and set frame counter mode
    STA JOYPAD_PORT2
    LDA #$0f
    STA SND_MASTERCTRL_REG  ; enable first four channels
    JSR sub_smb2_main_handle_square_2_sound_effect  ; play sfx on square channel 2
    JSR sub_smb2_data3_alt_music_handler
    LDA #$00
    STA AreaMusicQueue
    STA Square2SoundQueue
    RTS

bra_smb2_data3_continue_music_playback:
    JMP loc_smb2_data3_handle_square_2_music

sub_smb2_data3_alt_music_handler:
    LDA AreaMusicQueue
    BNE bra_smb2_data3_play_music
    LDA AltMusicBuffer
    BNE bra_smb2_data3_continue_music_playback
    RTS

bra_smb2_data3_play_music:
    LDY #$00  ; init song pattern number
    STY PatternNumber
    STA AltMusicBuffer  ; dump queue contents into buffer
loc_smb2_data3_next_pattern:
    INC PatternNumber
    LDY PatternNumber
    CPY #$0c
    BNE bra_smb2_data3_load_pattern_header
    JMP loc_smb2_data3_stop_music

bra_smb2_data3_load_pattern_header:
    LDA tbl_smb2_data3_music_header_offset_data-1,y  ; load pattern header offset using an address
    TAY  ; one byte behind (because Y starts at 1)
    LDA off_smb2_data3_music_header_offsets-$b,y
    STA NoteLengthTblAdder
    LDA off_smb2_data3_music_header_offsets-$a,y  ; now load the pattern header data using addresses
    STA MusicDataLow  ; that are relative of where the offset data is
    LDA off_smb2_data3_music_header_offsets-9,y  ; plus the offset data itself that was loaded
    STA MusicDataHigh
    LDA off_smb2_data3_music_header_offsets-8,y
    STA MusicOffset_Triangle
    LDA off_smb2_data3_music_header_offsets-7,y
    STA MusicOffset_Square1
    LDA off_smb2_data3_music_header_offsets-6,y
    STA MusicOffset_Noise
    STA NoiseDataLoopbackOfs
    LDA off_smb2_data3_music_header_offsets-5,y
    STA MusicOffset_FDSSND
    LDA off_smb2_data3_music_header_offsets-4,y
    STA WaveformID  ; value here is not used, but retained (probably for testing)
    STA $01
    JSR sub_smb2_data3_process_waveform_data
    LDA #$01  ; init note length counters
    STA Squ2_NoteLenCounter
    STA Squ1_NoteLenCounter
    STA Tri_NoteLenCounter
    STA Noise_BeatLenCounter
    STA FDSSND_LenCounter
    LDA #$00
    STA MusicOffset_Square2
    LDA #$0b
    STA SND_MASTERCTRL_REG  ; disable and reenable triangle channel
    LDA #$0f
    STA SND_MASTERCTRL_REG

loc_smb2_data3_handle_square_2_music:
    DEC Squ2_NoteLenCounter  ; if note length not expired, skip ahead to envelope
    BNE bra_smb2_data3_update_square_2_music_envelope
    LDY MusicOffset_Square2
    INC MusicOffset_Square2  ; get next byte in music data
    LDA (MusicData),y
    BEQ bra_smb2_data3_end_pattern  ; if end terminator, branch to play the next pattern or stop
    BPL bra_smb2_data3_handle_square_2_note  ; if positive, data is note, branch to play it
    BNE bra_smb2_data3_handle_square_2_length  ; otherwise data is length, branch to process length
bra_smb2_data3_end_pattern:
    LDA AltMusicBuffer  ; if music buffer still set, branch
    BNE bra_smb2_data3_next_pattern_jump
loc_smb2_data3_stop_music:
    LDA #$00  ; otherwise init sound and sound related variables
    STA AltMusicBuffer  ; to silence everything
    STA SND_TRIANGLE_REG
    STA MusicDataHigh
    STA MusicDataLow
    STA MusicOffset_Square2
    STA MusicOffset_Square1
    STA MusicOffset_Triangle
    STA MusicOffset_Noise
    LDA #$90
    STA SND_SQUARE1_REG
    STA SND_SQUARE2_REG
    LDA #$80
    STA FDSSND_VOLUMECTRL
    RTS

bra_smb2_data3_next_pattern_jump:
    JMP loc_smb2_data3_next_pattern

bra_smb2_data3_handle_square_2_length:
    JSR sub_smb2_data3_process_length_data  ; store length of note
    STA Squ2_NoteLenBuffer
    LDY MusicOffset_Square2
    INC MusicOffset_Square2  ; fetch another byte (MUST NOT BE LENGTH BYTE!)
    LDA (MusicData),y

bra_smb2_data3_handle_square_2_note:
    LDX Square2SoundBuffer  ; if playing sound on square 2 channel, skip
    BNE bra_smb2_data3_reload_square_2_note_counter
    JSR sub_smb2_data3_set_square_2_frequency  ; otherwise play a note on square 2
    BEQ bra_smb2_data3_store_square_2_envelope_state
    LDA #$10  ; set envelope counter and regs for square 2
    LDX #$82
    LDY #$7f
bra_smb2_data3_store_square_2_envelope_state:
    STA Squ2_EnvelopeDataCtrl
    JSR sub_smb2_data3_store_square_2_registers
bra_smb2_data3_reload_square_2_note_counter:
    LDA Squ2_NoteLenBuffer  ; save length to counter
    STA Squ2_NoteLenCounter

bra_smb2_data3_update_square_2_music_envelope:
    LDA Square2SoundBuffer  ; if playing sound on square 2 channel, skip
    BNE bra_smb2_data3_handle_square_1_music
    LDY Squ2_EnvelopeDataCtrl  ; get envelope counter
    BEQ bra_smb2_data3_load_square_2_envelope  ; use to update envelope on square 2 unless expired
    DEC Squ2_EnvelopeDataCtrl
bra_smb2_data3_load_square_2_envelope:
    LDA off_smb2_data3_victory_music_envelope_data,y
    STA SND_SQUARE2_REG

bra_smb2_data3_handle_square_1_music:
    LDY MusicOffset_Square1  ; get offset, skip if none was ever loaded
    BEQ bra_smb2_data3_handle_triangle_music
    DEC Squ1_NoteLenCounter  ; if note length not expired, skip ahead to envelope
    BNE bra_smb2_data3_update_square_1_music_envelope
    LDY MusicOffset_Square1
    INC MusicOffset_Square1
    LDA (MusicData),y  ; get note and encoded length
    JSR sub_smb2_data3_length_decoder  ; decode it
    STA Squ1_NoteLenCounter  ; save length
    TXA
    AND #$3e
    JSR sub_smb2_data3_set_square_1_frequency  ; play a note on square 1
    BEQ bra_smb2_data3_store_square_1_envelope_state
    LDA #$10  ; set envelope counter and regs for square 1
    LDX #$82
    LDY #$7f
bra_smb2_data3_store_square_1_envelope_state:
    STA Squ1_EnvelopeDataCtrl
    JSR sub_smb2_data3_store_square_1_registers
bra_smb2_data3_update_square_1_music_envelope:
    LDY Squ1_EnvelopeDataCtrl  ; get envelope counter
    BEQ bra_smb2_data3_load_square_1_envelope  ; use to update envelope on square 1
    DEC Squ1_EnvelopeDataCtrl
bra_smb2_data3_load_square_1_envelope:
    LDA off_smb2_data3_victory_music_envelope_data,y
    STA SND_SQUARE1_REG
    LDA #$7f
    STA SND_SQUARE1_REG+1

bra_smb2_data3_handle_triangle_music:
    LDA MusicOffset_Triangle  ; get offset, skip if none was ever loaded
    BEQ bra_smb2_data3_handle_fds_music
    DEC Tri_NoteLenCounter  ; if note length not expired, skip ahead
    BNE bra_smb2_data3_handle_fds_music
    LDY MusicOffset_Triangle
    INC MusicOffset_Triangle  ; get next byte in music data
    LDA (MusicData),y
    BEQ bra_smb2_data3_store_triangle_control_register  ; if zero, skip all this and move on to the FDS channel
    BPL bra_smb2_data3_handle_triangle_note  ; if positive, branch to process note
    JSR sub_smb2_data3_process_length_data  ; otherwise process length
    STA Tri_NoteLenBuffer
    LDY MusicOffset_Triangle
    INC MusicOffset_Triangle  ; get next byte in music data (must not be length byte!)
    LDA (MusicData),y
    BEQ bra_smb2_data3_store_triangle_control_register  ; if zero, skip, as before
bra_smb2_data3_handle_triangle_note:
    JSR sub_smb2_data3_set_triangle_frequency  ; play a note on triangle
    LDX Tri_NoteLenBuffer
    STX Tri_NoteLenCounter  ; save length to counter
    TXA
    CMP #$12  ; if playing a note longer than 12 frames,
    BCS bra_smb2_data3_use_long_triangle_sustain  ; branch to set triangle reg to $ff
    LDA #$18
    BNE bra_smb2_data3_store_triangle_control_register  ; otherwise set triangle reg to $18 for short notes
bra_smb2_data3_use_long_triangle_sustain:
    LDA #$ff
bra_smb2_data3_store_triangle_control_register:
    STA SND_TRIANGLE_REG

bra_smb2_data3_handle_fds_music:
    LDA MusicOffset_FDSSND  ; if no offset loaded, skip to handle noise channel
    BNE bra_smb2_data3_check_for_cutoff
    JMP bra_smb2_data3_handle_noise_music

bra_smb2_data3_check_for_cutoff:
    LDA FDSSND_LenCounter  ; check to see if length at specific point in note
    CMP #$02  ; if not, skip this part
    BNE bra_smb2_data3_run_fds_channel
    LDA #$00  ; otherwise perform note cutoff
    STA FDSSND_VOLUMECTRL
bra_smb2_data3_run_fds_channel:
    DEC FDSSND_LenCounter  ; if length not expired, skip ahead
    BNE bra_smb2_data3_fds_sound_envelope_modulation_run
    LDY MusicOffset_FDSSND
    INC MusicOffset_FDSSND  ; get next byte in music data
    LDA (MusicData),y
    BPL bra_smb2_data3_fds_sound_note_handler  ; if positive, branch to process note
    JSR sub_smb2_data3_process_length_data  ; otherwise process length
    STA FDSSND_LenBuffer
    LDY MusicOffset_FDSSND
    INC MusicOffset_FDSSND  ; get next byte in music data (must not be length byte!)
    LDA (MusicData),y
bra_smb2_data3_fds_sound_note_handler:
    JSR sub_smb2_data3_set_fds_frequency  ; play a note on the FDS channel
    TAY
    BNE bra_smb2_data3_fds_sound_envelope_modulation_start  ; if frequency high was nonzero, branch
    LDX #$80
    STX FDSSND_VOLUMECTRL  ; otherwise play a rest, use zero from frequency low data
    BNE bra_smb2_data3_initial_env_data  ; to be loaded into envelope timer
bra_smb2_data3_fds_sound_envelope_modulation_start:
    JSR sub_smb2_data3_get_modulation_table  ; reload modulation table
    LDY FDSSND_MasterEnvSet
bra_smb2_data3_initial_env_data:
    STY FDSSND_MasterEnvTimer  ; dump value from header data or zero if rest
    LDY #$00  ; as value into the timer
    STY FDSSND_VolumeEnvOffset  ; init envelope and sweep counter offsets
    STY FDSSND_SweepModOffset
    LDA (FDSSND_VolumeEnvData),y  ; get volume and sweep envelope data for the start of the note
    STA FDSSND_VOLUMECTRL
    LDA (FDSSND_SweepModData),y
    STA FDSSND_SWEEPCTRL
    LDA #$00
    STA FDSSND_SWEEPBIAS  ; set no sweep bias
    INY
    LDA (FDSSND_VolumeEnvData),y  ; get timing for volume and sweep envelopes
    STA FDSSND_VolumeEnvTimer
    LDA (FDSSND_SweepModData),y
    STA FDSSND_SweepModTimer
    STY FDSSND_VolumeEnvOffset  ; set current offset
    STY FDSSND_SweepModOffset
    LDA FDSSND_LenBuffer
    STA FDSSND_LenCounter  ; dump length of note
bra_smb2_data3_fds_sound_envelope_modulation_run:
    LDA FDSSND_MasterEnvTimer  ; get master counter, skip over this if at zero
    BEQ bra_smb2_data3_handle_noise_music
    DEC FDSSND_MasterEnvTimer  ; decrement the master counter
    DEC FDSSND_VolumeEnvTimer  ; if envelope counter not expired, branch to skip this
    BNE bra_smb2_data3_sweep_mod_ctrl
bra_smb2_data3_volume_env_ctrl:
    INC FDSSND_VolumeEnvOffset
    LDY FDSSND_VolumeEnvOffset  ; get next byte of data
    LDA (FDSSND_VolumeEnvData),y  ; if positive, write and continue
    BPL bra_smb2_data3_volume_env_timing
    STA FDSSND_VOLUMECTRL  ; otherwise, write and loop to get another byte
    BNE bra_smb2_data3_volume_env_ctrl
bra_smb2_data3_volume_env_timing:
    STA FDSSND_VOLUMECTRL  ; write to control the envelope of FDS channel
    INY
    LDA (FDSSND_VolumeEnvData),y  ; get another byte of data, set counter
    STA FDSSND_VolumeEnvTimer
    STY FDSSND_VolumeEnvOffset  ; save offset for later
bra_smb2_data3_sweep_mod_ctrl:
    DEC FDSSND_SweepModTimer
    BNE bra_smb2_data3_handle_noise_music  ; decrement sweep/modulation counter, skip if not expired
    INC FDSSND_SweepModOffset
    LDY FDSSND_SweepModOffset  ; get some more data
    LDA (FDSSND_SweepModData),y  ; save to sweep control, and mod frequency low and high
    STA FDSSND_SWEEPCTRL
    INY
    LDA (FDSSND_SweepModData),y
    STA FDSSND_MODFREQLOW
    INY
    LDA (FDSSND_SweepModData),y
    STA FDSSND_MODFREQHIGH
    INY
    LDA (FDSSND_SweepModData),y  ; get another byte of data, set counter
    STA FDSSND_SweepModTimer
    STY FDSSND_SweepModOffset  ; save offset for later

bra_smb2_data3_handle_noise_music:
    DEC Noise_BeatLenCounter  ; if length not expired, branch to leave
    BNE bra_smb2_data3_exit_music_handler
bra_smb2_data3_fetch_noise_beat_data:
    LDY MusicOffset_Noise
    INC MusicOffset_Noise  ; get next byte in beat data
    LDA (MusicData),y
    BNE bra_smb2_data3_proc_beat_data  ; if nonzero, branch to process beat data
    LDA NoiseDataLoopbackOfs
    STA MusicOffset_Noise  ; otherwise zero is loop, dump offset to loop
    BNE bra_smb2_data3_fetch_noise_beat_data  ; the pattern and loop back, refetch data
bra_smb2_data3_proc_beat_data:
    JSR sub_smb2_data3_length_decoder  ; decode length and save it
    STA Noise_BeatLenCounter
    TXA
    AND #$3e  ; get beat data
    BEQ bra_smb2_data3_store_noise_beat_registers  ; if none, branch to play silent beat
    LDA #$1c
    LDX #$03  ; otherwise play only one kind of beat
    LDY #$18
bra_smb2_data3_store_noise_beat_registers:
    STA SND_NOISE_REG
    STX SND_NOISE_REG+2  ; dump to noise regs
    STY SND_NOISE_REG+3
bra_smb2_data3_exit_music_handler:
    RTS

sub_smb2_data3_process_waveform_data:
    LDA $01  ; if last value in header was set to zero, leave
    BNE bra_smb2_data3_get_waveform_header  ; otherwise, use to load header for waveform
    RTS  ; and data for the envelope and modulation

bra_smb2_data3_get_waveform_header:
    LDY #$00
bra_smb2_data3_find_header:
    INY
    LSR  ; increment offset for every clear bit in value loaded
    BCC bra_smb2_data3_find_header
    LDA tbl_smb2_data3_waveform_header_offsets-1,y  ; get offset to header
    TAY
    LDA off_smb2_data3_waveform_header_data-2,y
    STA WaveformData  ; get header
    LDA off_smb2_data3_waveform_header_data-1,y
    STA WaveformData+1
    LDA off_smb2_data3_waveform_header_data,y
    STA FDSSND_MasterEnvSet
    LDA off_smb2_data3_waveform_header_data+1,y
    STA FDSSND_VolumeEnvData
    LDA off_smb2_data3_waveform_header_data+2,y
    STA FDSSND_VolumeEnvData+1
    LDA off_smb2_data3_waveform_header_data+3,y
    STA FDSSND_SweepModData
    LDA off_smb2_data3_waveform_header_data+4,y
    STA FDSSND_SweepModData+1
    LDA off_smb2_data3_waveform_header_data+5,y
    STA FDSSND_ModTableNumber
    JSR sub_smb2_data3_get_waveform_data
    LDA #$02  ; set volume, overwriting the setting from sub
    STA FDSSND_WAVEENABLEWR  ; that just got returned from
    RTS

sub_smb2_data3_get_waveform_data:
    LDA #$80  ; enable writes to FDS waveform RAM
    STA FDSSND_WAVEENABLEWR
    LDA #$00  ; init first byte of it
    STA FDSSND_WAVERAM
    LDY #$00
    LDX #$3f
bra_smb2_data3_write_waveform_data_loop:
    LDA (WaveformData),y  ; write each byte of data to the waveform RAM
    STA FDSSND_WAVERAM+1,y  ; both from start to middle and from end to middle
    INY  ; so that the data eventually converge and mirror
    CPY #$20
    BEQ bra_smb2_data3_set_wave_output_volume
    STA FDSSND_WAVERAM,x
    DEX
    BNE bra_smb2_data3_write_waveform_data_loop
bra_smb2_data3_set_wave_output_volume:
    LDA AltMusicBuffer  ; if d6 was clear, branch to lower the volume
    AND #$40  ; otherwise set for full volume
    BEQ bra_smb2_data3_set_low_wave_volume
    LDA #$00  ; this may have been used once for testing but is
    BEQ bra_smb2_data3_set_full_wave_volume  ; irrelevant now because the setting is overwritten
bra_smb2_data3_set_low_wave_volume:
    LDA #$03
bra_smb2_data3_set_full_wave_volume:
    STA FDSSND_WAVEENABLEWR  ; then fall through to next routine

sub_smb2_data3_get_modulation_table:
    LDA #$80  ; disable modulation
    STA FDSSND_MODFREQHIGH
    LDA #$00
    STA FDSSND_SWEEPBIAS  ; set no sweep bias
    LDX #$20
    LDY FDSSND_ModTableNumber  ; get value from header
    STY $02
bra_smb2_data3_write_modulation_table_loop:
    LDA $02  ; divide loaded value by 2, use as counter and offset
    LSR  ; (original value is * 2 because it shifts LSB for odd/even)
    TAY
    LDA tbl_smb2_data3_mod_table_data,y  ; get data, use lower nybble on every odd count
    BCS bra_smb2_data3_write_modulation_table_nibble  ; and the upper nybble on every even count
    LSR
    LSR  ; otherwise shift upper nybble to use it instead
    LSR
    LSR
bra_smb2_data3_write_modulation_table_nibble:
    AND #$0f  ; write to modulation table
    STA FDSSND_MODTBLAPPEND
    INC $02  ; increment loaded value
    DEX
    BNE bra_smb2_data3_write_modulation_table_loop
    RTS

tbl_smb2_data3_mod_table_data:
tbl_smb2_data3_mod_table1:
    .byte $07, $07, $07, $07, $01, $01, $01, $01, $01, $01, $01, $01, $07, $07, $07, $07
tbl_smb2_data3_mod_table2:
    .byte $77, $77, $77, $77, $11, $11, $11, $11, $11, $11, $11, $11, $77, $77, $77, $77

sub_smb2_data3_length_decoder:
    TAX
    ROR
    TXA
    ROL
    ROL
    ROL
sub_smb2_data3_process_length_data:
    AND #$07  ; save 3 LSB, add to header data loaded earlier
    CLC  ; then use as offset to load note length
    ADC NoteLengthTblAdder
    TAY
    LDA tbl_smb2_data3_music_note_lengths,y
    RTS

sub_smb2_data3_store_square_1_registers:
    STY SND_SQUARE1_REG+1  ; set regs for envelope on square 1 channel
    STX SND_SQUARE1_REG
    RTS

    JSR sub_smb2_data3_store_square_1_registers  ; dead code, nothing branches here
sub_smb2_data3_set_square_1_frequency:
    LDX #$00
bra_smb2_data3_store_frequency_registers:
    TAY
    LDA tbl_smb2_main_music_note_periods+1,y
    BEQ bra_smb2_data3_exit_frequency_update
    STA SND_REGISTER+2,x
    LDA tbl_smb2_main_music_note_periods,y
    ORA #$08
    STA SND_REGISTER+3,x
bra_smb2_data3_exit_frequency_update:
    RTS

sub_smb2_data3_store_square_2_registers:
    STX SND_SQUARE2_REG  ; set regs for envelope on square 2 channel
    STY SND_SQUARE2_REG+1
    RTS

    JSR sub_smb2_data3_store_square_2_registers  ; dead code, nothing branches here
sub_smb2_data3_set_square_2_frequency:
    LDX #$04  ; set frequency regs for square 2 channel to play note
    BNE bra_smb2_data3_store_frequency_registers
sub_smb2_data3_set_triangle_frequency:
    LDX #$08  ; if branched here, do that for triangle channel
    BNE bra_smb2_data3_store_frequency_registers
sub_smb2_data3_set_fds_frequency:
    LDX #$80  ; if branched here, start off by silencing the FDS channel
    STX FDSSND_FREQHIGH
    TAY
    LDA tbl_smb2_data3_fds_freq_lookup_tbl,y  ; now set the frequency regs for FDS channel
    STA FDSSND_FREQHIGH
    LDA tbl_smb2_data3_fds_freq_lookup_tbl+1,y
    STA FDSSND_FREQLOW
    RTS

; -------------------------------------------------------------------------------------
