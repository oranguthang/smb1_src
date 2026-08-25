; -------------------------------------------------------------------------------------
; $00-$01 - tile numbers
; $02 - relative Y position
; $03 - horizontal flip flag (not used here)
; $04 - attributes
; $05 - relative X position

tbl_default_block_sprite_tiles:
    .byte $85, $85, $86, $86  ; brick w/ line (these are sprite tiles, not BG!)

sub_draw_block:
    LDA ram_block_rel_y_pos  ; get relative vertical coordinate of block object
    STA $02  ; store here
    LDA ram_block_rel_x_pos  ; get relative horizontal coordinate of block object
    STA $05  ; store here
    LDA #$03
    STA $04  ; set attribute byte here
    LSR
    STA $03  ; set horizontal flip bit here (will not be used)
    LDY ram_block_spr_data_offset,x  ; get sprite data offset
    LDX #$00  ; reset X for use as offset to tile data
bra_draw_block_sprite_rows:
    LDA tbl_default_block_sprite_tiles,x  ; get left tile number
    STA $00  ; set here
    LDA tbl_default_block_sprite_tiles+1,x  ; get right tile number
    JSR sub_draw_one_sprite_row  ; do sub to write tile numbers to first row of sprites
    CPX #$04  ; check incremented offset
    BNE bra_draw_block_sprite_rows  ; and loop back until all four sprites are done
    LDX ram_object_offset  ; get block object offset
    LDY ram_block_spr_data_offset,x  ; get sprite data offset
    LDA ram_area_type
    CMP #$01  ; check for ground level type area
    BEQ bra_check_block_replacement_metatile  ; if found, branch to next part
    LDA #$86
    STA ram_sprite_tilenumber,y  ; otherwise remove brick tiles with lines
    STA ram_sprite_tilenumber+4,y  ; and replace then with lineless brick tiles
bra_check_block_replacement_metatile:
    LDA ram_block_metatile,x  ; check replacement metatile
    CMP #$c4  ; if not used block metatile, then
    BNE bra_clip_block_sprites  ; branch ahead to use current graphics
    LDA #$87  ; set A for used block tile
    INY  ; increment Y to write to tile bytes
    JSR sub_fill_four_sprite_fields  ; do sub to dump into all four sprites
    DEY  ; return Y to original offset
    LDA #$03  ; set palette bits
    LDX ram_area_type
    DEX  ; check for ground level type area again
    BEQ bra_store_used_block_attributes  ; if found, use current palette bits
    LSR  ; otherwise set to $01
bra_store_used_block_attributes:
    LDX ram_object_offset  ; put block object offset back in X
    STA ram_sprite_attributes,y  ; store attribute byte as-is in first sprite
    ORA #%01000000
    STA ram_sprite_attributes+4,y  ; set horizontal flip bit for second sprite
    ORA #%10000000
    STA ram_sprite_attributes+12,y  ; set both flip bits for fourth sprite
    AND #%10000011
    STA ram_sprite_attributes+8,y  ; set vertical flip bit for third sprite
bra_clip_block_sprites:
    LDA ram_block_offscreen_bits  ; get offscreen bits for block object
    PHA  ; save to stack
    AND #%00000100  ; check to see if d2 in offscreen bits are set
    BEQ bra_check_block_left_offscreen_bits  ; if not set, branch, otherwise move sprites offscreen
    LDA #$f8  ; move offscreen two OAMs
    STA ram_sprite_y_position+4,y  ; on the right side
    STA ram_sprite_y_position+12,y
bra_check_block_left_offscreen_bits:
    PLA  ; pull offscreen bits from stack
sub_check_left_column_offscreen:
    AND #%00001000  ; check to see if d3 in offscreen bits are set
    BEQ bra_exit_block_sprite_draw  ; if not set, branch, otherwise move sprites offscreen

sub_move_col_offscreen:
    LDA #$f8  ; move offscreen two OAMs
    STA ram_sprite_y_position,y  ; on the left side (or two rows of enemy on either side
    STA ram_sprite_y_position+8,y  ; if branched here from enemy graphics handler)
bra_exit_block_sprite_draw:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used to hold palette bits for attribute byte or relative X position

sub_draw_brick_chunks:
    LDA #$02  ; set palette bits here
    STA $00
    LDA #$75  ; set tile number for ball (something residual, likely)
    LDY ram_game_engine_subroutine
    CPY #$05  ; if end-of-level routine running,
    BEQ bra_draw_brick_chunk_tiles  ; use palette and tile number assigned
    LDA #$03  ; otherwise set different palette bits
    STA $00
    LDA #$84  ; and set tile number for brick chunks
bra_draw_brick_chunk_tiles:
    LDY ram_block_spr_data_offset,x  ; get OAM data offset
    INY  ; increment to start with tile bytes in OAM
    JSR sub_fill_four_sprite_fields  ; do sub to dump tile number into all four sprites
    LDA ram_frame_counter  ; get frame counter
    ASL
    ASL
    ASL  ; move low nybble to high
    ASL
    AND #$c0  ; get what was originally d3-d2 of low nybble
    ORA $00  ; add palette bits
    INY  ; increment offset for attribute bytes
    JSR sub_fill_four_sprite_fields  ; do sub to dump attribute data into all four sprites
    DEY
    DEY  ; decrement offset to Y coordinate
    LDA ram_block_rel_y_pos  ; get first block object's relative vertical coordinate
    JSR sub_fill_two_sprite_fields  ; do sub to dump current Y coordinate into two sprites
    LDA ram_block_rel_x_pos  ; get first block object's relative horizontal coordinate
    STA ram_sprite_x_position,y  ; save into X coordinate of first sprite
    LDA ram_block_orig_x_pos,x  ; get original horizontal coordinate
    SEC
    SBC ram_screen_left_x_pos  ; subtract coordinate of left side from original coordinate
    STA $00  ; store result as relative horizontal coordinate of original
    SEC
    SBC ram_block_rel_x_pos  ; get difference of relative positions of original - current
    ADC $00  ; add original relative position to result
    ADC #$06  ; plus 6 pixels to position second brick chunk correctly
    STA ram_sprite_x_position+4,y  ; save into X coordinate of second sprite
    LDA ram_block_rel_y_pos+1  ; get second block object's relative vertical coordinate
    STA ram_sprite_y_position+8,y
    STA ram_sprite_y_position+12,y  ; dump into Y coordinates of third and fourth sprites
    LDA ram_block_rel_x_pos+1  ; get second block object's relative horizontal coordinate
    STA ram_sprite_x_position+8,y  ; save into X coordinate of third sprite
    LDA $00  ; use original relative horizontal position
    SEC
    SBC ram_block_rel_x_pos+1  ; get difference of relative positions of original - current
    ADC $00  ; add original relative position to result
    ADC #$06  ; plus 6 pixels to position fourth brick chunk correctly
    STA ram_sprite_x_position+12,y  ; save into X coordinate of fourth sprite
    LDA ram_block_offscreen_bits  ; get offscreen bits for block object
    JSR sub_check_left_column_offscreen  ; do sub to move left half of sprites offscreen if necessary
    LDA ram_block_offscreen_bits  ; get offscreen bits again
    ASL  ; shift d7 into carry
    BCC bra_clip_brick_chunk_horizontal_wrap  ; if d7 not set, branch to last part
    LDA #$f8
    JSR sub_fill_two_sprite_fields  ; otherwise move top sprites offscreen
bra_clip_brick_chunk_horizontal_wrap:
    LDA $00  ; if relative position on left side of screen,
    BPL bra_exit_brick_chunk_draw  ; go ahead and leave
    LDA ram_sprite_x_position,y  ; otherwise compare left-side X coordinate
    CMP ram_sprite_x_position+4,y  ; to right-side X coordinate
    BCC bra_exit_brick_chunk_draw  ; branch to leave if less
    LDA #$f8  ; otherwise move right half of sprites offscreen
    STA ram_sprite_y_position+4,y
    STA ram_sprite_y_position+12,y
bra_exit_brick_chunk_draw:
    RTS  ; leave

; -------------------------------------------------------------------------------------

loc_draw_fireball:
    LDY ram_f_ball_spr_data_offset,x  ; get fireball's sprite data offset
    LDA ram_fireball_rel_y_pos  ; get relative vertical coordinate
    STA ram_sprite_y_position,y  ; store as sprite Y coordinate
    LDA ram_fireball_rel_x_pos  ; get relative horizontal coordinate
    STA ram_sprite_x_position,y  ; store as sprite X coordinate, then do shared code

sub_draw_firebar:
    LDA ram_frame_counter  ; get frame counter
    LSR  ; divide by four
    LSR
    PHA  ; save result to stack
    AND #$01  ; mask out all but last bit
    EOR #$64  ; set either tile $64 or $65 as fireball tile
    STA ram_sprite_tilenumber,y  ; thus tile changes every four frames
    PLA  ; get from stack
    LSR  ; divide by four again
    LSR
    LDA #$02  ; load value $02 to set palette in attrib byte
    BCC bra_store_fireball_attributes  ; if last bit shifted out was not set, skip this
    ORA #%11000000  ; otherwise flip both ways every eight frames
bra_store_fireball_attributes:
    STA ram_sprite_attributes,y  ; store attribute byte and leave
    RTS

; -------------------------------------------------------------------------------------

tbl_explosion_sprite_tiles:
    .byte $68, $67, $66

loc_draw_fireball_explosion:
    LDY ram_alt_spr_data_offset,x  ; get OAM data offset of alternate sort for fireball's explosion
    LDA ram_fireball_state,x  ; load fireball state
    INC ram_fireball_state,x  ; increment state for next frame
    LSR  ; divide by 2
    AND #%00000111  ; mask out all but d3-d1
    CMP #$03  ; check to see if time to kill fireball
    BCS bra_finish_fireball_explosion  ; branch if so, otherwise continue to draw explosion

sub_draw_explosion_fireworks:
    TAX  ; use whatever's in A for offset
    LDA tbl_explosion_sprite_tiles,x  ; get tile number using offset
    INY  ; increment Y (contains sprite data offset)
    JSR sub_fill_four_sprite_fields  ; and dump into tile number part of sprite data
    DEY  ; decrement Y so we have the proper offset again
    LDX ram_object_offset  ; return enemy object buffer offset to X
    LDA ram_fireball_rel_y_pos  ; get relative vertical coordinate
    SEC  ; subtract four pixels vertically
    SBC #$04  ; for first and third sprites
    STA ram_sprite_y_position,y
    STA ram_sprite_y_position+8,y
    CLC  ; add eight pixels vertically
    ADC #$08  ; for second and fourth sprites
    STA ram_sprite_y_position+4,y
    STA ram_sprite_y_position+12,y
    LDA ram_fireball_rel_x_pos  ; get relative horizontal coordinate
    SEC  ; subtract four pixels horizontally
    SBC #$04  ; for first and second sprites
    STA ram_sprite_x_position,y
    STA ram_sprite_x_position+4,y
    CLC  ; add eight pixels horizontally
    ADC #$08  ; for third and fourth sprites
    STA ram_sprite_x_position+8,y
    STA ram_sprite_x_position+12,y
    LDA #$02  ; set palette attributes for all sprites, but
    STA ram_sprite_attributes,y  ; set no flip at all for first sprite
    LDA #$82
    STA ram_sprite_attributes+4,y  ; set vertical flip for second sprite
    LDA #$42
    STA ram_sprite_attributes+8,y  ; set horizontal flip for third sprite
    LDA #$c2
    STA ram_sprite_attributes+12,y  ; set both flips for fourth sprite
    RTS  ; we are done

bra_finish_fireball_explosion:
    LDA #$00  ; clear fireball state to kill it
    STA ram_fireball_state,x
    RTS

; -------------------------------------------------------------------------------------

sub_draw_small_platform:
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    LDA #$5b  ; load tile number for small platforms
    INY  ; increment offset for tile numbers
    JSR sub_fill_six_sprite_fields  ; dump tile number into all six sprites
    INY  ; increment offset for attributes
    LDA #$02  ; load palette controls
    JSR sub_fill_six_sprite_fields  ; dump attributes into all six sprites
    DEY  ; decrement for original offset
    DEY
    LDA ram_enemy_rel_x_pos  ; get relative horizontal coordinate
    STA ram_sprite_x_position,y
    STA ram_sprite_x_position+12,y  ; dump as X coordinate into first and fourth sprites
    CLC
    ADC #$08  ; add eight pixels
    STA ram_sprite_x_position+4,y  ; dump into second and fifth sprites
    STA ram_sprite_x_position+16,y
    CLC
    ADC #$08  ; add eight more pixels
    STA ram_sprite_x_position+8,y  ; dump into third and sixth sprites
    STA ram_sprite_x_position+20,y
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    TAX
    PHA  ; save to stack
    CPX #$20  ; if vertical coordinate below status bar,
    BCS bra_store_small_platform_top_row_y  ; do not mess with it
    LDA #$f8  ; otherwise move first three sprites offscreen
bra_store_small_platform_top_row_y:
    JSR sub_fill_three_sprite_fields  ; dump vertical coordinate into Y coordinates
    PLA  ; pull from stack
    CLC
    ADC #$80  ; add 128 pixels
    TAX
    CPX #$20  ; if below status bar (taking wrap into account)
    BCS bra_store_small_platform_bottom_row_y  ; then do not change altered coordinate
    LDA #$f8  ; otherwise move last three sprites offscreen
bra_store_small_platform_bottom_row_y:
    STA ram_sprite_y_position+12,y  ; dump vertical coordinate + 128 pixels
    STA ram_sprite_y_position+16,y  ; into Y coordinates
    STA ram_sprite_y_position+20,y
    LDA ram_enemy_offscreen_bits  ; get offscreen bits
    PHA  ; save to stack
    AND #%00001000  ; check d3
    BEQ bra_check_small_platform_middle_column
    LDA #$f8  ; if d3 was set, move first and
    STA ram_sprite_y_position,y  ; fourth sprites offscreen
    STA ram_sprite_y_position+12,y
bra_check_small_platform_middle_column:
    PLA  ; move out and back into stack
    PHA
    AND #%00000100  ; check d2
    BEQ bra_check_small_platform_right_column
    LDA #$f8  ; if d2 was set, move second and
    STA ram_sprite_y_position+4,y  ; fifth sprites offscreen
    STA ram_sprite_y_position+16,y
bra_check_small_platform_right_column:
    PLA  ; get from stack
    AND #%00000010  ; check d1
    BEQ bra_exit_small_platform_draw
    LDA #$f8  ; if d1 was set, move third and
    STA ram_sprite_y_position+8,y  ; sixth sprites offscreen
    STA ram_sprite_y_position+20,y
bra_exit_small_platform_draw:
    LDX ram_object_offset  ; get enemy object offset and leave
    RTS

; -------------------------------------------------------------------------------------

sub_draw_bubble:
    LDY ram_player_y_high_pos  ; if player's vertical high position
    DEY  ; not within screen, skip all of this
    BNE bra_exit_bubble_draw
    LDA ram_bubble_offscreen_bits  ; check air bubble's offscreen bits
    AND #%00001000
    BNE bra_exit_bubble_draw  ; if bit set, branch to leave
    LDY ram_bubble_spr_data_offset,x  ; get air bubble's OAM data offset
    LDA ram_bubble_rel_x_pos  ; get relative horizontal coordinate
    STA ram_sprite_x_position,y  ; store as X coordinate here
    LDA ram_bubble_rel_y_pos  ; get relative vertical coordinate
    STA ram_sprite_y_position,y  ; store as Y coordinate here
    LDA #$74
    STA ram_sprite_tilenumber,y  ; put air bubble tile into OAM data
    LDA #$02
    STA ram_sprite_attributes,y  ; set attribute byte
bra_exit_bubble_draw:
    RTS  ; leave
