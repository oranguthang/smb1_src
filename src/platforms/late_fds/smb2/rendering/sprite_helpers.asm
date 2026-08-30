sub_smb2_main_move_six_sprites_offscreen:
    LDA #$f8  ; set offscreen coordinate if jumping here

sub_smb2_main_fill_six_sprite_fields:
    STA Sprite_Data+20,y  ; dump A contents
    STA Sprite_Data+16,y  ; into third row sprites

sub_smb2_main_fill_four_sprite_fields:
    STA Sprite_Data+12,y  ; into second row sprites

sub_smb2_main_fill_three_sprite_fields:
    STA Sprite_Data+8,y

sub_smb2_main_fill_two_sprite_fields:
    STA Sprite_Data+4,y  ; and into first row sprites
    STA Sprite_Data,y

bra_smb2_main_exit_sprite_data_fill:
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_draw_large_platform:
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    STY $02  ; store here
    INY  ; add 3 to it for offset
    INY  ; to X coordinate
    INY
    LDA Enemy_Rel_XPos  ; get horizontal relative coordinate
    JSR sub_smb2_main_six_sprite_stacker  ; store X coordinates using A as base, stack horizontally
    LDX ObjectOffset
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    JSR sub_smb2_main_fill_four_sprite_fields  ; dump into first four sprites as Y coordinate
    LDY AreaType
    CPY #$03  ; check for castle-type level
    BEQ bra_smb2_main_hide_large_platform_last_segments
    LDY SecondaryHardMode  ; check for secondary hard mode flag set
    BEQ bra_smb2_main_store_large_platform_last_segments_y  ; branch if not set elsewhere

bra_smb2_main_hide_large_platform_last_segments:
    LDA #$f8  ; load offscreen coordinate if flag set or castle-type level

bra_smb2_main_store_large_platform_last_segments_y:
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    STA Sprite_Y_Position+16,y  ; store vertical coordinate or offscreen
    STA Sprite_Y_Position+20,y  ; coordinate into last two sprites as Y coordinate
    LDA #$5b  ; load default tile for platform (mushroom)
    LDX CloudTypeOverride
    BEQ bra_smb2_main_store_large_platform_tiles  ; if cloud level override flag not set, use
    LDA #$75  ; otherwise load other tile for platform (puff)

bra_smb2_main_store_large_platform_tiles:
    LDX ObjectOffset  ; get enemy object buffer offset
    INY  ; increment Y for tile offset
    JSR sub_smb2_main_fill_six_sprite_fields  ; dump tile number into all six sprites
    LDA #$02  ; set palette controls
    INY  ; increment Y for sprite attributes
    JSR sub_smb2_main_fill_six_sprite_fields  ; dump attributes into all six sprites
    INX  ; increment X for enemy objects
    JSR sub_smb2_main_get_horizontal_offscreen_bits  ; get offscreen bits again
    DEX
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    ASL  ; rotate d7 into carry, save remaining
    PHA  ; bits to the stack
    BCC bra_smb2_main_clip_large_platform_second_sprite
    LDA #$f8  ; if d7 was set, move first sprite offscreen
    STA Sprite_Y_Position,y
bra_smb2_main_clip_large_platform_second_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d6 into carry
    PHA  ; save to stack
    BCC bra_smb2_main_clip_large_platform_third_sprite
    LDA #$f8  ; if d6 was set, move second sprite offscreen
    STA Sprite_Y_Position+4,y
bra_smb2_main_clip_large_platform_third_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d5 into carry
    PHA  ; save to stack
    BCC bra_smb2_main_clip_large_platform_fourth_sprite
    LDA #$f8  ; if d5 was set, move third sprite offscreen
    STA Sprite_Y_Position+8,y
bra_smb2_main_clip_large_platform_fourth_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d4 into carry
    PHA  ; save to stack
    BCC bra_smb2_main_clip_large_platform_fifth_sprite
    LDA #$f8  ; if d4 was set, move fourth sprite offscreen
    STA Sprite_Y_Position+12,y
bra_smb2_main_clip_large_platform_fifth_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d3 into carry
    PHA  ; save to stack
    BCC bra_smb2_main_clip_large_platform_sixth_sprite
    LDA #$f8  ; if d3 was set, move fifth sprite offscreen
    STA Sprite_Y_Position+16,y
bra_smb2_main_clip_large_platform_sixth_sprite:
    PLA  ; get bits from stack
    ASL  ; rotate d2 into carry
    BCC bra_smb2_main_check_large_platform_left_edge  ; save to stack
    LDA #$f8
    STA Sprite_Y_Position+20,y  ; if d2 was set, move sixth sprite offscreen
bra_smb2_main_check_large_platform_left_edge:
    LDA Enemy_OffscreenBits  ; check d7 of offscreen bits
    ASL  ; and if d7 is not set, skip sub
    BCC bra_smb2_main_exit_large_platform_draw
    JSR sub_smb2_main_move_six_sprites_offscreen  ; otherwise branch to move all sprites offscreen
bra_smb2_main_exit_large_platform_draw:
    RTS

; -------------------------------------------------------------------------------------

bra_smb2_main_draw_floating_coin_score:
    LDA FrameCounter  ; get frame counter
    LSR  ; divide by 2
    BCS bra_smb2_main_draw_floating_score_sprites  ; branch if d0 not set to raise number every other frame
    DEC Misc_Y_Position,x  ; otherwise, decrement vertical coordinate
bra_smb2_main_draw_floating_score_sprites:
    LDA Misc_Y_Position,x  ; get vertical coordinate
    JSR sub_smb2_main_fill_two_sprite_fields  ; dump into both sprites
    LDA Misc_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as X coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels
    STA Sprite_X_Position+4,y  ; store as X coordinate for second sprite
    LDA #$02
    STA Sprite_Attributes,y  ; store attribute byte in both sprites
    STA Sprite_Attributes+4,y
    LDA #$f7
    STA Sprite_Tilenumber,y  ; put tile numbers into both sprites
    LDA #$fb  ; that resemble "200"
    STA Sprite_Tilenumber+4,y
    JMP loc_smb2_main_exit_jumping_coin_graphics  ; then jump to leave (why not an rts here instead?)

tbl_smb2_main_jumping_coin_sprite_tiles:
    .byte $60, $61, $62, $63

sub_smb2_main_render_jumping_coin_graphics:
    LDY Misc_SprDataOffset,x  ; get coin/floatey number's OAM data offset
    LDA Misc_State,x  ; get state of misc object
    CMP #$02  ; if 2 or greater,
    BCS bra_smb2_main_draw_floating_coin_score  ; branch to draw floatey number
    LDA Misc_Y_Position,x  ; store vertical coordinate as
    STA Sprite_Y_Position,y  ; Y coordinate for first sprite
    CLC
    ADC #$08  ; add eight pixels
    STA Sprite_Y_Position+4,y  ; store as Y coordinate for second sprite
    LDA Misc_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y
    STA Sprite_X_Position+4,y  ; store as X coordinate for first and second sprites
    LDA FrameCounter  ; get frame counter
    LSR  ; divide by 2 to alter every other frame
    AND #%00000011  ; mask out d2-d1
    TAX  ; use as graphical offset
    LDA tbl_smb2_main_jumping_coin_sprite_tiles,x  ; load tile number
    INY  ; increment OAM data offset to write tile numbers
    JSR sub_smb2_main_fill_two_sprite_fields  ; do sub to dump tile number into both sprites
    DEY  ; decrement to get old offset
    LDA #$02
    STA Sprite_Attributes,y  ; set attribute byte in first sprite
    LDA #$82
    STA Sprite_Attributes+4,y  ; set attribute byte with vertical flip in second sprite
    LDX ObjectOffset  ; get misc object offset
loc_smb2_main_exit_jumping_coin_graphics:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold tiles for drawing the power-up, $00 also used to hold power-up type
; $02 - used to hold bottom row Y position
; $03 - used to hold flip control (not used here)
; $04 - used to hold sprite attributes
; $05 - used to hold X position
; $07 - counter

; tiles arranged in top left, right, bottom left, right order
tbl_smb2_main_power_up_graphics_tiles:
    .byte $d8, $da, $db, $ff  ; regular mushroom
    .byte $d6, $d6, $d9, $d9  ; fire flower
    .byte $8d, $8d, $e4, $e4  ; star
    .byte $d8, $da, $db, $ff  ; 1-up mushroom
    .byte $d8, $da, $db, $ff  ; poison mushroom

tbl_smb2_main_power_up_sprite_attributes:
    .byte $02, $01, $02, $01, $03

sub_smb2_main_draw_power_up:
    LDY Enemy_SprDataOffset+5  ; get power-up's sprite data offset
    LDA Enemy_Rel_YPos  ; get relative vertical coordinate
    CLC
    ADC #$08  ; add eight pixels
    STA $02  ; store result here
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA $05  ; store here
    LDX PowerUpType  ; get power-up type
    LDA tbl_smb2_main_power_up_sprite_attributes,x  ; get attribute data for power-up type
    ORA Enemy_SprAttrib+5  ; add background priority bit if set
    STA $04  ; store attributes here
    TXA
    PHA  ; save power-up type to the stack
    ASL
    ASL  ; multiply by four to get proper offset
    TAX  ; use as X
    LDA #$01
    STA $07  ; set counter here to draw two rows of sprite object
    STA $03  ; init d1 of flip control

bra_smb2_main_draw_power_up_sprite_rows:
    LDA tbl_smb2_main_power_up_graphics_tiles,x  ; load left tile of power-up object
    STA $00
    LDA tbl_smb2_main_power_up_graphics_tiles+1,x  ; load right tile
    JSR sub_smb2_main_draw_one_sprite_row  ; branch to draw one row of our power-up object
    DEC $07  ; decrement counter
    BPL bra_smb2_main_draw_power_up_sprite_rows  ; branch until two rows are drawn
    LDY Enemy_SprDataOffset+5  ; get sprite data offset again
    PLA  ; pull saved power-up type from the stack
    BEQ bra_smb2_main_clip_power_up_sprites  ; if regular mushroom, 1-up mushroom
    CMP #$03  ; or poison mushroom, branch
    BEQ bra_smb2_main_clip_power_up_sprites  ; do not change colors or flip them
    CMP #$04
    BEQ bra_smb2_main_clip_power_up_sprites
    STA $00  ; store power-up type here now
    LDA FrameCounter  ; get frame counter
    LSR  ; divide by 2 to change colors every two frames
    AND #%00000011  ; mask out all but d1 and d0 (previously d2 and d1)
    ORA Enemy_SprAttrib+5  ; add background priority bit if any set
    STA Sprite_Attributes,y  ; set as new palette bits for top left and
    STA Sprite_Attributes+4,y  ; top right sprites for fire flower and star
    LDX $00
    DEX  ; check power-up type for fire flower
    BEQ bra_smb2_main_flip_power_up_right_sprites  ; if found, skip this part
    STA Sprite_Attributes+8,y  ; otherwise set new palette bits for bottom left
    STA Sprite_Attributes+12,y  ; and bottom right sprites as well for star only

bra_smb2_main_flip_power_up_right_sprites:
    LDA Sprite_Attributes+4,y
    ORA #%01000000  ; set horizontal flip bit for top right sprite
    STA Sprite_Attributes+4,y
    LDA Sprite_Attributes+12,y
    ORA #%01000000  ; set horizontal flip bit for bottom right sprite
    STA Sprite_Attributes+12,y  ; note these are only done for fire flower and star power-ups
bra_smb2_main_clip_power_up_sprites:
    JMP bra_smb2_main_clip_enemy_sprites_variant_2  ; jump to check to see if power-up is offscreen at all, then leave

; -------------------------------------------------------------------------------------
; $00-$01 - used in DrawEnemyObjRow to hold sprite tile numbers
; $02 - used to store Y position
; $03 - used to store moving direction, used to flip enemies horizontally
; $04 - used to store enemy's sprite attributes
; $05 - used to store X position
; $eb - used to hold sprite data offset
; $ec - used to hold either altered enemy state or special value used in gfx handler as condition
; $ed - used to hold enemy state from buffer
; $ef - used to hold enemy code used in gfx handler (may or may not resemble Enemy_ID values)

; tiles arranged in top left, right, middle left, right, bottom left, right order
; most enemies use more than one frame, thus have more than 6 tiles
tbl_smb2_main_enemy_graphics_tiles:
    .byte $fc, $fc, $aa, $ab, $ac, $ad  ; buzzy beetle
    .byte $fc, $fc, $ae, $af, $b0, $b1
    .byte $fc, $a5, $a6, $a7, $a8, $a9  ; koopa troopa
    .byte $fc, $a0, $a1, $a2, $a3, $a4
    .byte $69, $a5, $6a, $a7, $a8, $a9  ; koopa paratroopa
    .byte $6b, $a0, $6c, $a2, $a3, $a4
    .byte $fc, $fc, $96, $97, $98, $99  ; spiny
    .byte $fc, $fc, $9a, $9b, $9c, $9d
    .byte $fc, $fc, $8f, $8e, $8e, $8f  ; spiny egg
    .byte $fc, $fc, $95, $94, $94, $95
    .byte $fc, $fc, $dc, $dc, $df, $df  ; bloober
    .byte $dc, $dc, $dd, $dd, $de, $de
    .byte $fc, $fc, $b2, $b3, $b4, $b5  ; cheep-cheep
    .byte $fc, $fc, $b6, $b3, $b7, $b5
    .byte $fc, $fc, $70, $71, $72, $73  ; goomba
    .byte $fc, $fc, $6e, $6e, $6f, $6f  ; koopa shell (upside-down)
    .byte $fc, $fc, $6d, $6d, $6f, $6f
    .byte $fc, $fc, $6f, $6f, $6e, $6e  ; koopa shell
    .byte $fc, $fc, $6f, $6f, $6d, $6d
    .byte $fc, $fc, $f4, $f4, $f5, $f5  ; buzzy beetle shell (upside-down)
    .byte $fc, $fc, $f4, $f4, $f5, $f5
    .byte $fc, $fc, $f5, $f5, $f4, $f4  ; buzzy beetle
    .byte $fc, $fc, $f5, $f5, $f4, $f4
    .byte $fc, $fc, $fc, $fc, $ef, $ef  ; defeated goomba
    .byte $b9, $b8, $bb, $ba, $bc, $bc  ; lakitu
    .byte $fc, $fc, $bd, $bd, $bc, $bc
    .byte $76, $79, $77, $77, $78, $78  ; princess/door to princess's room
    .byte $cd, $cd, $ce, $ce, $cf, $cf  ; mushroom retainer
    .byte $7d, $7c, $d1, $8c, $d3, $d2  ; hammer bro
    .byte $7d, $7c, $89, $88, $8b, $8a
    .byte $d5, $d4, $e3, $e2, $d3, $d2
    .byte $d5, $d4, $e3, $e2, $8b, $8a
    .byte $e5, $e5, $e6, $e6, $eb, $eb  ; piranha plant
    .byte $ec, $ec, $ed, $ed, $ee, $ee
    .byte $fc, $fc, $d0, $d0, $d7, $d7  ; podoboo
    .byte $bf, $be, $c1, $c0, $c2, $fc  ; bowser front
    .byte $c4, $c3, $c6, $c5, $c8, $c7  ; bowser rear
    .byte $bf, $be, $ca, $c9, $c2, $fc  ; front frame 2
    .byte $c4, $c3, $c6, $c5, $cc, $cb  ; rear frame 2
    .byte $fc, $fc, $e8, $e7, $ea, $e9  ; bullet bill
    .byte $f2, $f2, $f3, $f3, $f2, $f2  ; jumpspring
    .byte $f1, $f1, $f1, $f1, $fc, $fc
    .byte $f0, $f0, $fc, $fc, $fc, $fc

tbl_smb2_main_enemy_graphics_offsets:
    .byte $0c, $0c, $00, $0c, $c0, $a8, $54, $3c
    .byte $ea, $18, $48, $48, $cc, $c0, $18, $18
    .byte $18, $90, $24, $ff, $48, $9c, $d2, $d8
    .byte $f0, $f6, $fc

off_smb2_main_enemy_sprite_attributes:
    .byte $01, $02, $03, $02, $22, $01, $03, $03
    .byte $03, $01, $01, $02, $02, $21, $01, $02
    .byte $01, $01, $02, $ff, $02, $02, $01, $01
    .byte $02, $02, $02

tbl_smb2_main_enemy_animation_timing_masks:
    .byte $08, $18

tbl_smb2_main_jumpspring_graphics_offsets:
    .byte $18, $19, $1a, $19, $18
