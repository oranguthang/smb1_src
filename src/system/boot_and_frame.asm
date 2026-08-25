; -------------------------------------------------------------------------------------

Start:
    SEI  ; pretty standard 6502 type init here
    CLD
    LDA #%00010000  ; init PPU control register 1
    STA PPU_CTRL_REG1
    LDX #$ff  ; reset stack pointer
    TXS
VBlank1:
    LDA PPU_STATUS  ; wait two frames
    BPL VBlank1
VBlank2:
    LDA PPU_STATUS
    BPL VBlank2
    LDY #ColdBootOffset  ; load default cold boot pointer
    LDX #$05  ; this is where we check for a warm boot
WBootCheck:
    LDA TopScoreDisplay,x  ; check each score digit in the top score
    CMP #10  ; to see if we have a valid digit
    BCS ColdBoot  ; if not, give up and proceed with cold boot
    DEX
    BPL WBootCheck
    LDA WarmBootValidation  ; second checkpoint, check to see if
    CMP #$a5  ; another location has a specific value
    BNE ColdBoot
    LDY #WarmBootOffset  ; if passed both, load warm boot pointer
ColdBoot:
    JSR InitializeMemory  ; clear memory using pointer in Y
    STA SND_DELTA_REG+1  ; reset delta counter load register
    STA OperMode  ; reset primary mode of operation
    LDA #$a5  ; set warm boot flag
    STA WarmBootValidation
    STA PseudoRandomBitReg  ; set seed for pseudorandom register
    LDA #%00001111
    STA SND_MASTERCTRL_REG  ; enable all sound channels except dmc
    LDA #%00000110
    STA PPU_CTRL_REG2  ; turn off clipping for OAM and background
    JSR MoveAllSpritesOffscreen
    JSR InitializeNameTables  ; initialize both name tables
    INC DisableScreenFlag  ; set flag to disable screen output
    LDA Mirror_PPU_CTRL_REG1
    ORA #%10000000  ; enable NMIs
    JSR WritePPUReg1
EndlessLoop:
    JMP EndlessLoop  ; endless loop, need I say more?

; -------------------------------------------------------------------------------------
; $00 - vram buffer address table low, also used for pseudorandom bit
; $01 - vram buffer address table high

VRAM_AddrTable_Low:
    .byte <VRAM_Buffer1, <WaterPaletteData, <GroundPaletteData
    .byte <UndergroundPaletteData, <CastlePaletteData, <VRAM_Buffer1_Offset
    .byte <VRAM_Buffer2, <VRAM_Buffer2, <BowserPaletteData
    .byte <DaySnowPaletteData, <NightSnowPaletteData, <MushroomPaletteData
    .byte <MarioThanksMessage, <LuigiThanksMessage, <MushroomRetainerSaved
    .byte <PrincessSaved1, <PrincessSaved2, <WorldSelectMessage1
    .byte <WorldSelectMessage2

VRAM_AddrTable_High:
    .byte >VRAM_Buffer1, >WaterPaletteData, >GroundPaletteData
    .byte >UndergroundPaletteData, >CastlePaletteData, >VRAM_Buffer1_Offset
    .byte >VRAM_Buffer2, >VRAM_Buffer2, >BowserPaletteData
    .byte >DaySnowPaletteData, >NightSnowPaletteData, >MushroomPaletteData
    .byte >MarioThanksMessage, >LuigiThanksMessage, >MushroomRetainerSaved
    .byte >PrincessSaved1, >PrincessSaved2, >WorldSelectMessage1
    .byte >WorldSelectMessage2

VRAM_Buffer_Offset:
    .byte <VRAM_Buffer1_Offset, <VRAM_Buffer2_Offset

NonMaskableInterrupt:
    LDA Mirror_PPU_CTRL_REG1  ; disable NMIs in mirror reg
    AND #%01111111  ; save all other bits
    STA Mirror_PPU_CTRL_REG1
    AND #%01111110  ; alter name table address to be $2800
    STA PPU_CTRL_REG1  ; (essentially $2000) but save other bits
    LDA Mirror_PPU_CTRL_REG2  ; disable OAM and background display by default
    AND #%11100110
    LDY DisableScreenFlag  ; get screen disable flag
    BNE ScreenOff  ; if set, used bits as-is
    LDA Mirror_PPU_CTRL_REG2  ; otherwise reenable bits and save them
    ORA #%00011110
ScreenOff:
    STA Mirror_PPU_CTRL_REG2  ; save bits for later but not in register at the moment
    AND #%11100111  ; disable screen for now
    STA PPU_CTRL_REG2
    LDX PPU_STATUS  ; reset flip-flop and reset scroll registers to zero
    LDA #$00
    JSR InitScroll
    STA PPU_SPR_ADDR  ; reset spr-ram address register
    LDA #$02  ; perform spr-ram DMA access on $0200-$02ff
    STA SPR_DMA
    LDX VRAM_Buffer_AddrCtrl  ; load control for pointer to buffer contents
    LDA VRAM_AddrTable_Low,x  ; set indirect at $00 to pointer
    STA $00
    LDA VRAM_AddrTable_High,x
    STA $01
    JSR UpdateScreen  ; update screen with buffer contents
    LDY #$00
    LDX VRAM_Buffer_AddrCtrl  ; check for usage of $0341
    CPX #$06
    BNE InitBuffer
    INY  ; get offset based on usage
InitBuffer:
    LDX VRAM_Buffer_Offset,y
    LDA #$00  ; clear buffer header at last location
    STA VRAM_Buffer1_Offset,x
    STA VRAM_Buffer1,x
    STA VRAM_Buffer_AddrCtrl  ; reinit address control to $0301
    LDA Mirror_PPU_CTRL_REG2  ; copy mirror of $2001 to register
    STA PPU_CTRL_REG2
    JSR SoundEngine  ; play sound
    JSR ReadJoypads  ; read joypads
    JSR PauseRoutine  ; handle pause
    JSR UpdateTopScore
    LDA GamePauseStatus  ; check for pause status
    LSR
    BCS PauseSkip
    LDA TimerControl  ; if master timer control not set, decrement
    BEQ DecTimers  ; all frame and interval timers
    DEC TimerControl
    BNE NoDecTimers
DecTimers:
    LDX #$14  ; load end offset for end of frame timers
    DEC IntervalTimerControl  ; decrement interval timer control,
    BPL DecTimersLoop  ; if not expired, only frame timers will decrement
    LDA #$14
    STA IntervalTimerControl  ; if control for interval timers expired,
    LDX #$23  ; interval timers will decrement along with frame timers
DecTimersLoop:
    LDA Timers,x  ; check current timer
    BEQ SkipExpTimer  ; if current timer expired, branch to skip,
    DEC Timers,x  ; otherwise decrement the current timer
SkipExpTimer:
    DEX  ; move onto next timer
    BPL DecTimersLoop  ; do this until all timers are dealt with
NoDecTimers:
    INC FrameCounter  ; increment frame counter
PauseSkip:
    LDX #$00
    LDY #$07
    LDA PseudoRandomBitReg  ; get first memory location of LSFR bytes
    AND #%00000010  ; mask out all but d1
    STA $00  ; save here
    LDA PseudoRandomBitReg+1  ; get second memory location
    AND #%00000010  ; mask out all but d1
    EOR $00  ; perform exclusive-OR on d1 from first and second bytes
    CLC  ; if neither or both are set, carry will be clear
    BEQ RotPRandomBit
    SEC  ; if one or the other is set, carry will be set
RotPRandomBit:
    ROR PseudoRandomBitReg,x  ; rotate carry into d7, and rotate last bit into carry
    INX  ; increment to next byte
    DEY  ; decrement for loop
    BNE RotPRandomBit
    LDA Sprite0HitDetectFlag  ; check for flag here
    BEQ SkipSprite0
Sprite0Clr:
    LDA PPU_STATUS  ; wait for sprite 0 flag to clear, which will
    AND #%01000000  ; not happen until vblank has ended
    BNE Sprite0Clr
    LDA GamePauseStatus  ; if in pause mode, do not bother with sprites at all
    LSR
    BCS Sprite0Hit
    JSR MoveSpritesOffscreen
    JSR SpriteShuffler
Sprite0Hit:
    LDA PPU_STATUS  ; do sprite #0 hit detection
    AND #%01000000
    BEQ Sprite0Hit
    LDY #$14  ; small delay, to wait until we hit horizontal blank time
HBlankDelay:
    DEY
    BNE HBlankDelay
SkipSprite0:
    LDA HorizontalScroll  ; set scroll registers from variables
    STA PPU_SCROLL_REG
    LDA VerticalScroll
    STA PPU_SCROLL_REG
    LDA Mirror_PPU_CTRL_REG1  ; load saved mirror of $2000
    PHA
    STA PPU_CTRL_REG1
    LDA GamePauseStatus  ; if in pause mode, do not perform operation mode stuff
    LSR
    BCS SkipMainOper
    JSR OperModeExecutionTree  ; otherwise do one of many, many possible subroutines
SkipMainOper:
    LDA PPU_STATUS  ; reset flip-flop
    PLA
    ORA #%10000000  ; reactivate NMIs
    STA PPU_CTRL_REG1
    RTI  ; we are done until the next frame!

; -------------------------------------------------------------------------------------

PauseRoutine:
    LDA OperMode  ; are we in victory mode?
    CMP #VictoryModeValue  ; if so, go ahead
    BEQ ChkPauseTimer
    CMP #GameModeValue  ; are we in game mode?
    BNE ExitPause  ; if not, leave
    LDA OperMode_Task  ; if we are in game mode, are we running game engine?
    CMP #$03
    BNE ExitPause  ; if not, leave
ChkPauseTimer:
    LDA GamePauseTimer  ; check if pause timer is still counting down
    BEQ ChkStart
    DEC GamePauseTimer  ; if so, decrement and leave
    RTS
ChkStart:
    LDA SavedJoypad1Bits  ; check to see if start is pressed
    AND #Start_Button  ; on controller 1
    BEQ ClrPauseTimer
    LDA GamePauseStatus  ; check to see if timer flag is set
    AND #%10000000  ; and if so, do not reset timer (residual,
    BNE ExitPause  ; joypad reading routine makes this unnecessary)
    LDA #$2b  ; set pause timer
    STA GamePauseTimer
    LDA GamePauseStatus
    TAY
    INY  ; set pause sfx queue for next pause mode
    STY PauseSoundQueue
    EOR #%00000001  ; invert d0 and set d7
    ORA #%10000000
    BNE SetPause  ; unconditional branch
ClrPauseTimer:
    LDA GamePauseStatus  ; clear timer flag if timer is at zero and start button
    AND #%01111111  ; is not pressed
SetPause:
    STA GamePauseStatus
ExitPause:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used for preset value

SpriteShuffler:
    LDY AreaType  ; load level type, likely residual code
    LDA #$28  ; load preset value which will put it at
    STA $00  ; sprite #10
    LDX #$0e  ; start at the end of OAM data offsets
ShuffleLoop:
    LDA SprDataOffset,x  ; check for offset value against
    CMP $00  ; the preset value
    BCC NextSprOffset  ; if less, skip this part
    LDY SprShuffleAmtOffset  ; get current offset to preset value we want to add
    CLC
    ADC SprShuffleAmt,y  ; get shuffle amount, add to current sprite offset
    BCC StrSprOffset  ; if not exceeded $ff, skip second add
    CLC
    ADC $00  ; otherwise add preset value $28 to offset
StrSprOffset:
    STA SprDataOffset,x  ; store new offset here or old one if branched to here
NextSprOffset:
    DEX  ; move backwards to next one
    BPL ShuffleLoop
    LDX SprShuffleAmtOffset  ; load offset
    INX
    CPX #$03  ; check if offset + 1 goes to 3
    BNE SetAmtOffset  ; if offset + 1 not 3, store
    LDX #$00  ; otherwise, init to 0
SetAmtOffset:
    STX SprShuffleAmtOffset
    LDX #$08  ; load offsets for values and storage
    LDY #$02
SetMiscOffset:
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
    BPL SetMiscOffset  ; do this until all misc spr offsets are loaded
    RTS

; -------------------------------------------------------------------------------------

OperModeExecutionTree:
    LDA OperMode  ; this is the heart of the entire program,
    JSR sub_dispatch_inline_handler  ; most of what goes on starts here

    .word TitleScreenMode
    .word GameMode
    .word VictoryMode
    .word GameOverMode

; -------------------------------------------------------------------------------------

MoveAllSpritesOffscreen:
    LDY #$00  ; this routine moves all sprites off the screen
    .byte $2c  ; BIT instruction opcode

MoveSpritesOffscreen:
    LDY #$04  ; this routine moves all but sprite 0
    LDA #$f8  ; off the screen
SprInitLoop:
    STA Sprite_Y_Position,y  ; write 248 into OAM data's Y coordinate
    INY  ; which will move it off the screen
    INY
    INY
    INY
    BNE SprInitLoop
    RTS
