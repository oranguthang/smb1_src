; -------------------------------------------------------------------------------------
; $00 - used to hold one of bitmasks, or offset
; $01 - used for relative X coordinate, also used to store middle screen page location
; $02 - used for relative Y coordinate, also used to store middle screen coordinate

; this data added to relative coordinates of sprite objects
; stored in order: left edge, top edge, right edge, bottom edge
tbl_bounding_box_relative_edges:
    .byte $02, $08, $0e, $20
    .byte $03, $14, $0d, $20
    .byte $02, $14, $0e, $20
    .byte $02, $09, $0e, $15
    .byte $00, $00, $18, $06
    .byte $00, $00, $20, $0d
    .byte $00, $00, $30, $0d
    .byte $00, $00, $08, $08
    .byte $06, $04, $0a, $08
.if con_revision_profile = con_revision_profile_pal
    .byte $03, $0c, $0d
.else
    .byte $03, $0e, $0d
.endif
.if con_revision_profile = con_revision_profile_ann
    .byte $16
.else
    .byte $14
.endif
    .byte $00, $02, $10, $15
    .byte $04, $04, $0c, $1c

sub_get_fireball_bound_box:
    TXA  ; add seven bytes to offset
    CLC  ; to use in routines as offset for fireball
    ADC #$07
    TAX
    LDY #$02  ; set offset for relative coordinates
    BNE bra_use_fireball_bounding_box  ; unconditional branch

sub_get_misc_bound_box:
    TXA  ; add nine bytes to offset
    CLC  ; to use in routines as offset for misc object
    ADC #$09
    TAX
    LDY #$06  ; set offset for relative coordinates
bra_use_fireball_bounding_box:
    JSR sub_bounding_box_core  ; get bounding box coordinates
    JMP loc_clip_bounding_box_right_edge  ; jump to handle any offscreen coordinates

sub_get_enemy_bound_box:
    LDY #$48  ; store bitmask here for now
    STY $00
    LDY #$44  ; store another bitmask here for now and jump
    JMP loc_get_masked_offscreen_bits

sub_small_platform_bound_box:
    LDY #$08  ; store bitmask here for now
    STY $00
    LDY #$04  ; store another bitmask here for now

loc_get_masked_offscreen_bits:
    LDA ram_enemy_x_position,x  ; get enemy object position relative
    SEC  ; to the left side of the screen
    SBC ram_screen_left_x_pos
    STA $01  ; store here
    LDA ram_enemy_page_loc,x  ; subtract borrow from current page location
    SBC ram_screen_left_page_loc  ; of left side
    BMI bra_store_masked_offscreen_bits  ; if enemy object is beyond left edge, branch
    ORA $01
    BEQ bra_store_masked_offscreen_bits  ; if precisely at the left edge, branch
    LDY $00  ; if to the right of left edge, use value in $00 for A
bra_store_masked_offscreen_bits:
    TYA  ; otherwise use contents of Y
    AND ram_enemy_offscreen_bits  ; preserve bitwise whatever's in here
    STA ram_enemy_offscr_bits_masked,x  ; save masked offscreen bits here
    BNE bra_move_bounding_box_offscreen  ; if anything set here, branch
    JMP loc_select_fireball_bounding_box_offset  ; otherwise, do something else

sub_large_platform_bound_box:
    INX  ; increment X to get the proper offset
    JSR sub_get_horizontal_offscreen_bits  ; then jump directly to the sub for horizontal offscreen bits
    DEX  ; decrement to return to original offset
    CMP #$fe  ; if completely offscreen, branch to put entire bounding
    BCS bra_move_bounding_box_offscreen  ; box offscreen, otherwise start getting coordinates

loc_select_fireball_bounding_box_offset:
    TXA  ; add 1 to offset to properly address
    CLC  ; the enemy object memory locations
    ADC #$01
    TAX
    LDY #$01  ; load 1 as offset here, same reason
    JSR sub_bounding_box_core  ; do a sub to get the coordinates of the bounding box
    JMP loc_clip_bounding_box_right_edge  ; jump to handle offscreen coordinates of bounding box

bra_move_bounding_box_offscreen:
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

; Build an actor bounding box from relative position and size-control tables

; Inputs:
; X - actor slot and associated relative-position fields

; Outputs:
; Bounding-box coordinates for the selected actor are written to RAM

; Clobbers:
; A, X, Y
sub_bounding_box_core:
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
    ADC tbl_bounding_box_relative_edges,x  ; and store somewhere using same offset * 4
    STA ram_bounding_box_ul_corner,y  ; store here
    LDA $01
    CLC
    ADC tbl_bounding_box_relative_edges+2,x  ; add the third number in the bounding box data to the
    STA ram_bounding_box_lr_corner,y  ; relative horizontal coordinate and store
    INX  ; increment both offsets
    INY
    LDA $02  ; add the second number to the relative vertical coordinate
    CLC  ; using incremented offset and store using the other
    ADC tbl_bounding_box_relative_edges,x  ; incremented offset
    STA ram_bounding_box_ul_corner,y
    LDA $02
    CLC
    ADC tbl_bounding_box_relative_edges+2,x  ; add the fourth number to the relative vertical coordinate
    STA ram_bounding_box_lr_corner,y  ; and store
    PLA  ; get original offset loaded into $00 * y from stack
    TAY  ; use as Y
    LDX $00  ; get original offset and use as X again
    RTS

loc_clip_bounding_box_right_edge:
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
    BCC bra_clip_bounding_box_left_edge  ; if object is on the left side of the screen, branch
    LDA ram_bounding_box_dr_x_pos,y  ; check right-side edge of bounding box for offscreen
    BMI bra_store_right_screen_bounding_box  ; coordinates, branch if still on the screen
    LDA #$ff  ; load offscreen value here to use on one or both horizontal sides
    LDX ram_bounding_box_ul_x_pos,y  ; check left-side edge of bounding box for offscreen
    BMI bra_move_bounding_box_right_offscreen  ; coordinates, and branch if still on the screen
    STA ram_bounding_box_ul_x_pos,y  ; store offscreen value for left side
bra_move_bounding_box_right_offscreen:
    STA ram_bounding_box_dr_x_pos,y  ; store offscreen value for right side
bra_store_right_screen_bounding_box:
    LDX ram_object_offset  ; get object offset and leave
    RTS

bra_clip_bounding_box_left_edge:
    LDA ram_bounding_box_ul_x_pos,y  ; check left-side edge of bounding box for offscreen
    BPL bra_store_left_screen_bounding_box  ; coordinates, and branch if still on the screen
    CMP #$a0  ; check to see if left-side edge is in the middle of the
    BCC bra_store_left_screen_bounding_box  ; screen or really offscreen, and branch if still on
    LDA #$00
    LDX ram_bounding_box_dr_x_pos,y  ; check right-side edge of bounding box for offscreen
    BPL bra_move_bounding_box_left_offscreen  ; coordinates, branch if still onscreen
    STA ram_bounding_box_dr_x_pos,y  ; store offscreen value for right side
bra_move_bounding_box_left_offscreen:
    STA ram_bounding_box_ul_x_pos,y  ; store offscreen value for left side
bra_store_left_screen_bounding_box:
    LDX ram_object_offset  ; get object offset and leave
    RTS

; -------------------------------------------------------------------------------------
; $06 - second object's offset
; $07 - counter

sub_player_collision_core:
    LDX #$00  ; initialize X to use player's bounding box for comparison

sub_sprite_object_collision_core:
    STY $06  ; save contents of Y here
    LDA #$01
    STA $07  ; save value 1 here as counter, compare horizontal coordinates first

bra_check_bounding_box_axes:
    LDA ram_bounding_box_ul_corner,y  ; compare left/top coordinates
    CMP ram_bounding_box_ul_corner,x  ; of first and second objects' bounding boxes
    BCS bra_compare_first_box_opposite_edge  ; if first left/top => second, branch
    CMP ram_bounding_box_lr_corner,x  ; otherwise compare to right/bottom of second
    BCC bra_check_second_box_vertical_edge  ; if first left/top < second right/bottom, branch elsewhere
    BEQ bra_return_bounding_box_collision  ; if somehow equal, collision, thus branch
    LDA ram_bounding_box_lr_corner,y  ; if somehow greater, check to see if bottom of
    CMP ram_bounding_box_ul_corner,y  ; first object's bounding box is greater than its top
    BCC bra_return_bounding_box_collision  ; if somehow less, vertical wrap collision, thus branch
    CMP ram_bounding_box_ul_corner,x  ; otherwise compare bottom of first bounding box to the top
    BCS bra_return_bounding_box_collision  ; of second box, and if equal or greater, collision, thus branch
    LDY $06  ; otherwise return with carry clear and Y = $0006
    RTS  ; note horizontal wrapping never occurs

bra_check_second_box_vertical_edge:
    LDA ram_bounding_box_lr_corner,x  ; check to see if the vertical bottom of the box
    CMP ram_bounding_box_ul_corner,x  ; is greater than the vertical top
    BCC bra_return_bounding_box_collision  ; if somehow less, vertical wrap collision, thus branch
    LDA ram_bounding_box_lr_corner,y  ; otherwise compare horizontal right or vertical bottom
    CMP ram_bounding_box_ul_corner,x  ; of first box with horizontal left or vertical top of second box
    BCS bra_return_bounding_box_collision  ; if equal or greater, collision, thus branch
    LDY $06  ; otherwise return with carry clear and Y = $0006
    RTS

bra_compare_first_box_opposite_edge:
    CMP ram_bounding_box_ul_corner,x  ; compare first and second box horizontal left/vertical top again
    BEQ bra_return_bounding_box_collision  ; if first coordinate = second, collision, thus branch
    CMP ram_bounding_box_lr_corner,x  ; if not, compare with second object right or bottom edge
    BCC bra_return_bounding_box_collision  ; if left/top of first less than or equal to right/bottom of second
    BEQ bra_return_bounding_box_collision  ; then collision, thus branch
    CMP ram_bounding_box_lr_corner,y  ; otherwise check to see if top of first box is greater than bottom
    BCC bra_return_no_bounding_box_collision  ; if less than or equal, no collision, branch to end
    BEQ bra_return_no_bounding_box_collision
    LDA ram_bounding_box_lr_corner,y  ; otherwise compare bottom of first to top of second
    CMP ram_bounding_box_ul_corner,x  ; if bottom of first is greater than top of second, vertical wrap
    BCS bra_return_bounding_box_collision  ; collision, and branch, otherwise, proceed onwards here

bra_return_no_bounding_box_collision:
    CLC  ; clear carry, then load value set earlier, then leave
    LDY $06  ; like previous ones, if horizontal coordinates do not collide, we do
    RTS  ; not bother checking vertical ones, because what's the point?

bra_return_bounding_box_collision:
    INX  ; increment offsets on both objects to check
    INY  ; the vertical coordinates
    DEC $07  ; decrement counter to reflect this
    BPL bra_check_bounding_box_axes  ; if counter not expired, branch to loop
    SEC  ; otherwise we already did both sets, therefore collision, so set carry
    LDY $06  ; load original value set here earlier, then leave
    RTS

; -------------------------------------------------------------------------------------
; $02 - modified y coordinate
; $03 - stores metatile involved in block buffer collisions
; $04 - comes in with offset to block buffer adder data, goes out with low nybble x/y coordinate
; $05 - modified x coordinate
; $06-$07 - block buffer address

sub_check_enemy_block_buffer:
    PHA  ; save contents of A to stack
    TXA
    CLC  ; add 1 to X to run sub with enemy offset in mind
    ADC #$01
    TAX
    PLA  ; pull A from stack and jump elsewhere
    JMP loc_run_block_buffer_collision

; !(UNKNOWN) CODE-003 - intended caller and background-collision role
unused_misc_object_background_collision_setup:
    TXA
    CLC  ; supposedly used once to set offset for
    ADC #$0d  ; miscellaneous objects
    TAX
    LDY #$1b  ; supposedly used once to set offset for block buffer data
    JMP loc_shared_block_buffer_collision  ; probably used in early stages to do misc to bg collision detection

sub_check_fireball_block_buffer:
    LDY #$1a  ; set offset for block buffer adder data
    TXA
    CLC
    ADC #$07  ; add seven bytes to use
    TAX
loc_shared_block_buffer_collision:
    LDA #$00  ; set A to return vertical coordinate
loc_run_block_buffer_collision:
    JSR sub_block_buffer_collision  ; do collision detection subroutine for sprite object
    LDX ram_object_offset  ; get object offset
    CMP #$00  ; check to see if object bumped into anything
    RTS

tbl_block_buffer_object_offsets:
    .byte $00, $07, $0e

tbl_block_buffer_x_offsets:
    .byte $08, $03, $0c, $02, $02, $0d, $0d, $08
    .byte $03, $0c, $02, $02, $0d, $0d, $08, $03
    .byte $0c, $02, $02, $0d, $0d, $08, $00, $10
    .byte $04, $14, $04, $04

tbl_block_buffer_y_offsets:
    .byte $04, $20, $20, $08, $18, $08, $18, $02
    .byte $20, $20, $08, $18, $08, $18, $12, $20
    .byte $20, $18, $18, $18, $18, $18, $14, $14
    .byte $06, $06, $08, $10

sub_check_player_feet_block_buffer:
    INY  ; if branched here, increment to next set of adders

sub_check_player_head_block_buffer:
    LDA #$00  ; set flag to return vertical coordinate
.if con_revision_profile = con_revision_profile_vs
    JMP :+
.else
    .byte $2c  ; BIT instruction opcode
.endif

sub_check_player_side_block_buffer:
    LDA #$01  ; set flag to return horizontal coordinate
.if con_revision_profile = con_revision_profile_vs
    :
.endif
    LDX #$00  ; set offset for player object

sub_block_buffer_collision:
    PHA  ; save contents of A to stack
    STY $04  ; save contents of Y here
    LDA tbl_block_buffer_x_offsets,y  ; add horizontal coordinate
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
    JSR sub_get_block_buffer_addr  ; get address of block buffer into $06, $07
    LDY $04  ; get old contents of Y
    LDA ram_spr_object_y_position,x  ; get vertical coordinate of object
    CLC
    ADC tbl_block_buffer_y_offsets,y  ; add it to value obtained using Y as offset
    AND #%11110000  ; mask out low nybble
    SEC
    SBC #$20  ; subtract 32 pixels for the status bar
    STA $02  ; store result here
    TAY  ; use as offset for block buffer
    LDA ($06),y  ; check current content of block buffer
    STA $03  ; and store here
    LDY $04  ; get old contents of Y again
    PLA  ; pull A from stack
    BNE bra_return_block_buffer_x_coordinate  ; if A = 1, branch
    LDA ram_spr_object_y_position,x  ; if A = 0, load vertical coordinate
    JMP loc_return_block_buffer_y_coordinate  ; and jump
bra_return_block_buffer_x_coordinate:
    LDA ram_spr_object_x_position,x  ; otherwise load horizontal coordinate
loc_return_block_buffer_y_coordinate:
    AND #%00001111  ; and mask out high nybble
    STA $04  ; store masked out result here
    LDA $03  ; get saved content of block buffer
    RTS  ; and leave

; -------------------------------------------------------------------------------------

; unused byte
.if con_revision_profile = con_revision_profile_vs
    .res 6, $ff
.elseif con_revision_profile <> con_revision_profile_pal .and con_revision_profile <> con_revision_profile_fds_smb .and con_revision_profile <> con_revision_profile_ann
    .byte $ff
.endif
