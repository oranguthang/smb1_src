tbl_smb2_main_player_graphics_frame_offsets:
    .byte $20, $28, $c8, $18, $00, $40, $50, $58
    .byte $80, $88, $b8, $78, $60, $a0, $b0, $b8

; tiles arranged in order, 2 tiles per row, top to bottom

tbl_smb2_main_player_graphics_tiles:
; big player table
    .byte $00, $01, $02, $03, $04, $05, $06, $07  ; walking frame 1
    .byte $08, $09, $0a, $0b, $0c, $0d, $0e, $0f  ; frame 2
    .byte $10, $11, $12, $13, $14, $15, $16, $17  ; frame 3
    .byte $18, $19, $1a, $1b, $1c, $1d, $1e, $1f  ; skidding
    .byte $20, $21, $22, $23, $24, $25, $26, $27  ; jumping
    .byte $08, $09, $28, $29, $2a, $2b, $2c, $2d  ; swimming frame 1
    .byte $08, $09, $0a, $0b, $0c, $30, $2c, $2d  ; frame 2
    .byte $08, $09, $0a, $0b, $2e, $2f, $2c, $2d  ; frame 3
    .byte $08, $09, $28, $29, $2a, $2b, $5c, $5d  ; climbing frame 1
    .byte $08, $09, $0a, $0b, $0c, $0d, $5e, $5f  ; frame 2
    .byte $fc, $fc, $08, $09, $58, $59, $5a, $5a  ; crouching
    .byte $08, $09, $28, $29, $2a, $2b, $0e, $0f  ; fireball throwing

; small player table
    .byte $fc, $fc, $fc, $fc, $32, $33, $34, $35  ; walking frame 1
    .byte $fc, $fc, $fc, $fc, $36, $37, $38, $39  ; frame 2
    .byte $fc, $fc, $fc, $fc, $3a, $37, $3b, $3c  ; frame 3
    .byte $fc, $fc, $fc, $fc, $3d, $3e, $3f, $40  ; skidding
    .byte $fc, $fc, $fc, $fc, $32, $41, $42, $43  ; jumping
    .byte $fc, $fc, $fc, $fc, $32, $33, $44, $45  ; swimming frame 1
    .byte $fc, $fc, $fc, $fc, $32, $33, $44, $47  ; frame 2
    .byte $fc, $fc, $fc, $fc, $32, $33, $48, $49  ; frame 3
    .byte $fc, $fc, $fc, $fc, $32, $33, $90, $91  ; climbing frame 1
    .byte $fc, $fc, $fc, $fc, $3a, $37, $92, $93  ; frame 2
    .byte $fc, $fc, $fc, $fc, $9e, $9e, $9f, $9f  ; killed

; used by both player sizes
    .byte $fc, $fc, $fc, $fc, $3a, $37, $4f, $4f  ; small player standing
    .byte $fc, $fc, $00, $01, $4c, $4d, $4e, $4e  ; intermediate grow frame
    .byte $00, $01, $4c, $4d, $4a, $4a, $4b, $4b  ; big player standing

tbl_smb2_main_player_swim_kick_tiles:
    .byte $31, $46

sub_smb2_main_render_player_graphics:
    LDA InjuryTimer  ; if player's injured invincibility timer
    BEQ bra_smb2_main_continue_player_graphics  ; not set, skip checkpoint and continue code
    LDA FrameCounter
    LSR  ; otherwise check frame counter and branch
    BCS bra_smb2_main_exit_player_graphics_handler  ; to leave on every other frame (when d0 is set)
bra_smb2_main_continue_player_graphics:
    LDA GameEngineSubroutine  ; if executing specific game engine routine,
    CMP #$0b  ; branch ahead to some other part
    BEQ bra_smb2_main_draw_killed_player
    LDA PlayerChangeSizeFlag  ; if grow/shrink flag set
    BNE bra_smb2_main_draw_player_size_transition  ; then branch to some other code
    LDY SwimmingFlag  ; if swimming flag set, branch to
    BEQ sub_smb2_main_find_player_action  ; different part, do not return
    LDA Player_State
    CMP #$00  ; if player status normal,
    BEQ sub_smb2_main_find_player_action  ; branch and do not return
    JSR sub_smb2_main_find_player_action  ; otherwise jump and return
    LDA FrameCounter
    AND #%00000100  ; check frame counter for d2 set (8 frames every
    BNE bra_smb2_main_exit_player_graphics_handler  ; eighth frame), and branch if set to leave
    TAX  ; initialize X to zero
    LDY Player_SprDataOffset  ; get player sprite data offset
    LDA PlayerFacingDir  ; get player's facing direction
    LSR
    BCS bra_smb2_main_select_swim_kick_tile  ; if player facing to the right, use current offset
    INY
    INY  ; otherwise move to next OAM data
    INY
    INY
bra_smb2_main_select_swim_kick_tile:
    LDA PlayerSize  ; check player's size
    BEQ bra_smb2_main_store_swim_kick_tile  ; if big, use first tile
    LDA Sprite_Tilenumber+24,y  ; check tile number of seventh/eighth sprite
    CMP SwimTileRepOffset  ; against tile number in player graphics table
    BEQ bra_smb2_main_exit_player_graphics_handler  ; if spr7/spr8 tile number = value, branch to leave
    INX  ; otherwise increment X for second tile
bra_smb2_main_store_swim_kick_tile:
    LDA tbl_smb2_main_player_swim_kick_tiles,x  ; overwrite tile number in sprite 7/8
    STA Sprite_Tilenumber+24,y  ; to animate player's feet when swimming
bra_smb2_main_exit_player_graphics_handler:
    RTS  ; then leave

sub_smb2_main_find_player_action:
    JSR sub_smb2_main_process_player_action  ; find proper offset to graphics table by player's actions
    JMP loc_smb2_main_process_player_graphics  ; draw player, then process for fireball throwing

bra_smb2_main_draw_player_size_transition:
    JSR sub_smb2_main_handle_change_size  ; find proper offset to graphics table for grow/shrink
    JMP loc_smb2_main_process_player_graphics  ; draw player, then process for fireball throwing

bra_smb2_main_draw_killed_player:
    LDY #$0e  ; load offset for player killed
    LDA tbl_smb2_main_player_graphics_frame_offsets,y  ; get offset to graphics table

loc_smb2_main_process_player_graphics:
    STA PlayerGfxOffset  ; store offset to graphics table here
    LDA #$04
    JSR sub_smb2_main_render_player_sub  ; draw player based on offset loaded
    JSR sub_smb2_main_fix_player_sprite_attributes  ; set horizontal flip bits as necessary
    LDA FireballThrowingTimer
    BEQ bra_smb2_main_clip_player_sprites  ; if fireball throw timer not set, skip to the end
    LDY #$00  ; set value to initialize by default
    LDA PlayerAnimTimer  ; get animation frame timer
    CMP FireballThrowingTimer  ; compare to fireball throw timer
    STY FireballThrowingTimer  ; initialize fireball throw timer
    BCS bra_smb2_main_clip_player_sprites  ; if animation frame timer => fireball throw timer skip to end
    STA FireballThrowingTimer  ; otherwise store animation timer into fireball throw timer
    LDY #$07  ; load offset for throwing
    LDA tbl_smb2_main_player_graphics_frame_offsets,y  ; get offset to graphics table
    STA PlayerGfxOffset  ; store it for use later
    LDY #$04  ; set to update four sprite rows by default
    LDA Player_X_Speed
    ORA Left_Right_Buttons  ; check for horizontal speed or left/right button press
    BEQ bra_smb2_main_redraw_player_throwing_frame  ; if no speed or button press, branch using set value in Y
    DEY  ; otherwise set to update only three sprite rows
bra_smb2_main_redraw_player_throwing_frame:
    TYA  ; save in A for use
    JSR sub_smb2_main_render_player_sub  ; in sub, draw player object again

bra_smb2_main_clip_player_sprites:
    LDA Player_OffscreenBits  ; get player's offscreen bits
    LSR
    LSR  ; move vertical bits to low nybble
    LSR
    LSR
    STA $00  ; store here
    LDX #$03  ; check all four rows of player sprites
    LDA Player_SprDataOffset  ; get player's sprite data offset
    CLC
    ADC #$18  ; add 24 bytes to start at bottom row
    TAY  ; set as offset here
bra_smb2_main_clip_player_sprite_rows:
    LDA #$f8  ; load offscreen Y coordinate just in case
    LSR $00  ; shift bit into carry
    BCC bra_smb2_main_advance_player_sprite_row  ; if bit not set, skip, do not move sprites
    JSR sub_smb2_main_fill_two_sprite_fields  ; otherwise dump offscreen Y coordinate into sprite data
bra_smb2_main_advance_player_sprite_row:
    TYA
    SEC  ; subtract eight bytes to do
    SBC #$08  ; next row up
    TAY
    DEX  ; decrement row counter
    BPL bra_smb2_main_clip_player_sprite_rows  ; do this until all sprite rows are checked
    RTS  ; then we are done!

off_smb2_main_intermediate_player_draw_parameters:
    .byte $58, $01, $00, $60, $ff, $04

sub_smb2_main_draw_player_intermediate:
    LDX #$05  ; store data into zero page memory
bra_smb2_main_copy_intermediate_player_draw_parameters:
    LDA off_smb2_main_intermediate_player_draw_parameters,x  ; load data to display player as he always
    STA $02,x  ; appears on world/lives display
    DEX
    BPL bra_smb2_main_copy_intermediate_player_draw_parameters  ; do this until all data is loaded
    LDX #$b8  ; load offset for small standing
    LDY #$04  ; load sprite data offset
    JSR sub_smb2_main_draw_player_loop  ; draw player accordingly
    LDA Sprite_Attributes+36  ; get empty sprite attributes
    ORA #%01000000  ; set horizontal flip bit for bottom-right sprite
    STA Sprite_Attributes+32  ; store and leave
    RTS

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold tile numbers, $00 also used to hold upper extent of animation frames
; $02 - vertical position
; $03 - facing direction, used as horizontal flip control
; $04 - attributes
; $05 - horizontal position
; $07 - number of rows to draw
; these also used in IntermediatePlayerData

sub_smb2_main_render_player_sub:
    STA $07  ; store number of rows of sprites to draw
    LDA Player_Rel_XPos
    STA Player_Pos_ForScroll  ; store player's relative horizontal position
    STA $05  ; store it here also
    LDA Player_Rel_YPos
    STA $02  ; store player's vertical position
    LDA PlayerFacingDir
    STA $03  ; store player's facing direction
    LDA Player_SprAttrib
    STA $04  ; store player's sprite attributes
    LDX PlayerGfxOffset  ; load graphics table offset
    LDY Player_SprDataOffset  ; get player's sprite data offset

sub_smb2_main_draw_player_loop:
    LDA tbl_smb2_main_player_graphics_tiles,x  ; load player's left side
    STA $00
    LDA tbl_smb2_main_player_graphics_tiles+1,x  ; now load right side
    JSR sub_smb2_main_draw_one_sprite_row
    DEC $07  ; decrement rows of sprites to draw
    BNE sub_smb2_main_draw_player_loop  ; do this until all rows are drawn
    RTS

sub_smb2_main_process_player_action:
    LDA Player_State  ; get player's state
    CMP #$03
    BEQ bra_smb2_main_select_climbing_player_frame  ; if climbing, branch here
    CMP #$02
    BEQ bra_smb2_main_select_falling_player_frame  ; if falling, branch here
    CMP #$01
    BNE bra_smb2_main_select_grounded_player_action  ; if not jumping, branch here
    LDA SwimmingFlag
    BNE bra_smb2_main_select_swimming_player_frame  ; if swimming flag set, branch elsewhere
    LDY #$06  ; load offset for crouching
    LDA CrouchingFlag  ; get crouching flag
    BNE bra_smb2_main_select_nonanimated_player_frame  ; if set, branch to get offset for graphics table
    LDY #$00  ; otherwise load offset for jumping
    JMP bra_smb2_main_select_nonanimated_player_frame  ; go to get offset to graphics table

bra_smb2_main_select_grounded_player_action:
    LDY #$06  ; load offset for crouching
    LDA CrouchingFlag  ; get crouching flag
    BNE bra_smb2_main_select_nonanimated_player_frame  ; if set, branch to get offset for graphics table
    LDY #$02  ; load offset for standing
    LDA Player_X_Speed  ; check player's horizontal speed
    ORA Left_Right_Buttons  ; and left/right controller bits
    BEQ bra_smb2_main_select_nonanimated_player_frame  ; if no speed or buttons pressed, use standing offset
    LDA Player_XSpeedAbsolute  ; load walking/running speed
    CMP #$09
    BCC bra_smb2_main_select_walking_player_frame  ; if less than a certain amount, branch, too slow to skid
    LDA Player_MovingDir  ; otherwise check to see if moving direction
    AND PlayerFacingDir  ; and facing direction are the same
    BNE bra_smb2_main_select_walking_player_frame  ; if moving direction = facing direction, branch, don't skid
    LDA GameEngineSubroutine
    CMP #$09  ; if running the change size, fire flower, injure
    BCS bra_smb2_main_skip_skid_sound  ; or death game engine subroutines, skip this
    LDA #$80  ; otherwise play skid sound
    STA NoiseSoundQueue
bra_smb2_main_skip_skid_sound:
    INY  ; increment to skid offset ($03)

bra_smb2_main_select_nonanimated_player_frame:
    JSR sub_smb2_main_get_player_graphics_offset_adder  ; do a sub here to get offset adder for graphics table
    LDA #$00
    STA PlayerAnimCtrl  ; initialize animation frame control
    LDA tbl_smb2_main_player_graphics_frame_offsets,y  ; load offset to graphics table using size as offset
    RTS

bra_smb2_main_select_falling_player_frame:
    LDY #$04  ; load offset for walking/running
    JSR sub_smb2_main_get_player_graphics_offset_adder  ; get offset to graphics table
    JMP sub_smb2_main_get_current_anim_offset  ; execute instructions for falling state

bra_smb2_main_select_walking_player_frame:
    LDY #$04  ; load offset for walking/running
    JSR sub_smb2_main_get_player_graphics_offset_adder  ; get offset to graphics table
    JMP bra_smb2_main_set_four_frame_animation_extent  ; execute instructions for normal state

bra_smb2_main_select_climbing_player_frame:
    LDY #$05  ; load offset for climbing
    LDA Player_Y_Speed  ; check player's vertical speed
    BEQ bra_smb2_main_select_nonanimated_player_frame  ; if no speed, branch, use offset as-is
    JSR sub_smb2_main_get_player_graphics_offset_adder  ; otherwise get offset for graphics table
    JMP loc_smb2_main_set_three_frame_animation_extent  ; then skip ahead to more code

bra_smb2_main_select_swimming_player_frame:
    LDY #$01  ; load offset for swimming
    JSR sub_smb2_main_get_player_graphics_offset_adder
    LDA JumpSwimTimer  ; check jump/swim timer
    ORA PlayerAnimCtrl  ; and animation frame control
    BNE bra_smb2_main_set_four_frame_animation_extent  ; if any one of these set, branch ahead
    LDA A_B_Buttons
    ASL  ; check for A button pressed
    BCS bra_smb2_main_set_four_frame_animation_extent  ; branch to same place if A button pressed

sub_smb2_main_get_current_anim_offset:
    LDA PlayerAnimCtrl  ; get animation frame control
    JMP loc_smb2_main_get_player_animation_graphics_offset  ; jump to get proper offset to graphics table

bra_smb2_main_set_four_frame_animation_extent:
    LDA #$03  ; load upper extent for frame control
    JMP loc_smb2_main_update_player_animation  ; jump to get offset and animate player object

loc_smb2_main_set_three_frame_animation_extent:
    LDA #$02  ; load upper extent for frame control for climbing

loc_smb2_main_update_player_animation:
    STA $00  ; store upper extent here
    JSR sub_smb2_main_get_current_anim_offset  ; get proper offset to graphics table
    PHA  ; save offset to stack
    LDA PlayerAnimTimer  ; load animation frame timer
    BNE bra_smb2_main_return_player_animation_offset  ; branch if not expired
    LDA PlayerAnimTimerSet  ; get animation frame timer amount
    STA PlayerAnimTimer  ; and set timer accordingly
    LDA PlayerAnimCtrl
    CLC  ; add one to animation frame control
    ADC #$01
    CMP $00  ; compare to upper extent
    BCC bra_smb2_main_store_player_animation_frame  ; if frame control + 1 < upper extent, use as next
    LDA #$00  ; otherwise initialize frame control
bra_smb2_main_store_player_animation_frame:
    STA PlayerAnimCtrl  ; store as new animation frame control
bra_smb2_main_return_player_animation_offset:
    PLA  ; get offset to graphics table from stack and leave
    RTS

sub_smb2_main_get_player_graphics_offset_adder:
    LDA PlayerSize  ; get player's size
    BEQ bra_smb2_main_return_player_size_frame_offset  ; if player big, use current offset as-is
    TYA  ; for big player
    CLC  ; otherwise add eight bytes to offset
    ADC #$08  ; for small player
    TAY
bra_smb2_main_return_player_size_frame_offset:
    RTS  ; go back

tbl_smb2_main_player_size_transition_frame_adders:
    .byte $00, $01, $00, $01, $00, $01, $02, $00, $01, $02
    .byte $02, $00, $02, $00, $02, $00, $02, $00, $02, $00

sub_smb2_main_handle_change_size:
    LDY PlayerAnimCtrl  ; get animation frame control
    LDA FrameCounter
    AND #%00000011  ; get frame counter and execute this code every
    BNE bra_smb2_main_select_grow_or_shrink_frame  ; fourth frame, otherwise branch ahead
    INY  ; increment frame control
    CPY #$0a  ; check for preset upper extent
    BCC bra_smb2_main_store_player_size_transition_frame  ; if not there yet, skip ahead to use
    LDY #$00  ; otherwise initialize both grow/shrink flag
    STY PlayerChangeSizeFlag  ; and animation frame control
bra_smb2_main_store_player_size_transition_frame:
    STY PlayerAnimCtrl  ; store proper frame control
bra_smb2_main_select_grow_or_shrink_frame:
    LDA PlayerSize  ; get player's size
    BNE bra_smb2_main_select_shrinking_player_frame  ; if player small, skip ahead to next part
    LDA tbl_smb2_main_player_size_transition_frame_adders,y  ; get offset adder based on frame control as offset
    LDY #$0f  ; load offset for player growing

loc_smb2_main_get_player_animation_graphics_offset:
    ASL  ; multiply animation frame control
    ASL  ; by eight to get proper amount
    ASL  ; to add to our offset
    ADC tbl_smb2_main_player_graphics_frame_offsets,y  ; add to offset to graphics table
    RTS  ; and return with result in A

bra_smb2_main_select_shrinking_player_frame:
    TYA  ; add ten bytes to frame control as offset
    CLC
    ADC #$0a  ; this thing apparently uses two of the swimming frames
    TAX  ; to draw the player shrinking
    LDY #$09  ; load offset for small player swimming
    LDA tbl_smb2_main_player_size_transition_frame_adders,x  ; get what would normally be offset adder
    BNE bra_smb2_main_load_shrinking_player_frame  ; and branch to use offset if nonzero
    LDY #$01  ; otherwise load offset for big player swimming
bra_smb2_main_load_shrinking_player_frame:
    LDA tbl_smb2_main_player_graphics_frame_offsets,y  ; get offset to graphics table based on offset loaded
    RTS  ; and leave

sub_smb2_main_fix_player_sprite_attributes:
    LDY Player_SprDataOffset  ; get sprite data offset
    LDA GameEngineSubroutine
    CMP #$0b  ; if executing specific game engine routine,
    BEQ bra_smb2_main_fix_killed_player_attributes  ; branch to change third and fourth row OAM attributes
    LDA PlayerGfxOffset  ; get graphics table offset
    CMP #$50
    BEQ bra_smb2_main_fix_player_bottom_row_attributes  ; if crouch offset, either standing offset,
    CMP #$b8  ; or intermediate growing offset,
    BEQ bra_smb2_main_fix_player_bottom_row_attributes  ; go ahead and execute code to change
    CMP #$c0  ; fourth row OAM attributes only
    BEQ bra_smb2_main_fix_player_bottom_row_attributes
    CMP #$c8
    BNE bra_smb2_main_exit_player_attribute_fixup  ; if none of these, branch to leave
bra_smb2_main_fix_killed_player_attributes:
    LDA Sprite_Attributes+16,y
    AND #%00111111  ; mask out horizontal and vertical flip bits
    STA Sprite_Attributes+16,y  ; for third row sprites and save
    LDA Sprite_Attributes+20,y
    AND #%00111111
    ORA #%01000000  ; set horizontal flip bit for second
    STA Sprite_Attributes+20,y  ; sprite in the third row
bra_smb2_main_fix_player_bottom_row_attributes:
    LDA Sprite_Attributes+24,y
    AND #%00111111  ; mask out horizontal and vertical flip bits
    STA Sprite_Attributes+24,y  ; for fourth row sprites and save
    LDA Sprite_Attributes+28,y
    AND #%00111111
    ORA #%01000000  ; set horizontal flip bit for second
    STA Sprite_Attributes+28,y  ; sprite in the fourth row
bra_smb2_main_exit_player_attribute_fixup:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00 - used in adding to get proper offset
