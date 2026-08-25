; --------------------------------

FirebarSpinSpdData:
    .byte $28, $38, $28, $38, $28

FirebarSpinDirData:
    .byte $00, $00, $10, $10, $00

InitLongFirebar:
    JSR sub_duplicate_enemy_obj  ; create enemy object for long firebar

InitShortFirebar:
    LDA #$00  ; initialize low byte of spin state
    STA ram_firebar_spin_state_low,x
    LDA ram_enemy_id,x  ; subtract $1b from enemy identifier
    SEC  ; to get proper offset for firebar data
    SBC #$1b
    TAY
    LDA FirebarSpinSpdData,y  ; get spinning speed of firebar
    STA ram_firebar_spin_speed,x
    LDA FirebarSpinDirData,y  ; get spinning direction of firebar
    STA ram_firebar_spin_direction,x
    LDA ram_enemy_y_position,x
    CLC  ; add four pixels to vertical coordinate
    ADC #$04
    STA ram_enemy_y_position,x
    LDA ram_enemy_x_position,x
    CLC  ; add four pixels to horizontal coordinate
    ADC #$04
    STA ram_enemy_x_position,x
    LDA ram_enemy_page_loc,x
    ADC #$00  ; add carry to page location
    STA ram_enemy_page_loc,x
    JMP TallBBox2  ; set bounding box control (not used) and leave

; --------------------------------
; $00-$01 - used to hold pseudorandom bits

FlyCCXPositionData:
    .byte $80, $30, $40, $80
    .byte $30, $50, $50, $70
    .byte $20, $40, $80, $a0
    .byte $70, $40, $90, $68

FlyCCXSpeedData:
    .byte $0e, $05, $06, $0e
    .byte $1c, $20, $10, $0c
    .byte $1e, $22, $18, $14

FlyCCTimerData:
    .byte $10, $60, $20, $48

InitFlyingCheepCheep:
    LDA ram_frenzy_enemy_timer  ; if timer here not expired yet, branch to leave
    BNE ChpChpEx
    JSR sub_small_b_box  ; jump to set bounding box size $09 and init other values
    LDA ram_pseudo_random_bit_reg+1,x
    AND #%00000011  ; set pseudorandom offset here
    TAY
    LDA FlyCCTimerData,y  ; load timer with pseudorandom offset
    STA ram_frenzy_enemy_timer
    LDY #$03  ; load Y with default value
    LDA ram_secondary_hard_mode
    BEQ MaxCC  ; if secondary hard mode flag not set, do not increment Y
    INY  ; otherwise, increment Y to allow as many as four onscreen
MaxCC:
    STY $00  ; store whatever pseudorandom bits are in Y
    CPX $00  ; compare enemy object buffer offset with Y
    BCS ChpChpEx  ; if X => Y, branch to leave
    LDA ram_pseudo_random_bit_reg,x
    AND #%00000011  ; get last two bits of LSFR, first part
    STA $00  ; and store in two places
    STA $01
    LDA #$fb  ; set vertical speed for cheep-cheep
    STA ram_enemy_y_speed,x
    LDA #$00  ; load default value
    LDY ram_player_x_speed  ; check player's horizontal speed
    BEQ GSeed  ; if player not moving left or right, skip this part
    LDA #$04
    CPY #$19  ; if moving to the right but not very quickly,
    BCC GSeed  ; do not change A
    ASL  ; otherwise, multiply A by 2
GSeed:
    PHA  ; save to stack
    CLC
    ADC $00  ; add to last two bits of LSFR we saved earlier
    STA $00  ; save it there
    LDA ram_pseudo_random_bit_reg+1,x
    AND #%00000011  ; if neither of the last two bits of second LSFR set,
    BEQ RSeed  ; skip this part and save contents of $00
    LDA ram_pseudo_random_bit_reg+2,x
    AND #%00001111  ; otherwise overwrite with lower nybble of
    STA $00  ; third LSFR part
RSeed:
    PLA  ; get value from stack we saved earlier
    CLC
    ADC $01  ; add to last two bits of LSFR we saved in other place
    TAY  ; use as pseudorandom offset here
    LDA FlyCCXSpeedData,y  ; get horizontal speed using pseudorandom offset
    STA ram_enemy_x_speed,x
    LDA #$01  ; set to move towards the right
    STA ram_enemy_moving_dir,x
    LDA ram_player_x_speed  ; if player moving left or right, branch ahead of this part
    BNE D2XPos1
    LDY $00  ; get first LSFR or third LSFR lower nybble
    TYA  ; and check for d1 set
    AND #%00000010
    BEQ D2XPos1  ; if d1 not set, branch
    LDA ram_enemy_x_speed,x
    EOR #$ff  ; if d1 set, change horizontal speed
    CLC  ; into two's compliment, thus moving in the opposite
    ADC #$01  ; direction
    STA ram_enemy_x_speed,x
    INC ram_enemy_moving_dir,x  ; increment to move towards the left
D2XPos1:
    TYA  ; get first LSFR or third LSFR lower nybble again
    AND #%00000010
    BEQ D2XPos2  ; check for d1 set again, branch again if not set
    LDA ram_player_x_position  ; get player's horizontal position
    CLC
    ADC FlyCCXPositionData,y  ; if d1 set, add value obtained from pseudorandom offset
    STA ram_enemy_x_position,x  ; and save as enemy's horizontal position
    LDA ram_player_page_loc  ; get player's page location
    ADC #$00  ; add carry and jump past this part
    JMP FinCCSt
D2XPos2:
    LDA ram_player_x_position  ; get player's horizontal position
    SEC
    SBC FlyCCXPositionData,y  ; if d1 not set, subtract value obtained from pseudorandom
    STA ram_enemy_x_position,x  ; offset and save as enemy's horizontal position
    LDA ram_player_page_loc  ; get player's page location
    SBC #$00  ; subtract borrow
FinCCSt:
    STA ram_enemy_page_loc,x  ; save as enemy's page location
    LDA #$01
    STA ram_enemy_flag,x  ; set enemy's buffer flag
    STA ram_enemy_y_high_pos,x  ; set enemy's high vertical byte
    LDA #$f8
    STA ram_enemy_y_position,x  ; put enemy below the screen, and we are done
    RTS

; --------------------------------

InitBowser:
    JSR sub_duplicate_enemy_obj  ; jump to create another bowser object
    STX ram_bowser_front_offset  ; save offset of first here
    LDA #$00
    STA ram_bowser_body_controls  ; initialize bowser's body controls
    STA ram_bridge_collapse_offset  ; and bridge collapse offset
    LDA ram_enemy_x_position,x
    STA ram_bowser_orig_x_pos  ; store original horizontal position here
    LDA #$df
    STA ram_bowser_fire_breath_timer  ; store something here
    STA ram_enemy_moving_dir,x  ; and in moving direction
    LDA #$20
    STA ram_bowser_feet_counter  ; set bowser's feet timer and in enemy timer
    STA ram_enemy_frame_timer,x
    LDA #$05
    STA ram_bowser_hit_points  ; give bowser 5 hit points
    LSR
    STA ram_bowser_movement_speed  ; set default movement speed here
    RTS

; --------------------------------

sub_duplicate_enemy_obj:
    LDY #$ff  ; start at beginning of enemy slots
FSLoop:
    INY  ; increment one slot
    LDA ram_enemy_flag,y  ; check enemy buffer flag for empty slot
    BNE FSLoop  ; if set, branch and keep checking
    STY ram_duplicate_obj_offset  ; otherwise set offset here
    TXA  ; transfer original enemy buffer offset
    ORA #%10000000  ; store with d7 set as flag in new enemy
    STA ram_enemy_flag,y  ; slot as well as enemy offset
    LDA ram_enemy_page_loc,x
    STA ram_enemy_page_loc,y  ; copy page location and horizontal coordinates
    LDA ram_enemy_x_position,x  ; from original enemy to new enemy
    STA ram_enemy_x_position,y
    LDA #$01
    STA ram_enemy_flag,x  ; set flag as normal for original enemy
    STA ram_enemy_y_high_pos,y  ; set high vertical byte for new enemy
    LDA ram_enemy_y_position,x
    STA ram_enemy_y_position,y  ; copy vertical coordinate from original to new
FlmEx:
    RTS  ; and then leave

; --------------------------------

FlameYPosData:
    .byte $90, $80, $70, $90

FlameYMFAdderData:
    .byte $ff, $01

InitBowserFlame:
    LDA ram_frenzy_enemy_timer  ; if timer not expired yet, branch to leave
    BNE FlmEx
    STA ram_enemy_y_move_force,x  ; reset something here
    LDA ram_noise_sound_queue
    ORA #con_sfx_bowser_flame  ; load bowser's flame sound into queue
    STA ram_noise_sound_queue
    LDY ram_bowser_front_offset  ; get bowser's buffer offset
    LDA ram_enemy_id,y  ; check for bowser
    CMP #con_bowser
    BEQ SpawnFromMouth  ; branch if found
    JSR sub_set_flame_timer  ; get timer data based on flame counter
    CLC
    ADC #$20  ; add 32 frames by default
    LDY ram_secondary_hard_mode
    BEQ SetFrT  ; if secondary mode flag not set, use as timer setting
    SEC
    SBC #$10  ; otherwise subtract 16 frames for secondary hard mode
SetFrT:
    STA ram_frenzy_enemy_timer  ; set timer accordingly
    LDA ram_pseudo_random_bit_reg,x
    AND #%00000011  ; get 2 LSB from first part of LSFR
    STA ram_bowser_flame_p_random_ofs,x  ; set here
    TAY  ; use as offset
    LDA FlameYPosData,y  ; load vertical position based on pseudorandom offset

sub_put_at_right_extent:
    STA ram_enemy_y_position,x  ; set vertical position
    LDA ram_screen_right_x_pos
    CLC
    ADC #$20  ; place enemy 32 pixels beyond right side of screen
    STA ram_enemy_x_position,x
    LDA ram_screen_right_page_loc
    ADC #$00  ; add carry
    STA ram_enemy_page_loc,x
    JMP FinishFlame  ; skip this part to finish setting values

SpawnFromMouth:
    LDA ram_enemy_x_position,y  ; get bowser's horizontal position
    SEC
    SBC #$0e  ; subtract 14 pixels
    STA ram_enemy_x_position,x  ; save as flame's horizontal position
    LDA ram_enemy_page_loc,y
    STA ram_enemy_page_loc,x  ; copy page location from bowser to flame
    LDA ram_enemy_y_position,y
    CLC  ; add 8 pixels to bowser's vertical position
    ADC #$08
    STA ram_enemy_y_position,x  ; save as flame's vertical position
    LDA ram_pseudo_random_bit_reg,x
    AND #%00000011  ; get 2 LSB from first part of LSFR
    STA ram_enemy_ymf_dummy,x  ; save here
    TAY  ; use as offset
    LDA FlameYPosData,y  ; get value here using bits as offset
    LDY #$00  ; load default offset
    CMP ram_enemy_y_position,x  ; compare value to flame's current vertical position
    BCC SetMF  ; if less, do not increment offset
    INY  ; otherwise increment now
SetMF:
    LDA FlameYMFAdderData,y  ; get value here and save
    STA ram_enemy_y_move_force,x  ; to vertical movement force
    LDA #$00
    STA ram_enemy_frenzy_buffer  ; clear enemy frenzy buffer

FinishFlame:
    LDA #$08  ; set $08 for bounding box control
    STA ram_enemy_bound_box_ctrl,x
    LDA #$01  ; set high byte of vertical and
    STA ram_enemy_y_high_pos,x  ; enemy buffer flag
    STA ram_enemy_flag,x
    LSR
    STA ram_enemy_x_move_force,x  ; initialize horizontal movement force, and
    STA ram_enemy_state,x  ; enemy state
    RTS

; --------------------------------

FireworksXPosData:
    .byte $00, $30, $60, $60, $00, $20

FireworksYPosData:
    .byte $60, $40, $70, $40, $60, $30

InitFireworks:
    LDA ram_frenzy_enemy_timer  ; if timer not expired yet, branch to leave
    BNE ExitFWk
    LDA #$20  ; otherwise reset timer
    STA ram_frenzy_enemy_timer
    DEC ram_fireworks_counter  ; decrement for each explosion
    LDY #$06  ; start at last slot
StarFChk:
    DEY
    LDA ram_enemy_id,y  ; check for presence of star flag object
    CMP #con_star_flag_object  ; if there isn't a star flag object,
    BNE StarFChk  ; routine goes into infinite loop = crash
    LDA ram_enemy_x_position,y
    SEC  ; get horizontal coordinate of star flag object, then
    SBC #$30  ; subtract 48 pixels from it and save to
    PHA  ; the stack
    LDA ram_enemy_page_loc,y
    SBC #$00  ; subtract the carry from the page location
    STA $00  ; of the star flag object
    LDA ram_fireworks_counter  ; get fireworks counter
    CLC
    ADC ram_enemy_state,y  ; add state of star flag object (possibly not necessary)
    TAY  ; use as offset
    PLA  ; get saved horizontal coordinate of star flag - 48 pixels
    CLC
    ADC FireworksXPosData,y  ; add number based on offset of fireworks counter
    STA ram_enemy_x_position,x  ; store as the fireworks object horizontal coordinate
    LDA $00
    ADC #$00  ; add carry and store as page location for
    STA ram_enemy_page_loc,x  ; the fireworks object
    LDA FireworksYPosData,y  ; get vertical position using same offset
    STA ram_enemy_y_position,x  ; and store as vertical coordinate for fireworks object
    LDA #$01
    STA ram_enemy_y_high_pos,x  ; store in vertical high byte
    STA ram_enemy_flag,x  ; and activate enemy buffer flag
    LSR
    STA ram_explosion_gfx_counter,x  ; initialize explosion counter
    LDA #$08
    STA ram_explosion_timer_counter,x  ; set explosion timing counter
ExitFWk:
    RTS

; --------------------------------

Bitmasks:
    .byte %00000001, %00000010, %00000100, %00001000, %00010000, %00100000, %01000000, %10000000

Enemy17YPosData:
    .byte $40, $30, $90, $50, $20, $60, $a0, $70

SwimCC_IDData:
    .byte $0a, $0b

BulletBillCheepCheep:
    LDA ram_frenzy_enemy_timer  ; if timer not expired yet, branch to leave
    BNE ExF17
    LDA ram_area_type  ; are we in a water-type level?
    BNE DoBulletBills  ; if not, branch elsewhere
    CPX #$03  ; are we past third enemy slot?
    BCS ExF17  ; if so, branch to leave
    LDY #$00  ; load default offset
    LDA ram_pseudo_random_bit_reg,x
    CMP #$aa  ; check first part of LSFR against preset value
    BCC ChkW2  ; if less than preset, do not increment offset
    INY  ; otherwise increment
ChkW2:
    LDA ram_world_number  ; check world number
    CMP #con_world2
    BEQ Get17ID  ; if we're on world 2, do not increment offset
    INY  ; otherwise increment
Get17ID:
    TYA
    AND #%00000001  ; mask out all but last bit of offset
    TAY
    LDA SwimCC_IDData,y  ; load identifier for cheep-cheeps
Set17ID:
    STA ram_enemy_id,x  ; store whatever's in A as enemy identifier
    LDA ram_bit_m_filter
    CMP #$ff  ; if not all bits set, skip init part and compare bits
    BNE GetRBit
    LDA #$00  ; initialize vertical position filter
    STA ram_bit_m_filter
GetRBit:
    LDA ram_pseudo_random_bit_reg,x  ; get first part of LSFR
    AND #%00000111  ; mask out all but 3 LSB
ChkRBit:
    TAY  ; use as offset
    LDA Bitmasks,y  ; load bitmask
    BIT ram_bit_m_filter  ; perform AND on filter without changing it
    BEQ AddFBit
    INY  ; increment offset
    TYA
    AND #%00000111  ; mask out all but 3 LSB thus keeping it 0-7
    JMP ChkRBit  ; do another check
AddFBit:
    ORA ram_bit_m_filter  ; add bit to already set bits in filter
    STA ram_bit_m_filter  ; and store
    LDA Enemy17YPosData,y  ; load vertical position using offset
    JSR sub_put_at_right_extent  ; set vertical position and other values
    STA ram_enemy_ymf_dummy,x  ; initialize dummy variable
    LDA #$20  ; set timer
    STA ram_frenzy_enemy_timer
    JMP sub_checkpoint_enemy_id  ; process our new enemy object

DoBulletBills:
    LDY #$ff  ; start at beginning of enemy slots
BB_SLoop:
    INY  ; move onto the next slot
    CPY #$05  ; branch to play sound if we've done all slots
    BCS FireBulletBill
    LDA ram_enemy_flag,y  ; if enemy buffer flag not set,
    BEQ BB_SLoop  ; loop back and check another slot
    LDA ram_enemy_id,y
    CMP #con_bullet_bill_frenzy_var  ; check enemy identifier for
    BNE BB_SLoop  ; bullet bill object (frenzy variant)
ExF17:
    RTS  ; if found, leave

FireBulletBill:
    LDA ram_square2_sound_queue
    ORA #con_sfx_blast  ; play fireworks/gunfire sound
    STA ram_square2_sound_queue
    LDA #con_bullet_bill_frenzy_var  ; load identifier for bullet bill object
    BNE Set17ID  ; unconditional branch

; --------------------------------
; $00 - used to store Y position of group enemies
; $01 - used to store enemy ID
; $02 - used to store page location of right side of screen
; $03 - used to store X position of right side of screen

HandleGroupEnemies:
    LDY #$00  ; load value for green koopa troopa
    SEC
    SBC #$37  ; subtract $37 from second byte read
    PHA  ; save result in stack for now
    CMP #$04  ; was byte in $3b-$3e range?
    BCS SnglID  ; if so, branch
    PHA  ; save another copy to stack
    LDY #con_goomba  ; load value for goomba enemy
    LDA ram_primary_hard_mode  ; if primary hard mode flag not set,
    BEQ PullID  ; branch, otherwise change to value
    LDY #con_buzzy_beetle  ; for buzzy beetle
PullID:
    PLA  ; get second copy from stack
SnglID:
    STY $01  ; save enemy id here
    LDY #$b0  ; load default y coordinate
    AND #$02  ; check to see if d1 was set
    BEQ SetYGp  ; if so, move y coordinate up,
    LDY #$70  ; otherwise branch and use default
SetYGp:
    STY $00  ; save y coordinate here
    LDA ram_screen_right_page_loc  ; get page number of right edge of screen
    STA $02  ; save here
    LDA ram_screen_right_x_pos  ; get pixel coordinate of right edge
    STA $03  ; save here
    LDY #$02  ; load two enemies by default
    PLA  ; get first copy from stack
    LSR  ; check to see if d0 was set
    BCC CntGrp  ; if not, use default value
    INY  ; otherwise increment to three enemies
CntGrp:
    STY ram_numberof_group_enemies  ; save number of enemies here
GrLoop:
    LDX #$ff  ; start at beginning of enemy buffers
GSltLp:
    INX  ; increment and branch if past
    CPX #$05  ; end of buffers
    BCS NextED
    LDA ram_enemy_flag,x  ; check to see if enemy is already
    BNE GSltLp  ; stored in buffer, and branch if so
    LDA $01
    STA ram_enemy_id,x  ; store enemy object identifier
    LDA $02
    STA ram_enemy_page_loc,x  ; store page location for enemy object
    LDA $03
    STA ram_enemy_x_position,x  ; store x coordinate for enemy object
    CLC
    ADC #$18  ; add 24 pixels for next enemy
    STA $03
    LDA $02  ; add carry to page location for
    ADC #$00  ; next enemy
    STA $02
    LDA $00  ; store y coordinate for enemy object
    STA ram_enemy_y_position,x
    LDA #$01  ; activate flag for buffer, and
    STA ram_enemy_y_high_pos,x  ; put enemy within the screen vertically
    STA ram_enemy_flag,x
    JSR sub_checkpoint_enemy_id  ; process each enemy object separately
    DEC ram_numberof_group_enemies  ; do this until we run out of enemy objects
    BNE GrLoop
NextED:
    JMP Inc2B  ; jump to increment data offset and leave

; --------------------------------

sub_init_piranha_plant:
    LDA #$01  ; set initial speed
    STA ram_piranha_plant_y_speed,x
    LSR
    STA ram_enemy_state,x  ; initialize enemy state and what would normally
    STA ram_piranha_plant_move_flag,x  ; be used as vertical speed, but not in this case
    LDA ram_enemy_y_position,x
    STA ram_piranha_plant_down_y_pos,x  ; save original vertical coordinate here
    SEC
    SBC #$18
    STA ram_piranha_plant_up_y_pos,x  ; save original vertical coordinate - 24 pixels here
    LDA #$09
    JMP SetBBox2  ; set specific value for bounding box control

; --------------------------------

InitEnemyFrenzy:
    LDA ram_enemy_id,x  ; load enemy identifier
    STA ram_enemy_frenzy_buffer  ; save in enemy frenzy buffer
    SEC
    SBC #$12  ; subtract 12 and use as offset for jump engine
    JSR sub_dispatch_inline_handler

; frenzy object jump table
    .word LakituAndSpinyHandler
    .word NoFrenzyCode
    .word InitFlyingCheepCheep
    .word InitBowserFlame
    .word InitFireworks
    .word BulletBillCheepCheep

; --------------------------------

NoFrenzyCode:
    RTS

; --------------------------------

EndFrenzy:
    LDY #$05  ; start at last slot
LakituChk:
    LDA ram_enemy_id,y  ; check enemy identifiers
    CMP #con_lakitu  ; for lakitu
    BNE NextFSlot
    LDA #$01  ; if found, set state
    STA ram_enemy_state,y
NextFSlot:
    DEY  ; move onto the next slot
    BPL LakituChk  ; do this until all slots are checked
    LDA #$00
    STA ram_enemy_frenzy_buffer  ; empty enemy frenzy buffer
    STA ram_enemy_flag,x  ; disable enemy buffer flag for this object
    RTS

; --------------------------------

InitJumpGPTroopa:
    LDA #$02  ; set for movement to the left
    STA ram_enemy_moving_dir,x
    LDA #$f8  ; set horizontal speed
    STA ram_enemy_x_speed,x
TallBBox2:
    LDA #$03  ; set specific value for bounding box control
SetBBox2:
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box control then leave
    RTS

; --------------------------------

InitBalPlatform:
    DEC ram_enemy_y_position,x  ; raise vertical position by two pixels
    DEC ram_enemy_y_position,x
    LDY ram_secondary_hard_mode  ; if secondary hard mode flag not set,
    BNE AlignP  ; branch ahead
    LDY #$02  ; otherwise set value here
    JSR sub_pos_platform  ; do a sub to add or subtract pixels
AlignP:
    LDY #$ff  ; set default value here for now
    LDA ram_bal_platform_alignment  ; get current balance platform alignment
    STA ram_enemy_state,x  ; set platform alignment to object state here
    BPL SetBPA  ; if old alignment $ff, put $ff as alignment for negative
    TXA  ; if old contents already $ff, put
    TAY  ; object offset as alignment to make next positive
SetBPA:
    STY ram_bal_platform_alignment  ; store whatever value's in Y here
    LDA #$00
    STA ram_enemy_moving_dir,x  ; init moving direction
    TAY  ; init Y
    JSR sub_pos_platform  ; do a sub to add 8 pixels, then run shared code here

; --------------------------------

InitDropPlatform:
    LDA #$ff
    STA ram_platform_collision_flag,x  ; set some value here
    JMP CommonPlatCode  ; then jump ahead to execute more code

; --------------------------------

InitHoriPlatform:
    LDA #$00
    STA ram_x_move_secondary_counter,x  ; init one of the moving counters
    JMP CommonPlatCode  ; jump ahead to execute more code

; --------------------------------

InitVertPlatform:
    LDY #$40  ; set default value here
    LDA ram_enemy_y_position,x  ; check vertical position
    BPL SetYO  ; if above a certain point, skip this part
    EOR #$ff
    CLC  ; otherwise get two's compliment
    ADC #$01
    LDY #$c0  ; get alternate value to add to vertical position
SetYO:
    STA ram_y_platform_top_y_pos,x  ; save as top vertical position
    TYA
    CLC  ; load value from earlier, add number of pixels
    ADC ram_enemy_y_position,x  ; to vertical position
    STA ram_y_platform_center_y_pos,x  ; save result as central vertical position

; --------------------------------

CommonPlatCode:
    JSR sub_init_v_stf  ; do a sub to init certain other values
SPBBox:
    LDA #$05  ; set default bounding box size control
    LDY ram_area_type
    CPY #$03  ; check for castle-type level
    BEQ CasPBB  ; use default value if found
    LDY ram_secondary_hard_mode  ; otherwise check for secondary hard mode flag
    BNE CasPBB  ; if set, use default value
    LDA #$06  ; use alternate value if not castle or secondary not set
CasPBB:
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box size control here and leave
    RTS

; --------------------------------

LargeLiftUp:
    JSR sub_plat_lift_up  ; execute code for platforms going up
    JMP LargeLiftBBox  ; overwrite bounding box for large platforms

LargeLiftDown:
    JSR sub_plat_lift_down  ; execute code for platforms going down

LargeLiftBBox:
    JMP SPBBox  ; jump to overwrite bounding box size control

; --------------------------------

sub_plat_lift_up:
    LDA #$10  ; set movement amount here
    STA ram_enemy_y_move_force,x
    LDA #$ff  ; set moving speed for platforms going up
    STA ram_enemy_y_speed,x
    JMP CommonSmallLift  ; skip ahead to part we should be executing

; --------------------------------

sub_plat_lift_down:
    LDA #$f0  ; set movement amount here
    STA ram_enemy_y_move_force,x
    LDA #$00  ; set moving speed for platforms going down
    STA ram_enemy_y_speed,x

; --------------------------------

CommonSmallLift:
    LDY #$01
    JSR sub_pos_platform  ; do a sub to add 12 pixels due to preset value
    LDA #$04
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box control for small platforms
    RTS

; --------------------------------

PlatPosDataLow:
    .byte $08,$0c,$f8

PlatPosDataHigh:
    .byte $00,$00,$ff

sub_pos_platform:
    LDA ram_enemy_x_position,x  ; get horizontal coordinate
    CLC
    ADC PlatPosDataLow,y  ; add or subtract pixels depending on offset
    STA ram_enemy_x_position,x  ; store as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    ADC PlatPosDataHigh,y  ; add or subtract page location depending on offset
    STA ram_enemy_page_loc,x  ; store as new page location
    RTS  ; and go back

; --------------------------------

EndOfEnemyInitCode:
    RTS
