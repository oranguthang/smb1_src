off_smb2_main_bounding_box_relative_edges:
    .byte $02, $08, $0e, $20
    .byte $03, $14, $0d, $20
    .byte $02, $14, $0e, $20
    .byte $02, $09, $0e, $15
    .byte $00, $00, $18, $06
    .byte $00, $00, $20, $0d
    .byte $00, $00, $30, $0d
    .byte $00, $00, $08, $08
    .byte $06, $04, $0a, $08
    .byte $03, $0e, $0d, $16
    .byte $00, $02, $10, $15
    .byte $04, $04, $0c, $1c

sub_smb2_main_get_fireball_bound_box:
    TXA  ; add seven bytes to offset
    CLC  ; to use in routines as offset for fireball
    ADC #$07
    TAX
    LDY #$02  ; set offset for relative coordinates
    BNE bra_smb2_main_use_fireball_bounding_box  ; unconditional branch

sub_smb2_main_get_misc_bound_box:
    TXA  ; add nine bytes to offset
    CLC  ; to use in routines as offset for misc object
    ADC #$09
    TAX
    LDY #$06  ; set offset for relative coordinates
bra_smb2_main_use_fireball_bounding_box:
    JSR sub_smb2_main_bounding_box_core  ; get bounding box coordinates
    JMP loc_smb2_main_clip_bounding_box_right_edge  ; jump to handle any offscreen coordinates

sub_smb2_main_get_enemy_bound_box:
    LDY #$48  ; store bitmask here for now
    STY $00
    LDY #$44  ; store another bitmask here for now and jump
    JMP loc_smb2_main_get_masked_offscreen_bits

sub_smb2_main_small_platform_bound_box:
    LDY #$08  ; store bitmask here for now
    STY $00
    LDY #$04  ; store another bitmask here for now

loc_smb2_main_get_masked_offscreen_bits:
    LDA Enemy_X_Position,x  ; get enemy object position relative
    SEC  ; to the left side of the screen
    SBC ScreenLeft_X_Pos
    STA $01  ; store here
    LDA Enemy_PageLoc,x  ; subtract borrow from current page location
    SBC ScreenLeft_PageLoc  ; of left side
    BMI bra_smb2_main_store_masked_offscreen_bits  ; if enemy object is beyond left edge, branch
    ORA $01
    BEQ bra_smb2_main_store_masked_offscreen_bits  ; if precisely at the left edge, branch
    LDY $00  ; if to the right of left edge, use value in $00 for A
bra_smb2_main_store_masked_offscreen_bits:
    TYA  ; otherwise use contents of Y
    AND Enemy_OffscreenBits  ; preserve bitwise whatever's in here
    STA EnemyOffscrBitsMasked,x  ; save masked offscreen bits here
    BNE bra_smb2_main_move_bounding_box_offscreen  ; if anything set here, branch
    JMP loc_smb2_main_select_fireball_bounding_box_offset  ; otherwise, do something else

sub_smb2_main_large_platform_bound_box:
    INX  ; increment X to get the proper offset
    JSR sub_smb2_main_get_horizontal_offscreen_bits  ; then jump directly to the sub for horizontal offscreen bits
    DEX  ; decrement to return to original offset
    CMP #$fe  ; if completely offscreen, branch to put entire bounding
    BCS bra_smb2_main_move_bounding_box_offscreen  ; box offscreen, otherwise start getting coordinates

loc_smb2_main_select_fireball_bounding_box_offset:
    TXA  ; add 1 to offset to properly address
    CLC  ; the enemy object memory locations
    ADC #$01
    TAX
    LDY #$01  ; load 1 as offset here, same reason
    JSR sub_smb2_main_bounding_box_core  ; do a sub to get the coordinates of the bounding box
    JMP loc_smb2_main_clip_bounding_box_right_edge  ; jump to handle offscreen coordinates of bounding box

bra_smb2_main_move_bounding_box_offscreen:
    TXA  ; multiply offset by 4
    ASL
    ASL
    TAY  ; use as offset here
    LDA #$ff
    STA EnemyBoundingBoxCoord,y  ; load value into four locations here and leave
    STA EnemyBoundingBoxCoord+1,y
    STA EnemyBoundingBoxCoord+2,y
    STA EnemyBoundingBoxCoord+3,y
    RTS

sub_smb2_main_bounding_box_core:
    STX $00  ; save offset here
    LDA SprObject_Rel_YPos,y  ; store object coordinates relative to screen
    STA $02  ; vertically and horizontally, respectively
    LDA SprObject_Rel_XPos,y
    STA $01
    TXA  ; multiply offset by four and save to stack
    ASL
    ASL
    PHA
    TAY  ; use as offset for Y, X is left alone
    LDA SprObj_BoundBoxCtrl,x  ; load value here to be used as offset for X
    ASL  ; multiply that by four and use as X
    ASL
    TAX
    LDA $01  ; add the first number in the bounding box data to the
    CLC  ; relative horizontal coordinate using enemy object offset
    ADC off_smb2_main_bounding_box_relative_edges,x  ; and store somewhere using same offset * 4
    STA BoundingBox_UL_Corner,y  ; store here
    LDA $01
    CLC
    ADC off_smb2_main_bounding_box_relative_edges+2,x  ; add the third number in the bounding box data to the
    STA BoundingBox_LR_Corner,y  ; relative horizontal coordinate and store
    INX  ; increment both offsets
    INY
    LDA $02  ; add the second number to the relative vertical coordinate
    CLC  ; using incremented offset and store using the other
    ADC off_smb2_main_bounding_box_relative_edges,x  ; incremented offset
    STA BoundingBox_UL_Corner,y
    LDA $02
    CLC
    ADC off_smb2_main_bounding_box_relative_edges+2,x  ; add the fourth number to the relative vertical coordinate
    STA BoundingBox_LR_Corner,y  ; and store
    PLA  ; get original offset loaded into $00 * y from stack
    TAY  ; use as Y
    LDX $00  ; get original offset and use as X again
    RTS

loc_smb2_main_clip_bounding_box_right_edge:
    LDA ScreenLeft_X_Pos  ; add 128 pixels to left side of screen
    CLC  ; and store as horizontal coordinate of middle
    ADC #$80
    STA $02
    LDA ScreenLeft_PageLoc  ; add carry to page location of left side of screen
    ADC #$00  ; and store as page location of middle
    STA $01
    LDA SprObject_X_Position,x  ; get horizontal coordinate
    CMP $02  ; compare against middle horizontal coordinate
    LDA SprObject_PageLoc,x  ; get page location
    SBC $01  ; subtract from middle page location
    BCC bra_smb2_main_clip_bounding_box_left_edge  ; if object is on the left side of the screen, branch
    LDA BoundingBox_DR_XPos,y  ; check right-side edge of bounding box for offscreen
    BMI bra_smb2_main_store_right_screen_bounding_box  ; coordinates, branch if still on the screen
    LDA #$ff  ; load offscreen value here to use on one or both horizontal sides
    LDX BoundingBox_UL_XPos,y  ; check left-side edge of bounding box for offscreen
    BMI bra_smb2_main_move_bounding_box_right_offscreen  ; coordinates, and branch if still on the screen
    STA BoundingBox_UL_XPos,y  ; store offscreen value for left side
bra_smb2_main_move_bounding_box_right_offscreen:
    STA BoundingBox_DR_XPos,y  ; store offscreen value for right side
bra_smb2_main_store_right_screen_bounding_box:
    LDX ObjectOffset  ; get object offset and leave
    RTS

bra_smb2_main_clip_bounding_box_left_edge:
    LDA BoundingBox_UL_XPos,y  ; check left-side edge of bounding box for offscreen
    BPL bra_smb2_main_store_left_screen_bounding_box  ; coordinates, and branch if still on the screen
    CMP #$a0  ; check to see if left-side edge is in the middle of the
    BCC bra_smb2_main_store_left_screen_bounding_box  ; screen or really offscreen, and branch if still on
    LDA #$00
    LDX BoundingBox_DR_XPos,y  ; check right-side edge of bounding box for offscreen
    BPL bra_smb2_main_move_bounding_box_left_offscreen  ; coordinates, branch if still onscreen
    STA BoundingBox_DR_XPos,y  ; store offscreen value for right side
bra_smb2_main_move_bounding_box_left_offscreen:
    STA BoundingBox_UL_XPos,y  ; store offscreen value for left side
bra_smb2_main_store_left_screen_bounding_box:
    LDX ObjectOffset  ; get object offset and leave
    RTS

; -------------------------------------------------------------------------------------
; $06 - second object's offset
; $07 - counter

sub_smb2_main_player_collision_core:
    LDX #$00  ; initialize X to use player's bounding box for comparison

sub_smb2_main_sprite_object_collision_core:
    STY $06  ; save contents of Y here
    LDA #$01
    STA $07  ; save value 1 here as counter, compare horizontal coordinates first

bra_smb2_main_check_bounding_box_axes:
    LDA BoundingBox_UL_Corner,y  ; compare left/top coordinates
    CMP BoundingBox_UL_Corner,x  ; of first and second objects' bounding boxes
    BCS bra_smb2_main_compare_first_box_opposite_edge  ; if first left/top => second, branch
    CMP BoundingBox_LR_Corner,x  ; otherwise compare to right/bottom of second
    BCC bra_smb2_main_check_second_box_vertical_edge  ; if first left/top < second right/bottom, branch elsewhere
    BEQ bra_smb2_main_return_bounding_box_collision  ; if somehow equal, collision, thus branch
    LDA BoundingBox_LR_Corner,y  ; if somehow greater, check to see if bottom of
    CMP BoundingBox_UL_Corner,y  ; first object's bounding box is greater than its top
    BCC bra_smb2_main_return_bounding_box_collision  ; if somehow less, vertical wrap collision, thus branch
    CMP BoundingBox_UL_Corner,x  ; otherwise compare bottom of first bounding box to the top
    BCS bra_smb2_main_return_bounding_box_collision  ; of second box, and if equal or greater, collision, thus branch
    LDY $06  ; otherwise return with carry clear and Y = $0006
    RTS  ; note horizontal wrapping never occurs

bra_smb2_main_check_second_box_vertical_edge:
    LDA BoundingBox_LR_Corner,x  ; check to see if the vertical bottom of the box
    CMP BoundingBox_UL_Corner,x  ; is greater than the vertical top
    BCC bra_smb2_main_return_bounding_box_collision  ; if somehow less, vertical wrap collision, thus branch
    LDA BoundingBox_LR_Corner,y  ; otherwise compare horizontal right or vertical bottom
    CMP BoundingBox_UL_Corner,x  ; of first box with horizontal left or vertical top of second box
    BCS bra_smb2_main_return_bounding_box_collision  ; if equal or greater, collision, thus branch
    LDY $06  ; otherwise return with carry clear and Y = $0006
    RTS

bra_smb2_main_compare_first_box_opposite_edge:
    CMP BoundingBox_UL_Corner,x  ; compare first and second box horizontal left/vertical top again
    BEQ bra_smb2_main_return_bounding_box_collision  ; if first coordinate = second, collision, thus branch
    CMP BoundingBox_LR_Corner,x  ; if not, compare with second object right or bottom edge
    BCC bra_smb2_main_return_bounding_box_collision  ; if left/top of first less than or equal to right/bottom of second
    BEQ bra_smb2_main_return_bounding_box_collision  ; then collision, thus branch
    CMP BoundingBox_LR_Corner,y  ; otherwise check to see if top of first box is greater than bottom
    BCC bra_smb2_main_return_no_bounding_box_collision  ; if less than or equal, no collision, branch to end
    BEQ bra_smb2_main_return_no_bounding_box_collision
    LDA BoundingBox_LR_Corner,y  ; otherwise compare bottom of first to top of second
    CMP BoundingBox_UL_Corner,x  ; if bottom of first is greater than top of second, vertical wrap
    BCS bra_smb2_main_return_bounding_box_collision  ; collision, and branch, otherwise, proceed onwards here

bra_smb2_main_return_no_bounding_box_collision:
    CLC  ; clear carry, then load value set earlier, then leave
    LDY $06  ; like previous ones, if horizontal coordinates do not collide, we do
    RTS  ; not bother checking vertical ones, because what's the point?

bra_smb2_main_return_bounding_box_collision:
    INX  ; increment offsets on both objects to check
    INY  ; the vertical coordinates
    DEC $07  ; decrement counter to reflect this
    BPL bra_smb2_main_check_bounding_box_axes  ; if counter not expired, branch to loop
    SEC  ; otherwise we already did both sets, therefore collision, so set carry
    LDY $06  ; load original value set here earlier, then leave
    RTS

; -------------------------------------------------------------------------------------
; $02 - modified y coordinate
; $03 - stores metatile involved in block buffer collisions
; $04 - comes in with offset to block buffer adder data, goes out with low nybble x/y coordinate
; $05 - modified x coordinate
; $06-$07 - block buffer address

sub_smb2_main_check_enemy_block_buffer:
    PHA  ; save contents of A to stack
    TXA
    CLC  ; add 1 to X to run sub with enemy offset in mind
    ADC #$01
    TAX
    PLA  ; pull A from stack and jump elsewhere
    JMP loc_smb2_main_run_block_buffer_collision

loc_smb2_main_misc_object_background_collision_setup:
    TXA
    CLC  ; supposedly used once to set offset for
    ADC #$0d  ; miscellaneous objects
    TAX
    LDY #$1b  ; supposedly used once to set offset for block buffer data
    JMP loc_smb2_main_shared_block_buffer_collision  ; probably used in early stages to do misc to bg collision detection

sub_smb2_main_check_fireball_block_buffer:
    LDY #$1a  ; set offset for block buffer adder data
    TXA
    CLC
    ADC #$07  ; add seven bytes to use
    TAX
loc_smb2_main_shared_block_buffer_collision:
    LDA #$00  ; set A to return vertical coordinate
loc_smb2_main_run_block_buffer_collision:
    JSR sub_smb2_main_block_buffer_collision  ; do collision detection subroutine for sprite object
    LDX ObjectOffset  ; get object offset
    CMP #$00  ; check to see if object bumped into anything
    RTS

off_smb2_main_block_buffer_object_offsets:
    .byte $00, $07, $0e

tbl_smb2_main_block_buffer_x_offsets:
    .byte $08, $03, $0c, $02, $02, $0d, $0d, $08
    .byte $03, $0c, $02, $02, $0d, $0d, $08, $03
    .byte $0c, $02, $02, $0d, $0d, $08, $00, $10
    .byte $04, $14, $04, $04

tbl_smb2_main_block_buffer_y_offsets:
    .byte $04, $20, $20, $08, $18, $08, $18, $02
    .byte $20, $20, $08, $18, $08, $18, $12, $20
    .byte $20, $18, $18, $18, $18, $18, $14, $14
    .byte $06, $06, $08, $10

sub_smb2_main_check_player_feet_block_buffer:
    INY  ; if branched here, increment to next set of adders

sub_smb2_main_check_player_head_block_buffer:
    LDA #$00  ; set flag to return vertical coordinate
    .byte $2c  ; BIT instruction opcode

sub_smb2_main_check_player_side_block_buffer:
    LDA #$01  ; set flag to return horizontal coordinate
    LDX #$00  ; set offset for player object

sub_smb2_main_block_buffer_collision:
    PHA  ; save contents of A to stack
    STY $04  ; save contents of Y here
    LDA tbl_smb2_main_block_buffer_x_offsets,y  ; add horizontal coordinate
    CLC  ; of object to value obtained using Y as offset
    ADC SprObject_X_Position,x
    STA $05  ; store here
    LDA SprObject_PageLoc,x
    ADC #$00  ; add carry to page location
    AND #$01  ; get LSB, mask out all other bits
    LSR  ; move to carry
    ORA $05  ; get stored value
    ROR  ; rotate carry to MSB of A
    LSR  ; and effectively move high nybble to
    LSR  ; lower, LSB which became MSB will be
    LSR  ; d4 at this point
    JSR sub_smb2_main_get_block_buffer_addr  ; get address of block buffer into $06, $07
    LDY $04  ; get old contents of Y
    LDA SprObject_Y_Position,x  ; get vertical coordinate of object
    CLC
    ADC tbl_smb2_main_block_buffer_y_offsets,y  ; add it to value obtained using Y as offset
    AND #%11110000  ; mask out low nybble
    SEC
    SBC #$20  ; subtract 32 pixels for the status bar
    STA $02  ; store result here
    TAY  ; use as offset for block buffer
    LDA ($06),y  ; check current content of block buffer
    STA $03  ; and store here
    LDY $04  ; get old contents of Y again
    PLA  ; pull A from stack
    BNE bra_smb2_main_return_block_buffer_x_coordinate  ; if A = 1, branch
    LDA SprObject_Y_Position,x  ; if A = 0, load vertical coordinate
    JMP loc_smb2_main_return_block_buffer_y_coordinate  ; and jump
bra_smb2_main_return_block_buffer_x_coordinate:
    LDA SprObject_X_Position,x  ; otherwise load horizontal coordinate
loc_smb2_main_return_block_buffer_y_coordinate:
    AND #%00001111  ; and mask out high nybble
    STA $04  ; store masked out result here
    LDA $03  ; get saved content of block buffer
    RTS  ; and leave

; -------------------------------------------------------------------------------------

; unused bytes
    .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff

; -------------------------------------------------------------------------------------
; $00 - offset to vine Y coordinate adder
; $02 - offset to sprite data

tbl_smb2_main_vine_y_offsets:
    .byte $00, $30

sub_smb2_main_draw_vine:
    STY $00  ; save offset here
    LDA Enemy_Rel_YPos  ; get relative vertical coordinate
    CLC
    ADC tbl_smb2_main_vine_y_offsets,y  ; add value using offset in Y to get value
    LDX VineObjOffset,y  ; get offset to vine
    LDY Enemy_SprDataOffset,x  ; get sprite data offset
    STY $02  ; store sprite data offset here
    JSR sub_smb2_main_six_sprite_stacker  ; stack six sprites on top of each other vertically
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store in first, third and fifth sprites
    STA Sprite_X_Position+8,y
    STA Sprite_X_Position+16,y
    CLC
    ADC #$06  ; add six pixels to second, fourth and sixth sprites
    STA Sprite_X_Position+4,y  ; to give characteristic staggered vine shape to
    STA Sprite_X_Position+12,y  ; our vertical stack of sprites
    STA Sprite_X_Position+20,y
    LDA #%00100001  ; set bg priority and palette attribute bits
    STA Sprite_Attributes,y  ; set in first, third and fifth sprites
    STA Sprite_Attributes+8,y
    STA Sprite_Attributes+16,y
    ORA #%01000000  ; additionally, set horizontal flip bit
    STA Sprite_Attributes+4,y  ; for second, fourth and sixth sprites
    STA Sprite_Attributes+12,y
    STA Sprite_Attributes+20,y
    LDX #$05  ; set tiles for six sprites
bra_smb2_main_store_vine_sprite_tiles:
    LDA #$e1  ; set tile number for sprite
    STA Sprite_Tilenumber,y
    INY  ; move offset to next sprite data
    INY
    INY
    INY
    DEX  ; move onto next sprite
    BPL bra_smb2_main_store_vine_sprite_tiles  ; loop until all sprites are done
    LDY $02  ; get original offset
    LDA $00  ; get offset to vine adding data
    BNE bra_smb2_main_clip_vine_top  ; if offset not zero, skip this part
    LDA #$e0
    STA Sprite_Tilenumber,y  ; set other tile number for top of vine
bra_smb2_main_clip_vine_top:
    LDX #$00  ; start with the first sprite again
bra_smb2_main_check_vine_sprite_above_growth_start:
    LDA VineStart_Y_Position  ; get original starting vertical coordinate
    SEC
    SBC Sprite_Y_Position,y  ; subtract top-most sprite's Y coordinate
    CMP #$64  ; if two coordinates are less than 100/$64 pixels
    BCC bra_smb2_main_advance_vine_sprite  ; apart, skip this to leave sprite alone
    LDA #$f8
    STA Sprite_Y_Position,y  ; otherwise move sprite offscreen
bra_smb2_main_advance_vine_sprite:
    INY  ; move offset to next OAM data
    INY
    INY
    INY
    INX  ; move onto next sprite
    CPX #$06  ; do this until all sprites are checked
    BNE bra_smb2_main_check_vine_sprite_above_growth_start
    LDY $00  ; return offset set earlier
    RTS

sub_smb2_main_six_sprite_stacker:
    LDX #$06  ; do six sprites
bra_smb2_main_stack_six_sprites:
    STA Sprite_Data,y  ; store X or Y coordinate into OAM data
    CLC
    ADC #$08  ; add eight pixels
    INY
    INY  ; move offset four bytes forward
    INY
    INY
    DEX  ; do another sprite
    BNE bra_smb2_main_stack_six_sprites  ; do this until all sprites are done
    LDY $02  ; get saved OAM data offset and leave
    RTS

; -------------------------------------------------------------------------------------

tbl_smb2_main_hammer_first_sprite_x_offsets:
    .byte $04, $00, $04, $00

tbl_smb2_main_hammer_first_sprite_y_offsets:
    .byte $00, $04, $00, $04

tbl_smb2_main_hammer_second_sprite_x_offsets:
    .byte $00, $08, $00, $08

tbl_smb2_main_hammer_second_sprite_y_offsets:
    .byte $08, $00, $08, $00

tbl_smb2_main_hammer_first_sprite_tiles:
    .byte $80, $82, $81, $83

tbl_smb2_main_hammer_second_sprite_tiles:
    .byte $81, $83, $80, $82

tbl_smb2_main_hammer_sprite_attributes:
    .byte $03, $03, $c3, $c3

sub_smb2_main_draw_hammer:
    LDY Misc_SprDataOffset,x  ; get misc object OAM data offset
    LDA TimerControl
    BNE bra_smb2_main_force_hammer_pose  ; if master timer control set, skip this part
    LDA Misc_State,x  ; otherwise get hammer's state
    AND #%01111111  ; mask out d7
    CMP #$01  ; check to see if set to 1 yet
    BEQ bra_smb2_main_select_hammer_pose  ; if so, branch
bra_smb2_main_force_hammer_pose:
    LDX #$00  ; reset offset here
    BEQ bra_smb2_main_render_hammer  ; do unconditional branch to rendering part
bra_smb2_main_select_hammer_pose:
    LDA FrameCounter  ; get frame counter
    LSR  ; move d3-d2 to d1-d0
    LSR
    AND #%00000011  ; mask out all but d1-d0 (changes every four frames)
    TAX  ; use as timing offset
bra_smb2_main_render_hammer:
    LDA Misc_Rel_YPos  ; get relative vertical coordinate
    CLC
    ADC tbl_smb2_main_hammer_first_sprite_y_offsets,x  ; add first sprite vertical adder based on offset
    STA Sprite_Y_Position,y  ; store as sprite Y coordinate for first sprite
    CLC
    ADC tbl_smb2_main_hammer_second_sprite_y_offsets,x  ; add second sprite vertical adder based on offset
    STA Sprite_Y_Position+4,y  ; store as sprite Y coordinate for second sprite
    LDA Misc_Rel_XPos  ; get relative horizontal coordinate
    CLC
    ADC tbl_smb2_main_hammer_first_sprite_x_offsets,x  ; add first sprite horizontal adder based on offset
    STA Sprite_X_Position,y  ; store as sprite X coordinate for first sprite
    CLC
    ADC tbl_smb2_main_hammer_second_sprite_x_offsets,x  ; add second sprite horizontal adder based on offset
    STA Sprite_X_Position+4,y  ; store as sprite X coordinate for second sprite
    LDA tbl_smb2_main_hammer_first_sprite_tiles,x
    STA Sprite_Tilenumber,y  ; get and store tile number of first sprite
    LDA tbl_smb2_main_hammer_second_sprite_tiles,x
    STA Sprite_Tilenumber+4,y  ; get and store tile number of second sprite
    LDA tbl_smb2_main_hammer_sprite_attributes,x
    STA Sprite_Attributes,y  ; get and store attribute bytes for both
    STA Sprite_Attributes+4,y  ; note in this case they use the same data
    LDX ObjectOffset  ; get misc object offset
    LDA Misc_OffscreenBits
    AND #%11111100  ; check offscreen bits
    BEQ bra_smb2_main_exit_hammer_draw  ; if all bits clear, leave object alone
    LDA #$00
    STA Misc_State,x  ; otherwise nullify misc object state
    LDA #$f8
    JSR sub_smb2_main_fill_two_sprite_fields  ; do sub to move hammer sprites offscreen
bra_smb2_main_exit_hammer_draw:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold tile numbers ($01 addressed in draw floatey number part)
; $02 - used to hold Y coordinate for floatey number
; $03 - residual byte used for flip (but value set here affects nothing)
; $04 - attribute byte for floatey number
; $05 - used as X coordinate for floatey number

tbl_smb2_main_flagpole_score_number_tiles:
    .byte $f9, $50
    .byte $f7, $50
    .byte $fa, $fb
    .byte $f8, $fb
    .byte $f6, $fb
    .byte $fd, $fe

sub_smb2_main_render_flagpole_graphics:
    LDY Enemy_SprDataOffset,x  ; get sprite data offset for flagpole flag
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as X coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels and store
    STA Sprite_X_Position+4,y  ; as X coordinate for second and third sprites
    STA Sprite_X_Position+8,y
    CLC
    ADC #$0c  ; add twelve more pixels and
    STA $05  ; store here to be used later by floatey number
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    JSR sub_smb2_main_fill_two_sprite_fields  ; and do sub to dump into first and second sprites
    ADC #$08  ; add eight pixels
    STA Sprite_Y_Position+8,y  ; and store into third sprite
    LDA FlagpoleFNum_Y_Pos  ; get vertical coordinate for floatey number
    STA $02  ; store it here
    LDA #$01
    STA $03  ; set value for flip which will not be used, and
    STA $04  ; attribute byte for floatey number
    STA Sprite_Attributes,y  ; set attribute bytes for all three sprites
    STA Sprite_Attributes+4,y
    STA Sprite_Attributes+8,y
    LDA #$7e
    STA Sprite_Tilenumber,y  ; put triangle shaped tile
    STA Sprite_Tilenumber+8,y  ; into first and third sprites
    LDA #$7f
    STA Sprite_Tilenumber+4,y  ; put skull tile into second sprite
    LDA FlagpoleCollisionYPos  ; get vertical coordinate at time of collision
    BEQ bra_smb2_main_clip_flagpole_sprites  ; if zero, branch ahead
    TYA
    CLC  ; add 12 bytes to sprite data offset
    ADC #$0c
    TAY  ; put back in Y
    LDA FlagpoleScore  ; get offset used to award points for touching flagpole
    ASL  ; multiply by 2 to get proper offset here
    TAX
    LDA tbl_smb2_main_flagpole_score_number_tiles,x  ; get appropriate tile data
    STA $00
    LDA tbl_smb2_main_flagpole_score_number_tiles+1,x
    JSR sub_smb2_main_draw_one_sprite_row  ; use it to render floatey number

bra_smb2_main_clip_flagpole_sprites:
    LDX ObjectOffset  ; get object offset for flag
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA Enemy_OffscreenBits  ; get offscreen bits
    AND #%00001110  ; mask out all but d3-d1
    BEQ bra_smb2_main_exit_sprite_data_fill  ; if none of these bits set, branch to leave

; -------------------------------------------------------------------------------------
