; -------------------------------------------------------------------------------------
; $00 - offset to vine Y coordinate adder
; $02 - offset to sprite data

tbl_vine_y_offsets:
    .byte $00, $30

sub_draw_vine:
    STY $00  ; save offset here
    LDA ram_enemy_rel_y_pos  ; get relative vertical coordinate
    CLC
    ADC tbl_vine_y_offsets,y  ; add value using offset in Y to get value
    LDX ram_vine_obj_offset,y  ; get offset to vine
    LDY ram_enemy_spr_data_offset,x  ; get sprite data offset
    STY $02  ; store sprite data offset here
    JSR sub_six_sprite_stacker  ; stack six sprites on top of each other vertically
    LDA ram_enemy_rel_x_pos  ; get relative horizontal coordinate
    STA ram_sprite_x_position,y  ; store in first, third and fifth sprites
    STA ram_sprite_x_position+8,y
    STA ram_sprite_x_position+16,y
    CLC
    ADC #$06  ; add six pixels to second, fourth and sixth sprites
    STA ram_sprite_x_position+4,y  ; to give characteristic staggered vine shape to
    STA ram_sprite_x_position+12,y  ; our vertical stack of sprites
    STA ram_sprite_x_position+20,y
    LDA #%00100001  ; set bg priority and palette attribute bits
    STA ram_sprite_attributes,y  ; set in first, third and fifth sprites
    STA ram_sprite_attributes+8,y
    STA ram_sprite_attributes+16,y
    ORA #%01000000  ; additionally, set horizontal flip bit
    STA ram_sprite_attributes+4,y  ; for second, fourth and sixth sprites
    STA ram_sprite_attributes+12,y
    STA ram_sprite_attributes+20,y
    LDX #$05  ; set tiles for six sprites
bra_store_vine_sprite_tiles:
    LDA #$e1  ; set tile number for sprite
    STA ram_sprite_tilenumber,y
    INY  ; move offset to next sprite data
    INY
    INY
    INY
    DEX  ; move onto next sprite
    BPL bra_store_vine_sprite_tiles  ; loop until all sprites are done
    LDY $02  ; get original offset
    LDA $00  ; get offset to vine adding data
    BNE bra_clip_vine_top  ; if offset not zero, skip this part
    LDA #$e0
    STA ram_sprite_tilenumber,y  ; set other tile number for top of vine
bra_clip_vine_top:
    LDX #$00  ; start with the first sprite again
bra_check_vine_sprite_above_growth_start:
    LDA ram_vine_start_y_position  ; get original starting vertical coordinate
    SEC
    SBC ram_sprite_y_position,y  ; subtract top-most sprite's Y coordinate
    CMP #$64  ; if two coordinates are less than 100/$64 pixels
    BCC bra_advance_vine_sprite  ; apart, skip this to leave sprite alone
    LDA #$f8
    STA ram_sprite_y_position,y  ; otherwise move sprite offscreen
bra_advance_vine_sprite:
    INY  ; move offset to next OAM data
    INY
    INY
    INY
    INX  ; move onto next sprite
    CPX #$06  ; do this until all sprites are checked
    BNE bra_check_vine_sprite_above_growth_start
    LDY $00  ; return offset set earlier
    RTS

sub_six_sprite_stacker:
    LDX #$06  ; do six sprites
bra_stack_six_sprites:
    STA ram_sprite_data,y  ; store X or Y coordinate into OAM data
    CLC
    ADC #$08  ; add eight pixels
    INY
    INY  ; move offset four bytes forward
    INY
    INY
    DEX  ; do another sprite
    BNE bra_stack_six_sprites  ; do this until all sprites are done
    LDY $02  ; get saved OAM data offset and leave
    RTS

; -------------------------------------------------------------------------------------

tbl_hammer_first_sprite_x_offsets:
    .byte $04, $00, $04, $00

tbl_hammer_first_sprite_y_offsets:
    .byte $00, $04, $00, $04

tbl_hammer_second_sprite_x_offsets:
    .byte $00, $08, $00, $08

tbl_hammer_second_sprite_y_offsets:
    .byte $08, $00, $08, $00

tbl_hammer_first_sprite_tiles:
    .byte $80, $82, $81, $83

tbl_hammer_second_sprite_tiles:
    .byte $81, $83, $80, $82

tbl_hammer_sprite_attributes:
    .byte $03, $03, $c3, $c3

sub_draw_hammer:
    LDY ram_misc_spr_data_offset,x  ; get misc object OAM data offset
    LDA ram_timer_control
    BNE bra_force_hammer_pose  ; if master timer control set, skip this part
    LDA ram_misc_state,x  ; otherwise get hammer's state
    AND #%01111111  ; mask out d7
    CMP #$01  ; check to see if set to 1 yet
    BEQ bra_select_hammer_pose  ; if so, branch
bra_force_hammer_pose:
    LDX #$00  ; reset offset here
    BEQ bra_render_hammer  ; do unconditional branch to rendering part
bra_select_hammer_pose:
    LDA ram_frame_counter  ; get frame counter
    LSR  ; move d3-d2 to d1-d0
    LSR
    AND #%00000011  ; mask out all but d1-d0 (changes every four frames)
    TAX  ; use as timing offset
bra_render_hammer:
    LDA ram_misc_rel_y_pos  ; get relative vertical coordinate
    CLC
    ADC tbl_hammer_first_sprite_y_offsets,x  ; add first sprite vertical adder based on offset
    STA ram_sprite_y_position,y  ; store as sprite Y coordinate for first sprite
    CLC
    ADC tbl_hammer_second_sprite_y_offsets,x  ; add second sprite vertical adder based on offset
    STA ram_sprite_y_position+4,y  ; store as sprite Y coordinate for second sprite
    LDA ram_misc_rel_x_pos  ; get relative horizontal coordinate
    CLC
    ADC tbl_hammer_first_sprite_x_offsets,x  ; add first sprite horizontal adder based on offset
    STA ram_sprite_x_position,y  ; store as sprite X coordinate for first sprite
    CLC
    ADC tbl_hammer_second_sprite_x_offsets,x  ; add second sprite horizontal adder based on offset
    STA ram_sprite_x_position+4,y  ; store as sprite X coordinate for second sprite
    LDA tbl_hammer_first_sprite_tiles,x
    STA ram_sprite_tilenumber,y  ; get and store tile number of first sprite
    LDA tbl_hammer_second_sprite_tiles,x
    STA ram_sprite_tilenumber+4,y  ; get and store tile number of second sprite
    LDA tbl_hammer_sprite_attributes,x
    STA ram_sprite_attributes,y  ; get and store attribute bytes for both
    STA ram_sprite_attributes+4,y  ; note in this case they use the same data
    LDX ram_object_offset  ; get misc object offset
    LDA ram_misc_offscreen_bits
    AND #%11111100  ; check offscreen bits
    BEQ bra_exit_hammer_draw  ; if all bits clear, leave object alone
    LDA #$00
    STA ram_misc_state,x  ; otherwise nullify misc object state
    LDA #$f8
    JSR sub_fill_two_sprite_fields  ; do sub to move hammer sprites offscreen
bra_exit_hammer_draw:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold tile numbers ($01 addressed in draw floatey number part)
; $02 - used to hold Y coordinate for floatey number
; $03 - residual byte used for flip (but value set here affects nothing)
; $04 - attribute byte for floatey number
; $05 - used as X coordinate for floatey number

tbl_flagpole_score_number_tiles:
    .byte $f9, $50
    .byte $f7, $50
    .byte $fa, $fb
    .byte $f8, $fb
    .byte $f6, $fb

sub_render_flagpole_graphics:
    LDY ram_enemy_spr_data_offset,x  ; get sprite data offset for flagpole flag
    LDA ram_enemy_rel_x_pos  ; get relative horizontal coordinate
    STA ram_sprite_x_position,y  ; store as X coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels and store
    STA ram_sprite_x_position+4,y  ; as X coordinate for second and third sprites
    STA ram_sprite_x_position+8,y
    CLC
    ADC #$0c  ; add twelve more pixels and
    STA $05  ; store here to be used later by floatey number
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    JSR sub_fill_two_sprite_fields  ; and do sub to dump into first and second sprites
    ADC #$08  ; add eight pixels
    STA ram_sprite_y_position+8,y  ; and store into third sprite
    LDA ram_flagpole_f_num_y_pos  ; get vertical coordinate for floatey number
    STA $02  ; store it here
    LDA #$01
    STA $03  ; set value for flip which will not be used, and
    STA $04  ; attribute byte for floatey number
    STA ram_sprite_attributes,y  ; set attribute bytes for all three sprites
    STA ram_sprite_attributes+4,y
    STA ram_sprite_attributes+8,y
    LDA #$7e
    STA ram_sprite_tilenumber,y  ; put triangle shaped tile
    STA ram_sprite_tilenumber+8,y  ; into first and third sprites
    LDA #$7f
    STA ram_sprite_tilenumber+4,y  ; put skull tile into second sprite
    LDA ram_flagpole_collision_y_pos  ; get vertical coordinate at time of collision
    BEQ bra_clip_flagpole_sprites  ; if zero, branch ahead
    TYA
    CLC  ; add 12 bytes to sprite data offset
    ADC #$0c
    TAY  ; put back in Y
    LDA ram_flagpole_score  ; get offset used to award points for touching flagpole
    ASL  ; multiply by 2 to get proper offset here
    TAX
    LDA tbl_flagpole_score_number_tiles,x  ; get appropriate tile data
    STA $00
    LDA tbl_flagpole_score_number_tiles+1,x
    JSR sub_draw_one_sprite_row  ; use it to render floatey number

bra_clip_flagpole_sprites:
    LDX ram_object_offset  ; get object offset for flag
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    LDA ram_enemy_offscreen_bits  ; get offscreen bits
    AND #%00001110  ; mask out all but d3-d1
    BEQ bra_exit_sprite_data_fill  ; if none of these bits set, branch to leave

; -------------------------------------------------------------------------------------

sub_move_six_sprites_offscreen:
    LDA #$f8  ; set offscreen coordinate if jumping here

sub_fill_six_sprite_fields:
    STA ram_sprite_data+20,y  ; dump A contents
    STA ram_sprite_data+16,y  ; into third row sprites

sub_fill_four_sprite_fields:
    STA ram_sprite_data+12,y  ; into second row sprites

sub_fill_three_sprite_fields:
    STA ram_sprite_data+8,y

sub_fill_two_sprite_fields:
    STA ram_sprite_data+4,y  ; and into first row sprites
    STA ram_sprite_data,y

bra_exit_sprite_data_fill:
    RTS

; -------------------------------------------------------------------------------------

sub_draw_large_platform:
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    STY $02  ; store here
    INY  ; add 3 to it for offset
    INY  ; to X coordinate
    INY
    LDA ram_enemy_rel_x_pos  ; get horizontal relative coordinate
    JSR sub_six_sprite_stacker  ; store X coordinates using A as base, stack horizontally
    LDX ram_object_offset
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    JSR sub_fill_four_sprite_fields  ; dump into first four sprites as Y coordinate
    LDY ram_area_type
    CPY #$03  ; check for castle-type level
    BEQ bra_hide_large_platform_last_segments
    LDY ram_secondary_hard_mode  ; check for secondary hard mode flag set
    BEQ bra_store_large_platform_last_segments_y  ; branch if not set elsewhere

bra_hide_large_platform_last_segments:
    LDA #$f8  ; load offscreen coordinate if flag set or castle-type level

bra_store_large_platform_last_segments_y:
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    STA ram_sprite_y_position+16,y  ; store vertical coordinate or offscreen
    STA ram_sprite_y_position+20,y  ; coordinate into last two sprites as Y coordinate
    LDA #$5b  ; load default tile for platform (girder)
    LDX ram_cloud_type_override
    BEQ bra_store_large_platform_tiles  ; if cloud level override flag not set, use
    LDA #$75  ; otherwise load other tile for platform (puff)

bra_store_large_platform_tiles:
    LDX ram_object_offset  ; get enemy object buffer offset
    INY  ; increment Y for tile offset
    JSR sub_fill_six_sprite_fields  ; dump tile number into all six sprites
    LDA #$02  ; set palette controls
    INY  ; increment Y for sprite attributes
    JSR sub_fill_six_sprite_fields  ; dump attributes into all six sprites
    INX  ; increment X for enemy objects
    JSR sub_get_horizontal_offscreen_bits  ; get offscreen bits again
    DEX
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    ASL  ; rotate d7 into carry, save remaining
    PHA  ; bits to the stack
    BCC bra_clip_large_platform_second_sprite
    LDA #$f8  ; if d7 was set, move first sprite offscreen
    STA ram_sprite_y_position,y
bra_clip_large_platform_second_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d6 into carry
    PHA  ; save to stack
    BCC bra_clip_large_platform_third_sprite
    LDA #$f8  ; if d6 was set, move second sprite offscreen
    STA ram_sprite_y_position+4,y
bra_clip_large_platform_third_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d5 into carry
    PHA  ; save to stack
    BCC bra_clip_large_platform_fourth_sprite
    LDA #$f8  ; if d5 was set, move third sprite offscreen
    STA ram_sprite_y_position+8,y
bra_clip_large_platform_fourth_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d4 into carry
    PHA  ; save to stack
    BCC bra_clip_large_platform_fifth_sprite
    LDA #$f8  ; if d4 was set, move fourth sprite offscreen
    STA ram_sprite_y_position+12,y
bra_clip_large_platform_fifth_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d3 into carry
    PHA  ; save to stack
    BCC bra_clip_large_platform_sixth_sprite
    LDA #$f8  ; if d3 was set, move fifth sprite offscreen
    STA ram_sprite_y_position+16,y
bra_clip_large_platform_sixth_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d2 into carry
    BCC bra_check_large_platform_left_edge  ; save to stack
    LDA #$f8
    STA ram_sprite_y_position+20,y  ; if d2 was set, move sixth sprite offscreen
bra_check_large_platform_left_edge:
    LDA ram_enemy_offscreen_bits  ; check d7 of offscreen bits
    ASL  ; and if d7 is not set, skip sub
    BCC bra_exit_large_platform_draw
    JSR sub_move_six_sprites_offscreen  ; otherwise branch to move all sprites offscreen
bra_exit_large_platform_draw:
    RTS

; -------------------------------------------------------------------------------------

bra_draw_floating_coin_score:
    LDA ram_frame_counter  ; get frame counter
    LSR  ; divide by 2
    BCS bra_draw_floating_score_sprites  ; branch if d0 not set to raise number every other frame
    DEC ram_misc_y_position,x  ; otherwise, decrement vertical coordinate
bra_draw_floating_score_sprites:
    LDA ram_misc_y_position,x  ; get vertical coordinate
    JSR sub_fill_two_sprite_fields  ; dump into both sprites
    LDA ram_misc_rel_x_pos  ; get relative horizontal coordinate
    STA ram_sprite_x_position,y  ; store as X coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels
    STA ram_sprite_x_position+4,y  ; store as X coordinate for second sprite
    LDA #$02
    STA ram_sprite_attributes,y  ; store attribute byte in both sprites
    STA ram_sprite_attributes+4,y
    LDA #$f7
    STA ram_sprite_tilenumber,y  ; put tile numbers into both sprites
    LDA #$fb  ; that resemble "200"
    STA ram_sprite_tilenumber+4,y
    JMP loc_exit_jumping_coin_graphics  ; then jump to leave (why not an rts here instead?)

tbl_jumping_coin_sprite_tiles:
    .byte $60, $61, $62, $63

sub_render_jumping_coin_graphics:
    LDY ram_misc_spr_data_offset,x  ; get coin/floatey number's OAM data offset
    LDA ram_misc_state,x  ; get state of misc object
    CMP #$02  ; if 2 or greater,
    BCS bra_draw_floating_coin_score  ; branch to draw floatey number
    LDA ram_misc_y_position,x  ; store vertical coordinate as
    STA ram_sprite_y_position,y  ; Y coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels
    STA ram_sprite_y_position+4,y  ; store as Y coordinate for second sprite
    LDA ram_misc_rel_x_pos  ; get relative horizontal coordinate
    STA ram_sprite_x_position,y
    STA ram_sprite_x_position+4,y  ; store as X coordinate for first and second sprites
    LDA ram_frame_counter  ; get frame counter
    LSR  ; divide by 2 to alter every other frame
    AND #%00000011  ; mask out d2-d1
    TAX  ; use as graphical offset
    LDA tbl_jumping_coin_sprite_tiles,x  ; load tile number
    INY  ; increment OAM data offset to write tile numbers
    JSR sub_fill_two_sprite_fields  ; do sub to dump tile number into both sprites
    DEY  ; decrement to get old offset
    LDA #$02
    STA ram_sprite_attributes,y  ; set attribute byte in first sprite
    LDA #$82
    STA ram_sprite_attributes+4,y  ; set attribute byte with vertical flip in second sprite
    LDX ram_object_offset  ; get misc object offset
loc_exit_jumping_coin_graphics:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold tiles for drawing the power-up, $00 also used to hold power-up type
; $02 - used to hold bottom row Y position
; $03 - used to hold flip control (not used here)
; $04 - used to hold sprite attributes
; $05 - used to hold X position
; $07 - counter

; tiles arranged in top left, right, bottom left, right order
tbl_power_up_graphics_tiles:
    .byte $76, $77, $78, $79  ; regular mushroom
    .byte $d6, $d6, $d9, $d9  ; fire flower
    .byte $8d, $8d, $e4, $e4  ; star
    .byte $76, $77, $78, $79  ; 1-up mushroom

tbl_power_up_sprite_attributes:
    .byte $02, $01, $02, $01

sub_draw_power_up:
    LDY ram_enemy_spr_data_offset+5  ; get power-up's sprite data offset
    LDA ram_enemy_rel_y_pos  ; get relative vertical coordinate
    CLC
    ADC #$08  ; add eight pixels
    STA $02  ; store result here
    LDA ram_enemy_rel_x_pos  ; get relative horizontal coordinate
    STA $05  ; store here
    LDX ram_power_up_type  ; get power-up type
    LDA tbl_power_up_sprite_attributes,x  ; get attribute data for power-up type
    ORA ram_enemy_spr_attrib+5  ; add background priority bit if set
    STA $04  ; store attributes here
    TXA
    PHA  ; save power-up type to the stack
    ASL
    ASL  ; multiply by four to get proper offset
    TAX  ; use as X
    LDA #$01
    STA $07  ; set counter here to draw two rows of sprite object
    STA $03  ; init d1 of flip control

bra_draw_power_up_sprite_rows:
    LDA tbl_power_up_graphics_tiles,x  ; load left tile of power-up object
    STA $00
    LDA tbl_power_up_graphics_tiles+1,x  ; load right tile
    JSR sub_draw_one_sprite_row  ; branch to draw one row of our power-up object
    DEC $07  ; decrement counter
    BPL bra_draw_power_up_sprite_rows  ; branch until two rows are drawn
    LDY ram_enemy_spr_data_offset+5  ; get sprite data offset again
    PLA  ; pull saved power-up type from the stack
    BEQ bra_clip_power_up_sprites  ; if regular mushroom, branch, do not change colors or flip
    CMP #$03
    BEQ bra_clip_power_up_sprites  ; if 1-up mushroom, branch, do not change colors or flip
    STA $00  ; store power-up type here now
    LDA ram_frame_counter  ; get frame counter
    LSR  ; divide by 2 to change colors every two frames
    AND #%00000011  ; mask out all but d1 and d0 (previously d2 and d1)
    ORA ram_enemy_spr_attrib+5  ; add background priority bit if any set
    STA ram_sprite_attributes,y  ; set as new palette bits for top left and
    STA ram_sprite_attributes+4,y  ; top right sprites for fire flower and star
    LDX $00
    DEX  ; check power-up type for fire flower
    BEQ bra_flip_power_up_right_sprites  ; if found, skip this part
    STA ram_sprite_attributes+8,y  ; otherwise set new palette bits  for bottom left
    STA ram_sprite_attributes+12,y  ; and bottom right sprites as well for star only

bra_flip_power_up_right_sprites:
    LDA ram_sprite_attributes+4,y
    ORA #%01000000  ; set horizontal flip bit for top right sprite
    STA ram_sprite_attributes+4,y
    LDA ram_sprite_attributes+12,y
    ORA #%01000000  ; set horizontal flip bit for bottom right sprite
    STA ram_sprite_attributes+12,y  ; note these are only done for fire flower and star power-ups
bra_clip_power_up_sprites:
    JMP loc_clip_enemy_sprites  ; jump to check to see if power-up is offscreen at all, then leave
