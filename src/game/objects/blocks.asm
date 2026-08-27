; -------------------------------------------------------------------------------------
; These apply to all routines in this section unless otherwise noted:
; $00 - used to store metatile from block buffer routine
; $02 - used to store vertical high nybble offset from block buffer routine
; $05 - used to store metatile stored in A at beginning of sub_player_head_collision
; $06-$07 - used as block buffer address indirect

tbl_block_y_position_adders:
    .byte $04, $12

sub_player_head_collision:
    PHA  ; store metatile number to stack
    LDA #$11  ; load unbreakable block object state by default
    LDX ram_spr_data_offset_ctrl  ; load offset control bit here
    LDY ram_player_size  ; check player's size
    BNE bra_store_bumped_block_state  ; if small, branch
    LDA #$12  ; otherwise load breakable block object state
bra_store_bumped_block_state:
    STA ram_block_state,x  ; store into block object buffer
    JSR sub_destroy_block_metatile  ; store blank metatile in vram buffer to write to name table
    LDX ram_spr_data_offset_ctrl  ; load offset control bit
    LDA $02  ; get vertical high nybble offset used in block buffer routine
    STA ram_block_orig_y_pos,x  ; set as vertical coordinate for block object
    TAY
    LDA $06  ; get low byte of block buffer address used in same routine
    STA ram_block_b_buf_low,x  ; save as offset here to be used later
    LDA ($06),y  ; get contents of block buffer at old address at $06, $07
    JSR sub_check_bumped_block  ; do a sub to check which block player bumped head on
    STA $00  ; store metatile here
    LDY ram_player_size  ; check player's size
    BNE bra_check_bumped_brick  ; if small, use metatile itself as contents of A
    TYA  ; otherwise init A (note: big = 0)
bra_check_bumped_brick:
    BCC bra_store_block_replacement_metatile  ; if no match was found in previous sub, skip ahead
    LDY #$11  ; otherwise load unbreakable state into block object buffer
    STY ram_block_state,x  ; note this applies to both player sizes
    LDA #$c4  ; load empty block metatile into A for now
    LDY $00  ; get metatile from before
    CPY #$58  ; is it brick with coins (with line)?
    BEQ bra_start_brick_coin_timer  ; if so, branch
    CPY #$5d  ; is it brick with coins (without line)?
    BNE bra_store_block_replacement_metatile  ; if not, branch ahead to store empty block metatile
bra_start_brick_coin_timer:
    LDA ram_brick_coin_timer_flag  ; check brick coin timer flag
    BNE bra_continue_brick_coin_timer  ; if set, timer expired or counting down, thus branch
    LDA #$0b
    STA ram_brick_coin_timer  ; if not set, set brick coin timer
    INC ram_brick_coin_timer_flag  ; and set flag linked to it
bra_continue_brick_coin_timer:
    LDA ram_brick_coin_timer  ; check brick coin timer
    BNE bra_use_existing_brick_metatile  ; if not yet expired, branch to use current metatile
    LDY #$c4  ; otherwise use empty block metatile
bra_use_existing_brick_metatile:
    TYA  ; put metatile into A
bra_store_block_replacement_metatile:
    STA ram_block_metatile,x  ; store whatever metatile be appropriate here
    JSR sub_initialize_block_position  ; get block object horizontal coordinates saved
    LDY $02  ; get vertical high nybble offset
    LDA #$23
    STA ($06),y  ; write blank metatile $23 to block buffer
    LDA #con_block_bounce_timer
    STA ram_block_bounce_timer  ; set block bounce timer
    PLA  ; pull original metatile from stack
    STA $05  ; and save here
    LDY #$00  ; set default offset
    LDA ram_crouching_flag  ; is player crouching?
    BNE bra_use_small_player_block_y_offset  ; if so, branch to increment offset
    LDA ram_player_size  ; is player big?
    BEQ bra_set_bumped_block_y_position  ; if so, branch to use default offset
bra_use_small_player_block_y_offset:
    INY  ; increment for small or big and crouching
bra_set_bumped_block_y_position:
    LDA ram_player_y_position  ; get player's vertical coordinate
    CLC
    ADC tbl_block_y_position_adders,y  ; add value determined by size
    AND #$f0  ; mask out low nybble to get 16-pixel correspondence
    STA ram_block_y_position,x  ; save as vertical coordinate for block object
    LDY ram_block_state,x  ; get block object state
    CPY #$11
    BEQ bra_bump_unbreakable_block  ; if set to value loaded for unbreakable, branch
    JSR sub_brick_shatter  ; execute code for breakable brick
    JMP loc_toggle_block_object_slot  ; skip subroutine to do last part of code here
bra_bump_unbreakable_block:
    JSR sub_bump_block  ; execute code for unbreakable brick or question block
loc_toggle_block_object_slot:
    LDA ram_spr_data_offset_ctrl  ; invert control bit used by block objects
    EOR #$01  ; and floatey numbers
    STA ram_spr_data_offset_ctrl
    RTS  ; leave!

; --------------------------------

sub_initialize_block_position:
    LDA ram_player_x_position  ; get player's horizontal coordinate
    CLC
    ADC #$08  ; add eight pixels
    AND #$f0  ; mask out low nybble to give 16-pixel correspondence
    STA ram_block_x_position,x  ; save as horizontal coordinate for block object
    LDA ram_player_page_loc
    ADC #$00  ; add carry to page location of player
    STA ram_block_page_loc,x  ; save as page location of block object
    STA ram_block_page_loc2,x  ; save elsewhere to be used later
    LDA ram_player_y_high_pos
    STA ram_block_y_high_pos,x  ; save vertical high byte of player into
    RTS  ; vertical high byte of block object and leave

; --------------------------------

sub_bump_block:
    JSR sub_check_top_of_block  ; check to see if there's a coin directly above this block
    LDA #con_sfx_bump
    STA ram_square1_sound_queue  ; play bump sound
    LDA #$00
    STA ram_block_x_speed,x  ; initialize horizontal speed for block object
    STA ram_block_y_move_force,x  ; init fractional movement force
    STA ram_player_y_speed  ; init player's vertical speed
    LDA #$fe
    STA ram_block_y_speed,x  ; set vertical speed for block object
    LDA $05  ; get original metatile from stack
    JSR sub_check_bumped_block  ; do a sub to check which block player bumped head on
    BCC bra_exit_block_content_check  ; if no match was found, branch to leave
    TYA  ; move block number to A
    CMP #$09  ; if block number was within 0-8 range,
    BCC bra_dispatch_block_contents  ; branch to use current number
    SBC #$05  ; otherwise subtract 5 for second set to get proper number
bra_dispatch_block_contents:
    JSR sub_dispatch_inline_handler  ; run appropriate subroutine depending on block number

    .word handler_mushroom_or_flower_block
    .word handler_run_coin_block
    .word handler_run_coin_block
    .word handler_extra_life_mushroom_block
    .word handler_mushroom_or_flower_block
    .word handler_release_vine_from_block
    .word handler_release_star_from_block
    .word handler_run_coin_block
    .word handler_extra_life_mushroom_block

; --------------------------------

handler_mushroom_or_flower_block:
    LDA #$00  ; load mushroom/fire flower into power-up type
    .byte $2c  ; BIT instruction opcode

handler_release_star_from_block:
    LDA #$02  ; load star into power-up type
    .byte $2c  ; BIT instruction opcode

handler_extra_life_mushroom_block:
    LDA #$03  ; load 1-up mushroom into power-up type
    STA $39  ; store correct power-up type
    JMP loc_setup_power_up_object

handler_release_vine_from_block:
    LDX #$05  ; load last slot for enemy object buffer
    LDY ram_spr_data_offset_ctrl  ; get control bit
    JSR sub_setup_vine  ; set up vine object

bra_exit_block_content_check:
    RTS  ; leave

; --------------------------------

tbl_brick_and_question_block_metatiles:
    .byte $c1, $c0, $5f, $60  ; used by question blocks

; these two sets are functionally identical, but look different
    .byte $55, $56, $57, $58, $59  ; used by ground level types
    .byte $5a, $5b, $5c, $5d, $5e  ; used by other level types

sub_check_bumped_block:
    LDY #$0d  ; start at end of metatile data
bra_check_bumped_blocks_loop:
    CMP tbl_brick_and_question_block_metatiles,y  ; check to see if current metatile matches
    BEQ bra_return_matching_bumped_metatile  ; metatile found in block buffer, branch if so
    DEY  ; otherwise move onto next metatile
    BPL bra_check_bumped_blocks_loop  ; do this until all metatiles are checked
    CLC  ; if none match, return with carry clear
bra_return_matching_bumped_metatile:
    RTS  ; note carry is set if found match

; --------------------------------

sub_brick_shatter:
    JSR sub_check_top_of_block  ; check to see if there's a coin directly above this block
    LDA #con_sfx_brick_shatter
    STA ram_block_rep_flag,x  ; set flag for block object to immediately replace metatile
    STA ram_noise_sound_queue  ; load brick shatter sound
    JSR sub_spawn_brick_chunks  ; create brick chunk objects
    LDA #$fe
    STA ram_player_y_speed  ; set vertical speed for player
    LDA #$05
    STA ram_digit_modifier+5  ; set digit modifier to give player 50 points
    JSR sub_add_to_score  ; do sub to update the score
    LDX ram_spr_data_offset_ctrl  ; load control bit and leave
    RTS

; --------------------------------

sub_check_top_of_block:
    LDX ram_spr_data_offset_ctrl  ; load control bit
    LDY $02  ; get vertical high nybble offset used in block buffer
    BEQ bra_exit_top_of_block_check  ; branch to leave if set to zero, because we're at the top
    TYA  ; otherwise set to A
    SEC
    SBC #$10  ; subtract $10 to move up one row in the block buffer
    STA $02  ; store as new vertical high nybble offset
    TAY
    LDA ($06),y  ; get contents of block buffer in same column, one row up
    CMP #$c2  ; is it a coin? (not underwater)
    BNE bra_exit_top_of_block_check  ; if not, branch to leave
    LDA #$00
    STA ($06),y  ; otherwise put blank metatile where coin was
    JSR sub_remove_coin_axe  ; write blank metatile to vram buffer
    LDX ram_spr_data_offset_ctrl  ; get control bit
    JSR sub_setup_jump_coin  ; create jumping coin object and update coin variables
bra_exit_top_of_block_check:
    RTS  ; leave!

; --------------------------------

sub_spawn_brick_chunks:
    LDA ram_block_x_position,x  ; set horizontal coordinate of block object
    STA ram_block_orig_x_pos,x  ; as original horizontal coordinate here
    LDA #$f0
    STA ram_block_x_speed,x  ; set horizontal speed for brick chunk objects
    STA ram_block_x_speed+2,x
    LDA #$fa
    STA ram_block_y_speed,x  ; set vertical speed for one
    LDA #$fc
    STA ram_block_y_speed+2,x  ; set lower vertical speed for the other
    LDA #$00
    STA ram_block_y_move_force,x  ; init fractional movement force for both
    STA ram_block_y_move_force+2,x
    LDA ram_block_page_loc,x
    STA ram_block_page_loc+2,x  ; copy page location
    LDA ram_block_x_position,x
    STA ram_block_x_position+2,x  ; copy horizontal coordinate
    LDA ram_block_y_position,x
    CLC  ; add 8 pixels to vertical coordinate
    ADC #$08  ; and save as vertical coordinate for one of them
    STA ram_block_y_position+2,x
    LDA #$fa
    STA ram_block_y_speed,x  ; set vertical speed...again??? (redundant)
    RTS

; -------------------------------------------------------------------------------------

sub_block_objects_core:
    LDA ram_block_state,x  ; get state of block object
    BEQ bra_store_block_object_state  ; if not set, branch to leave
    AND #$0f  ; mask out high nybble
    PHA  ; push to stack
    TAY  ; put in Y for now
    TXA
    CLC
    ADC #$09  ; add 9 bytes to offset (note two block objects are created
    TAX  ; when using brick chunks, but only one offset for both)
    DEY  ; decrement Y to check for solid block state
    BEQ bra_update_bouncing_block  ; branch if found, otherwise continue for brick chunks
    JSR sub_apply_block_gravity  ; do sub to impose gravity on one block object object
    JSR sub_move_object_horizontally  ; do another sub to move horizontally
    TXA
    CLC  ; move onto next block object
    ADC #$02
    TAX
    JSR sub_apply_block_gravity  ; do sub to impose gravity on other block object
    JSR sub_move_object_horizontally  ; do another sub to move horizontally
    LDX ram_object_offset  ; get block object offset used for both
    JSR sub_relative_block_position  ; get relative coordinates
    JSR sub_get_block_offscreen_bits  ; get offscreen information
    JSR sub_draw_brick_chunks  ; draw the brick chunks
    PLA  ; get lower nybble of saved state
    LDY ram_block_y_high_pos,x  ; check vertical high byte of block object
    BEQ bra_store_block_object_state  ; if above the screen, branch to kill it
    PHA  ; otherwise save state back into stack
    LDA #$f0
    CMP ram_block_y_position+2,x  ; check to see if bottom block object went
    BCS bra_check_block_top_collision  ; to the bottom of the screen, and branch if not
    STA ram_block_y_position+2,x  ; otherwise set offscreen coordinate
bra_check_block_top_collision:
    LDA ram_block_y_position,x  ; get top block object's vertical coordinate
    CMP #$f0  ; see if it went to the bottom of the screen
    PLA  ; pull block object state from stack
    BCC bra_store_block_object_state  ; if not, branch to save state
    BCS bra_clear_block_object  ; otherwise do unconditional branch to kill it

bra_update_bouncing_block:
    JSR sub_apply_block_gravity  ; do sub to impose gravity on block object
    LDX ram_object_offset  ; get block object offset
    JSR sub_relative_block_position  ; get relative coordinates
    JSR sub_get_block_offscreen_bits  ; get offscreen information
    JSR sub_draw_block  ; draw the block
    LDA ram_block_y_position,x  ; get vertical coordinate
    AND #$0f  ; mask out high nybble
    CMP #$05  ; check to see if low nybble wrapped around
    PLA  ; pull state from stack
    BCS bra_store_block_object_state  ; if still above amount, not time to kill block yet, thus branch
    LDA #$01
    STA ram_block_rep_flag,x  ; otherwise set flag to replace metatile
bra_clear_block_object:
    LDA #$00  ; if branched here, nullify object state
bra_store_block_object_state:
    STA ram_block_state,x  ; store contents of A in block object state
    RTS

; -------------------------------------------------------------------------------------
; $02 - used to store offset to block buffer
; $06-$07 - used to store block buffer address

sub_update_block_object_metatile:
    LDX #$01  ; set offset to start with second block object
bra_update_block_metatiles_loop:
    STX ram_object_offset  ; set offset here
    LDA ram_vram_buffer1  ; if vram buffer already being used here,
    BNE bra_advance_block_metatile_update  ; branch to move onto next block object
    LDA ram_block_rep_flag,x  ; if flag for block object already clear,
    BEQ bra_advance_block_metatile_update  ; branch to move onto next block object
    LDA ram_block_b_buf_low,x  ; get low byte of block buffer
    STA $06  ; store into block buffer address
    LDA #$05
    STA $07  ; set high byte of block buffer address
    LDA ram_block_orig_y_pos,x  ; get original vertical coordinate of block object
    STA $02  ; store here and use as offset to block buffer
    TAY
    LDA ram_block_metatile,x  ; get metatile to be written
    STA ($06),y  ; write it to the block buffer
    JSR sub_replace_block_metatile  ; do sub to replace metatile where block object is
    LDA #$00
    STA ram_block_rep_flag,x  ; clear block object flag
bra_advance_block_metatile_update:
    DEX  ; decrement block object offset
    BPL bra_update_block_metatiles_loop  ; do this until both block objects are dealt with
    RTS  ; then leave
