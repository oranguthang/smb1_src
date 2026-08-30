bra_smb2_main_spawn_queued_frenzy_enemy:
    LDA EnemyFrenzyQueue  ; check for enemy object in frenzy queue
    BEQ bra_smb2_main_process_enemy_stream  ; if not, skip this part
    STA Enemy_ID,x  ; store as enemy object identifier here
    LDA #$01
    STA Enemy_Flag,x  ; activate enemy object flag
    LDA #$00
    STA Enemy_State,x  ; initialize state and frenzy queue
    STA EnemyFrenzyQueue
    JMP sub_smb2_main_initialize_enemy_object  ; and then jump to deal with this enemy

; --------------------------------
; $06 - used to hold page location of extended right boundary
; $07 - used to hold high nybble of position of extended right boundary

bra_smb2_main_process_enemy_stream:
    LDY EnemyDataOffset  ; get offset of enemy object data
    LDA (EnemyData),y  ; load first byte
    CMP #$ff  ; check for EOD terminator
    BNE bra_smb2_main_enforce_enemy_slot_limit
    JMP bra_smb2_main_spawn_frenzy_enemy_or_vine  ; if found, jump to check frenzy buffer, otherwise

bra_smb2_main_enforce_enemy_slot_limit:
    AND #%00001111  ; check for special row $0e
    CMP #$0e
    BEQ bra_smb2_main_compute_enemy_spawn_boundary  ; if found, branch, otherwise
    CPX #$05  ; check for end of buffer
    BCC bra_smb2_main_compute_enemy_spawn_boundary  ; if not at end of buffer, branch
    INY
    LDA (EnemyData),y  ; check for specific value here
    AND #%00111111  ; not sure what this was intended for, exactly
    CMP #$2e  ; this part is quite possibly residual code
    BEQ bra_smb2_main_compute_enemy_spawn_boundary  ; but it has the effect of keeping enemies out of
    RTS  ; the sixth slot

bra_smb2_main_compute_enemy_spawn_boundary:
    LDA ScreenRight_X_Pos  ; add 48 to pixel coordinate of right boundary
    CLC
    ADC #$30
    AND #%11110000  ; store high nybble
    STA $07
    LDA ScreenRight_PageLoc  ; add carry to page location of right boundary
    ADC #$00
    STA $06  ; store page location + carry
    LDY EnemyDataOffset
    INY
    LDA (EnemyData),y  ; if MSB of enemy object is clear, branch to check for row $0f
    ASL
    BCC bra_smb2_main_parse_enemy_page_command
    LDA EnemyObjectPageSel  ; if page select already set, do not set again
    BNE bra_smb2_main_parse_enemy_page_command
    INC EnemyObjectPageSel  ; otherwise, if MSB is set, set page select
    INC EnemyObjectPageLoc  ; and increment page control

bra_smb2_main_parse_enemy_page_command:
    DEY
    LDA (EnemyData),y  ; reread first byte
    AND #$0f
    CMP #$0f  ; check for special row $0f
    BNE bra_smb2_main_decode_enemy_position  ; if not found, branch to position enemy object
    LDA EnemyObjectPageSel  ; if page select set,
    BNE bra_smb2_main_decode_enemy_position  ; branch without reading second byte
    INY
    LDA (EnemyData),y  ; otherwise, get second byte, mask out 2 MSB
    AND #%00111111
    STA EnemyObjectPageLoc  ; store as page control for enemy object data
    INC EnemyDataOffset  ; increment enemy object data offset 2 bytes
    INC EnemyDataOffset
    INC EnemyObjectPageSel  ; set page select for enemy object data and
    JMP loc_smb2_main_process_game_loop_command  ; jump back to process loop commands again

bra_smb2_main_decode_enemy_position:
    LDA EnemyObjectPageLoc  ; store page control as page location
    STA Enemy_PageLoc,x  ; for enemy object
    LDA (EnemyData),y  ; get first byte of enemy object
    AND #%11110000
    STA Enemy_X_Position,x  ; store column position
    CMP ScreenRight_X_Pos  ; check column position against right boundary
    LDA Enemy_PageLoc,x  ; without subtracting, then subtract borrow
    SBC ScreenRight_PageLoc  ; from page location
    BCS bra_smb2_main_check_enemy_spawn_boundary  ; if enemy object beyond or at boundary, branch
    LDA (EnemyData),y
    AND #%00001111  ; check for special row $0e
    CMP #$0e  ; if found, jump elsewhere
    BEQ bra_smb2_main_parse_area_transition_command
    JMP loc_smb2_main_advance_enemy_stream  ; if not found, unconditional jump

bra_smb2_main_check_enemy_spawn_boundary:
    LDA $07  ; check right boundary + 48 against
    CMP Enemy_X_Position,x  ; column position without subtracting,
    LDA $06  ; then subtract borrow from page control temp
    SBC Enemy_PageLoc,x  ; plus carry
    BCC bra_smb2_main_spawn_frenzy_enemy_or_vine  ; if enemy object beyond extended boundary, branch
    LDA #$01  ; store value in vertical high byte
    STA Enemy_Y_HighPos,x
    LDA (EnemyData),y  ; get first byte again
    ASL  ; multiply by four to get the vertical
    ASL  ; coordinate
    ASL
    ASL
    STA Enemy_Y_Position,x
    CMP #$e0  ; do one last check for special row $0e
    BEQ bra_smb2_main_parse_area_transition_command  ; (necessary if branched to $c1cb)
    INY
    LDA (EnemyData),y  ; get second byte of object
    AND #%01000000  ; check to see if hard mode bit is set
    BEQ bra_smb2_main_decode_enemy_or_group_id  ; if not, branch to check for group enemy objects
    LDA SecondaryHardMode  ; if set, check to see if secondary hard mode flag
    BEQ bra_smb2_main_advance_enemy_stream_two_bytes  ; is on, and if not, branch to skip this object completely

bra_smb2_main_decode_enemy_or_group_id:
    LDA (EnemyData),y  ; get second byte and mask out 2 MSB
    AND #%00111111
    CMP #$37  ; check for value below $37
    BCC bra_smb2_main_apply_hard_mode_enemy_substitution
    CMP #$3f  ; if $37 or greater, check for value
    BCC bra_smb2_main_spawn_enemy_group  ; below $3f, branch if below $3f

bra_smb2_main_apply_hard_mode_enemy_substitution:
    CMP #Goomba  ; if below $37, check for goomba
    BNE bra_smb2_main_store_and_initialize_enemy_id  ; value ($3f or more always fails)
    LDY PrimaryHardMode  ; check if primary hard mode flag is set
    BEQ bra_smb2_main_store_and_initialize_enemy_id  ; and if so, change goomba to buzzy beetle
    LDA #BuzzyBeetle
bra_smb2_main_store_and_initialize_enemy_id:
    STA Enemy_ID,x  ; store enemy object number into buffer
    LDA #$01
    STA Enemy_Flag,x  ; set flag for enemy in buffer
    JSR sub_smb2_main_initialize_enemy_object
    LDA Enemy_Flag,x  ; check to see if flag is set
    BNE bra_smb2_main_advance_enemy_stream_two_bytes  ; if not, leave, otherwise branch
    RTS

bra_smb2_main_spawn_frenzy_enemy_or_vine:
    LDA EnemyFrenzyBuffer  ; if enemy object stored in frenzy buffer
    BNE bra_smb2_main_store_queued_frenzy_or_vine_id  ; then branch ahead to store in enemy object buffer
    LDA VineFlagOffset  ; otherwise check vine flag offset
    CMP #$01
    BNE bra_smb2_main_exit_enemy_stream_parser  ; if other value <> 1, leave
    LDA #VineObject  ; otherwise put vine in enemy identifier
bra_smb2_main_store_queued_frenzy_or_vine_id:
    STA Enemy_ID,x  ; store contents of frenzy buffer into enemy identifier value

sub_smb2_main_initialize_enemy_object:
    LDA #$00  ; initialize enemy state
    STA Enemy_State,x
    JSR sub_smb2_main_checkpoint_enemy_id  ; jump ahead to run jump engine and subroutines
bra_smb2_main_exit_enemy_stream_parser:
    RTS  ; then leave

bra_smb2_main_spawn_enemy_group:
    JMP loc_smb2_main_spawn_enemy_group  ; handle enemy group objects

bra_smb2_main_parse_area_transition_command:
    INY  ; increment Y to load third byte of object
    INY
    LDA WorldNumber
    CMP #World9  ; skip world number check if on world 9
    BEQ bra_smb2_main_w9_skip
    LDA (EnemyData),y
    LSR  ; move 3 MSB to the bottom, effectively
    LSR  ; making %xxx00000 into %00000xxx
    LSR
    LSR
    LSR
    CMP WorldNumber  ; is it the same world number as we're on?
    BNE bra_smb2_main_skip_area_transition_command  ; if not, do not use (this allows multiple uses
bra_smb2_main_w9_skip:
    DEY  ; of the same area, like the underground bonus areas)
    LDA (EnemyData),y  ; otherwise, get second byte and use as offset
    STA AreaPointer  ; to addresses for level and enemy object data
    INY
    LDA (EnemyData),y  ; get third byte again, and this time mask out
    AND #%00011111  ; the 3 MSB from before, save as page number to be
    STA EntrancePage  ; used upon entry to area, if area is entered
bra_smb2_main_skip_area_transition_command:
    JMP loc_smb2_main_advance_enemy_stream_three_bytes

loc_smb2_main_advance_enemy_stream:
    LDY EnemyDataOffset  ; load current offset for enemy object data
    LDA (EnemyData),y  ; get first byte
    AND #%00001111  ; check for special row $0e
    CMP #$0e
    BNE bra_smb2_main_advance_enemy_stream_two_bytes
loc_smb2_main_advance_enemy_stream_three_bytes:
    INC EnemyDataOffset  ; if row = $0e, increment three bytes
bra_smb2_main_advance_enemy_stream_two_bytes:
    INC EnemyDataOffset  ; otherwise increment two bytes
    INC EnemyDataOffset
    LDA #$00  ; init page select for enemy objects
    STA EnemyObjectPageSel
    LDX ObjectOffset  ; reload current offset in enemy buffers
    RTS  ; and leave

sub_smb2_main_checkpoint_enemy_id:
    LDA Enemy_ID,x
    CMP #$15  ; check enemy object identifier for $15 or greater
    BCS bra_smb2_main_dispatch_enemy_initializer  ; and branch straight to the jump engine if found
    TAY  ; save identifier in Y register for now
    LDA Enemy_Y_Position,x
    ADC #$08  ; add eight pixels to what will eventually be the
    STA Enemy_Y_Position,x  ; enemy object's vertical coordinate ($00-$14 only)
    LDA #$01
    STA EnemyOffscrBitsMasked,x  ; set offscreen masked bit
    TYA  ; get identifier back and use as offset for jump engine

bra_smb2_main_dispatch_enemy_initializer:
    JSR sub_smb2_main_dispatch_inline_handler

    .word sub_smb2_main_initialize_normal_enemy
    .word sub_smb2_main_initialize_normal_enemy
    .word sub_smb2_main_initialize_normal_enemy
    .word handler_smb2_main_initialize_red_koopa
    .word handler_smb2_main_initialize_piranha_plant
    .word handler_smb2_main_initialize_hammer_bro
    .word handler_smb2_main_initialize_goomba
    .word handler_smb2_main_initialize_blooper
    .word handler_smb2_main_initialize_bullet_bill
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_initialize_cheep_cheep
    .word handler_smb2_main_initialize_cheep_cheep
    .word sub_smb2_main_initialize_podoboo
    .word handler_smb2_main_initialize_piranha_plant
    .word handler_smb2_main_initialize_jumping_green_paratroopa
    .word handler_smb2_main_initialize_red_paratroopa

    .word sub_smb2_main_initialize_horizontal_flying_or_swimming_enemy
    .word handler_smb2_main_initialize_lakitu
    .word handler_smb2_main_initialize_enemy_frenzy
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_initialize_enemy_frenzy
    .word handler_smb2_main_initialize_enemy_frenzy
    .word handler_smb2_main_initialize_enemy_frenzy
    .word handler_smb2_main_initialize_enemy_frenzy
    .word handler_smb2_main_end_enemy_frenzy
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_initialize_short_firebar
    .word handler_smb2_main_initialize_short_firebar
    .word handler_smb2_main_initialize_short_firebar
    .word handler_smb2_main_initialize_short_firebar
    .word handler_smb2_main_initialize_long_firebar

    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_initialize_balance_platform
    .word handler_smb2_main_initialize_vertical_platform
    .word handler_smb2_main_initialize_large_lift_up
    .word handler_smb2_main_initialize_large_lift_down
    .word handler_smb2_main_initialize_horizontal_platform
    .word handler_smb2_main_initialize_drop_platform
    .word handler_smb2_main_initialize_horizontal_platform
    .word sub_smb2_main_initialize_platform_lift_up
    .word sub_smb2_main_initialize_platform_lift_down
    .word handler_smb2_main_initialize_bowser
    .word handler_smb2_main_initialize_power_up_object
    .word sub_smb2_main_setup_vine

    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_no_enemy_initialization
    .word handler_smb2_main_initialize_retainer
    .word handler_smb2_main_end_enemy_initialization

handler_smb2_main_no_enemy_initialization:
    RTS

handler_smb2_main_initialize_goomba:
    JSR sub_smb2_main_initialize_normal_enemy  ; set appropriate horizontal speed
    JMP sub_smb2_main_initialize_small_enemy_bounding_box  ; set $09 as bounding box control, set other values

sub_smb2_main_initialize_podoboo:
    LDA #$02  ; set enemy position to below
    STA Enemy_Y_HighPos,x  ; the bottom of the screen
    STA Enemy_Y_Position,x
    LSR
    STA EnemyIntervalTimer,x  ; set timer for enemy
    LSR
    STA Enemy_State,x  ; initialize enemy state, then jump to use
    JMP sub_smb2_main_initialize_small_enemy_bounding_box  ; $09 as bounding box size and set other things

handler_smb2_main_initialize_retainer:
    LDA #$b8  ; set fixed vertical position for
    STA Enemy_Y_Position,x  ; princess/mushroom retainer object
    RTS

off_smb2_main_normal_enemy_x_speeds:
    .byte $f8, $f4

sub_smb2_main_initialize_normal_enemy:
    LDY #$01  ; load offset of 1 by default
    LDA PrimaryHardMode  ; check for primary hard mode flag set
    BNE bra_smb2_main_select_normal_enemy_x_speed
    DEY  ; if not set, decrement offset
bra_smb2_main_select_normal_enemy_x_speed:
    LDA off_smb2_main_normal_enemy_x_speeds,y  ; get appropriate horizontal speed
loc_smb2_main_store_enemy_x_speed:
    STA Enemy_X_Speed,x  ; store as speed for enemy object
    JMP loc_smb2_main_set_tall_enemy_bounding_box  ; branch to set bounding box control and other data

handler_smb2_main_initialize_red_koopa:
    JSR sub_smb2_main_initialize_normal_enemy  ; load appropriate horizontal speed
    LDA #$01  ; set enemy state for red koopa troopa $03
    STA Enemy_State,x
    RTS

off_smb2_main_hammer_bro_walking_delays:
    .byte $80, $50

handler_smb2_main_initialize_hammer_bro:
    LDA #$00  ; init horizontal speed and timer used by hammer bro
    STA HammerThrowingTimer,x  ; apparently to time hammer throwing
    STA Enemy_X_Speed,x
    LDA WorldNumber  ; if on worlds 7-9, branch to skip the walk delay
    CMP #World7
    BCS bra_smb2_main_finish_hammer_bro_initialization
    LDY SecondaryHardMode  ; get secondary hard mode flag
    LDA off_smb2_main_hammer_bro_walking_delays,y
    STA EnemyIntervalTimer,x  ; set value as delay for hammer bro to walk left
bra_smb2_main_finish_hammer_bro_initialization:
    LDA #$0b  ; set specific value for bounding box size control
    JMP bra_smb2_main_set_enemy_bounding_box

; --------------------------------

sub_smb2_main_initialize_horizontal_flying_or_swimming_enemy:
    LDA #$00  ; initialize horizontal speed
    JMP loc_smb2_main_store_enemy_x_speed

; --------------------------------

handler_smb2_main_initialize_blooper:
    LDA #$00  ; initialize horizontal speed
    STA BlooperMoveSpeed,x
sub_smb2_main_initialize_small_enemy_bounding_box:
    LDA #$09  ; set specific bounding box size control
    BNE bra_smb2_main_set_enemy_bounding_box  ; unconditional branch

handler_smb2_main_initialize_red_paratroopa:
    LDY #$30  ; load central position adder for 48 pixels down
    LDA Enemy_Y_Position,x  ; set vertical coordinate into location to
    STA RedPTroopaOrigXPos,x  ; be used as original vertical coordinate
    BPL bra_smb2_main_compute_red_paratroopa_center_y  ; if vertical coordinate < $80
    LDY #$e0  ; if => $80, load position adder for 32 pixels up
bra_smb2_main_compute_red_paratroopa_center_y:
    TYA  ; send central position adder to A
    ADC Enemy_Y_Position,x  ; add to current vertical coordinate
    STA RedPTroopaCenterYPos,x  ; store as central vertical coordinate
loc_smb2_main_set_tall_enemy_bounding_box:
    LDA #$03  ; set specific bounding box size control
bra_smb2_main_set_enemy_bounding_box:
    STA Enemy_BoundBoxCtrl,x  ; set bounding box control here
    LDA #$02  ; set moving direction for left
    STA Enemy_MovingDir,x
sub_smb2_main_clear_enemy_vertical_motion:
    LDA #$00  ; initialize vertical speed
    STA Enemy_Y_Speed,x  ; and movement force
    STA Enemy_Y_MoveForce,x
    RTS

handler_smb2_main_initialize_bullet_bill:
    LDA #$02  ; set moving direction for left
    STA Enemy_MovingDir,x
    LDA #$09  ; set bounding box control for $09
    STA Enemy_BoundBoxCtrl,x
    RTS

handler_smb2_main_initialize_cheep_cheep:
    JSR sub_smb2_main_initialize_small_enemy_bounding_box  ; set vertical bounding box, speed, init others
    LDA PseudoRandomBitReg,x  ; check one portion of LSFR
    AND #%00010000  ; get d4 from it
    STA CheepCheepMoveMFlag,x  ; save as movement flag of some sort
    LDA Enemy_Y_Position,x
    STA CheepCheepOrigYPos,x  ; save original vertical coordinate here
    RTS

handler_smb2_main_initialize_lakitu:
    LDA EnemyFrenzyBuffer  ; check to see if an enemy is already in
    BNE bra_smb2_main_erase_duplicate_lakitu  ; the frenzy buffer, and branch to kill lakitu if so

sub_smb2_main_setup_lakitu:
    LDA #$00  ; erase counter for lakitu's reappearance
    STA LakituReappearTimer
    JSR sub_smb2_main_initialize_horizontal_flying_or_swimming_enemy  ; set $03 as bounding box, set other attributes
    JMP loc_smb2_main_set_tall_special_enemy_bounding_box  ; set $03 as bounding box again (not necessary) and leave

bra_smb2_main_erase_duplicate_lakitu:
    JMP sub_smb2_main_erase_enemy_object

; --------------------------------
; $01-$03 - used to hold pseudorandom difference adjusters

off_smb2_main_spiny_throw_speed_adjustments:
    .byte $26, $2c, $32, $38
    .byte $20, $22, $24, $26
    .byte $13, $14, $15, $16

handler_smb2_main_spawn_lakitu_or_spiny:
    LDA FrenzyEnemyTimer  ; if timer here not expired, leave
    BNE bra_smb2_main_exit_lakitu_spiny_handler
    CPX #$05  ; if we are on the special use slot, leave
    BCS bra_smb2_main_exit_lakitu_spiny_handler
    LDA #$80  ; set timer
    STA FrenzyEnemyTimer
    LDY #$04  ; start with the last enemy slot
bra_smb2_main_find_active_lakitu:
    LDA Enemy_ID,y  ; check all enemy slots to see
    CMP #Lakitu  ; if lakitu is on one of them
    BEQ bra_smb2_main_spawn_spiny_egg  ; if so, branch out of this loop
    DEY  ; otherwise check another slot
    BPL bra_smb2_main_find_active_lakitu  ; loop until all slots are checked
    INC LakituReappearTimer  ; increment reappearance timer
    LDA LakituReappearTimer
    CMP #$03  ; check to see if we're up to a certain value yet
    BCC bra_smb2_main_exit_lakitu_spiny_handler  ; if not, leave
    LDX #$04  ; start with the last enemy slot again
bra_smb2_main_find_empty_enemy_slot_for_lakitu:
    LDA Enemy_Flag,x  ; check enemy buffer flag for non-active enemy slot
    BEQ bra_smb2_main_spawn_lakitu  ; branch out of loop if found
    DEX  ; otherwise check next slot
    BPL bra_smb2_main_find_empty_enemy_slot_for_lakitu  ; branch until all slots are checked
    BMI bra_smb2_main_restore_current_enemy_slot  ; if no empty slots were found, branch to leave
bra_smb2_main_spawn_lakitu:
    LDA #$00  ; initialize enemy state
    STA Enemy_State,x
    LDA #Lakitu  ; create lakitu enemy object
    STA Enemy_ID,x
    JSR sub_smb2_main_setup_lakitu  ; do a sub to set up lakitu
    LDA #$20
    LDY HardWorldFlag
    BNE bra_smb2_main_set_lower_lakitu_y_position  ; if in worlds A-D, put lakitu lower on the screen
    LDY WorldNumber
    CPY #$06  ; if in worlds 1-6, branch to use default high position
    BCC bra_smb2_main_set_lakitu_position  ; otherwise put lakitu lower on the screen
bra_smb2_main_set_lower_lakitu_y_position:
    LDA #$60
bra_smb2_main_set_lakitu_position:
    JSR sub_smb2_main_put_at_right_extent  ; finish setting up lakitu
bra_smb2_main_restore_current_enemy_slot:
    LDX ObjectOffset  ; get enemy object buffer offset again and leave
bra_smb2_main_exit_lakitu_spiny_handler:
    RTS

bra_smb2_main_spawn_spiny_egg:
    LDA Player_Y_Position  ; if player above a certain point, branch to leave
    CMP #$2c
    BCC bra_smb2_main_exit_lakitu_spiny_handler
    LDA Enemy_State,y  ; if lakitu is not in normal state, branch to leave
    BNE bra_smb2_main_exit_lakitu_spiny_handler
    LDA Enemy_PageLoc,y  ; store horizontal coordinates (high and low) of lakitu
    STA Enemy_PageLoc,x  ; into the coordinates of the spiny we're going to create
    LDA Enemy_X_Position,y
    STA Enemy_X_Position,x
    LDA #$01  ; put spiny within vertical screen unit
    STA Enemy_Y_HighPos,x
    LDA Enemy_Y_Position,y  ; put spiny eight pixels above where lakitu is
    SEC
    SBC #$08
    STA Enemy_Y_Position,x
    LDA PseudoRandomBitReg,x  ; get 2 LSB of LSFR and save to Y
    AND #%00000011
    TAY
    LDX #$02
bra_smb2_main_build_spiny_throw_adjustments:
    LDA off_smb2_main_spiny_throw_speed_adjustments,y  ; get three values and save them
    STA $01,x  ; to $01-$03
    INY
    INY  ; increment Y four bytes for each value
    INY
    INY
    DEX  ; decrement X for each one
    BPL bra_smb2_main_build_spiny_throw_adjustments  ; loop until all three are written
    LDX ObjectOffset  ; get enemy object buffer offset
    JSR sub_smb2_main_player_lakitu_diff  ; move enemy, change direction, get value - difference
    LDY Player_X_Speed  ; check player's horizontal speed
    CPY #$08
    BCS bra_smb2_main_initialize_spiny_throw_speed  ; if moving faster than a certain amount, branch elsewhere
    TAY  ; otherwise save value in A to Y for now
    LDA PseudoRandomBitReg+1,x
    AND #%00000011  ; get one of the LSFR parts and save the 2 LSB
    BEQ bra_smb2_main_use_positive_spiny_throw_speed  ; branch if neither bits are set
    TYA
    EOR #%11111111  ; otherwise get two's compliment of Y
    TAY
    INY
bra_smb2_main_use_positive_spiny_throw_speed:
    TYA  ; put value from A in Y back to A (they will be lost anyway)
bra_smb2_main_initialize_spiny_throw_speed:
    JSR sub_smb2_main_initialize_small_enemy_bounding_box  ; set bounding box control, init attributes, lose contents of A
    LDY #$02  ; (putting this call elsewhere will preserve A)
    STA Enemy_X_Speed,x  ; set horizontal speed to zero because previous contents
    CMP #$00  ; of A were lost...branch here will never be taken for
    BMI bra_smb2_main_store_spiny_throw_direction  ; the same reason
    DEY
bra_smb2_main_store_spiny_throw_direction:
    STY Enemy_MovingDir,x  ; set moving direction to the right
    LDA #$fd
    STA Enemy_Y_Speed,x  ; set vertical speed to move upwards
    LDA #$01
    STA Enemy_Flag,x  ; enable enemy object by setting flag
    LDA #$05
    STA Enemy_State,x  ; put spiny in egg state and leave
bra_smb2_main_exit_enemy_initialization:
    RTS

; --------------------------------
