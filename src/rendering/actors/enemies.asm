; -------------------------------------------------------------------------------------
; $00-$01 - used in sub_draw_enemy_sprite_row to hold sprite tile numbers
; $02 - used to store Y position
; $03 - used to store moving direction, used to flip enemies horizontally
; $04 - used to store enemy's sprite attributes
; $05 - used to store X position
; $eb - used to hold sprite data offset
; $ec - used to hold either altered enemy state or special value used in gfx handler as condition
; $ed - used to hold enemy state from buffer
; $ef - used to hold enemy code used in gfx handler (may or may not resemble ram_enemy_id values)

; tiles arranged in top left, right, middle left, right, bottom left, right order
tbl_enemy_graphics_tiles:
    .byte $fc, $fc, $aa, $ab, $ac, $ad  ; buzzy beetle frame 1
    .byte $fc, $fc, $ae, $af, $b0, $b1  ; frame 2
    .byte $fc, $a5, $a6, $a7, $a8, $a9  ; koopa troopa frame 1
    .byte $fc, $a0, $a1, $a2, $a3, $a4  ; frame 2
    .byte $69, $a5, $6a, $a7, $a8, $a9  ; koopa paratroopa frame 1
    .byte $6b, $a0, $6c, $a2, $a3, $a4  ; frame 2
    .byte $fc, $fc, $96, $97, $98, $99  ; spiny frame 1
    .byte $fc, $fc, $9a, $9b, $9c, $9d  ; frame 2
    .byte $fc, $fc, $8f, $8e, $8e, $8f  ; spiny's egg frame 1
    .byte $fc, $fc, $95, $94, $94, $95  ; frame 2
    .byte $fc, $fc, $dc, $dc, $df, $df  ; bloober frame 1
    .byte $dc, $dc, $dd, $dd, $de, $de  ; frame 2
    .byte $fc, $fc, $b2, $b3, $b4, $b5  ; cheep-cheep frame 1
    .byte $fc, $fc, $b6, $b3, $b7, $b5  ; frame 2
    .byte $fc, $fc, $70, $71, $72, $73  ; goomba
    .byte $fc, $fc, $6e, $6e, $6f, $6f  ; koopa shell frame 1 (upside-down)
    .byte $fc, $fc, $6d, $6d, $6f, $6f  ; frame 2
    .byte $fc, $fc, $6f, $6f, $6e, $6e  ; koopa shell frame 1 (rightsideup)
    .byte $fc, $fc, $6f, $6f, $6d, $6d  ; frame 2
    .byte $fc, $fc, $f4, $f4, $f5, $f5  ; buzzy beetle shell frame 1 (rightsideup)
    .byte $fc, $fc, $f4, $f4, $f5, $f5  ; frame 2
    .byte $fc, $fc, $f5, $f5, $f4, $f4  ; buzzy beetle shell frame 1 (upside-down)
    .byte $fc, $fc, $f5, $f5, $f4, $f4  ; frame 2
    .byte $fc, $fc, $fc, $fc, $ef, $ef  ; defeated goomba
    .byte $b9, $b8, $bb, $ba, $bc, $bc  ; lakitu frame 1
    .byte $fc, $fc, $bd, $bd, $bc, $bc  ; frame 2
    .byte $7a, $7b, $da, $db, $d8, $d8  ; princess
    .byte $cd, $cd, $ce, $ce, $cf, $cf  ; mushroom retainer
    .byte $7d, $7c, $d1, $8c, $d3, $d2  ; hammer bro frame 1
    .byte $7d, $7c, $89, $88, $8b, $8a  ; frame 2
    .byte $d5, $d4, $e3, $e2, $d3, $d2  ; frame 3
    .byte $d5, $d4, $e3, $e2, $8b, $8a  ; frame 4
    .byte $e5, $e5, $e6, $e6, $eb, $eb  ; piranha plant frame 1
    .byte $ec, $ec, $ed, $ed, $ee, $ee  ; frame 2
    .byte $fc, $fc, $d0, $d0, $d7, $d7  ; podoboo
    .byte $bf, $be, $c1, $c0, $c2, $fc  ; bowser front frame 1
    .byte $c4, $c3, $c6, $c5, $c8, $c7  ; bowser rear frame 1
    .byte $bf, $be, $ca, $c9, $c2, $fc  ; front frame 2
    .byte $c4, $c3, $c6, $c5, $cc, $cb  ; rear frame 2
    .byte $fc, $fc, $e8, $e7, $ea, $e9  ; bullet bill
    .byte $f2, $f2, $f3, $f3, $f2, $f2  ; jumpspring frame 1
    .byte $f1, $f1, $f1, $f1, $fc, $fc  ; frame 2
    .byte $f0, $f0, $fc, $fc, $fc, $fc  ; frame 3

tbl_enemy_graphics_offsets:
    .byte $0c, $0c, $00, $0c, $0c, $a8, $54, $3c
    .byte $ea, $18, $48, $48, $cc, $c0, $18, $18
    .byte $18, $90, $24, $ff, $48, $9c, $d2, $d8
    .byte $f0, $f6, $fc

tbl_enemy_sprite_attributes:
    .byte $01, $02, $03, $02, $01, $01, $03, $03
    .byte $03, $01, $01, $02, $02, $21, $01, $02
    .byte $01, $01, $02, $ff, $02, $02, $01, $01
    .byte $02, $02, $02

tbl_enemy_animation_timing_masks:
    .byte $08, $18

tbl_jumpspring_graphics_offsets:
    .byte $18, $19, $1a, $19, $18

sub_render_enemy_graphics:
    LDA ram_enemy_y_position,x  ; get enemy object vertical position
    STA $02
    LDA ram_enemy_rel_x_pos  ; get enemy object horizontal position
    STA $05  ; relative to screen
    LDY ram_enemy_spr_data_offset,x
    STY $eb  ; get sprite data offset
    LDA #$00
    STA ram_vertical_flip_flag  ; initialize vertical flip flag by default
    LDA ram_enemy_moving_dir,x
    STA $03  ; get enemy object moving direction
    LDA ram_enemy_spr_attrib,x
    STA $04  ; get enemy object sprite attributes
    LDA ram_enemy_id,x
    CMP #con_piranha_plant  ; is enemy object piranha plant?
    BNE bra_check_retainer_graphics  ; if not, branch
    LDY ram_piranha_plant_y_speed,x
    BMI bra_check_retainer_graphics  ; if piranha plant moving upwards, branch
    LDY ram_enemy_frame_timer,x
    BEQ bra_check_retainer_graphics  ; if timer for movement expired, branch
    RTS  ; if all conditions fail, leave

bra_check_retainer_graphics:
    LDA ram_enemy_state,x  ; store enemy state
    STA $ed
    AND #%00011111  ; nullify all but 5 LSB and use as Y
    TAY
    LDA ram_enemy_id,x  ; check for mushroom retainer/princess object
    CMP #con_retainer_object
    BNE bra_check_cannon_bullet_bill_graphics  ; if not found, branch
    LDY #$00  ; if found, nullify saved state in Y
    LDA #$01  ; set value that will not be used
    STA $03
    LDA #$15  ; set value $15 as code for mushroom retainer/princess object

bra_check_cannon_bullet_bill_graphics:
    CMP #con_bullet_bill_cannon_var  ; otherwise check for bullet bill object
    BNE bra_check_jumpspring_graphics  ; if not found, branch again
    DEC $02  ; decrement saved vertical position
    LDA #$03
    LDY ram_enemy_frame_timer,x  ; get timer for enemy object
    BEQ bra_store_cannon_bullet_bill_attributes  ; if expired, do not set priority bit
    ORA #%00100000  ; otherwise do so
bra_store_cannon_bullet_bill_attributes:
    STA $04  ; set new sprite attributes
    LDY #$00  ; nullify saved enemy state both in Y and in
    STY $ed  ; memory location here
    LDA #$08  ; set specific value to unconditionally branch once

bra_check_jumpspring_graphics:
    CMP #con_jumpspring_object  ; check for jumpspring object
    BNE bra_check_podoboo_graphics
    LDY #$03  ; set enemy state -2 MSB here for jumpspring object
    LDX ram_jumpspring_anim_ctrl  ; get current frame number for jumpspring object
    LDA tbl_jumpspring_graphics_offsets,x  ; load data using frame number as offset

bra_check_podoboo_graphics:
    STA $ef  ; store saved enemy object value here
    STY $ec  ; and Y here (enemy state -2 MSB if not changed)
    LDX ram_object_offset  ; get enemy object offset
    CMP #$0c  ; check for podoboo object
    BNE bra_check_bowser_graphics_half  ; branch if not found
    LDA ram_enemy_y_speed,x  ; if moving upwards, branch
    BMI bra_check_bowser_graphics_half
    INC ram_vertical_flip_flag  ; otherwise, set flag for vertical flip

bra_check_bowser_graphics_half:
    LDA ram_bowser_gfx_flag  ; if not drawing bowser at all, skip to something else
    BEQ bra_check_goomba_graphics
    LDY #$16  ; if set to 1, draw bowser's front
    CMP #$01
    BEQ bra_store_bowser_graphics_offset
    INY  ; otherwise draw bowser's rear
bra_store_bowser_graphics_offset:
    STY $ef

bra_check_goomba_graphics:
    LDY $ef  ; check value for goomba object
    CPY #con_goomba
    BNE bra_select_enemy_graphics  ; branch if not found
    LDA ram_enemy_state,x
    CMP #$02  ; check for defeated state
    BCC bra_animate_goomba_graphics  ; if not defeated, go ahead and animate
    LDX #$04  ; if defeated, write new value here
    STX $ec
bra_animate_goomba_graphics:
    AND #%00100000  ; check for d5 set in enemy object state
    ORA ram_timer_control  ; or timer disable flag set
    BNE bra_select_enemy_graphics  ; if either condition true, do not animate goomba
    LDA ram_frame_counter
    AND #%00001000  ; check for every eighth frame
    BNE bra_select_enemy_graphics
    LDA $03
    EOR #%00000011  ; invert bits to flip horizontally every eight frames
    STA $03  ; leave alone otherwise

bra_select_enemy_graphics:
    LDA tbl_enemy_sprite_attributes,y  ; load sprite attribute using enemy object
    ORA $04  ; as offset, and add to bits already loaded
    STA $04
    LDA tbl_enemy_graphics_offsets,y  ; load value based on enemy object as offset
    TAX  ; save as X
    LDY $ec  ; get previously saved value
    LDA ram_bowser_gfx_flag
    BEQ bra_check_spiny_graphics  ; if not drawing bowser object at all, skip all of this
    CMP #$01
    BNE bra_select_bowser_rear_graphics  ; if not drawing front part, branch to draw the rear part
    LDA ram_bowser_body_controls  ; check bowser's body control bits
    BPL bra_check_bowser_front_state  ; branch if d7 not set (control's bowser's mouth)
    LDX #$de  ; otherwise load offset for second frame
bra_check_bowser_front_state:
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; if bowser not defeated, do not set flag
    BEQ bra_draw_bowser_graphics

loc_flip_bowser_vertically:
    STX ram_vertical_flip_flag  ; set vertical flip flag to nonzero

bra_draw_bowser_graphics:
    JMP loc_draw_enemy_object  ; draw bowser's graphics now

bra_select_bowser_rear_graphics:
    LDA ram_bowser_body_controls  ; check bowser's body control bits
    AND #$01
    BEQ bra_check_bowser_rear_state  ; branch if d0 not set (control's bowser's feet)
    LDX #$e4  ; otherwise load offset for second frame
bra_check_bowser_rear_state:
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; if bowser not defeated, do not set flag
    BEQ bra_draw_bowser_graphics
    LDA $02  ; subtract 16 pixels from
    SEC  ; saved vertical coordinate
    SBC #$10
    STA $02
    JMP loc_flip_bowser_vertically  ; jump to set vertical flip flag

bra_check_spiny_graphics:
    CPX #$24  ; check if value loaded is for spiny
    BNE bra_check_lakitu_graphics  ; if not found, branch
    CPY #$05  ; if enemy state set to $05, do this,
    BNE bra_finish_spiny_graphics_selection  ; otherwise branch
    LDX #$30  ; set to spiny egg offset
    LDA #$02
    STA $03  ; set enemy direction to reverse sprites horizontally
    LDA #$05
    STA $ec  ; set enemy state
bra_finish_spiny_graphics_selection:
    JMP loc_check_hammer_bro_graphics  ; skip a big chunk of this if we found spiny but not in egg

bra_check_lakitu_graphics:
    CPX #$90  ; check value for lakitu's offset loaded
    BNE bra_check_upside_down_shell_graphics  ; branch if not loaded
    LDA $ed
    AND #%00100000  ; check for d5 set in enemy state
    BNE bra_finish_lakitu_graphics_selection  ; branch if set
    LDA ram_frenzy_enemy_timer
    CMP #$10  ; check timer to see if we've reached a certain range
    BCS bra_finish_lakitu_graphics_selection  ; branch if not
    LDX #$96  ; if d6 not set and timer in range, load alt frame for lakitu
bra_finish_lakitu_graphics_selection:
    JMP loc_apply_defeated_enemy_graphics  ; skip this next part if we found lakitu but alt frame not needed

bra_check_upside_down_shell_graphics:
    LDA $ef  ; check for enemy object => $04
    CMP #$04
    BCS bra_check_right_side_up_shell_graphics  ; branch if true
    CPY #$02
    BCC bra_check_right_side_up_shell_graphics  ; branch if enemy state < $02
    LDX #$5a  ; set for upside-down koopa shell by default
    LDY $ef
    CPY #con_buzzy_beetle  ; check for buzzy beetle object
    BNE bra_check_right_side_up_shell_graphics
    LDX #$7e  ; set for upside-down buzzy beetle shell if found
    INC $02  ; increment vertical position by one pixel

bra_check_right_side_up_shell_graphics:
    LDA $ec  ; check for value set here
    CMP #$04  ; if enemy state < $02, do not change to shell, if
    BNE loc_check_hammer_bro_graphics  ; enemy state => $02 but not = $04, leave shell upside-down
    LDX #$72  ; set right-side up buzzy beetle shell by default
    INC $02  ; increment saved vertical position by one pixel
    LDY $ef
    CPY #con_buzzy_beetle  ; check for buzzy beetle object
    BEQ bra_check_defeated_goomba_graphics  ; branch if found
    LDX #$66  ; change to right-side up koopa shell if not found
    INC $02  ; and increment saved vertical position again

bra_check_defeated_goomba_graphics:
    CPY #con_goomba  ; check for goomba object (necessary if previously
    BNE loc_check_hammer_bro_graphics  ; failed buzzy beetle object test)
    LDX #$54  ; load for regular goomba
    LDA $ed  ; note that this only gets performed if enemy state => $02
    AND #%00100000  ; check saved enemy state for d5 set
    BNE loc_check_hammer_bro_graphics  ; branch if set
    LDX #$8a  ; load offset for defeated goomba
    DEC $02  ; set different value and decrement saved vertical position

loc_check_hammer_bro_graphics:
    LDY ram_object_offset
    LDA $ef  ; check for hammer bro object
    CMP #con_hammer_bro
    BNE bra_check_blooper_graphics  ; branch if not found
    LDA $ed
    BEQ bra_check_enemy_animation_eligibility  ; branch if not in normal enemy state
    AND #%00001000
    BEQ loc_apply_defeated_enemy_graphics  ; if d3 not set, branch further away
    LDX #$b4  ; otherwise load offset for different frame
    BNE bra_check_enemy_animation_eligibility  ; unconditional branch

bra_check_blooper_graphics:
    CPX #$48  ; check for cheep-cheep offset loaded
    BEQ bra_check_enemy_animation_eligibility  ; branch if found
    LDA ram_enemy_interval_timer,y
    CMP #$05
    BCS loc_apply_defeated_enemy_graphics  ; branch if some timer is above a certain point
    CPX #$3c  ; check for bloober offset loaded
    BNE bra_check_enemy_animation_eligibility  ; branch if not found this time
    CMP #$01
    BEQ loc_apply_defeated_enemy_graphics  ; branch if timer is set to certain point
    INC $02  ; increment saved vertical coordinate three pixels
    INC $02
    INC $02
    JMP loc_check_enemy_animation_pause  ; and do something else

bra_check_enemy_animation_eligibility:
    LDA $ef  ; check for specific enemy objects
    CMP #con_goomba
    BEQ loc_apply_defeated_enemy_graphics  ; branch if goomba
    CMP #$08
    BEQ loc_apply_defeated_enemy_graphics  ; branch if bullet bill (note both variants use $08 here)
    CMP #con_podoboo
    BEQ loc_apply_defeated_enemy_graphics  ; branch if podoboo
    CMP #$18  ; branch if => $18
    BCS loc_apply_defeated_enemy_graphics
    LDY #$00
    CMP #$15  ; check for mushroom retainer/princess object
    BNE bra_check_enemy_animation_frame  ; which uses different code here, branch if not found
    INY  ; residual instruction
    LDA ram_world_number  ; are we on world 8?
    CMP #con_world8
    BCS loc_apply_defeated_enemy_graphics  ; if so, leave the offset alone (use princess)
    LDX #$a2  ; otherwise, set for mushroom retainer object instead
    LDA #$03  ; set alternate state here
    STA $ec
    BNE loc_apply_defeated_enemy_graphics  ; unconditional branch

bra_check_enemy_animation_frame:
    LDA ram_frame_counter  ; load frame counter
    AND tbl_enemy_animation_timing_masks,y  ; mask it (partly residual, one byte not ever used)
    BNE loc_apply_defeated_enemy_graphics  ; branch if timing is off

loc_check_enemy_animation_pause:
    LDA $ed  ; check saved enemy state
    AND #%10100000  ; for d7 or d5, or check for timers stopped
    ORA ram_timer_control
    BNE loc_apply_defeated_enemy_graphics  ; if either condition true, branch
    TXA
    CLC
    ADC #$06  ; add $06 to current enemy offset
    TAX  ; to animate various enemy objects

loc_apply_defeated_enemy_graphics:
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; for d5 set
    BEQ loc_draw_enemy_object  ; branch if not set
    LDA $ef
    CMP #$04  ; check for saved enemy object => $04
    BCC loc_draw_enemy_object  ; branch if less
    LDY #$01
    STY ram_vertical_flip_flag  ; set vertical flip flag
    DEY
    STY $ec  ; init saved value here

loc_draw_enemy_object:
    LDY $eb  ; load sprite data offset
    JSR sub_draw_enemy_sprite_row  ; draw six tiles of data
    JSR sub_draw_enemy_sprite_row  ; into sprite data
    JSR sub_draw_enemy_sprite_row
    LDX ram_object_offset  ; get enemy object offset
    LDY ram_enemy_spr_data_offset,x  ; get sprite data offset
    LDA $ef
    CMP #$08  ; get saved enemy object and check
    BNE bra_check_enemy_vertical_flip  ; for bullet bill, branch if not found

bra_clip_enemy_sprites:
    JMP loc_clip_enemy_sprites  ; jump if found

bra_check_enemy_vertical_flip:
    LDA ram_vertical_flip_flag  ; check if vertical flip flag is set here
    BEQ bra_check_enemy_sprite_symmetry  ; branch if not
    LDA ram_sprite_attributes,y  ; get attributes of first sprite we dealt with
    ORA #%10000000  ; set bit for vertical flip
    INY
    INY  ; increment two bytes so that we store the vertical flip
    JSR sub_fill_six_sprite_fields  ; in attribute bytes of enemy obj sprite data
    DEY
    DEY  ; now go back to the Y coordinate offset
    TYA
    TAX  ; give offset to X
    LDA $ef
    CMP #con_hammer_bro  ; check saved enemy object for hammer bro
    BEQ bra_flip_enemy_tiles_vertically
    CMP #con_lakitu  ; check saved enemy object for lakitu
    BEQ bra_flip_enemy_tiles_vertically  ; branch for hammer bro or lakitu
    CMP #$15
    BCS bra_flip_enemy_tiles_vertically  ; also branch if enemy object => $15
    TXA
    CLC
    ADC #$08  ; if not selected objects or => $15, set
    TAX  ; offset in X for next row

bra_flip_enemy_tiles_vertically:
    LDA ram_sprite_tilenumber,x  ; load first or second row tiles
    PHA  ; and save tiles to the stack
    LDA ram_sprite_tilenumber+4,x
    PHA
    LDA ram_sprite_tilenumber+16,y  ; exchange third row tiles
    STA ram_sprite_tilenumber,x  ; with first or second row tiles
    LDA ram_sprite_tilenumber+20,y
    STA ram_sprite_tilenumber+4,x
    PLA  ; pull first or second row tiles from stack
    STA ram_sprite_tilenumber+20,y  ; and save in third row
    PLA
    STA ram_sprite_tilenumber+16,y

bra_check_enemy_sprite_symmetry:
    LDA ram_bowser_gfx_flag  ; are we drawing bowser at all?
    BNE bra_clip_enemy_sprites  ; branch if so
    LDA $ef
    LDX $ec  ; get alternate enemy state
    CMP #$05  ; check for hammer bro object
    BNE bra_select_symmetric_enemy_graphics
    JMP loc_clip_enemy_sprites  ; jump if found
bra_select_symmetric_enemy_graphics:
    CMP #con_bloober  ; check for bloober object
    BEQ bra_mirror_enemy_graphics
    CMP #con_piranha_plant  ; check for piranha plant object
    BEQ bra_mirror_enemy_graphics
    CMP #con_podoboo  ; check for podoboo object
    BEQ bra_mirror_enemy_graphics  ; branch if either of three are found
    CMP #con_spiny  ; check for spiny object
    BNE bra_apply_retainer_sprite_symmetry  ; branch closer if not found
    CPX #$05  ; check spiny's state
    BNE bra_check_lakitu_sprite_symmetry  ; branch if not an egg, otherwise
bra_apply_retainer_sprite_symmetry:
    CMP #$15  ; check for princess/mushroom retainer object
    BNE bra_check_spiny_shell_symmetry
    LDA #$42  ; set horizontal flip on bottom right sprite
    STA ram_sprite_attributes+20,y  ; note that palette bits were already set earlier
bra_check_spiny_shell_symmetry:
    CPX #$02  ; if alternate enemy state set to 1 or 0, branch
    BCC bra_check_lakitu_sprite_symmetry

bra_mirror_enemy_graphics:
    LDA ram_bowser_gfx_flag  ; if enemy object is bowser, skip all of this
    BNE bra_check_lakitu_sprite_symmetry
    LDA ram_sprite_attributes,y  ; load attribute bits of first sprite
    AND #%10100011
    STA ram_sprite_attributes,y  ; save vertical flip, priority, and palette bits
    STA ram_sprite_attributes+8,y  ; in left sprite column of enemy object OAM data
    STA ram_sprite_attributes+16,y
    ORA #%01000000  ; set horizontal flip
    CPX #$05  ; check for state used by spiny's egg
    BNE bra_store_mirrored_enemy_attributes  ; if alternate state not set to $05, branch
    ORA #%10000000  ; otherwise set vertical flip
bra_store_mirrored_enemy_attributes:
    STA ram_sprite_attributes+4,y  ; set bits of right sprite column
    STA ram_sprite_attributes+12,y  ; of enemy object sprite data
    STA ram_sprite_attributes+20,y
    CPX #$04  ; check alternate enemy state
    BNE bra_check_lakitu_sprite_symmetry  ; branch if not $04
    LDA ram_sprite_attributes+8,y  ; get second row left sprite attributes
    ORA #%10000000
    STA ram_sprite_attributes+8,y  ; store bits with vertical flip in
    STA ram_sprite_attributes+16,y  ; second and third row left sprites
    ORA #%01000000
    STA ram_sprite_attributes+12,y  ; store with horizontal and vertical flip in
    STA ram_sprite_attributes+20,y  ; second and third row right sprites

bra_check_lakitu_sprite_symmetry:
    LDA $ef  ; check for lakitu enemy object
    CMP #con_lakitu
    BNE bra_check_jumpspring_sprite_symmetry  ; branch if not found
    LDA ram_vertical_flip_flag
    BNE bra_mirror_vertically_flipped_lakitu  ; branch if vertical flip flag not set
    LDA ram_sprite_attributes+16,y  ; save vertical flip and palette bits
    AND #%10000001  ; in third row left sprite
    STA ram_sprite_attributes+16,y
    LDA ram_sprite_attributes+20,y  ; set horizontal flip and palette bits
    ORA #%01000001  ; in third row right sprite
    STA ram_sprite_attributes+20,y
    LDX ram_frenzy_enemy_timer  ; check timer
    CPX #$10
    BCS loc_clip_enemy_sprites  ; branch if timer has not reached a certain range
    STA ram_sprite_attributes+12,y  ; otherwise set same for second row right sprite
    AND #%10000001
    STA ram_sprite_attributes+8,y  ; preserve vertical flip and palette bits for left sprite
    BCC loc_clip_enemy_sprites  ; unconditional branch
bra_mirror_vertically_flipped_lakitu:
    LDA ram_sprite_attributes,y  ; get first row left sprite attributes
    AND #%10000001
    STA ram_sprite_attributes,y  ; save vertical flip and palette bits
    LDA ram_sprite_attributes+4,y  ; get first row right sprite attributes
    ORA #%01000001  ; set horizontal flip and palette bits
    STA ram_sprite_attributes+4,y  ; note that vertical flip is left as-is

bra_check_jumpspring_sprite_symmetry:
    LDA $ef  ; check for jumpspring object (any frame)
    CMP #$18
    BCC loc_clip_enemy_sprites  ; branch if not jumpspring object at all
    LDA #$82
    STA ram_sprite_attributes+8,y  ; set vertical flip and palette bits of
    STA ram_sprite_attributes+16,y  ; second and third row left sprites
    ORA #%01000000
    STA ram_sprite_attributes+12,y  ; set, in addition to those, horizontal flip
    STA ram_sprite_attributes+20,y  ; for second and third row right sprites

loc_clip_enemy_sprites:
    LDX ram_object_offset  ; get enemy buffer offset
    LDA ram_enemy_offscreen_bits  ; check offscreen information
    LSR
    LSR  ; shift three times to the right
    LSR  ; which puts d2 into carry
    PHA  ; save to stack
    BCC bra_check_enemy_left_column_clip  ; branch if not set
    LDA #$04  ; set for right column sprites
    JSR sub_move_enemy_sprite_column_offscreen  ; and move them offscreen
bra_check_enemy_left_column_clip:
    PLA  ; get from stack
    LSR  ; move d3 to carry
    PHA  ; save to stack
    BCC bra_check_enemy_third_row_clip  ; branch if not set
    LDA #$00  ; set for left column sprites,
    JSR sub_move_enemy_sprite_column_offscreen  ; move them offscreen
bra_check_enemy_third_row_clip:
    PLA  ; get from stack again
    LSR  ; move d5 to carry this time
    LSR
    PHA  ; save to stack again
    BCC bra_check_enemy_lower_rows_clip  ; branch if carry not set
    LDA #$10  ; set for third row of sprites
    JSR sub_move_enemy_sprite_row_offscreen  ; and move them offscreen
bra_check_enemy_lower_rows_clip:
    PLA  ; get from stack
    LSR  ; move d6 into carry
    PHA  ; save to stack
    BCC bra_check_enemy_all_rows_clip
    LDA #$08  ; set for second and third rows
    JSR sub_move_enemy_sprite_row_offscreen  ; move them offscreen
bra_check_enemy_all_rows_clip:
    PLA  ; get from stack once more
    LSR  ; move d7 into carry
    BCC bra_exit_enemy_graphics_handler
    JSR sub_move_enemy_sprite_row_offscreen  ; move all sprites offscreen (A should be 0 by now)
    LDA ram_enemy_id,x
    CMP #con_podoboo  ; check enemy identifier for podoboo
    BEQ bra_exit_enemy_graphics_handler  ; skip this part if found, we do not want to erase podoboo!
    LDA ram_enemy_y_high_pos,x  ; check high byte of vertical position
    CMP #$02  ; if not yet past the bottom of the screen, branch
    BNE bra_exit_enemy_graphics_handler
    JSR sub_erase_enemy_object  ; what it says

bra_exit_enemy_graphics_handler:
    RTS

sub_draw_enemy_sprite_row:
    LDA tbl_enemy_graphics_tiles,x  ; load two tiles of enemy graphics
    STA $00
    LDA tbl_enemy_graphics_tiles+1,x

sub_draw_one_sprite_row:
    STA $01
    JMP loc_draw_two_tile_sprite_row  ; draw them

sub_move_enemy_sprite_row_offscreen:
    CLC  ; add A to enemy object OAM data offset
    ADC ram_enemy_spr_data_offset,x
    TAY  ; use as offset
    LDA #$f8
    JMP sub_fill_two_sprite_fields  ; move first row of sprites offscreen

sub_move_enemy_sprite_column_offscreen:
    CLC  ; add A to enemy object OAM data offset
    ADC ram_enemy_spr_data_offset,x
    TAY  ; use as offset
    JSR sub_move_col_offscreen  ; move first and second row sprites in column offscreen
    STA ram_sprite_data+16,y  ; move third row sprite in column offscreen
    RTS
