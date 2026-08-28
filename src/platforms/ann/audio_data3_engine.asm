; All Night Nippon alternate APU and FDS music engine

handler_ann_fds_audio_cycle:
    LDA #$ff
    STA APU_FRAME_COUNTER
    LDA #$0f
    STA SND_MASTERCTRL_REG
    JSR sub_handle_square_2_sound_effect
    JSR sub_ann_play_fds_music
    LDA #$00
    STA ram_area_music_queue
    STA ram_square2_sound_queue
    RTS
    JMP handler_ann_fds_pulse_2_music

sub_ann_play_fds_music:
    LDA ram_area_music_queue
    BNE $ccd5
    LDA ram_ann_fds_music_current
    BNE $ccc8
    RTS
    LDY #$00
    STY ram_ann_fds_music_step
    STA ram_ann_fds_music_current

loc_ann_advance_fds_music:
    INC ram_ann_fds_music_step
    LDY ram_ann_fds_music_step
    CPY #$0c
    BNE $ccea
    JMP handler_ann_silence_fds_music
    LDA $cff9, Y
    TAY
    LDA tbl_ann_fds_music_offsets, Y
    STA ram_ann_fds_note_length_offset
    LDA $cffb, Y
    STA ram_ann_fds_track
    LDA $cffc, Y
    STA ram_ann_fds_track + 1
    LDA $cffd, Y
    STA ram_ann_fds_triangle_offset
    LDA $cffe, Y
    STA ram_ann_fds_pulse_1_offset
    LDA $cfff, Y
    STA ram_ann_fds_noise_offset
    STA ram_ann_fds_noise_loop_offset
    LDA $d000, Y
    STA ram_ann_fds_wave_offset
    LDA $d001, Y
    STA ram_ann_fds_wave_id_buffer
    STA zp_ann_fds_wave_id
    JSR sub_ann_prepare_fds_wave
    LDA #$01
    STA ram_ann_fds_pulse_2_note_length
    STA ram_ann_fds_pulse_1_note_length
    STA ram_ann_fds_triangle_note_length
    STA ram_ann_fds_noise_note_length
    STA ram_ann_fds_wave_note_length
    LDA #$00
    STA ram_ann_fds_pulse_2_offset
    LDA #$0b
    STA SND_MASTERCTRL_REG
    LDA #$0f
    STA SND_MASTERCTRL_REG

handler_ann_fds_pulse_2_music:
    DEC ram_ann_fds_pulse_2_note_length
    BNE $cdae
    LDY ram_ann_fds_pulse_2_offset
    INC ram_ann_fds_pulse_2_offset
    LDA (ram_ann_fds_track), Y
    BEQ $cd57
    BPL $cd93
    BNE $cd85
    LDA ram_ann_fds_music_current
    BNE $cd82

handler_ann_silence_fds_music:
    LDA #$00
    STA ram_ann_fds_music_current
    STA SND_TRIANGLE_REG
    STA ram_ann_fds_track + 1
    STA ram_ann_fds_track
    STA ram_ann_fds_pulse_2_offset
    STA ram_ann_fds_pulse_1_offset
    STA ram_ann_fds_triangle_offset
    STA ram_ann_fds_noise_offset
    LDA #$90
    STA SND_REGISTER
    STA SND_SQUARE2_REG
    LDA #$80
    STA FDS_SND_VOLUME
    RTS
    JMP loc_ann_advance_fds_music
    JSR sub_ann_load_fds_note_length
    STA ram_ann_fds_pulse_2_note_length_buffer
    LDY ram_ann_fds_pulse_2_offset
    INC ram_ann_fds_pulse_2_offset
    LDA (ram_ann_fds_track), Y
    LDX ram_square2_sound_buffer
    BNE $cda8
    JSR sub_ann_write_fds_pulse_2_note
    BEQ $cda2
    LDA #$10
    LDX #$82
    LDY #$7f
    STA ram_ann_fds_pulse_2_envelope_control
    JSR sub_ann_write_fds_pulse_2_base
    LDA ram_ann_fds_pulse_2_note_length_buffer
    STA ram_ann_fds_pulse_2_note_length
    LDA ram_square2_sound_buffer
    BNE handler_ann_fds_pulse_1_music
    LDY ram_ann_fds_pulse_2_envelope_control
    BEQ $cdba
    DEC ram_ann_fds_pulse_2_envelope_control
    LDA tbl_ann_fds_envelope, Y
    STA SND_SQUARE2_REG

handler_ann_fds_pulse_1_music:
    LDY ram_ann_fds_pulse_1_offset
    BEQ handler_ann_fds_triangle_music
    DEC ram_ann_fds_pulse_1_note_length
    BNE $cdec
    LDY ram_ann_fds_pulse_1_offset
    INC ram_ann_fds_pulse_1_offset
    LDA (ram_ann_fds_track), Y
    JSR sub_ann_decompress_fds_note
    STA ram_ann_fds_pulse_1_note_length
    TXA
    AND #$3e
    JSR sub_ann_write_fds_pulse_1_note
    BEQ $cde6
    LDA #$10
    LDX #$82
    LDY #$7f
    STA ram_ann_fds_pulse_1_envelope_control
    JSR sub_ann_write_fds_pulse_1_base
    LDY ram_ann_fds_pulse_1_envelope_control
    BEQ $cdf4
    DEC ram_ann_fds_pulse_1_envelope_control
    LDA tbl_ann_fds_envelope, Y
    STA SND_REGISTER
    LDA #$7f
    STA SND_SQUARE1_SWEEP

handler_ann_fds_triangle_music:
    LDA ram_ann_fds_triangle_offset
    BEQ handler_ann_fds_wave_music
    DEC ram_ann_fds_triangle_note_length
    BNE handler_ann_fds_wave_music
    LDY ram_ann_fds_triangle_offset
    INC ram_ann_fds_triangle_offset
    LDA (ram_ann_fds_track), Y
    BEQ $ce39
    BPL $ce25
    JSR sub_ann_load_fds_note_length
    STA ram_ann_fds_triangle_note_length_buffer
    LDY ram_ann_fds_triangle_offset
    INC ram_ann_fds_triangle_offset
    LDA (ram_ann_fds_track), Y
    BEQ $ce39
    JSR sub_ann_write_fds_triangle_note
    LDX ram_ann_fds_triangle_note_length_buffer
    STX ram_ann_fds_triangle_note_length
    TXA
    CMP #$12
    BCS $ce37
    LDA #$18
    BNE $ce39
    LDA #$ff
    STA SND_TRIANGLE_REG

handler_ann_fds_wave_music:
    LDA ram_ann_fds_wave_offset
    BNE $ce44
    JMP handler_ann_fds_noise_music
    LDA ram_ann_fds_wave_note_length
    CMP #$02
    BNE $ce50
    LDA #$00
    STA FDS_SND_VOLUME
    DEC ram_ann_fds_wave_note_length
    BNE $ceb1
    LDY ram_ann_fds_wave_offset
    INC ram_ann_fds_wave_offset
    LDA (ram_ann_fds_track), Y
    BPL $ce6d
    JSR sub_ann_load_fds_note_length
    STA ram_ann_fds_wave_note_length_buffer
    LDY ram_ann_fds_wave_offset
    INC ram_ann_fds_wave_offset
    LDA (ram_ann_fds_track), Y
    JSR sub_ann_write_fds_wave_note
    TAY
    BNE $ce7a
    LDX #$80
    STX FDS_SND_VOLUME
    BNE $ce80
    JSR sub_ann_load_fds_modulation
    LDY ram_ann_fds_wave_envelope_start
    STY ram_ann_fds_wave_envelope_control
    LDY #$00
    STY ram_ann_fds_wave_volume_index
    STY ram_ann_fds_wave_mod_index
    LDA (ram_ann_fds_wave_volume_address), Y
    STA FDS_SND_VOLUME
    LDA (ram_ann_fds_wave_mod_address), Y
    STA FDS_SND_MOD_ENVELOPE
    LDA #$00
    STA FDS_SND_MOD_COUNT
    INY
    LDA (ram_ann_fds_wave_volume_address), Y
    STA ram_ann_fds_wave_volume_length
    LDA (ram_ann_fds_wave_mod_address), Y
    STA ram_ann_fds_wave_mod_length
    STY ram_ann_fds_wave_volume_index
    STY ram_ann_fds_wave_mod_index
    LDA ram_ann_fds_wave_note_length_buffer
    STA ram_ann_fds_wave_note_length
    LDA ram_ann_fds_wave_envelope_control
    BEQ handler_ann_fds_noise_music
    DEC ram_ann_fds_wave_envelope_control
    DEC ram_ann_fds_wave_volume_length
    BNE $ced9
    INC ram_ann_fds_wave_volume_index
    LDY ram_ann_fds_wave_volume_index
    LDA (ram_ann_fds_wave_volume_address), Y
    BPL $cecd
    STA FDS_SND_VOLUME
    BNE $cebe
    STA FDS_SND_VOLUME
    INY
    LDA (ram_ann_fds_wave_volume_address), Y
    STA ram_ann_fds_wave_volume_length
    STY ram_ann_fds_wave_volume_index
    DEC ram_ann_fds_wave_mod_length
    BNE handler_ann_fds_noise_music
    INC ram_ann_fds_wave_mod_index
    LDY ram_ann_fds_wave_mod_index
    LDA (ram_ann_fds_wave_mod_address), Y
    STA FDS_SND_MOD_ENVELOPE
    INY
    LDA (ram_ann_fds_wave_mod_address), Y
    STA FDS_SND_MOD_FREQ_LO
    INY
    LDA (ram_ann_fds_wave_mod_address), Y
    STA FDS_SND_MOD_FREQ_HI
    INY
    LDA (ram_ann_fds_wave_mod_address), Y
    STA ram_ann_fds_wave_mod_length
    STY ram_ann_fds_wave_mod_index

handler_ann_fds_noise_music:
    DEC ram_ann_fds_noise_note_length
    BNE $cf2f
    LDY ram_ann_fds_noise_offset
    INC ram_ann_fds_noise_offset
    LDA (ram_ann_fds_track), Y
    BNE $cf15
    LDA ram_ann_fds_noise_loop_offset
    STA ram_ann_fds_noise_offset
    BNE $cf03
    JSR sub_ann_decompress_fds_note
    STA ram_ann_fds_noise_note_length
    TXA
    AND #$3e
    BEQ $cf26
    LDA #$1c
    LDX #$03
    LDY #$18
    STA SND_NOISE_REG
    STX SND_NOISE_PERIOD
    STY SND_NOISE_LENGTH
    RTS
