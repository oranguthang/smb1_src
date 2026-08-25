; -------------------------------------------------------------------------------------
; $04 - address low to jump address
; $05 - address high to jump address
; $06 - jump address low
; $07 - jump address high

sub_dispatch_inline_handler:
    ASL  ; shift bit from contents of A
    TAY
    PLA  ; pull saved return address from stack
    STA $04  ; save to indirect
    PLA
    STA $05
    INY
    LDA ($04),y  ; load pointer from indirect
    STA $06  ; note that if an RTS is performed in next routine
    INY  ; it will return to the execution before the sub
    LDA ($04),y  ; that called this routine
    STA $07
    JMP ($06)  ; jump to the address we loaded

; -------------------------------------------------------------------------------------

InitializeNameTables:
    LDA PPU_STATUS  ; reset flip-flop
    LDA Mirror_PPU_CTRL_REG1  ; load mirror of ppu reg $2000
    ORA #%00010000  ; set sprites for first 4k and background for second 4k
    AND #%11110000  ; clear rest of lower nybble, leave higher alone
    JSR WritePPUReg1
    LDA #$24  ; set vram address to start of name table 1
    JSR WriteNTAddr
    LDA #$20  ; and then set it to name table 0
WriteNTAddr:
    STA PPU_ADDRESS
    LDA #$00
    STA PPU_ADDRESS
    LDX #$04  ; clear name table with blank tile #24
    LDY #$c0
    LDA #$24
InitNTLoop:
    STA PPU_DATA  ; count out exactly 768 tiles
    DEY
    BNE InitNTLoop
    DEX
    BNE InitNTLoop
    LDY #64  ; now to clear the attribute table (with zero this time)
    TXA
    STA VRAM_Buffer1_Offset  ; init vram buffer 1 offset
    STA VRAM_Buffer1  ; init vram buffer 1
InitATLoop:
    STA PPU_DATA
    DEY
    BNE InitATLoop
    STA HorizontalScroll  ; reset scroll variables
    STA VerticalScroll
    JMP InitScroll  ; initialize scroll registers to zero

; -------------------------------------------------------------------------------------
; $00 - temp joypad bit

ReadJoypads:
    LDA #$01  ; reset and clear strobe of joypad ports
    STA JOYPAD_PORT
    LSR
    TAX  ; start with joypad 1's port
    STA JOYPAD_PORT
    JSR ReadPortBits
    INX  ; increment for joypad 2's port
ReadPortBits:
    LDY #$08
PortLoop:
    PHA  ; push previous bit onto stack
    LDA JOYPAD_PORT,x  ; read current bit on joypad port
    STA $00  ; check d1 and d0 of port output
    LSR  ; this is necessary on the old
    ORA $00  ; famicom systems in japan
    LSR
    PLA  ; read bits from stack
    ROL  ; rotate bit from carry flag
    DEY
    BNE PortLoop  ; count down bits left
    STA SavedJoypadBits,x  ; save controller status here always
    PHA
    AND #%00110000  ; check for select or start
    AND JoypadBitMask,x  ; if neither saved state nor current state
    BEQ Save8Bits  ; have any of these two set, branch
    PLA
    AND #%11001111  ; otherwise store without select
    STA SavedJoypadBits,x  ; or start bits and leave
    RTS
Save8Bits:
    PLA
    STA JoypadBitMask,x  ; save with all bits in another place and leave
    RTS

; -------------------------------------------------------------------------------------
; $00 - vram buffer address table low
; $01 - vram buffer address table high

WriteBufferToScreen:
    STA PPU_ADDRESS  ; store high byte of vram address
    INY
    LDA ($00),y  ; load next byte (second)
    STA PPU_ADDRESS  ; store low byte of vram address
    INY
    LDA ($00),y  ; load next byte (third)
    ASL  ; shift to left and save in stack
    PHA
    LDA Mirror_PPU_CTRL_REG1  ; load mirror of $2000,
    ORA #%00000100  ; set ppu to increment by 32 by default
    BCS SetupWrites  ; if d7 of third byte was clear, ppu will
    AND #%11111011  ; only increment by 1
SetupWrites:
    JSR WritePPUReg1  ; write to register
    PLA  ; pull from stack and shift to left again
    ASL
    BCC GetLength  ; if d6 of third byte was clear, do not repeat byte
    ORA #%00000010  ; otherwise set d1 and increment Y
    INY
GetLength:
    LSR  ; shift back to the right to get proper length
    LSR  ; note that d1 will now be in carry
    TAX
OutputToVRAM:
    BCS RepeatByte  ; if carry set, repeat loading the same byte
    INY  ; otherwise increment Y to load next byte
RepeatByte:
    LDA ($00),y  ; load more data from buffer and write to vram
    STA PPU_DATA
    DEX  ; done writing?
    BNE OutputToVRAM
    SEC
    TYA
    ADC $00  ; add end length plus one to the indirect at $00
    STA $00  ; to allow this routine to read another set of updates
    LDA #$00
    ADC $01
    STA $01
    LDA #$3f  ; sets vram address to $3f00
    STA PPU_ADDRESS
    LDA #$00
    STA PPU_ADDRESS
    STA PPU_ADDRESS  ; then reinitializes it for some reason
    STA PPU_ADDRESS
UpdateScreen:
    LDX PPU_STATUS  ; reset flip-flop
    LDY #$00  ; load first byte from indirect as a pointer
    LDA ($00),y
    BNE WriteBufferToScreen  ; if byte is zero we have no further updates to make here
InitScroll:
    STA PPU_SCROLL_REG  ; store contents of A into scroll registers
    STA PPU_SCROLL_REG  ; and end whatever subroutine led us here
    RTS

; -------------------------------------------------------------------------------------

WritePPUReg1:
    STA PPU_CTRL_REG1  ; write contents of A to PPU register 1
    STA Mirror_PPU_CTRL_REG1  ; and its mirror
    RTS
