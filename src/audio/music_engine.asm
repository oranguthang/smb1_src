; --------------------------------

ContinueMusic:
    JMP HandleSquare2Music  ; if we have music, start with square 2 channel

MusicHandler:
    LDA EventMusicQueue  ; check event music queue
    BNE LoadEventMusic
    LDA AreaMusicQueue  ; check area music queue
    BNE LoadAreaMusic
    LDA EventMusicBuffer  ; check both buffers
    ORA AreaMusicBuffer
    BNE ContinueMusic
    RTS  ; no music, then leave

LoadEventMusic:
    STA EventMusicBuffer  ; copy event music queue contents to buffer
    CMP #DeathMusic  ; is it death music?
    BNE NoStopSfx  ; if not, jump elsewhere
    JSR StopSquare1Sfx  ; stop sfx in square 1 and 2
    JSR StopSquare2Sfx  ; but clear only square 1's sfx buffer
NoStopSfx:
    LDX AreaMusicBuffer
    STX AreaMusicBuffer_Alt  ; save current area music buffer to be re-obtained later
    LDY #$00
    STY NoteLengthTblAdder  ; default value for additional length byte offset
    STY AreaMusicBuffer  ; clear area music buffer
    CMP #TimeRunningOutMusic  ; is it time running out music?
    BNE FindEventMusicHeader
    LDX #$08  ; load offset to be added to length byte of header
    STX NoteLengthTblAdder
    BNE FindEventMusicHeader  ; unconditional branch

LoadAreaMusic:
    CMP #$04  ; is it underground music?
    BNE NoStop1  ; no, do not stop square 1 sfx
    JSR StopSquare1Sfx
NoStop1:
    LDY #$10  ; start counter used only by ground level music
GMLoopB:
    STY GroundMusicHeaderOfs

HandleAreaMusicLoopB:
    LDY #$00  ; clear event music buffer
    STY EventMusicBuffer
    STA AreaMusicBuffer  ; copy area music queue contents to buffer
    CMP #$01  ; is it ground level music?
    BNE FindAreaMusicHeader
    INC GroundMusicHeaderOfs  ; increment but only if playing ground level music
    LDY GroundMusicHeaderOfs  ; is it time to loopback ground level music?
    CPY #$32
    BNE LoadHeader  ; branch ahead with alternate offset
    LDY #$11
    BNE GMLoopB  ; unconditional branch

FindAreaMusicHeader:
    LDY #$08  ; load Y for offset of area music
    STY MusicOffset_Square2  ; residual instruction here

FindEventMusicHeader:
    INY  ; increment Y pointer based on previously loaded queue contents
    LSR  ; bit shift and increment until we find a set bit for music
    BCC FindEventMusicHeader

LoadHeader:
    LDA MusicHeaderOffsetData,y  ; load offset for header
    TAY
    LDA MusicHeaderData,y  ; now load the header
    STA NoteLenLookupTblOfs
    LDA MusicHeaderData+1,y
    STA MusicDataLow
    LDA MusicHeaderData+2,y
    STA MusicDataHigh
    LDA MusicHeaderData+3,y
    STA MusicOffset_Triangle
    LDA MusicHeaderData+4,y
    STA MusicOffset_Square1
    LDA MusicHeaderData+5,y
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

HandleSquare2Music:
    DEC Squ2_NoteLenCounter  ; decrement square 2 note length
    BNE MiscSqu2MusicTasks  ; is it time for more data?  if not, branch to end tasks
    LDY MusicOffset_Square2  ; increment square 2 music offset and fetch data
    INC MusicOffset_Square2
    LDA (MusicData),y
    BEQ EndOfMusicData  ; if zero, the data is a null terminator
    BPL Squ2NoteHandler  ; if non-negative, data is a note
    BNE Squ2LengthHandler  ; otherwise it is length data

EndOfMusicData:
    LDA EventMusicBuffer  ; check secondary buffer for time running out music
    CMP #TimeRunningOutMusic
    BNE NotTRO
    LDA AreaMusicBuffer_Alt  ; load previously saved contents of primary buffer
    BNE MusicLoopBack  ; and start playing the song again if there is one
NotTRO:
    AND #VictoryMusic  ; check for victory music (the only secondary that loops)
    BNE VictoryMLoopBack
    LDA AreaMusicBuffer  ; check primary buffer for any music except pipe intro
    AND #%01011111
    BNE MusicLoopBack  ; if any area music except pipe intro, music loops
    LDA #$00  ; clear primary and secondary buffers and initialize
    STA AreaMusicBuffer  ; control regs of square and triangle channels
    STA EventMusicBuffer
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
    JSR ProcessLengthData  ; store length of note
    STA Squ2_NoteLenBuffer
    LDY MusicOffset_Square2  ; fetch another byte (MUST NOT BE LENGTH BYTE!)
    INC MusicOffset_Square2
    LDA (MusicData),y

Squ2NoteHandler:
    LDX Square2SoundBuffer  ; is there a sound playing on this channel?
    BNE SkipFqL1
    JSR SetFreq_Squ2  ; no, then play the note
    BEQ Rest  ; check to see if note is rest
    JSR LoadControlRegs  ; if not, load control regs for square 2
Rest:
    STA Squ2_EnvelopeDataCtrl  ; save contents of A
    JSR Dump_Sq2_Regs  ; dump X and Y into square 2 control regs
SkipFqL1:
    LDA Squ2_NoteLenBuffer  ; save length in square 2 note counter
    STA Squ2_NoteLenCounter

MiscSqu2MusicTasks:
    LDA Square2SoundBuffer  ; is there a sound playing on square 2?
    BNE HandleSquare1Music
    LDA EventMusicBuffer  ; check for death music or d4 set on secondary buffer
    AND #%10010001  ; note that regs for death music or d4 are loaded by default
    BNE HandleSquare1Music
    LDY Squ2_EnvelopeDataCtrl  ; check for contents saved from LoadControlRegs
    BEQ NoDecEnv1
    DEC Squ2_EnvelopeDataCtrl  ; decrement unless already zero
NoDecEnv1:
    JSR LoadEnvelopeData  ; do a load of envelope data to replace default
    STA SND_SQUARE2_REG  ; based on offset set by first load unless playing
    LDX #$7f  ; death music or d4 set on secondary buffer
    STX SND_SQUARE2_REG+1

HandleSquare1Music:
    LDY MusicOffset_Square1  ; is there a nonzero offset here?
    BEQ HandleTriangleMusic  ; if not, skip ahead to the triangle channel
    DEC Squ1_NoteLenCounter  ; decrement square 1 note length
    BNE MiscSqu1MusicTasks  ; is it time for more data?

FetchSqu1MusicData:
    LDY MusicOffset_Square1  ; increment square 1 music offset and fetch data
    INC MusicOffset_Square1
    LDA (MusicData),y
    BNE Squ1NoteHandler  ; if nonzero, then skip this part
    LDA #$83
    STA SND_SQUARE1_REG  ; store some data into control regs for square 1
    LDA #$94  ; and fetch another byte of data, used to give
    STA SND_SQUARE1_REG+1  ; death music its unique sound
    STA AltRegContentFlag
    BNE FetchSqu1MusicData  ; unconditional branch

Squ1NoteHandler:
    JSR AlternateLengthHandler
    STA Squ1_NoteLenCounter  ; save contents of A in square 1 note counter
    LDY Square1SoundBuffer  ; is there a sound playing on square 1?
    BNE HandleTriangleMusic
    TXA
    AND #%00111110  ; change saved data to appropriate note format
    JSR SetFreq_Squ1  ; play the note
    BEQ SkipCtrlL
    JSR LoadControlRegs
SkipCtrlL:
    STA Squ1_EnvelopeDataCtrl  ; save envelope offset
    JSR Dump_Squ1_Regs

MiscSqu1MusicTasks:
    LDA Square1SoundBuffer  ; is there a sound playing on square 1?
    BNE HandleTriangleMusic
    LDA EventMusicBuffer  ; check for death music or d4 set on secondary buffer
    AND #%10010001
    BNE DeathMAltReg
    LDY Squ1_EnvelopeDataCtrl  ; check saved envelope offset
    BEQ NoDecEnv2
    DEC Squ1_EnvelopeDataCtrl  ; decrement unless already zero
NoDecEnv2:
    JSR LoadEnvelopeData  ; do a load of envelope data
    STA SND_SQUARE1_REG  ; based on offset set by first load
DeathMAltReg:
    LDA AltRegContentFlag  ; check for alternate control reg data
    BNE DoAltLoad
    LDA #$7f  ; load this value if zero, the alternate value
DoAltLoad:
    STA SND_SQUARE1_REG+1  ; if nonzero, and let's move on

HandleTriangleMusic:
    LDA MusicOffset_Triangle
    DEC Tri_NoteLenCounter  ; decrement triangle note length
    BNE HandleNoiseMusic  ; is it time for more data?
    LDY MusicOffset_Triangle  ; increment square 1 music offset and fetch data
    INC MusicOffset_Triangle
    LDA (MusicData),y
    BEQ LoadTriCtrlReg  ; if zero, skip all this and move on to noise
    BPL TriNoteHandler  ; if non-negative, data is note
    JSR ProcessLengthData  ; otherwise, it is length data
    STA Tri_NoteLenBuffer  ; save contents of A
    LDA #$1f
    STA SND_TRIANGLE_REG  ; load some default data for triangle control reg
    LDY MusicOffset_Triangle  ; fetch another byte
    INC MusicOffset_Triangle
    LDA (MusicData),y
    BEQ LoadTriCtrlReg  ; check once more for nonzero data

TriNoteHandler:
    JSR SetFreq_Tri
    LDX Tri_NoteLenBuffer  ; save length in triangle note counter
    STX Tri_NoteLenCounter
    LDA EventMusicBuffer
    AND #%01101110  ; check for death music or d4 set on secondary buffer
    BNE NotDOrD4  ; if playing any other secondary, skip primary buffer check
    LDA AreaMusicBuffer  ; check primary buffer for water or castle level music
    AND #%00001010
    BEQ HandleNoiseMusic  ; if playing any other primary, or death or d4, go on to noise routine
NotDOrD4:
    TXA  ; if playing water or castle music or any secondary
    CMP #$12  ; besides death music or d4 set, check length of note
    BCS LongN
    LDA EventMusicBuffer  ; check for win castle music again if not playing a long note
    AND #EndOfCastleMusic
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
    LDA AreaMusicBuffer  ; check if playing underground or castle music
    AND #%11110011
    BEQ ExitMusicHandler  ; if so, skip the noise routine
    DEC Noise_BeatLenCounter  ; decrement noise beat length
    BNE ExitMusicHandler  ; is it time for more data?

FetchNoiseBeatData:
    LDY MusicOffset_Noise  ; increment noise beat offset and fetch data
    INC MusicOffset_Noise
    LDA (MusicData),y  ; get noise beat data, if nonzero, branch to handle
    BNE NoiseBeatHandler
    LDA NoiseDataLoopbackOfs  ; if data is zero, reload original noise beat offset
    STA MusicOffset_Noise  ; and loopback next time around
    BNE FetchNoiseBeatData  ; unconditional branch

NoiseBeatHandler:
    JSR AlternateLengthHandler
    STA Noise_BeatLenCounter  ; store length in noise beat counter
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

AlternateLengthHandler:
    TAX  ; save a copy of original byte into X
    ROR  ; save LSB from original byte into carry
    TXA  ; reload original byte and rotate three times
    ROL  ; turning xx00000x into 00000xxx, with the
    ROL  ; bit in carry as the MSB here
    ROL

ProcessLengthData:
    AND #%00000111  ; clear all but the three LSBs
    CLC
    ADC $f0  ; add offset loaded from first header byte
    ADC NoteLengthTblAdder  ; add extra if time running out music
    TAY
    LDA MusicLengthLookupTbl,y  ; load length
    RTS

LoadControlRegs:
    LDA EventMusicBuffer  ; check secondary buffer for win castle music
    AND #EndOfCastleMusic
    BEQ NotECstlM
    LDA #$04  ; this value is only used for win castle music
    BNE AllMus  ; unconditional branch
NotECstlM:
    LDA AreaMusicBuffer
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

LoadEnvelopeData:
    LDA EventMusicBuffer  ; check secondary buffer for win castle music
    AND #EndOfCastleMusic
    BEQ LoadUsualEnvData
    LDA EndOfCastleMusicEnvData,y  ; load data from offset for win castle music
    RTS

LoadUsualEnvData:
    LDA AreaMusicBuffer  ; check primary buffer for water music
    AND #%01111101
    BEQ LoadWaterEventMusEnvData
    LDA AreaMusicEnvData,y  ; load default data from offset for all other music
    RTS

LoadWaterEventMusEnvData:
    LDA WaterEventMusEnvData,y  ; load data from offset for water music and all other event music
    RTS
