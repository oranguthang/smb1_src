sub_smb2_main_render_enemy_graphics:
    LDA #$02
    LDY WorldNumber  ; if the world number is not 2, 3 or 7
    CPY #$01  ; then use regular attributes for jumpsprings
    BEQ bra_smb2_main_draw_green_jumpspring  ; which will paint them red
    CPY #$02
    BEQ bra_smb2_main_draw_green_jumpspring  ; otherwise use alternate attributes
    CPY #$06  ; to get the green superhigh jumpsprings
    BNE bra_smb2_main_use_red_jumpspring
bra_smb2_main_draw_green_jumpspring:
    LSR
bra_smb2_main_use_red_jumpspring:
    STA off_smb2_main_enemy_sprite_attributes+$18  ; set jumpspring gfx attributes in the lookup table
    STA off_smb2_main_enemy_sprite_attributes+$19
    STA off_smb2_main_enemy_sprite_attributes+$1a
    LDA Enemy_Y_Position,x  ; get enemy object vertical position
    STA $02
    LDA Enemy_Rel_XPos  ; get enemy object horizontal position
    STA $05  ; relative to screen
    LDY Enemy_SprDataOffset,x
    STY $eb  ; get sprite data offset
    LDA #$00
    STA VerticalFlipFlag  ; initialize vertical flip flag by default
    LDA Enemy_MovingDir,x
    STA $03  ; get enemy object moving direction
    LDA Enemy_SprAttrib,x
    STA $04  ; get enemy object sprite attributes
    LDA Enemy_ID,x
    CMP #PiranhaPlant  ; is enemy object piranha plant?
    BNE bra_smb2_main_check_retainer_graphics  ; if not, branch
    LDY PiranhaPlant_Y_Speed,x
    BMI bra_smb2_main_check_retainer_graphics  ; if piranha plant moving upwards, branch
    LDY EnemyFrameTimer,x
    BEQ bra_smb2_main_check_retainer_graphics  ; if timer for movement expired, branch
    RTS  ; if all conditions fail, leave

bra_smb2_main_check_retainer_graphics:
    LDA Enemy_State,x  ; store enemy state
    STA $ed
    AND #%00011111  ; nullify all but 5 LSB and use as Y
    TAY
    LDA Enemy_ID,x  ; check for mushroom retainer/princess object
    CMP #RetainerObject
    BNE bra_smb2_main_check_cannon_bullet_bill_graphics  ; if not found, branch
    LDY #$00  ; if found, nullify saved state in Y
    LDA #$01  ; set value that will not be used
    STA $03
    LDA #$15  ; set value $15 as code for mushroom retainer/princess object

bra_smb2_main_check_cannon_bullet_bill_graphics:
    CMP #BulletBill_CannonVar  ; otherwise check for bullet bill object
    BNE bra_smb2_main_check_jumpspring_graphics  ; if not found, branch again
    DEC $02  ; decrement saved vertical position
    LDA #$03
    LDY EnemyFrameTimer,x  ; get timer for enemy object
    BEQ bra_smb2_main_store_cannon_bullet_bill_attributes  ; if expired, do not set priority bit
    ORA #%00100000  ; otherwise do so
bra_smb2_main_store_cannon_bullet_bill_attributes:
    STA $04  ; set new sprite attributes
    LDY #$00  ; nullify saved enemy state both in Y and in
    STY $ed  ; memory location here
    LDA #$08  ; set specific value to unconditionally branch once

bra_smb2_main_check_jumpspring_graphics:
    CMP #JumpspringObject  ; check for jumpspring object
    BNE bra_smb2_main_check_podoboo_graphics
    LDY #$03  ; set enemy state -2 MSB here for jumpspring object
    LDX JumpspringAnimCtrl  ; get current frame number for jumpspring object
    LDA tbl_smb2_main_jumpspring_graphics_offsets,x  ; load data using frame number as offset

bra_smb2_main_check_podoboo_graphics:
    STA $ef  ; store saved enemy object value here
    STY $ec  ; and Y here (enemy state -2 MSB if not changed)
    LDX ObjectOffset  ; get enemy object offset
    CMP #$0c  ; check for podoboo object
    BNE bra_smb2_main_check_bowser_graphics_half  ; branch if not found
    LDA Enemy_Y_Speed,x  ; if moving upwards, branch
    BMI bra_smb2_main_check_bowser_graphics_half
    INC VerticalFlipFlag  ; otherwise, set flag for vertical flip

bra_smb2_main_check_bowser_graphics_half:
    LDA BowserGfxFlag  ; if not drawing bowser at all, skip to something else
    BEQ bra_smb2_main_check_goomba_graphics
    LDY #$16  ; if set to 1, draw bowser's front
    CMP #$01
    BEQ bra_smb2_main_store_bowser_graphics_offset
    INY  ; otherwise draw bowser's rear
bra_smb2_main_store_bowser_graphics_offset:
    STY $ef

bra_smb2_main_check_goomba_graphics:
    LDY $ef  ; check value for goomba object
    CPY #Goomba
    BNE bra_smb2_main_select_enemy_graphics  ; branch if not found
    LDA Enemy_State,x
    CMP #$02  ; check for defeated state
    BCC bra_smb2_main_animate_goomba_graphics  ; if not defeated, go ahead and animate
    LDX #$04  ; if defeated, write new value here
    STX $ec
bra_smb2_main_animate_goomba_graphics:
    AND #%00100000  ; check for d5 set in enemy object state
    ORA TimerControl  ; or timer disable flag set
    BNE bra_smb2_main_select_enemy_graphics  ; if either condition true, do not animate goomba
    LDA FrameCounter
    AND #%00001000  ; check for every eighth frame
    BNE bra_smb2_main_select_enemy_graphics
    LDA $03
    EOR #%00000011  ; invert bits to flip horizontally every eight frames
    STA $03  ; leave alone otherwise

bra_smb2_main_select_enemy_graphics:
    LDA off_smb2_main_enemy_sprite_attributes,y  ; load sprite attribute using enemy object
    ORA $04  ; as offset, and add to bits already loaded
    STA $04
    LDA tbl_smb2_main_enemy_graphics_offsets,y  ; load value based on enemy object as offset
    TAX  ; save as X
    LDY $ec  ; get previously saved value
    LDA BowserGfxFlag
    BEQ bra_smb2_main_check_spiny_graphics  ; if not drawing bowser object at all, skip all of this
    CMP #$01
    BNE bra_smb2_main_select_bowser_rear_graphics  ; if not drawing front part, branch to draw the rear part
    LDA BowserBodyControls  ; check bowser's body control bits
    BPL bra_smb2_main_check_bowser_front_state  ; branch if d7 not set (control's bowser's mouth)
    LDX #$de  ; otherwise load offset for second frame
bra_smb2_main_check_bowser_front_state:
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; if bowser not defeated, do not set flag
    BEQ bra_smb2_main_draw_bowser_graphics

loc_smb2_main_flip_bowser_vertically:
    STX VerticalFlipFlag  ; set vertical flip flag to nonzero

bra_smb2_main_draw_bowser_graphics:
    JMP bra_smb2_main_draw_enemy_object  ; draw bowser's graphics now

bra_smb2_main_select_bowser_rear_graphics:
    LDA BowserBodyControls  ; check bowser's body control bits
    AND #$01
    BEQ bra_smb2_main_check_bowser_rear_state  ; branch if d0 not set (control's bowser's feet)
    LDX #$e4  ; otherwise load offset for second frame
bra_smb2_main_check_bowser_rear_state:
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; if bowser not defeated, do not set flag
    BEQ bra_smb2_main_draw_bowser_graphics
    LDA $02  ; subtract 16 pixels from
    SEC  ; saved vertical coordinate
    SBC #$10
    STA $02
    JMP loc_smb2_main_flip_bowser_vertically  ; jump to set vertical flip flag

bra_smb2_main_check_spiny_graphics:
    CPX #$24  ; check if value loaded is for spiny
    BNE bra_smb2_main_check_lakitu_graphics  ; if not found, branch
    CPY #$05  ; if enemy state set to $05, do this,
    BNE bra_smb2_main_finish_spiny_graphics_selection  ; otherwise branch
    LDX #$30  ; set to spiny egg offset
    LDA #$02
    STA $03  ; set enemy direction to reverse sprites horizontally
    LDA #$05
    STA $ec  ; set enemy state
bra_smb2_main_finish_spiny_graphics_selection:
    JMP bra_smb2_main_check_hammer_bro_graphics  ; skip a big chunk of this if we found spiny but not in egg

bra_smb2_main_check_lakitu_graphics:
    CPX #$90  ; check value for lakitu's offset loaded
    BNE bra_smb2_main_check_upside_down_shell_graphics  ; branch if not loaded
    LDA $ed
    AND #%00100000  ; check for d5 set in enemy state
    BNE bra_smb2_main_finish_lakitu_graphics_selection  ; branch if set
    LDA FrenzyEnemyTimer
    CMP #$10  ; check timer to see if we've reached a certain range
    BCS bra_smb2_main_finish_lakitu_graphics_selection  ; branch if not
    LDX #$96  ; if d6 not set and timer in range, load alt frame for lakitu
bra_smb2_main_finish_lakitu_graphics_selection:
    JMP bra_smb2_main_apply_defeated_enemy_graphics  ; skip this next part if we found lakitu but alt frame not needed

bra_smb2_main_check_upside_down_shell_graphics:
    LDA $ef  ; check for enemy object => $04
    CMP #$04
    BCS bra_smb2_main_check_right_side_up_shell_graphics  ; branch if true
    CPY #$02
    BCC bra_smb2_main_check_right_side_up_shell_graphics  ; branch if enemy state < $02
    LDX #$5a  ; set for upside-down koopa shell by default
    LDY $ef
    CPY #BuzzyBeetle  ; check for buzzy beetle object
    BNE bra_smb2_main_check_right_side_up_shell_graphics
    LDX #$7e  ; set for upside-down buzzy beetle shell if found
    INC $02  ; increment vertical position by one pixel

bra_smb2_main_check_right_side_up_shell_graphics:
    LDA $ec  ; check for value set here
    CMP #$04  ; if enemy state < $02, do not change to shell, if
    BNE bra_smb2_main_check_hammer_bro_graphics  ; enemy state => $02 but not = $04, leave shell upside-down
    LDX #$72  ; set right-side up buzzy beetle shell by default
    INC $02  ; increment saved vertical position by one pixel
    LDY $ef
    CPY #BuzzyBeetle  ; check for buzzy beetle object
    BEQ bra_smb2_main_check_defeated_goomba_graphics  ; branch if found
    LDX #$66  ; change to right-side up koopa shell if not found
    INC $02  ; and increment saved vertical position again

bra_smb2_main_check_defeated_goomba_graphics:
    CPY #Goomba  ; check for goomba object (necessary if previously
    BNE bra_smb2_main_check_hammer_bro_graphics  ; failed buzzy beetle object test)
    LDX #$54  ; load for regular goomba
    LDA $ed  ; note that this only gets performed if enemy state => $02
    AND #%00100000  ; check saved enemy state for d5 set
    BNE bra_smb2_main_check_hammer_bro_graphics  ; branch if set
    LDX #$8a  ; load offset for defeated goomba
    DEC $02  ; set different value and decrement saved vertical position

bra_smb2_main_check_hammer_bro_graphics:
    LDY ObjectOffset
    LDA $ef  ; check for hammer bro object
    CMP #HammerBro
    BNE bra_smb2_main_check_blooper_graphics  ; branch if not found
    LDA $ed
    BEQ bra_smb2_main_check_enemy_animation_eligibility  ; branch if not in normal enemy state
    AND #%00001000
    BEQ bra_smb2_main_apply_defeated_enemy_graphics  ; if d3 not set, branch further away
    LDX #$b4  ; otherwise load offset for different frame
    BNE bra_smb2_main_check_enemy_animation_eligibility  ; unconditional branch

bra_smb2_main_check_blooper_graphics:
    CPX #$48  ; check for cheep-cheep offset loaded
    BEQ bra_smb2_main_check_enemy_animation_eligibility  ; branch if found
    LDA EnemyIntervalTimer,y
    CMP #$05
    BCS bra_smb2_main_apply_defeated_enemy_graphics  ; branch if some timer is above a certain point
    CPX #$3c  ; check for bloober offset loaded
    BNE bra_smb2_main_check_enemy_animation_eligibility  ; branch if not found this time
    CMP #$01
    BEQ bra_smb2_main_apply_defeated_enemy_graphics  ; branch if timer is set to certain point
    INC $02  ; increment saved vertical coordinate three pixels
    INC $02
    INC $02
    JMP loc_smb2_main_check_enemy_animation_pause  ; and do something else

bra_smb2_main_check_enemy_animation_eligibility:
    LDA $ef  ; check for specific enemy objects
    CMP #Goomba
    BEQ bra_smb2_main_apply_defeated_enemy_graphics  ; branch if goomba
    CMP #$08
    BEQ bra_smb2_main_apply_defeated_enemy_graphics  ; branch if bullet bill (note both variants use $08 here)
    CMP #Podoboo
    BEQ bra_smb2_main_apply_defeated_enemy_graphics  ; branch if podoboo
    CMP #$18  ; branch if => $18
    BCS bra_smb2_main_apply_defeated_enemy_graphics
    LDY #$00
    CMP #$15  ; check for mushroom retainer/princess object
    BNE bra_smb2_main_check_enemy_animation_frame  ; which uses different code here, branch if not found
    INY  ; residual instruction
    LDA #$03  ; set state for mushroom retainer/princess object
    STA $ec
    LDA WorldNumber  ; are we on world 8?
    CMP #World8
    BCS bra_smb2_main_apply_defeated_enemy_graphics  ; if so, leave the offset alone (use princess)
    LDX #$a2  ; otherwise, set for mushroom retainer object instead
    BNE bra_smb2_main_apply_defeated_enemy_graphics  ; unconditional branch

bra_smb2_main_check_enemy_animation_frame:
    LDA FrameCounter  ; load frame counter
    AND tbl_smb2_main_enemy_animation_timing_masks,y  ; mask it (partly residual, one byte not ever used)
    BNE bra_smb2_main_apply_defeated_enemy_graphics  ; branch if timing is off

loc_smb2_main_check_enemy_animation_pause:
    LDA $ed  ; check saved enemy state
    AND #%10100000  ; for d7 or d5, or check for timers stopped
    ORA TimerControl
    BNE bra_smb2_main_apply_defeated_enemy_graphics  ; if either condition true, branch
    TXA
    CLC
    ADC #$06  ; add $06 to current enemy offset
    TAX  ; to animate various enemy objects

bra_smb2_main_apply_defeated_enemy_graphics:
    LDA $ef  ; check for upside-down piranha plant
    CMP #$04  ; if found, branch to draw it upside-down
    BEQ bra_smb2_main_flip_v
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; for d5 set
    BEQ bra_smb2_main_draw_enemy_object  ; branch if not set
    LDA $ef
    CMP #$04  ; check for saved enemy object => $04
    BCC bra_smb2_main_draw_enemy_object  ; branch if less
bra_smb2_main_flip_v:
    LDY #$01
    STY VerticalFlipFlag  ; set vertical flip flag
    DEY
    STY $ec  ; init saved value here

bra_smb2_main_draw_enemy_object:
    LDY $eb  ; load sprite data offset
    JSR sub_smb2_main_draw_enemy_sprite_row  ; draw six tiles of data
    JSR sub_smb2_main_draw_enemy_sprite_row  ; into sprite data
    JSR sub_smb2_main_draw_enemy_sprite_row
    LDX ObjectOffset  ; get enemy object offset
    LDY Enemy_SprDataOffset,x  ; get sprite data offset
    LDA $ef
    CMP #$08  ; get saved enemy object and check
    BNE bra_smb2_main_check_enemy_vertical_flip  ; for bullet bill, branch if not found

bra_smb2_main_clip_enemy_sprites:
    JMP bra_smb2_main_clip_enemy_sprites_variant_2  ; jump if found

bra_smb2_main_check_enemy_vertical_flip:
    LDA VerticalFlipFlag  ; check if vertical flip flag is set here
    BEQ bra_smb2_main_check_enemy_sprite_symmetry  ; branch if not
    LDA Sprite_Attributes,y  ; get attributes of first sprite we dealt with
    ORA #%10000000  ; set bit for vertical flip
    INY
    INY  ; increment two bytes so that we store the vertical flip
    JSR sub_smb2_main_fill_six_sprite_fields  ; in attribute bytes of enemy obj sprite data
    DEY
    DEY  ; now go back to the Y coordinate offset
    TYA
    TAX  ; give offset to X
    LDA $ef
    CMP #HammerBro  ; check saved enemy object for hammer bro
    BEQ bra_smb2_main_flip_enemy_tiles_vertically
    CMP #UpsideDownPiranhaP  ; check saved enemy object for upside-down piranha plant
    BEQ bra_smb2_main_flip_enemy_tiles_vertically
    CMP #Lakitu  ; check saved enemy object for lakitu
    BEQ bra_smb2_main_flip_enemy_tiles_vertically  ; branch for any of these objects
    CMP #$15
    BCS bra_smb2_main_flip_enemy_tiles_vertically  ; also branch if enemy object => $15
    TXA
    CLC
    ADC #$08  ; if not selected objects or => $15, set
    TAX  ; offset in X for next row

bra_smb2_main_flip_enemy_tiles_vertically:
    LDA Sprite_Tilenumber,x  ; load first or second row tiles
    PHA  ; and save tiles to the stack
    LDA Sprite_Tilenumber+4,x
    PHA
    LDA Sprite_Tilenumber+16,y  ; exchange third row tiles
    STA Sprite_Tilenumber,x  ; with first or second row tiles
    LDA Sprite_Tilenumber+20,y
    STA Sprite_Tilenumber+4,x
    PLA  ; pull first or second row tiles from stack
    STA Sprite_Tilenumber+20,y  ; and save in third row
    PLA
    STA Sprite_Tilenumber+16,y

bra_smb2_main_check_enemy_sprite_symmetry:
    LDA BowserGfxFlag  ; are we drawing bowser at all?
    BNE bra_smb2_main_clip_enemy_sprites  ; branch if so
    LDA $ef
    LDX $ec  ; get alternate enemy state
    CMP #$05  ; check for hammer bro object
    BNE bra_smb2_main_select_symmetric_enemy_graphics
    JMP bra_smb2_main_clip_enemy_sprites_variant_2  ; jump if found
bra_smb2_main_select_symmetric_enemy_graphics:
    CMP #Bloober  ; check for bloober object
    BEQ bra_smb2_main_mirror_enemy_graphics
    CMP #PiranhaPlant  ; check for piranha plant object
    BEQ bra_smb2_main_mirror_enemy_graphics
    CMP #UpsideDownPiranhaP  ; check for upside-down piranha plant object
    BEQ bra_smb2_main_mirror_enemy_graphics
    CMP #Podoboo  ; check for podoboo object
    BEQ bra_smb2_main_mirror_enemy_graphics  ; branch if either of three are found
    CMP #Spiny  ; check for spiny object
    BNE bra_smb2_main_apply_retainer_sprite_symmetry  ; branch closer if not found
    CPX #$05  ; check spiny's state
    BNE bra_smb2_main_check_lakitu_sprite_symmetry  ; branch if not an egg, otherwise
bra_smb2_main_apply_retainer_sprite_symmetry:
    CMP #$15  ; check for princess/mushroom retainer object
    BNE bra_smb2_main_check_spiny_shell_symmetry
    LDA #$42  ; set horizontal flip on bottom right sprite
    STA Sprite_Attributes+20,y  ; note that palette bits were already set earlier
bra_smb2_main_check_spiny_shell_symmetry:
    CPX #$02  ; if alternate enemy state set to 1 or 0, branch
    BCC bra_smb2_main_check_lakitu_sprite_symmetry

bra_smb2_main_mirror_enemy_graphics:
    LDA BowserGfxFlag  ; if enemy object is bowser, skip all of this
    BNE bra_smb2_main_check_lakitu_sprite_symmetry
    LDA Sprite_Attributes,y  ; load attribute bits of first sprite
    AND #%10100011
    STA Sprite_Attributes,y  ; save vertical flip, priority, and palette bits
    STA Sprite_Attributes+8,y  ; in left sprite column of enemy object OAM data
    STA Sprite_Attributes+16,y
    ORA #%01000000  ; set horizontal flip
    CPX #$05  ; check for state used by spiny's egg
    BNE bra_smb2_main_store_mirrored_enemy_attributes  ; if alternate state not set to $05, branch
    ORA #%10000000  ; otherwise set vertical flip
bra_smb2_main_store_mirrored_enemy_attributes:
    STA Sprite_Attributes+4,y  ; set bits of right sprite column
    STA Sprite_Attributes+12,y  ; of enemy object sprite data
    STA Sprite_Attributes+20,y
    CPX #$04  ; check alternate enemy state
    BNE bra_smb2_main_check_lakitu_sprite_symmetry  ; branch if not $04
    LDA Sprite_Attributes+8,y  ; get second row left sprite attributes
    ORA #%10000000
    STA Sprite_Attributes+8,y  ; store bits with vertical flip in
    STA Sprite_Attributes+16,y  ; second and third row left sprites
    ORA #%01000000
    STA Sprite_Attributes+12,y  ; store with horizontal and vertical flip in
    STA Sprite_Attributes+20,y  ; second and third row right sprites

bra_smb2_main_check_lakitu_sprite_symmetry:
    LDA $ef  ; check for lakitu enemy object
    CMP #Lakitu
    BNE bra_smb2_main_check_jumpspring_sprite_symmetry  ; branch if not found
    LDA VerticalFlipFlag
    BNE bra_smb2_main_mirror_vertically_flipped_lakitu  ; branch if vertical flip flag set
    LDA Sprite_Attributes+16,y  ; save vertical flip and palette bits
    AND #%10000001  ; in third row left sprite
    STA Sprite_Attributes+16,y
    LDA Sprite_Attributes+20,y  ; set horizontal flip and palette bits
    ORA #%01000001  ; in third row right sprite
    STA Sprite_Attributes+20,y
    LDX FrenzyEnemyTimer  ; check timer
    CPX #$10
    BCS bra_smb2_main_clip_enemy_sprites_variant_2  ; branch if timer has not reached a certain range
    STA Sprite_Attributes+12,y  ; otherwise set same for second row right sprite
    AND #%10000001
    STA Sprite_Attributes+8,y  ; preserve vertical flip and palette bits for left sprite
    BCC bra_smb2_main_clip_enemy_sprites_variant_2  ; unconditional branch
bra_smb2_main_mirror_vertically_flipped_lakitu:
    LDA Sprite_Attributes,y  ; get first row left sprite attributes
    AND #%10000001
    STA Sprite_Attributes,y  ; save vertical flip and palette bits
    LDA Sprite_Attributes+4,y  ; get first row right sprite attributes
    ORA #%01000001  ; set horizontal flip and palette bits
    STA Sprite_Attributes+4,y  ; note that vertical flip is left as-is

bra_smb2_main_check_jumpspring_sprite_symmetry:
    LDA $ef  ; check for jumpspring object (any frame)
    CMP #$18
    BCC bra_smb2_main_clip_enemy_sprites_variant_2  ; branch if not jumpspring object at all
    LDA #$80
    ORA off_smb2_main_enemy_sprite_attributes+$18
    STA Sprite_Attributes+8,y  ; set vertical flip and palette bits of
    STA Sprite_Attributes+16,y  ; second and third row left sprites
    ORA #%01000000
    STA Sprite_Attributes+12,y  ; set, in addition to those, horizontal flip
    STA Sprite_Attributes+20,y  ; for second and third row right sprites

bra_smb2_main_clip_enemy_sprites_variant_2:
    LDX ObjectOffset  ; get enemy buffer offset
    LDA Enemy_OffscreenBits  ; check offscreen information
    LSR
    LSR  ; shift three times to the right
    LSR  ; which puts d2 into carry
    PHA  ; save to stack
    BCC bra_smb2_main_check_enemy_left_column_clip  ; branch if not set
    LDA #$04  ; set for right column sprites
    JSR sub_smb2_main_move_enemy_sprite_column_offscreen  ; and move them offscreen
bra_smb2_main_check_enemy_left_column_clip:
    PLA  ; get from stack
    LSR  ; move d3 to carry
    PHA  ; save to stack
    BCC bra_smb2_main_check_enemy_third_row_clip  ; branch if not set
    LDA #$00  ; set for left column sprites,
    JSR sub_smb2_main_move_enemy_sprite_column_offscreen  ; move them offscreen
bra_smb2_main_check_enemy_third_row_clip:
    PLA  ; get from stack again
    LSR  ; move d5 to carry this time
    LSR
    PHA  ; save to stack again
    BCC bra_smb2_main_check_enemy_lower_rows_clip  ; branch if carry not set
    LDA #$10  ; set for third row of sprites
    JSR sub_smb2_main_move_enemy_sprite_row_offscreen  ; and move them offscreen
bra_smb2_main_check_enemy_lower_rows_clip:
    PLA  ; get from stack
    LSR  ; move d6 into carry
    PHA  ; save to stack
    BCC bra_smb2_main_check_enemy_all_rows_clip
    LDA #$08  ; set for second and third rows
    JSR sub_smb2_main_move_enemy_sprite_row_offscreen  ; move them offscreen
bra_smb2_main_check_enemy_all_rows_clip:
    PLA  ; get from stack once more
    LSR  ; move d7 into carry
    BCC bra_smb2_main_exit_enemy_graphics_handler
    JSR sub_smb2_main_move_enemy_sprite_row_offscreen  ; move all sprites offscreen (A should be 0 by now)
    LDA Enemy_ID,x
    CMP #Podoboo  ; check enemy identifier for podoboo
    BEQ bra_smb2_main_exit_enemy_graphics_handler  ; skip this part if found, we do not want to erase podoboo!
    LDA Enemy_Y_HighPos,x  ; check high byte of vertical position
    CMP #$02  ; if not yet past the bottom of the screen, branch
    BNE bra_smb2_main_exit_enemy_graphics_handler
    JSR sub_smb2_main_erase_enemy_object  ; what it says

bra_smb2_main_exit_enemy_graphics_handler:
    RTS

sub_smb2_main_draw_enemy_sprite_row:
    LDA tbl_smb2_main_enemy_graphics_tiles,x  ; load two tiles of enemy graphics
    STA $00
    LDA tbl_smb2_main_enemy_graphics_tiles+1,x

sub_smb2_main_draw_one_sprite_row:
    STA $01
    JMP loc_smb2_main_draw_two_tile_sprite_row  ; draw them

sub_smb2_main_move_enemy_sprite_row_offscreen:
    CLC  ; add A to enemy object OAM data offset
    ADC Enemy_SprDataOffset,x
    TAY  ; use as offset
    LDA #$f8
    JMP sub_smb2_main_fill_two_sprite_fields  ; move first row of sprites offscreen

sub_smb2_main_move_enemy_sprite_column_offscreen:
    CLC  ; add A to enemy object OAM data offset
    ADC Enemy_SprDataOffset,x
    TAY  ; use as offset
    JSR sub_smb2_main_move_col_offscreen  ; move first and second row sprites in column offscreen
    STA Sprite_Data+16,y  ; move third row sprite in column offscreen
    RTS

; -------------------------------------------------------------------------------------
; $00-$01 - tile numbers
; $02 - relative Y position
; $03 - horizontal flip flag (not used here)
; $04 - attributes
; $05 - relative X position
