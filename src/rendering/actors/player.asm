; -------------------------------------------------------------------------------------
; $00 - used to store player's vertical offscreen bits

PlayerGfxTblOffsets:
    .byte $20, $28, $c8, $18, $00, $40, $50, $58
    .byte $80, $88, $b8, $78, $60, $a0, $b0, $b8

; tiles arranged in order, 2 tiles per row, top to bottom

PlayerGraphicsTable:
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

SwimKickTileNum:
    .byte $31, $46

PlayerGfxHandler:
    LDA ram_injury_timer  ; if player's injured invincibility timer
    BEQ CntPl  ; not set, skip checkpoint and continue code
    LDA ram_frame_counter
    LSR  ; otherwise check frame counter and branch
    BCS ExPGH  ; to leave on every other frame (when d0 is set)
CntPl:
    LDA ram_game_engine_subroutine  ; if executing specific game engine routine,
    CMP #$0b  ; branch ahead to some other part
    BEQ PlayerKilled
    LDA ram_player_change_size_flag  ; if grow/shrink flag set
    BNE DoChangeSize  ; then branch to some other code
    LDY ram_swimming_flag  ; if swimming flag set, branch to
    BEQ FindPlayerAction  ; different part, do not return
    LDA ram_player_state
    CMP #$00  ; if player status normal,
    BEQ FindPlayerAction  ; branch and do not return
    JSR FindPlayerAction  ; otherwise jump and return
    LDA ram_frame_counter
    AND #%00000100  ; check frame counter for d2 set (8 frames every
    BNE ExPGH  ; eighth frame), and branch if set to leave
    TAX  ; initialize X to zero
    LDY ram_player_spr_data_offset  ; get player sprite data offset
    LDA ram_player_facing_dir  ; get player's facing direction
    LSR
    BCS SwimKT  ; if player facing to the right, use current offset
    INY
    INY  ; otherwise move to next OAM data
    INY
    INY
SwimKT:
    LDA ram_player_size  ; check player's size
    BEQ BigKTS  ; if big, use first tile
    LDA ram_sprite_tilenumber+24,y  ; check tile number of seventh/eighth sprite
    CMP con_swim_tile_replacement_offset  ; against tile number in player graphics table
    BEQ ExPGH  ; if spr7/spr8 tile number = value, branch to leave
    INX  ; otherwise increment X for second tile
BigKTS:
    LDA SwimKickTileNum,x  ; overwrite tile number in sprite 7/8
    STA ram_sprite_tilenumber+24,y  ; to animate player's feet when swimming
ExPGH:
    RTS  ; then leave

FindPlayerAction:
    JSR ProcessPlayerAction  ; find proper offset to graphics table by player's actions
    JMP PlayerGfxProcessing  ; draw player, then process for fireball throwing

DoChangeSize:
    JSR HandleChangeSize  ; find proper offset to graphics table for grow/shrink
    JMP PlayerGfxProcessing  ; draw player, then process for fireball throwing

PlayerKilled:
    LDY #$0e  ; load offset for player killed
    LDA PlayerGfxTblOffsets,y  ; get offset to graphics table

PlayerGfxProcessing:
    STA ram_player_gfx_offset  ; store offset to graphics table here
    LDA #$04
    JSR RenderPlayerSub  ; draw player based on offset loaded
    JSR ChkForPlayerAttrib  ; set horizontal flip bits as necessary
    LDA ram_fireball_throwing_timer
    BEQ PlayerOffscreenChk  ; if fireball throw timer not set, skip to the end
    LDY #$00  ; set value to initialize by default
    LDA ram_player_anim_timer  ; get animation frame timer
    CMP ram_fireball_throwing_timer  ; compare to fireball throw timer
    STY ram_fireball_throwing_timer  ; initialize fireball throw timer
    BCS PlayerOffscreenChk  ; if animation frame timer => fireball throw timer skip to end
    STA ram_fireball_throwing_timer  ; otherwise store animation timer into fireball throw timer
    LDY #$07  ; load offset for throwing
    LDA PlayerGfxTblOffsets,y  ; get offset to graphics table
    STA ram_player_gfx_offset  ; store it for use later
    LDY #$04  ; set to update four sprite rows by default
    LDA ram_player_x_speed
    ORA ram_left_right_buttons  ; check for horizontal speed or left/right button press
    BEQ SUpdR  ; if no speed or button press, branch using set value in Y
    DEY  ; otherwise set to update only three sprite rows
SUpdR:
    TYA  ; save in A for use
    JSR RenderPlayerSub  ; in sub, draw player object again

PlayerOffscreenChk:
    LDA ram_player_offscreen_bits  ; get player's offscreen bits
    LSR
    LSR  ; move vertical bits to low nybble
    LSR
    LSR
    STA $00  ; store here
    LDX #$03  ; check all four rows of player sprites
    LDA ram_player_spr_data_offset  ; get player's sprite data offset
    CLC
    ADC #$18  ; add 24 bytes to start at bottom row
    TAY  ; set as offset here
PROfsLoop:
    LDA #$f8  ; load offscreen Y coordinate just in case
    LSR $00  ; shift bit into carry
    BCC NPROffscr  ; if bit not set, skip, do not move sprites
    JSR DumpTwoSpr  ; otherwise dump offscreen Y coordinate into sprite data
NPROffscr:
    TYA
    SEC  ; subtract eight bytes to do
    SBC #$08  ; next row up
    TAY
    DEX  ; decrement row counter
    BPL PROfsLoop  ; do this until all sprite rows are checked
    RTS  ; then we are done!

; -------------------------------------------------------------------------------------

IntermediatePlayerData:
    .byte $58, $01, $00, $60, $ff, $04

DrawPlayer_Intermediate:
    LDX #$05  ; store data into zero page memory
PIntLoop:
    LDA IntermediatePlayerData,x  ; load data to display player as he always
    STA $02,x  ; appears on world/lives display
    DEX
    BPL PIntLoop  ; do this until all data is loaded
    LDX #$b8  ; load offset for small standing
    LDY #$04  ; load sprite data offset
    JSR DrawPlayerLoop  ; draw player accordingly
    LDA ram_sprite_attributes+36  ; get empty sprite attributes
    ORA #%01000000  ; set horizontal flip bit for bottom-right sprite
    STA ram_sprite_attributes+32  ; store and leave
    RTS

; -------------------------------------------------------------------------------------
; $00-$01 - used to hold tile numbers, $00 also used to hold upper extent of animation frames
; $02 - vertical position
; $03 - facing direction, used as horizontal flip control
; $04 - attributes
; $05 - horizontal position
; $07 - number of rows to draw
; these also used in IntermediatePlayerData

RenderPlayerSub:
    STA $07  ; store number of rows of sprites to draw
    LDA ram_player_rel_x_pos
    STA ram_player_pos_for_scroll  ; store player's relative horizontal position
    STA $05  ; store it here also
    LDA ram_player_rel_y_pos
    STA $02  ; store player's vertical position
    LDA ram_player_facing_dir
    STA $03  ; store player's facing direction
    LDA ram_player_spr_attrib
    STA $04  ; store player's sprite attributes
    LDX ram_player_gfx_offset  ; load graphics table offset
    LDY ram_player_spr_data_offset  ; get player's sprite data offset

DrawPlayerLoop:
    LDA PlayerGraphicsTable,x  ; load player's left side
    STA $00
    LDA PlayerGraphicsTable+1,x  ; now load right side
    JSR DrawOneSpriteRow
    DEC $07  ; decrement rows of sprites to draw
    BNE DrawPlayerLoop  ; do this until all rows are drawn
    RTS

ProcessPlayerAction:
    LDA ram_player_state  ; get player's state
    CMP #$03
    BEQ ActionClimbing  ; if climbing, branch here
    CMP #$02
    BEQ ActionFalling  ; if falling, branch here
    CMP #$01
    BNE ProcOnGroundActs  ; if not jumping, branch here
    LDA ram_swimming_flag
    BNE ActionSwimming  ; if swimming flag set, branch elsewhere
    LDY #$06  ; load offset for crouching
    LDA ram_crouching_flag  ; get crouching flag
    BNE NonAnimatedActs  ; if set, branch to get offset for graphics table
    LDY #$00  ; otherwise load offset for jumping
    JMP NonAnimatedActs  ; go to get offset to graphics table

ProcOnGroundActs:
    LDY #$06  ; load offset for crouching
    LDA ram_crouching_flag  ; get crouching flag
    BNE NonAnimatedActs  ; if set, branch to get offset for graphics table
    LDY #$02  ; load offset for standing
    LDA ram_player_x_speed  ; check player's horizontal speed
    ORA ram_left_right_buttons  ; and left/right controller bits
    BEQ NonAnimatedActs  ; if no speed or buttons pressed, use standing offset
    LDA ram_player_x_speed_absolute  ; load walking/running speed
    CMP #$09
    BCC ActionWalkRun  ; if less than a certain amount, branch, too slow to skid
    LDA ram_player_moving_dir  ; otherwise check to see if moving direction
    AND ram_player_facing_dir  ; and facing direction are the same
    BNE ActionWalkRun  ; if moving direction = facing direction, branch, don't skid
    INY  ; otherwise increment to skid offset ($03)

NonAnimatedActs:
    JSR GetGfxOffsetAdder  ; do a sub here to get offset adder for graphics table
    LDA #$00
    STA ram_player_anim_ctrl  ; initialize animation frame control
    LDA PlayerGfxTblOffsets,y  ; load offset to graphics table using size as offset
    RTS

ActionFalling:
    LDY #$04  ; load offset for walking/running
    JSR GetGfxOffsetAdder  ; get offset to graphics table
    JMP GetCurrentAnimOffset  ; execute instructions for falling state

ActionWalkRun:
    LDY #$04  ; load offset for walking/running
    JSR GetGfxOffsetAdder  ; get offset to graphics table
    JMP FourFrameExtent  ; execute instructions for normal state

ActionClimbing:
    LDY #$05  ; load offset for climbing
    LDA ram_player_y_speed  ; check player's vertical speed
    BEQ NonAnimatedActs  ; if no speed, branch, use offset as-is
    JSR GetGfxOffsetAdder  ; otherwise get offset for graphics table
    JMP ThreeFrameExtent  ; then skip ahead to more code

ActionSwimming:
    LDY #$01  ; load offset for swimming
    JSR GetGfxOffsetAdder
    LDA ram_jump_swim_timer  ; check jump/swim timer
    ORA ram_player_anim_ctrl  ; and animation frame control
    BNE FourFrameExtent  ; if any one of these set, branch ahead
    LDA ram_a_b_buttons
    ASL  ; check for A button pressed
    BCS FourFrameExtent  ; branch to same place if A button pressed

GetCurrentAnimOffset:
    LDA ram_player_anim_ctrl  ; get animation frame control
    JMP GetOffsetFromAnimCtrl  ; jump to get proper offset to graphics table

FourFrameExtent:
    LDA #$03  ; load upper extent for frame control
    JMP AnimationControl  ; jump to get offset and animate player object

ThreeFrameExtent:
    LDA #$02  ; load upper extent for frame control for climbing

AnimationControl:
    STA $00  ; store upper extent here
    JSR GetCurrentAnimOffset  ; get proper offset to graphics table
    PHA  ; save offset to stack
    LDA ram_player_anim_timer  ; load animation frame timer
    BNE ExAnimC  ; branch if not expired
    LDA ram_player_anim_timer_set  ; get animation frame timer amount
    STA ram_player_anim_timer  ; and set timer accordingly
    LDA ram_player_anim_ctrl
    CLC  ; add one to animation frame control
    ADC #$01
    CMP $00  ; compare to upper extent
    BCC SetAnimC  ; if frame control + 1 < upper extent, use as next
    LDA #$00  ; otherwise initialize frame control
SetAnimC:
    STA ram_player_anim_ctrl  ; store as new animation frame control
ExAnimC:
    PLA  ; get offset to graphics table from stack and leave
    RTS

GetGfxOffsetAdder:
    LDA ram_player_size  ; get player's size
    BEQ SzOfs  ; if player big, use current offset as-is
    TYA  ; for big player
    CLC  ; otherwise add eight bytes to offset
    ADC #$08  ; for small player
    TAY
SzOfs:
    RTS  ; go back

ChangeSizeOffsetAdder:
    .byte $00, $01, $00, $01, $00, $01, $02, $00, $01, $02
    .byte $02, $00, $02, $00, $02, $00, $02, $00, $02, $00

HandleChangeSize:
    LDY ram_player_anim_ctrl  ; get animation frame control
    LDA ram_frame_counter
    AND #%00000011  ; get frame counter and execute this code every
    BNE GorSLog  ; fourth frame, otherwise branch ahead
    INY  ; increment frame control
    CPY #$0a  ; check for preset upper extent
    BCC CSzNext  ; if not there yet, skip ahead to use
    LDY #$00  ; otherwise initialize both grow/shrink flag
    STY ram_player_change_size_flag  ; and animation frame control
CSzNext:
    STY ram_player_anim_ctrl  ; store proper frame control
GorSLog:
    LDA ram_player_size  ; get player's size
    BNE ShrinkPlayer  ; if player small, skip ahead to next part
    LDA ChangeSizeOffsetAdder,y  ; get offset adder based on frame control as offset
    LDY #$0f  ; load offset for player growing

GetOffsetFromAnimCtrl:
    ASL  ; multiply animation frame control
    ASL  ; by eight to get proper amount
    ASL  ; to add to our offset
    ADC PlayerGfxTblOffsets,y  ; add to offset to graphics table
    RTS  ; and return with result in A

ShrinkPlayer:
    TYA  ; add ten bytes to frame control as offset
    CLC
    ADC #$0a  ; this thing apparently uses two of the swimming frames
    TAX  ; to draw the player shrinking
    LDY #$09  ; load offset for small player swimming
    LDA ChangeSizeOffsetAdder,x  ; get what would normally be offset adder
    BNE ShrPlF  ; and branch to use offset if nonzero
    LDY #$01  ; otherwise load offset for big player swimming
ShrPlF:
    LDA PlayerGfxTblOffsets,y  ; get offset to graphics table based on offset loaded
    RTS  ; and leave

ChkForPlayerAttrib:
    LDY ram_player_spr_data_offset  ; get sprite data offset
    LDA ram_game_engine_subroutine
    CMP #$0b  ; if executing specific game engine routine,
    BEQ KilledAtt  ; branch to change third and fourth row OAM attributes
    LDA ram_player_gfx_offset  ; get graphics table offset
    CMP #$50
    BEQ C_S_IGAtt  ; if crouch offset, either standing offset,
    CMP #$b8  ; or intermediate growing offset,
    BEQ C_S_IGAtt  ; go ahead and execute code to change
    CMP #$c0  ; fourth row OAM attributes only
    BEQ C_S_IGAtt
    CMP #$c8
    BNE ExPlyrAt  ; if none of these, branch to leave
KilledAtt:
    LDA ram_sprite_attributes+16,y
    AND #%00111111  ; mask out horizontal and vertical flip bits
    STA ram_sprite_attributes+16,y  ; for third row sprites and save
    LDA ram_sprite_attributes+20,y
    AND #%00111111
    ORA #%01000000  ; set horizontal flip bit for second
    STA ram_sprite_attributes+20,y  ; sprite in the third row
C_S_IGAtt:
    LDA ram_sprite_attributes+24,y
    AND #%00111111  ; mask out horizontal and vertical flip bits
    STA ram_sprite_attributes+24,y  ; for fourth row sprites and save
    LDA ram_sprite_attributes+28,y
    AND #%00111111
    ORA #%01000000  ; set horizontal flip bit for second
    STA ram_sprite_attributes+28,y  ; sprite in the fourth row
ExPlyrAt:
    RTS  ; leave
