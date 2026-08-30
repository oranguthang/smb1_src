sub_smb2_main_move_jumping_enemy:
    JSR sub_smb2_main_move_enemy_with_gravity  ; do a sub to impose gravity on green paratroopa
    JMP sub_smb2_main_move_enemy_horizontally  ; jump to move enemy horizontally

; --------------------------------

handler_smb2_main_move_red_paratroopa:
    LDA Enemy_Y_Speed,x
    ORA Enemy_Y_MoveForce,x  ; check for any vertical force or speed
    BNE bra_smb2_main_select_red_paratroopa_vertical_direction  ; branch if any found
    STA Enemy_YMF_Dummy,x  ; initialize something here
    LDA Enemy_Y_Position,x  ; check current vs. original vertical coordinate
    CMP RedPTroopaOrigXPos,x
    BCS bra_smb2_main_select_red_paratroopa_vertical_direction  ; if current => original, skip ahead to more code
    LDA FrameCounter  ; get frame counter
    AND #%00000111  ; mask out all but 3 LSB
    BNE bra_smb2_main_exit_red_paratroopa_idle_correction  ; if any bits set, branch to leave
    INC Enemy_Y_Position,x  ; otherwise increment red paratroopa's vertical position
bra_smb2_main_exit_red_paratroopa_idle_correction:
    RTS  ; leave

bra_smb2_main_select_red_paratroopa_vertical_direction:
    LDA Enemy_Y_Position,x  ; check current vs. central vertical coordinate
    CMP RedPTroopaCenterYPos,x
    BCC bra_smb2_main_move_red_paratroopa_down  ; if current < central, jump to move downwards
    JMP loc_smb2_main_move_red_paratroopa_up  ; otherwise jump to move upwards
bra_smb2_main_move_red_paratroopa_down:
    JMP loc_smb2_main_move_red_paratroopa_down  ; move downwards

; --------------------------------
; $00 - used to store adder for movement, also used as adder for platform
; $01 - used to store maximum value for secondary counter

handler_smb2_main_move_flying_green_paratroopa:
    JSR sub_smb2_main_update_green_paratroopa_x_movement_counters  ; do sub to increment primary and secondary counters
    JSR sub_smb2_main_move_with_x_movement_counters  ; do sub to move green paratroopa accordingly, and horizontally
    LDY #$01  ; set Y to move green paratroopa down
    LDA FrameCounter
    AND #%00000011  ; check frame counter 2 LSB for any bits set
    BNE bra_smb2_main_exit_green_paratroopa_movement  ; branch to leave if set to move up/down every fourth frame
    LDA FrameCounter
    AND #%01000000  ; check frame counter for d6 set
    BNE bra_smb2_main_apply_green_paratroopa_y_sway  ; branch to move green paratroopa down if set
    LDY #$ff  ; otherwise set Y to move green paratroopa up
bra_smb2_main_apply_green_paratroopa_y_sway:
    STY $00  ; store adder here
    LDA Enemy_Y_Position,x
    CLC  ; add or subtract from vertical position
    ADC $00  ; to give green paratroopa a wavy flight
    STA Enemy_Y_Position,x
bra_smb2_main_exit_green_paratroopa_movement:
    RTS  ; leave!

sub_smb2_main_update_green_paratroopa_x_movement_counters:
    LDA #$13  ; load preset maximum value for secondary counter

sub_smb2_main_update_platform_x_movement_counters:
    STA $01  ; store value here
    LDA FrameCounter
    AND #%00000011  ; branch to leave if not on
    BNE bra_smb2_main_exit_x_movement_counter_update  ; every fourth frame
    LDY XMoveSecondaryCounter,x  ; get secondary counter
    LDA XMovePrimaryCounter,x  ; get primary counter
    LSR
    BCS bra_smb2_main_decrement_x_movement_amplitude  ; if d0 of primary counter set, branch elsewhere
    CPY $01  ; compare secondary counter to preset maximum value
    BEQ bra_smb2_main_advance_x_movement_phase  ; if equal, branch ahead of this part
    INC XMoveSecondaryCounter,x  ; increment secondary counter and leave
bra_smb2_main_exit_x_movement_counter_update:
    RTS
bra_smb2_main_advance_x_movement_phase:
    INC XMovePrimaryCounter,x  ; increment primary counter and leave
    RTS
bra_smb2_main_decrement_x_movement_amplitude:
    TYA  ; put secondary counter in A
    BEQ bra_smb2_main_advance_x_movement_phase  ; if secondary counter at zero, branch back
    DEC XMoveSecondaryCounter,x  ; otherwise decrement secondary counter and leave
    RTS

sub_smb2_main_move_with_x_movement_counters:
    LDA XMoveSecondaryCounter,x  ; save secondary counter to stack
    PHA
    LDY #$01  ; set value here by default
    LDA XMovePrimaryCounter,x
    AND #%00000010  ; if d1 of primary counter is
    BNE bra_smb2_main_move_counter_driven_object_right  ; set, branch ahead of this part here
    LDA XMoveSecondaryCounter,x
    EOR #$ff  ; otherwise change secondary
    CLC  ; counter to two's compliment
    ADC #$01
    STA XMoveSecondaryCounter,x
    LDY #$02  ; load alternate value here
bra_smb2_main_move_counter_driven_object_right:
    STY Enemy_MovingDir,x  ; store as moving direction
    JSR sub_smb2_main_move_enemy_horizontally
    STA $00  ; save value obtained from sub here
    PLA  ; get secondary counter from stack
    STA XMoveSecondaryCounter,x  ; and return to original place
    RTS

; --------------------------------

tbl_smb2_main_blooper_random_masks_by_hard_mode:
    .byte %00111111, %00000011

handler_smb2_main_move_blooper:
    LDA Enemy_State,x
    AND #%00100000  ; check enemy state for d5 set
    BNE bra_smb2_main_move_defeated_blooper  ; branch if set to move defeated bloober
    LDY SecondaryHardMode  ; use secondary hard mode flag as offset
    LDA PseudoRandomBitReg+1,x  ; get LSFR
    AND tbl_smb2_main_blooper_random_masks_by_hard_mode,y  ; mask out bits in LSFR using bitmask loaded with offset
    BNE bra_smb2_main_update_blooper_swim  ; if any bits set, skip ahead to make swim
    TXA
    LSR  ; check to see if on second or fourth slot (1 or 3)
    BCC bra_smb2_main_face_blooper_toward_player  ; if not, branch to figure out moving direction
    LDY Player_MovingDir  ; otherwise, load player's moving direction and
    BCS bra_smb2_main_store_blooper_moving_direction  ; do an unconditional branch to set
bra_smb2_main_face_blooper_toward_player:
    LDY #$02  ; set left moving direction by default
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between player and bloober
    BPL bra_smb2_main_store_blooper_moving_direction  ; if enemy to the right of player, keep left
    DEY  ; otherwise decrement to set right moving direction
bra_smb2_main_store_blooper_moving_direction:
    STY Enemy_MovingDir,x  ; set moving direction of bloober, then continue on here

bra_smb2_main_update_blooper_swim:
    JSR sub_smb2_main_process_blooper_swim  ; execute sub to make bloober swim characteristically
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    SEC
    SBC Enemy_Y_MoveForce,x  ; subtract movement force
    CMP #$20  ; check to see if position is above edge of status bar
    BCC bra_smb2_main_move_blooper_horizontally  ; if so, don't do it
    STA Enemy_Y_Position,x  ; otherwise, set new vertical position, make bloober swim
bra_smb2_main_move_blooper_horizontally:
    LDY Enemy_MovingDir,x  ; check moving direction
    DEY
    BNE bra_smb2_main_move_blooper_left  ; if moving to the left, branch to second part
    LDA Enemy_X_Position,x
    CLC  ; add movement speed to horizontal coordinate
    ADC BlooperMoveSpeed,x
    STA Enemy_X_Position,x  ; store result as new horizontal coordinate
    LDA Enemy_PageLoc,x
    ADC #$00  ; add carry to page location
    STA Enemy_PageLoc,x  ; store as new page location and leave
    RTS

bra_smb2_main_move_blooper_left:
    LDA Enemy_X_Position,x
    SEC  ; subtract movement speed from horizontal coordinate
    SBC BlooperMoveSpeed,x
    STA Enemy_X_Position,x  ; store result as new horizontal coordinate
    LDA Enemy_PageLoc,x
    SBC #$00  ; subtract borrow from page location
    STA Enemy_PageLoc,x  ; store as new page location and leave
    RTS

bra_smb2_main_move_defeated_blooper:
    JMP sub_smb2_main_move_enemy_downward_slow  ; jump to move defeated bloober downwards

sub_smb2_main_process_blooper_swim:
    LDA BlooperMoveCounter,x  ; get enemy's movement counter
    AND #%00000010  ; check for d1 set
    BNE bra_smb2_main_check_blooper_float_down  ; branch if set
    LDA FrameCounter
    AND #%00000111  ; get 3 LSB of frame counter
    PHA  ; and save it to the stack
    LDA BlooperMoveCounter,x  ; get enemy's movement counter
    LSR  ; check for d0 set
    BCS bra_smb2_main_slow_blooper_swim  ; branch if set
    PLA  ; pull 3 LSB of frame counter from the stack
    BNE bra_smb2_main_exit_blooper_swim_phase  ; branch to leave, execute code only every eighth frame
    LDA Enemy_Y_MoveForce,x
    CLC  ; add to movement force to speed up swim
    ADC #$01
    STA Enemy_Y_MoveForce,x  ; set movement force
    STA BlooperMoveSpeed,x  ; set as movement speed
    CMP #$02
    BNE bra_smb2_main_exit_blooper_swim_phase  ; if certain horizontal speed, branch to leave
    INC BlooperMoveCounter,x  ; otherwise increment movement counter
bra_smb2_main_exit_blooper_swim_phase:
    RTS

bra_smb2_main_slow_blooper_swim:
    PLA  ; pull 3 LSB of frame counter from the stack
    BNE bra_smb2_main_exit_blooper_slowdown  ; branch to leave, execute code only every eighth frame
    LDA Enemy_Y_MoveForce,x
    SEC  ; subtract from movement force to slow swim
    SBC #$01
    STA Enemy_Y_MoveForce,x  ; set movement force
    STA BlooperMoveSpeed,x  ; set as movement speed
    BNE bra_smb2_main_exit_blooper_slowdown  ; if any speed, branch to leave
    INC BlooperMoveCounter,x  ; otherwise increment movement counter
    LDA #$02
    STA EnemyIntervalTimer,x  ; set enemy's timer
bra_smb2_main_exit_blooper_slowdown:
    RTS  ; leave

bra_smb2_main_check_blooper_float_down:
    LDA EnemyIntervalTimer,x  ; get enemy timer
    BEQ bra_smb2_main_check_blooper_near_player_y  ; branch if expired

bra_smb2_main_float_blooper_down:
    LDA FrameCounter  ; get frame counter
    LSR  ; check for d0 set
    BCS bra_smb2_main_exit_blooper_float_down  ; branch to leave on every other frame
    INC Enemy_Y_Position,x  ; otherwise increment vertical coordinate
bra_smb2_main_exit_blooper_float_down:
    RTS  ; leave

bra_smb2_main_check_blooper_near_player_y:
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    ADC #$10  ; add sixteen pixels
    CMP Player_Y_Position  ; compare result with player's vertical coordinate
    BCC bra_smb2_main_float_blooper_down  ; if modified vertical less than player's, branch
    LDA #$00
    STA BlooperMoveCounter,x  ; otherwise nullify movement counter
    RTS

; --------------------------------

handler_smb2_main_move_frenzy_bullet_bill:
    LDA Enemy_State,x  ; check bullet bill's enemy object state for d5 set
    AND #%00100000
    BEQ bra_smb2_main_move_active_frenzy_bullet_bill  ; if not set, continue with movement code
    JMP sub_smb2_main_move_enemy_with_gravity  ; otherwise jump to move defeated bullet bill downwards
bra_smb2_main_move_active_frenzy_bullet_bill:
    LDA #$e8  ; set bullet bill's horizontal speed
    STA Enemy_X_Speed,x  ; and move it accordingly (note: this bullet bill
    JMP sub_smb2_main_move_enemy_horizontally  ; object occurs in frenzy object $17, not from cannons)

; --------------------------------
; $02 - used to hold preset values
; $03 - used to hold enemy state

off_smb2_main_swimming_cheep_cheep_x_forces:
    .byte $40, $80
    .byte $04, $04  ; residual data, not used

handler_smb2_main_move_swimming_cheep_cheep:
    LDA Enemy_State,x  ; check cheep-cheep's enemy object state
    AND #%00100000  ; for d5 set
    BEQ bra_smb2_main_move_active_swimming_cheep_cheep  ; if not set, continue with movement code
    JMP sub_smb2_main_move_enemy_downward_slow  ; otherwise jump to move defeated cheep-cheep downwards
bra_smb2_main_move_active_swimming_cheep_cheep:
    STA $03  ; save enemy state in $03
    LDA Enemy_ID,x  ; get enemy identifier
    SEC
    SBC #$0a  ; subtract ten for cheep-cheep identifiers
    TAY  ; use as offset
    LDA off_smb2_main_swimming_cheep_cheep_x_forces,y  ; load value here
    STA $02
    LDA Enemy_X_MoveForce,x  ; load horizontal force
    SEC
    SBC $02  ; subtract preset value from horizontal force
    STA Enemy_X_MoveForce,x  ; store as new horizontal force
    LDA Enemy_X_Position,x  ; get horizontal coordinate
    SBC #$00  ; subtract borrow (thus moving it slowly)
    STA Enemy_X_Position,x  ; and save as new horizontal coordinate
    LDA Enemy_PageLoc,x
    SBC #$00  ; subtract borrow again, this time from the
    STA Enemy_PageLoc,x  ; page location, then save
    LDA #$40
    STA $02  ; save new value here
    CPX #$02  ; check enemy object offset
    BCC bra_smb2_main_exit_swimming_cheep_cheep_movement  ; if in first or second slot, branch to leave
    LDA CheepCheepMoveMFlag,x  ; check movement flag
    CMP #$10  ; if movement speed set to $00,
    BCC bra_smb2_main_move_swimming_cheep_cheep_up  ; branch to move upwards
    LDA Enemy_YMF_Dummy,x
    CLC
    ADC $02  ; add preset value to dummy variable to get carry
    STA Enemy_YMF_Dummy,x  ; and save dummy
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    ADC $03  ; add carry to it plus enemy state to slowly move it downwards
    STA Enemy_Y_Position,x  ; save as new vertical coordinate
    LDA Enemy_Y_HighPos,x
    ADC #$00  ; add carry to page location and
    JMP loc_smb2_main_check_swimming_cheep_cheep_y_range  ; jump to end of movement code

bra_smb2_main_move_swimming_cheep_cheep_up:
    LDA Enemy_YMF_Dummy,x
    SEC
    SBC $02  ; subtract preset value to dummy variable to get borrow
    STA Enemy_YMF_Dummy,x  ; and save dummy
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    SBC $03  ; subtract borrow to it plus enemy state to slowly move it upwards
    STA Enemy_Y_Position,x  ; save as new vertical coordinate
    LDA Enemy_Y_HighPos,x
    SBC #$00  ; subtract borrow from page location

loc_smb2_main_check_swimming_cheep_cheep_y_range:
    STA Enemy_Y_HighPos,x  ; save new page location here
    LDY #$00  ; load movement speed to upwards by default
    LDA Enemy_Y_Position,x  ; get vertical coordinate
    SEC
    SBC CheepCheepOrigYPos,x  ; subtract original coordinate from current
    BPL bra_smb2_main_check_swimming_cheep_cheep_y_distance  ; if result positive, skip to next part
    LDY #$10  ; otherwise load movement speed to downwards
    EOR #$ff
    CLC  ; get two's compliment of result
    ADC #$01  ; to obtain total difference of original vs. current
bra_smb2_main_check_swimming_cheep_cheep_y_distance:
    CMP #$0f  ; if difference between original vs. current vertical
    BCC bra_smb2_main_exit_swimming_cheep_cheep_movement  ; coordinates < 15 pixels, leave movement speed alone
    TYA
    STA CheepCheepMoveMFlag,x  ; otherwise change movement speed
bra_smb2_main_exit_swimming_cheep_cheep_movement:
    RTS  ; leave

; --------------------------------
; $00 - used as counter for firebar parts
; $01 - used for oscillated high byte of spin state or to hold horizontal adder
; $02 - used for oscillated high byte of spin state or to hold vertical adder
; $03 - used for mirror data
; $04 - used to store player's sprite 1 X coordinate
; $05 - used to evaluate mirror data
; $06 - used to store either screen X coordinate or sprite data offset
; $07 - used to store screen Y coordinate
; $ed - used to hold maximum length of firebar
; $ef - used to hold high byte of spinstate

; horizontal adder is at first byte + high byte of spinstate,
; vertical adder is same + 8 bytes, two's compliment
; if greater than $08 for proper oscillation
tbl_smb2_main_firebar_radial_offsets:
    .byte $00, $01, $03, $04, $05, $06, $07, $07, $08
    .byte $00, $03, $06, $09, $0b, $0d, $0e, $0f, $10
    .byte $00, $04, $09, $0d, $10, $13, $16, $17, $18
    .byte $00, $06, $0c, $12, $16, $1a, $1d, $1f, $20
    .byte $00, $07, $0f, $16, $1c, $21, $25, $27, $28
    .byte $00, $09, $12, $1b, $21, $27, $2c, $2f, $30
    .byte $00, $0b, $15, $1f, $27, $2e, $33, $37, $38
    .byte $00, $0c, $18, $24, $2d, $35, $3b, $3e, $40
    .byte $00, $0e, $1b, $28, $32, $3b, $42, $46, $48
    .byte $00, $0f, $1f, $2d, $38, $42, $4a, $4e, $50
    .byte $00, $11, $22, $31, $3e, $49, $51, $56, $58

off_smb2_main_firebar_quadrant_mirror_bits:
    .byte $01, $03, $02, $00

tbl_smb2_main_firebar_segment_offset_indices:
    .byte $00, $09, $12, $1b, $24, $2d
    .byte $36, $3f, $48, $51, $5a, $63

tbl_smb2_main_player_firebar_collision_y_offsets:
    .byte $0c, $18

sub_smb2_main_process_firebar:
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; get offscreen information
    LDA Enemy_OffscreenBits  ; check for d3 set
    AND #%00001000  ; if so, branch to leave
    BNE bra_smb2_main_exit_firebar_handler
    LDA TimerControl  ; if master timer control set, branch
    BNE bra_smb2_main_use_current_firebar_spin_state  ; ahead of this part
    LDA FirebarSpinSpeed,x  ; load spinning speed of firebar
    JSR sub_smb2_main_firebar_spin  ; modify current spinstate
    AND #%00011111  ; mask out all but 5 LSB
    STA FirebarSpinState_High,x  ; and store as new high byte of spinstate
bra_smb2_main_use_current_firebar_spin_state:
    LDA FirebarSpinState_High,x  ; get high byte of spinstate
    LDY Enemy_ID,x  ; check enemy identifier
    CPY #$1f
    BCC bra_smb2_main_setup_firebar_graphics  ; if < $1f (long firebar), branch
    CMP #$08  ; check high byte of spinstate
    BEQ bra_smb2_main_avoid_horizontal_firebar_state  ; if eight, branch to change
    CMP #$18
    BNE bra_smb2_main_setup_firebar_graphics  ; if not at twenty-four branch to not change
bra_smb2_main_avoid_horizontal_firebar_state:
    CLC
    ADC #$01  ; add one to spinning thing to avoid horizontal state
    STA FirebarSpinState_High,x
bra_smb2_main_setup_firebar_graphics:
    STA $ef  ; save high byte of spinning thing, modified or otherwise
    JSR sub_smb2_main_relative_enemy_position  ; get relative coordinates to screen
    JSR sub_smb2_main_get_firebar_position  ; do a sub here (residual, too early to be used now)
    LDY Enemy_SprDataOffset,x  ; get OAM data offset
    LDA Enemy_Rel_YPos  ; get relative vertical coordinate
    STA Sprite_Y_Position,y  ; store as Y in OAM data
    STA $07  ; also save here
    LDA Enemy_Rel_XPos  ; get relative horizontal coordinate
    STA Sprite_X_Position,y  ; store as X in OAM data
    STA $06  ; also save here
    LDA #$01
    STA $00  ; set $01 value here (not necessary)
    JSR sub_smb2_main_firebar_collision  ; draw fireball part and do collision detection
    LDY #$05  ; load value for short firebars by default
    LDA Enemy_ID,x
    CMP #$1f  ; are we doing a long firebar?
    BCC bra_smb2_main_store_firebar_segment_limit  ; no, branch then
    LDY #$0b  ; otherwise load value for long firebars
bra_smb2_main_store_firebar_segment_limit:
    STY $ed  ; store maximum value for length of firebars
    LDA #$00
    STA $00  ; initialize counter here
bra_smb2_main_draw_firebar_segment_loop:
    LDA $ef  ; load high byte of spinstate
    JSR sub_smb2_main_get_firebar_position  ; get fireball position data depending on firebar part
    JSR sub_smb2_main_draw_firebar_collision  ; position it properly, draw it and do collision detection
    LDA $00  ; check which firebar part
    CMP #$04
    BNE bra_smb2_main_advance_firebar_segment
    LDY DuplicateObj_Offset  ; if we arrive at fifth firebar part,
    LDA Enemy_SprDataOffset,y  ; get offset from long firebar and load OAM data offset
    STA $06  ; using long firebar offset, then store as new one here
bra_smb2_main_advance_firebar_segment:
    INC $00  ; move onto the next firebar part
    LDA $00
    CMP $ed  ; if we end up at the maximum part, go on and leave
    BCC bra_smb2_main_draw_firebar_segment_loop  ; otherwise go back and do another
bra_smb2_main_exit_firebar_handler:
    RTS

sub_smb2_main_draw_firebar_collision:
    LDA $03  ; store mirror data elsewhere
    STA $05
    LDY $06  ; load OAM data offset for firebar
    LDA $01  ; load horizontal adder we got from position loader
    LSR $05  ; shift LSB of mirror data
    BCS bra_smb2_main_apply_positive_firebar_x_offset  ; if carry was set, skip this part
    EOR #$ff
    ADC #$01  ; otherwise get two's compliment of horizontal adder
bra_smb2_main_apply_positive_firebar_x_offset:
    CLC  ; add horizontal coordinate relative to screen to
    ADC Enemy_Rel_XPos  ; horizontal adder, modified or otherwise
    STA Sprite_X_Position,y  ; store as X coordinate here
    STA $06  ; store here for now, note offset is saved in Y still
    CMP Enemy_Rel_XPos  ; compare X coordinate of sprite to original X of firebar
    BCS bra_smb2_main_measure_firebar_x_distance_right  ; if sprite coordinate => original coordinate, branch
    LDA Enemy_Rel_XPos
    SEC  ; otherwise subtract sprite X from the
    SBC $06  ; original one and skip this part
    JMP loc_smb2_main_check_firebar_horizontal_range
bra_smb2_main_measure_firebar_x_distance_right:
    SEC  ; subtract original X from the
    SBC Enemy_Rel_XPos  ; current sprite X
loc_smb2_main_check_firebar_horizontal_range:
    CMP #$59  ; if difference of coordinates within a certain range,
    BCC bra_smb2_main_apply_firebar_y_offset  ; continue by handling vertical adder
    LDA #$f8  ; otherwise, load offscreen Y coordinate
    BNE bra_smb2_main_store_firebar_sprite_y  ; and unconditionally branch to move sprite offscreen
bra_smb2_main_apply_firebar_y_offset:
    LDA Enemy_Rel_YPos  ; if vertical relative coordinate offscreen,
    CMP #$f8  ; skip ahead of this part and write into sprite Y coordinate
    BEQ bra_smb2_main_store_firebar_sprite_y
    LDA $02  ; load vertical adder we got from position loader
    LSR $05  ; shift LSB of mirror data one more time
    BCS bra_smb2_main_apply_positive_firebar_y_offset  ; if carry was set, skip this part
    EOR #$ff
    ADC #$01  ; otherwise get two's compliment of second part
bra_smb2_main_apply_positive_firebar_y_offset:
    CLC  ; add vertical coordinate relative to screen to
    ADC Enemy_Rel_YPos  ; the second data, modified or otherwise
bra_smb2_main_store_firebar_sprite_y:
    STA Sprite_Y_Position,y  ; store as Y coordinate here
    STA $07  ; also store here for now

sub_smb2_main_firebar_collision:
    JSR sub_smb2_main_draw_firebar  ; run sub here to draw current tile of firebar
    TYA  ; return OAM data offset and save
    PHA  ; to the stack for now
    LDA StarInvincibleTimer  ; if star mario invincibility timer
    ORA TimerControl  ; or master timer controls set
    BNE bra_smb2_main_finish_firebar_collision_check  ; then skip all of this
    STA $05  ; otherwise initialize counter
    LDY Player_Y_HighPos
    DEY  ; if player's vertical high byte offscreen,
    BNE bra_smb2_main_finish_firebar_collision_check  ; skip all of this
    LDY Player_Y_Position  ; get player's vertical position
    LDA PlayerSize  ; get player's size
    BNE bra_smb2_main_adjust_small_or_crouching_player_hitbox  ; if player small, branch to alter variables
    LDA CrouchingFlag
    BEQ bra_smb2_main_check_firebar_player_collision  ; if player big and not crouching, jump ahead
bra_smb2_main_adjust_small_or_crouching_player_hitbox:
    INC $05  ; if small or big but crouching, execute this part
    INC $05  ; first increment our counter twice (setting $02 as flag)
    TYA
    CLC  ; then add 24 pixels to the player's
    ADC #$18  ; vertical coordinate
    TAY
bra_smb2_main_check_firebar_player_collision:
    TYA  ; get vertical coordinate, altered or otherwise, from Y
loc_smb2_main_check_firebar_player_y_sample:
    SEC  ; subtract vertical position of firebar
    SBC $07  ; from the vertical coordinate of the player
    BPL bra_smb2_main_check_firebar_player_y_distance  ; if player lower on the screen than firebar,
    EOR #$ff  ; skip two's compliment part
    CLC  ; otherwise get two's compliment
    ADC #$01
bra_smb2_main_check_firebar_player_y_distance:
    CMP #$08  ; if difference => 8 pixels, skip ahead of this part
    BCS bra_smb2_main_check_next_firebar_player_y_sample
    LDA $06  ; if firebar on far right on the screen, skip this,
    CMP #$f0  ; because, really, what's the point?
    BCS bra_smb2_main_check_next_firebar_player_y_sample
    LDA Sprite_X_Position+4  ; get OAM X coordinate for sprite #1
    CLC
    ADC #$04  ; add four pixels
    STA $04  ; store here
    SEC  ; subtract horizontal coordinate of firebar
    SBC $06  ; from the X coordinate of player's sprite 1
    BPL bra_smb2_main_check_firebar_player_x_distance  ; if modded X coordinate to the right of firebar
    EOR #$ff  ; skip two's compliment part
    CLC  ; otherwise get two's compliment
    ADC #$01
bra_smb2_main_check_firebar_player_x_distance:
    CMP #$08  ; if difference < 8 pixels, collision, thus branch
    BCC bra_smb2_main_handle_firebar_player_collision  ; to process
bra_smb2_main_check_next_firebar_player_y_sample:
    LDA $05  ; if value of $02 was set earlier for whatever reason,
    CMP #$02  ; branch to increment OAM offset and leave, no collision
    BEQ bra_smb2_main_finish_firebar_collision_check
    LDY $05  ; otherwise get temp here and use as offset
    LDA Player_Y_Position
    CLC
    ADC tbl_smb2_main_player_firebar_collision_y_offsets,y  ; add value loaded with offset to player's vertical coordinate
    INC $05  ; then increment temp and jump back
    JMP loc_smb2_main_check_firebar_player_y_sample
bra_smb2_main_handle_firebar_player_collision:
    LDX #$01  ; set movement direction by default
    LDA $04  ; if OAM X coordinate of player's sprite 1
    CMP $06  ; is greater than horizontal coordinate of firebar
    BCS bra_smb2_main_set_firebar_knockback_direction  ; then do not alter movement direction
    INX  ; otherwise increment it
bra_smb2_main_set_firebar_knockback_direction:
    STX Enemy_MovingDir  ; store movement direction here
    LDX #$00
    LDA $00  ; save value written to $00 to stack
    PHA
    JSR sub_smb2_main_injure_player  ; perform sub to hurt or kill player
    PLA
    STA $00  ; get value of $00 from stack
bra_smb2_main_finish_firebar_collision_check:
    PLA  ; get OAM data offset
    CLC  ; add four to it and save
    ADC #$04
    STA $06
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

sub_smb2_main_get_firebar_position:
    PHA  ; save high byte of spinstate to the stack
    AND #%00001111  ; mask out low nybble
    CMP #$09
    BCC bra_smb2_main_load_firebar_x_offset  ; if lower than $09, branch ahead
    EOR #%00001111  ; otherwise get two's compliment to oscillate
    CLC
    ADC #$01
bra_smb2_main_load_firebar_x_offset:
    STA $01  ; store result, modified or not, here
    LDY $00  ; load number of firebar ball where we're at
    LDA tbl_smb2_main_firebar_segment_offset_indices,y  ; load offset to firebar position data
    CLC
    ADC $01  ; add oscillated high byte of spinstate
    TAY  ; to offset here and use as new offset
    LDA tbl_smb2_main_firebar_radial_offsets,y  ; get data here and store as horizontal adder
    STA $01
    PLA  ; pull whatever was in A from the stack
    PHA  ; save it again because we still need it
    CLC
    ADC #$08  ; add eight this time, to get vertical adder
    AND #%00001111  ; mask out high nybble
    CMP #$09  ; if lower than $09, branch ahead
    BCC bra_smb2_main_load_firebar_y_offset
    EOR #%00001111  ; otherwise get two's compliment
    CLC
    ADC #$01
bra_smb2_main_load_firebar_y_offset:
    STA $02  ; store result here
    LDY $00
    LDA tbl_smb2_main_firebar_segment_offset_indices,y  ; load offset to firebar position data again
    CLC
    ADC $02  ; this time add value in $02 to offset here and use as offset
    TAY
    LDA tbl_smb2_main_firebar_radial_offsets,y  ; get data here and store as vertica adder
    STA $02
    PLA  ; pull out whatever was in A one last time
    LSR  ; divide by eight or shift three to the right
    LSR
    LSR
    TAY  ; use as offset
    LDA off_smb2_main_firebar_quadrant_mirror_bits,y  ; load mirroring data here
    STA $03  ; store
    RTS

; --------------------------------
