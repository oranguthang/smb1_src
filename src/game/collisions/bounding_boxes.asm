; -------------------------------------------------------------------------------------
; $00 - used to hold one of bitmasks, or offset
; $01 - used for relative X coordinate, also used to store middle screen page location
; $02 - used for relative Y coordinate, also used to store middle screen coordinate

; this data added to relative coordinates of sprite objects
; stored in order: left edge, top edge, right edge, bottom edge
BoundBoxCtrlData:
    .byte $02, $08, $0e, $20
    .byte $03, $14, $0d, $20
    .byte $02, $14, $0e, $20
    .byte $02, $09, $0e, $15
    .byte $00, $00, $18, $06
    .byte $00, $00, $20, $0d
    .byte $00, $00, $30, $0d
    .byte $00, $00, $08, $08
    .byte $06, $04, $0a, $08
    .byte $03, $0e, $0d, $14
    .byte $00, $02, $10, $15
    .byte $04, $04, $0c, $1c

GetFireballBoundBox:
    TXA  ; add seven bytes to offset
    CLC  ; to use in routines as offset for fireball
    ADC #$07
    TAX
    LDY #$02  ; set offset for relative coordinates
    BNE FBallB  ; unconditional branch

GetMiscBoundBox:
    TXA  ; add nine bytes to offset
    CLC  ; to use in routines as offset for misc object
    ADC #$09
    TAX
    LDY #$06  ; set offset for relative coordinates
FBallB:
    JSR BoundingBoxCore  ; get bounding box coordinates
    JMP CheckRightScreenBBox  ; jump to handle any offscreen coordinates

GetEnemyBoundBox:
    LDY #$48  ; store bitmask here for now
    STY $00
    LDY #$44  ; store another bitmask here for now and jump
    JMP GetMaskedOffScrBits

SmallPlatformBoundBox:
    LDY #$08  ; store bitmask here for now
    STY $00
    LDY #$04  ; store another bitmask here for now

GetMaskedOffScrBits:
    LDA ram_enemy_x_position,x  ; get enemy object position relative
    SEC  ; to the left side of the screen
    SBC ram_screen_left_x_pos
    STA $01  ; store here
    LDA ram_enemy_page_loc,x  ; subtract borrow from current page location
    SBC ram_screen_left_page_loc  ; of left side
    BMI CMBits  ; if enemy object is beyond left edge, branch
    ORA $01
    BEQ CMBits  ; if precisely at the left edge, branch
    LDY $00  ; if to the right of left edge, use value in $00 for A
CMBits:
    TYA  ; otherwise use contents of Y
    AND ram_enemy_offscreen_bits  ; preserve bitwise whatever's in here
    STA ram_enemy_offscr_bits_masked,x  ; save masked offscreen bits here
    BNE MoveBoundBoxOffscreen  ; if anything set here, branch
    JMP SetupEOffsetFBBox  ; otherwise, do something else

LargePlatformBoundBox:
    INX  ; increment X to get the proper offset
    JSR GetXOffscreenBits  ; then jump directly to the sub for horizontal offscreen bits
    DEX  ; decrement to return to original offset
    CMP #$fe  ; if completely offscreen, branch to put entire bounding
    BCS MoveBoundBoxOffscreen  ; box offscreen, otherwise start getting coordinates

SetupEOffsetFBBox:
    TXA  ; add 1 to offset to properly address
    CLC  ; the enemy object memory locations
    ADC #$01
    TAX
    LDY #$01  ; load 1 as offset here, same reason
    JSR BoundingBoxCore  ; do a sub to get the coordinates of the bounding box
    JMP CheckRightScreenBBox  ; jump to handle offscreen coordinates of bounding box

MoveBoundBoxOffscreen:
    TXA  ; multiply offset by 4
    ASL
    ASL
    TAY  ; use as offset here
    LDA #$ff
    STA ram_enemy_bounding_box_coord,y  ; load value into four locations here and leave
    STA ram_enemy_bounding_box_coord+1,y
    STA ram_enemy_bounding_box_coord+2,y
    STA ram_enemy_bounding_box_coord+3,y
    RTS

BoundingBoxCore:
    STX $00  ; save offset here
    LDA ram_spr_object_rel_y_pos,y  ; store object coordinates relative to screen
    STA $02  ; vertically and horizontally, respectively
    LDA ram_spr_object_rel_x_pos,y
    STA $01
    TXA  ; multiply offset by four and save to stack
    ASL
    ASL
    PHA
    TAY  ; use as offset for Y, X is left alone
    LDA ram_spr_obj_bound_box_ctrl,x  ; load value here to be used as offset for X
    ASL  ; multiply that by four and use as X
    ASL
    TAX
    LDA $01  ; add the first number in the bounding box data to the
    CLC  ; relative horizontal coordinate using enemy object offset
    ADC BoundBoxCtrlData,x  ; and store somewhere using same offset * 4
    STA ram_bounding_box_ul_corner,y  ; store here
    LDA $01
    CLC
    ADC BoundBoxCtrlData+2,x  ; add the third number in the bounding box data to the
    STA ram_bounding_box_lr_corner,y  ; relative horizontal coordinate and store
    INX  ; increment both offsets
    INY
    LDA $02  ; add the second number to the relative vertical coordinate
    CLC  ; using incremented offset and store using the other
    ADC BoundBoxCtrlData,x  ; incremented offset
    STA ram_bounding_box_ul_corner,y
    LDA $02
    CLC
    ADC BoundBoxCtrlData+2,x  ; add the fourth number to the relative vertical coordinate
    STA ram_bounding_box_lr_corner,y  ; and store
    PLA  ; get original offset loaded into $00 * y from stack
    TAY  ; use as Y
    LDX $00  ; get original offset and use as X again
    RTS

CheckRightScreenBBox:
    LDA ram_screen_left_x_pos  ; add 128 pixels to left side of screen
    CLC  ; and store as horizontal coordinate of middle
    ADC #$80
    STA $02
    LDA ram_screen_left_page_loc  ; add carry to page location of left side of screen
    ADC #$00  ; and store as page location of middle
    STA $01
    LDA ram_spr_object_x_position,x  ; get horizontal coordinate
    CMP $02  ; compare against middle horizontal coordinate
    LDA ram_spr_object_page_loc,x  ; get page location
    SBC $01  ; subtract from middle page location
    BCC CheckLeftScreenBBox  ; if object is on the left side of the screen, branch
    LDA ram_bounding_box_dr_x_pos,y  ; check right-side edge of bounding box for offscreen
    BMI NoOfs  ; coordinates, branch if still on the screen
    LDA #$ff  ; load offscreen value here to use on one or both horizontal sides
    LDX ram_bounding_box_ul_x_pos,y  ; check left-side edge of bounding box for offscreen
    BMI SORte  ; coordinates, and branch if still on the screen
    STA ram_bounding_box_ul_x_pos,y  ; store offscreen value for left side
SORte:
    STA ram_bounding_box_dr_x_pos,y  ; store offscreen value for right side
NoOfs:
    LDX ram_object_offset  ; get object offset and leave
    RTS

CheckLeftScreenBBox:
    LDA ram_bounding_box_ul_x_pos,y  ; check left-side edge of bounding box for offscreen
    BPL NoOfs2  ; coordinates, and branch if still on the screen
    CMP #$a0  ; check to see if left-side edge is in the middle of the
    BCC NoOfs2  ; screen or really offscreen, and branch if still on
    LDA #$00
    LDX ram_bounding_box_dr_x_pos,y  ; check right-side edge of bounding box for offscreen
    BPL SOLft  ; coordinates, branch if still onscreen
    STA ram_bounding_box_dr_x_pos,y  ; store offscreen value for right side
SOLft:
    STA ram_bounding_box_ul_x_pos,y  ; store offscreen value for left side
NoOfs2:
    LDX ram_object_offset  ; get object offset and leave
    RTS

; -------------------------------------------------------------------------------------
; $06 - second object's offset
; $07 - counter

PlayerCollisionCore:
    LDX #$00  ; initialize X to use player's bounding box for comparison

SprObjectCollisionCore:
    STY $06  ; save contents of Y here
    LDA #$01
    STA $07  ; save value 1 here as counter, compare horizontal coordinates first

CollisionCoreLoop:
    LDA ram_bounding_box_ul_corner,y  ; compare left/top coordinates
    CMP ram_bounding_box_ul_corner,x  ; of first and second objects' bounding boxes
    BCS FirstBoxGreater  ; if first left/top => second, branch
    CMP ram_bounding_box_lr_corner,x  ; otherwise compare to right/bottom of second
    BCC SecondBoxVerticalChk  ; if first left/top < second right/bottom, branch elsewhere
    BEQ CollisionFound  ; if somehow equal, collision, thus branch
    LDA ram_bounding_box_lr_corner,y  ; if somehow greater, check to see if bottom of
    CMP ram_bounding_box_ul_corner,y  ; first object's bounding box is greater than its top
    BCC CollisionFound  ; if somehow less, vertical wrap collision, thus branch
    CMP ram_bounding_box_ul_corner,x  ; otherwise compare bottom of first bounding box to the top
    BCS CollisionFound  ; of second box, and if equal or greater, collision, thus branch
    LDY $06  ; otherwise return with carry clear and Y = $0006
    RTS  ; note horizontal wrapping never occurs

SecondBoxVerticalChk:
    LDA ram_bounding_box_lr_corner,x  ; check to see if the vertical bottom of the box
    CMP ram_bounding_box_ul_corner,x  ; is greater than the vertical top
    BCC CollisionFound  ; if somehow less, vertical wrap collision, thus branch
    LDA ram_bounding_box_lr_corner,y  ; otherwise compare horizontal right or vertical bottom
    CMP ram_bounding_box_ul_corner,x  ; of first box with horizontal left or vertical top of second box
    BCS CollisionFound  ; if equal or greater, collision, thus branch
    LDY $06  ; otherwise return with carry clear and Y = $0006
    RTS

FirstBoxGreater:
    CMP ram_bounding_box_ul_corner,x  ; compare first and second box horizontal left/vertical top again
    BEQ CollisionFound  ; if first coordinate = second, collision, thus branch
    CMP ram_bounding_box_lr_corner,x  ; if not, compare with second object right or bottom edge
    BCC CollisionFound  ; if left/top of first less than or equal to right/bottom of second
    BEQ CollisionFound  ; then collision, thus branch
    CMP ram_bounding_box_lr_corner,y  ; otherwise check to see if top of first box is greater than bottom
    BCC NoCollisionFound  ; if less than or equal, no collision, branch to end
    BEQ NoCollisionFound
    LDA ram_bounding_box_lr_corner,y  ; otherwise compare bottom of first to top of second
    CMP ram_bounding_box_ul_corner,x  ; if bottom of first is greater than top of second, vertical wrap
    BCS CollisionFound  ; collision, and branch, otherwise, proceed onwards here

NoCollisionFound:
    CLC  ; clear carry, then load value set earlier, then leave
    LDY $06  ; like previous ones, if horizontal coordinates do not collide, we do
    RTS  ; not bother checking vertical ones, because what's the point?

CollisionFound:
    INX  ; increment offsets on both objects to check
    INY  ; the vertical coordinates
    DEC $07  ; decrement counter to reflect this
    BPL CollisionCoreLoop  ; if counter not expired, branch to loop
    SEC  ; otherwise we already did both sets, therefore collision, so set carry
    LDY $06  ; load original value set here earlier, then leave
    RTS

; -------------------------------------------------------------------------------------
; $02 - modified y coordinate
; $03 - stores metatile involved in block buffer collisions
; $04 - comes in with offset to block buffer adder data, goes out with low nybble x/y coordinate
; $05 - modified x coordinate
; $06-$07 - block buffer address

BlockBufferChk_Enemy:
    PHA  ; save contents of A to stack
    TXA
    CLC  ; add 1 to X to run sub with enemy offset in mind
    ADC #$01
    TAX
    PLA  ; pull A from stack and jump elsewhere
    JMP BBChk_E

ResidualMiscObjectCode:
    TXA
    CLC  ; supposedly used once to set offset for
    ADC #$0d  ; miscellaneous objects
    TAX
    LDY #$1b  ; supposedly used once to set offset for block buffer data
    JMP ResJmpM  ; probably used in early stages to do misc to bg collision detection

BlockBufferChk_FBall:
    LDY #$1a  ; set offset for block buffer adder data
    TXA
    CLC
    ADC #$07  ; add seven bytes to use
    TAX
ResJmpM:
    LDA #$00  ; set A to return vertical coordinate
BBChk_E:
    JSR BlockBufferCollision  ; do collision detection subroutine for sprite object
    LDX ram_object_offset  ; get object offset
    CMP #$00  ; check to see if object bumped into anything
    RTS

BlockBufferAdderData:
    .byte $00, $07, $0e

BlockBuffer_X_Adder:
    .byte $08, $03, $0c, $02, $02, $0d, $0d, $08
    .byte $03, $0c, $02, $02, $0d, $0d, $08, $03
    .byte $0c, $02, $02, $0d, $0d, $08, $00, $10
    .byte $04, $14, $04, $04

BlockBuffer_Y_Adder:
    .byte $04, $20, $20, $08, $18, $08, $18, $02
    .byte $20, $20, $08, $18, $08, $18, $12, $20
    .byte $20, $18, $18, $18, $18, $18, $14, $14
    .byte $06, $06, $08, $10

BlockBufferColli_Feet:
    INY  ; if branched here, increment to next set of adders

BlockBufferColli_Head:
    LDA #$00  ; set flag to return vertical coordinate
    .byte $2c  ; BIT instruction opcode

BlockBufferColli_Side:
    LDA #$01  ; set flag to return horizontal coordinate
    LDX #$00  ; set offset for player object

BlockBufferCollision:
    PHA  ; save contents of A to stack
    STY $04  ; save contents of Y here
    LDA BlockBuffer_X_Adder,y  ; add horizontal coordinate
    CLC  ; of object to value obtained using Y as offset
    ADC ram_spr_object_x_position,x
    STA $05  ; store here
    LDA ram_spr_object_page_loc,x
    ADC #$00  ; add carry to page location
    AND #$01  ; get LSB, mask out all other bits
    LSR  ; move to carry
    ORA $05  ; get stored value
    ROR  ; rotate carry to MSB of A
    LSR  ; and effectively move high nybble to
    LSR  ; lower, LSB which became MSB will be
    LSR  ; d4 at this point
    JSR GetBlockBufferAddr  ; get address of block buffer into $06, $07
    LDY $04  ; get old contents of Y
    LDA ram_spr_object_y_position,x  ; get vertical coordinate of object
    CLC
    ADC BlockBuffer_Y_Adder,y  ; add it to value obtained using Y as offset
    AND #%11110000  ; mask out low nybble
    SEC
    SBC #$20  ; subtract 32 pixels for the status bar
    STA $02  ; store result here
    TAY  ; use as offset for block buffer
    LDA ($06),y  ; check current content of block buffer
    STA $03  ; and store here
    LDY $04  ; get old contents of Y again
    PLA  ; pull A from stack
    BNE RetXC  ; if A = 1, branch
    LDA ram_spr_object_y_position,x  ; if A = 0, load vertical coordinate
    JMP RetYC  ; and jump
RetXC:
    LDA ram_spr_object_x_position,x  ; otherwise load horizontal coordinate
RetYC:
    AND #%00001111  ; and mask out high nybble
    STA $04  ; store masked out result here
    LDA $03  ; get saved content of block buffer
    RTS  ; and leave

; -------------------------------------------------------------------------------------

; unused byte
    .byte $ff
