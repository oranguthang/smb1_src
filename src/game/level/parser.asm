; -------------------------------------------------------------------------------------

AreaParserTaskHandler:
    LDY AreaParserTaskNum  ; check number of tasks here
    BNE DoAPTasks  ; if already set, go ahead
    LDY #$08
    STY AreaParserTaskNum  ; otherwise, set eight by default
DoAPTasks:
    DEY
    TYA
    JSR AreaParserTasks
    DEC AreaParserTaskNum  ; if all tasks not complete do not
    BNE SkipATRender  ; render attribute table yet
    JSR RenderAttributeTables
SkipATRender:
    RTS

AreaParserTasks:
    JSR JumpEngine

    .word IncrementColumnPos
    .word RenderAreaGraphics
    .word RenderAreaGraphics
    .word AreaParserCore
    .word IncrementColumnPos
    .word RenderAreaGraphics
    .word RenderAreaGraphics
    .word AreaParserCore

; -------------------------------------------------------------------------------------

IncrementColumnPos:
    INC CurrentColumnPos  ; increment column where we're at
    LDA CurrentColumnPos
    AND #%00001111  ; mask out higher nybble
    BNE NoColWrap
    STA CurrentColumnPos  ; if no bits left set, wrap back to zero (0-f)
    INC CurrentPageLoc  ; and increment page number where we're at
NoColWrap:
    INC BlockBufferColumnPos  ; increment column offset where we're at
    LDA BlockBufferColumnPos
    AND #%00011111  ; mask out all but 5 LSB (0-1f)
    STA BlockBufferColumnPos  ; and save
    RTS

; -------------------------------------------------------------------------------------
; $00 - used as counter, store for low nybble for background, ceiling byte for terrain
; $01 - used to store floor byte for terrain
; $07 - used to store terrain metatile
; $06-$07 - used to store block buffer address

BSceneDataOffsets:
    .byte $00, $30, $60

BackSceneryData:
    .byte $93, $00, $00, $11, $12, $12, $13, $00  ; clouds
    .byte $00, $51, $52, $53, $00, $00, $00, $00
    .byte $00, $00, $01, $02, $02, $03, $00, $00
    .byte $00, $00, $00, $00, $91, $92, $93, $00
    .byte $00, $00, $00, $51, $52, $53, $41, $42
    .byte $43, $00, $00, $00, $00, $00, $91, $92

    .byte $97, $87, $88, $89, $99, $00, $00, $00  ; mountains and bushes
    .byte $11, $12, $13, $a4, $a5, $a5, $a5, $a6
    .byte $97, $98, $99, $01, $02, $03, $00, $a4
    .byte $a5, $a6, $00, $11, $12, $12, $12, $13
    .byte $00, $00, $00, $00, $01, $02, $02, $03
    .byte $00, $a4, $a5, $a5, $a6, $00, $00, $00

    .byte $11, $12, $12, $13, $00, $00, $00, $00  ; trees and fences
    .byte $00, $00, $00, $9c, $00, $8b, $aa, $aa
    .byte $aa, $aa, $11, $12, $13, $8b, $00, $9c
    .byte $9c, $00, $00, $01, $02, $03, $11, $12
    .byte $12, $13, $00, $00, $00, $00, $aa, $aa
    .byte $9c, $aa, $00, $8b, $00, $01, $02, $03

BackSceneryMetatiles:
    .byte $80, $83, $00  ; cloud left
    .byte $81, $84, $00  ; cloud middle
    .byte $82, $85, $00  ; cloud right
    .byte $02, $00, $00  ; bush left
    .byte $03, $00, $00  ; bush middle
    .byte $04, $00, $00  ; bush right
    .byte $00, $05, $06  ; mountain left
    .byte $07, $06, $0a  ; mountain middle
    .byte $00, $08, $09  ; mountain right
    .byte $4d, $00, $00  ; fence
    .byte $0d, $0f, $4e  ; tall tree
    .byte $0e, $4e, $4e  ; short tree

FSceneDataOffsets:
    .byte $00, $0d, $1a

ForeSceneryData:
    .byte $86, $87, $87, $87, $87, $87, $87  ; in water
    .byte $87, $87, $87, $87, $69, $69

    .byte $00, $00, $00, $00, $00, $45, $47  ; wall
    .byte $47, $47, $47, $47, $00, $00

    .byte $00, $00, $00, $00, $00, $00, $00  ; over water
    .byte $00, $00, $00, $00, $86, $87

TerrainMetatiles:
    .byte $69, $54, $52, $62

TerrainRenderBits:
    .byte %00000000, %00000000  ; no ceiling or floor
    .byte %00000000, %00011000  ; no ceiling, floor 2
    .byte %00000001, %00011000  ; ceiling 1, floor 2
    .byte %00000111, %00011000  ; ceiling 3, floor 2
    .byte %00001111, %00011000  ; ceiling 4, floor 2
    .byte %11111111, %00011000  ; ceiling 8, floor 2
    .byte %00000001, %00011111  ; ceiling 1, floor 5
    .byte %00000111, %00011111  ; ceiling 3, floor 5
    .byte %00001111, %00011111  ; ceiling 4, floor 5
    .byte %10000001, %00011111  ; ceiling 1, floor 6
    .byte %00000001, %00000000  ; ceiling 1, no floor
    .byte %10001111, %00011111  ; ceiling 4, floor 6
    .byte %11110001, %00011111  ; ceiling 1, floor 9
    .byte %11111001, %00011000  ; ceiling 1, middle 5, floor 2
    .byte %11110001, %00011000  ; ceiling 1, middle 4, floor 2
    .byte %11111111, %00011111  ; completely solid top to bottom

AreaParserCore:
    LDA BackloadingFlag  ; check to see if we are starting right of start
    BEQ RenderSceneryTerrain  ; if not, go ahead and render background, foreground and terrain
    JSR ProcessAreaData  ; otherwise skip ahead and load level data

RenderSceneryTerrain:
    LDX #$0c
    LDA #$00
ClrMTBuf:
    STA MetatileBuffer,x  ; clear out metatile buffer
    DEX
    BPL ClrMTBuf
    LDY BackgroundScenery  ; do we need to render the background scenery?
    BEQ RendFore  ; if not, skip to check the foreground
    LDA CurrentPageLoc  ; otherwise check for every third page
ThirdP:
    CMP #$03
    BMI RendBack  ; if less than three we're there
    SEC
    SBC #$03  ; if 3 or more, subtract 3 and
    BPL ThirdP  ; do an unconditional branch
RendBack:
    ASL  ; move results to higher nybble
    ASL
    ASL
    ASL
    ADC BSceneDataOffsets-1,y  ; add to it offset loaded from here
    ADC CurrentColumnPos  ; add to the result our current column position
    TAX
    LDA BackSceneryData,x  ; load data from sum of offsets
    BEQ RendFore  ; if zero, no scenery for that part
    PHA
    AND #$0f  ; save to stack and clear high nybble
    SEC
    SBC #$01  ; subtract one (because low nybble is $01-$0c)
    STA $00  ; save low nybble
    ASL  ; multiply by three (shift to left and add result to old one)
    ADC $00  ; note that since d7 was nulled, the carry flag is always clear
    TAX  ; save as offset for background scenery metatile data
    PLA  ; get high nybble from stack, move low
    LSR
    LSR
    LSR
    LSR
    TAY  ; use as second offset (used to determine height)
    LDA #$03  ; use previously saved memory location for counter
    STA $00
SceLoop1:
    LDA BackSceneryMetatiles,x  ; load metatile data from offset of (lsb - 1) * 3
    STA MetatileBuffer,y  ; store into buffer from offset of (msb / 16)
    INX
    INY
    CPY #$0b  ; if at this location, leave loop
    BEQ RendFore
    DEC $00  ; decrement until counter expires, barring exception
    BNE SceLoop1
RendFore:
    LDX ForegroundScenery  ; check for foreground data needed or not
    BEQ RendTerr  ; if not, skip this part
    LDY FSceneDataOffsets-1,x  ; load offset from location offset by header value, then
    LDX #$00  ; reinit X
SceLoop2:
    LDA ForeSceneryData,y  ; load data until counter expires
    BEQ NoFore  ; do not store if zero found
    STA MetatileBuffer,x
NoFore:
    INY
    INX
    CPX #$0d  ; store up to end of metatile buffer
    BNE SceLoop2
RendTerr:
    LDY AreaType  ; check world type for water level
    BNE TerMTile  ; if not water level, skip this part
    LDA WorldNumber  ; check world number, if not world number eight
    CMP #World8  ; then skip this part
    BNE TerMTile
    LDA #$62  ; if set as water level and world number eight,
    JMP StoreMT  ; use castle wall metatile as terrain type
TerMTile:
    LDA TerrainMetatiles,y  ; otherwise get appropriate metatile for area type
    LDY CloudTypeOverride  ; check for cloud type override
    BEQ StoreMT  ; if not set, keep value otherwise
    LDA #$88  ; use cloud block terrain
StoreMT:
    STA $07  ; store value here
    LDX #$00  ; initialize X, use as metatile buffer offset
    LDA TerrainControl  ; use yet another value from the header
    ASL  ; multiply by 2 and use as yet another offset
    TAY
TerrLoop:
    LDA TerrainRenderBits,y  ; get one of the terrain rendering bit data
    STA $00
    INY  ; increment Y and use as offset next time around
    STY $01
    LDA CloudTypeOverride  ; skip if value here is zero
    BEQ NoCloud2
    CPX #$00  ; otherwise, check if we're doing the ceiling byte
    BEQ NoCloud2
    LDA $00  ; if not, mask out all but d3
    AND #%00001000
    STA $00
NoCloud2:
    LDY #$00  ; start at beginning of bitmasks
TerrBChk:
    LDA Bitmasks,y  ; load bitmask, then perform AND on contents of first byte
    BIT $00
    BEQ NextTBit  ; if not set, skip this part (do not write terrain to buffer)
    LDA $07
    STA MetatileBuffer,x  ; load terrain type metatile number and store into buffer here
NextTBit:
    INX  ; continue until end of buffer
    CPX #$0d
    BEQ RendBBuf  ; if we're at the end, break out of this loop
    LDA AreaType  ; check world type for underground area
    CMP #$02
    BNE EndUChk  ; if not underground, skip this part
    CPX #$0b
    BNE EndUChk  ; if we're at the bottom of the screen, override
    LDA #$54  ; old terrain type with ground level terrain type
    STA $07
EndUChk:
    INY  ; increment bitmasks offset in Y
    CPY #$08
    BNE TerrBChk  ; if not all bits checked, loop back
    LDY $01
    BNE TerrLoop  ; unconditional branch, use Y to load next byte
RendBBuf:
    JSR ProcessAreaData  ; do the area data loading routine now
    LDA BlockBufferColumnPos
    JSR GetBlockBufferAddr  ; get block buffer address from where we're at
    LDX #$00
    LDY #$00  ; init index regs and start at beginning of smaller buffer
ChkMTLow:
    STY $00
    LDA MetatileBuffer,x  ; load stored metatile number
    AND #%11000000  ; mask out all but 2 MSB
    ASL
    ROL  ; make %xx000000 into %000000xx
    ROL
    TAY  ; use as offset in Y
    LDA MetatileBuffer,x  ; reload original unmasked value here
    CMP BlockBuffLowBounds,y  ; check for certain values depending on bits set
    BCS StrBlock  ; if equal or greater, branch
    LDA #$00  ; if less, init value before storing
StrBlock:
    LDY $00  ; get offset for block buffer
    STA ($06),y  ; store value into block buffer
    TYA
    CLC  ; add 16 (move down one row) to offset
    ADC #$10
    TAY
    INX  ; increment column value
    CPX #$0d
    BCC ChkMTLow  ; continue until we pass last row, then leave
    RTS

; numbers lower than these with the same attribute bits
; will not be stored in the block buffer
BlockBuffLowBounds:
    .byte $10, $51, $88, $c0

; -------------------------------------------------------------------------------------
; $00 - used to store area object identifier
; $07 - used as adder to find proper area object code

ProcessAreaData:
    LDX #$02  ; start at the end of area object buffer
ProcADLoop:
    STX ObjectOffset
    LDA #$00  ; reset flag
    STA BehindAreaParserFlag
    LDY AreaDataOffset  ; get offset of area data pointer
    LDA (AreaData),y  ; get first byte of area object
    CMP #$fd  ; if end-of-area, skip all this crap
    BEQ RdyDecode
    LDA AreaObjectLength,x  ; check area object buffer flag
    BPL RdyDecode  ; if buffer not negative, branch, otherwise
    INY
    LDA (AreaData),y  ; get second byte of area object
    ASL  ; check for page select bit (d7), branch if not set
    BCC Chk1Row13
    LDA AreaObjectPageSel  ; check page select
    BNE Chk1Row13
    INC AreaObjectPageSel  ; if not already set, set it now
    INC AreaObjectPageLoc  ; and increment page location
Chk1Row13:
    DEY
    LDA (AreaData),y  ; reread first byte of level object
    AND #$0f  ; mask out high nybble
    CMP #$0d  ; row 13?
    BNE Chk1Row14
    INY  ; if so, reread second byte of level object
    LDA (AreaData),y
    DEY  ; decrement to get ready to read first byte
    AND #%01000000  ; check for d6 set (if not, object is page control)
    BNE CheckRear
    LDA AreaObjectPageSel  ; if page select is set, do not reread
    BNE CheckRear
    INY  ; if d6 not set, reread second byte
    LDA (AreaData),y
    AND #%00011111  ; mask out all but 5 LSB and store in page control
    STA AreaObjectPageLoc
    INC AreaObjectPageSel  ; increment page select
    JMP NextAObj
Chk1Row14:
    CMP #$0e  ; row 14?
    BNE CheckRear
    LDA BackloadingFlag  ; check flag for saved page number and branch if set
    BNE RdyDecode  ; to render the object (otherwise bg might not look right)
CheckRear:
    LDA AreaObjectPageLoc  ; check to see if current page of level object is
    CMP CurrentPageLoc  ; behind current page of renderer
    BCC SetBehind  ; if so branch
RdyDecode:
    JSR DecodeAreaData  ; do sub and do not turn on flag
    JMP ChkLength
SetBehind:
    INC BehindAreaParserFlag  ; turn on flag if object is behind renderer
NextAObj:
    JSR IncAreaObjOffset  ; increment buffer offset and move on
ChkLength:
    LDX ObjectOffset  ; get buffer offset
    LDA AreaObjectLength,x  ; check object length for anything stored here
    BMI ProcLoopb  ; if not, branch to handle loopback
    DEC AreaObjectLength,x  ; otherwise decrement length or get rid of it
ProcLoopb:
    DEX  ; decrement buffer offset
    BPL ProcADLoop  ; and loopback unless exceeded buffer
    LDA BehindAreaParserFlag  ; check for flag set if objects were behind renderer
    BNE ProcessAreaData  ; branch if true to load more level data, otherwise
    LDA BackloadingFlag  ; check for flag set if starting right of page $00
    BNE ProcessAreaData  ; branch if true to load more level data, otherwise leave
EndAParse:
    RTS

IncAreaObjOffset:
    INC AreaDataOffset  ; increment offset of level pointer
    INC AreaDataOffset
    LDA #$00  ; reset page select
    STA AreaObjectPageSel
    RTS

DecodeAreaData:
    LDA AreaObjectLength,x  ; check current buffer flag
    BMI Chk1stB
    LDY AreaObjOffsetBuffer,x  ; if not, get offset from buffer
Chk1stB:
    LDX #$10  ; load offset of 16 for special row 15
    LDA (AreaData),y  ; get first byte of level object again
    CMP #$fd
    BEQ EndAParse  ; if end of level, leave this routine
    AND #$0f  ; otherwise, mask out low nybble
    CMP #$0f  ; row 15?
    BEQ ChkRow14  ; if so, keep the offset of 16
    LDX #$08  ; otherwise load offset of 8 for special row 12
    CMP #$0c  ; row 12?
    BEQ ChkRow14  ; if so, keep the offset value of 8
    LDX #$00  ; otherwise nullify value by default
ChkRow14:
    STX $07  ; store whatever value we just loaded here
    LDX ObjectOffset  ; get object offset again
    CMP #$0e  ; row 14?
    BNE ChkRow13
    LDA #$00  ; if so, load offset with $00
    STA $07
    LDA #$2e  ; and load A with another value
    BNE NormObj  ; unconditional branch
ChkRow13:
    CMP #$0d  ; row 13?
    BNE ChkSRows
    LDA #$22  ; if so, load offset with 34
    STA $07
    INY  ; get next byte
    LDA (AreaData),y
    AND #%01000000  ; mask out all but d6 (page control obj bit)
    BEQ LeavePar  ; if d6 clear, branch to leave (we handled this earlier)
    LDA (AreaData),y  ; otherwise, get byte again
    AND #%01111111  ; mask out d7
    CMP #$4b  ; check for loop command in low nybble
    BNE Mask2MSB  ; (plus d6 set for object other than page control)
    INC LoopCommand  ; if loop command, set loop command flag
Mask2MSB:
    AND #%00111111  ; mask out d7 and d6
    JMP NormObj  ; and jump
ChkSRows:
    CMP #$0c  ; row 12-15?
    BCS SpecObj
    INY  ; if not, get second byte of level object
    LDA (AreaData),y
    AND #%01110000  ; mask out all but d6-d4
    BNE LrgObj  ; if any bits set, branch to handle large object
    LDA #$16
    STA $07  ; otherwise set offset of 24 for small object
    LDA (AreaData),y  ; reload second byte of level object
    AND #%00001111  ; mask out higher nybble and jump
    JMP NormObj
LrgObj:
    STA $00  ; store value here (branch for large objects)
    CMP #$70  ; check for vertical pipe object
    BNE NotWPipe
    LDA (AreaData),y  ; if not, reload second byte
    AND #%00001000  ; mask out all but d3 (usage control bit)
    BEQ NotWPipe  ; if d3 clear, branch to get original value
    LDA #$00  ; otherwise, nullify value for warp pipe
    STA $00
NotWPipe:
    LDA $00  ; get value and jump ahead
    JMP MoveAOId
SpecObj:
    INY  ; branch here for rows 12-15
    LDA (AreaData),y
    AND #%01110000  ; get next byte and mask out all but d6-d4
MoveAOId:
    LSR  ; move d6-d4 to lower nybble
    LSR
    LSR
    LSR
NormObj:
    STA $00  ; store value here (branch for small objects and rows 13 and 14)
    LDA AreaObjectLength,x  ; is there something stored here already?
    BPL RunAObj  ; if so, branch to do its particular sub
    LDA AreaObjectPageLoc  ; otherwise check to see if the object we've loaded is on the
    CMP CurrentPageLoc  ; same page as the renderer, and if so, branch
    BEQ InitRear
    LDY AreaDataOffset  ; if not, get old offset of level pointer
    LDA (AreaData),y  ; and reload first byte
    AND #%00001111
    CMP #$0e  ; row 14?
    BNE LeavePar
    LDA BackloadingFlag  ; if so, check backloading flag
    BNE StrAObj  ; if set, branch to render object, else leave
LeavePar:
    RTS
InitRear:
    LDA BackloadingFlag  ; check backloading flag to see if it's been initialized
    BEQ BackColC  ; branch to column-wise check
    LDA #$00  ; if not, initialize both backloading and
    STA BackloadingFlag  ; behind-renderer flags and leave
    STA BehindAreaParserFlag
    STA ObjectOffset
LoopCmdE:
    RTS
BackColC:
    LDY AreaDataOffset  ; get first byte again
    LDA (AreaData),y
    AND #%11110000  ; mask out low nybble and move high to low
    LSR
    LSR
    LSR
    LSR
    CMP CurrentColumnPos  ; is this where we're at?
    BNE LeavePar  ; if not, branch to leave
StrAObj:
    LDA AreaDataOffset  ; if so, load area obj offset and store in buffer
    STA AreaObjOffsetBuffer,x
    JSR IncAreaObjOffset  ; do sub to increment to next object data
RunAObj:
    LDA $00  ; get stored value and add offset to it
    CLC  ; then use the jump engine with current contents of A
    ADC $07
    JSR JumpEngine

; large objects (rows $00-$0b or 00-11, d6-d4 set)
    .word VerticalPipe  ; used by warp pipes
    .word AreaStyleObject
    .word RowOfBricks
    .word RowOfSolidBlocks
    .word RowOfCoins
    .word ColumnOfBricks
    .word ColumnOfSolidBlocks
    .word VerticalPipe  ; used by decoration pipes

; objects for special row $0c or 12
    .word Hole_Empty
    .word PulleyRopeObject
    .word Bridge_High
    .word Bridge_Middle
    .word Bridge_Low
    .word Hole_Water
    .word QuestionBlockRow_High
    .word QuestionBlockRow_Low

; objects for special row $0f or 15
    .word EndlessRope
    .word BalancePlatRope
    .word CastleObject
    .word StaircaseObject
    .word ExitPipe
    .word FlagBalls_Residual

; small objects (rows $00-$0b or 00-11, d6-d4 all clear)
    .word QuestionBlock  ; power-up
    .word QuestionBlock  ; coin
    .word QuestionBlock  ; hidden, coin
    .word Hidden1UpBlock  ; hidden, 1-up
    .word BrickWithItem  ; brick, power-up
    .word BrickWithItem  ; brick, vine
    .word BrickWithItem  ; brick, star
    .word BrickWithCoins  ; brick, coins
    .word BrickWithItem  ; brick, 1-up
    .word WaterPipe
    .word EmptyBlock
    .word Jumpspring

; objects for special row $0d or 13 (d6 set)
    .word IntroPipe
    .word FlagpoleObject
    .word AxeObj
    .word ChainObj
    .word CastleBridgeObj
    .word ScrollLockObject_Warp
    .word ScrollLockObject
    .word ScrollLockObject
    .word AreaFrenzy  ; flying cheep-cheeps
    .word AreaFrenzy  ; bullet bills or swimming cheep-cheeps
    .word AreaFrenzy  ; stop frenzy
    .word LoopCmdE

; object for special row $0e or 14
    .word AlterAreaAttributes
