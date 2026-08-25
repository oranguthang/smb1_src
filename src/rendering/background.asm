;-------------------------------------------------------------------------------------
;$00 - temp vram buffer offset
;$01 - temp metatile buffer offset
;$02 - temp metatile graphics table offset
;$03 - used to store attribute bits
;$04 - used to determine attribute table row
;$05 - used to determine attribute table column
;$06 - metatile graphics table address low
;$07 - metatile graphics table address high

RenderAreaGraphics:
            lda CurrentColumnPos         ;store LSB of where we're at
            and #$01
            sta $05
            ldy VRAM_Buffer2_Offset      ;store vram buffer offset
            sty $00
            lda CurrentNTAddr_Low        ;get current name table address we're supposed to render
            sta VRAM_Buffer2+1,y
            lda CurrentNTAddr_High
            sta VRAM_Buffer2,y
            lda #$9a                     ;store length byte of 26 here with d7 set
            sta VRAM_Buffer2+2,y         ;to increment by 32 (in columns)
            lda #$00                     ;init attribute row
            sta $04
            tax
DrawMTLoop: stx $01                      ;store init value of 0 or incremented offset for buffer
            lda MetatileBuffer,x         ;get first metatile number, and mask out all but 2 MSB
            and #%11000000
            sta $03                      ;store attribute table bits here
            asl                          ;note that metatile format is:
            rol                          ;%xx000000 - attribute table bits,
            rol                          ;%00xxxxxx - metatile number
            tay                          ;rotate bits to d1-d0 and use as offset here
            lda MetatileGraphics_Low,y   ;get address to graphics table from here
            sta $06
            lda MetatileGraphics_High,y
            sta $07
            lda MetatileBuffer,x         ;get metatile number again
            asl                          ;multiply by 4 and use as tile offset
            asl
            sta $02
            lda AreaParserTaskNum        ;get current task number for level processing and
            and #%00000001               ;mask out all but LSB, then invert LSB, multiply by 2
            eor #%00000001               ;to get the correct column position in the metatile,
            asl                          ;then add to the tile offset so we can draw either side
            adc $02                      ;of the metatiles
            tay
            ldx $00                      ;use vram buffer offset from before as X
            lda ($06),y
            sta VRAM_Buffer2+3,x         ;get first tile number (top left or top right) and store
            iny
            lda ($06),y                  ;now get the second (bottom left or bottom right) and store
            sta VRAM_Buffer2+4,x
            ldy $04                      ;get current attribute row
            lda $05                      ;get LSB of current column where we're at, and
            bne RightCheck               ;branch if set (clear = left attrib, set = right)
            lda $01                      ;get current row we're rendering
            lsr                          ;branch if LSB set (clear = top left, set = bottom left)
            bcs LLeft
            rol $03                      ;rotate attribute bits 3 to the left
            rol $03                      ;thus in d1-d0, for upper left square
            rol $03
            jmp SetAttrib
RightCheck: lda $01                      ;get LSB of current row we're rendering
            lsr                          ;branch if set (clear = top right, set = bottom right)
            bcs NextMTRow
            lsr $03                      ;shift attribute bits 4 to the right
            lsr $03                      ;thus in d3-d2, for upper right square
            lsr $03
            lsr $03
            jmp SetAttrib
LLeft:      lsr $03                      ;shift attribute bits 2 to the right
            lsr $03                      ;thus in d5-d4 for lower left square
NextMTRow:  inc $04                      ;move onto next attribute row
SetAttrib:  lda AttributeBuffer,y        ;get previously saved bits from before
            ora $03                      ;if any, and put new bits, if any, onto
            sta AttributeBuffer,y        ;the old, and store
            inc $00                      ;increment vram buffer offset by 2
            inc $00
            ldx $01                      ;get current gfx buffer row, and check for
            inx                          ;the bottom of the screen
            cpx #$0d
            bcc DrawMTLoop               ;if not there yet, loop back
            ldy $00                      ;get current vram buffer offset, increment by 3
            iny                          ;(for name table address and length bytes)
            iny
            iny
            lda #$00
            sta VRAM_Buffer2,y           ;put null terminator at end of data for name table
            sty VRAM_Buffer2_Offset      ;store new buffer offset
            inc CurrentNTAddr_Low        ;increment name table address low
            lda CurrentNTAddr_Low        ;check current low byte
            and #%00011111               ;if no wraparound, just skip this part
            bne ExitDrawM
            lda #$80                     ;if wraparound occurs, make sure low byte stays
            sta CurrentNTAddr_Low        ;just under the status bar
            lda CurrentNTAddr_High       ;and then invert d2 of the name table address high
            eor #%00000100               ;to move onto the next appropriate name table
            sta CurrentNTAddr_High
ExitDrawM:  jmp SetVRAMCtrl              ;jump to set buffer to $0341 and leave

;-------------------------------------------------------------------------------------
;$00 - temp attribute table address high (big endian order this time!)
;$01 - temp attribute table address low

RenderAttributeTables:
             lda CurrentNTAddr_Low    ;get low byte of next name table address
             and #%00011111           ;to be written to, mask out all but 5 LSB,
             sec                      ;subtract four
             sbc #$04
             and #%00011111           ;mask out bits again and store
             sta $01
             lda CurrentNTAddr_High   ;get high byte and branch if borrow not set
             bcs SetATHigh
             eor #%00000100           ;otherwise invert d2
SetATHigh:   and #%00000100           ;mask out all other bits
             ora #$23                 ;add $2300 to the high byte and store
             sta $00
             lda $01                  ;get low byte - 4, divide by 4, add offset for
             lsr                      ;attribute table and store
             lsr
             adc #$c0                 ;we should now have the appropriate block of
             sta $01                  ;attribute table in our temp address
             ldx #$00
             ldy VRAM_Buffer2_Offset  ;get buffer offset
AttribLoop:  lda $00
             sta VRAM_Buffer2,y       ;store high byte of attribute table address
             lda $01
             clc                      ;get low byte, add 8 because we want to start
             adc #$08                 ;below the status bar, and store
             sta VRAM_Buffer2+1,y
             sta $01                  ;also store in temp again
             lda AttributeBuffer,x    ;fetch current attribute table byte and store
             sta VRAM_Buffer2+3,y     ;in the buffer
             lda #$01
             sta VRAM_Buffer2+2,y     ;store length of 1 in buffer
             lsr
             sta AttributeBuffer,x    ;clear current byte in attribute buffer
             iny                      ;increment buffer offset by 4 bytes
             iny
             iny
             iny
             inx                      ;increment attribute offset and check to see
             cpx #$07                 ;if we're at the end yet
             bcc AttribLoop
             sta VRAM_Buffer2,y       ;put null terminator at the end
             sty VRAM_Buffer2_Offset  ;store offset in case we want to do any more
SetVRAMCtrl: lda #$06
             sta VRAM_Buffer_AddrCtrl ;set buffer to $0341 and leave
             rts

;-------------------------------------------------------------------------------------

;$00 - used as temporary counter in ColorRotation

ColorRotatePalette:
       .byte $27, $27, $27, $17, $07, $17

BlankPalette:
       .byte $3f, $0c, $04, $ff, $ff, $ff, $ff, $00

;used based on area type
Palette3Data:
       .byte $0f, $07, $12, $0f
       .byte $0f, $07, $17, $0f
       .byte $0f, $07, $17, $1c
       .byte $0f, $07, $17, $00

ColorRotation:
              lda FrameCounter         ;get frame counter
              and #$07                 ;mask out all but three LSB
              bne ExitColorRot         ;branch if not set to zero to do this every eighth frame
              ldx VRAM_Buffer1_Offset  ;check vram buffer offset
              cpx #$31
              bcs ExitColorRot         ;if offset over 48 bytes, branch to leave
              tay                      ;otherwise use frame counter's 3 LSB as offset here
GetBlankPal:  lda BlankPalette,y       ;get blank palette for palette 3
              sta VRAM_Buffer1,x       ;store it in the vram buffer
              inx                      ;increment offsets
              iny
              cpy #$08
              bcc GetBlankPal          ;do this until all bytes are copied
              ldx VRAM_Buffer1_Offset  ;get current vram buffer offset
              lda #$03
              sta $00                  ;set counter here
              lda AreaType             ;get area type
              asl                      ;multiply by 4 to get proper offset
              asl
              tay                      ;save as offset here
GetAreaPal:   lda Palette3Data,y       ;fetch palette to be written based on area type
              sta VRAM_Buffer1+3,x     ;store it to overwrite blank palette in vram buffer
              iny
              inx
              dec $00                  ;decrement counter
              bpl GetAreaPal           ;do this until the palette is all copied
              ldx VRAM_Buffer1_Offset  ;get current vram buffer offset
              ldy ColorRotateOffset    ;get color cycling offset
              lda ColorRotatePalette,y
              sta VRAM_Buffer1+4,x     ;get and store current color in second slot of palette
              lda VRAM_Buffer1_Offset
              clc                      ;add seven bytes to vram buffer offset
              adc #$07
              sta VRAM_Buffer1_Offset
              inc ColorRotateOffset    ;increment color cycling offset
              lda ColorRotateOffset
              cmp #$06                 ;check to see if it's still in range
              bcc ExitColorRot         ;if so, branch to leave
              lda #$00
              sta ColorRotateOffset    ;otherwise, init to keep it in range
ExitColorRot: rts                      ;leave

;-------------------------------------------------------------------------------------
;$00 - temp store for offset control bit
;$01 - temp vram buffer offset
;$02 - temp store for vertical high nybble in block buffer routine
;$03 - temp adder for high byte of name table address
;$04, $05 - name table address low/high
;$06, $07 - block buffer address low/high

BlockGfxData:
       .byte $45, $45, $47, $47
       .byte $47, $47, $47, $47
       .byte $57, $58, $59, $5a
       .byte $24, $24, $24, $24
       .byte $26, $26, $26, $26

RemoveCoin_Axe:
              ldy #$41                 ;set low byte so offset points to $0341
              lda #$03                 ;load offset for default blank metatile
              ldx AreaType             ;check area type
              bne WriteBlankMT         ;if not water type, use offset
              lda #$04                 ;otherwise load offset for blank metatile used in water
WriteBlankMT: jsr PutBlockMetatile     ;do a sub to write blank metatile to vram buffer
              lda #$06
              sta VRAM_Buffer_AddrCtrl ;set vram address controller to $0341 and leave
              rts

ReplaceBlockMetatile:
       jsr WriteBlockMetatile    ;write metatile to vram buffer to replace block object
       inc Block_ResidualCounter ;increment unused counter (residual code)
       dec Block_RepFlag,x       ;decrement flag (residual code)
       rts                       ;leave

DestroyBlockMetatile:
       lda #$00       ;force blank metatile if branched/jumped to this point

WriteBlockMetatile:
             ldy #$03                ;load offset for blank metatile
             cmp #$00                ;check contents of A for blank metatile
             beq UseBOffset          ;branch if found (unconditional if branched from 8a6b)
             ldy #$00                ;load offset for brick metatile w/ line
             cmp #$58
             beq UseBOffset          ;use offset if metatile is brick with coins (w/ line)
             cmp #$51
             beq UseBOffset          ;use offset if metatile is breakable brick w/ line
             iny                     ;increment offset for brick metatile w/o line
             cmp #$5d
             beq UseBOffset          ;use offset if metatile is brick with coins (w/o line)
             cmp #$52
             beq UseBOffset          ;use offset if metatile is breakable brick w/o line
             iny                     ;if any other metatile, increment offset for empty block
UseBOffset:  tya                     ;put Y in A
             ldy VRAM_Buffer1_Offset ;get vram buffer offset
             iny                     ;move onto next byte
             jsr PutBlockMetatile    ;get appropriate block data and write to vram buffer
MoveVOffset: dey                     ;decrement vram buffer offset
             tya                     ;add 10 bytes to it
             clc
             adc #10
             jmp SetVRAMOffset       ;branch to store as new vram buffer offset

PutBlockMetatile:
            stx $00               ;store control bit from SprDataOffset_Ctrl
            sty $01               ;store vram buffer offset for next byte
            asl
            asl                   ;multiply A by four and use as X
            tax
            ldy #$20              ;load high byte for name table 0
            lda $06               ;get low byte of block buffer pointer
            cmp #$d0              ;check to see if we're on odd-page block buffer
            bcc SaveHAdder        ;if not, use current high byte
            ldy #$24              ;otherwise load high byte for name table 1
SaveHAdder: sty $03               ;save high byte here
            and #$0f              ;mask out high nybble of block buffer pointer
            asl                   ;multiply by 2 to get appropriate name table low byte
            sta $04               ;and then store it here
            lda #$00
            sta $05               ;initialize temp high byte
            lda $02               ;get vertical high nybble offset used in block buffer routine
            clc
            adc #$20              ;add 32 pixels for the status bar
            asl
            rol $05               ;shift and rotate d7 onto d0 and d6 into carry
            asl
            rol $05               ;shift and rotate d6 onto d0 and d5 into carry
            adc $04               ;add low byte of name table and carry to vertical high nybble
            sta $04               ;and store here
            lda $05               ;get whatever was in d7 and d6 of vertical high nybble
            adc #$00              ;add carry
            clc
            adc $03               ;then add high byte of name table
            sta $05               ;store here
            ldy $01               ;get vram buffer offset to be used
RemBridge:  lda BlockGfxData,x    ;write top left and top right
            sta VRAM_Buffer1+2,y  ;tile numbers into first spot
            lda BlockGfxData+1,x
            sta VRAM_Buffer1+3,y
            lda BlockGfxData+2,x  ;write bottom left and bottom
            sta VRAM_Buffer1+7,y  ;right tiles numbers into
            lda BlockGfxData+3,x  ;second spot
            sta VRAM_Buffer1+8,y
            lda $04
            sta VRAM_Buffer1,y    ;write low byte of name table
            clc                   ;into first slot as read
            adc #$20              ;add 32 bytes to value
            sta VRAM_Buffer1+5,y  ;write low byte of name table
            lda $05               ;plus 32 bytes into second slot
            sta VRAM_Buffer1-1,y  ;write high byte of name
            sta VRAM_Buffer1+4,y  ;table address to both slots
            lda #$02
            sta VRAM_Buffer1+1,y  ;put length of 2 in
            sta VRAM_Buffer1+6,y  ;both slots
            lda #$00
            sta VRAM_Buffer1+9,y  ;put null terminator at end
            ldx $00               ;get offset control bit here
            rts                   ;and leave

;-------------------------------------------------------------------------------------
;METATILE GRAPHICS TABLE

MetatileGraphics_Low:
  .byte <Palette0_MTiles, <Palette1_MTiles, <Palette2_MTiles, <Palette3_MTiles

MetatileGraphics_High:
  .byte >Palette0_MTiles, >Palette1_MTiles, >Palette2_MTiles, >Palette3_MTiles

Palette0_MTiles:
  .byte $24, $24, $24, $24 ;blank
  .byte $27, $27, $27, $27 ;black metatile
  .byte $24, $24, $24, $35 ;bush left
  .byte $36, $25, $37, $25 ;bush middle
  .byte $24, $38, $24, $24 ;bush right
  .byte $24, $30, $30, $26 ;mountain left
  .byte $26, $26, $34, $26 ;mountain left bottom/middle center
  .byte $24, $31, $24, $32 ;mountain middle top
  .byte $33, $26, $24, $33 ;mountain right
  .byte $34, $26, $26, $26 ;mountain right bottom
  .byte $26, $26, $26, $26 ;mountain middle bottom
  .byte $24, $c0, $24, $c0 ;bridge guardrail
  .byte $24, $7f, $7f, $24 ;chain
  .byte $b8, $ba, $b9, $bb ;tall tree top, top half
  .byte $b8, $bc, $b9, $bd ;short tree top
  .byte $ba, $bc, $bb, $bd ;tall tree top, bottom half
  .byte $60, $64, $61, $65 ;warp pipe end left, points up
  .byte $62, $66, $63, $67 ;warp pipe end right, points up
  .byte $60, $64, $61, $65 ;decoration pipe end left, points up
  .byte $62, $66, $63, $67 ;decoration pipe end right, points up
  .byte $68, $68, $69, $69 ;pipe shaft left
  .byte $26, $26, $6a, $6a ;pipe shaft right
  .byte $4b, $4c, $4d, $4e ;tree ledge left edge
  .byte $4d, $4f, $4d, $4f ;tree ledge middle
  .byte $4d, $4e, $50, $51 ;tree ledge right edge
  .byte $6b, $70, $2c, $2d ;mushroom left edge
  .byte $6c, $71, $6d, $72 ;mushroom middle
  .byte $6e, $73, $6f, $74 ;mushroom right edge
  .byte $86, $8a, $87, $8b ;sideways pipe end top
  .byte $88, $8c, $88, $8c ;sideways pipe shaft top
  .byte $89, $8d, $69, $69 ;sideways pipe joint top
  .byte $8e, $91, $8f, $92 ;sideways pipe end bottom
  .byte $26, $93, $26, $93 ;sideways pipe shaft bottom
  .byte $90, $94, $69, $69 ;sideways pipe joint bottom
  .byte $a4, $e9, $ea, $eb ;seaplant
  .byte $24, $24, $24, $24 ;blank, used on bricks or blocks that are hit
  .byte $24, $2f, $24, $3d ;flagpole ball
  .byte $a2, $a2, $a3, $a3 ;flagpole shaft
  .byte $24, $24, $24, $24 ;blank, used in conjunction with vines

Palette1_MTiles:
  .byte $a2, $a2, $a3, $a3 ;vertical rope
  .byte $99, $24, $99, $24 ;horizontal rope
  .byte $24, $a2, $3e, $3f ;left pulley
  .byte $5b, $5c, $24, $a3 ;right pulley
  .byte $24, $24, $24, $24 ;blank used for balance rope
  .byte $9d, $47, $9e, $47 ;castle top
  .byte $47, $47, $27, $27 ;castle window left
  .byte $47, $47, $47, $47 ;castle brick wall
  .byte $27, $27, $47, $47 ;castle window right
  .byte $a9, $47, $aa, $47 ;castle top w/ brick
  .byte $9b, $27, $9c, $27 ;entrance top
  .byte $27, $27, $27, $27 ;entrance bottom
  .byte $52, $52, $52, $52 ;green ledge stump
  .byte $80, $a0, $81, $a1 ;fence
  .byte $be, $be, $bf, $bf ;tree trunk
  .byte $75, $ba, $76, $bb ;mushroom stump top
  .byte $ba, $ba, $bb, $bb ;mushroom stump bottom
  .byte $45, $47, $45, $47 ;breakable brick w/ line
  .byte $47, $47, $47, $47 ;breakable brick
  .byte $45, $47, $45, $47 ;breakable brick (not used)
  .byte $b4, $b6, $b5, $b7 ;cracked rock terrain
  .byte $45, $47, $45, $47 ;brick with line (power-up)
  .byte $45, $47, $45, $47 ;brick with line (vine)
  .byte $45, $47, $45, $47 ;brick with line (star)
  .byte $45, $47, $45, $47 ;brick with line (coins)
  .byte $45, $47, $45, $47 ;brick with line (1-up)
  .byte $47, $47, $47, $47 ;brick (power-up)
  .byte $47, $47, $47, $47 ;brick (vine)
  .byte $47, $47, $47, $47 ;brick (star)
  .byte $47, $47, $47, $47 ;brick (coins)
  .byte $47, $47, $47, $47 ;brick (1-up)
  .byte $24, $24, $24, $24 ;hidden block (1 coin)
  .byte $24, $24, $24, $24 ;hidden block (1-up)
  .byte $ab, $ac, $ad, $ae ;solid block (3-d block)
  .byte $5d, $5e, $5d, $5e ;solid block (white wall)
  .byte $c1, $24, $c1, $24 ;bridge
  .byte $c6, $c8, $c7, $c9 ;bullet bill cannon barrel
  .byte $ca, $cc, $cb, $cd ;bullet bill cannon top
  .byte $2a, $2a, $40, $40 ;bullet bill cannon bottom
  .byte $24, $24, $24, $24 ;blank used for jumpspring
  .byte $24, $47, $24, $47 ;half brick used for jumpspring
  .byte $82, $83, $84, $85 ;solid block (water level, green rock)
  .byte $24, $47, $24, $47 ;half brick (???)
  .byte $86, $8a, $87, $8b ;water pipe top
  .byte $8e, $91, $8f, $92 ;water pipe bottom
  .byte $24, $2f, $24, $3d ;flag ball (residual object)

Palette2_MTiles:
  .byte $24, $24, $24, $35 ;cloud left
  .byte $36, $25, $37, $25 ;cloud middle
  .byte $24, $38, $24, $24 ;cloud right
  .byte $24, $24, $39, $24 ;cloud bottom left
  .byte $3a, $24, $3b, $24 ;cloud bottom middle
  .byte $3c, $24, $24, $24 ;cloud bottom right
  .byte $41, $26, $41, $26 ;water/lava top
  .byte $26, $26, $26, $26 ;water/lava
  .byte $b0, $b1, $b2, $b3 ;cloud level terrain
  .byte $77, $79, $77, $79 ;bowser's bridge

Palette3_MTiles:
  .byte $53, $55, $54, $56 ;question block (coin)
  .byte $53, $55, $54, $56 ;question block (power-up)
  .byte $a5, $a7, $a6, $a8 ;coin
  .byte $c2, $c4, $c3, $c5 ;underwater coin
  .byte $57, $59, $58, $5a ;empty block
  .byte $7b, $7d, $7c, $7e ;axe

;-------------------------------------------------------------------------------------
;VRAM BUFFER DATA FOR LOCATIONS IN PRG-ROM

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
;"THANK YOU MARIO!"
  .byte $25, $48, $10
  .byte $1d, $11, $0a, $17, $14, $24
  .byte $22, $18, $1e, $24
  .byte $16, $0a, $1b, $12, $18, $2b
  .byte $00

LuigiThanksMessage:
;"THANK YOU LUIGI!"
  .byte $25, $48, $10
  .byte $1d, $11, $0a, $17, $14, $24
  .byte $22, $18, $1e, $24
  .byte $15, $1e, $12, $10, $12, $2b
  .byte $00

MushroomRetainerSaved:
;"BUT OUR PRINCESS IS IN"
  .byte $25, $c5, $16
  .byte $0b, $1e, $1d, $24, $18, $1e, $1b, $24
  .byte $19, $1b, $12, $17, $0c, $0e, $1c, $1c, $24
  .byte $12, $1c, $24, $12, $17
;"ANOTHER CASTLE!"
  .byte $26, $05, $0f
  .byte $0a, $17, $18, $1d, $11, $0e, $1b, $24
  .byte $0c, $0a, $1c, $1d, $15, $0e, $2b, $00

PrincessSaved1:
;"YOUR QUEST IS OVER."
  .byte $25, $a7, $13
  .byte $22, $18, $1e, $1b, $24
  .byte $1a, $1e, $0e, $1c, $1d, $24
  .byte $12, $1c, $24, $18, $1f, $0e, $1b, $af
  .byte $00

PrincessSaved2:
;"WE PRESENT YOU A NEW QUEST."
  .byte $25, $e3, $1b
  .byte $20, $0e, $24
  .byte $19, $1b, $0e, $1c, $0e, $17, $1d, $24
  .byte $22, $18, $1e, $24, $0a, $24, $17, $0e, $20, $24
  .byte $1a, $1e, $0e, $1c, $1d, $af
  .byte $00

WorldSelectMessage1:
;"PUSH BUTTON B"
  .byte $26, $4a, $0d
  .byte $19, $1e, $1c, $11, $24
  .byte $0b, $1e, $1d, $1d, $18, $17, $24, $0b
  .byte $00

WorldSelectMessage2:
;"TO SELECT A WORLD"
  .byte $26, $88, $11
  .byte $1d, $18, $24, $1c, $0e, $15, $0e, $0c, $1d, $24
  .byte $0a, $24, $20, $18, $1b, $15, $0d
  .byte $00
