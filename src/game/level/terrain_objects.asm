; --------------------------------

Hole_Water:
    JSR ChkLrgObjLength  ; get low nybble and save as length
    LDA #$86  ; render waves
    STA ram_metatile_buffer+10
    LDX #$0b
    LDY #$01  ; now render the water underneath
    LDA #$87
    JMP RenderUnderPart

; --------------------------------

QuestionBlockRow_High:
    LDA #$03  ; start on the fourth row
    .byte $2c  ; BIT instruction opcode

QuestionBlockRow_Low:
    LDA #$07  ; start on the eighth row
    PHA  ; save whatever row to the stack for now
    JSR ChkLrgObjLength  ; get low nybble and save as length
    PLA
    TAX  ; render question boxes with coins
    LDA #$c0
    STA ram_metatile_buffer,x
    RTS

; --------------------------------

Bridge_High:
    LDA #$06  ; start on the seventh row from top of screen
    .byte $2c  ; BIT instruction opcode

Bridge_Middle:
    LDA #$07  ; start on the eighth row
    .byte $2c  ; BIT instruction opcode

Bridge_Low:
    LDA #$09  ; start on the tenth row
    PHA  ; save whatever row to the stack for now
    JSR ChkLrgObjLength  ; get low nybble and save as length
    PLA
    TAX  ; render bridge railing
    LDA #$0b
    STA ram_metatile_buffer,x
    INX
    LDY #$00  ; now render the bridge itself
    LDA #$63
    JMP RenderUnderPart

; --------------------------------

FlagBalls_Residual:
    JSR GetLrgObjAttrib  ; get low nybble from object byte
    LDX #$02  ; render flag balls on third row from top
    LDA #$6d  ; of screen downwards based on low nybble
    JMP RenderUnderPart

; --------------------------------

FlagpoleObject:
    LDA #$24  ; render flagpole ball on top
    STA ram_metatile_buffer
    LDX #$01  ; now render the flagpole shaft
    LDY #$08
    LDA #$25
    JSR RenderUnderPart
    LDA #$61  ; render solid block at the bottom
    STA ram_metatile_buffer+10
    JSR GetAreaObjXPosition
    SEC  ; get pixel coordinate of where the flagpole is,
    SBC #$08  ; subtract eight pixels and use as horizontal
    STA ram_enemy_x_position+5  ; coordinate for the flag
    LDA ram_current_page_loc
    SBC #$00  ; subtract borrow from page location and use as
    STA ram_enemy_page_loc+5  ; page location for the flag
    LDA #$30
    STA ram_enemy_y_position+5  ; set vertical coordinate for flag
    LDA #$b0
    STA ram_flagpole_f_num_y_pos  ; set initial vertical coordinate for flagpole's floatey number
    LDA #con_flagpole_flag_object
    STA ram_enemy_id+5  ; set flag identifier, note that identifier and coordinates
    INC ram_enemy_flag+5  ; use last space in enemy object buffer
    RTS

; --------------------------------

EndlessRope:
    LDX #$00  ; render rope from the top to the bottom of screen
    LDY #$0f
    JMP DrawRope

BalancePlatRope:
    TXA  ; save object buffer offset for now
    PHA
    LDX #$01  ; blank out all from second row to the bottom
    LDY #$0f  ; with blank used for balance platform rope
    LDA #$44
    JSR RenderUnderPart
    PLA  ; get back object buffer offset
    TAX
    JSR GetLrgObjAttrib  ; get vertical length from lower nybble
    LDX #$01
DrawRope:
    LDA #$40  ; render the actual rope
    JMP RenderUnderPart

; --------------------------------

CoinMetatileData:
    .byte $c3, $c2, $c2, $c2

RowOfCoins:
    LDY ram_area_type  ; get area type
    LDA CoinMetatileData,y  ; load appropriate coin metatile
    JMP GetRow

; --------------------------------

C_ObjectRow:
    .byte $06, $07, $08

C_ObjectMetatile:
    .byte $c5, $0c, $89

CastleBridgeObj:
    LDY #$0c  ; load length of 13 columns
    JSR ChkLrgObjFixedLength
    JMP ChainObj

AxeObj:
    LDA #$08  ; load bowser's palette into sprite portion of palette
    STA ram_vram_buffer_addr_ctrl

ChainObj:
    LDY $00  ; get value loaded earlier from decoder
    LDX C_ObjectRow-2,y  ; get appropriate row and metatile for object
    LDA C_ObjectMetatile-2,y
    JMP ColObj

EmptyBlock:
    JSR GetLrgObjAttrib  ; get row location
    LDX $07
    LDA #$c4
ColObj:
    LDY #$00  ; column length of 1
    JMP RenderUnderPart

; --------------------------------

SolidBlockMetatiles:
    .byte $69, $61, $61, $62

BrickMetatiles:
    .byte $22, $51, $52, $52
    .byte $88  ; used only by row of bricks object

RowOfBricks:
    LDY ram_area_type  ; load area type obtained from area offset pointer
    LDA ram_cloud_type_override  ; check for cloud type override
    BEQ DrawBricks
    LDY #$04  ; if cloud type, override area type
DrawBricks:
    LDA BrickMetatiles,y  ; get appropriate metatile
    JMP GetRow  ; and go render it

RowOfSolidBlocks:
    LDY ram_area_type  ; load area type obtained from area offset pointer
    LDA SolidBlockMetatiles,y  ; get metatile
GetRow:
    PHA  ; store metatile here
    JSR ChkLrgObjLength  ; get row number, load length
DrawRow:
    LDX $07
    LDY #$00  ; set vertical height of 1
    PLA
    JMP RenderUnderPart  ; render object

ColumnOfBricks:
    LDY ram_area_type  ; load area type obtained from area offset
    LDA BrickMetatiles,y  ; get metatile (no cloud override as for row)
    JMP GetRow2

ColumnOfSolidBlocks:
    LDY ram_area_type  ; load area type obtained from area offset
    LDA SolidBlockMetatiles,y  ; get metatile
GetRow2:
    PHA  ; save metatile to stack for now
    JSR GetLrgObjAttrib  ; get length and row
    PLA  ; restore metatile
    LDX $07  ; get starting row
    JMP RenderUnderPart  ; now render the column

; --------------------------------

BulletBillCannon:
    JSR GetLrgObjAttrib  ; get row and length of bullet bill cannon
    LDX $07  ; start at first row
    LDA #$64  ; render bullet bill cannon
    STA ram_metatile_buffer,x
    INX
    DEY  ; done yet?
    BMI SetupCannon
    LDA #$65  ; if not, render middle part
    STA ram_metatile_buffer,x
    INX
    DEY  ; done yet?
    BMI SetupCannon
    LDA #$66  ; if not, render bottom until length expires
    JSR RenderUnderPart
SetupCannon:
    LDX ram_cannon_offset  ; get offset for data used by cannons and whirlpools
    JSR GetAreaObjYPosition  ; get proper vertical coordinate for cannon
    STA ram_cannon_y_position,x  ; and store it here
    LDA ram_current_page_loc
    STA ram_cannon_page_loc,x  ; store page number for cannon here
    JSR GetAreaObjXPosition  ; get proper horizontal coordinate for cannon
    STA ram_cannon_x_position,x  ; and store it here
    INX
    CPX #$06  ; increment and check offset
    BCC StrCOffset  ; if not yet reached sixth cannon, branch to save offset
    LDX #$00  ; otherwise initialize it
StrCOffset:
    STX ram_cannon_offset  ; save new offset and leave
    RTS

; --------------------------------

StaircaseHeightData:
    .byte $07, $07, $06, $05, $04, $03, $02, $01, $00

StaircaseRowData:
    .byte $03, $03, $04, $05, $06, $07, $08, $09, $0a

StaircaseObject:
    JSR ChkLrgObjLength  ; check and load length
    BCC NextStair  ; if length already loaded, skip init part
    LDA #$09  ; start past the end for the bottom
    STA ram_staircase_control  ; of the staircase
NextStair:
    DEC ram_staircase_control  ; move onto next step (or first if starting)
    LDY ram_staircase_control
    LDX StaircaseRowData,y  ; get starting row and height to render
    LDA StaircaseHeightData,y
    TAY
    LDA #$61  ; now render solid block staircase
    JMP RenderUnderPart

; --------------------------------

Jumpspring:
    JSR GetLrgObjAttrib
    JSR FindEmptyEnemySlot  ; find empty space in enemy object buffer
    JSR GetAreaObjXPosition  ; get horizontal coordinate for jumpspring
    STA ram_enemy_x_position,x  ; and store
    LDA ram_current_page_loc  ; store page location of jumpspring
    STA ram_enemy_page_loc,x
    JSR GetAreaObjYPosition  ; get vertical coordinate for jumpspring
    STA ram_enemy_y_position,x  ; and store
    STA ram_jumpspring_fixed_y_pos,x  ; store as permanent coordinate here
    LDA #con_jumpspring_object
    STA ram_enemy_id,x  ; write jumpspring object to enemy object buffer
    LDY #$01
    STY ram_enemy_y_high_pos,x  ; store vertical high byte
    INC ram_enemy_flag,x  ; set flag for enemy object buffer
    LDX $07
    LDA #$67  ; draw metatiles in two rows where jumpspring is
    STA ram_metatile_buffer,x
    LDA #$68
    STA ram_metatile_buffer+1,x
    RTS

; --------------------------------
; $07 - used to save ID of brick object

Hidden1UpBlock:
    LDA ram_hidden1_up_flag  ; if flag not set, do not render object
    BEQ ExitDecBlock
    LDA #$00  ; if set, init for the next one
    STA ram_hidden1_up_flag
    JMP BrickWithItem  ; jump to code shared with unbreakable bricks

QuestionBlock:
    JSR GetAreaObjectID  ; get value from level decoder routine
    JMP DrawQBlk  ; go to render it

BrickWithCoins:
    LDA #$00  ; initialize multi-coin timer flag
    STA ram_brick_coin_timer_flag

BrickWithItem:
    JSR GetAreaObjectID  ; save area object ID
    STY $07
    LDA #$00  ; load default adder for bricks with lines
    LDY ram_area_type  ; check level type for ground level
    DEY
    BEQ BWithL  ; if ground type, do not start with 5
    LDA #$05  ; otherwise use adder for bricks without lines
BWithL:
    CLC  ; add object ID to adder
    ADC $07
    TAY  ; use as offset for metatile
DrawQBlk:
    LDA BrickQBlockMetatiles,y  ; get appropriate metatile for brick (question block
    PHA  ; if branched to here from question block routine)
    JSR GetLrgObjAttrib  ; get row from location byte
    JMP DrawRow  ; now render the object

GetAreaObjectID:
    LDA $00  ; get value saved from area parser routine
    SEC
    SBC #$00  ; possibly residual code
    TAY  ; save to Y
ExitDecBlock:
    RTS

; --------------------------------

HoleMetatiles:
    .byte $87, $00, $00, $00

Hole_Empty:
    JSR ChkLrgObjLength  ; get lower nybble and save as length
    BCC NoWhirlP  ; skip this part if length already loaded
    LDA ram_area_type  ; check for water type level
    BNE NoWhirlP  ; if not water type, skip this part
    LDX ram_whirlpool_offset  ; get offset for data used by cannons and whirlpools
    JSR GetAreaObjXPosition  ; get proper vertical coordinate of where we're at
    SEC
    SBC #$10  ; subtract 16 pixels
    STA ram_whirlpool_left_extent,x  ; store as left extent of whirlpool
    LDA ram_current_page_loc  ; get page location of where we're at
    SBC #$00  ; subtract borrow
    STA ram_whirlpool_page_loc,x  ; save as page location of whirlpool
    INY
    INY  ; increment length by 2
    TYA
    ASL  ; multiply by 16 to get size of whirlpool
    ASL  ; note that whirlpool will always be
    ASL  ; two blocks bigger than actual size of hole
    ASL  ; and extend one block beyond each edge
    STA ram_whirlpool_length,x  ; save size of whirlpool here
    INX
    CPX #$05  ; increment and check offset
    BCC StrWOffset  ; if not yet reached fifth whirlpool, branch to save offset
    LDX #$00  ; otherwise initialize it
StrWOffset:
    STX ram_whirlpool_offset  ; save new offset here
NoWhirlP:
    LDX ram_area_type  ; get appropriate metatile, then
    LDA HoleMetatiles,x  ; render the hole proper
    LDX #$08
    LDY #$0f  ; start at ninth row and go to bottom, run RenderUnderPart

; --------------------------------

RenderUnderPart:
    STY ram_area_object_height  ; store vertical length to render
    LDY ram_metatile_buffer,x  ; check current spot to see if there's something
    BEQ DrawThisRow  ; we need to keep, if nothing, go ahead
    CPY #$17
    BEQ WaitOneRow  ; if middle part (tree ledge), wait until next row
    CPY #$1a
    BEQ WaitOneRow  ; if middle part (mushroom ledge), wait until next row
    CPY #$c0
    BEQ DrawThisRow  ; if question block w/ coin, overwrite
    CPY #$c0
    BCS WaitOneRow  ; if any other metatile with palette 3, wait until next row
    CPY #$54
    BNE DrawThisRow  ; if cracked rock terrain, overwrite
    CMP #$50
    BEQ WaitOneRow  ; if stem top of mushroom, wait until next row
DrawThisRow:
    STA ram_metatile_buffer,x  ; render contents of A from routine that called this
WaitOneRow:
    INX
    CPX #$0d  ; stop rendering if we're at the bottom of the screen
    BCS ExitUPartR
    LDY ram_area_object_height  ; decrement, and stop rendering if there is no more length
    DEY
    BPL RenderUnderPart
ExitUPartR:
    RTS

; --------------------------------

ChkLrgObjLength:
    JSR GetLrgObjAttrib  ; get row location and size (length if branched to from here)

ChkLrgObjFixedLength:
    LDA ram_area_object_length,x  ; check for set length counter
    CLC  ; clear carry flag for not just starting
    BPL LenSet  ; if counter not set, load it, otherwise leave alone
    TYA  ; save length into length counter
    STA ram_area_object_length,x
    SEC  ; set carry flag if just starting
LenSet:
    RTS

GetLrgObjAttrib:
    LDY ram_area_obj_offset_buffer,x  ; get offset saved from area obj decoding routine
    LDA (ram_area_data),y  ; get first byte of level object
    AND #%00001111
    STA $07  ; save row location
    INY
    LDA (ram_area_data),y  ; get next byte, save lower nybble (length or height)
    AND #%00001111  ; as Y, then leave
    TAY
    RTS

; --------------------------------

GetAreaObjXPosition:
    LDA ram_current_column_pos  ; multiply current offset where we're at by 16
    ASL  ; to obtain horizontal pixel coordinate
    ASL
    ASL
    ASL
    RTS

; --------------------------------

GetAreaObjYPosition:
    LDA $07  ; multiply value by 16
    ASL
    ASL  ; this will give us the proper vertical pixel coordinate
    ASL
    ASL
    CLC
    ADC #32  ; add 32 pixels for the status bar
    RTS

; -------------------------------------------------------------------------------------
; $06-$07 - used to store block buffer address used as indirect

BlockBufferAddr:
    .byte <ram_block_buffer_1, <ram_block_buffer_2
    .byte >ram_block_buffer_1, >ram_block_buffer_2

GetBlockBufferAddr:
    PHA  ; take value of A, save
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    TAY  ; use nybble as pointer to high byte
    LDA BlockBufferAddr+2,y  ; of indirect here
    STA $07
    PLA
    AND #%00001111  ; pull from stack, mask out high nybble
    CLC
    ADC BlockBufferAddr,y  ; add to low byte
    STA $06  ; store here and leave
    RTS

; -------------------------------------------------------------------------------------

; unused space
    .byte $ff, $ff
