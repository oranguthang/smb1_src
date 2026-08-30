sub_smb2_main_relative_player_position:
    LDX #$00  ; set offsets for relative cooordinates
    LDY #$00  ; routine to correspond to player object
    JMP loc_smb2_main_finish_relative_object_position  ; get the coordinates

sub_smb2_main_relative_bubble_position:
    LDY #$01  ; set for air bubble offsets
    JSR sub_smb2_main_get_sprite_object_array_offset  ; modify X to get proper air bubble offset
    LDY #$03
    JMP loc_smb2_main_finish_relative_object_position  ; get the coordinates

sub_smb2_main_relative_fireball_position:
    LDY #$00  ; set for fireball offsets
    JSR sub_smb2_main_get_sprite_object_array_offset  ; modify X to get proper fireball offset
    LDY #$02
loc_smb2_main_finish_relative_object_position:
    JSR sub_smb2_main_get_object_relative_position  ; get the coordinates
    LDX ObjectOffset  ; return original offset
    RTS  ; leave

sub_smb2_main_relative_misc_position:
    LDY #$02  ; set for misc object offsets
    JSR sub_smb2_main_get_sprite_object_array_offset  ; modify X to get proper misc object offset
    LDY #$06
    JMP loc_smb2_main_finish_relative_object_position  ; get the coordinates

sub_smb2_main_relative_enemy_position:
    LDA #$01  ; get coordinates of enemy object
    LDY #$01  ; relative to the screen
    JMP sub_smb2_main_get_variable_object_relative_position

sub_smb2_main_relative_block_position:
    LDA #$09  ; get coordinates of one block object
    LDY #$04  ; relative to the screen
    JSR sub_smb2_main_get_variable_object_relative_position
    INX  ; adjust offset for other block object if any
    INX
    LDA #$09
    INY  ; adjust other and get coordinates for other one

sub_smb2_main_get_variable_object_relative_position:
    STX $00  ; store value to add to A here
    CLC
    ADC $00  ; add A to value stored
    TAX  ; use as enemy offset
    JSR sub_smb2_main_get_object_relative_position
    LDX ObjectOffset  ; reload old object offset and leave
    RTS

sub_smb2_main_get_object_relative_position:
    LDA SprObject_Y_Position,x  ; load vertical coordinate low
    STA SprObject_Rel_YPos,y  ; store here
    LDA SprObject_X_Position,x  ; load horizontal coordinate
    SEC  ; subtract left edge coordinate
    SBC ScreenLeft_X_Pos
    STA SprObject_Rel_XPos,y  ; store result here
    RTS

; -------------------------------------------------------------------------------------
; $00 - used as temp variable to hold offscreen bits

sub_smb2_main_get_player_offscreen_bits:
    LDX #$00  ; set offsets for player-specific variables
    LDY #$00  ; and get offscreen information about player
    JMP loc_smb2_main_compute_and_store_offscreen_bits

sub_smb2_main_get_fireball_offscreen_bits:
    LDY #$00  ; set for fireball offsets
    JSR sub_smb2_main_get_sprite_object_array_offset  ; modify X to get proper fireball offset
    LDY #$02  ; set other offset for fireball's offscreen bits
    JMP loc_smb2_main_compute_and_store_offscreen_bits  ; and get offscreen information about fireball

sub_smb2_main_get_bubble_offscreen_bits:
    LDY #$01  ; set for air bubble offsets
    JSR sub_smb2_main_get_sprite_object_array_offset  ; modify X to get proper air bubble offset
    LDY #$03  ; set other offset for airbubble's offscreen bits
    JMP loc_smb2_main_compute_and_store_offscreen_bits  ; and get offscreen information about air bubble

sub_smb2_main_get_misc_offscreen_bits:
    LDY #$02  ; set for misc object offsets
    JSR sub_smb2_main_get_sprite_object_array_offset  ; modify X to get proper misc object offset
    LDY #$06  ; set other offset for misc object's offscreen bits
    JMP loc_smb2_main_compute_and_store_offscreen_bits  ; and get offscreen information about misc object

tbl_smb2_main_sprite_object_array_offsets:
    .byte $07, $16, $0d

sub_smb2_main_get_sprite_object_array_offset:
    TXA  ; move offset to A
    CLC
    ADC tbl_smb2_main_sprite_object_array_offsets,y  ; add amount of bytes to offset depending on setting in Y
    TAX  ; put back in X and leave
    RTS

sub_smb2_main_get_enemy_offscreen_bits:
    LDA #$01  ; set A to add 1 byte in order to get enemy offset
    LDY #$01  ; set Y to put offscreen bits in Enemy_OffscreenBits
    JMP loc_smb2_main_select_object_offscreen_slot

sub_smb2_main_get_block_offscreen_bits:
    LDA #$09  ; set A to add 9 bytes in order to get block obj offset
    LDY #$04  ; set Y to put offscreen bits in Block_OffscreenBits

loc_smb2_main_select_object_offscreen_slot:
    STX $00
    CLC  ; add contents of X to A to get
    ADC $00  ; appropriate offset, then give back to X
    TAX

loc_smb2_main_compute_and_store_offscreen_bits:
    TYA  ; save offscreen bits offset to stack for now
    PHA
    JSR sub_smb2_main_compute_object_offscreen_bits
    ASL  ; move low nybble to high nybble
    ASL
    ASL
    ASL
    ORA $00  ; mask together with previously saved low nybble
    STA $00  ; store both here
    PLA  ; get offscreen bits offset from stack
    TAY
    LDA $00  ; get value here and store elsewhere
    STA SprObject_OffscrBits,y
    LDX ObjectOffset
    RTS

sub_smb2_main_compute_object_offscreen_bits:
    JSR sub_smb2_main_get_horizontal_offscreen_bits  ; do subroutine here
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    STA $00  ; store here
    JMP loc_smb2_main_get_vertical_offscreen_bits

; --------------------------------
; (these apply to these three subsections)
; $04 - used to store proper offset
; $05 - used as adder in DividePDiff
; $06 - used to store preset value used to compare to pixel difference in $07
; $07 - used to store difference between coordinates of object and screen edges

off_smb2_main_horizontal_offscreen_bit_masks:
    .byte $7f, $3f, $1f, $0f, $07, $03, $01, $00
    .byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff

tbl_smb2_main_horizontal_offscreen_default_indices:
    .byte $07, $0f, $07

sub_smb2_main_get_horizontal_offscreen_bits:
    STX $04  ; save position in buffer to here
    LDY #$01  ; start with right side of screen
bra_smb2_main_check_horizontal_screen_edge:
    LDA ScreenEdge_X_Pos,y  ; get pixel coordinate of edge
    SEC  ; get difference between pixel coordinate of edge
    SBC SprObject_X_Position,x  ; and pixel coordinate of object position
    STA $07  ; store here
    LDA ScreenEdge_PageLoc,y  ; get page location of edge
    SBC SprObject_PageLoc,x  ; subtract from page location of object position
    LDX tbl_smb2_main_horizontal_offscreen_default_indices,y  ; load offset value here
    CMP #$00
    BMI bra_smb2_main_load_horizontal_offscreen_bits  ; if beyond right edge or in front of left edge, branch
    LDX tbl_smb2_main_horizontal_offscreen_default_indices+1,y  ; if not, load alternate offset value here
    CMP #$01
    BPL bra_smb2_main_load_horizontal_offscreen_bits  ; if one page or more to the left of either edge, branch
    LDA #$38  ; if no branching, load value here and store
    STA $06
    LDA #$08  ; load some other value and execute subroutine
    JSR sub_smb2_main_select_offscreen_bits_by_distance
bra_smb2_main_load_horizontal_offscreen_bits:
    LDA off_smb2_main_horizontal_offscreen_bit_masks,x  ; get bits here
    LDX $04  ; reobtain position in buffer
    CMP #$00  ; if bits not zero, branch to leave
    BNE bra_smb2_main_exit_horizontal_offscreen_check
    DEY  ; otherwise, do left side of screen now
    BPL bra_smb2_main_check_horizontal_screen_edge  ; branch if not already done with left side
bra_smb2_main_exit_horizontal_offscreen_check:
    RTS

; --------------------------------

off_smb2_main_vertical_offscreen_bit_masks:
    .byte $0f, $07, $03, $01
    .byte $00, $08, $0c, $0e
    .byte $00

tbl_smb2_main_vertical_offscreen_default_indices:
    .byte $04, $00, $04

off_smb2_main_vertical_screen_edge_units:
    .byte $00, $ff

loc_smb2_main_get_vertical_offscreen_bits:
    STX $04  ; save position in buffer to here
    LDY #$01  ; start with bottom of screen
bra_smb2_main_check_vertical_screen_edge:
    LDA off_smb2_main_vertical_screen_edge_units,y  ; load coordinate for edge of vertical unit
    SEC
    SBC SprObject_Y_Position,x  ; subtract from vertical coordinate of object
    STA $07  ; store here
    LDA #$01  ; subtract one from vertical high byte of object
    SBC SprObject_Y_HighPos,x
    LDX tbl_smb2_main_vertical_offscreen_default_indices,y  ; load offset value here
    CMP #$00
    BMI bra_smb2_main_load_vertical_offscreen_bits  ; if under top of the screen or beyond bottom, branch
    LDX tbl_smb2_main_vertical_offscreen_default_indices+1,y  ; if not, load alternate offset value here
    CMP #$01
    BPL bra_smb2_main_load_vertical_offscreen_bits  ; if one vertical unit or more above the screen, branch
    LDA #$20  ; if no branching, load value here and store
    STA $06
    LDA #$04  ; load some other value and execute subroutine
    JSR sub_smb2_main_select_offscreen_bits_by_distance
bra_smb2_main_load_vertical_offscreen_bits:
    LDA off_smb2_main_vertical_offscreen_bit_masks,x  ; get offscreen data bits using offset
    LDX $04  ; reobtain position in buffer
    CMP #$00
    BNE bra_smb2_main_exit_vertical_offscreen_check  ; if bits not zero, branch to leave
    DEY  ; otherwise, do top of the screen now
    BPL bra_smb2_main_check_vertical_screen_edge
bra_smb2_main_exit_vertical_offscreen_check:
    RTS

; --------------------------------

sub_smb2_main_select_offscreen_bits_by_distance:
    STA $05  ; store current value in A here
    LDA $07  ; get pixel difference
    CMP $06  ; compare to preset value
    BCS bra_smb2_main_exit_offscreen_distance_division  ; if pixel difference >= preset value, branch
    LSR  ; divide by eight
    LSR
    LSR
    AND #$07  ; mask out all but 3 LSB
    CPY #$01  ; right side of the screen or top?
    BCS bra_smb2_main_select_offscreen_bit_index  ; if so, branch, use difference / 8 as offset
    ADC $05  ; if not, add value to difference / 8
bra_smb2_main_select_offscreen_bit_index:
    TAX  ; use as offset
bra_smb2_main_exit_offscreen_distance_division:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - tile numbers
; $02 - Y coordinate
; $03 - flip control
; $04 - sprite attributes
; $05 - X coordinate

loc_smb2_main_draw_two_tile_sprite_row:
    LDA $03  ; get saved flip control bits
    LSR
    LSR  ; move d1 into carry
    LDA $00
    BCC bra_smb2_main_draw_unflipped_sprite_row  ; if d1 not set, branch
    STA Sprite_Tilenumber+4,y  ; store first tile into second sprite
    LDA $01  ; and second into first sprite
    STA Sprite_Tilenumber,y
    LDA #$40  ; activate horizontal flip OAM attribute
    BNE bra_smb2_main_store_sprite_row_attributes  ; and unconditionally branch
bra_smb2_main_draw_unflipped_sprite_row:
    STA Sprite_Tilenumber,y  ; store first tile into first sprite
    LDA $01  ; and second into second sprite
    STA Sprite_Tilenumber+4,y
    LDA #$00  ; clear bit for horizontal flip
bra_smb2_main_store_sprite_row_attributes:
    ORA $04  ; add other OAM attributes if necessary
    STA Sprite_Attributes,y  ; store sprite attributes
    STA Sprite_Attributes+4,y
    LDA $02  ; now the y coordinates
    STA Sprite_Y_Position,y  ; note because they are
    STA Sprite_Y_Position+4,y  ; side by side, they are the same
    LDA $05
    STA Sprite_X_Position,y  ; store x coordinate, then
    CLC  ; add 8 pixels and store another to
    ADC #$08  ; put them side by side
    STA Sprite_X_Position+4,y
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

; unused byte
    .byte $ff

; -------------------------------------------------------------------------------------
