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
    LDY #con_cold_boot_offset  ; load default cold boot pointer
    LDX #$05  ; this is where we check for a warm boot
WBootCheck:
    LDA ram_top_score_display,x  ; check each score digit in the top score
    CMP #10  ; to see if we have a valid digit
    BCS ColdBoot  ; if not, give up and proceed with cold boot
    DEX
    BPL WBootCheck
    LDA ram_warm_boot_validation  ; second checkpoint, check to see if
    CMP #$a5  ; another location has a specific value
    BNE ColdBoot
    LDY #con_warm_boot_offset  ; if passed both, load warm boot pointer
ColdBoot:
    JSR sub_initialize_memory  ; clear memory using pointer in Y
    STA SND_DELTA_REG+1  ; reset delta counter load register
    STA ram_oper_mode  ; reset primary mode of operation
    LDA #$a5  ; set warm boot flag
    STA ram_warm_boot_validation
    STA ram_pseudo_random_bit_reg  ; set seed for pseudorandom register
    LDA #%00001111
    STA SND_MASTERCTRL_REG  ; enable all sound channels except dmc
    LDA #%00000110
    STA PPU_CTRL_REG2  ; turn off clipping for OAM and background
    JSR sub_move_all_sprites_offscreen
    JSR sub_initialize_name_tables  ; initialize both name tables
    INC ram_disable_screen_flag  ; set flag to disable screen output
    LDA ram_mirror_ppu_ctrl_reg1
    ORA #%10000000  ; enable NMIs
    JSR sub_write_ppu_reg1
EndlessLoop:
    JMP EndlessLoop  ; endless loop, need I say more?

; -------------------------------------------------------------------------------------
; $00 - vram buffer address table low, also used for pseudorandom bit
; $01 - vram buffer address table high

VRAM_AddrTable_Low:
    .byte <ram_vram_buffer1, <WaterPaletteData, <GroundPaletteData
    .byte <UndergroundPaletteData, <CastlePaletteData, <ram_vram_buffer1_offset
    .byte <ram_vram_buffer2, <ram_vram_buffer2, <BowserPaletteData
    .byte <DaySnowPaletteData, <NightSnowPaletteData, <MushroomPaletteData
    .byte <MarioThanksMessage, <LuigiThanksMessage, <MushroomRetainerSaved
    .byte <PrincessSaved1, <PrincessSaved2, <WorldSelectMessage1
    .byte <WorldSelectMessage2

VRAM_AddrTable_High:
    .byte >ram_vram_buffer1, >WaterPaletteData, >GroundPaletteData
    .byte >UndergroundPaletteData, >CastlePaletteData, >ram_vram_buffer1_offset
    .byte >ram_vram_buffer2, >ram_vram_buffer2, >BowserPaletteData
    .byte >DaySnowPaletteData, >NightSnowPaletteData, >MushroomPaletteData
    .byte >MarioThanksMessage, >LuigiThanksMessage, >MushroomRetainerSaved
    .byte >PrincessSaved1, >PrincessSaved2, >WorldSelectMessage1
    .byte >WorldSelectMessage2

VRAM_Buffer_Offset:
    .byte <ram_vram_buffer1_offset, <ram_vram_buffer2_offset

NonMaskableInterrupt:
    LDA ram_mirror_ppu_ctrl_reg1  ; disable NMIs in mirror reg
    AND #%01111111  ; save all other bits
    STA ram_mirror_ppu_ctrl_reg1
    AND #%01111110  ; alter name table address to be $2800
    STA PPU_CTRL_REG1  ; (essentially $2000) but save other bits
    LDA ram_mirror_ppu_ctrl_reg2  ; disable OAM and background display by default
    AND #%11100110
    LDY ram_disable_screen_flag  ; get screen disable flag
    BNE ScreenOff  ; if set, used bits as-is
    LDA ram_mirror_ppu_ctrl_reg2  ; otherwise reenable bits and save them
    ORA #%00011110
ScreenOff:
    STA ram_mirror_ppu_ctrl_reg2  ; save bits for later but not in register at the moment
    AND #%11100111  ; disable screen for now
    STA PPU_CTRL_REG2
    LDX PPU_STATUS  ; reset flip-flop and reset scroll registers to zero
    LDA #$00
    JSR sub_init_scroll
    STA PPU_SPR_ADDR  ; reset spr-ram address register
    LDA #$02  ; perform spr-ram DMA access on $0200-$02ff
    STA SPR_DMA
    LDX ram_vram_buffer_addr_ctrl  ; load control for pointer to buffer contents
    LDA VRAM_AddrTable_Low,x  ; set indirect at $00 to pointer
    STA $00
    LDA VRAM_AddrTable_High,x
    STA $01
    JSR sub_update_screen  ; update screen with buffer contents
    LDY #$00
    LDX ram_vram_buffer_addr_ctrl  ; check for usage of $0341
    CPX #$06
    BNE InitBuffer
    INY  ; get offset based on usage
InitBuffer:
    LDX VRAM_Buffer_Offset,y
    LDA #$00  ; clear buffer header at last location
    STA ram_vram_buffer1_offset,x
    STA ram_vram_buffer1,x
    STA ram_vram_buffer_addr_ctrl  ; reinit address control to $0301
    LDA ram_mirror_ppu_ctrl_reg2  ; copy mirror of $2001 to register
    STA PPU_CTRL_REG2
    JSR sub_sound_engine  ; play sound
    JSR sub_read_joypads  ; read joypads
    JSR sub_pause_routine  ; handle pause
    JSR sub_update_top_score
    LDA ram_game_pause_status  ; check for pause status
    LSR
    BCS PauseSkip
    LDA ram_timer_control  ; if master timer control not set, decrement
    BEQ DecTimers  ; all frame and interval timers
    DEC ram_timer_control
    BNE NoDecTimers
DecTimers:
    LDX #$14  ; load end offset for end of frame timers
    DEC ram_interval_timer_control  ; decrement interval timer control,
    BPL DecTimersLoop  ; if not expired, only frame timers will decrement
    LDA #$14
    STA ram_interval_timer_control  ; if control for interval timers expired,
    LDX #$23  ; interval timers will decrement along with frame timers
DecTimersLoop:
    LDA ram_timers,x  ; check current timer
    BEQ SkipExpTimer  ; if current timer expired, branch to skip,
    DEC ram_timers,x  ; otherwise decrement the current timer
SkipExpTimer:
    DEX  ; move onto next timer
    BPL DecTimersLoop  ; do this until all timers are dealt with
NoDecTimers:
    INC ram_frame_counter  ; increment frame counter
PauseSkip:
    LDX #$00
    LDY #$07
    LDA ram_pseudo_random_bit_reg  ; get first memory location of LSFR bytes
    AND #%00000010  ; mask out all but d1
    STA $00  ; save here
    LDA ram_pseudo_random_bit_reg+1  ; get second memory location
    AND #%00000010  ; mask out all but d1
    EOR $00  ; perform exclusive-OR on d1 from first and second bytes
    CLC  ; if neither or both are set, carry will be clear
    BEQ RotPRandomBit
    SEC  ; if one or the other is set, carry will be set
RotPRandomBit:
    ROR ram_pseudo_random_bit_reg,x  ; rotate carry into d7, and rotate last bit into carry
    INX  ; increment to next byte
    DEY  ; decrement for loop
    BNE RotPRandomBit
    LDA ram_sprite0_hit_detect_flag  ; check for flag here
    BEQ SkipSprite0
Sprite0Clr:
    LDA PPU_STATUS  ; wait for sprite 0 flag to clear, which will
    AND #%01000000  ; not happen until vblank has ended
    BNE Sprite0Clr
    LDA ram_game_pause_status  ; if in pause mode, do not bother with sprites at all
    LSR
    BCS Sprite0Hit
    JSR sub_move_sprites_offscreen
    JSR sub_sprite_shuffler
Sprite0Hit:
    LDA PPU_STATUS  ; do sprite #0 hit detection
    AND #%01000000
    BEQ Sprite0Hit
    LDY #$14  ; small delay, to wait until we hit horizontal blank time
HBlankDelay:
    DEY
    BNE HBlankDelay
SkipSprite0:
    LDA ram_horizontal_scroll  ; set scroll registers from variables
    STA PPU_SCROLL_REG
    LDA ram_vertical_scroll
    STA PPU_SCROLL_REG
    LDA ram_mirror_ppu_ctrl_reg1  ; load saved mirror of $2000
    PHA
    STA PPU_CTRL_REG1
    LDA ram_game_pause_status  ; if in pause mode, do not perform operation mode stuff
    LSR
    BCS SkipMainOper
    JSR sub_oper_mode_execution_tree  ; otherwise do one of many, many possible subroutines
SkipMainOper:
    LDA PPU_STATUS  ; reset flip-flop
    PLA
    ORA #%10000000  ; reactivate NMIs
    STA PPU_CTRL_REG1
    RTI  ; we are done until the next frame!

; -------------------------------------------------------------------------------------

sub_pause_routine:
    LDA ram_oper_mode  ; are we in victory mode?
    CMP #con_mode_victory  ; if so, go ahead
    BEQ ChkPauseTimer
    CMP #con_mode_game  ; are we in game mode?
    BNE ExitPause  ; if not, leave
    LDA ram_oper_mode_task  ; if we are in game mode, are we running game engine?
    CMP #$03
    BNE ExitPause  ; if not, leave
ChkPauseTimer:
    LDA ram_game_pause_timer  ; check if pause timer is still counting down
    BEQ ChkStart
    DEC ram_game_pause_timer  ; if so, decrement and leave
    RTS
ChkStart:
    LDA ram_saved_joypad1_bits  ; check to see if start is pressed
    AND #con_btn_start  ; on controller 1
    BEQ ClrPauseTimer
    LDA ram_game_pause_status  ; check to see if timer flag is set
    AND #%10000000  ; and if so, do not reset timer (residual,
    BNE ExitPause  ; joypad reading routine makes this unnecessary)
    LDA #$2b  ; set pause timer
    STA ram_game_pause_timer
    LDA ram_game_pause_status
    TAY
    INY  ; set pause sfx queue for next pause mode
    STY ram_pause_sound_queue
    EOR #%00000001  ; invert d0 and set d7
    ORA #%10000000
    BNE SetPause  ; unconditional branch
ClrPauseTimer:
    LDA ram_game_pause_status  ; clear timer flag if timer is at zero and start button
    AND #%01111111  ; is not pressed
SetPause:
    STA ram_game_pause_status
ExitPause:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used for preset value

sub_sprite_shuffler:
    LDY ram_area_type  ; load level type, likely residual code
    LDA #$28  ; load preset value which will put it at
    STA $00  ; sprite #10
    LDX #$0e  ; start at the end of OAM data offsets
ShuffleLoop:
    LDA ram_spr_data_offset,x  ; check for offset value against
    CMP $00  ; the preset value
    BCC NextSprOffset  ; if less, skip this part
    LDY ram_spr_shuffle_amt_offset  ; get current offset to preset value we want to add
    CLC
    ADC ram_spr_shuffle_amt,y  ; get shuffle amount, add to current sprite offset
    BCC StrSprOffset  ; if not exceeded $ff, skip second add
    CLC
    ADC $00  ; otherwise add preset value $28 to offset
StrSprOffset:
    STA ram_spr_data_offset,x  ; store new offset here or old one if branched to here
NextSprOffset:
    DEX  ; move backwards to next one
    BPL ShuffleLoop
    LDX ram_spr_shuffle_amt_offset  ; load offset
    INX
    CPX #$03  ; check if offset + 1 goes to 3
    BNE SetAmtOffset  ; if offset + 1 not 3, store
    LDX #$00  ; otherwise, init to 0
SetAmtOffset:
    STX ram_spr_shuffle_amt_offset
    LDX #$08  ; load offsets for values and storage
    LDY #$02
SetMiscOffset:
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
    BPL SetMiscOffset  ; do this until all misc spr offsets are loaded
    RTS

; -------------------------------------------------------------------------------------

sub_oper_mode_execution_tree:
    LDA ram_oper_mode  ; this is the heart of the entire program,
    JSR sub_dispatch_inline_handler  ; most of what goes on starts here

    .word TitleScreenMode
    .word GameMode
    .word VictoryMode
    .word GameOverMode

; -------------------------------------------------------------------------------------

sub_move_all_sprites_offscreen:
    LDY #$00  ; this routine moves all sprites off the screen
    .byte $2c  ; BIT instruction opcode

sub_move_sprites_offscreen:
    LDY #$04  ; this routine moves all but sprite 0
    LDA #$f8  ; off the screen
SprInitLoop:
    STA ram_sprite_y_position,y  ; write 248 into OAM data's Y coordinate
    INY  ; which will move it off the screen
    INY
    INY
    INY
    BNE SprInitLoop
    RTS
