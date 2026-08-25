; -------------------------------------------------------------------------------------

RunEnemyObjectsCore:
    LDX ram_object_offset  ; get offset for enemy object buffer
    LDA #$00  ; load value 0 for jump engine by default
    LDY ram_enemy_id,x
    CPY #$15  ; if enemy object < $15, use default value
    BCC JmpEO
    TYA  ; otherwise subtract $14 from the value and use
    SBC #$14  ; as value for jump engine
JmpEO:
    JSR sub_dispatch_inline_handler

    .word RunNormalEnemies  ; for objects $00-$14

    .word RunBowserFlame  ; for objects $15-$1f
    .word RunFireworks
    .word NoRunCode
    .word NoRunCode
    .word NoRunCode
    .word NoRunCode
    .word RunFirebarObj
    .word RunFirebarObj
    .word RunFirebarObj
    .word RunFirebarObj
    .word RunFirebarObj

    .word RunFirebarObj  ; for objects $20-$2f
    .word RunFirebarObj
    .word RunFirebarObj
    .word NoRunCode
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunLargePlatform
    .word RunSmallPlatform
    .word RunSmallPlatform
    .word RunBowser
    .word PowerUpObjHandler
    .word VineObjectHandler

    .word NoRunCode  ; for objects $30-$35
    .word RunStarFlagObj
    .word JumpspringHandler
    .word NoRunCode
    .word WarpZoneObject
    .word sub_run_retainer_obj

; --------------------------------

NoRunCode:
    RTS

; --------------------------------

sub_run_retainer_obj:
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JMP sub_enemy_gfx_handler

; --------------------------------

RunNormalEnemies:
    LDA #$00  ; init sprite attributes
    STA ram_enemy_spr_attrib,x
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JSR sub_enemy_gfx_handler
    JSR sub_get_enemy_bound_box
    JSR sub_enemy_to_bg_collision_det
    JSR sub_enemies_collision
    JSR sub_player_enemy_collision
    LDY ram_timer_control  ; if master timer control set, skip to last routine
    BNE SkipMove
    JSR sub_enemy_movement_subs
SkipMove:
    JMP sub_offscreen_bounds_check

sub_enemy_movement_subs:
    LDA ram_enemy_id,x
    JSR sub_dispatch_inline_handler

    .word sub_move_normal_enemy  ; only objects $00-$14 use this table
    .word sub_move_normal_enemy
    .word sub_move_normal_enemy
    .word sub_move_normal_enemy
    .word sub_move_normal_enemy
    .word ProcHammerBro
    .word sub_move_normal_enemy
    .word MoveBloober
    .word MoveBulletBill
    .word NoMoveCode
    .word MoveSwimmingCheepCheep
    .word MoveSwimmingCheepCheep
    .word MovePodoboo
    .word MovePiranhaPlant
    .word sub_move_jumping_enemy
    .word ProcMoveRedPTroopa
    .word MoveFlyGreenPTroopa
    .word MoveLakitu
    .word sub_move_normal_enemy
    .word NoMoveCode  ; dummy
    .word MoveFlyingCheepCheep

; --------------------------------

NoMoveCode:
    RTS

; --------------------------------

RunBowserFlame:
    JSR sub_proc_bowser_flame
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JSR sub_get_enemy_bound_box
    JSR sub_player_enemy_collision
    JMP sub_offscreen_bounds_check

; --------------------------------

RunFirebarObj:
    JSR sub_proc_firebar
    JMP sub_offscreen_bounds_check

; --------------------------------

RunSmallPlatform:
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JSR sub_small_platform_bound_box
    JSR sub_small_platform_collision
    JSR sub_relative_enemy_position
    JSR sub_draw_small_platform
    JSR sub_move_small_platform
    JMP sub_offscreen_bounds_check

; --------------------------------

RunLargePlatform:
    JSR sub_get_enemy_offscreen_bits
    JSR sub_relative_enemy_position
    JSR sub_large_platform_bound_box
    JSR sub_large_platform_collision
    LDA ram_timer_control  ; if master timer control set,
    BNE SkipPT  ; skip subroutine tree
    JSR sub_large_platform_subroutines
SkipPT:
    JSR sub_relative_enemy_position
    JSR sub_draw_large_platform
    JMP sub_offscreen_bounds_check

; --------------------------------

sub_large_platform_subroutines:
    LDA ram_enemy_id,x  ; subtract $24 to get proper offset for jump table
    SEC
    SBC #$24
    JSR sub_dispatch_inline_handler

    .word BalancePlatform  ; table used by objects $24-$2a
    .word YMovingPlatform
    .word MoveLargeLiftPlat
    .word MoveLargeLiftPlat
    .word XMovingPlatform
    .word DropPlatform
    .word RightPlatform

; -------------------------------------------------------------------------------------

sub_erase_enemy_object:
    LDA #$00  ; clear all enemy object variables
    STA ram_enemy_flag,x
    STA ram_enemy_id,x
    STA ram_enemy_state,x
    STA ram_floatey_num_control,x
    STA ram_enemy_interval_timer,x
    STA ram_shell_chain_counter,x
    STA ram_enemy_spr_attrib,x
    STA ram_enemy_frame_timer,x
    RTS

; -------------------------------------------------------------------------------------

MovePodoboo:
    LDA ram_enemy_interval_timer,x  ; check enemy timer
    BNE PdbM  ; branch to move enemy if not expired
    JSR sub_init_podoboo  ; otherwise set up podoboo again
    LDA ram_pseudo_random_bit_reg+1,x  ; get part of LSFR
    ORA #%10000000  ; set d7
    STA ram_enemy_y_move_force,x  ; store as movement force
    AND #%00001111  ; mask out high nybble
    ORA #$06  ; set for at least six intervals
    STA ram_enemy_interval_timer,x  ; store as new enemy timer
    LDA #$f9
    STA ram_enemy_y_speed,x  ; set vertical speed to move podoboo upwards
PdbM:
    JMP sub_move_enemy_with_gravity  ; branch to impose gravity on podoboo

; --------------------------------
; $00 - used in HammerBroJumpCode as bitmask

HammerThrowTmrData:
    .byte $30, $1c

XSpeedAdderData:
    .byte $00, $e8, $00, $18

RevivedXSpeed:
    .byte $08, $f8, $0c, $f4

ProcHammerBro:
    LDA ram_enemy_state,x  ; check hammer bro's enemy state for d5 set
    AND #%00100000
    BEQ ChkJH  ; if not set, go ahead with code
    JMP MoveDefeatedEnemy  ; otherwise jump to something else
ChkJH:
    LDA ram_hammer_bro_jump_timer,x  ; check jump timer
    BEQ HammerBroJumpCode  ; if expired, branch to jump
    DEC ram_hammer_bro_jump_timer,x  ; otherwise decrement jump timer
    LDA ram_enemy_offscreen_bits
    AND #%00001100  ; check offscreen bits
    BNE MoveHammerBroXDir  ; if hammer bro a little offscreen, skip to movement code
    LDA ram_hammer_throwing_timer,x  ; check hammer throwing timer
    BNE DecHT  ; if not expired, skip ahead, do not throw hammer
    LDY ram_secondary_hard_mode  ; otherwise get secondary hard mode flag
    LDA HammerThrowTmrData,y  ; get timer data using flag as offset
    STA ram_hammer_throwing_timer,x  ; set as new timer
    JSR sub_spawn_hammer_obj  ; do a sub here to spawn hammer object
    BCC DecHT  ; if carry clear, hammer not spawned, skip to decrement timer
    LDA ram_enemy_state,x
    ORA #%00001000  ; set d3 in enemy state for hammer throw
    STA ram_enemy_state,x
    JMP MoveHammerBroXDir  ; jump to move hammer bro
DecHT:
    DEC ram_hammer_throwing_timer,x  ; decrement timer
    JMP MoveHammerBroXDir  ; jump to move hammer bro

HammerBroJumpLData:
    .byte $20, $37

HammerBroJumpCode:
    LDA ram_enemy_state,x  ; get hammer bro's enemy state
    AND #%00000111  ; mask out all but 3 LSB
    CMP #$01  ; check for d0 set (for jumping)
    BEQ MoveHammerBroXDir  ; if set, branch ahead to moving code
    LDA #$00  ; load default value here
    STA $00  ; save into temp variable for now
    LDY #$fa  ; set default vertical speed
    LDA ram_enemy_y_position,x  ; check hammer bro's vertical coordinate
    BMI SetHJ  ; if on the bottom half of the screen, use current speed
    LDY #$fd  ; otherwise set alternate vertical speed
    CMP #$70  ; check to see if hammer bro is above the middle of screen
    INC $00  ; increment preset value to $01
    BCC SetHJ  ; if above the middle of the screen, use current speed and $01
    DEC $00  ; otherwise return value to $00
    LDA ram_pseudo_random_bit_reg+1,x  ; get part of LSFR, mask out all but LSB
    AND #$01
    BNE SetHJ  ; if d0 of LSFR set, branch and use current speed and $00
    LDY #$fa  ; otherwise reset to default vertical speed
SetHJ:
    STY ram_enemy_y_speed,x  ; set vertical speed for jumping
    LDA ram_enemy_state,x  ; set d0 in enemy state for jumping
    ORA #$01
    STA ram_enemy_state,x
    LDA $00  ; load preset value here to use as bitmask
    AND ram_pseudo_random_bit_reg+2,x  ; and do bit-wise comparison with part of LSFR
    TAY  ; then use as offset
    LDA ram_secondary_hard_mode  ; check secondary hard mode flag
    BNE HJump
    TAY  ; if secondary hard mode flag clear, set offset to 0
HJump:
    LDA HammerBroJumpLData,y  ; get jump length timer data using offset from before
    STA ram_enemy_frame_timer,x  ; save in enemy timer
    LDA ram_pseudo_random_bit_reg+1,x
    ORA #%11000000  ; get contents of part of LSFR, set d7 and d6, then
    STA ram_hammer_bro_jump_timer,x  ; store in jump timer

MoveHammerBroXDir:
    LDY #$fc  ; move hammer bro a little to the left
    LDA ram_frame_counter
    AND #%01000000  ; change hammer bro's direction every 64 frames
    BNE Shimmy
    LDY #$04  ; if d6 set in counter, move him a little to the right
Shimmy:
    STY ram_enemy_x_speed,x  ; store horizontal speed
    LDY #$01  ; set to face right by default
    JSR sub_player_enemy_diff  ; get horizontal difference between player and hammer bro
    BMI SetShim  ; if enemy to the left of player, skip this part
    INY  ; set to face left
    LDA ram_enemy_interval_timer,x  ; check walking timer
    BNE SetShim  ; if not yet expired, skip to set moving direction
    LDA #$f8
    STA ram_enemy_x_speed,x  ; otherwise, make the hammer bro walk left towards player
SetShim:
    STY ram_enemy_moving_dir,x  ; set moving direction

sub_move_normal_enemy:
    LDY #$00  ; init Y to leave horizontal movement as-is
    LDA ram_enemy_state,x
    AND #%01000000  ; check enemy state for d6 set, if set skip
    BNE FallE  ; to move enemy vertically, then horizontally if necessary
    LDA ram_enemy_state,x
    ASL  ; check enemy state for d7 set
    BCS SteadM  ; if set, branch to move enemy horizontally
    LDA ram_enemy_state,x
    AND #%00100000  ; check enemy state for d5 set
    BNE MoveDefeatedEnemy  ; if set, branch to move defeated enemy object
    LDA ram_enemy_state,x
    AND #%00000111  ; check d2-d0 of enemy state for any set bits
    BEQ SteadM  ; if enemy in normal state, branch to move enemy horizontally
    CMP #$05
    BEQ FallE  ; if enemy in state used by spiny's egg, go ahead here
    CMP #$03
    BCS ReviveStunned  ; if enemy in states $03 or $04, skip ahead to yet another part
FallE:
    JSR sub_move_enemy_downward_fast  ; do a sub here to move enemy downwards
    LDY #$00
    LDA ram_enemy_state,x  ; check for enemy state $02
    CMP #$02
    BEQ MEHor  ; if found, branch to move enemy horizontally
    AND #%01000000  ; check for d6 set
    BEQ SteadM  ; if not set, branch to something else
    LDA ram_enemy_id,x
    CMP #con_power_up_object  ; check for power-up object
    BEQ SteadM
    BNE SlowM  ; if any other object where d6 set, jump to set Y
MEHor:
    JMP sub_move_enemy_horizontally  ; jump here to move enemy horizontally for <> $2e and d6 set

SlowM:
    LDY #$01  ; if branched here, increment Y to slow horizontal movement
SteadM:
    LDA ram_enemy_x_speed,x  ; get current horizontal speed
    PHA  ; save to stack
    BPL AddHS  ; if not moving or moving right, skip, leave Y alone
    INY
    INY  ; otherwise increment Y to next data
AddHS:
    CLC
    ADC XSpeedAdderData,y  ; add value here to slow enemy down if necessary
    STA ram_enemy_x_speed,x  ; save as horizontal speed temporarily
    JSR sub_move_enemy_horizontally  ; then do a sub to move horizontally
    PLA
    STA ram_enemy_x_speed,x  ; get old horizontal speed from stack and return to
    RTS  ; original memory location, then leave

ReviveStunned:
    LDA ram_enemy_interval_timer,x  ; if enemy timer not expired yet,
    BNE ChkKillGoomba  ; skip ahead to something else
    STA ram_enemy_state,x  ; otherwise initialize enemy state to normal
    LDA ram_frame_counter
    AND #$01  ; get d0 of frame counter
    TAY  ; use as Y and increment for movement direction
    INY
    STY ram_enemy_moving_dir,x  ; store as pseudorandom movement direction
    DEY  ; decrement for use as pointer
    LDA ram_primary_hard_mode  ; check primary hard mode flag
    BEQ SetRSpd  ; if not set, use pointer as-is
    INY
    INY  ; otherwise increment 2 bytes to next data
SetRSpd:
    LDA RevivedXSpeed,y  ; load and store new horizontal speed
    STA ram_enemy_x_speed,x  ; and leave
    RTS

MoveDefeatedEnemy:
    JSR sub_move_enemy_downward_fast  ; execute sub to move defeated enemy downwards
    JMP sub_move_enemy_horizontally  ; now move defeated enemy horizontally

ChkKillGoomba:
    CMP #$0e  ; check to see if enemy timer has reached
    BNE NKGmba  ; a certain point, and branch to leave if not
    LDA ram_enemy_id,x
    CMP #con_goomba  ; check for goomba object
    BNE NKGmba  ; branch if not found
    JSR sub_erase_enemy_object  ; otherwise, kill this goomba object
NKGmba:
    RTS  ; leave!

; --------------------------------

sub_move_jumping_enemy:
    JSR sub_move_enemy_with_gravity  ; do a sub to impose gravity on green paratroopa
    JMP sub_move_enemy_horizontally  ; jump to move enemy horizontally

; --------------------------------

ProcMoveRedPTroopa:
    LDA ram_enemy_y_speed,x
    ORA ram_enemy_y_move_force,x  ; check for any vertical force or speed
    BNE MoveRedPTUpOrDown  ; branch if any found
    STA ram_enemy_ymf_dummy,x  ; initialize something here
    LDA ram_enemy_y_position,x  ; check current vs. original vertical coordinate
    CMP ram_red_p_troopa_orig_x_pos,x
    BCS MoveRedPTUpOrDown  ; if current => original, skip ahead to more code
    LDA ram_frame_counter  ; get frame counter
    AND #%00000111  ; mask out all but 3 LSB
    BNE NoIncPT  ; if any bits set, branch to leave
    INC ram_enemy_y_position,x  ; otherwise increment red paratroopa's vertical position
NoIncPT:
    RTS  ; leave

MoveRedPTUpOrDown:
    LDA ram_enemy_y_position,x  ; check current vs. central vertical coordinate
    CMP ram_red_p_troopa_center_y_pos,x
    BCC MovPTDwn  ; if current < central, jump to move downwards
    JMP loc_move_red_paratroopa_up  ; otherwise jump to move upwards
MovPTDwn:
    JMP loc_move_red_paratroopa_down  ; move downwards

; --------------------------------
; $00 - used to store adder for movement, also used as adder for platform
; $01 - used to store maximum value for secondary counter

MoveFlyGreenPTroopa:
    JSR sub_x_move_cntr_green_p_troopa  ; do sub to increment primary and secondary counters
    JSR sub_move_with_xm_cntrs  ; do sub to move green paratroopa accordingly, and horizontally
    LDY #$01  ; set Y to move green paratroopa down
    LDA ram_frame_counter
    AND #%00000011  ; check frame counter 2 LSB for any bits set
    BNE NoMGPT  ; branch to leave if set to move up/down every fourth frame
    LDA ram_frame_counter
    AND #%01000000  ; check frame counter for d6 set
    BNE YSway  ; branch to move green paratroopa down if set
    LDY #$ff  ; otherwise set Y to move green paratroopa up
YSway:
    STY $00  ; store adder here
    LDA ram_enemy_y_position,x
    CLC  ; add or subtract from vertical position
    ADC $00  ; to give green paratroopa a wavy flight
    STA ram_enemy_y_position,x
NoMGPT:
    RTS  ; leave!

sub_x_move_cntr_green_p_troopa:
    LDA #$13  ; load preset maximum value for secondary counter

sub_x_move_cntr_platform:
    STA $01  ; store value here
    LDA ram_frame_counter
    AND #%00000011  ; branch to leave if not on
    BNE NoIncXM  ; every fourth frame
    LDY ram_x_move_secondary_counter,x  ; get secondary counter
    LDA ram_x_move_primary_counter,x  ; get primary counter
    LSR
    BCS DecSeXM  ; if d0 of primary counter set, branch elsewhere
    CPY $01  ; compare secondary counter to preset maximum value
    BEQ IncPXM  ; if equal, branch ahead of this part
    INC ram_x_move_secondary_counter,x  ; increment secondary counter and leave
NoIncXM:
    RTS
IncPXM:
    INC ram_x_move_primary_counter,x  ; increment primary counter and leave
    RTS
DecSeXM:
    TYA  ; put secondary counter in A
    BEQ IncPXM  ; if secondary counter at zero, branch back
    DEC ram_x_move_secondary_counter,x  ; otherwise decrement secondary counter and leave
    RTS

sub_move_with_xm_cntrs:
    LDA ram_x_move_secondary_counter,x  ; save secondary counter to stack
    PHA
    LDY #$01  ; set value here by default
    LDA ram_x_move_primary_counter,x
    AND #%00000010  ; if d1 of primary counter is
    BNE XMRight  ; set, branch ahead of this part here
    LDA ram_x_move_secondary_counter,x
    EOR #$ff  ; otherwise change secondary
    CLC  ; counter to two's compliment
    ADC #$01
    STA ram_x_move_secondary_counter,x
    LDY #$02  ; load alternate value here
XMRight:
    STY ram_enemy_moving_dir,x  ; store as moving direction
    JSR sub_move_enemy_horizontally
    STA $00  ; save value obtained from sub here
    PLA  ; get secondary counter from stack
    STA ram_x_move_secondary_counter,x  ; and return to original place
    RTS

; --------------------------------

BlooberBitmasks:
    .byte %00111111, %00000011

MoveBloober:
    LDA ram_enemy_state,x
    AND #%00100000  ; check enemy state for d5 set
    BNE MoveDefeatedBloober  ; branch if set to move defeated bloober
    LDY ram_secondary_hard_mode  ; use secondary hard mode flag as offset
    LDA ram_pseudo_random_bit_reg+1,x  ; get LSFR
    AND BlooberBitmasks,y  ; mask out bits in LSFR using bitmask loaded with offset
    BNE BlooberSwim  ; if any bits set, skip ahead to make swim
    TXA
    LSR  ; check to see if on second or fourth slot (1 or 3)
    BCC FBLeft  ; if not, branch to figure out moving direction
    LDY ram_player_moving_dir  ; otherwise, load player's moving direction and
    BCS SBMDir  ; do an unconditional branch to set
FBLeft:
    LDY #$02  ; set left moving direction by default
    JSR sub_player_enemy_diff  ; get horizontal difference between player and bloober
    BPL SBMDir  ; if enemy to the right of player, keep left
    DEY  ; otherwise decrement to set right moving direction
SBMDir:
    STY ram_enemy_moving_dir,x  ; set moving direction of bloober, then continue on here

BlooberSwim:
    JSR sub_proc_swimming_b  ; execute sub to make bloober swim characteristically
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    SEC
    SBC ram_enemy_y_move_force,x  ; subtract movement force
    CMP #$20  ; check to see if position is above edge of status bar
    BCC SwimX  ; if so, don't do it
    STA ram_enemy_y_position,x  ; otherwise, set new vertical position, make bloober swim
SwimX:
    LDY ram_enemy_moving_dir,x  ; check moving direction
    DEY
    BNE LeftSwim  ; if moving to the left, branch to second part
    LDA ram_enemy_x_position,x
    CLC  ; add movement speed to horizontal coordinate
    ADC ram_blooper_move_speed,x
    STA ram_enemy_x_position,x  ; store result as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    ADC #$00  ; add carry to page location
    STA ram_enemy_page_loc,x  ; store as new page location and leave
    RTS

LeftSwim:
    LDA ram_enemy_x_position,x
    SEC  ; subtract movement speed from horizontal coordinate
    SBC ram_blooper_move_speed,x
    STA ram_enemy_x_position,x  ; store result as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    SBC #$00  ; subtract borrow from page location
    STA ram_enemy_page_loc,x  ; store as new page location and leave
    RTS

MoveDefeatedBloober:
    JMP sub_move_enemy_downward_slow  ; jump to move defeated bloober downwards

sub_proc_swimming_b:
    LDA ram_blooper_move_counter,x  ; get enemy's movement counter
    AND #%00000010  ; check for d1 set
    BNE ChkForFloatdown  ; branch if set
    LDA ram_frame_counter
    AND #%00000111  ; get 3 LSB of frame counter
    PHA  ; and save it to the stack
    LDA ram_blooper_move_counter,x  ; get enemy's movement counter
    LSR  ; check for d0 set
    BCS SlowSwim  ; branch if set
    PLA  ; pull 3 LSB of frame counter from the stack
    BNE BSwimE  ; branch to leave, execute code only every eighth frame
    LDA ram_enemy_y_move_force,x
    CLC  ; add to movement force to speed up swim
    ADC #$01
    STA ram_enemy_y_move_force,x  ; set movement force
    STA ram_blooper_move_speed,x  ; set as movement speed
    CMP #$02
    BNE BSwimE  ; if certain horizontal speed, branch to leave
    INC ram_blooper_move_counter,x  ; otherwise increment movement counter
BSwimE:
    RTS

SlowSwim:
    PLA  ; pull 3 LSB of frame counter from the stack
    BNE NoSSw  ; branch to leave, execute code only every eighth frame
    LDA ram_enemy_y_move_force,x
    SEC  ; subtract from movement force to slow swim
    SBC #$01
    STA ram_enemy_y_move_force,x  ; set movement force
    STA ram_blooper_move_speed,x  ; set as movement speed
    BNE NoSSw  ; if any speed, branch to leave
    INC ram_blooper_move_counter,x  ; otherwise increment movement counter
    LDA #$02
    STA ram_enemy_interval_timer,x  ; set enemy's timer
NoSSw:
    RTS  ; leave

ChkForFloatdown:
    LDA ram_enemy_interval_timer,x  ; get enemy timer
    BEQ ChkNearPlayer  ; branch if expired

Floatdown:
    LDA ram_frame_counter  ; get frame counter
    LSR  ; check for d0 set
    BCS NoFD  ; branch to leave on every other frame
    INC ram_enemy_y_position,x  ; otherwise increment vertical coordinate
NoFD:
    RTS  ; leave

ChkNearPlayer:
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    ADC #$10  ; add sixteen pixels
    CMP ram_player_y_position  ; compare result with player's vertical coordinate
    BCC Floatdown  ; if modified vertical less than player's, branch
    LDA #$00
    STA ram_blooper_move_counter,x  ; otherwise nullify movement counter
    RTS

; --------------------------------

MoveBulletBill:
    LDA ram_enemy_state,x  ; check bullet bill's enemy object state for d5 set
    AND #%00100000
    BEQ NotDefB  ; if not set, continue with movement code
    JMP sub_move_enemy_with_gravity  ; otherwise jump to move defeated bullet bill downwards
NotDefB:
    LDA #$e8  ; set bullet bill's horizontal speed
    STA ram_enemy_x_speed,x  ; and move it accordingly (note: this bullet bill
    JMP sub_move_enemy_horizontally  ; object occurs in frenzy object $17, not from cannons)

; --------------------------------
; $02 - used to hold preset values
; $03 - used to hold enemy state

SwimCCXMoveData:
    .byte $40, $80
    .byte $04, $04  ; residual data, not used

MoveSwimmingCheepCheep:
    LDA ram_enemy_state,x  ; check cheep-cheep's enemy object state
    AND #%00100000  ; for d5 set
    BEQ CCSwim  ; if not set, continue with movement code
    JMP sub_move_enemy_downward_slow  ; otherwise jump to move defeated cheep-cheep downwards
CCSwim:
    STA $03  ; save enemy state in $03
    LDA ram_enemy_id,x  ; get enemy identifier
    SEC
    SBC #$0a  ; subtract ten for cheep-cheep identifiers
    TAY  ; use as offset
    LDA SwimCCXMoveData,y  ; load value here
    STA $02
    LDA ram_enemy_x_move_force,x  ; load horizontal force
    SEC
    SBC $02  ; subtract preset value from horizontal force
    STA ram_enemy_x_move_force,x  ; store as new horizontal force
    LDA ram_enemy_x_position,x  ; get horizontal coordinate
    SBC #$00  ; subtract borrow (thus moving it slowly)
    STA ram_enemy_x_position,x  ; and save as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    SBC #$00  ; subtract borrow again, this time from the
    STA ram_enemy_page_loc,x  ; page location, then save
    LDA #$20
    STA $02  ; save new value here
    CPX #$02  ; check enemy object offset
    BCC ExSwCC  ; if in first or second slot, branch to leave
    LDA ram_cheep_cheep_move_m_flag,x  ; check movement flag
    CMP #$10  ; if movement speed set to $00,
    BCC CCSwimUpwards  ; branch to move upwards
    LDA ram_enemy_ymf_dummy,x
    CLC
    ADC $02  ; add preset value to dummy variable to get carry
    STA ram_enemy_ymf_dummy,x  ; and save dummy
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    ADC $03  ; add carry to it plus enemy state to slowly move it downwards
    STA ram_enemy_y_position,x  ; save as new vertical coordinate
    LDA ram_enemy_y_high_pos,x
    ADC #$00  ; add carry to page location and
    JMP ChkSwimYPos  ; jump to end of movement code

CCSwimUpwards:
    LDA ram_enemy_ymf_dummy,x
    SEC
    SBC $02  ; subtract preset value to dummy variable to get borrow
    STA ram_enemy_ymf_dummy,x  ; and save dummy
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    SBC $03  ; subtract borrow to it plus enemy state to slowly move it upwards
    STA ram_enemy_y_position,x  ; save as new vertical coordinate
    LDA ram_enemy_y_high_pos,x
    SBC #$00  ; subtract borrow from page location

ChkSwimYPos:
    STA ram_enemy_y_high_pos,x  ; save new page location here
    LDY #$00  ; load movement speed to upwards by default
    LDA ram_enemy_y_position,x  ; get vertical coordinate
    SEC
    SBC ram_cheep_cheep_orig_y_pos,x  ; subtract original coordinate from current
    BPL YPDiff  ; if result positive, skip to next part
    LDY #$10  ; otherwise load movement speed to downwards
    EOR #$ff
    CLC  ; get two's compliment of result
    ADC #$01  ; to obtain total difference of original vs. current
YPDiff:
    CMP #$0f  ; if difference between original vs. current vertical
    BCC ExSwCC  ; coordinates < 15 pixels, leave movement speed alone
    TYA
    STA ram_cheep_cheep_move_m_flag,x  ; otherwise change movement speed
ExSwCC:
    RTS  ; leave
