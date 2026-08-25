; -------------------------------------------------------------------------------------

tbl_cannon_slot_masks_by_hard_mode:
    .byte %00001111, %00000111

sub_process_cannons:
    LDA ram_area_type  ; get area type
    BEQ bra_exit_cannon_processing  ; if water type area, branch to leave
    LDX #$02
bra_check_cannon_slots:
    STX ram_object_offset  ; start at third enemy slot
    LDA ram_enemy_flag,x  ; check enemy buffer flag
    BNE loc_check_bullet_bill_slot  ; if set, branch to check enemy
    LDA ram_pseudo_random_bit_reg+1,x  ; otherwise get part of LSFR
    LDY ram_secondary_hard_mode  ; get secondary hard mode flag, use as offset
    AND tbl_cannon_slot_masks_by_hard_mode,y  ; mask out bits of LSFR as decided by flag
    CMP #$06  ; check to see if lower nybble is above certain value
    BCS loc_check_bullet_bill_slot  ; if so, branch to check enemy
    TAY  ; transfer masked contents of LSFR to Y as pseudorandom offset
    LDA ram_cannon_page_loc,y  ; get page location
    BEQ loc_check_bullet_bill_slot  ; if not set or on page 0, branch to check enemy
    LDA ram_cannon_timer,y  ; get cannon timer
    BEQ bra_fire_bullet_bill_cannon  ; if expired, branch to fire cannon
    SBC #$00  ; otherwise subtract borrow (note carry will always be clear here)
    STA ram_cannon_timer,y  ; to count timer down
    JMP loc_check_bullet_bill_slot  ; then jump ahead to check enemy

bra_fire_bullet_bill_cannon:
    LDA ram_timer_control  ; if master timer control set,
    BNE loc_check_bullet_bill_slot  ; branch to check enemy
    LDA #$0e  ; otherwise we start creating one
    STA ram_cannon_timer,y  ; first, reset cannon timer
    LDA ram_cannon_page_loc,y  ; get page location of cannon
    STA ram_enemy_page_loc,x  ; save as page location of bullet bill
    LDA ram_cannon_x_position,y  ; get horizontal coordinate of cannon
    STA ram_enemy_x_position,x  ; save as horizontal coordinate of bullet bill
    LDA ram_cannon_y_position,y  ; get vertical coordinate of cannon
    SEC
    SBC #$08  ; subtract eight pixels (because enemies are 24 pixels tall)
    STA ram_enemy_y_position,x  ; save as vertical coordinate of bullet bill
    LDA #$01
    STA ram_enemy_y_high_pos,x  ; set vertical high byte of bullet bill
    STA ram_enemy_flag,x  ; set buffer flag
    LSR  ; shift right once to init A
    STA ram_enemy_state,x  ; then initialize enemy's state
    LDA #$09
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box size control for bullet bill
    LDA #con_bullet_bill_cannon_var
    STA ram_enemy_id,x  ; load identifier for bullet bill (cannon variant)
    JMP loc_advance_cannon_slot  ; move onto next slot
loc_check_bullet_bill_slot:
    LDA ram_enemy_id,x  ; check enemy identifier for bullet bill (cannon variant)
    CMP #con_bullet_bill_cannon_var
    BNE loc_advance_cannon_slot  ; if not found, branch to get next slot
    JSR sub_offscreen_bounds_check  ; otherwise, check to see if it went offscreen
    LDA ram_enemy_flag,x  ; check enemy buffer flag
    BEQ loc_advance_cannon_slot  ; if not set, branch to get next slot
    JSR sub_get_enemy_offscreen_bits  ; otherwise, get offscreen information
    JSR sub_bullet_bill_handler  ; then do sub to handle bullet bill
loc_advance_cannon_slot:
    DEX  ; move onto next slot
    BPL bra_check_cannon_slots  ; do this until first three slots are checked
bra_exit_cannon_processing:
    RTS  ; then leave

; --------------------------------

tbl_bullet_bill_x_speeds:
    .byte $18, $e8

sub_bullet_bill_handler:
    LDA ram_timer_control  ; if master timer control set,
    BNE bra_run_bullet_bill_subsystems  ; branch to run subroutines except movement sub
    LDA ram_enemy_state,x
    BNE bra_check_bullet_bill_defeated_state  ; if bullet bill's state set, branch to check defeated state
    LDA ram_enemy_offscreen_bits  ; otherwise load offscreen bits
    AND #%00001100  ; mask out bits
    CMP #%00001100  ; check to see if all bits are set
    BEQ bra_erase_bullet_bill  ; if so, branch to kill this object
    LDY #$01  ; set to move right by default
    JSR sub_player_enemy_diff  ; get horizontal difference between player and bullet bill
    BMI bra_initialize_bullet_bill  ; if enemy to the left of player, branch
    INY  ; otherwise increment to move left
bra_initialize_bullet_bill:
    STY ram_enemy_moving_dir,x  ; set bullet bill's moving direction
    DEY  ; decrement to use as offset
    LDA tbl_bullet_bill_x_speeds,y  ; get horizontal speed based on moving direction
    STA ram_enemy_x_speed,x  ; and store it
    LDA $00  ; get horizontal difference
    ADC #$28  ; add 40 pixels
    CMP #$50  ; if less than a certain amount, player is too close
    BCC bra_erase_bullet_bill  ; to cannon either on left or right side, thus branch
    LDA #$01
    STA ram_enemy_state,x  ; otherwise set bullet bill's state
    LDA #$0a
    STA ram_enemy_frame_timer,x  ; set enemy frame timer
    LDA #con_sfx_blast
    STA ram_square2_sound_queue  ; play fireworks/gunfire sound
bra_check_bullet_bill_defeated_state:
    LDA ram_enemy_state,x  ; check enemy state for d5 set
    AND #%00100000
    BEQ bra_update_bullet_bill_flight  ; if not set, skip to move horizontally
    JSR sub_move_enemy_downward_fast  ; otherwise do sub to move bullet bill vertically
bra_update_bullet_bill_flight:
    JSR sub_move_enemy_horizontally  ; do sub to move bullet bill horizontally
bra_run_bullet_bill_subsystems:
    JSR sub_get_enemy_offscreen_bits  ; get offscreen information
    JSR sub_relative_enemy_position  ; get relative coordinates
    JSR sub_get_enemy_bound_box  ; get bounding box coordinates
    JSR sub_player_enemy_collision  ; handle player to enemy collisions
    JMP sub_render_enemy_graphics  ; draw the bullet bill and leave
bra_erase_bullet_bill:
    JSR sub_erase_enemy_object  ; kill bullet bill and leave
    RTS

; -------------------------------------------------------------------------------------

tbl_hammer_misc_to_enemy_slot_offsets:
    .byte $04, $04, $04, $05, $05, $05
    .byte $06, $06, $06

tbl_hammer_x_speeds:
    .byte $10, $f0

sub_spawn_hammer_object:
    LDA ram_pseudo_random_bit_reg+1  ; get pseudorandom bits from
    AND #%00000111  ; second part of LSFR
    BNE bra_select_hammer_misc_slot  ; if any bits are set, branch and use as offset
    LDA ram_pseudo_random_bit_reg+1
    AND #%00001000  ; get d3 from same part of LSFR
bra_select_hammer_misc_slot:
    TAY  ; use either d3 or d2-d0 for offset here
    LDA ram_misc_state,y  ; if any values loaded in
    BNE bra_reject_hammer_spawn  ; $2a-$32 where offset is then leave with carry clear
    LDX tbl_hammer_misc_to_enemy_slot_offsets,y  ; get offset of enemy slot to check using Y as offset
    LDA ram_enemy_flag,x  ; check enemy buffer flag at offset
    BNE bra_reject_hammer_spawn  ; if buffer flag set, branch to leave with carry clear
    LDX ram_object_offset  ; get original enemy object offset
    TXA
    STA ram_hammer_enemy_offset,y  ; save here
    LDA #$90
    STA ram_misc_state,y  ; save hammer's state here
    LDA #$07
    STA ram_misc_bound_box_ctrl,y  ; set something else entirely, here
    SEC  ; return with carry set
    RTS
bra_reject_hammer_spawn:
    LDX ram_object_offset  ; get original enemy object offset
    CLC  ; return with carry clear
    RTS

; --------------------------------
; $00 - used to set downward force
; $01 - used to set upward force (residual)
; $02 - used to set maximum speed

sub_process_hammer_object:
    LDA ram_timer_control  ; if master timer control set
    BNE bra_run_hammer_subsystems  ; skip all of this code and go to last subs at the end
    LDA ram_misc_state,x  ; otherwise get hammer's state
    AND #%01111111  ; mask out d7
    LDY ram_hammer_enemy_offset,x  ; get enemy object offset that spawned this hammer
    CMP #$02  ; check hammer's state
    BEQ bra_store_hammer_x_speed  ; if currently at 2, branch
    BCS bra_store_hammer_position  ; if greater than 2, branch elsewhere
    TXA
    CLC  ; add 13 bytes to use
    ADC #$0d  ; proper misc object
    TAX  ; return offset to X
    LDA #$10
    STA $00  ; set downward movement force
    LDA #$0f
    STA $01  ; set upward movement force (not used)
    LDA #$04
    STA $02  ; set maximum vertical speed
    LDA #$00  ; set A to impose gravity on hammer
    JSR sub_apply_object_gravity  ; do sub to impose gravity on hammer and move vertically
    JSR sub_move_object_horizontally  ; do sub to move it horizontally
    LDX ram_object_offset  ; get original misc object offset
    JMP loc_process_all_hammers  ; branch to essential subroutines
bra_store_hammer_x_speed:
    LDA #$fe
    STA ram_misc_y_speed,x  ; set hammer's vertical speed
    LDA ram_enemy_state,y  ; get enemy object state
    AND #%11110111  ; mask out d3
    STA ram_enemy_state,y  ; store new state
    LDX ram_enemy_moving_dir,y  ; get enemy's moving direction
    DEX  ; decrement to use as offset
    LDA tbl_hammer_x_speeds,x  ; get proper speed to use based on moving direction
    LDX ram_object_offset  ; reobtain hammer's buffer offset
    STA ram_misc_x_speed,x  ; set hammer's horizontal speed
bra_store_hammer_position:
    DEC ram_misc_state,x  ; decrement hammer's state
    LDA ram_enemy_x_position,y  ; get enemy's horizontal position
    CLC
    ADC #$02  ; set position 2 pixels to the right
    STA ram_misc_x_position,x  ; store as hammer's horizontal position
    LDA ram_enemy_page_loc,y  ; get enemy's page location
    ADC #$00  ; add carry
    STA ram_misc_page_loc,x  ; store as hammer's page location
    LDA ram_enemy_y_position,y  ; get enemy's vertical position
    SEC
    SBC #$0a  ; move position 10 pixels upward
    STA ram_misc_y_position,x  ; store as hammer's vertical position
    LDA #$01
    STA ram_misc_y_high_pos,x  ; set hammer's vertical high byte
    BNE bra_run_hammer_subsystems  ; unconditional branch to skip first routine
loc_process_all_hammers:
    JSR sub_player_hammer_collision  ; handle collisions
bra_run_hammer_subsystems:
    JSR sub_get_misc_offscreen_bits  ; get offscreen information
    JSR sub_relative_misc_position  ; get relative coordinates
    JSR sub_get_misc_bound_box  ; get bounding box coordinates
    JSR sub_draw_hammer  ; draw the hammer
    RTS  ; and we are done here

; -------------------------------------------------------------------------------------
; $02 - used to store vertical high nybble offset from block buffer routine
; $06 - used to store low byte of block buffer address

handler_run_coin_block:
    JSR sub_find_empty_misc_slot  ; set offset for empty or last misc object buffer slot
    LDA ram_block_page_loc,x  ; get page location of block object
    STA ram_misc_page_loc,y  ; store as page location of misc object
    LDA ram_block_x_position,x  ; get horizontal coordinate of block object
    ORA #$05  ; add 5 pixels
    STA ram_misc_x_position,y  ; store as horizontal coordinate of misc object
    LDA ram_block_y_position,x  ; get vertical coordinate of block object
    SBC #$10  ; subtract 16 pixels
    STA ram_misc_y_position,y  ; store as vertical coordinate of misc object
    JMP loc_initialize_jump_coin  ; jump to rest of code as applies to this misc object

sub_setup_jump_coin:
    JSR sub_find_empty_misc_slot  ; set offset for empty or last misc object buffer slot
    LDA ram_block_page_loc2,x  ; get page location saved earlier
    STA ram_misc_page_loc,y  ; and save as page location for misc object
    LDA $06  ; get low byte of block buffer offset
    ASL
    ASL  ; multiply by 16 to use lower nybble
    ASL
    ASL
    ORA #$05  ; add five pixels
    STA ram_misc_x_position,y  ; save as horizontal coordinate for misc object
    LDA $02  ; get vertical high nybble offset from earlier
    ADC #$20  ; add 32 pixels for the status bar
    STA ram_misc_y_position,y  ; store as vertical coordinate
loc_initialize_jump_coin:
    LDA #$fb
    STA ram_misc_y_speed,y  ; set vertical speed
    LDA #$01
    STA ram_misc_y_high_pos,y  ; set vertical high byte
    STA ram_misc_state,y  ; set state for misc object
    STA ram_square2_sound_queue  ; load coin grab sound
    STX ram_object_offset  ; store current control bit as misc object offset
    JSR sub_give_one_coin  ; update coin tally on the screen and coin amount variable
    INC ram_coin_tally_for1_ups  ; increment coin tally used to activate 1-up block flag
    RTS

sub_find_empty_misc_slot:
    LDY #$08  ; start at end of misc objects buffer
bra_find_empty_misc_slot_loop:
    LDA ram_misc_state,y  ; get misc object state
    BEQ bra_store_selected_misc_slot  ; branch if none found to use current offset
    DEY  ; decrement offset
    CPY #$05  ; do this for three slots
    BNE bra_find_empty_misc_slot_loop  ; do this until all slots are checked
    LDY #$08  ; if no empty slots found, use last slot
bra_store_selected_misc_slot:
    STY ram_jump_coin_misc_offset  ; store offset of misc object buffer here (residual)
    RTS

; -------------------------------------------------------------------------------------

sub_misc_objects_core:
    LDX #$08  ; set at end of misc object buffer
bra_process_misc_object_slots:
    STX ram_object_offset  ; store misc object offset here
    LDA ram_misc_state,x  ; check misc object state
    BEQ loc_advance_misc_object_slot  ; branch to check next slot
    ASL  ; otherwise shift d7 into carry
    BCC bra_process_jump_coin_or_score  ; if d7 not set, jumping coin, thus skip to rest of code here
    JSR sub_process_hammer_object  ; otherwise go to process hammer,
    JMP loc_advance_misc_object_slot  ; then check next slot

; --------------------------------
; $00 - used to set downward force
; $01 - used to set upward force (residual)
; $02 - used to set maximum speed

bra_process_jump_coin_or_score:
    LDY ram_misc_state,x  ; check misc object state
    DEY  ; decrement to see if it's set to 1
    BEQ bra_update_jumping_coin  ; if so, branch to handle jumping coin
    INC ram_misc_state,x  ; otherwise increment state to either start off or as timer
    LDA ram_misc_x_position,x  ; get horizontal coordinate for misc object
    CLC  ; whether its jumping coin (state 0 only) or floatey number
    ADC ram_scroll_amount  ; add current scroll speed
    STA ram_misc_x_position,x  ; store as new horizontal coordinate
    LDA ram_misc_page_loc,x  ; get page location
    ADC #$00  ; add carry
    STA ram_misc_page_loc,x  ; store as new page location
    LDA ram_misc_state,x
    CMP #$30  ; check state of object for preset value
    BNE bra_run_jump_coin_subsystems  ; if not yet reached, branch to subroutines
    LDA #$00
    STA ram_misc_state,x  ; otherwise nullify object state
    JMP loc_advance_misc_object_slot  ; and move onto next slot
bra_update_jumping_coin:
    TXA
    CLC  ; add 13 bytes to offset for next subroutine
    ADC #$0d
    TAX
    LDA #$50  ; set downward movement amount
    STA $00
    LDA #$06  ; set maximum vertical speed
    STA $02
    LSR  ; divide by 2 and set
    STA $01  ; as upward movement amount (apparently residual)
    LDA #$00  ; set A to impose gravity on jumping coin
    JSR sub_apply_object_gravity  ; do sub to move coin vertically and impose gravity on it
    LDX ram_object_offset  ; get original misc object offset
    LDA ram_misc_y_speed,x  ; check vertical speed
    CMP #$05
    BNE bra_run_jump_coin_subsystems  ; if not moving downward fast enough, keep state as-is
    INC ram_misc_state,x  ; otherwise increment state to change to floatey number
bra_run_jump_coin_subsystems:
    JSR sub_relative_misc_position  ; get relative coordinates
    JSR sub_get_misc_offscreen_bits  ; get offscreen information
    JSR sub_get_misc_bound_box  ; get bounding box coordinates (why?)
    JSR sub_render_jumping_coin_graphics  ; draw the coin or floatey number

loc_advance_misc_object_slot:
    DEX  ; decrement misc object offset
    BPL bra_process_misc_object_slots  ; loop back until all misc objects handled
    RTS  ; then leave

; -------------------------------------------------------------------------------------

tbl_coin_tally_digit_offsets:
    .byte $17, $1d

tbl_score_digit_offsets:
    .byte $0b, $11

tbl_status_bar_nibbles:
    .byte $02, $13

sub_give_one_coin:
    LDA #$01  ; set digit modifier to add 1 coin
    STA ram_digit_modifier+5  ; to the current player's coin tally
    LDX ram_current_player  ; get current player on the screen
    LDY tbl_coin_tally_digit_offsets,x  ; get offset for player's coin tally
    JSR sub_digits_math_routine  ; update the coin tally
    INC ram_coin_tally  ; increment onscreen player's coin amount
    LDA ram_coin_tally
    CMP #100  ; does player have 100 coins yet?
    BNE bra_award_coin_points  ; if not, skip all of this
    LDA #$00
    STA ram_coin_tally  ; otherwise, reinitialize coin amount
    INC ram_numberof_lives  ; give the player an extra life
    LDA #con_sfx_extra_life
    STA ram_square2_sound_queue  ; play 1-up sound

bra_award_coin_points:
    LDA #$02  ; set digit modifier to award
    STA ram_digit_modifier+4  ; 200 points to the player

sub_add_to_score:
    LDX ram_current_player  ; get current player
    LDY tbl_score_digit_offsets,x  ; get offset for player's score
    JSR sub_digits_math_routine  ; update the score internally with value in digit modifier

sub_get_status_bar_nibbles:
    LDY ram_current_player  ; get current player
    LDA tbl_status_bar_nibbles,y  ; get nybbles based on player, use to update score and coins

sub_update_number:
    JSR sub_print_status_bar_numbers  ; print status bar numbers based on nybbles, whatever they be
    LDY ram_vram_buffer1_offset
    LDA ram_vram_buffer1-6,y  ; check highest digit of score
    BNE bra_finish_score_zero_suppression  ; if zero, overwrite with space tile for zero suppression
    LDA #$24
    STA ram_vram_buffer1-6,y
bra_finish_score_zero_suppression:
    LDX ram_object_offset  ; get enemy object buffer offset
    RTS

; -------------------------------------------------------------------------------------

loc_setup_power_up_object:
    LDA #con_power_up_object  ; load power-up identifier into
    STA ram_enemy_id+5  ; special use slot of enemy object buffer
    LDA ram_block_page_loc,x  ; store page location of block object
    STA ram_enemy_page_loc+5  ; as page location of power-up object
    LDA ram_block_x_position,x  ; store horizontal coordinate of block object
    STA ram_enemy_x_position+5  ; as horizontal coordinate of power-up object
    LDA #$01
    STA ram_enemy_y_high_pos+5  ; set vertical high byte of power-up object
    LDA ram_block_y_position,x  ; get vertical coordinate of block object
    SEC
    SBC #$08  ; subtract 8 pixels
    STA ram_enemy_y_position+5  ; and use as vertical coordinate of power-up object
handler_initialize_power_up_object:
    LDA #$01  ; this is a residual jump point in enemy object jump table
    STA ram_enemy_state+5  ; set power-up object's state
    STA ram_enemy_flag+5  ; set buffer flag
    LDA #$03
    STA ram_enemy_bound_box_ctrl+5  ; set bounding box size control for power-up object
    LDA ram_power_up_type
    CMP #$02  ; check currently loaded power-up type
    BCS bra_put_power_up_behind_background  ; if star or 1-up, branch ahead
    LDA ram_player_status  ; otherwise check player's current status
    CMP #$02
    BCC bra_store_power_up_type  ; if player not fiery, use status as power-up type
    LSR  ; otherwise shift right to force fire flower type
bra_store_power_up_type:
    STA ram_power_up_type  ; store type here
bra_put_power_up_behind_background:
    LDA #%00100000
    STA ram_enemy_spr_attrib+5  ; set background priority bit
    LDA #con_sfx_grow_power_up
    STA ram_square2_sound_queue  ; load power-up reveal sound and leave
    RTS

; -------------------------------------------------------------------------------------

handler_process_power_up_object:
    LDX #$05  ; set object offset for last slot in enemy object buffer
    STX ram_object_offset
    LDA ram_enemy_state+5  ; check power-up object's state
    BEQ bra_exit_power_up_handler  ; if not set, branch to leave
    ASL  ; shift to check if d7 was set in object state
    BCC bra_raise_power_up_from_block  ; if not set, branch ahead to skip this part
    LDA ram_timer_control  ; if master timer control set,
    BNE loc_run_power_up_subsystems  ; branch ahead to enemy object routines
    LDA ram_power_up_type  ; check power-up type
    BEQ bra_move_mushroom_power_up  ; if normal mushroom, branch ahead to move it
    CMP #$03
    BEQ bra_move_mushroom_power_up  ; if 1-up mushroom, branch ahead to move it
    CMP #$02
    BNE loc_run_power_up_subsystems  ; if not star, branch elsewhere to skip movement
    JSR sub_move_jumping_enemy  ; otherwise impose gravity on star power-up and make it jump
    JSR sub_enemy_jump  ; note that green paratroopa shares the same code here
    JMP loc_run_power_up_subsystems  ; then jump to other power-up subroutines
bra_move_mushroom_power_up:
    JSR sub_move_normal_enemy  ; do sub to make mushrooms move
    JSR sub_detect_enemy_background_collision  ; deal with collisions
    JMP loc_run_power_up_subsystems  ; run the other subroutines

bra_raise_power_up_from_block:
    LDA ram_frame_counter  ; get frame counter
    AND #$03  ; mask out all but 2 LSB
    BNE bra_check_power_up_state  ; if any bits set here, branch
    DEC ram_enemy_y_position+5  ; otherwise decrement vertical coordinate slowly
    LDA ram_enemy_state+5  ; load power-up object state
    INC ram_enemy_state+5  ; increment state for next frame (to make power-up rise)
    CMP #$11  ; if power-up object state not yet past 16th pixel,
    BCC bra_check_power_up_state  ; branch ahead to last part here
    LDA #$10
    STA ram_enemy_x_speed,x  ; otherwise set horizontal speed
    LDA #%10000000
    STA ram_enemy_state+5  ; and then set d7 in power-up object's state
    ASL  ; shift once to init A
    STA ram_enemy_spr_attrib+5  ; initialize background priority bit set here
    ROL  ; rotate A to set right moving direction
    STA ram_enemy_moving_dir,x  ; set moving direction
bra_check_power_up_state:
    LDA ram_enemy_state+5  ; check power-up object's state
    CMP #$06  ; for if power-up has risen enough
    BCC bra_exit_power_up_handler  ; if not, don't even bother running these routines
loc_run_power_up_subsystems:
    JSR sub_relative_enemy_position  ; get coordinates relative to screen
    JSR sub_get_enemy_offscreen_bits  ; get offscreen bits
    JSR sub_get_enemy_bound_box  ; get bounding box coordinates
    JSR sub_draw_power_up  ; draw the power-up object
    JSR sub_player_enemy_collision  ; check for collision with player
    JSR sub_offscreen_bounds_check  ; check to see if it went offscreen
bra_exit_power_up_handler:
    RTS  ; and we're done
