; -------------------------------------------------------------------------------------
; $00 - used in adding to get proper offset

RelativePlayerPosition:
    LDX #$00  ; set offsets for relative cooordinates
    LDY #$00  ; routine to correspond to player object
    JMP RelWOfs  ; get the coordinates

RelativeBubblePosition:
    LDY #$01  ; set for air bubble offsets
    JSR GetProperObjOffset  ; modify X to get proper air bubble offset
    LDY #$03
    JMP RelWOfs  ; get the coordinates

RelativeFireballPosition:
    LDY #$00  ; set for fireball offsets
    JSR GetProperObjOffset  ; modify X to get proper fireball offset
    LDY #$02
RelWOfs:
    JSR GetObjRelativePosition  ; get the coordinates
    LDX ram_object_offset  ; return original offset
    RTS  ; leave

RelativeMiscPosition:
    LDY #$02  ; set for misc object offsets
    JSR GetProperObjOffset  ; modify X to get proper misc object offset
    LDY #$06
    JMP RelWOfs  ; get the coordinates

RelativeEnemyPosition:
    LDA #$01  ; get coordinates of enemy object
    LDY #$01  ; relative to the screen
    JMP VariableObjOfsRelPos

RelativeBlockPosition:
    LDA #$09  ; get coordinates of one block object
    LDY #$04  ; relative to the screen
    JSR VariableObjOfsRelPos
    INX  ; adjust offset for other block object if any
    INX
    LDA #$09
    INY  ; adjust other and get coordinates for other one

VariableObjOfsRelPos:
    STX $00  ; store value to add to A here
    CLC
    ADC $00  ; add A to value stored
    TAX  ; use as enemy offset
    JSR GetObjRelativePosition
    LDX ram_object_offset  ; reload old object offset and leave
    RTS

GetObjRelativePosition:
    LDA ram_spr_object_y_position,x  ; load vertical coordinate low
    STA ram_spr_object_rel_y_pos,y  ; store here
    LDA ram_spr_object_x_position,x  ; load horizontal coordinate
    SEC  ; subtract left edge coordinate
    SBC ram_screen_left_x_pos
    STA ram_spr_object_rel_x_pos,y  ; store result here
    RTS

; -------------------------------------------------------------------------------------
; $00 - used as temp variable to hold offscreen bits

GetPlayerOffscreenBits:
    LDX #$00  ; set offsets for player-specific variables
    LDY #$00  ; and get offscreen information about player
    JMP GetOffScreenBitsSet

GetFireballOffscreenBits:
    LDY #$00  ; set for fireball offsets
    JSR GetProperObjOffset  ; modify X to get proper fireball offset
    LDY #$02  ; set other offset for fireball's offscreen bits
    JMP GetOffScreenBitsSet  ; and get offscreen information about fireball

GetBubbleOffscreenBits:
    LDY #$01  ; set for air bubble offsets
    JSR GetProperObjOffset  ; modify X to get proper air bubble offset
    LDY #$03  ; set other offset for airbubble's offscreen bits
    JMP GetOffScreenBitsSet  ; and get offscreen information about air bubble

GetMiscOffscreenBits:
    LDY #$02  ; set for misc object offsets
    JSR GetProperObjOffset  ; modify X to get proper misc object offset
    LDY #$06  ; set other offset for misc object's offscreen bits
    JMP GetOffScreenBitsSet  ; and get offscreen information about misc object

ObjOffsetData:
    .byte $07, $16, $0d

GetProperObjOffset:
    TXA  ; move offset to A
    CLC
    ADC ObjOffsetData,y  ; add amount of bytes to offset depending on setting in Y
    TAX  ; put back in X and leave
    RTS

GetEnemyOffscreenBits:
    LDA #$01  ; set A to add 1 byte in order to get enemy offset
    LDY #$01  ; set Y to put offscreen bits in ram_enemy_offscreen_bits
    JMP SetOffscrBitsOffset

GetBlockOffscreenBits:
    LDA #$09  ; set A to add 9 bytes in order to get block obj offset
    LDY #$04  ; set Y to put offscreen bits in ram_block_offscreen_bits

SetOffscrBitsOffset:
    STX $00
    CLC  ; add contents of X to A to get
    ADC $00  ; appropriate offset, then give back to X
    TAX

GetOffScreenBitsSet:
    TYA  ; save offscreen bits offset to stack for now
    PHA
    JSR RunOffscrBitsSubs
    ASL  ; move low nybble to high nybble
    ASL
    ASL
    ASL
    ORA $00  ; mask together with previously saved low nybble
    STA $00  ; store both here
    PLA  ; get offscreen bits offset from stack
    TAY
    LDA $00  ; get value here and store elsewhere
    STA ram_spr_object_offscr_bits,y
    LDX ram_object_offset
    RTS

RunOffscrBitsSubs:
    JSR GetXOffscreenBits  ; do subroutine here
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    STA $00  ; store here
    JMP GetYOffscreenBits

; --------------------------------
; (these apply to these three subsections)
; $04 - used to store proper offset
; $05 - used as adder in DividePDiff
; $06 - used to store preset value used to compare to pixel difference in $07
; $07 - used to store difference between coordinates of object and screen edges

XOffscreenBitsData:
    .byte $7f, $3f, $1f, $0f, $07, $03, $01, $00
    .byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff

DefaultXOnscreenOfs:
    .byte $07, $0f, $07

GetXOffscreenBits:
    STX $04  ; save position in buffer to here
    LDY #$01  ; start with right side of screen
XOfsLoop:
    LDA ram_screen_edge_x_pos,y  ; get pixel coordinate of edge
    SEC  ; get difference between pixel coordinate of edge
    SBC ram_spr_object_x_position,x  ; and pixel coordinate of object position
    STA $07  ; store here
    LDA ram_screen_edge_page_loc,y  ; get page location of edge
    SBC ram_spr_object_page_loc,x  ; subtract from page location of object position
    LDX DefaultXOnscreenOfs,y  ; load offset value here
    CMP #$00
    BMI XLdBData  ; if beyond right edge or in front of left edge, branch
    LDX DefaultXOnscreenOfs+1,y  ; if not, load alternate offset value here
    CMP #$01
    BPL XLdBData  ; if one page or more to the left of either edge, branch
    LDA #$38  ; if no branching, load value here and store
    STA $06
    LDA #$08  ; load some other value and execute subroutine
    JSR DividePDiff
XLdBData:
    LDA XOffscreenBitsData,x  ; get bits here
    LDX $04  ; reobtain position in buffer
    CMP #$00  ; if bits not zero, branch to leave
    BNE ExXOfsBS
    DEY  ; otherwise, do left side of screen now
    BPL XOfsLoop  ; branch if not already done with left side
ExXOfsBS:
    RTS

; --------------------------------

YOffscreenBitsData:
    .byte $00, $08, $0c, $0e
    .byte $0f, $07, $03, $01
    .byte $00

DefaultYOnscreenOfs:
    .byte $04, $00, $04

HighPosUnitData:
    .byte $ff, $00

GetYOffscreenBits:
    STX $04  ; save position in buffer to here
    LDY #$01  ; start with top of screen
YOfsLoop:
    LDA HighPosUnitData,y  ; load coordinate for edge of vertical unit
    SEC
    SBC ram_spr_object_y_position,x  ; subtract from vertical coordinate of object
    STA $07  ; store here
    LDA #$01  ; subtract one from vertical high byte of object
    SBC ram_spr_object_y_high_pos,x
    LDX DefaultYOnscreenOfs,y  ; load offset value here
    CMP #$00
    BMI YLdBData  ; if under top of the screen or beyond bottom, branch
    LDX DefaultYOnscreenOfs+1,y  ; if not, load alternate offset value here
    CMP #$01
    BPL YLdBData  ; if one vertical unit or more above the screen, branch
    LDA #$20  ; if no branching, load value here and store
    STA $06
    LDA #$04  ; load some other value and execute subroutine
    JSR DividePDiff
YLdBData:
    LDA YOffscreenBitsData,x  ; get offscreen data bits using offset
    LDX $04  ; reobtain position in buffer
    CMP #$00
    BNE ExYOfsBS  ; if bits not zero, branch to leave
    DEY  ; otherwise, do bottom of the screen now
    BPL YOfsLoop
ExYOfsBS:
    RTS

; --------------------------------

DividePDiff:
    STA $05  ; store current value in A here
    LDA $07  ; get pixel difference
    CMP $06  ; compare to preset value
    BCS ExDivPD  ; if pixel difference >= preset value, branch
    LSR  ; divide by eight
    LSR
    LSR
    AND #$07  ; mask out all but 3 LSB
    CPY #$01  ; right side of the screen or top?
    BCS SetOscrO  ; if so, branch, use difference / 8 as offset
    ADC $05  ; if not, add value to difference / 8
SetOscrO:
    TAX  ; use as offset
ExDivPD:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - tile numbers
; $02 - Y coordinate
; $03 - flip control
; $04 - sprite attributes
; $05 - X coordinate

DrawSpriteObject:
    LDA $03  ; get saved flip control bits
    LSR
    LSR  ; move d1 into carry
    LDA $00
    BCC NoHFlip  ; if d1 not set, branch
    STA ram_sprite_tilenumber+4,y  ; store first tile into second sprite
    LDA $01  ; and second into first sprite
    STA ram_sprite_tilenumber,y
    LDA #$40  ; activate horizontal flip OAM attribute
    BNE SetHFAt  ; and unconditionally branch
NoHFlip:
    STA ram_sprite_tilenumber,y  ; store first tile into first sprite
    LDA $01  ; and second into second sprite
    STA ram_sprite_tilenumber+4,y
    LDA #$00  ; clear bit for horizontal flip
SetHFAt:
    ORA $04  ; add other OAM attributes if necessary
    STA ram_sprite_attributes,y  ; store sprite attributes
    STA ram_sprite_attributes+4,y
    LDA $02  ; now the y coordinates
    STA ram_sprite_y_position,y  ; note because they are
    STA ram_sprite_y_position+4,y  ; side by side, they are the same
    LDA $05
    STA ram_sprite_x_position,y  ; store x coordinate, then
    CLC  ; add 8 pixels and store another to
    ADC #$08  ; put them side by side
    STA ram_sprite_x_position+4,y
    LDA $02  ; add eight pixels to the next y
    CLC  ; coordinate
    ADC #$08
    STA $02
    TYA  ; add eight to the offset in Y to
    CLC  ; move to the next two sprites
    ADC #$08
    TAY
    INX  ; increment offset to return it to the
    INX  ; routine that called this subroutine
    RTS

; -------------------------------------------------------------------------------------

; unused space
    .byte $ff, $ff, $ff, $ff, $ff, $ff
