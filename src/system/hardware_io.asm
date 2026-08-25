;-------------------------------------------------------------------------------------
;$04 - address low to jump address
;$05 - address high to jump address
;$06 - jump address low
;$07 - jump address high

JumpEngine:
       asl          ;shift bit from contents of A
       tay
       pla          ;pull saved return address from stack
       sta $04      ;save to indirect
       pla
       sta $05
       iny
       lda ($04),y  ;load pointer from indirect
       sta $06      ;note that if an RTS is performed in next routine
       iny          ;it will return to the execution before the sub
       lda ($04),y  ;that called this routine
       sta $07
       jmp ($06)    ;jump to the address we loaded

;-------------------------------------------------------------------------------------

InitializeNameTables:
              lda PPU_STATUS            ;reset flip-flop
              lda Mirror_PPU_CTRL_REG1  ;load mirror of ppu reg $2000
              ora #%00010000            ;set sprites for first 4k and background for second 4k
              and #%11110000            ;clear rest of lower nybble, leave higher alone
              jsr WritePPUReg1
              lda #$24                  ;set vram address to start of name table 1
              jsr WriteNTAddr
              lda #$20                  ;and then set it to name table 0
WriteNTAddr:  sta PPU_ADDRESS
              lda #$00
              sta PPU_ADDRESS
              ldx #$04                  ;clear name table with blank tile #24
              ldy #$c0
              lda #$24
InitNTLoop:   sta PPU_DATA              ;count out exactly 768 tiles
              dey
              bne InitNTLoop
              dex
              bne InitNTLoop
              ldy #64                   ;now to clear the attribute table (with zero this time)
              txa
              sta VRAM_Buffer1_Offset   ;init vram buffer 1 offset
              sta VRAM_Buffer1          ;init vram buffer 1
InitATLoop:   sta PPU_DATA
              dey
              bne InitATLoop
              sta HorizontalScroll      ;reset scroll variables
              sta VerticalScroll
              jmp InitScroll            ;initialize scroll registers to zero

;-------------------------------------------------------------------------------------
;$00 - temp joypad bit

ReadJoypads:
              lda #$01               ;reset and clear strobe of joypad ports
              sta JOYPAD_PORT
              lsr
              tax                    ;start with joypad 1's port
              sta JOYPAD_PORT
              jsr ReadPortBits
              inx                    ;increment for joypad 2's port
ReadPortBits: ldy #$08
PortLoop:     pha                    ;push previous bit onto stack
              lda JOYPAD_PORT,x      ;read current bit on joypad port
              sta $00                ;check d1 and d0 of port output
              lsr                    ;this is necessary on the old
              ora $00                ;famicom systems in japan
              lsr
              pla                    ;read bits from stack
              rol                    ;rotate bit from carry flag
              dey
              bne PortLoop           ;count down bits left
              sta SavedJoypadBits,x  ;save controller status here always
              pha
              and #%00110000         ;check for select or start
              and JoypadBitMask,x    ;if neither saved state nor current state
              beq Save8Bits          ;have any of these two set, branch
              pla
              and #%11001111         ;otherwise store without select
              sta SavedJoypadBits,x  ;or start bits and leave
              rts
Save8Bits:    pla
              sta JoypadBitMask,x    ;save with all bits in another place and leave
              rts

;-------------------------------------------------------------------------------------
;$00 - vram buffer address table low
;$01 - vram buffer address table high

WriteBufferToScreen:
               sta PPU_ADDRESS           ;store high byte of vram address
               iny
               lda ($00),y               ;load next byte (second)
               sta PPU_ADDRESS           ;store low byte of vram address
               iny
               lda ($00),y               ;load next byte (third)
               asl                       ;shift to left and save in stack
               pha
               lda Mirror_PPU_CTRL_REG1  ;load mirror of $2000,
               ora #%00000100            ;set ppu to increment by 32 by default
               bcs SetupWrites           ;if d7 of third byte was clear, ppu will
               and #%11111011            ;only increment by 1
SetupWrites:   jsr WritePPUReg1          ;write to register
               pla                       ;pull from stack and shift to left again
               asl
               bcc GetLength             ;if d6 of third byte was clear, do not repeat byte
               ora #%00000010            ;otherwise set d1 and increment Y
               iny
GetLength:     lsr                       ;shift back to the right to get proper length
               lsr                       ;note that d1 will now be in carry
               tax
OutputToVRAM:  bcs RepeatByte            ;if carry set, repeat loading the same byte
               iny                       ;otherwise increment Y to load next byte
RepeatByte:    lda ($00),y               ;load more data from buffer and write to vram
               sta PPU_DATA
               dex                       ;done writing?
               bne OutputToVRAM
               sec
               tya
               adc $00                   ;add end length plus one to the indirect at $00
               sta $00                   ;to allow this routine to read another set of updates
               lda #$00
               adc $01
               sta $01
               lda #$3f                  ;sets vram address to $3f00
               sta PPU_ADDRESS
               lda #$00
               sta PPU_ADDRESS
               sta PPU_ADDRESS           ;then reinitializes it for some reason
               sta PPU_ADDRESS
UpdateScreen:  ldx PPU_STATUS            ;reset flip-flop
               ldy #$00                  ;load first byte from indirect as a pointer
               lda ($00),y
               bne WriteBufferToScreen   ;if byte is zero we have no further updates to make here
InitScroll:    sta PPU_SCROLL_REG        ;store contents of A into scroll registers
               sta PPU_SCROLL_REG        ;and end whatever subroutine led us here
               rts

;-------------------------------------------------------------------------------------

WritePPUReg1:
               sta PPU_CTRL_REG1         ;write contents of A to PPU register 1
               sta Mirror_PPU_CTRL_REG1  ;and its mirror
               rts
