tbl_smb2_main_flying_cheep_cheep_y_reference_offsets:
    .byte $f8, $a0, $70, $bd, $00

tbl_smb2_main_flying_cheep_cheep_background_priorities:
    .byte $20, $20, $20, $00, $00

handler_smb2_main_move_flying_cheep_cheep:
    LDA Enemy_State,x  ; check cheep-cheep's enemy state
    AND #%00100000  ; for d5 set
    BEQ bra_smb2_main_move_active_flying_cheep_cheep  ; branch to continue code if not set
    LDA #$00
    STA Enemy_SprAttrib,x  ; otherwise clear sprite attributes
    JMP sub_smb2_main_move_enemy_with_gravity  ; and jump to move defeated cheep-cheep downwards
bra_smb2_main_move_active_flying_cheep_cheep:
    JSR sub_smb2_main_move_enemy_horizontally  ; move cheep-cheep horizontally based on speed and force
    LDY #$0d  ; set vertical movement amount
    LDA #$05  ; set maximum speed
    JSR sub_smb2_main_apply_enemy_vertical_motion  ; branch to impose gravity on flying cheep-cheep
    LDA Enemy_Y_MoveForce,x
    LSR  ; get vertical movement force and
    LSR  ; move high nybble to low
    LSR
    LSR
    TAY  ; save as offset (note this tends to go into reach of code)
    LDA Enemy_Y_Position,x  ; get vertical position
    SEC  ; subtract pseudorandom value based on offset from position
    SBC tbl_smb2_main_flying_cheep_cheep_y_reference_offsets,y
    BPL bra_smb2_main_normalize_flying_cheep_cheep_y_error  ; if result within top half of screen, skip this part
    EOR #$ff
    CLC  ; otherwise get two's compliment
    ADC #$01
bra_smb2_main_normalize_flying_cheep_cheep_y_error:
    CMP #$08  ; if result or two's compliment greater than eight,
    BCS bra_smb2_main_store_unused_flying_cheep_cheep_attributes  ; skip to the end without changing movement force
    LDA Enemy_Y_MoveForce,x
    CLC
    ADC #$10  ; otherwise add to it
    STA Enemy_Y_MoveForce,x
    LSR  ; move high nybble to low again
    LSR
    LSR
    LSR
    TAY
bra_smb2_main_store_unused_flying_cheep_cheep_attributes:
    LDA tbl_smb2_main_flying_cheep_cheep_background_priorities,y  ; load bg priority data and store (this is very likely
    STA Enemy_SprAttrib,x  ; broken or residual code, value is overwritten before
    RTS  ; drawing it next frame), then leave

; --------------------------------
; $00 - used to hold horizontal difference
; $01-$03 - used to hold difference adjusters

tbl_smb2_main_lakitu_player_distance_adjustments:
    .byte $15, $30, $40

handler_smb2_main_move_lakitu:
    LDA Enemy_State,x  ; check lakitu's enemy state
    AND #%00100000  ; for d5 set
    BEQ bra_smb2_main_update_lakitu_state  ; if not set, continue with code
    JMP sub_smb2_main_move_enemy_downward_fast  ; otherwise jump to move defeated lakitu downwards
bra_smb2_main_update_lakitu_state:
    LDA Enemy_State,x  ; if lakitu's enemy state not set at all,
    BEQ bra_smb2_main_prepare_lakitu_chase  ; go ahead and continue with code
    LDA #$00
    STA LakituMoveDirection,x  ; otherwise initialize moving direction to move to left
    STA EnemyFrenzyBuffer  ; initialize frenzy buffer
    LDA #$10
    BNE bra_smb2_main_store_lakitu_move_speed  ; load horizontal speed and do unconditional branch
bra_smb2_main_prepare_lakitu_chase:
    LDA #Spiny
    STA EnemyFrenzyBuffer  ; set spiny identifier in frenzy buffer
    LDY #$02
bra_smb2_main_copy_lakitu_distance_adjustments:
    LDA tbl_smb2_main_lakitu_player_distance_adjustments,y  ; load values
    STA $0001,y  ; store in zero page
    DEY
    BPL bra_smb2_main_copy_lakitu_distance_adjustments  ; do this until all values are stired
    JSR sub_smb2_main_player_lakitu_diff  ; execute sub to set speed and create spinys
bra_smb2_main_store_lakitu_move_speed:
    STA LakituMoveSpeed,x  ; set movement speed returned from sub
    LDY #$01  ; set moving direction to right by default
    LDA LakituMoveDirection,x
    AND #$01  ; get LSB of moving direction
    BNE bra_smb2_main_move_lakitu_horizontally  ; if set, branch to the end to use moving direction
    LDA LakituMoveSpeed,x
    EOR #$ff  ; get two's compliment of moving speed
    CLC
    ADC #$01
    STA LakituMoveSpeed,x  ; store as new moving speed
    INY  ; increment moving direction to left
bra_smb2_main_move_lakitu_horizontally:
    STY Enemy_MovingDir,x  ; store moving direction
    JMP sub_smb2_main_move_enemy_horizontally  ; move lakitu horizontally

sub_smb2_main_player_lakitu_diff:
    LDY #$00  ; set Y for default value
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between enemy and player
    BPL bra_smb2_main_check_lakitu_player_distance  ; branch if enemy is to the right of the player
    INY  ; increment Y for left of player
    LDA $00
    EOR #$ff  ; get two's compliment of low byte of horizontal difference
    CLC
    ADC #$01  ; store two's compliment as horizontal difference
    STA $00
bra_smb2_main_check_lakitu_player_distance:
    LDA $00  ; get low byte of horizontal difference
    CMP #$3c  ; if within a certain distance of player, branch
    BCC bra_smb2_main_adjust_lakitu_speed_for_player
    LDA #$3c  ; otherwise set maximum distance
    STA $00
    LDA Enemy_ID,x  ; check if lakitu is in our current enemy slot
    CMP #Lakitu
    BNE bra_smb2_main_adjust_lakitu_speed_for_player  ; if not, branch elsewhere
    TYA  ; compare contents of Y, now in A
    CMP LakituMoveDirection,x  ; to what is being used as horizontal movement direction
    BEQ bra_smb2_main_adjust_lakitu_speed_for_player  ; if moving toward the player, branch, do not alter
    LDA LakituMoveDirection,x  ; if moving to the left beyond maximum distance,
    BEQ bra_smb2_main_set_lakitu_chase_direction  ; branch and alter without delay
    DEC LakituMoveSpeed,x  ; decrement horizontal speed
    LDA LakituMoveSpeed,x  ; if horizontal speed not yet at zero, branch to leave
    BNE bra_smb2_main_exit_lakitu_movement
bra_smb2_main_set_lakitu_chase_direction:
    TYA  ; set horizontal direction depending on horizontal
    STA LakituMoveDirection,x  ; difference between enemy and player if necessary
bra_smb2_main_adjust_lakitu_speed_for_player:
    LDA $00
    AND #%00111100  ; mask out all but four bits in the middle
    LSR  ; divide masked difference by four
    LSR
    STA $00  ; store as new value
    LDY #$00  ; init offset
    LDA Player_X_Speed
    BEQ bra_smb2_main_compute_lakitu_chase_speed  ; if player not moving horizontally, branch
    LDA ScrollAmount
    BEQ bra_smb2_main_compute_lakitu_chase_speed  ; if scroll speed not set, branch to same place
    INY  ; otherwise increment offset
    LDA Player_X_Speed
    CMP #$19  ; if player not running, branch
    BCC bra_smb2_main_adjust_spiny_throw_speed
    LDA ScrollAmount
    CMP #$02  ; if scroll speed below a certain amount, branch
    BCC bra_smb2_main_adjust_spiny_throw_speed  ; to same place
    INY  ; otherwise increment once more
bra_smb2_main_adjust_spiny_throw_speed:
    LDA Enemy_ID,x  ; check for spiny object
    CMP #Spiny
    BNE bra_smb2_main_adjust_enemy_chase_speed  ; branch if not found
    LDA Player_X_Speed  ; if player not moving, skip this part
    BNE bra_smb2_main_compute_lakitu_chase_speed
bra_smb2_main_adjust_enemy_chase_speed:
    LDA Enemy_Y_Speed,x  ; check vertical speed
    BNE bra_smb2_main_compute_lakitu_chase_speed  ; branch if nonzero
    LDY #$00  ; otherwise reinit offset
bra_smb2_main_compute_lakitu_chase_speed:
    LDA $0001,y  ; get one of three saved values from earlier
    LDY $00  ; get saved horizontal difference
bra_smb2_main_subtract_lakitu_distance_pixels:
    SEC  ; subtract one for each pixel of horizontal difference
    SBC #$01  ; from one of three saved values
    DEY
    BPL bra_smb2_main_subtract_lakitu_distance_pixels  ; branch until all pixels are subtracted, to adjust difference
bra_smb2_main_exit_lakitu_movement:
    RTS  ; leave!!!

; -------------------------------------------------------------------------------------
; $04-$05 - used to store name table address in little endian order

off_smb2_main_bridge_collapse_vram_addresses_low:
    .byte $1a  ; axe
    .byte $58  ; chain
    .byte $98, $96, $94, $92, $90, $8e, $8c  ; bridge
    .byte $8a, $88, $86, $84, $82, $80

handler_smb2_main_bridge_collapse:
    LDX BowserFront_Offset  ; get enemy offset for bowser
    LDA Enemy_ID,x  ; check enemy object identifier for bowser
    CMP #Bowser  ; if not found, branch ahead,
    BNE bra_smb2_main_finish_bridge_collapse  ; metatile removal not necessary
    STX ObjectOffset  ; store as enemy offset here
    LDA Enemy_State,x  ; if bowser in normal state, skip all of this
    BEQ bra_smb2_main_remove_next_bridge_metatile
    AND #%01000000  ; if bowser's state has d6 clear, skip to silence music
    BEQ bra_smb2_main_finish_bridge_collapse
    LDA Enemy_Y_Position,x  ; check bowser's vertical coordinate
    CMP #$e0  ; if bowser not yet low enough, skip this part ahead
    BCC bra_smb2_main_move_defeated_bowser
bra_smb2_main_finish_bridge_collapse:
    LDA #Silence  ; silence music
    STA EventMusicQueue
    INC OperMode_Task  ; move onto next secondary mode in victory mode
    JMP sub_smb2_main_kill_all_enemies  ; jump to empty all enemy slots and then leave

bra_smb2_main_move_defeated_bowser:
    JSR sub_smb2_main_move_enemy_downward_slow  ; do a sub to move bowser downwards
    JMP bra_smb2_main_process_bowser_graphics  ; jump to draw bowser's front and rear, then leave

bra_smb2_main_remove_next_bridge_metatile:
    DEC BowserFeetCounter  ; decrement timer to control bowser's feet
    BNE bra_smb2_main_render_bowser_during_bridge_collapse  ; if not expired, skip all of this
    LDA #$04
    STA BowserFeetCounter  ; otherwise, set timer now
    LDA BowserBodyControls
    EOR #$01  ; invert bit to control bowser's feet
    STA BowserBodyControls
    LDA #$22  ; put high byte of name table address here for now
    STA $05
    LDY BridgeCollapseOffset  ; get bridge collapse offset here
    LDA off_smb2_main_bridge_collapse_vram_addresses_low,y  ; load low byte of name table address and store here
    STA $04
    LDY VRAM_Buffer1_Offset  ; increment vram buffer offset
    INY
    LDX #$0c  ; set offset for tile data for sub to draw blank metatile
    JSR sub_smb2_main_write_block_or_bridge_metatile  ; do sub here to remove bowser's bridge metatiles
    LDX ObjectOffset  ; get enemy offset
    JSR sub_smb2_main_advance_primary_vram_buffer_offset  ; set new vram buffer offset
    LDA #Sfx_Blast  ; load the fireworks/gunfire sound into the square 2 sfx
    STA Square2SoundQueue  ; queue while at the same time loading the brick
    LDA #Sfx_BrickShatter  ; shatter sound into the noise sfx queue thus
    STA NoiseSoundQueue  ; producing the unique sound of the bridge collapsing
    INC BridgeCollapseOffset  ; increment bridge collapse offset
    LDA BridgeCollapseOffset
    CMP #$0f  ; if bridge collapse offset has not yet reached
    BNE bra_smb2_main_render_bowser_during_bridge_collapse  ; the end, go ahead and skip this part
    JSR sub_smb2_main_clear_enemy_vertical_motion  ; initialize whatever vertical speed bowser has
    LDA #%01000000
    STA Enemy_State,x  ; set bowser's state to one of defeated states (d6 set)
    LDA #Sfx_BowserFall
    STA Square2SoundQueue  ; play bowser defeat sound
bra_smb2_main_render_bowser_during_bridge_collapse:
    JMP bra_smb2_main_process_bowser_graphics  ; jump to code that draws bowser

; --------------------------------

tbl_smb2_main_bowser_movement_range_limits:
    .byte $21, $41, $11, $31

handler_smb2_main_run_bowser:
    LDA Enemy_State,x  ; if d5 in enemy state is not set
    AND #%00100000  ; then branch elsewhere to run bowser
    BEQ bra_smb2_main_update_bowser
    LDA Enemy_Y_Position,x  ; otherwise check vertical position
    CMP #$e0  ; if above a certain point, branch to move defeated bowser
    BCC bra_smb2_main_move_defeated_bowser  ; otherwise proceed to KillAllEnemies

sub_smb2_main_kill_all_enemies:
    LDX #$04  ; start with last enemy slot
bra_smb2_main_kill_all_enemies_loop:
    JSR sub_smb2_main_erase_enemy_object  ; branch to kill enemy objects
    DEX  ; move onto next enemy slot
    BPL bra_smb2_main_kill_all_enemies_loop  ; do this until all slots are emptied
    STA EnemyFrenzyBuffer  ; empty frenzy buffer
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

bra_smb2_main_update_bowser:
    LDA #$00
    STA EnemyFrenzyBuffer  ; empty frenzy buffer
    LDA TimerControl  ; if master timer control not set,
    BEQ bra_smb2_main_update_bowser_body  ; skip jump and execute code here
    JMP loc_smb2_main_enter_bowser_fire_breath_check  ; otherwise, jump over a bunch of code
bra_smb2_main_update_bowser_body:
    LDA BowserBodyControls  ; check bowser's mouth
    BPL bra_smb2_main_update_bowser_feet_animation  ; if bit clear, go ahead with code here
    JMP bra_smb2_main_update_bowser_jump_and_hammers  ; otherwise skip a whole section starting here
bra_smb2_main_update_bowser_feet_animation:
    DEC BowserFeetCounter  ; decrement timer to control bowser's feet
    BNE bra_smb2_main_update_bowser_facing  ; if not expired, skip this part
    LDA #$20  ; otherwise, reset timer
    STA BowserFeetCounter
    LDA BowserBodyControls  ; and invert bit used
    EOR #%00000001  ; to control bowser's feet
    STA BowserBodyControls
bra_smb2_main_update_bowser_facing:
    LDA FrameCounter  ; check frame counter
    AND #%00001111  ; if not on every sixteenth frame, skip
    BNE bra_smb2_main_face_bowser_toward_player  ; ahead to continue code
    LDA #$02  ; otherwise reset moving/facing direction every
    STA Enemy_MovingDir,x  ; sixteen frames
bra_smb2_main_face_bowser_toward_player:
    LDA EnemyFrameTimer,x  ; if timer set here expired,
    BEQ bra_smb2_main_update_bowser_patrol  ; branch to next section
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between player and bowser,
    BPL bra_smb2_main_update_bowser_patrol  ; and branch if bowser to the right of the player
    LDA #$01
    STA Enemy_MovingDir,x  ; set bowser to move and face to the right
    LDA #$02
    STA BowserMovementSpeed  ; set movement speed
    LDA #$20
    STA EnemyFrameTimer,x  ; set timer here
    STA BowserFireBreathTimer  ; set timer used for bowser's flame
    LDA Enemy_X_Position,x
    CMP #$c8  ; if bowser to the right past a certain point,
    BCS bra_smb2_main_update_bowser_jump_and_hammers  ; skip ahead to some other section
bra_smb2_main_update_bowser_patrol:
    LDA FrameCounter  ; get frame counter
    AND #%00000011
    BNE bra_smb2_main_update_bowser_jump_and_hammers  ; execute this code every fourth frame, otherwise branch
    LDA Enemy_X_Position,x
    CMP BowserOrigXPos  ; if bowser not at original horizontal position,
    BNE bra_smb2_main_move_bowser_horizontally  ; branch to skip this part
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get pseudorandom offset
    TAY
    LDA tbl_smb2_main_bowser_movement_range_limits,y  ; load value using pseudorandom offset
    STA MaxRangeFromOrigin  ; and store here
bra_smb2_main_move_bowser_horizontally:
    LDA Enemy_X_Position,x
    CLC  ; add movement speed to bowser's horizontal
    ADC BowserMovementSpeed  ; coordinate and save as new horizontal position
    STA Enemy_X_Position,x
    LDY Enemy_MovingDir,x
    CPY #$01  ; if bowser moving and facing to the right, skip ahead
    BEQ bra_smb2_main_update_bowser_jump_and_hammers
    LDY #$ff  ; set default movement speed here (move left)
    SEC  ; get difference of current vs. original
    SBC BowserOrigXPos  ; horizontal position
    BPL bra_smb2_main_check_bowser_patrol_limit  ; if current position to the right of original, skip ahead
    EOR #$ff
    CLC  ; get two's compliment
    ADC #$01
    LDY #$01  ; set alternate movement speed here (move right)
bra_smb2_main_check_bowser_patrol_limit:
    CMP MaxRangeFromOrigin  ; compare difference with pseudorandom value
    BCC bra_smb2_main_update_bowser_jump_and_hammers  ; if difference < pseudorandom value, leave speed alone
    STY BowserMovementSpeed  ; otherwise change bowser's movement speed
bra_smb2_main_update_bowser_jump_and_hammers:
    LDA EnemyFrameTimer,x  ; if timer set here not expired yet, skip ahead to
    BNE bra_smb2_main_start_bowser_jump_if_due  ; some other section of code
    JSR sub_smb2_main_move_enemy_downward_slow  ; otherwise start by moving bowser downwards
    LDA WorldNumber  ; check world number
    CMP #World6
    BCC bra_smb2_main_schedule_bowser_jump  ; if world 1-5, skip this part (not time to throw hammers yet)
    LDA FrameCounter
    AND #%00000011  ; check to see if it's time to execute sub
    BNE bra_smb2_main_schedule_bowser_jump  ; if not, skip sub, otherwise
    JSR sub_smb2_main_spawn_hammer_object  ; execute sub on every fourth frame to spawn hammer
bra_smb2_main_schedule_bowser_jump:
    LDA Enemy_Y_Position,x  ; get current vertical position
    CMP #$80  ; if still above a certain point
    BCC bra_smb2_main_check_bowser_fire_breath  ; then skip to world number check for flames
    LDA PseudoRandomBitReg,x
    AND #%00000011  ; get pseudorandom offset
    TAY
    LDA tbl_smb2_main_bowser_movement_range_limits,y  ; get value using pseudorandom offset
    STA EnemyFrameTimer,x  ; set for timer here
loc_smb2_main_enter_bowser_fire_breath_check:
    JMP bra_smb2_main_check_bowser_fire_breath  ; jump to execute flames code
bra_smb2_main_start_bowser_jump_if_due:
    CMP #$01  ; if timer not yet about to expire,
    BNE bra_smb2_main_check_bowser_fire_breath  ; skip ahead to next part
    DEC Enemy_Y_Position,x  ; otherwise decrement vertical coordinate
    JSR sub_smb2_main_clear_enemy_vertical_motion  ; initialize movement amount
    LDA #$fe
    STA Enemy_Y_Speed,x  ; set vertical speed to move bowser upwards
bra_smb2_main_check_bowser_fire_breath:
    LDA WorldNumber  ; check world number here
    CMP #World8  ; world 8?
    BEQ bra_smb2_main_update_bowser_fire_breath  ; if so, execute this part here
    CMP #World6  ; world 6-7?
    BCS bra_smb2_main_process_bowser_graphics  ; if so, skip this part here
bra_smb2_main_update_bowser_fire_breath:
    LDA BowserFireBreathTimer  ; check timer here
    BNE bra_smb2_main_process_bowser_graphics  ; if not expired yet, skip all of this
    LDA #$20
    STA BowserFireBreathTimer  ; set timer here
    LDA BowserBodyControls
    EOR #%10000000  ; invert bowser's mouth bit to open
    STA BowserBodyControls  ; and close bowser's mouth
    BMI bra_smb2_main_check_bowser_fire_breath  ; if bowser's mouth open, loop back
    JSR sub_smb2_main_set_flame_timer  ; get timing for bowser's flame
    LDY SecondaryHardMode
    BEQ bra_smb2_main_queue_bowser_flame  ; if secondary hard mode flag not set, skip this
    SEC
    SBC #$10  ; otherwise subtract from value in A
bra_smb2_main_queue_bowser_flame:
    STA BowserFireBreathTimer  ; set value as timer here
    LDA #BowserFlame  ; put bowser's flame identifier
    STA EnemyFrenzyBuffer  ; in enemy frenzy buffer

; --------------------------------

bra_smb2_main_process_bowser_graphics:
    JSR sub_smb2_main_process_bowser_half  ; do a sub here to process bowser's front
    LDY #$10  ; load default value here to position bowser's rear
    LDA Enemy_MovingDir,x  ; check moving direction
    LSR
    BCC bra_smb2_main_position_bowser_rear  ; if moving left, use default
    LDY #$f0  ; otherwise load alternate positioning value here
bra_smb2_main_position_bowser_rear:
    TYA  ; move bowser's rear object position value to A
    CLC
    ADC Enemy_X_Position,x  ; add to bowser's front object horizontal coordinate
    LDY DuplicateObj_Offset  ; get bowser's rear object offset
    STA Enemy_X_Position,y  ; store A as bowser's rear horizontal coordinate
    LDA Enemy_Y_Position,x
    CLC  ; add eight pixels to bowser's front object
    ADC #$08  ; vertical coordinate and store as vertical coordinate
    STA Enemy_Y_Position,y  ; for bowser's rear
    LDA Enemy_State,x
    STA Enemy_State,y  ; copy enemy state directly from front to rear
    LDA Enemy_MovingDir,x
    STA Enemy_MovingDir,y  ; copy moving direction also
    LDA ObjectOffset  ; save enemy object offset of front to stack
    PHA
    LDX DuplicateObj_Offset  ; put enemy object offset of rear as current
    STX ObjectOffset
    LDA #Bowser  ; set bowser's enemy identifier
    STA Enemy_ID,x  ; store in bowser's rear object
    JSR sub_smb2_main_process_bowser_half  ; do a sub here to process bowser's rear
    PLA
    STA ObjectOffset  ; get original enemy object offset
    TAX
    LDA #$00  ; nullify bowser's front/rear graphics flag
    STA BowserGfxFlag
bra_smb2_main_exit_bowser_graphics_handler:
    RTS  ; leave!

sub_smb2_main_process_bowser_half:
    INC BowserGfxFlag  ; increment bowser's graphics flag, then run subroutines
    JSR sub_smb2_main_run_retainer_obj  ; to get offscreen bits, relative position and draw bowser (finally!)
    LDA Enemy_State,x
    BNE bra_smb2_main_exit_bowser_graphics_handler  ; if either enemy object not in normal state, branch to leave
    LDA #$0a
    STA Enemy_BoundBoxCtrl,x  ; set bounding box size control
    JSR sub_smb2_main_get_enemy_bound_box  ; get bounding box coordinates
    JMP sub_smb2_main_player_enemy_collision  ; do player-to-enemy collision detection

; -------------------------------------------------------------------------------------
; $00 - used to hold movement force and tile number
; $01 - used to hold sprite attribute data
