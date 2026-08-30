off_smb2_main_firebar_spin_speeds:
    .byte $28, $38, $28, $38, $28

off_smb2_main_firebar_spin_directions:
    .byte $00, $00, $10, $10, $00

handler_smb2_main_initialize_long_firebar:
    JSR sub_smb2_main_duplicate_enemy_object  ; create enemy object for long firebar

handler_smb2_main_initialize_short_firebar:
    LDA #$00  ; initialize low byte of spin state
    STA FirebarSpinState_Low,x
    LDA Enemy_ID,x  ; subtract $1b from enemy identifier
    SEC  ; to get proper offset for firebar data
    SBC #$1b
    TAY
    LDA off_smb2_main_firebar_spin_speeds,y  ; get spinning speed of firebar
    STA FirebarSpinSpeed,x
    LDA off_smb2_main_firebar_spin_directions,y  ; get spinning direction of firebar
    STA FirebarSpinDirection,x
    LDA Enemy_Y_Position,x
    CLC  ; add four pixels to vertical coordinate
    ADC #$04
    STA Enemy_Y_Position,x
    LDA Enemy_X_Position,x
    CLC  ; add four pixels to horizontal coordinate
    ADC #$04
    STA Enemy_X_Position,x
    LDA Enemy_PageLoc,x
    ADC #$00  ; add carry to page location
    STA Enemy_PageLoc,x
    JMP loc_smb2_main_set_tall_special_enemy_bounding_box  ; set bounding box control (not used) and leave

; --------------------------------
; $00-$01 - used to hold pseudorandom bits

off_smb2_main_flying_cheep_cheep_x_offsets:
    .byte $80, $30, $40, $80
    .byte $30, $50, $50, $70
    .byte $20, $40, $80, $a0
    .byte $70, $40, $90, $68

off_smb2_main_flying_cheep_cheep_x_speeds:
    .byte $0e, $05, $06, $0e
    .byte $1c, $20, $10, $0c
    .byte $1e, $22, $18, $14

off_smb2_main_flying_cheep_cheep_spawn_delays:
    .byte $10, $60, $20, $48

handler_smb2_main_initialize_flying_cheep_cheep:
    LDA FrenzyEnemyTimer  ; if timer here not expired yet, branch to leave
    BNE bra_smb2_main_exit_enemy_initialization
    JSR sub_smb2_main_initialize_small_enemy_bounding_box  ; jump to set bounding box size $09 and init other values
    LDA PseudoRandomBitReg+1,x
    AND #%00000011  ; set pseudorandom offset here
    TAY
    LDA off_smb2_main_flying_cheep_cheep_spawn_delays,y  ; load timer with pseudorandom offset
    STA FrenzyEnemyTimer
    LDY #$03  ; load Y with default value
    LDA SecondaryHardMode
    BEQ bra_smb2_main_set_flying_cheep_cheep_slot_limit  ; if secondary hard mode flag not set, do not increment Y
    INY  ; otherwise, increment Y to allow as many as four onscreen
bra_smb2_main_set_flying_cheep_cheep_slot_limit:
    STY $00  ; store whatever pseudorandom bits are in Y
    CPX $00  ; compare enemy object buffer offset with Y
    BCS bra_smb2_main_exit_enemy_initialization  ; if X => Y, branch to leave
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get last two bits of LSFR, first part
    STA $00  ; and store in two places
    STA $01
    LDA #$fb  ; set vertical speed for cheep-cheep
    STA Enemy_Y_Speed,x
    LDA #$00  ; load default value
    LDY Player_X_Speed  ; check player's horizontal speed
    BEQ bra_smb2_main_build_flying_cheep_cheep_random_seed  ; if player not moving left or right, skip this part
    LDA #$04
    CPY #$19  ; if moving to the right but not very quickly,
    BCC bra_smb2_main_build_flying_cheep_cheep_random_seed  ; do not change A
    ASL  ; otherwise, multiply A by 2
bra_smb2_main_build_flying_cheep_cheep_random_seed:
    PHA  ; save to stack
    CLC
    ADC $00  ; add to last two bits of LSFR we saved earlier
    STA $00  ; save it there
    LDA PseudoRandomBitReg+1,x
    AND #%00000011  ; if neither of the last two bits of second LSFR set,
    BEQ bra_smb2_main_select_flying_cheep_cheep_random_offset  ; skip this part and save contents of $00
    LDA PseudoRandomBitReg+2,x
    AND #%00001111  ; otherwise overwrite with lower nybble of
    STA $00  ; third LSFR part
bra_smb2_main_select_flying_cheep_cheep_random_offset:
    PLA  ; get value from stack we saved earlier
    CLC
    ADC $01  ; add to last two bits of LSFR we saved in other place
    TAY  ; use as pseudorandom offset here
    LDA off_smb2_main_flying_cheep_cheep_x_speeds,y  ; get horizontal speed using pseudorandom offset
    STA Enemy_X_Speed,x
    LDA #$01  ; set to move towards the right
    STA Enemy_MovingDir,x
    LDA Player_X_Speed  ; if player moving left or right, branch ahead of this part
    BNE bra_smb2_main_choose_flying_cheep_cheep_spawn_side
    LDY $00  ; get first LSFR or third LSFR lower nybble
    TYA  ; and check for d1 set
    AND #%00000010
    BEQ bra_smb2_main_choose_flying_cheep_cheep_spawn_side  ; if d1 not set, branch
    LDA Enemy_X_Speed,x
    EOR #$ff  ; if d1 set, change horizontal speed
    CLC  ; into two's compliment, thus moving in the opposite
    ADC #$01  ; direction
    STA Enemy_X_Speed,x
    INC Enemy_MovingDir,x  ; increment to move towards the left
bra_smb2_main_choose_flying_cheep_cheep_spawn_side:
    TYA  ; get first LSFR or third LSFR lower nybble again
    AND #%00000010
    BEQ bra_smb2_main_spawn_flying_cheep_cheep_left_of_player  ; check for d1 set again, branch again if not set
    LDA Player_X_Position  ; get player's horizontal position
    CLC
    ADC off_smb2_main_flying_cheep_cheep_x_offsets,y  ; if d1 set, add value obtained from pseudorandom offset
    STA Enemy_X_Position,x  ; and save as enemy's horizontal position
    LDA Player_PageLoc  ; get player's page location
    ADC #$00  ; add carry and jump past this part
    JMP loc_smb2_main_finish_flying_cheep_cheep_spawn
bra_smb2_main_spawn_flying_cheep_cheep_left_of_player:
    LDA Player_X_Position  ; get player's horizontal position
    SEC
    SBC off_smb2_main_flying_cheep_cheep_x_offsets,y  ; if d1 not set, subtract value obtained from pseudorandom
    STA Enemy_X_Position,x  ; offset and save as enemy's horizontal position
    LDA Player_PageLoc  ; get player's page location
    SBC #$00  ; subtract borrow
loc_smb2_main_finish_flying_cheep_cheep_spawn:
    STA Enemy_PageLoc,x  ; save as enemy's page location
    LDA #$01
    STA Enemy_Flag,x  ; set enemy's buffer flag
    STA Enemy_Y_HighPos,x  ; set enemy's high vertical byte
    LDA #$f8
    STA Enemy_Y_Position,x  ; put enemy below the screen, and we are done
    RTS

handler_smb2_main_initialize_bowser:
    LDY #$04  ; if the slot about to be checked is the slot
bra_smb2_main_check_bowser_enemy_slot:
    CPY ObjectOffset  ; where bowser is being initialized, skip it
    BEQ bra_smb2_main_no_bowser
    LDA Enemy_ID,y  ; otherwise check to see if a bowser object
    CMP #Bowser  ; exists in another slot
    BNE bra_smb2_main_no_bowser  ; if not, branch to check another enemy slot
    LDA #$00
    STA Enemy_ID,y  ; do this until any previous bowser objects are erased
    STA Enemy_Flag,y
bra_smb2_main_no_bowser:
    DEY  ; loop until all slots are checked
    BPL bra_smb2_main_check_bowser_enemy_slot  ; except the slot where bowser is being initialized

loc_smb2_main_create_bowser:
    JSR sub_smb2_main_duplicate_enemy_object  ; jump to create another bowser object
    STX BowserFront_Offset  ; save offset of first here
    LDA #$00
    STA BowserBodyControls  ; initialize bowser's body controls
    STA BridgeCollapseOffset  ; and bridge collapse offset
    LDA Enemy_X_Position,x
    STA BowserOrigXPos  ; store original horizontal position here
    LDA #$df
    STA BowserFireBreathTimer  ; store something here
    STA Enemy_MovingDir,x  ; and in moving direction
    LDA #$20
    STA BowserFeetCounter  ; set bowser's feet timer and in enemy timer
    STA EnemyFrameTimer,x
    LDA #$05
    STA BowserHitPoints  ; give bowser 5 hit points
    LSR
    STA BowserMovementSpeed  ; set default movement speed here
    RTS

sub_smb2_main_duplicate_enemy_object:
    LDY #$ff  ; start at beginning of enemy slots
bra_smb2_main_find_duplicate_enemy_slot:
    INY  ; increment one slot
    LDA Enemy_Flag,y  ; check enemy buffer flag for empty slot
    BNE bra_smb2_main_find_duplicate_enemy_slot  ; if set, branch and keep checking
    STY DuplicateObj_Offset  ; otherwise set offset here
    TXA  ; transfer original enemy buffer offset
    ORA #%10000000  ; store with d7 set as flag in new enemy
    STA Enemy_Flag,y  ; slot as well as enemy offset
    LDA Enemy_PageLoc,x
    STA Enemy_PageLoc,y  ; copy page location and horizontal coordinates
    LDA Enemy_X_Position,x  ; from original enemy to new enemy
    STA Enemy_X_Position,y
    LDA #$01
    STA Enemy_Flag,x  ; set flag as normal for original enemy
    STA Enemy_Y_HighPos,y  ; set high vertical byte for new enemy
    LDA Enemy_Y_Position,x
    STA Enemy_Y_Position,y  ; copy vertical coordinate from original to new
bra_smb2_main_exit_special_enemy_initialization:
    RTS  ; and then leave

; --------------------------------

off_smb2_main_bowser_flame_target_y_positions:
    .byte $90, $80, $70, $90

off_smb2_main_bowser_flame_y_force_adjustments:
    .byte $ff, $01

handler_smb2_main_initialize_bowser_flame:
    LDA FrenzyEnemyTimer  ; if timer not expired yet, branch to leave
    BNE bra_smb2_main_exit_special_enemy_initialization
    STA Enemy_Y_MoveForce,x  ; reset something here
    LDA NoiseSoundQueue
    ORA #Sfx_BowserFlame  ; load bowser's flame sound into queue
    STA NoiseSoundQueue
    LDY BowserFront_Offset  ; get bowser's buffer offset
    LDA Enemy_ID,y  ; check for bowser
    CMP #Bowser
    BEQ bra_smb2_main_spawn_flame_from_bowser_mouth  ; branch if found
    JSR sub_smb2_main_set_flame_timer  ; get timer data based on flame counter
    CLC
    ADC #$20  ; add 32 frames by default
    LDY SecondaryHardMode
    BEQ bra_smb2_main_set_bowser_flame_spawn_delay  ; if secondary mode flag not set, use as timer setting
    SEC
    SBC #$10  ; otherwise subtract 16 frames for secondary hard mode
bra_smb2_main_set_bowser_flame_spawn_delay:
    STA FrenzyEnemyTimer  ; set timer accordingly
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get 2 LSB from first part of LSFR
    STA BowserFlamePRandomOfs,x  ; set here
    TAY  ; use as offset
    LDA off_smb2_main_bowser_flame_target_y_positions,y  ; load vertical position based on pseudorandom offset

sub_smb2_main_put_at_right_extent:
    STA Enemy_Y_Position,x  ; set vertical position
    LDA ScreenRight_X_Pos
    CLC
    ADC #$20  ; place enemy 32 pixels beyond right side of screen
    STA Enemy_X_Position,x
    LDA ScreenRight_PageLoc
    ADC #$00  ; add carry
    STA Enemy_PageLoc,x
    JMP loc_smb2_main_finish_bowser_flame_initialization  ; skip this part to finish setting values

bra_smb2_main_spawn_flame_from_bowser_mouth:
    LDA Enemy_X_Position,y  ; get bowser's horizontal position
    SEC
    SBC #$0e  ; subtract 14 pixels
    STA Enemy_X_Position,x  ; save as flame's horizontal position
    LDA Enemy_PageLoc,y
    STA Enemy_PageLoc,x  ; copy page location from bowser to flame
    LDA Enemy_Y_Position,y
    CLC  ; add 8 pixels to bowser's vertical position
    ADC #$08
    STA Enemy_Y_Position,x  ; save as flame's vertical position
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get 2 LSB from first part of LSFR
    STA Enemy_YMF_Dummy,x  ; save here
    TAY  ; use as offset
    LDA off_smb2_main_bowser_flame_target_y_positions,y  ; get value here using bits as offset
    LDY #$00  ; load default offset
    CMP Enemy_Y_Position,x  ; compare value to flame's current vertical position
    BCC bra_smb2_main_set_bowser_flame_y_force  ; if less, do not increment offset
    INY  ; otherwise increment now
bra_smb2_main_set_bowser_flame_y_force:
    LDA off_smb2_main_bowser_flame_y_force_adjustments,y  ; get value here and save
    STA Enemy_Y_MoveForce,x  ; to vertical movement force
    LDA #$00
    STA EnemyFrenzyBuffer  ; clear enemy frenzy buffer

loc_smb2_main_finish_bowser_flame_initialization:
    LDA #$08  ; set $08 for bounding box control
    STA Enemy_BoundBoxCtrl,x
    LDA #$01  ; set high byte of vertical and
    STA Enemy_Y_HighPos,x  ; enemy buffer flag
    STA Enemy_Flag,x
    LSR
    STA Enemy_X_MoveForce,x  ; initialize horizontal movement force, and
    STA Enemy_State,x  ; enemy state
    RTS

; --------------------------------

off_smb2_main_fireworks_x_offsets:
    .byte $00, $30, $60, $60, $00, $20

off_smb2_main_fireworks_y_positions:
    .byte $60, $40, $70, $40, $60, $30

handler_smb2_main_initialize_fireworks:
    LDA FrenzyEnemyTimer  ; if timer not expired yet, branch to leave
    BNE bra_smb2_main_exit_fireworks_initialization
    LDA #$20  ; otherwise reset timer
    STA FrenzyEnemyTimer
    DEC FireworksCounter  ; decrement for each explosion
    LDY #$06  ; start at last slot
bra_smb2_main_find_star_flag_for_fireworks:
    DEY
    LDA Enemy_ID,y  ; check for presence of star flag object
    CMP #StarFlagObject  ; if there isn't a star flag object,
    BNE bra_smb2_main_find_star_flag_for_fireworks  ; routine goes into infinite loop = crash
    LDA Enemy_X_Position,y
    SEC  ; get horizontal coordinate of star flag object, then
    SBC #$30  ; subtract 48 pixels from it and save to
    PHA  ; the stack
    LDA Enemy_PageLoc,y
    SBC #$00  ; subtract the carry from the page location
    STA $00  ; of the star flag object
    LDA FireworksCounter  ; get fireworks counter
    CLC
    ADC Enemy_State,y  ; add state of star flag object (possibly not necessary)
    TAY  ; use as offset
    PLA  ; get saved horizontal coordinate of star flag - 48 pixels
    CLC
    ADC off_smb2_main_fireworks_x_offsets,y  ; add number based on offset of fireworks counter
    STA Enemy_X_Position,x  ; store as the fireworks object horizontal coordinate
    LDA $00
    ADC #$00  ; add carry and store as page location for
    STA Enemy_PageLoc,x  ; the fireworks object
    LDA off_smb2_main_fireworks_y_positions,y  ; get vertical position using same offset
    STA Enemy_Y_Position,x  ; and store as vertical coordinate for fireworks object
    LDA #$01
    STA Enemy_Y_HighPos,x  ; store in vertical high byte
    STA Enemy_Flag,x  ; and activate enemy buffer flag
    LSR
    STA ExplosionGfxCounter,x  ; initialize explosion counter
    LDA #$08
    STA ExplosionTimerCounter,x  ; set explosion timing counter
bra_smb2_main_exit_fireworks_initialization:
    RTS

; --------------------------------

tbl_smb2_main_enemy_slot_bit_masks:
    .byte %00000001, %00000010, %00000100, %00001000, %00010000, %00100000, %01000000, %10000000

off_smb2_main_frenzy_enemy_y_positions:
    .byte $40, $30, $90, $50, $20, $60, $a0, $70

off_smb2_main_swimming_cheep_cheep_ids:
    .byte $0a, $0b

handler_smb2_main_spawn_bullet_bill_or_cheep_cheep:
    LDA FrenzyEnemyTimer  ; if timer not expired yet, branch to leave
    BNE bra_smb2_main_exit_frenzy_enemy_spawn
    LDA AreaType  ; are we in a water-type level?
    BNE bra_smb2_main_spawn_bullet_bill_frenzy  ; if not, branch elsewhere
    CPX #$03  ; are we past third enemy slot?
    BCS bra_smb2_main_exit_frenzy_enemy_spawn  ; if so, branch to leave
    LDY #$00  ; load default offset
    LDA PseudoRandomBitReg,x
    CMP #$aa  ; check first part of LSFR against preset value
    BCC bra_smb2_main_select_swimming_cheep_cheep_variant  ; if less than preset, do not increment offset
    INY  ; otherwise increment
bra_smb2_main_select_swimming_cheep_cheep_variant:
    LDA WorldNumber  ; check world number
    CMP #World2
    BEQ bra_smb2_main_load_swimming_cheep_cheep_id  ; if we're on world 2, do not increment offset
    INY  ; otherwise increment
bra_smb2_main_load_swimming_cheep_cheep_id:
    TYA
    AND #%00000001  ; mask out all but last bit of offset
    TAY
    LDA off_smb2_main_swimming_cheep_cheep_ids,y  ; load identifier for cheep-cheeps
bra_smb2_main_store_generated_frenzy_enemy_id:
    STA Enemy_ID,x  ; store whatever's in A as enemy identifier
    LDA BitMFilter
    CMP #$ff  ; if not all bits set, skip init part and compare bits
    BNE bra_smb2_main_select_frenzy_enemy_y_slot
    LDA #$00  ; initialize vertical position filter
    STA BitMFilter
bra_smb2_main_select_frenzy_enemy_y_slot:
    LDA PseudoRandomBitReg,x  ; get first part of LSFR
    AND #%00000111  ; mask out all but 3 LSB
loc_smb2_main_find_unused_frenzy_enemy_y_slot:
    TAY  ; use as offset
    LDA tbl_smb2_main_enemy_slot_bit_masks,y  ; load bitmask
    BIT BitMFilter  ; perform AND on filter without changing it
    BEQ bra_smb2_main_reserve_frenzy_enemy_y_slot
    INY  ; increment offset
    TYA
    AND #%00000111  ; mask out all but 3 LSB thus keeping it 0-7
    JMP loc_smb2_main_find_unused_frenzy_enemy_y_slot  ; do another check
bra_smb2_main_reserve_frenzy_enemy_y_slot:
    ORA BitMFilter  ; add bit to already set bits in filter
    STA BitMFilter  ; and store
    LDA off_smb2_main_frenzy_enemy_y_positions,y  ; load vertical position using offset
    JSR sub_smb2_main_put_at_right_extent  ; set vertical position and other values
    STA Enemy_YMF_Dummy,x  ; initialize dummy variable
    LDA #$20  ; set timer
    STA FrenzyEnemyTimer
    JMP sub_smb2_main_checkpoint_enemy_id  ; process our new enemy object

bra_smb2_main_spawn_bullet_bill_frenzy:
    LDY #$ff  ; start at beginning of enemy slots
bra_smb2_main_find_active_frenzy_bullet_bill:
    INY  ; move onto the next slot
    CPY #$05  ; branch to play sound if we've done all slots
    BCS bra_smb2_main_fire_frenzy_bullet_bill
    LDA Enemy_Flag,y  ; if enemy buffer flag not set,
    BEQ bra_smb2_main_find_active_frenzy_bullet_bill  ; loop back and check another slot
    LDA Enemy_ID,y
    CMP #BulletBill_FrenzyVar  ; check enemy identifier for
    BNE bra_smb2_main_find_active_frenzy_bullet_bill  ; bullet bill object (frenzy variant)
bra_smb2_main_exit_frenzy_enemy_spawn:
    RTS  ; if found, leave

bra_smb2_main_fire_frenzy_bullet_bill:
    LDA Square2SoundQueue
    ORA #Sfx_Blast  ; play fireworks/gunfire sound
    STA Square2SoundQueue
    LDA #BulletBill_FrenzyVar  ; load identifier for bullet bill object
    BNE bra_smb2_main_store_generated_frenzy_enemy_id  ; unconditional branch

; --------------------------------
; $00 - used to store Y position of group enemies
; $01 - used to store enemy ID
; $02 - used to store page location of right side of screen
; $03 - used to store X position of right side of screen

loc_smb2_main_spawn_enemy_group:
    LDY #$00  ; load value for green koopa troopa
    SEC
    SBC #$37  ; subtract $37 from second byte read
    PHA  ; save result in stack for now
    CMP #$04  ; was byte in $3b-$3e range?
    BCS bra_smb2_main_store_group_enemy_type  ; if so, branch
    PHA  ; save another copy to stack
    LDY #Goomba  ; load value for goomba enemy
    LDA PrimaryHardMode  ; if primary hard mode flag not set,
    BEQ bra_smb2_main_restore_group_enemy_type  ; branch, otherwise change to value
    LDY #BuzzyBeetle  ; for buzzy beetle
bra_smb2_main_restore_group_enemy_type:
    PLA  ; get second copy from stack
bra_smb2_main_store_group_enemy_type:
    STY $01  ; save enemy id here
    LDY #$b0  ; load default y coordinate
    AND #$02  ; check to see if d1 was set
    BEQ bra_smb2_main_store_group_enemy_y_position  ; if so, move y coordinate up,
    LDY #$70  ; otherwise branch and use default
bra_smb2_main_store_group_enemy_y_position:
    STY $00  ; save y coordinate here
    LDA ScreenRight_PageLoc  ; get page number of right edge of screen
    STA $02  ; save here
    LDA ScreenRight_X_Pos  ; get pixel coordinate of right edge
    STA $03  ; save here
    LDY #$02  ; load two enemies by default
    PLA  ; get first copy from stack
    LSR  ; check to see if d0 was set
    BCC bra_smb2_main_store_group_enemy_count  ; if not, use default value
    INY  ; otherwise increment to three enemies
bra_smb2_main_store_group_enemy_count:
    STY NumberofGroupEnemies  ; save number of enemies here
bra_smb2_main_spawn_enemy_group_loop:
    LDX #$ff  ; start at beginning of enemy buffers
bra_smb2_main_find_enemy_group_slot:
    INX  ; increment and branch if past
    CPX #$05  ; end of buffers
    BCS bra_smb2_main_finish_enemy_group_command
    LDA Enemy_Flag,x  ; check to see if enemy is already
    BNE bra_smb2_main_find_enemy_group_slot  ; stored in buffer, and branch if so
    LDA $01
    STA Enemy_ID,x  ; store enemy object identifier
    LDA $02
    STA Enemy_PageLoc,x  ; store page location for enemy object
    LDA $03
    STA Enemy_X_Position,x  ; store x coordinate for enemy object
    CLC
    ADC #$18  ; add 24 pixels for next enemy
    STA $03
    LDA $02  ; add carry to page location for
    ADC #$00  ; next enemy
    STA $02
    LDA $00  ; store y coordinate for enemy object
    STA Enemy_Y_Position,x
    LDA #$01  ; activate flag for buffer, and
    STA Enemy_Y_HighPos,x  ; put enemy within the screen vertically
    STA Enemy_Flag,x
    JSR sub_smb2_main_checkpoint_enemy_id  ; process each enemy object separately
    DEC NumberofGroupEnemies  ; do this until we run out of enemy objects
    BNE bra_smb2_main_spawn_enemy_group_loop
bra_smb2_main_finish_enemy_group_command:
    JMP bra_smb2_main_advance_enemy_stream_two_bytes  ; jump to increment data offset and leave

; --------------------------------
; $00 - used to store piranha plant attribute data
; $01 - used to store piranha plant range data for player
