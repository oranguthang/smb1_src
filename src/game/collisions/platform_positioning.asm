; -------------------------------------------------------------------------------------

tbl_small_platform_player_y_offsets:
    .byte $80, $00

sub_position_player_on_small_platform:
    TAY  ; use bounding box counter saved in collision flag
    LDA ram_enemy_y_position,x  ; for offset
    CLC  ; add positioning data using offset to the vertical
    ADC tbl_small_platform_player_y_offsets-1,y  ; coordinate
.if con_revision_profile = con_revision_profile_vs
    JMP :+
.else
    .byte $2c  ; BIT instruction opcode
.endif

sub_position_player_on_vertical_platform:
    LDA ram_enemy_y_position,x  ; get vertical coordinate
.if con_revision_profile = con_revision_profile_vs
    :
.endif
    LDY ram_game_engine_subroutine
    CPY #$0b  ; if certain routine being executed on this frame,
    BEQ bra_exit_player_platform_position  ; skip all of this
    LDY ram_enemy_y_high_pos,x
    CPY #$01  ; if vertical high byte offscreen, skip this
    BNE bra_exit_player_platform_position
    SEC  ; subtract 32 pixels from vertical coordinate
    SBC #$20  ; for the player object's height
    STA ram_player_y_position  ; save as player's new vertical coordinate
    TYA
    SBC #$00  ; subtract borrow and store as player's
    STA ram_player_y_high_pos  ; new vertical high byte
    LDA #$00
    STA ram_player_y_speed  ; initialize vertical speed and low byte of force
    STA ram_player_y_speed_fraction  ; and then leave
bra_exit_player_platform_position:
    RTS

; -------------------------------------------------------------------------------------

sub_check_player_vertical:
    LDA ram_player_offscreen_bits  ; if player object is completely offscreen
.if con_revision_profile = con_revision_profile_ann
    AND #%11110000
    CLC
    BEQ bra_exit_vertical_platform_player_position
    SEC
.else
    CMP #$f0  ; vertically, leave this routine
    BCS bra_exit_vertical_platform_player_position
    LDY ram_player_y_high_pos  ; if player high vertical byte is not
    DEY  ; within the screen, leave this routine
    BNE bra_exit_vertical_platform_player_position
    LDA ram_player_y_position  ; if on the screen, check to see how far down
    CMP #$d0  ; the player is vertically
.endif
bra_exit_vertical_platform_player_position:
    RTS

; -------------------------------------------------------------------------------------

sub_get_enemy_bounding_box_offset:
    LDA ram_object_offset  ; get enemy object buffer offset

sub_get_enemy_bounding_box_offset_from_x:
    ASL  ; multiply A by four, then add four
    ASL  ; to skip player's bounding box
    CLC
    ADC #$04
    TAY  ; send to Y
    LDA ram_enemy_offscreen_bits  ; get offscreen bits for enemy object
    AND #%00001111  ; save low nybble
    CMP #%00001111  ; check for all bits set
    RTS
