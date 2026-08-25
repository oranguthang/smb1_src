; -------------------------------------------------------------------------------------
; $00 - used to store high nybble of horizontal speed as adder
; $01 - used to store low nybble of horizontal speed
; $02 - used to store adder to page location

sub_move_enemy_horizontally:
    INX  ; increment offset for enemy offset
    JSR sub_move_object_horizontally  ; position object horizontally according to
    LDX ram_object_offset  ; counters, return with saved value in A,
    RTS  ; put enemy offset back in X and leave

; Integrate the player's signed horizontal speed into world position

; Outputs:
; Player page, pixel, and fractional horizontal position are updated
; A returns the signed integer displacement used by scrolling

; Clobbers:
; A, X, Y
sub_move_player_horizontally:
    LDA ram_jumpspring_anim_ctrl  ; if jumpspring currently animating,
    BNE bra_return_from_movement  ; branch to leave
    TAX  ; otherwise set zero for offset to use player's stuff

sub_move_object_horizontally:
    LDA ram_spr_object_x_speed,x  ; get currently saved value (horizontal
    ASL  ; speed, secondary counter, whatever)
    ASL  ; and move low nybble to high
    ASL
    ASL
    STA $01  ; store result here
    LDA ram_spr_object_x_speed,x  ; get saved value again
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    CMP #$08  ; if < 8, branch, do not change
    BCC bra_store_signed_x_speed
    ORA #%11110000  ; otherwise alter high nybble
bra_store_signed_x_speed:
    STA $00  ; save result here
    LDY #$00  ; load default Y value here
    CMP #$00  ; if result positive, leave Y alone
    BPL bra_apply_horizontal_position_delta
    DEY  ; otherwise decrement Y
bra_apply_horizontal_position_delta:
    STY $02  ; save Y here
    LDA ram_spr_object_x_move_force,x  ; get whatever number's here
    CLC
    ADC $01  ; add low nybble moved to high
    STA ram_spr_object_x_move_force,x  ; store result here
    LDA #$00  ; init A
    ROL  ; rotate carry into d0
    PHA  ; push onto stack
    ROR  ; rotate d0 back onto carry
    LDA ram_spr_object_x_position,x
    ADC $00  ; add carry plus saved value (high nybble moved to low
    STA ram_spr_object_x_position,x  ; plus $f0 if necessary) to object's horizontal position
    LDA ram_spr_object_page_loc,x
    ADC $02  ; add carry plus other saved value to the
    STA ram_spr_object_page_loc,x  ; object's page location and save
    PLA
    CLC  ; pull old carry from stack and add
    ADC $00  ; to high nybble moved to low
bra_return_from_movement:
    RTS  ; and leave

; -------------------------------------------------------------------------------------
; $00 - used for downward force
; $01 - used for upward force
; $02 - used for maximum vertical speed

; Integrate player vertical position and apply the selected gravity

; Inputs:
; ram_player_active_gravity - fractional downward acceleration

; Outputs:
; Player vertical position and velocity are updated

; Clobbers:
; A, X, Y
loc_move_player_vertically:
    LDX #$00  ; set X for player offset
    LDA ram_timer_control
    BNE bra_load_player_vertical_force  ; if master timer control set, branch ahead
    LDA ram_jumpspring_anim_ctrl  ; otherwise check to see if jumpspring is animating
    BNE bra_return_from_movement  ; branch to leave if so
bra_load_player_vertical_force:
    LDA ram_player_active_gravity  ; dump vertical force
    STA $00
    LDA #$04  ; set maximum vertical speed here
    JMP sub_apply_sprite_object_gravity  ; then jump to move player vertically

; --------------------------------

sub_move_enemy_downward_fast:
    LDY #$3d  ; set quick movement amount downwards
    LDA ram_enemy_state,x  ; then check enemy state
    CMP #$05  ; if not set to unique state for spiny's egg, go ahead
    BNE bra_set_fast_vertical_motion  ; and use, otherwise set different movement amount, continue on

sub_move_falling_platform:
    LDY #$20  ; set movement amount
bra_set_fast_vertical_motion:
    JMP bra_set_high_vertical_speed_limit  ; jump to skip the rest of this

; --------------------------------

loc_move_red_paratroopa_down:
    LDY #$00  ; set Y to move downwards
    JMP loc_move_red_paratroopa_vertically  ; skip to movement routine

loc_move_red_paratroopa_up:
    LDY #$01  ; set Y to move upwards

loc_move_red_paratroopa_vertically:
    INX  ; increment X for enemy offset
    LDA #$03
    STA $00  ; set downward movement amount here
    LDA #$06
    STA $01  ; set upward movement amount here
    LDA #$02
    STA $02  ; set maximum speed here
    TYA  ; set movement direction in A, and
    JMP loc_apply_red_paratroopa_gravity  ; jump to move this thing

; --------------------------------

sub_move_drop_platform:
    LDY #$7f  ; set movement amount for drop platform
    BNE bra_set_medium_vertical_speed_limit  ; skip ahead of other value set here

sub_move_enemy_downward_slow:
    LDY #$0f  ; set movement amount for bowser/other objects
bra_set_medium_vertical_speed_limit:
    LDA #$02  ; set maximum speed in A
    BNE sub_apply_enemy_vertical_motion  ; unconditional branch

; --------------------------------

sub_move_enemy_with_gravity:
    LDY #$1c  ; set movement amount for podoboo/other objects
bra_set_high_vertical_speed_limit:
    LDA #$03  ; set maximum speed in A
sub_apply_enemy_vertical_motion:
    STY $00  ; set movement amount here
    INX  ; increment X for enemy offset
    JSR sub_apply_sprite_object_gravity  ; do a sub to move enemy object downwards
    LDX ram_object_offset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------

tbl_block_maximum_y_speed:
    .byte $06, $08

unused_gravity_block_entry:
    LDY #$00  ; this part appears to be residual,
    .byte $2c  ; no code branches or jumps to it

sub_apply_block_gravity:
    LDY #$01  ; set offset for maximum speed
    LDA #$50  ; set movement amount here
    STA $00
    LDA tbl_block_maximum_y_speed,y  ; get maximum speed

sub_apply_sprite_object_gravity:
    STA $02  ; set maximum speed here
    LDA #$00  ; set value to move downwards
    JMP sub_apply_object_gravity  ; jump to the code that actually moves it

; --------------------------------

sub_move_platform_down:
    LDA #$00  ; save value to stack (if branching here, execute next
    .byte $2c  ; part as BIT instruction)

sub_move_platform_up:
    LDA #$01  ; save value to stack
    PHA
    LDY ram_enemy_id,x  ; get enemy object identifier
    INX  ; increment offset for enemy object
    LDA #$05  ; load default value here
    CPY #$29  ; residual comparison, object #29 never executes
    BNE bra_set_platform_gravity_force  ; this code, thus unconditional branch here
    LDA #$09  ; residual code
bra_set_platform_gravity_force:
    STA $00  ; save downward movement amount here
    LDA #$0a  ; save upward movement amount here
    STA $01
    LDA #$03  ; save maximum vertical speed here
    STA $02
    PLA  ; get value from stack
    TAY  ; use as Y, then move onto code shared by red koopa

loc_apply_red_paratroopa_gravity:
    JSR sub_apply_object_gravity  ; do a sub to move object gradually
    LDX ram_object_offset  ; get enemy object offset and leave
    RTS

; -------------------------------------------------------------------------------------
; $00 - used for downward force
; $01 - used for upward force
; $07 - used as adder for vertical position

; Integrate an object's 8.8 vertical position and velocity with acceleration

; Inputs:
; A - zero for downward-only motion, nonzero to apply upward acceleration
; X - sprite-object slot
; $00 - downward acceleration
; $01 - upward acceleration
; $02 - maximum vertical speed magnitude

; Outputs:
; Object vertical page, pixel, position fraction, speed, and speed fraction
; are updated

; Clobbers:
; A, Y
sub_apply_object_gravity:
    PHA  ; push value to stack
    LDA ram_spr_object_ymf_dummy,x
    CLC  ; add value in movement force to contents of dummy variable
    ADC ram_spr_object_y_move_force,x
    STA ram_spr_object_ymf_dummy,x
    LDY #$00  ; set Y to zero by default
    LDA ram_spr_object_y_speed,x  ; get current vertical speed
    BPL bra_update_object_y_position  ; if currently moving downwards, do not decrement Y
    DEY  ; otherwise decrement Y
bra_update_object_y_position:
    STY $07  ; store Y here
    ADC ram_spr_object_y_position,x  ; add vertical position to vertical speed plus carry
    STA ram_spr_object_y_position,x  ; store as new vertical position
    LDA ram_spr_object_y_high_pos,x
    ADC $07  ; add carry plus contents of $07 to vertical high byte
    STA ram_spr_object_y_high_pos,x  ; store as new vertical high byte
    LDA ram_spr_object_y_move_force,x
    CLC
    ADC $00  ; add downward movement amount to contents of $0433
    STA ram_spr_object_y_move_force,x
    LDA ram_spr_object_y_speed,x  ; add carry to vertical speed and store
    ADC #$00
    STA ram_spr_object_y_speed,x
    CMP $02  ; compare to maximum speed
    BMI bra_apply_upward_gravity  ; if less than preset value, skip this part
    LDA ram_spr_object_y_move_force,x
    CMP #$80  ; if less positively than preset maximum, skip this part
    BCC bra_apply_upward_gravity
    LDA $02
    STA ram_spr_object_y_speed,x  ; keep vertical speed within maximum value
    LDA #$00
    STA ram_spr_object_y_move_force,x  ; clear fractional
bra_apply_upward_gravity:
    PLA  ; get value from stack
    BEQ bra_return_from_vertical_movement  ; if set to zero, branch to leave
    LDA $02
    EOR #%11111111  ; otherwise get two's compliment of maximum speed
    TAY
    INY
    STY $07  ; store two's compliment here
    LDA ram_spr_object_y_move_force,x
    SEC  ; subtract upward movement amount from contents
    SBC $01  ; of movement force, note that $01 is twice as large as $00,
    STA ram_spr_object_y_move_force,x  ; thus it effectively undoes add we did earlier
    LDA ram_spr_object_y_speed,x
    SBC #$00  ; subtract borrow from vertical speed and store
    STA ram_spr_object_y_speed,x
    CMP $07  ; compare vertical speed to two's compliment
    BPL bra_return_from_vertical_movement  ; if less negatively than preset maximum, skip this part
    LDA ram_spr_object_y_move_force,x
    CMP #$80  ; check if fractional part is above certain amount,
    BCS bra_return_from_vertical_movement  ; and if so, branch to leave
    LDA $07
    STA ram_spr_object_y_speed,x  ; keep vertical speed within maximum value
    LDA #$ff
    STA ram_spr_object_y_move_force,x  ; clear fractional
bra_return_from_vertical_movement:
    RTS  ; leave!
