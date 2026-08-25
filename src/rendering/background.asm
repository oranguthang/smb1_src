; -------------------------------------------------------------------------------------
; $00 - temp vram buffer offset
; $01 - temp metatile buffer offset
; $02 - temp metatile graphics table offset
; $03 - used to store attribute bits
; $04 - used to determine attribute table row
; $05 - used to determine attribute table column
; $06 - metatile graphics table address low
; $07 - metatile graphics table address high

; Convert the current metatile column into buffered PPU tile and attribute data

; Outputs:
; VRAM update buffers and attribute accumulation state are updated

; Clobbers:
; A, X, Y
RenderAreaGraphics:
    LDA ram_current_column_pos  ; store LSB of where we're at
    AND #$01
    STA $05
    LDY ram_vram_buffer2_offset  ; store vram buffer offset
    STY $00
    LDA ram_current_nt_addr_low  ; get current name table address we're supposed to render
    STA ram_vram_buffer2+1,y
    LDA ram_current_nt_addr_high
    STA ram_vram_buffer2,y
    LDA #$9a  ; store length byte of 26 here with d7 set
    STA ram_vram_buffer2+2,y  ; to increment by 32 (in columns)
    LDA #$00  ; init attribute row
    STA $04
    TAX
DrawMTLoop:
    STX $01  ; store init value of 0 or incremented offset for buffer
    LDA ram_metatile_buffer,x  ; get first metatile number, and mask out all but 2 MSB
    AND #%11000000
    STA $03  ; store attribute table bits here
    ASL  ; note that metatile format is:
    ROL  ; %xx000000 - attribute table bits,
    ROL  ; %00xxxxxx - metatile number
    TAY  ; rotate bits to d1-d0 and use as offset here
    LDA MetatileGraphics_Low,y  ; get address to graphics table from here
    STA $06
    LDA MetatileGraphics_High,y
    STA $07
    LDA ram_metatile_buffer,x  ; get metatile number again
    ASL  ; multiply by 4 and use as tile offset
    ASL
    STA $02
    LDA ram_area_parser_task_num  ; get current task number for level processing and
    AND #%00000001  ; mask out all but LSB, then invert LSB, multiply by 2
    EOR #%00000001  ; to get the correct column position in the metatile,
    ASL  ; then add to the tile offset so we can draw either side
    ADC $02  ; of the metatiles
    TAY
    LDX $00  ; use vram buffer offset from before as X
    LDA ($06),y
    STA ram_vram_buffer2+3,x  ; get first tile number (top left or top right) and store
    INY
    LDA ($06),y  ; now get the second (bottom left or bottom right) and store
    STA ram_vram_buffer2+4,x
    LDY $04  ; get current attribute row
    LDA $05  ; get LSB of current column where we're at, and
    BNE RightCheck  ; branch if set (clear = left attrib, set = right)
    LDA $01  ; get current row we're rendering
    LSR  ; branch if LSB set (clear = top left, set = bottom left)
    BCS LLeft
    ROL $03  ; rotate attribute bits 3 to the left
    ROL $03  ; thus in d1-d0, for upper left square
    ROL $03
    JMP SetAttrib
RightCheck:
    LDA $01  ; get LSB of current row we're rendering
    LSR  ; branch if set (clear = top right, set = bottom right)
    BCS NextMTRow
    LSR $03  ; shift attribute bits 4 to the right
    LSR $03  ; thus in d3-d2, for upper right square
    LSR $03
    LSR $03
    JMP SetAttrib
LLeft:
    LSR $03  ; shift attribute bits 2 to the right
    LSR $03  ; thus in d5-d4 for lower left square
NextMTRow:
    INC $04  ; move onto next attribute row
SetAttrib:
    LDA ram_attribute_buffer,y  ; get previously saved bits from before
    ORA $03  ; if any, and put new bits, if any, onto
    STA ram_attribute_buffer,y  ; the old, and store
    INC $00  ; increment vram buffer offset by 2
    INC $00
    LDX $01  ; get current gfx buffer row, and check for
    INX  ; the bottom of the screen
    CPX #$0d
    BCC DrawMTLoop  ; if not there yet, loop back
    LDY $00  ; get current vram buffer offset, increment by 3
    INY  ; (for name table address and length bytes)
    INY
    INY
    LDA #$00
    STA ram_vram_buffer2,y  ; put null terminator at end of data for name table
    STY ram_vram_buffer2_offset  ; store new buffer offset
    INC ram_current_nt_addr_low  ; increment name table address low
    LDA ram_current_nt_addr_low  ; check current low byte
    AND #%00011111  ; if no wraparound, just skip this part
    BNE ExitDrawM
    LDA #$80  ; if wraparound occurs, make sure low byte stays
    STA ram_current_nt_addr_low  ; just under the status bar
    LDA ram_current_nt_addr_high  ; and then invert d2 of the name table address high
    EOR #%00000100  ; to move onto the next appropriate name table
    STA ram_current_nt_addr_high
ExitDrawM:
    JMP SetVRAMCtrl  ; jump to set buffer to $0341 and leave

; -------------------------------------------------------------------------------------
; $00 - temp attribute table address high (big endian order this time!)
; $01 - temp attribute table address low

sub_render_attribute_tables:
    LDA ram_current_nt_addr_low  ; get low byte of next name table address
    AND #%00011111  ; to be written to, mask out all but 5 LSB,
    SEC  ; subtract four
    SBC #$04
    AND #%00011111  ; mask out bits again and store
    STA $01
    LDA ram_current_nt_addr_high  ; get high byte and branch if borrow not set
    BCS SetATHigh
    EOR #%00000100  ; otherwise invert d2
SetATHigh:
    AND #%00000100  ; mask out all other bits
    ORA #$23  ; add $2300 to the high byte and store
    STA $00
    LDA $01  ; get low byte - 4, divide by 4, add offset for
    LSR  ; attribute table and store
    LSR
    ADC #$c0  ; we should now have the appropriate block of
    STA $01  ; attribute table in our temp address
    LDX #$00
    LDY ram_vram_buffer2_offset  ; get buffer offset
AttribLoop:
    LDA $00
    STA ram_vram_buffer2,y  ; store high byte of attribute table address
    LDA $01
    CLC  ; get low byte, add 8 because we want to start
    ADC #$08  ; below the status bar, and store
    STA ram_vram_buffer2+1,y
    STA $01  ; also store in temp again
    LDA ram_attribute_buffer,x  ; fetch current attribute table byte and store
    STA ram_vram_buffer2+3,y  ; in the buffer
    LDA #$01
    STA ram_vram_buffer2+2,y  ; store length of 1 in buffer
    LSR
    STA ram_attribute_buffer,x  ; clear current byte in attribute buffer
    INY  ; increment buffer offset by 4 bytes
    INY
    INY
    INY
    INX  ; increment attribute offset and check to see
    CPX #$07  ; if we're at the end yet
    BCC AttribLoop
    STA ram_vram_buffer2,y  ; put null terminator at the end
    STY ram_vram_buffer2_offset  ; store offset in case we want to do any more
SetVRAMCtrl:
    LDA #$06
    STA ram_vram_buffer_addr_ctrl  ; set buffer to $0341 and leave
    RTS

; -------------------------------------------------------------------------------------

; $00 - used as temporary counter in sub_color_rotation

ColorRotatePalette:
    .byte $27, $27, $27, $17, $07, $17

BlankPalette:
    .byte $3f, $0c, $04, $ff, $ff, $ff, $ff, $00

; used based on area type
Palette3Data:
    .byte $0f, $07, $12, $0f
    .byte $0f, $07, $17, $0f
    .byte $0f, $07, $17, $1c
    .byte $0f, $07, $17, $00

sub_color_rotation:
    LDA ram_frame_counter  ; get frame counter
    AND #$07  ; mask out all but three LSB
    BNE ExitColorRot  ; branch if not set to zero to do this every eighth frame
    LDX ram_vram_buffer1_offset  ; check vram buffer offset
    CPX #$31
    BCS ExitColorRot  ; if offset over 48 bytes, branch to leave
    TAY  ; otherwise use frame counter's 3 LSB as offset here
GetBlankPal:
    LDA BlankPalette,y  ; get blank palette for palette 3
    STA ram_vram_buffer1,x  ; store it in the vram buffer
    INX  ; increment offsets
    INY
    CPY #$08
    BCC GetBlankPal  ; do this until all bytes are copied
    LDX ram_vram_buffer1_offset  ; get current vram buffer offset
    LDA #$03
    STA $00  ; set counter here
    LDA ram_area_type  ; get area type
    ASL  ; multiply by 4 to get proper offset
    ASL
    TAY  ; save as offset here
GetAreaPal:
    LDA Palette3Data,y  ; fetch palette to be written based on area type
    STA ram_vram_buffer1+3,x  ; store it to overwrite blank palette in vram buffer
    INY
    INX
    DEC $00  ; decrement counter
    BPL GetAreaPal  ; do this until the palette is all copied
    LDX ram_vram_buffer1_offset  ; get current vram buffer offset
    LDY ram_color_rotate_offset  ; get color cycling offset
    LDA ColorRotatePalette,y
    STA ram_vram_buffer1+4,x  ; get and store current color in second slot of palette
    LDA ram_vram_buffer1_offset
    CLC  ; add seven bytes to vram buffer offset
    ADC #$07
    STA ram_vram_buffer1_offset
    INC ram_color_rotate_offset  ; increment color cycling offset
    LDA ram_color_rotate_offset
    CMP #$06  ; check to see if it's still in range
    BCC ExitColorRot  ; if so, branch to leave
    LDA #$00
    STA ram_color_rotate_offset  ; otherwise, init to keep it in range
ExitColorRot:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00 - temp store for offset control bit
; $01 - temp vram buffer offset
; $02 - temp store for vertical high nybble in block buffer routine
; $03 - temp adder for high byte of name table address
; $04, $05 - name table address low/high
; $06, $07 - block buffer address low/high

BlockGfxData:
    .byte $45, $45, $47, $47
    .byte $47, $47, $47, $47
    .byte $57, $58, $59, $5a
    .byte $24, $24, $24, $24
    .byte $26, $26, $26, $26

sub_remove_coin_axe:
    LDY #$41  ; set low byte so offset points to $0341
    LDA #$03  ; load offset for default blank metatile
    LDX ram_area_type  ; check area type
    BNE WriteBlankMT  ; if not water type, use offset
    LDA #$04  ; otherwise load offset for blank metatile used in water
WriteBlankMT:
    JSR sub_put_block_metatile  ; do a sub to write blank metatile to vram buffer
    LDA #$06
    STA ram_vram_buffer_addr_ctrl  ; set vram address controller to $0341 and leave
    RTS

sub_replace_block_metatile:
    JSR sub_write_block_metatile  ; write metatile to vram buffer to replace block object
    INC ram_block_residual_counter  ; increment unused counter (residual code)
    DEC ram_block_rep_flag,x  ; decrement flag (residual code)
    RTS  ; leave

sub_destroy_block_metatile:
    LDA #$00  ; force blank metatile if branched/jumped to this point

sub_write_block_metatile:
    LDY #$03  ; load offset for blank metatile
    CMP #$00  ; check contents of A for blank metatile
    BEQ UseBOffset  ; branch if found (unconditional if branched from 8a6b)
    LDY #$00  ; load offset for brick metatile w/ line
    CMP #$58
    BEQ UseBOffset  ; use offset if metatile is brick with coins (w/ line)
    CMP #$51
    BEQ UseBOffset  ; use offset if metatile is breakable brick w/ line
    INY  ; increment offset for brick metatile w/o line
    CMP #$5d
    BEQ UseBOffset  ; use offset if metatile is brick with coins (w/o line)
    CMP #$52
    BEQ UseBOffset  ; use offset if metatile is breakable brick w/o line
    INY  ; if any other metatile, increment offset for empty block
UseBOffset:
    TYA  ; put Y in A
    LDY ram_vram_buffer1_offset  ; get vram buffer offset
    INY  ; move onto next byte
    JSR sub_put_block_metatile  ; get appropriate block data and write to vram buffer
sub_move_v_offset:
    DEY  ; decrement vram buffer offset
    TYA  ; add 10 bytes to it
    CLC
    ADC #10
    JMP SetVRAMOffset  ; branch to store as new vram buffer offset

sub_put_block_metatile:
    STX $00  ; store control bit from ram_spr_data_offset_ctrl
    STY $01  ; store vram buffer offset for next byte
    ASL
    ASL  ; multiply A by four and use as X
    TAX
    LDY #$20  ; load high byte for name table 0
    LDA $06  ; get low byte of block buffer pointer
    CMP #$d0  ; check to see if we're on odd-page block buffer
    BCC SaveHAdder  ; if not, use current high byte
    LDY #$24  ; otherwise load high byte for name table 1
SaveHAdder:
    STY $03  ; save high byte here
    AND #$0f  ; mask out high nybble of block buffer pointer
    ASL  ; multiply by 2 to get appropriate name table low byte
    STA $04  ; and then store it here
    LDA #$00
    STA $05  ; initialize temp high byte
    LDA $02  ; get vertical high nybble offset used in block buffer routine
    CLC
    ADC #$20  ; add 32 pixels for the status bar
    ASL
    ROL $05  ; shift and rotate d7 onto d0 and d6 into carry
    ASL
    ROL $05  ; shift and rotate d6 onto d0 and d5 into carry
    ADC $04  ; add low byte of name table and carry to vertical high nybble
    STA $04  ; and store here
    LDA $05  ; get whatever was in d7 and d6 of vertical high nybble
    ADC #$00  ; add carry
    CLC
    ADC $03  ; then add high byte of name table
    STA $05  ; store here
    LDY $01  ; get vram buffer offset to be used
sub_rem_bridge:
    LDA BlockGfxData,x  ; write top left and top right
    STA ram_vram_buffer1+2,y  ; tile numbers into first spot
    LDA BlockGfxData+1,x
    STA ram_vram_buffer1+3,y
    LDA BlockGfxData+2,x  ; write bottom left and bottom
    STA ram_vram_buffer1+7,y  ; right tiles numbers into
    LDA BlockGfxData+3,x  ; second spot
    STA ram_vram_buffer1+8,y
    LDA $04
    STA ram_vram_buffer1,y  ; write low byte of name table
    CLC  ; into first slot as read
    ADC #$20  ; add 32 bytes to value
    STA ram_vram_buffer1+5,y  ; write low byte of name table
    LDA $05  ; plus 32 bytes into second slot
    STA ram_vram_buffer1-1,y  ; write high byte of name
    STA ram_vram_buffer1+4,y  ; table address to both slots
    LDA #$02
    STA ram_vram_buffer1+1,y  ; put length of 2 in
    STA ram_vram_buffer1+6,y  ; both slots
    LDA #$00
    STA ram_vram_buffer1+9,y  ; put null terminator at end
    LDX $00  ; get offset control bit here
    RTS  ; and leave

; -------------------------------------------------------------------------------------
; METATILE GRAPHICS TABLE

MetatileGraphics_Low:
    .byte <Palette0_MTiles, <Palette1_MTiles, <Palette2_MTiles, <Palette3_MTiles

MetatileGraphics_High:
    .byte >Palette0_MTiles, >Palette1_MTiles, >Palette2_MTiles, >Palette3_MTiles

Palette0_MTiles:
    .byte $24, $24, $24, $24  ; blank
    .byte $27, $27, $27, $27  ; black metatile
    .byte $24, $24, $24, $35  ; bush left
    .byte $36, $25, $37, $25  ; bush middle
    .byte $24, $38, $24, $24  ; bush right
    .byte $24, $30, $30, $26  ; mountain left
    .byte $26, $26, $34, $26  ; mountain left bottom/middle center
    .byte $24, $31, $24, $32  ; mountain middle top
    .byte $33, $26, $24, $33  ; mountain right
    .byte $34, $26, $26, $26  ; mountain right bottom
    .byte $26, $26, $26, $26  ; mountain middle bottom
    .byte $24, $c0, $24, $c0  ; bridge guardrail
    .byte $24, $7f, $7f, $24  ; chain
    .byte $b8, $ba, $b9, $bb  ; tall tree top, top half
    .byte $b8, $bc, $b9, $bd  ; short tree top
    .byte $ba, $bc, $bb, $bd  ; tall tree top, bottom half
    .byte $60, $64, $61, $65  ; warp pipe end left, points up
    .byte $62, $66, $63, $67  ; warp pipe end right, points up
    .byte $60, $64, $61, $65  ; decoration pipe end left, points up
    .byte $62, $66, $63, $67  ; decoration pipe end right, points up
    .byte $68, $68, $69, $69  ; pipe shaft left
    .byte $26, $26, $6a, $6a  ; pipe shaft right
    .byte $4b, $4c, $4d, $4e  ; tree ledge left edge
    .byte $4d, $4f, $4d, $4f  ; tree ledge middle
    .byte $4d, $4e, $50, $51  ; tree ledge right edge
    .byte $6b, $70, $2c, $2d  ; mushroom left edge
    .byte $6c, $71, $6d, $72  ; mushroom middle
    .byte $6e, $73, $6f, $74  ; mushroom right edge
    .byte $86, $8a, $87, $8b  ; sideways pipe end top
    .byte $88, $8c, $88, $8c  ; sideways pipe shaft top
    .byte $89, $8d, $69, $69  ; sideways pipe joint top
    .byte $8e, $91, $8f, $92  ; sideways pipe end bottom
    .byte $26, $93, $26, $93  ; sideways pipe shaft bottom
    .byte $90, $94, $69, $69  ; sideways pipe joint bottom
    .byte $a4, $e9, $ea, $eb  ; seaplant
    .byte $24, $24, $24, $24  ; blank, used on bricks or blocks that are hit
    .byte $24, $2f, $24, $3d  ; flagpole ball
    .byte $a2, $a2, $a3, $a3  ; flagpole shaft
    .byte $24, $24, $24, $24  ; blank, used in conjunction with vines

Palette1_MTiles:
    .byte $a2, $a2, $a3, $a3  ; vertical rope
    .byte $99, $24, $99, $24  ; horizontal rope
    .byte $24, $a2, $3e, $3f  ; left pulley
    .byte $5b, $5c, $24, $a3  ; right pulley
    .byte $24, $24, $24, $24  ; blank used for balance rope
    .byte $9d, $47, $9e, $47  ; castle top
    .byte $47, $47, $27, $27  ; castle window left
    .byte $47, $47, $47, $47  ; castle brick wall
    .byte $27, $27, $47, $47  ; castle window right
    .byte $a9, $47, $aa, $47  ; castle top w/ brick
    .byte $9b, $27, $9c, $27  ; entrance top
    .byte $27, $27, $27, $27  ; entrance bottom
    .byte $52, $52, $52, $52  ; green ledge stump
    .byte $80, $a0, $81, $a1  ; fence
    .byte $be, $be, $bf, $bf  ; tree trunk
    .byte $75, $ba, $76, $bb  ; mushroom stump top
    .byte $ba, $ba, $bb, $bb  ; mushroom stump bottom
    .byte $45, $47, $45, $47  ; breakable brick w/ line
    .byte $47, $47, $47, $47  ; breakable brick
    .byte $45, $47, $45, $47  ; breakable brick (not used)
    .byte $b4, $b6, $b5, $b7  ; cracked rock terrain
    .byte $45, $47, $45, $47  ; brick with line (power-up)
    .byte $45, $47, $45, $47  ; brick with line (vine)
    .byte $45, $47, $45, $47  ; brick with line (star)
    .byte $45, $47, $45, $47  ; brick with line (coins)
    .byte $45, $47, $45, $47  ; brick with line (1-up)
    .byte $47, $47, $47, $47  ; brick (power-up)
    .byte $47, $47, $47, $47  ; brick (vine)
    .byte $47, $47, $47, $47  ; brick (star)
    .byte $47, $47, $47, $47  ; brick (coins)
    .byte $47, $47, $47, $47  ; brick (1-up)
    .byte $24, $24, $24, $24  ; hidden block (1 coin)
    .byte $24, $24, $24, $24  ; hidden block (1-up)
    .byte $ab, $ac, $ad, $ae  ; solid block (3-d block)
    .byte $5d, $5e, $5d, $5e  ; solid block (white wall)
    .byte $c1, $24, $c1, $24  ; bridge
    .byte $c6, $c8, $c7, $c9  ; bullet bill cannon barrel
    .byte $ca, $cc, $cb, $cd  ; bullet bill cannon top
    .byte $2a, $2a, $40, $40  ; bullet bill cannon bottom
    .byte $24, $24, $24, $24  ; blank used for jumpspring
    .byte $24, $47, $24, $47  ; half brick used for jumpspring
    .byte $82, $83, $84, $85  ; solid block (water level, green rock)
    .byte $24, $47, $24, $47  ; half brick (???)
    .byte $86, $8a, $87, $8b  ; water pipe top
    .byte $8e, $91, $8f, $92  ; water pipe bottom
    .byte $24, $2f, $24, $3d  ; flag ball (residual object)

Palette2_MTiles:
    .byte $24, $24, $24, $35  ; cloud left
    .byte $36, $25, $37, $25  ; cloud middle
    .byte $24, $38, $24, $24  ; cloud right
    .byte $24, $24, $39, $24  ; cloud bottom left
    .byte $3a, $24, $3b, $24  ; cloud bottom middle
    .byte $3c, $24, $24, $24  ; cloud bottom right
    .byte $41, $26, $41, $26  ; water/lava top
    .byte $26, $26, $26, $26  ; water/lava
    .byte $b0, $b1, $b2, $b3  ; cloud level terrain
    .byte $77, $79, $77, $79  ; bowser's bridge

Palette3_MTiles:
    .byte $53, $55, $54, $56  ; question block (coin)
    .byte $53, $55, $54, $56  ; question block (power-up)
    .byte $a5, $a7, $a6, $a8  ; coin
    .byte $c2, $c4, $c3, $c5  ; underwater coin
    .byte $57, $59, $58, $5a  ; empty block
    .byte $7b, $7d, $7c, $7e  ; axe

; -------------------------------------------------------------------------------------
; VRAM BUFFER DATA FOR LOCATIONS IN PRG-ROM

WaterPaletteData:
    .byte $3f, $00, $20
    .byte $0f, $15, $12, $25
    .byte $0f, $3a, $1a, $0f
    .byte $0f, $30, $12, $0f
    .byte $0f, $27, $12, $0f
    .byte $22, $16, $27, $18
    .byte $0f, $10, $30, $27
    .byte $0f, $16, $30, $27
    .byte $0f, $0f, $30, $10
    .byte $00

GroundPaletteData:
    .byte $3f, $00, $20
    .byte $0f, $29, $1a, $0f
    .byte $0f, $36, $17, $0f
    .byte $0f, $30, $21, $0f
    .byte $0f, $27, $17, $0f
    .byte $0f, $16, $27, $18
    .byte $0f, $1a, $30, $27
    .byte $0f, $16, $30, $27
    .byte $0f, $0f, $36, $17
    .byte $00

UndergroundPaletteData:
    .byte $3f, $00, $20
    .byte $0f, $29, $1a, $09
    .byte $0f, $3c, $1c, $0f
    .byte $0f, $30, $21, $1c
    .byte $0f, $27, $17, $1c
    .byte $0f, $16, $27, $18
    .byte $0f, $1c, $36, $17
    .byte $0f, $16, $30, $27
    .byte $0f, $0c, $3c, $1c
    .byte $00

CastlePaletteData:
    .byte $3f, $00, $20
    .byte $0f, $30, $10, $00
    .byte $0f, $30, $10, $00
    .byte $0f, $30, $16, $00
    .byte $0f, $27, $17, $00
    .byte $0f, $16, $27, $18
    .byte $0f, $1c, $36, $17
    .byte $0f, $16, $30, $27
    .byte $0f, $00, $30, $10
    .byte $00

DaySnowPaletteData:
    .byte $3f, $00, $04
    .byte $22, $30, $00, $10
    .byte $00

NightSnowPaletteData:
    .byte $3f, $00, $04
    .byte $0f, $30, $00, $10
    .byte $00

MushroomPaletteData:
    .byte $3f, $00, $04
    .byte $22, $27, $16, $0f
    .byte $00

BowserPaletteData:
    .byte $3f, $14, $04
    .byte $0f, $1a, $30, $27
    .byte $00

MarioThanksMessage:
; "THANK YOU MARIO!"
    .byte $25, $48, $10
    .byte $1d, $11, $0a, $17, $14, $24
    .byte $22, $18, $1e, $24
    .byte $16, $0a, $1b, $12, $18, $2b
    .byte $00

LuigiThanksMessage:
; "THANK YOU LUIGI!"
    .byte $25, $48, $10
    .byte $1d, $11, $0a, $17, $14, $24
    .byte $22, $18, $1e, $24
    .byte $15, $1e, $12, $10, $12, $2b
    .byte $00

MushroomRetainerSaved:
; "BUT OUR PRINCESS IS IN"
    .byte $25, $c5, $16
    .byte $0b, $1e, $1d, $24, $18, $1e, $1b, $24
    .byte $19, $1b, $12, $17, $0c, $0e, $1c, $1c, $24
    .byte $12, $1c, $24, $12, $17
; "ANOTHER CASTLE!"
    .byte $26, $05, $0f
    .byte $0a, $17, $18, $1d, $11, $0e, $1b, $24
    .byte $0c, $0a, $1c, $1d, $15, $0e, $2b, $00

PrincessSaved1:
; "YOUR QUEST IS OVER."
    .byte $25, $a7, $13
    .byte $22, $18, $1e, $1b, $24
    .byte $1a, $1e, $0e, $1c, $1d, $24
    .byte $12, $1c, $24, $18, $1f, $0e, $1b, $af
    .byte $00

PrincessSaved2:
; "WE PRESENT YOU A NEW QUEST."
    .byte $25, $e3, $1b
    .byte $20, $0e, $24
    .byte $19, $1b, $0e, $1c, $0e, $17, $1d, $24
    .byte $22, $18, $1e, $24, $0a, $24, $17, $0e, $20, $24
    .byte $1a, $1e, $0e, $1c, $1d, $af
    .byte $00

WorldSelectMessage1:
; "PUSH BUTTON B"
    .byte $26, $4a, $0d
    .byte $19, $1e, $1c, $11, $24
    .byte $0b, $1e, $1d, $1d, $18, $17, $24, $0b
    .byte $00

WorldSelectMessage2:
; "TO SELECT A WORLD"
    .byte $26, $88, $11
    .byte $1d, $18, $24, $1c, $0e, $15, $0e, $0c, $1d, $24
    .byte $0a, $24, $20, $18, $1b, $15, $0d
    .byte $00
