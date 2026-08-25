; --------------------------------

bra_continue_music_playback:
    JMP loc_handle_square_2_music  ; if we have music, start with square 2 channel

sub_music_handler:
    LDA ram_event_music_queue  ; check event music queue
    BNE loc_load_event_music
    LDA ram_area_music_queue  ; check area music queue
    BNE bra_load_area_music
    LDA ram_event_music_buffer  ; check both buffers
    ORA ram_area_music_buffer
    BNE bra_continue_music_playback
    RTS  ; no music, then leave

loc_load_event_music:
    STA ram_event_music_buffer  ; copy event music queue contents to buffer
    CMP #con_death_music  ; is it death music?
    BNE bra_prepare_event_music  ; if not, jump elsewhere
    JSR sub_stop_square_1_sound_effect  ; stop sfx in square 1 and 2
    JSR sub_stop_square_2_sound_effect  ; but clear only square 1's sfx buffer
bra_prepare_event_music:
    LDX ram_area_music_buffer
    STX ram_area_music_buffer_alt  ; save current area music buffer to be re-obtained later
    LDY #$00
    STY ram_note_length_tbl_adder  ; default value for additional length byte offset
    STY ram_area_music_buffer  ; clear area music buffer
    CMP #con_time_running_out_music  ; is it time running out music?
    BNE bra_find_event_music_header
    LDX #$08  ; load offset to be added to length byte of header
    STX ram_note_length_tbl_adder
    BNE bra_find_event_music_header  ; unconditional branch

bra_load_area_music:
    CMP #$04  ; is it underground music?
    BNE bra_prepare_area_music  ; no, do not stop square 1 sfx
    JSR sub_stop_square_1_sound_effect
bra_prepare_area_music:
    LDY #$10  ; start counter used only by ground level music
bra_store_ground_music_header_offset:
    STY ram_ground_music_header_ofs

loc_restart_area_music:
    LDY #$00  ; clear event music buffer
    STY ram_event_music_buffer
    STA ram_area_music_buffer  ; copy area music queue contents to buffer
    CMP #$01  ; is it ground level music?
    BNE bra_find_area_music_header
    INC ram_ground_music_header_ofs  ; increment but only if playing ground level music
    LDY ram_ground_music_header_ofs  ; is it time to loopback ground level music?
    CPY #$32
    BNE bra_load_music_header  ; branch ahead with alternate offset
    LDY #$11
    BNE bra_store_ground_music_header_offset  ; unconditional branch

bra_find_area_music_header:
    LDY #$08  ; load Y for offset of area music
    STY ram_music_offset_square2  ; !(WHY?) SND-002 - possibly observable residual store

bra_find_event_music_header:
    INY  ; increment Y pointer based on previously loaded queue contents
    LSR  ; bit shift and increment until we find a set bit for music
    BCC bra_find_event_music_header

bra_load_music_header:
    LDA con_music_header_offset_table_base,y  ; load offset for header
    TAY
    LDA tbl_music_header_offsets,y  ; now load the header
    STA ram_note_len_lookup_tbl_ofs
    LDA tbl_music_header_offsets+1,y
    STA ram_music_data_low
    LDA tbl_music_header_offsets+2,y
    STA ram_music_data_high
    LDA tbl_music_header_offsets+3,y
    STA ram_music_offset_triangle
    LDA tbl_music_header_offsets+4,y
    STA ram_music_offset_square1
    LDA tbl_music_header_offsets+5,y
    STA ram_music_offset_noise
    STA ram_noise_data_loopback_ofs
    LDA #$01  ; initialize music note counters
    STA ram_squ2_note_len_counter
    STA ram_squ1_note_len_counter
    STA ram_tri_note_len_counter
    STA ram_noise_beat_len_counter
    LDA #$00  ; initialize music data offset for square 2
    STA ram_music_offset_square2
    STA ram_alt_reg_content_flag  ; initialize alternate control reg data used by square 1
    LDA #$0b  ; disable triangle channel and reenable it
    STA SND_MASTERCTRL_REG
    LDA #$0f
    STA SND_MASTERCTRL_REG

loc_handle_square_2_music:
    DEC ram_squ2_note_len_counter  ; decrement square 2 note length
    BNE bra_update_square_2_music_envelope  ; is it time for more data?  if not, branch to end tasks
    LDY ram_music_offset_square2  ; increment square 2 music offset and fetch data
    INC ram_music_offset_square2
    LDA (ram_music_data),y
    BEQ bra_handle_end_of_music_data  ; if zero, the data is a null terminator
    BPL bra_handle_square_2_note  ; if non-negative, data is a note
    BNE bra_handle_square_2_length  ; otherwise it is length data

bra_handle_end_of_music_data:
    LDA ram_event_music_buffer  ; check secondary buffer for time running out music
    CMP #con_time_running_out_music
    BNE bra_handle_regular_music_end
    LDA ram_area_music_buffer_alt  ; load previously saved contents of primary buffer
    BNE bra_restart_area_music  ; and start playing the song again if there is one
bra_handle_regular_music_end:
    AND #con_victory_music  ; check for victory music (the only secondary that loops)
    BNE bra_restart_victory_music
    LDA ram_area_music_buffer  ; check primary buffer for any music except pipe intro
    AND #%01011111
    BNE bra_restart_area_music  ; if any area music except pipe intro, music loops
    LDA #$00  ; clear primary and secondary buffers and initialize
    STA ram_area_music_buffer  ; control regs of square and triangle channels
    STA ram_event_music_buffer
    STA SND_TRIANGLE_REG
    LDA #$90
    STA SND_SQUARE1_REG
    STA SND_SQUARE2_REG
    RTS

bra_restart_area_music:
    JMP loc_restart_area_music

bra_restart_victory_music:
    JMP loc_load_event_music

bra_handle_square_2_length:
    JSR sub_process_length_data  ; store length of note
    STA ram_squ2_note_len_buffer
    LDY ram_music_offset_square2  ; fetch another byte (MUST NOT BE LENGTH BYTE!)
    INC ram_music_offset_square2
    LDA (ram_music_data),y

bra_handle_square_2_note:
    LDX ram_square2_sound_buffer  ; is there a sound playing on this channel?
    BNE bra_reload_square_2_note_counter
    JSR sub_set_square_2_frequency  ; no, then play the note
    BEQ bra_store_square_2_envelope_state  ; check to see if note is rest
    JSR sub_load_control_regs  ; if not, load control regs for square 2
bra_store_square_2_envelope_state:
    STA ram_squ2_envelope_data_ctrl  ; save contents of A
    JSR sub_store_square_2_registers  ; dump X and Y into square 2 control regs
bra_reload_square_2_note_counter:
    LDA ram_squ2_note_len_buffer  ; save length in square 2 note counter
    STA ram_squ2_note_len_counter

bra_update_square_2_music_envelope:
    LDA ram_square2_sound_buffer  ; is there a sound playing on square 2?
    BNE bra_handle_square_1_music
    LDA ram_event_music_buffer  ; check for death music or d4 set on secondary buffer
    AND #%10010001  ; note that regs for death music or d4 are loaded by default
    BNE bra_handle_square_1_music
    LDY ram_squ2_envelope_data_ctrl  ; check for contents saved from sub_load_control_regs
    BEQ bra_load_square_2_envelope
    DEC ram_squ2_envelope_data_ctrl  ; decrement unless already zero
bra_load_square_2_envelope:
    JSR sub_load_envelope_data  ; do a load of envelope data to replace default
    STA SND_SQUARE2_REG  ; based on offset set by first load unless playing
    LDX #$7f  ; death music or d4 set on secondary buffer
    STX SND_SQUARE2_REG+1

bra_handle_square_1_music:
    LDY ram_music_offset_square1  ; is there a nonzero offset here?
    BEQ bra_handle_triangle_music  ; if not, skip ahead to the triangle channel
    DEC ram_squ1_note_len_counter  ; decrement square 1 note length
    BNE bra_update_square_1_music_envelope  ; is it time for more data?

bra_fetch_square_1_music_data:
    LDY ram_music_offset_square1  ; increment square 1 music offset and fetch data
    INC ram_music_offset_square1
    LDA (ram_music_data),y
    BNE bra_handle_square_1_note  ; if nonzero, then skip this part
    LDA #$83
    STA SND_SQUARE1_REG  ; store some data into control regs for square 1
    LDA #$94  ; and fetch another byte of data, used to give
    STA SND_SQUARE1_REG+1  ; death music its unique sound
    STA ram_alt_reg_content_flag
    BNE bra_fetch_square_1_music_data  ; unconditional branch

bra_handle_square_1_note:
    JSR sub_alternate_length_handler
    STA ram_squ1_note_len_counter  ; save contents of A in square 1 note counter
    LDY ram_square1_sound_buffer  ; is there a sound playing on square 1?
    BNE bra_handle_triangle_music
    TXA
    AND #%00111110  ; change saved data to appropriate note format
    JSR sub_set_square_1_frequency  ; play the note
    BEQ bra_store_square_1_envelope_state
    JSR sub_load_control_regs
bra_store_square_1_envelope_state:
    STA ram_squ1_envelope_data_ctrl  ; save envelope offset
    JSR sub_store_square_1_registers

bra_update_square_1_music_envelope:
    LDA ram_square1_sound_buffer  ; is there a sound playing on square 1?
    BNE bra_handle_triangle_music
    LDA ram_event_music_buffer  ; check for death music or d4 set on secondary buffer
    AND #%10010001
    BNE bra_load_square_1_sweep_register
    LDY ram_squ1_envelope_data_ctrl  ; check saved envelope offset
    BEQ bra_load_square_1_envelope
    DEC ram_squ1_envelope_data_ctrl  ; decrement unless already zero
bra_load_square_1_envelope:
    JSR sub_load_envelope_data  ; do a load of envelope data
    STA SND_SQUARE1_REG  ; based on offset set by first load
bra_load_square_1_sweep_register:
    LDA ram_alt_reg_content_flag  ; check for alternate control reg data
    BNE bra_store_square_1_sweep_register
    LDA #$7f  ; load this value if zero, the alternate value
bra_store_square_1_sweep_register:
    STA SND_SQUARE1_REG+1  ; if nonzero, and let's move on

bra_handle_triangle_music:
    LDA ram_music_offset_triangle
    DEC ram_tri_note_len_counter  ; decrement triangle note length
    BNE bra_handle_noise_music  ; is it time for more data?
    LDY ram_music_offset_triangle  ; increment square 1 music offset and fetch data
    INC ram_music_offset_triangle
    LDA (ram_music_data),y
    BEQ bra_store_triangle_control_register  ; if zero, skip all this and move on to noise
    BPL bra_handle_triangle_note  ; if non-negative, data is note
    JSR sub_process_length_data  ; otherwise, it is length data
    STA ram_tri_note_len_buffer  ; save contents of A
    LDA #$1f
    STA SND_TRIANGLE_REG  ; load some default data for triangle control reg
    LDY ram_music_offset_triangle  ; fetch another byte
    INC ram_music_offset_triangle
    LDA (ram_music_data),y
    BEQ bra_store_triangle_control_register  ; check once more for nonzero data

bra_handle_triangle_note:
    JSR sub_set_triangle_frequency
    LDX ram_tri_note_len_buffer  ; save length in triangle note counter
    STX ram_tri_note_len_counter
    LDA ram_event_music_buffer
    AND #%01101110  ; check for death music or d4 set on secondary buffer
    BNE bra_select_triangle_note_sustain  ; if playing any other secondary, skip primary buffer check
    LDA ram_area_music_buffer  ; check primary buffer for water or castle level music
    AND #%00001010
    BEQ bra_handle_noise_music  ; if playing any other primary, or death or d4, go on to noise routine
bra_select_triangle_note_sustain:
    TXA  ; if playing water or castle music or any secondary
    CMP #$12  ; besides death music or d4 set, check length of note
    BCS bra_use_long_triangle_sustain
    LDA ram_event_music_buffer  ; check for win castle music again if not playing a long note
    AND #con_end_of_castle_music
    BEQ bra_use_medium_triangle_sustain
    LDA #$0f  ; load value $0f if playing the win castle music and playing a short
    BNE bra_store_triangle_control_register  ; note, load value $1f if playing water or castle level music or any
bra_use_medium_triangle_sustain:
    LDA #$1f  ; secondary besides death and d4 except win castle or win castle and playing
    BNE bra_store_triangle_control_register  ; a short note, and load value $ff if playing a long note on water, castle
bra_use_long_triangle_sustain:
    LDA #$ff  ; or any secondary (including win castle) except death and d4

bra_store_triangle_control_register:
    STA SND_TRIANGLE_REG  ; save final contents of A into control reg for triangle

bra_handle_noise_music:
    LDA ram_area_music_buffer  ; check if playing underground or castle music
    AND #%11110011
    BEQ bra_exit_music_handler  ; if so, skip the noise routine
    DEC ram_noise_beat_len_counter  ; decrement noise beat length
    BNE bra_exit_music_handler  ; is it time for more data?

bra_fetch_noise_beat_data:
    LDY ram_music_offset_noise  ; increment noise beat offset and fetch data
    INC ram_music_offset_noise
    LDA (ram_music_data),y  ; get noise beat data, if nonzero, branch to handle
    BNE bra_handle_noise_beat
    LDA ram_noise_data_loopback_ofs  ; if data is zero, reload original noise beat offset
    STA ram_music_offset_noise  ; and loopback next time around
    BNE bra_fetch_noise_beat_data  ; unconditional branch

bra_handle_noise_beat:
    JSR sub_alternate_length_handler
    STA ram_noise_beat_len_counter  ; store length in noise beat counter
    TXA
    AND #%00111110  ; reload data and erase length bits
    BEQ bra_silence_noise_beat  ; if no beat data, silence
    CMP #$30  ; check the beat data and play the appropriate
    BEQ bra_play_long_noise_beat  ; noise accordingly
    CMP #$20
    BEQ bra_play_strong_noise_beat
    AND #%00010000
    BEQ bra_silence_noise_beat
    LDA #$1c  ; short beat data
    LDX #$03
    LDY #$18
    BNE bra_store_noise_beat_registers

bra_play_strong_noise_beat:
    LDA #$1c  ; strong beat data
    LDX #$0c
    LDY #$18
    BNE bra_store_noise_beat_registers

bra_play_long_noise_beat:
    LDA #$1c  ; long beat data
    LDX #$03
    LDY #$58
    BNE bra_store_noise_beat_registers

bra_silence_noise_beat:
    LDA #$10  ; silence

bra_store_noise_beat_registers:
    STA SND_NOISE_REG  ; load beat data into noise regs
    STX SND_NOISE_REG+2
    STY SND_NOISE_REG+3

bra_exit_music_handler:
    RTS

sub_alternate_length_handler:
    TAX  ; save a copy of original byte into X
    ROR  ; save LSB from original byte into carry
    TXA  ; reload original byte and rotate three times
    ROL  ; turning xx00000x into 00000xxx, with the
    ROL  ; bit in carry as the MSB here
    ROL

sub_process_length_data:
    AND #%00000111  ; clear all but the three LSBs
    CLC
    ADC $f0  ; add offset loaded from first header byte
    ADC ram_note_length_tbl_adder  ; add extra if time running out music
    TAY
    LDA tbl_music_note_lengths,y  ; load length
    RTS

sub_load_control_regs:
    LDA ram_event_music_buffer  ; check secondary buffer for win castle music
    AND #con_end_of_castle_music
    BEQ bra_select_regular_music_control
    LDA #$04  ; this value is only used for win castle music
    BNE bra_finish_music_control_registers  ; unconditional branch
bra_select_regular_music_control:
    LDA ram_area_music_buffer
    AND #%01111101  ; check primary buffer for water music
    BEQ bra_select_water_music_control
    LDA #$08  ; this is the default value for all other music
    BNE bra_finish_music_control_registers
bra_select_water_music_control:
    LDA #$28  ; this value is used for water music and all other event music
bra_finish_music_control_registers:
    LDX #$82  ; load contents of other sound regs for square 2
    LDY #$7f
    RTS

sub_load_envelope_data:
    LDA ram_event_music_buffer  ; check secondary buffer for win castle music
    AND #con_end_of_castle_music
    BEQ bra_load_area_music_envelope
    LDA tbl_castle_clear_music_envelope,y  ; load data from offset for win castle music
    RTS

bra_load_area_music_envelope:
    LDA ram_area_music_buffer  ; check primary buffer for water music
    AND #%01111101
    BEQ bra_load_water_or_event_music_envelope
    LDA tbl_area_music_envelope_values,y  ; load default data from offset for all other music
    RTS

bra_load_water_or_event_music_envelope:
    LDA tbl_water_and_event_music_envelope_values,y  ; load data from offset for water music and all other event music
    RTS
