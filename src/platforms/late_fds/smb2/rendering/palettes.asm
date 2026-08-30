off_smb2_main_rotating_palette_colors:
    .byte $27, $27, $27, $17, $07, $17

off_smb2_main_blank_palette_packet:
    .byte $3f, $0c, $04, $ff, $ff, $ff, $ff, $00

; used based on area type
off_smb2_main_area_type_palette_3_colors:
    .byte $0f, $07, $12, $0f
    .byte $0f, $07, $17, $0f
    .byte $0f, $07, $17, $1c
    .byte $0f, $07, $17, $00

sub_smb2_main_color_rotation:
    LDA FrameCounter  ; get frame counter
    AND #$07  ; mask out all but three LSB
    BNE bra_smb2_main_exit_color_rotation  ; branch if not set to zero to do this every eighth frame
    LDX VRAM_Buffer1_Offset  ; check vram buffer offset
    CPX #$31
    BCS bra_smb2_main_exit_color_rotation  ; if offset over 48 bytes, branch to leave
    TAY  ; otherwise use frame counter's 3 LSB as offset here
bra_smb2_main_copy_blank_palette_packet:
    LDA off_smb2_main_blank_palette_packet,y  ; get blank palette for palette 3
    STA VRAM_Buffer1,x  ; store it in the vram buffer
    INX  ; increment offsets
    INY
    CPY #$08
    BCC bra_smb2_main_copy_blank_palette_packet  ; do this until all bytes are copied
    LDX VRAM_Buffer1_Offset  ; get current vram buffer offset
    LDA #$03
    STA $00  ; set counter here
    LDA AreaType  ; get area type
    ASL  ; multiply by 4 to get proper offset
    ASL
    TAY  ; save as offset here
bra_smb2_main_copy_area_palette_colors:
    LDA off_smb2_main_area_type_palette_3_colors,y  ; fetch palette to be written based on area type
    STA VRAM_Buffer1+3,x  ; store it to overwrite blank palette in vram buffer
    INY
    INX
    DEC $00  ; decrement counter
    BPL bra_smb2_main_copy_area_palette_colors  ; do this until the palette is all copied
    LDX VRAM_Buffer1_Offset  ; get current vram buffer offset
    LDY ColorRotateOffset  ; get color cycling offset
    LDA off_smb2_main_rotating_palette_colors,y
    STA VRAM_Buffer1+4,x  ; get and store current color in second slot of palette
    LDA VRAM_Buffer1_Offset
    CLC  ; add seven bytes to vram buffer offset
    ADC #$07
    STA VRAM_Buffer1_Offset
    INC ColorRotateOffset  ; increment color cycling offset
    LDA ColorRotateOffset
    CMP #$06  ; check to see if it's still in range
    BCC bra_smb2_main_exit_color_rotation  ; if so, branch to leave
    LDA #$00
    STA ColorRotateOffset  ; otherwise, init to keep it in range
bra_smb2_main_exit_color_rotation:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00 - temp store for offset control bit
; $01 - temp vram buffer offset
; $02 - temp store for vertical high nybble in block buffer routine
; $03 - temp adder for high byte of name table address
; $04, $05 - name table address low/high
; $06, $07 - block buffer address low/high

off_smb2_main_block_metatile_tiles:
    .byte $45, $45, $47, $47
    .byte $47, $47, $47, $47
    .byte $57, $58, $59, $5a
    .byte $24, $24, $24, $24
    .byte $26, $26, $26, $26

sub_smb2_main_remove_coin_axe:
    LDY #$41  ; set low byte so offset points to second vram buffer
    LDA #$03  ; load offset for default blank metatile
    LDX AreaType  ; check area type
    BNE bra_smb2_main_write_blank_metatile  ; if not water type, use offset
    LDA #$04  ; otherwise load offset for blank metatile used in water
bra_smb2_main_write_blank_metatile:
    JSR sub_smb2_main_put_block_metatile  ; do a sub to write blank metatile to vram buffer
    LDA #$06
    STA VRAM_Buffer_AddrCtrl  ; set vram address controller to second vram buffer and leave
    RTS

sub_smb2_main_replace_block_metatile:
    JSR sub_smb2_main_write_block_metatile  ; write metatile to vram buffer to replace block object
    INC Block_ResidualCounter  ; increment unused counter (residual code)
    DEC Block_RepFlag,x  ; decrement flag (residual code)
    RTS  ; leave

sub_smb2_main_destroy_block_metatile:
    LDA #$00  ; force blank metatile if branched/jumped to this point

sub_smb2_main_write_block_metatile:
    LDY #$03  ; load offset for blank metatile
    CMP #$00  ; check contents of A for blank metatile
    BEQ bra_smb2_main_select_block_metatile_tiles  ; branch if found (unconditional if destroying metatile)
    LDY #$00  ; load offset for brick metatile w/ line
    CMP #$56
    BEQ bra_smb2_main_select_block_metatile_tiles  ; use offset if metatile is brick with coins (w/ line)
    CMP #$4f
    BEQ bra_smb2_main_select_block_metatile_tiles  ; use offset if metatile is breakable brick w/ line
    INY  ; increment offset for brick metatile w/o line
    CMP #$5c
    BEQ bra_smb2_main_select_block_metatile_tiles  ; use offset if metatile is brick with coins (w/o line)
    CMP #$50
    BEQ bra_smb2_main_select_block_metatile_tiles  ; use offset if metatile is breakable brick w/o line
    INY  ; if any other metatile, increment offset for empty block
bra_smb2_main_select_block_metatile_tiles:
    TYA  ; put Y in A
    LDY VRAM_Buffer1_Offset  ; get vram buffer offset
    INY  ; move onto next byte
    JSR sub_smb2_main_put_block_metatile  ; get appropriate block data and write to vram buffer
sub_smb2_main_advance_primary_vram_buffer_offset:
    DEY  ; decrement vram buffer offset
    TYA  ; add 10 bytes to it
    CLC
    ADC #10
    JMP loc_smb2_main_store_primary_vram_buffer_offset  ; branch to store as new vram buffer offset

sub_smb2_main_put_block_metatile:
    STX $00  ; store control bit from SprDataOffset_Ctrl
    STY $01  ; store vram buffer offset for next byte
    ASL
    ASL  ; multiply A by four and use as X
    TAX
    LDY #$20  ; load high byte for name table 0
    LDA $06  ; get low byte of block buffer pointer
    CMP #$d0  ; check to see if we're on odd-page block buffer
    BCC bra_smb2_main_compute_block_nametable_address  ; if not, use current high byte
    LDY #$24  ; otherwise load high byte for name table 1
bra_smb2_main_compute_block_nametable_address:
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
sub_smb2_main_write_block_or_bridge_metatile:
    LDA off_smb2_main_block_metatile_tiles,x  ; write top left and top right
    STA VRAM_Buffer1+2,y  ; tile numbers into first spot
    LDA off_smb2_main_block_metatile_tiles+1,x
    STA VRAM_Buffer1+3,y
    LDA off_smb2_main_block_metatile_tiles+2,x  ; write bottom left and bottom
    STA VRAM_Buffer1+7,y  ; right tiles numbers into
    LDA off_smb2_main_block_metatile_tiles+3,x  ; second spot
    STA VRAM_Buffer1+8,y
    LDA $04
    STA VRAM_Buffer1,y  ; write low byte of name table
    CLC  ; into first slot as read
    ADC #$20  ; add 32 bytes to value
    STA VRAM_Buffer1+5,y  ; write low byte of name table
    LDA $05  ; plus 32 bytes into second slot
    STA VRAM_Buffer1-1,y  ; write high byte of name
    STA VRAM_Buffer1+4,y  ; table address to both slots
    LDA #$02
    STA VRAM_Buffer1+1,y  ; put length of 2 in
    STA VRAM_Buffer1+6,y  ; both slots
    LDA #$00
    STA VRAM_Buffer1+9,y  ; put null terminator at end
    LDX $00  ; get offset control bit here
    RTS  ; and leave

; -------------------------------------------------------------------------------------
; METATILE GRAPHICS TABLE

tbl_smb2_main_metatile_graphics_pointers_low:
    .byte <off_smb2_main_palette_0_metatiles, <off_smb2_main_palette_1_metatiles, <off_smb2_main_palette_2_metatiles, <off_smb2_main_palette_3_metatiles

tbl_smb2_main_metatile_graphics_pointers_high:
    .byte >off_smb2_main_palette_0_metatiles, >off_smb2_main_palette_1_metatiles, >off_smb2_main_palette_2_metatiles, >off_smb2_main_palette_3_metatiles

off_smb2_main_palette_0_metatiles:
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

off_smb2_main_palette_1_metatiles:
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
    .byte $45, $47, $45, $47  ; breakable brick w/ line
    .byte $47, $47, $47, $47  ; breakable brick
    .byte $45, $47, $45, $47  ; breakable brick (not used)
    .byte $45, $47, $45, $47  ; brick with line (power-up)
    .byte $45, $47, $45, $47  ; brick with line (poison shroom)
    .byte $45, $47, $45, $47  ; brick with line (vine)
    .byte $45, $47, $45, $47  ; brick with line (star)
    .byte $45, $47, $45, $47  ; brick with line (coins)
    .byte $45, $47, $45, $47  ; brick with line (1-up)
    .byte $47, $47, $47, $47  ; brick (power-up)
    .byte $47, $47, $47, $47  ; brick (poison shroom)
    .byte $47, $47, $47, $47  ; brick (vine)
    .byte $47, $47, $47, $47  ; brick (star)
    .byte $47, $47, $47, $47  ; brick (coins)
    .byte $47, $47, $47, $47  ; brick (1-up)
    .byte $24, $24, $24, $24  ; hidden block (1 coin)
    .byte $24, $24, $24, $24  ; hidden block (1-up)
    .byte $24, $24, $24, $24  ; hidden block (poison shroom)
    .byte $24, $24, $24, $24  ; hidden block (power-up)
    .byte $ab, $ac, $ad, $ae  ; solid block (3-d block)
    .byte $5d, $5e, $5d, $5e  ; solid block (white wall)
    .byte $c1, $24, $c1, $24  ; bridge
    .byte $c6, $c8, $c7, $c9  ; bullet bill cannon barrel
    .byte $ca, $cc, $cb, $cd  ; bullet bill cannon top
    .byte $2a, $2a, $40, $40  ; bullet bill cannon bottom
    .byte $24, $24, $24, $24  ; blank used for jumpspring
    .byte $24, $47, $24, $47  ; half brick used for jumpspring
    .byte $82, $83, $84, $85  ; solid block (water level, green rock)
    .byte $b4, $b6, $b5, $b7  ; cracked rock terrain
    .byte $24, $47, $24, $47  ; half brick (not used)
    .byte $86, $8a, $87, $8b  ; water pipe top
    .byte $8e, $91, $8f, $92  ; water pipe bottom
    .byte $24, $2f, $24, $3d  ; flag ball (residual object)

off_smb2_main_palette_2_metatiles:
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
    .byte $6b, $70, $2c, $2d  ; cloud ledge left edge
    .byte $6c, $71, $6d, $72  ; cloud ledge middle
    .byte $6e, $73, $6f, $74  ; cloud ledge right edge

off_smb2_main_palette_3_metatiles:
    .byte $53, $55, $54, $56  ; question block (coin)
    .byte $53, $55, $54, $56  ; question block (power-up)
    .byte $53, $55, $54, $56  ; question block (poison shroom)
    .byte $a5, $a7, $a6, $a8  ; coin
    .byte $c2, $c4, $c3, $c5  ; underwater coin
    .byte $57, $59, $58, $5a  ; empty block
    .byte $7b, $7d, $7c, $7e  ; axe

; ------------------------------------------------------------------------------------

off_smb2_main_water_area_palette_packet:
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

off_smb2_main_ground_area_palette_packet:
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

off_smb2_main_underground_area_palette_packet:
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

off_smb2_main_castle_area_palette_packet:
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

off_smb2_main_day_snow_palette_packet:
    .byte $3f, $00, $04
    .byte $22, $30, $00, $10
    .byte $00

off_smb2_main_night_snow_palette_packet:
    .byte $3f, $00, $04
    .byte $0f, $30, $00, $10
    .byte $00

off_smb2_main_mushroom_palette_packet:
    .byte $3f, $00, $04
    .byte $22, $27, $16, $0f
    .byte $00

off_smb2_main_bowser_palette_packet:
    .byte $3f, $14, $04
    .byte $0f, $1a, $30, $27
    .byte $00

off_smb2_main_thank_you_message:
    .byte $25, $48, $10
    .byte $1d, $11, $0a, $17, $14, $24, $22, $18
    .byte $1e, $24, $16, $0a, $1b, $12, $18, $2b
    .byte $00

off_smb2_main_mushroom_retainer_msg:
    .byte $25, $c5, $16
    .byte $0b, $1e, $1d, $24, $18, $1e, $1b, $24
    .byte $19, $1b, $12, $17, $0c, $0e, $1c, $1c
    .byte $24, $12, $1c, $24, $12, $17
    .byte $26, $05, $0f
    .byte $0a, $17, $18, $1d, $11, $0e, $1b, $24
    .byte $0c, $0a, $1c, $1d, $15, $0e, $2b
    .byte $00

; ------------------------------------------------------------------------------------

sub_smb2_main_dispatch_inline_handler:
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
    JMP ($0006)  ; jump to the address we loaded

; ------------------------------------------------------------------------------------
