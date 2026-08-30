tbl_smb2_main_default_block_sprite_tiles:
    .byte $85, $85, $86, $86  ; brick w/ line (these are sprite tiles, not BG!)

sub_smb2_main_draw_block:
    LDA Block_Rel_YPos  ; get relative vertical coordinate of block object
    STA $02  ; store here
    LDA Block_Rel_XPos  ; get relative horizontal coordinate of block object
    STA $05  ; store here
    LDA #$03
    STA $04  ; set attribute byte here
    LSR
    STA $03  ; set horizontal flip bit here (will not be used)
    LDY Block_SprDataOffset,x  ; get sprite data offset
    LDX #$00  ; reset X for use as offset to tile data
bra_smb2_main_draw_block_sprite_rows:
    LDA tbl_smb2_main_default_block_sprite_tiles,x  ; get left tile number
    STA $00  ; set here
    LDA tbl_smb2_main_default_block_sprite_tiles+1,x  ; get right tile number
    JSR sub_smb2_main_draw_one_sprite_row  ; do sub to write tile numbers to first row of sprites
    CPX #$04  ; check incremented offset
    BNE bra_smb2_main_draw_block_sprite_rows  ; and loop back until all four sprites are done
    LDX ObjectOffset  ; get block object offset
    LDY Block_SprDataOffset,x  ; get sprite data offset
    LDA AreaType
    CMP #$01  ; check for ground level type area
    BEQ bra_smb2_main_check_block_replacement_metatile  ; if found, branch to next part
    LDA #$86
    STA Sprite_Tilenumber,y  ; otherwise remove brick tiles with lines
    STA Sprite_Tilenumber+4,y  ; and replace then with lineless brick tiles
bra_smb2_main_check_block_replacement_metatile:
    LDA Block_Metatile,x  ; check replacement metatile
    CMP #$c5  ; if not used block metatile, then
    BNE bra_smb2_main_clip_block_sprites  ; branch ahead to use current graphics
    LDA #$87  ; set A for used block tile
    INY  ; increment Y to write to tile bytes
    JSR sub_smb2_main_fill_four_sprite_fields  ; do sub to dump into all four sprites
    DEY  ; return Y to original offset
    LDA #$03  ; set palette bits
    LDX AreaType
    DEX  ; check for ground level type area again
    BEQ bra_smb2_main_store_used_block_attributes  ; if found, use current palette bits
    LSR  ; otherwise set to $01
bra_smb2_main_store_used_block_attributes:
    LDX ObjectOffset  ; put block object offset back in X
    STA Sprite_Attributes,y  ; store attribute byte as-is in first sprite
    ORA #%01000000
    STA Sprite_Attributes+4,y  ; set horizontal flip bit for second sprite
    ORA #%10000000
    STA Sprite_Attributes+12,y  ; set both flip bits for fourth sprite
    AND #%10000011
    STA Sprite_Attributes+8,y  ; set vertical flip bit for third sprite
bra_smb2_main_clip_block_sprites:
    LDA Block_OffscreenBits  ; get offscreen bits for block object
    PHA  ; save to stack
    AND #%00000100  ; check to see if d2 in offscreen bits are set
    BEQ bra_smb2_main_check_block_left_offscreen_bits  ; if not set, branch, otherwise move sprites offscreen
    LDA #$f8  ; move offscreen two OAMs
    STA Sprite_Y_Position+4,y  ; on the right side
    STA Sprite_Y_Position+12,y
bra_smb2_main_check_block_left_offscreen_bits:
    PLA  ; pull offscreen bits from stack
sub_smb2_main_check_left_column_offscreen:
    AND #%00001000  ; check to see if d3 in offscreen bits are set
    BEQ bra_smb2_main_exit_block_sprite_draw  ; if not set, branch, otherwise move sprites offscreen

sub_smb2_main_move_col_offscreen:
    LDA #$f8  ; move offscreen two OAMs
    STA Sprite_Y_Position,y  ; on the left side (or two rows of enemy on either side
    STA Sprite_Y_Position+8,y  ; if branched here from enemy graphics handler)
bra_smb2_main_exit_block_sprite_draw:
    RTS

; -------------------------------------------------------------------------------------
; $00 - used to hold palette bits for attribute byte or relative X position

sub_smb2_main_draw_brick_chunks:
    LDA #$02  ; set palette bits here
    STA $00
    LDA #$75  ; set tile number for ball (something residual, likely)
    LDY GameEngineSubroutine
    CPY #$05  ; if end-of-level routine running,
    BEQ bra_smb2_main_draw_brick_chunk_tiles  ; use palette and tile number assigned
    LDA #$03  ; otherwise set different palette bits
    STA $00
    LDA #$84  ; and set tile number for brick chunks
bra_smb2_main_draw_brick_chunk_tiles:
    LDY Block_SprDataOffset,x  ; get OAM data offset
    INY  ; increment to start with tile bytes in OAM
    JSR sub_smb2_main_fill_four_sprite_fields  ; do sub to dump tile number into all four sprites
    LDA FrameCounter  ; get frame counter
    ASL
    ASL
    ASL  ; move low nybble to high
    ASL
    AND #$c0  ; get what was originally d3-d2 of low nybble
    ORA $00  ; add palette bits
    INY  ; increment offset for attribute bytes
    JSR sub_smb2_main_fill_four_sprite_fields  ; do sub to dump attribute data into all four sprites
    DEY
    DEY  ; decrement offset to Y coordinate
    LDA Block_Rel_YPos  ; get first block object's relative vertical coordinate
    JSR sub_smb2_main_fill_two_sprite_fields  ; do sub to dump current Y coordinate into two sprites
    LDA Block_Rel_XPos  ; get first block object's relative horizontal coordinate
    STA Sprite_X_Position,y  ; save into X coordinate of first sprite
    LDA Block_Orig_XPos,x  ; get original horizontal coordinate
    SEC
    SBC ScreenLeft_X_Pos  ; subtract coordinate of left side from original coordinate
    STA $00  ; store result as relative horizontal coordinate of original
    SEC
    SBC Block_Rel_XPos  ; get difference of relative positions of original - current
    ADC $00  ; add original relative position to result
    ADC #$06  ; plus 6 pixels to position second brick chunk correctly
    STA Sprite_X_Position+4,y  ; save into X coordinate of second sprite
    LDA Block_Rel_YPos+1  ; get second block object's relative vertical coordinate
    STA Sprite_Y_Position+8,y
    STA Sprite_Y_Position+12,y  ; dump into Y coordinates of third and fourth sprites
    LDA Block_Rel_XPos+1  ; get second block object's relative horizontal coordinate
    STA Sprite_X_Position+8,y  ; save into X coordinate of third sprite
    LDA $00  ; use original relative horizontal position
    SEC
    SBC Block_Rel_XPos+1  ; get difference of relative positions of original - current
    ADC $00  ; add original relative position to result
    ADC #$06  ; plus 6 pixels to position fourth brick chunk correctly
    STA Sprite_X_Position+12,y  ; save into X coordinate of fourth sprite
    LDA Block_OffscreenBits  ; get offscreen bits for block object
    JSR sub_smb2_main_check_left_column_offscreen  ; do sub to move left half of sprites offscreen if necessary
    LDA Block_OffscreenBits  ; get offscreen bits again
    ASL  ; shift d7 into carry
    BCC bra_smb2_main_clip_brick_chunk_horizontal_wrap  ; if d7 not set, branch to last part
    LDA #$f8
    JSR sub_smb2_main_fill_two_sprite_fields  ; otherwise move top sprites offscreen
bra_smb2_main_clip_brick_chunk_horizontal_wrap:
    LDA $00  ; if relative position on left side of screen,
    BPL bra_smb2_main_exit_brick_chunk_draw  ; go ahead and leave
    LDA Sprite_X_Position,y  ; otherwise compare left-side X coordinate
    CMP Sprite_X_Position+4,y  ; to right-side X coordinate
    BCC bra_smb2_main_exit_brick_chunk_draw  ; branch to leave if less
    LDA #$f8  ; otherwise move right half of sprites offscreen
    STA Sprite_Y_Position+4,y
    STA Sprite_Y_Position+12,y
bra_smb2_main_exit_brick_chunk_draw:
    RTS  ; leave

; -------------------------------------------------------------------------------------

loc_smb2_main_draw_fireball:
    LDY FBall_SprDataOffset,x  ; get fireball's sprite data offset
    LDA Fireball_Rel_YPos  ; get relative vertical coordinate
    STA Sprite_Y_Position,y  ; store as sprite Y coordinate
    LDA Fireball_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as sprite X coordinate, then do shared code

sub_smb2_main_draw_firebar:
    LDA FrameCounter  ; get frame counter
    LSR  ; divide by four
    LSR
    PHA  ; save result to stack
    AND #$01  ; mask out all but last bit
    EOR #$64  ; set either tile $64 or $65 as fireball tile
    STA Sprite_Tilenumber,y  ; thus tile changes every four frames
    PLA  ; get from stack
    LSR  ; divide by four again
    LSR
    LDA #$02  ; load value $02 to set palette in attrib byte
    BCC bra_smb2_main_store_fireball_attributes  ; if last bit shifted out was not set, skip this
    ORA #%11000000  ; otherwise flip both ways every eight frames
bra_smb2_main_store_fireball_attributes:
    STA Sprite_Attributes,y  ; store attribute byte and leave
    RTS

; -------------------------------------------------------------------------------------

tbl_smb2_main_explosion_sprite_tiles:
    .byte $68, $67, $66

loc_smb2_main_draw_fireball_explosion:
    LDY Alt_SprDataOffset,x  ; get OAM data offset of alternate sort for fireball's explosion
    LDA Fireball_State,x  ; load fireball state
    INC Fireball_State,x  ; increment state for next frame
    LSR  ; divide by 2
    AND #%00000111  ; mask out all but d3-d1
    CMP #$03  ; check to see if time to kill fireball
    BCS bra_smb2_main_finish_fireball_explosion  ; branch if so, otherwise continue to draw explosion

sub_smb2_main_draw_explosion_fireworks:
    TAX  ; use whatever's in A for offset
    LDA tbl_smb2_main_explosion_sprite_tiles,x  ; get tile number using offset
    INY  ; increment Y (contains sprite data offset)
    JSR sub_smb2_main_fill_four_sprite_fields  ; and dump into tile number part of sprite data
    DEY  ; decrement Y so we have the proper offset again
    LDX ObjectOffset  ; return enemy object buffer offset to X
    LDA Fireball_Rel_YPos  ; get relative vertical coordinate
    SEC  ; subtract four pixels vertically
    SBC #$04  ; for first and third sprites
    STA Sprite_Y_Position,y
    STA Sprite_Y_Position+8,y
    CLC  ; add eight pixels vertically
    ADC #$08  ; for second and fourth sprites
    STA Sprite_Y_Position+4,y
    STA Sprite_Y_Position+12,y
    LDA Fireball_Rel_XPos  ; get relative horizontal coordinate
    SEC  ; subtract four pixels horizontally
    SBC #$04  ; for first and second sprites
    STA Sprite_X_Position,y
    STA Sprite_X_Position+4,y
    CLC  ; add eight pixels horizontally
    ADC #$08  ; for third and fourth sprites
    STA Sprite_X_Position+8,y
    STA Sprite_X_Position+12,y
    LDA #$02  ; set palette attributes for all sprites, but
    STA Sprite_Attributes,y  ; set no flip at all for first sprite
    LDA #$82
    STA Sprite_Attributes+4,y  ; set vertical flip for second sprite
    LDA #$42
    STA Sprite_Attributes+8,y  ; set horizontal flip for third sprite
    LDA #$c2
    STA Sprite_Attributes+12,y  ; set both flips for fourth sprite
    RTS  ; we are done

bra_smb2_main_finish_fireball_explosion:
    LDA #$00  ; clear fireball state to kill it
    STA Fireball_State,x
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_draw_small_platform:
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA #$5b  ; load tile number for small platforms
    INY  ; increment offset for tile numbers
    JSR sub_smb2_main_fill_six_sprite_fields  ; dump tile number into all six sprites
    INY  ; increment offset for attributes
    LDA #$02  ; load palette controls
    JSR sub_smb2_main_fill_six_sprite_fields  ; dump attributes into all six sprites
    DEY  ; decrement for original offset
    DEY
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y
    STA Sprite_X_Position+12,y  ; dump as X coordinate into first and fourth sprites
    CLC
    ADC #$08  ; add eight pixels
    STA Sprite_X_Position+4,y  ; dump into second and fifth sprites
    STA Sprite_X_Position+16,y
    CLC
    ADC #$08  ; add eight more pixels
    STA Sprite_X_Position+8,y  ; dump into third and sixth sprites
    STA Sprite_X_Position+20,y
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    TAX
    PHA  ; save to stack
    CPX #$20  ; if vertical coordinate below status bar,
    BCS bra_smb2_main_store_small_platform_top_row_y  ; do not mess with it
    LDA #$f8  ; otherwise move first three sprites offscreen
bra_smb2_main_store_small_platform_top_row_y:
    JSR sub_smb2_main_fill_three_sprite_fields  ; dump vertical coordinate into Y coordinates
    PLA  ; pull from stack
    CLC
    ADC #$80  ; add 128 pixels
    TAX
    CPX #$20  ; if below status bar (taking wrap into account)
    BCS bra_smb2_main_store_small_platform_bottom_row_y  ; then do not change altered coordinate
    LDA #$f8  ; otherwise move last three sprites offscreen
bra_smb2_main_store_small_platform_bottom_row_y:
    STA Sprite_Y_Position+12,y  ; dump vertical coordinate + 128 pixels
    STA Sprite_Y_Position+16,y  ; into Y coordinates
    STA Sprite_Y_Position+20,y
    LDA Enemy_OffscreenBits  ; get offscreen bits
    PHA  ; save to stack
    AND #%00001000  ; check d3
    BEQ bra_smb2_main_check_small_platform_middle_column
    LDA #$f8  ; if d3 was set, move first and
    STA Sprite_Y_Position,y  ; fourth sprites offscreen
    STA Sprite_Y_Position+12,y
bra_smb2_main_check_small_platform_middle_column:
    PLA  ; move out and back into stack
    PHA
    AND #%00000100  ; check d2
    BEQ bra_smb2_main_check_small_platform_right_column
    LDA #$f8  ; if d2 was set, move second and
    STA Sprite_Y_Position+4,y  ; fifth sprites offscreen
    STA Sprite_Y_Position+16,y
bra_smb2_main_check_small_platform_right_column:
    PLA  ; get from stack
    AND #%00000010  ; check d1
    BEQ bra_smb2_main_exit_small_platform_draw
    LDA #$f8  ; if d1 was set, move third and
    STA Sprite_Y_Position+8,y  ; sixth sprites offscreen
    STA Sprite_Y_Position+20,y
bra_smb2_main_exit_small_platform_draw:
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_draw_bubble:
    LDY Player_Y_HighPos  ; if player's vertical high position
    DEY  ; not within screen, skip all of this
    BNE bra_smb2_main_exit_bubble_draw
    LDA Bubble_OffscreenBits  ; check air bubble's offscreen bits
    AND #%00001000
    BNE bra_smb2_main_exit_bubble_draw  ; if bit set, branch to leave
    LDY Bubble_SprDataOffset,x  ; get air bubble's OAM data offset
    LDA Bubble_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as X coordinate here
    LDA Bubble_Rel_YPos  ; get relative vertical coordinate
    STA Sprite_Y_Position,y  ; store as Y coordinate here
    LDA #$74
    STA Sprite_Tilenumber,y  ; put air bubble tile into OAM data
    LDA #$02
    STA Sprite_Attributes,y  ; set attribute byte
bra_smb2_main_exit_bubble_draw:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00 - used to store player's vertical offscreen bits
