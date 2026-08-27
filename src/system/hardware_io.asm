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

sub_initialize_name_tables:
    LDA PPU_STATUS  ; reset flip-flop
    LDA ram_mirror_ppu_ctrl_reg1  ; load mirror of ppu reg $2000
    ORA #%00010000  ; set sprites for first 4k and background for second 4k
    AND #%11110000  ; clear rest of lower nybble, leave higher alone
    JSR sub_write_ppu_reg1
    LDA #$24  ; set vram address to start of name table 1
    JSR sub_write_nametable_address
    LDA #$20  ; and then set it to name table 0
sub_write_nametable_address:
    STA PPU_ADDRESS
    LDA #$00
    STA PPU_ADDRESS
    LDX #$04  ; clear name table with blank tile #24
    LDY #$c0
    LDA #$24
bra_initialize_nametable_loop:
    STA PPU_DATA  ; count out exactly 768 tiles
    DEY
    BNE bra_initialize_nametable_loop
    DEX
    BNE bra_initialize_nametable_loop
    LDY #64  ; now to clear the attribute table (with zero this time)
    TXA
    STA ram_vram_buffer1_offset  ; init vram buffer 1 offset
    STA ram_vram_buffer1  ; init vram buffer 1
bra_initialize_attribute_table_loop:
    STA PPU_DATA
    DEY
    BNE bra_initialize_attribute_table_loop
    STA ram_horizontal_scroll  ; reset scroll variables
    STA ram_vertical_scroll
    JMP sub_initialize_ppu_scroll  ; initialize scroll registers to zero

; -------------------------------------------------------------------------------------
; $00 - temp joypad bit

sub_read_joypads:
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release+con_vs_request_controller_strobe
    STA VS_REQUEST
    LDA #con_vs_request_irq_release
    LDX #$00
    STA VS_REQUEST
    LDA #$00
.else
    LDA #$01  ; reset and clear strobe of joypad ports
    STA JOYPAD_PORT
    LSR
    TAX  ; start with joypad 1's port
    STA JOYPAD_PORT
.endif
    JSR sub_read_port_bits
    INX  ; increment for joypad 2's port
sub_read_port_bits:
    LDY #$08
bra_read_controller_port_loop:
    PHA  ; push previous bit onto stack
    LDA JOYPAD_PORT,x  ; read current bit on joypad port
    STA $00  ; check d1 and d0 of port output
.if con_revision_profile <> con_revision_profile_vs
    LSR  ; this is necessary on the old
    ORA $00  ; famicom systems in japan
.endif
    LSR
    PLA  ; read bits from stack
    ROL  ; rotate bit from carry flag
    DEY
    BNE bra_read_controller_port_loop  ; count down bits left
    STA ram_saved_joypad_bits,x  ; save controller status here always
    PHA
    AND #%00110000  ; check for select or start
    AND ram_joypad_bit_mask,x  ; if neither saved state nor current state
    BEQ bra_store_controller_bits  ; have any of these two set, branch
    PLA
    AND #%11001111  ; otherwise store without select
    STA ram_saved_joypad_bits,x  ; or start bits and leave
    RTS
bra_store_controller_bits:
    PLA
    STA ram_joypad_bit_mask,x  ; save with all bits in another place and leave
    RTS

; -------------------------------------------------------------------------------------
; $00 - vram buffer address table low
; $01 - vram buffer address table high

bra_write_vram_buffer:
    STA PPU_ADDRESS  ; store high byte of vram address
    INY
    LDA ($00),y  ; load next byte (second)
    STA PPU_ADDRESS  ; store low byte of vram address
    INY
    LDA ($00),y  ; load next byte (third)
    ASL  ; shift to left and save in stack
    PHA
    LDA ram_mirror_ppu_ctrl_reg1  ; load mirror of $2000,
    ORA #%00000100  ; set ppu to increment by 32 by default
    BCS bra_prepare_vram_buffer_entry  ; if d7 of third byte was clear, ppu will
    AND #%11111011  ; only increment by 1
bra_prepare_vram_buffer_entry:
    JSR sub_write_ppu_reg1  ; write to register
    PLA  ; pull from stack and shift to left again
    ASL
    BCC bra_decode_vram_buffer_length  ; if d6 of third byte was clear, do not repeat byte
    ORA #%00000010  ; otherwise set d1 and increment Y
    INY
bra_decode_vram_buffer_length:
    LSR  ; shift back to the right to get proper length
    LSR  ; note that d1 will now be in carry
    TAX
bra_write_vram_buffer_bytes:
    BCS bra_repeat_vram_buffer_byte  ; if carry set, repeat loading the same byte
    INY  ; otherwise increment Y to load next byte
bra_repeat_vram_buffer_byte:
    LDA ($00),y  ; load more data from buffer and write to vram
    STA PPU_DATA
    DEX  ; done writing?
    BNE bra_write_vram_buffer_bytes
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
sub_update_screen:
    LDX PPU_STATUS  ; reset flip-flop
    LDY #$00  ; load first byte from indirect as a pointer
    LDA ($00),y
    BNE bra_write_vram_buffer  ; if byte is zero we have no further updates to make here
sub_initialize_ppu_scroll:
    STA PPU_SCROLL_REG  ; store contents of A into scroll registers
    STA PPU_SCROLL_REG  ; and end whatever subroutine led us here
    RTS

; -------------------------------------------------------------------------------------

sub_write_ppu_reg1:
    STA PPU_CTRL_REG1  ; write contents of A to PPU register 1
    STA ram_mirror_ppu_ctrl_reg1  ; and its mirror
    RTS
