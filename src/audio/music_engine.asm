; --------------------------------

ContinueMusic:
    JMP HandleSquare2Music  ; if we have music, start with square 2 channel

sub_music_handler:
    LDA ram_event_music_queue  ; check event music queue
    BNE LoadEventMusic
    LDA ram_area_music_queue  ; check area music queue
    BNE LoadAreaMusic
    LDA ram_event_music_buffer  ; check both buffers
    ORA ram_area_music_buffer
    BNE ContinueMusic
    RTS  ; no music, then leave

LoadEventMusic:
    STA ram_event_music_buffer  ; copy event music queue contents to buffer
    CMP #con_death_music  ; is it death music?
    BNE NoStopSfx  ; if not, jump elsewhere
    JSR sub_stop_square1_sfx  ; stop sfx in square 1 and 2
    JSR sub_stop_square2_sfx  ; but clear only square 1's sfx buffer
NoStopSfx:
    LDX ram_area_music_buffer
    STX ram_area_music_buffer_alt  ; save current area music buffer to be re-obtained later
    LDY #$00
    STY ram_note_length_tbl_adder  ; default value for additional length byte offset
    STY ram_area_music_buffer  ; clear area music buffer
    CMP #con_time_running_out_music  ; is it time running out music?
    BNE FindEventMusicHeader
    LDX #$08  ; load offset to be added to length byte of header
    STX ram_note_length_tbl_adder
    BNE FindEventMusicHeader  ; unconditional branch

LoadAreaMusic:
    CMP #$04  ; is it underground music?
    BNE NoStop1  ; no, do not stop square 1 sfx
    JSR sub_stop_square1_sfx
NoStop1:
    LDY #$10  ; start counter used only by ground level music
GMLoopB:
    STY ram_ground_music_header_ofs

HandleAreaMusicLoopB:
    LDY #$00  ; clear event music buffer
    STY ram_event_music_buffer
    STA ram_area_music_buffer  ; copy area music queue contents to buffer
    CMP #$01  ; is it ground level music?
    BNE FindAreaMusicHeader
    INC ram_ground_music_header_ofs  ; increment but only if playing ground level music
    LDY ram_ground_music_header_ofs  ; is it time to loopback ground level music?
    CPY #$32
    BNE LoadHeader  ; branch ahead with alternate offset
    LDY #$11
    BNE GMLoopB  ; unconditional branch

FindAreaMusicHeader:
    LDY #$08  ; load Y for offset of area music
    STY ram_music_offset_square2  ; !(WHY?) SND-002 - possibly observable residual store

FindEventMusicHeader:
    INY  ; increment Y pointer based on previously loaded queue contents
    LSR  ; bit shift and increment until we find a set bit for music
    BCC FindEventMusicHeader

LoadHeader:
    LDA con_music_header_offset_table_base,y  ; load offset for header
    TAY
    LDA MusicHeaderData,y  ; now load the header
    STA ram_note_len_lookup_tbl_ofs
    LDA MusicHeaderData+1,y
    STA ram_music_data_low
    LDA MusicHeaderData+2,y
    STA ram_music_data_high
    LDA MusicHeaderData+3,y
    STA ram_music_offset_triangle
    LDA MusicHeaderData+4,y
    STA ram_music_offset_square1
    LDA MusicHeaderData+5,y
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

HandleSquare2Music:
    DEC ram_squ2_note_len_counter  ; decrement square 2 note length
    BNE MiscSqu2MusicTasks  ; is it time for more data?  if not, branch to end tasks
    LDY ram_music_offset_square2  ; increment square 2 music offset and fetch data
    INC ram_music_offset_square2
    LDA (ram_music_data),y
    BEQ EndOfMusicData  ; if zero, the data is a null terminator
    BPL Squ2NoteHandler  ; if non-negative, data is a note
    BNE Squ2LengthHandler  ; otherwise it is length data

EndOfMusicData:
    LDA ram_event_music_buffer  ; check secondary buffer for time running out music
    CMP #con_time_running_out_music
    BNE NotTRO
    LDA ram_area_music_buffer_alt  ; load previously saved contents of primary buffer
    BNE MusicLoopBack  ; and start playing the song again if there is one
NotTRO:
    AND #con_victory_music  ; check for victory music (the only secondary that loops)
    BNE VictoryMLoopBack
    LDA ram_area_music_buffer  ; check primary buffer for any music except pipe intro
    AND #%01011111
    BNE MusicLoopBack  ; if any area music except pipe intro, music loops
    LDA #$00  ; clear primary and secondary buffers and initialize
    STA ram_area_music_buffer  ; control regs of square and triangle channels
    STA ram_event_music_buffer
    STA SND_TRIANGLE_REG
    LDA #$90
    STA SND_SQUARE1_REG
    STA SND_SQUARE2_REG
    RTS

MusicLoopBack:
    JMP HandleAreaMusicLoopB

VictoryMLoopBack:
    JMP LoadEventMusic

Squ2LengthHandler:
    JSR sub_process_length_data  ; store length of note
    STA ram_squ2_note_len_buffer
    LDY ram_music_offset_square2  ; fetch another byte (MUST NOT BE LENGTH BYTE!)
    INC ram_music_offset_square2
    LDA (ram_music_data),y

Squ2NoteHandler:
    LDX ram_square2_sound_buffer  ; is there a sound playing on this channel?
    BNE SkipFqL1
    JSR sub_set_freq_squ2  ; no, then play the note
    BEQ Rest  ; check to see if note is rest
    JSR sub_load_control_regs  ; if not, load control regs for square 2
Rest:
    STA ram_squ2_envelope_data_ctrl  ; save contents of A
    JSR sub_dump_sq2_regs  ; dump X and Y into square 2 control regs
SkipFqL1:
    LDA ram_squ2_note_len_buffer  ; save length in square 2 note counter
    STA ram_squ2_note_len_counter

MiscSqu2MusicTasks:
    LDA ram_square2_sound_buffer  ; is there a sound playing on square 2?
    BNE HandleSquare1Music
    LDA ram_event_music_buffer  ; check for death music or d4 set on secondary buffer
    AND #%10010001  ; note that regs for death music or d4 are loaded by default
    BNE HandleSquare1Music
    LDY ram_squ2_envelope_data_ctrl  ; check for contents saved from sub_load_control_regs
    BEQ NoDecEnv1
    DEC ram_squ2_envelope_data_ctrl  ; decrement unless already zero
NoDecEnv1:
    JSR sub_load_envelope_data  ; do a load of envelope data to replace default
    STA SND_SQUARE2_REG  ; based on offset set by first load unless playing
    LDX #$7f  ; death music or d4 set on secondary buffer
    STX SND_SQUARE2_REG+1

HandleSquare1Music:
    LDY ram_music_offset_square1  ; is there a nonzero offset here?
    BEQ HandleTriangleMusic  ; if not, skip ahead to the triangle channel
    DEC ram_squ1_note_len_counter  ; decrement square 1 note length
    BNE MiscSqu1MusicTasks  ; is it time for more data?

FetchSqu1MusicData:
    LDY ram_music_offset_square1  ; increment square 1 music offset and fetch data
    INC ram_music_offset_square1
    LDA (ram_music_data),y
    BNE Squ1NoteHandler  ; if nonzero, then skip this part
    LDA #$83
    STA SND_SQUARE1_REG  ; store some data into control regs for square 1
    LDA #$94  ; and fetch another byte of data, used to give
    STA SND_SQUARE1_REG+1  ; death music its unique sound
    STA ram_alt_reg_content_flag
    BNE FetchSqu1MusicData  ; unconditional branch

Squ1NoteHandler:
    JSR sub_alternate_length_handler
    STA ram_squ1_note_len_counter  ; save contents of A in square 1 note counter
    LDY ram_square1_sound_buffer  ; is there a sound playing on square 1?
    BNE HandleTriangleMusic
    TXA
    AND #%00111110  ; change saved data to appropriate note format
    JSR sub_set_freq_squ1  ; play the note
    BEQ SkipCtrlL
    JSR sub_load_control_regs
SkipCtrlL:
    STA ram_squ1_envelope_data_ctrl  ; save envelope offset
    JSR sub_dump_squ1_regs

MiscSqu1MusicTasks:
    LDA ram_square1_sound_buffer  ; is there a sound playing on square 1?
    BNE HandleTriangleMusic
    LDA ram_event_music_buffer  ; check for death music or d4 set on secondary buffer
    AND #%10010001
    BNE DeathMAltReg
    LDY ram_squ1_envelope_data_ctrl  ; check saved envelope offset
    BEQ NoDecEnv2
    DEC ram_squ1_envelope_data_ctrl  ; decrement unless already zero
NoDecEnv2:
    JSR sub_load_envelope_data  ; do a load of envelope data
    STA SND_SQUARE1_REG  ; based on offset set by first load
DeathMAltReg:
    LDA ram_alt_reg_content_flag  ; check for alternate control reg data
    BNE DoAltLoad
    LDA #$7f  ; load this value if zero, the alternate value
DoAltLoad:
    STA SND_SQUARE1_REG+1  ; if nonzero, and let's move on

HandleTriangleMusic:
    LDA ram_music_offset_triangle
    DEC ram_tri_note_len_counter  ; decrement triangle note length
    BNE HandleNoiseMusic  ; is it time for more data?
    LDY ram_music_offset_triangle  ; increment square 1 music offset and fetch data
    INC ram_music_offset_triangle
    LDA (ram_music_data),y
    BEQ LoadTriCtrlReg  ; if zero, skip all this and move on to noise
    BPL TriNoteHandler  ; if non-negative, data is note
    JSR sub_process_length_data  ; otherwise, it is length data
    STA ram_tri_note_len_buffer  ; save contents of A
    LDA #$1f
    STA SND_TRIANGLE_REG  ; load some default data for triangle control reg
    LDY ram_music_offset_triangle  ; fetch another byte
    INC ram_music_offset_triangle
    LDA (ram_music_data),y
    BEQ LoadTriCtrlReg  ; check once more for nonzero data

TriNoteHandler:
    JSR sub_set_freq_tri
    LDX ram_tri_note_len_buffer  ; save length in triangle note counter
    STX ram_tri_note_len_counter
    LDA ram_event_music_buffer
    AND #%01101110  ; check for death music or d4 set on secondary buffer
    BNE NotDOrD4  ; if playing any other secondary, skip primary buffer check
    LDA ram_area_music_buffer  ; check primary buffer for water or castle level music
    AND #%00001010
    BEQ HandleNoiseMusic  ; if playing any other primary, or death or d4, go on to noise routine
NotDOrD4:
    TXA  ; if playing water or castle music or any secondary
    CMP #$12  ; besides death music or d4 set, check length of note
    BCS LongN
    LDA ram_event_music_buffer  ; check for win castle music again if not playing a long note
    AND #con_end_of_castle_music
    BEQ MediN
    LDA #$0f  ; load value $0f if playing the win castle music and playing a short
    BNE LoadTriCtrlReg  ; note, load value $1f if playing water or castle level music or any
MediN:
    LDA #$1f  ; secondary besides death and d4 except win castle or win castle and playing
    BNE LoadTriCtrlReg  ; a short note, and load value $ff if playing a long note on water, castle
LongN:
    LDA #$ff  ; or any secondary (including win castle) except death and d4

LoadTriCtrlReg:
    STA SND_TRIANGLE_REG  ; save final contents of A into control reg for triangle

HandleNoiseMusic:
    LDA ram_area_music_buffer  ; check if playing underground or castle music
    AND #%11110011
    BEQ ExitMusicHandler  ; if so, skip the noise routine
    DEC ram_noise_beat_len_counter  ; decrement noise beat length
    BNE ExitMusicHandler  ; is it time for more data?

FetchNoiseBeatData:
    LDY ram_music_offset_noise  ; increment noise beat offset and fetch data
    INC ram_music_offset_noise
    LDA (ram_music_data),y  ; get noise beat data, if nonzero, branch to handle
    BNE NoiseBeatHandler
    LDA ram_noise_data_loopback_ofs  ; if data is zero, reload original noise beat offset
    STA ram_music_offset_noise  ; and loopback next time around
    BNE FetchNoiseBeatData  ; unconditional branch

NoiseBeatHandler:
    JSR sub_alternate_length_handler
    STA ram_noise_beat_len_counter  ; store length in noise beat counter
    TXA
    AND #%00111110  ; reload data and erase length bits
    BEQ SilentBeat  ; if no beat data, silence
    CMP #$30  ; check the beat data and play the appropriate
    BEQ LongBeat  ; noise accordingly
    CMP #$20
    BEQ StrongBeat
    AND #%00010000
    BEQ SilentBeat
    LDA #$1c  ; short beat data
    LDX #$03
    LDY #$18
    BNE PlayBeat

StrongBeat:
    LDA #$1c  ; strong beat data
    LDX #$0c
    LDY #$18
    BNE PlayBeat

LongBeat:
    LDA #$1c  ; long beat data
    LDX #$03
    LDY #$58
    BNE PlayBeat

SilentBeat:
    LDA #$10  ; silence

PlayBeat:
    STA SND_NOISE_REG  ; load beat data into noise regs
    STX SND_NOISE_REG+2
    STY SND_NOISE_REG+3

ExitMusicHandler:
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
    LDA MusicLengthLookupTbl,y  ; load length
    RTS

sub_load_control_regs:
    LDA ram_event_music_buffer  ; check secondary buffer for win castle music
    AND #con_end_of_castle_music
    BEQ NotECstlM
    LDA #$04  ; this value is only used for win castle music
    BNE AllMus  ; unconditional branch
NotECstlM:
    LDA ram_area_music_buffer
    AND #%01111101  ; check primary buffer for water music
    BEQ WaterMus
    LDA #$08  ; this is the default value for all other music
    BNE AllMus
WaterMus:
    LDA #$28  ; this value is used for water music and all other event music
AllMus:
    LDX #$82  ; load contents of other sound regs for square 2
    LDY #$7f
    RTS

sub_load_envelope_data:
    LDA ram_event_music_buffer  ; check secondary buffer for win castle music
    AND #con_end_of_castle_music
    BEQ LoadUsualEnvData
    LDA EndOfCastleMusicEnvData,y  ; load data from offset for win castle music
    RTS

LoadUsualEnvData:
    LDA ram_area_music_buffer  ; check primary buffer for water music
    AND #%01111101
    BEQ LoadWaterEventMusEnvData
    LDA AreaMusicEnvData,y  ; load default data from offset for all other music
    RTS

LoadWaterEventMusEnvData:
    LDA WaterEventMusEnvData,y  ; load data from offset for water music and all other event music
    RTS
