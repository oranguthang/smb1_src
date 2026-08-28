; -------------------------------------------------------------------------------------
; $00 - used in adding to get proper offset

sub_relative_player_position:
    LDX #$00  ; set offsets for relative cooordinates
    LDY #$00  ; routine to correspond to player object
    JMP loc_finish_relative_object_position  ; get the coordinates

sub_relative_bubble_position:
    LDY #$01  ; set for air bubble offsets
    JSR sub_get_sprite_object_array_offset  ; modify X to get proper air bubble offset
    LDY #$03
    JMP loc_finish_relative_object_position  ; get the coordinates

sub_relative_fireball_position:
    LDY #$00  ; set for fireball offsets
    JSR sub_get_sprite_object_array_offset  ; modify X to get proper fireball offset
    LDY #$02
loc_finish_relative_object_position:
    JSR sub_get_object_relative_position  ; get the coordinates
    LDX ram_object_offset  ; return original offset
    RTS  ; leave

sub_relative_misc_position:
    LDY #$02  ; set for misc object offsets
    JSR sub_get_sprite_object_array_offset  ; modify X to get proper misc object offset
    LDY #$06
    JMP loc_finish_relative_object_position  ; get the coordinates

sub_relative_enemy_position:
    LDA #$01  ; get coordinates of enemy object
    LDY #$01  ; relative to the screen
    JMP sub_get_variable_object_relative_position

sub_relative_block_position:
    LDA #$09  ; get coordinates of one block object
    LDY #$04  ; relative to the screen
    JSR sub_get_variable_object_relative_position
    INX  ; adjust offset for other block object if any
    INX
    LDA #$09
    INY  ; adjust other and get coordinates for other one

sub_get_variable_object_relative_position:
    STX $00  ; store value to add to A here
    CLC
    ADC $00  ; add A to value stored
    TAX  ; use as enemy offset
    JSR sub_get_object_relative_position
    LDX ram_object_offset  ; reload old object offset and leave
    RTS

sub_get_object_relative_position:
    LDA ram_spr_object_y_position,x  ; load vertical coordinate low
    STA ram_spr_object_rel_y_pos,y  ; store here
    LDA ram_spr_object_x_position,x  ; load horizontal coordinate
    SEC  ; subtract left edge coordinate
    SBC ram_screen_left_x_pos
    STA ram_spr_object_rel_x_pos,y  ; store result here
    RTS

; -------------------------------------------------------------------------------------
; $00 - used as temp variable to hold offscreen bits

sub_get_player_offscreen_bits:
    LDX #$00  ; set offsets for player-specific variables
    LDY #$00  ; and get offscreen information about player
    JMP loc_compute_and_store_offscreen_bits

sub_get_fireball_offscreen_bits:
    LDY #$00  ; set for fireball offsets
    JSR sub_get_sprite_object_array_offset  ; modify X to get proper fireball offset
    LDY #$02  ; set other offset for fireball's offscreen bits
    JMP loc_compute_and_store_offscreen_bits  ; and get offscreen information about fireball

sub_get_bubble_offscreen_bits:
    LDY #$01  ; set for air bubble offsets
    JSR sub_get_sprite_object_array_offset  ; modify X to get proper air bubble offset
    LDY #$03  ; set other offset for airbubble's offscreen bits
    JMP loc_compute_and_store_offscreen_bits  ; and get offscreen information about air bubble

sub_get_misc_offscreen_bits:
    LDY #$02  ; set for misc object offsets
    JSR sub_get_sprite_object_array_offset  ; modify X to get proper misc object offset
    LDY #$06  ; set other offset for misc object's offscreen bits
    JMP loc_compute_and_store_offscreen_bits  ; and get offscreen information about misc object

tbl_sprite_object_array_offsets:
    .byte $07, $16, $0d

sub_get_sprite_object_array_offset:
    TXA  ; move offset to A
    CLC
    ADC tbl_sprite_object_array_offsets,y  ; add amount of bytes to offset depending on setting in Y
    TAX  ; put back in X and leave
    RTS

sub_get_enemy_offscreen_bits:
    LDA #$01  ; set A to add 1 byte in order to get enemy offset
    LDY #$01  ; set Y to put offscreen bits in ram_enemy_offscreen_bits
    JMP loc_select_object_offscreen_slot

sub_get_block_offscreen_bits:
    LDA #$09  ; set A to add 9 bytes in order to get block obj offset
    LDY #$04  ; set Y to put offscreen bits in ram_block_offscreen_bits

loc_select_object_offscreen_slot:
    STX $00
    CLC  ; add contents of X to A to get
    ADC $00  ; appropriate offset, then give back to X
    TAX

loc_compute_and_store_offscreen_bits:
    TYA  ; save offscreen bits offset to stack for now
    PHA
    JSR sub_compute_object_offscreen_bits
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

sub_compute_object_offscreen_bits:
    JSR sub_get_horizontal_offscreen_bits  ; do subroutine here
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    STA $00  ; store here
    JMP loc_get_vertical_offscreen_bits

; --------------------------------
; (these apply to these three subsections)
; $04 - used to store proper offset
; $05 - used as adder in sub_select_offscreen_bits_by_distance
; $06 - used to store preset value used to compare to pixel difference in $07
; $07 - used to store difference between coordinates of object and screen edges

tbl_horizontal_offscreen_bit_masks:
    .byte $7f, $3f, $1f, $0f, $07, $03, $01, $00
    .byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff

tbl_horizontal_offscreen_default_indices:
    .byte $07, $0f, $07

sub_get_horizontal_offscreen_bits:
    STX $04  ; save position in buffer to here
    LDY #$01  ; start with right side of screen
bra_check_horizontal_screen_edge:
    LDA ram_screen_edge_x_pos,y  ; get pixel coordinate of edge
    SEC  ; get difference between pixel coordinate of edge
    SBC ram_spr_object_x_position,x  ; and pixel coordinate of object position
    STA $07  ; store here
    LDA ram_screen_edge_page_loc,y  ; get page location of edge
    SBC ram_spr_object_page_loc,x  ; subtract from page location of object position
    LDX tbl_horizontal_offscreen_default_indices,y  ; load offset value here
    CMP #$00
    BMI bra_load_horizontal_offscreen_bits  ; if beyond right edge or in front of left edge, branch
    LDX tbl_horizontal_offscreen_default_indices+1,y  ; if not, load alternate offset value here
    CMP #$01
    BPL bra_load_horizontal_offscreen_bits  ; if one page or more to the left of either edge, branch
    LDA #$38  ; if no branching, load value here and store
    STA $06
    LDA #$08  ; load some other value and execute subroutine
    JSR sub_select_offscreen_bits_by_distance
bra_load_horizontal_offscreen_bits:
    LDA tbl_horizontal_offscreen_bit_masks,x  ; get bits here
    LDX $04  ; reobtain position in buffer
    CMP #$00  ; if bits not zero, branch to leave
    BNE bra_exit_horizontal_offscreen_check
    DEY  ; otherwise, do left side of screen now
    BPL bra_check_horizontal_screen_edge  ; branch if not already done with left side
bra_exit_horizontal_offscreen_check:
    RTS

; --------------------------------

tbl_vertical_offscreen_bit_masks:
.if con_revision_profile = con_revision_profile_ann
    .byte $0f, $07, $03, $01
    .byte $00, $08, $0c, $0e
    .byte $00
.else
    .byte $00, $08, $0c, $0e
    .byte $0f, $07, $03, $01
    .byte $00
.endif

tbl_vertical_offscreen_default_indices:
    .byte $04, $00, $04

tbl_vertical_screen_edge_units:
.if con_revision_profile = con_revision_profile_ann
    .byte $00, $ff
.else
    .byte $ff, $00
.endif

loc_get_vertical_offscreen_bits:
    STX $04  ; save position in buffer to here
    LDY #$01  ; start with top of screen
bra_check_vertical_screen_edge:
    LDA tbl_vertical_screen_edge_units,y  ; load coordinate for edge of vertical unit
    SEC
    SBC ram_spr_object_y_position,x  ; subtract from vertical coordinate of object
    STA $07  ; store here
    LDA #$01  ; subtract one from vertical high byte of object
    SBC ram_spr_object_y_high_pos,x
    LDX tbl_vertical_offscreen_default_indices,y  ; load offset value here
    CMP #$00
    BMI bra_load_vertical_offscreen_bits  ; if under top of the screen or beyond bottom, branch
    LDX tbl_vertical_offscreen_default_indices+1,y  ; if not, load alternate offset value here
    CMP #$01
    BPL bra_load_vertical_offscreen_bits  ; if one vertical unit or more above the screen, branch
    LDA #$20  ; if no branching, load value here and store
    STA $06
    LDA #$04  ; load some other value and execute subroutine
    JSR sub_select_offscreen_bits_by_distance
bra_load_vertical_offscreen_bits:
    LDA tbl_vertical_offscreen_bit_masks,x  ; get offscreen data bits using offset
    LDX $04  ; reobtain position in buffer
    CMP #$00
    BNE bra_exit_vertical_offscreen_check  ; if bits not zero, branch to leave
    DEY  ; otherwise, do bottom of the screen now
    BPL bra_check_vertical_screen_edge
bra_exit_vertical_offscreen_check:
    RTS

; --------------------------------

sub_select_offscreen_bits_by_distance:
    STA $05  ; store current value in A here
    LDA $07  ; get pixel difference
    CMP $06  ; compare to preset value
    BCS bra_exit_offscreen_distance_division  ; if pixel difference >= preset value, branch
    LSR  ; divide by eight
    LSR
    LSR
    AND #$07  ; mask out all but 3 LSB
    CPY #$01  ; right side of the screen or top?
    BCS bra_select_offscreen_bit_index  ; if so, branch, use difference / 8 as offset
    ADC $05  ; if not, add value to difference / 8
bra_select_offscreen_bit_index:
    TAX  ; use as offset
bra_exit_offscreen_distance_division:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - tile numbers
; $02 - Y coordinate
; $03 - flip control
; $04 - sprite attributes
; $05 - X coordinate

loc_draw_two_tile_sprite_row:
    LDA $03  ; get saved flip control bits
    LSR
    LSR  ; move d1 into carry
    LDA $00
    BCC bra_draw_unflipped_sprite_row  ; if d1 not set, branch
    STA ram_sprite_tilenumber+4,y  ; store first tile into second sprite
    LDA $01  ; and second into first sprite
    STA ram_sprite_tilenumber,y
    LDA #$40  ; activate horizontal flip OAM attribute
    BNE bra_store_sprite_row_attributes  ; and unconditionally branch
bra_draw_unflipped_sprite_row:
    STA ram_sprite_tilenumber,y  ; store first tile into first sprite
    LDA $01  ; and second into second sprite
    STA ram_sprite_tilenumber+4,y
    LDA #$00  ; clear bit for horizontal flip
bra_store_sprite_row_attributes:
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
.if con_revision_profile <> con_revision_profile_pal .and con_revision_profile <> con_revision_profile_fds_smb .and con_revision_profile <> con_revision_profile_ann
    .byte $ff, $ff, $ff, $ff, $ff, $ff
.endif
