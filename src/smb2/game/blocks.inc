tbl_smb2_main_brick_and_question_block_metatiles:
    .byte $c1, $c2, $c0, $5e, $5f, $60, $61  ; used by question blocks

    .byte $52, $53, $54, $55, $56, $57  ; used by ground level bricks
    .byte $58, $59, $5a, $5b, $5c, $5d  ; used by other level bricks

sub_smb2_main_check_bumped_block:
    LDY #$12  ; start at end of metatile data
bra_smb2_main_check_bumped_blocks_loop:
    CMP tbl_smb2_main_brick_and_question_block_metatiles,y  ; check to see if current metatile matches
    BEQ bra_smb2_main_return_matching_bumped_metatile  ; metatile found in block buffer, branch if so
    DEY  ; otherwise move onto next metatile
    BPL bra_smb2_main_check_bumped_blocks_loop  ; do this until all metatiles are checked
    CLC  ; if none match, return with carry clear
bra_smb2_main_return_matching_bumped_metatile:
    RTS  ; note carry is set if found match

; --------------------------------

sub_smb2_main_brick_shatter:
    JSR sub_smb2_main_check_top_of_block  ; check to see if there's a coin directly above this block
    LDA #Sfx_BrickShatter
    STA Block_RepFlag,x  ; set flag for block object to immediately replace metatile
    STA NoiseSoundQueue  ; load brick shatter sound
    JSR sub_smb2_main_spawn_brick_chunks  ; create brick chunk objects
    LDA #$fe
    STA Player_Y_Speed  ; set vertical speed for player
    LDA #$05
    STA DigitModifier+5  ; set digit modifier to give player 50 points
    JSR sub_smb2_main_add_to_score  ; do sub to update the score
    LDX SprDataOffset_Ctrl  ; load control bit and leave
    RTS

; --------------------------------

sub_smb2_main_check_top_of_block:
    LDX SprDataOffset_Ctrl  ; load control bit
    LDY $02  ; get vertical high nybble offset used in block buffer
    BEQ bra_smb2_main_exit_top_of_block_check  ; branch to leave if set to zero, because we're at the top
    TYA  ; otherwise set to A
    SEC
    SBC #$10  ; subtract $10 to move up one row in the block buffer
    STA $02  ; store as new vertical high nybble offset
    TAY
    LDA ($06),y  ; get contents of block buffer in same column, one row up
    CMP #$c3  ; is it a coin? (not underwater)
    BNE bra_smb2_main_exit_top_of_block_check  ; if not, branch to leave
    LDA #$00
    STA ($06),y  ; otherwise put blank metatile where coin was
    JSR sub_smb2_main_remove_coin_axe  ; write blank metatile to vram buffer
    LDX SprDataOffset_Ctrl  ; get control bit
    JSR sub_smb2_main_setup_jump_coin  ; create jumping coin object and update coin variables
bra_smb2_main_exit_top_of_block_check:
    RTS  ; leave!

; --------------------------------

sub_smb2_main_spawn_brick_chunks:
    LDA Block_X_Position,x  ; set horizontal coordinate of block object
    STA Block_Orig_XPos,x  ; as original horizontal coordinate here
    LDA #$f0
    STA Block_X_Speed,x  ; set horizontal speed for brick chunk objects
    STA Block_X_Speed+2,x
    LDA #$fa
    STA Block_Y_Speed,x  ; set vertical speed for one
    LDA #$fc
    STA Block_Y_Speed+2,x  ; set lower vertical speed for the other
    LDA #$00
    STA Block_Y_MoveForce,x  ; init fractional movement force for both
    STA Block_Y_MoveForce+2,x
    LDA Block_PageLoc,x
    STA Block_PageLoc+2,x  ; copy page location
    LDA Block_X_Position,x
    STA Block_X_Position+2,x  ; copy horizontal coordinate
    LDA Block_Y_Position,x
    CLC  ; add 8 pixels to vertical coordinate
    ADC #$08  ; and save as vertical coordinate for one of them
    STA Block_Y_Position+2,x
    LDA #$fa
    STA Block_Y_Speed,x  ; set vertical speed...again??? (redundant)
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_block_objects_core:
    LDA Block_State,x  ; get state of block object
    BEQ bra_smb2_main_store_block_object_state  ; if not set, branch to leave
    AND #$0f  ; mask out high nybble
    PHA  ; push to stack
    TAY  ; put in Y for now
    TXA
    CLC
    ADC #$09  ; add 9 bytes to offset (note two block objects are created
    TAX  ; when using brick chunks, but only one offset for both)
    DEY  ; decrement Y to check for solid block state
    BEQ bra_smb2_main_update_bouncing_block  ; branch if found, otherwise continue for brick chunks
    JSR sub_smb2_main_apply_block_gravity  ; do sub to impose gravity on one block object object
    JSR sub_smb2_main_move_object_horizontally  ; do another sub to move horizontally
    TXA
    CLC  ; move onto next block object
    ADC #$02
    TAX
    JSR sub_smb2_main_apply_block_gravity  ; do sub to impose gravity on other block object
    JSR sub_smb2_main_move_object_horizontally  ; do another sub to move horizontally
    LDX ObjectOffset  ; get block object offset used for both
    JSR sub_smb2_main_relative_block_position  ; get relative coordinates
    JSR sub_smb2_main_get_block_offscreen_bits  ; get offscreen information
    JSR sub_smb2_main_draw_brick_chunks  ; draw the brick chunks
    PLA  ; get lower nybble of saved state
    LDY Block_Y_HighPos,x  ; check vertical high byte of block object
    BEQ bra_smb2_main_store_block_object_state  ; if above the screen, branch to kill it
    PHA  ; otherwise save state back into stack
    LDA #$f0
    CMP Block_Y_Position+2,x  ; check to see if bottom block object went
    BCS bra_smb2_main_check_block_top_collision  ; to the bottom of the screen, and branch if not
    STA Block_Y_Position+2,x  ; otherwise set offscreen coordinate
bra_smb2_main_check_block_top_collision:
    LDA Block_Y_Position,x  ; get top block object's vertical coordinate
    CMP #$f0  ; see if it went to the bottom of the screen
    PLA  ; pull block object state from stack
    BCC bra_smb2_main_store_block_object_state  ; if not, branch to save state
    BCS bra_smb2_main_clear_block_object  ; otherwise do unconditional branch to kill it

bra_smb2_main_update_bouncing_block:
    JSR sub_smb2_main_apply_block_gravity  ; do sub to impose gravity on block object
    LDX ObjectOffset  ; get block object offset
    JSR sub_smb2_main_relative_block_position  ; get relative coordinates
    JSR sub_smb2_main_get_block_offscreen_bits  ; get offscreen information
    JSR sub_smb2_main_draw_block  ; draw the block
    LDA Block_Y_Position,x  ; get vertical coordinate
    AND #$0f  ; mask out high nybble
    CMP #$05  ; check to see if low nybble wrapped around
    PLA  ; pull state from stack
    BCS bra_smb2_main_store_block_object_state  ; if still above amount, not time to kill block yet, thus branch
    LDA #$01
    STA Block_RepFlag,x  ; otherwise set flag to replace metatile
bra_smb2_main_clear_block_object:
    LDA #$00  ; if branched here, nullify object state
bra_smb2_main_store_block_object_state:
    STA Block_State,x  ; store contents of A in block object state
    RTS

; -------------------------------------------------------------------------------------
; $02 - used to store offset to block buffer
; $06-$07 - used to store block buffer address

sub_smb2_main_update_block_object_metatile:
    LDX #$01  ; set offset to start with second block object
bra_smb2_main_update_block_metatiles_loop:
    STX ObjectOffset  ; set offset here
    LDA VRAM_Buffer1  ; if vram buffer already being used here,
    BNE bra_smb2_main_advance_block_metatile_update  ; branch to move onto next block object
    LDA Block_RepFlag,x  ; if flag for block object already clear,
    BEQ bra_smb2_main_advance_block_metatile_update  ; branch to move onto next block object
    LDA Block_BBuf_Low,x  ; get low byte of block buffer
    STA $06  ; store into block buffer address
    LDA #$05
    STA $07  ; set high byte of block buffer address
    LDA Block_Orig_YPos,x  ; get original vertical coordinate of block object
    STA $02  ; store here and use as offset to block buffer
    TAY
    LDA Block_Metatile,x  ; get metatile to be written
    STA ($06),y  ; write it to the block buffer
    JSR sub_smb2_main_replace_block_metatile  ; do sub to replace metatile where block object is
    LDA #$00
    STA Block_RepFlag,x  ; clear block object flag
bra_smb2_main_advance_block_metatile_update:
    DEX  ; decrement block object offset
    BPL bra_smb2_main_update_block_metatiles_loop  ; do this until both block objects are dealt with
    RTS  ; then leave

; -------------------------------------------------------------------------------------
; $00 - used to store high nybble of horizontal speed as adder
; $01 - used to store low nybble of horizontal speed
; $02 - used to store adder to page location

sub_smb2_main_move_enemy_horizontally:
    INX  ; increment offset for enemy offset
    JSR sub_smb2_main_move_object_horizontally  ; position object horizontally according to
    LDX ObjectOffset  ; counters, return with saved value in A,
    RTS  ; put enemy offset back in X and leave

sub_smb2_main_move_player_horizontally:
    LDA JumpspringAnimCtrl  ; if jumpspring currently animating,
    BNE bra_smb2_main_return_from_movement  ; branch to leave
    TAX  ; otherwise set zero for offset to use player's stuff

sub_smb2_main_move_object_horizontally:
    LDA SprObject_X_Speed,x  ; get currently saved value (horizontal
    ASL  ; speed, secondary counter, whatever)
    ASL  ; and move low nybble to high
    ASL
    ASL
    STA $01  ; store result here
    LDA SprObject_X_Speed,x  ; get saved value again
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    CMP #$08  ; if < 8, branch, do not change
    BCC bra_smb2_main_store_signed_x_speed
    ORA #%11110000  ; otherwise alter high nybble
bra_smb2_main_store_signed_x_speed:
    STA $00  ; save result here
    LDY #$00  ; load default Y value here
    CMP #$00  ; if result positive, leave Y alone
    BPL bra_smb2_main_apply_horizontal_position_delta
    DEY  ; otherwise decrement Y
bra_smb2_main_apply_horizontal_position_delta:
    STY $02  ; save Y here
    LDA SprObject_X_MoveForce,x  ; get whatever number's here
    CLC
    ADC $01  ; add low nybble moved to high
    STA SprObject_X_MoveForce,x  ; store result here
    LDA #$00  ; init A
    ROL  ; rotate carry into d0
    PHA  ; push onto stack
    ROR  ; rotate d0 back onto carry
    LDA SprObject_X_Position,x
    ADC $00  ; add carry plus saved value (high nybble moved to low
    STA SprObject_X_Position,x  ; plus $f0 if necessary) to object's horizontal position
    LDA SprObject_PageLoc,x
    ADC $02  ; add carry plus other saved value to the
    STA SprObject_PageLoc,x  ; object's page location and save
    PLA
    CLC  ; pull old carry from stack and add
    ADC $00  ; to high nybble moved to low
bra_smb2_main_return_from_movement:
    RTS  ; and leave

; -------------------------------------------------------------------------------------
; $00 - used for downward force
; $01 - used for upward force
; $02 - used for maximum vertical speed

loc_smb2_main_move_player_vertically:
    LDX #$00  ; set X for player offset
    LDA TimerControl
    BNE bra_smb2_main_load_player_vertical_force  ; if master timer control set, branch ahead
    LDA JumpspringAnimCtrl  ; otherwise check to see if jumpspring is animating
    BNE bra_smb2_main_return_from_movement  ; branch to leave if so
bra_smb2_main_load_player_vertical_force:
    LDA VerticalForce  ; dump vertical force
    STA $00
    LDA #$04  ; set maximum vertical speed here
    JMP sub_smb2_main_apply_sprite_object_gravity  ; then jump to move player vertically

; --------------------------------

sub_smb2_main_move_enemy_downward_fast:
    LDY #$3d  ; set quick movement amount downwards
    LDA Enemy_State,x  ; then check enemy state
    CMP #$05  ; if not set to unique state for spiny's egg, go ahead
    BNE bra_smb2_main_set_fast_vertical_motion  ; and use, otherwise set different movement amount, continue on

sub_smb2_main_move_falling_platform:
    LDY #$20  ; set movement amount
bra_smb2_main_set_fast_vertical_motion:
    JMP loc_smb2_main_set_high_vertical_speed_limit  ; jump to skip the rest of this

; --------------------------------

loc_smb2_main_move_red_paratroopa_down:
    LDY #$00  ; set Y to move downwards
    JMP loc_smb2_main_move_red_paratroopa_vertically  ; skip to movement routine

loc_smb2_main_move_red_paratroopa_up:
    LDY #$01  ; set Y to move upwards

loc_smb2_main_move_red_paratroopa_vertically:
    INX  ; increment X for enemy offset
    LDA #$03
    STA $00  ; set downward movement amount here
    LDA #$06
    STA $01  ; set upward movement amount here
    LDA #$02
    STA $02  ; set maximum speed here
    TYA  ; set movement direction in A, and
    JMP loc_smb2_main_apply_red_paratroopa_gravity  ; jump to move this thing

; --------------------------------

sub_smb2_main_move_drop_platform:
    LDY #$7f  ; set movement amount for drop platform
    BNE bra_smb2_main_set_medium_vertical_speed_limit  ; skip ahead of other value set here

sub_smb2_main_move_enemy_downward_slow:
    LDY #$0f  ; set movement amount for bowser/other objects
bra_smb2_main_set_medium_vertical_speed_limit:
    LDA #$02  ; set maximum speed in A
    BNE sub_smb2_main_apply_enemy_vertical_motion  ; unconditional branch

; --------------------------------

sub_smb2_main_move_enemy_with_gravity:
    LDY #$1c  ; set movement amount for podoboo/other objects
loc_smb2_main_set_high_vertical_speed_limit:
    LDA #$03  ; set maximum speed in A
sub_smb2_main_apply_enemy_vertical_motion:
    STY $00  ; set movement amount here
    INX  ; increment X for enemy offset
    JSR sub_smb2_main_apply_sprite_object_gravity  ; do a sub to move enemy object downwards
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------

off_smb2_main_block_maximum_y_speed:
    .byte $06, $08

loc_smb2_main_gravity_block_entry:
    LDY #$00  ; this part appears to be residual,
    .byte $2c  ; no code branches or jumps to it

sub_smb2_main_apply_block_gravity:
    LDY #$01  ; set offset for maximum speed
    LDA #$50  ; set movement amount here
    STA $00
    LDA off_smb2_main_block_maximum_y_speed,y  ; get maximum speed

sub_smb2_main_apply_sprite_object_gravity:
    STA $02  ; set maximum speed here
    LDA #$00  ; set value to move downwards
    JMP sub_smb2_main_apply_object_gravity  ; jump to the code that actually moves it

; --------------------------------

sub_smb2_main_move_platform_down:
    LDA #$00  ; save value to stack (if branching here, execute next
    .byte $2c  ; part as BIT instruction)

sub_smb2_main_move_platform_up:
    LDA #$01  ; save value to stack
    PHA
    LDY Enemy_ID,x  ; get enemy object identifier
    INX  ; increment offset for enemy object
    LDA #$05  ; load default value here
    CPY #$29  ; residual comparison, object #29 never executes
    BNE bra_smb2_main_set_platform_gravity_force  ; this code, thus unconditional branch here
    LDA #$09  ; residual code
bra_smb2_main_set_platform_gravity_force:
    STA $00  ; save downward movement amount here
    LDA #$0a  ; save upward movement amount here
    STA $01
    LDA #$03  ; save maximum vertical speed here
    STA $02
    PLA  ; get value from stack
    TAY  ; use as Y, then move onto code shared by red koopa

loc_smb2_main_apply_red_paratroopa_gravity:
    JSR sub_smb2_main_apply_object_gravity  ; do a sub to move object gradually
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

; -------------------------------------------------------------------------------------
; $00 - used for downward force
; $01 - used for upward force
; $07 - used as adder for vertical position

sub_smb2_main_apply_object_gravity:
    PHA  ; push value to stack
    LDA SprObject_YMF_Dummy,x
    CLC  ; add value in movement force to contents of dummy variable
    ADC SprObject_Y_MoveForce,x
    STA SprObject_YMF_Dummy,x
    LDY #$00  ; set Y to zero by default
    LDA SprObject_Y_Speed,x  ; get current vertical speed
    BPL bra_smb2_main_update_object_y_position  ; if currently moving downwards, do not decrement Y
    DEY  ; otherwise decrement Y
bra_smb2_main_update_object_y_position:
    STY $07  ; store Y here
    ADC SprObject_Y_Position,x  ; add vertical position to vertical speed plus carry
    STA SprObject_Y_Position,x  ; store as new vertical position
    LDA SprObject_Y_HighPos,x
    ADC $07  ; add carry plus contents of $07 to vertical high byte
    STA SprObject_Y_HighPos,x  ; store as new vertical high byte
    LDA SprObject_Y_MoveForce,x
    CLC
    ADC $00  ; add downward movement amount to contents of $0433
    STA SprObject_Y_MoveForce,x
    LDA SprObject_Y_Speed,x  ; add carry to vertical speed and store
    ADC #$00
    STA SprObject_Y_Speed,x
    CMP $02  ; compare to maximum speed
    BMI bra_smb2_main_apply_upward_gravity  ; if less than preset value, skip this part
    LDA SprObject_Y_MoveForce,x
    CMP #$80  ; if less positively than preset maximum, skip this part
    BCC bra_smb2_main_apply_upward_gravity
    LDA $02
    STA SprObject_Y_Speed,x  ; keep vertical speed within maximum value
    LDA #$00
    STA SprObject_Y_MoveForce,x  ; clear fractional
bra_smb2_main_apply_upward_gravity:
    PLA  ; get value from stack
    BEQ bra_smb2_main_return_from_vertical_movement  ; if set to zero, branch to leave
    LDA $02
    EOR #%11111111  ; otherwise get two's compliment of maximum speed
    TAY
    INY
    STY $07  ; store two's compliment here
    LDA SprObject_Y_MoveForce,x
    SEC  ; subtract upward movement amount from contents
    SBC $01  ; of movement force, note that $01 is twice as large as $00,
    STA SprObject_Y_MoveForce,x  ; thus it effectively undoes add we did earlier
    LDA SprObject_Y_Speed,x
    SBC #$00  ; subtract borrow from vertical speed and store
    STA SprObject_Y_Speed,x
    CMP $07  ; compare vertical speed to two's compliment
    BPL bra_smb2_main_return_from_vertical_movement  ; if less negatively than preset maximum, skip this part
    LDA SprObject_Y_MoveForce,x
    CMP #$80  ; check if fractional part is above certain amount,
    BCS bra_smb2_main_return_from_vertical_movement  ; and if so, branch to leave
    LDA $07
    STA SprObject_Y_Speed,x  ; keep vertical speed within maximum value
    LDA #$ff
    STA SprObject_Y_MoveForce,x  ; clear fractional
bra_smb2_main_return_from_vertical_movement:
    RTS  ; leave!

; -------------------------------------------------------------------------------------

; some unused bytes
    .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff

; -------------------------------------------------------------------------------------

sub_smb2_main_enemies_and_loops_core:
    LDA Enemy_Flag,x  ; check data here for MSB set
    PHA  ; save in stack
    ASL
    BCS bra_smb2_main_resolve_bowser_rear_slot  ; if MSB set in enemy flag, branch ahead of jumps
    PLA  ; get from stack
    BEQ bra_smb2_main_check_area_parser_task  ; if data zero, branch
    JMP loc_smb2_main_run_enemy_objects_core  ; otherwise, jump to run enemy subroutines
bra_smb2_main_check_area_parser_task:
    LDA AreaParserTaskNum  ; check number of tasks to perform
    AND #$07
    CMP #$07  ; if at a specific task, jump and leave
    BEQ bra_smb2_main_exit_enemy_and_loop_core
    JMP loc_smb2_main_process_game_loop_command  ; otherwise, jump to process loop command/load enemies
bra_smb2_main_resolve_bowser_rear_slot:
    PLA  ; get data from stack
    AND #%00001111  ; mask out high nybble
    TAY
    LDA Enemy_Flag,y  ; use as pointer and load same place with different offset
    BNE bra_smb2_main_exit_enemy_and_loop_core
    STA Enemy_Flag,x  ; if second enemy flag not set, also clear first one
bra_smb2_main_exit_enemy_and_loop_core:
    RTS

; -------------------------------------------------------------------------------------

; loop command data
; note that some data is never used (it may have been
; used at one point, but the area data that ref'd it
; is now missing the loop command object)

tbl_smb2_main_loop_command_world_numbers:
    .byte $02, $02, $02, $02, $05, $05, $05, $05, $06, $07, $07, $04

tbl_smb2_main_loop_command_page_numbers:
    .byte $03, $05, $08, $09, $03, $06, $07, $0a, $05, $05, $0b, $05

tbl_smb2_main_loop_command_player_y_positions:
    .byte $b0, $b0, $40, $30, $b0, $30, $b0, $b0, $f0, $f0, $b0, $f0

tbl_smb2_main_multi_loop_count:
    .byte $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01

sub_smb2_main_exec_game_loopback:
    LDA Player_PageLoc  ; send player back four pages
    SEC
    SBC #$04
    STA Player_PageLoc
    LDA CurrentPageLoc  ; send current page back four pages
    SEC
    SBC #$04
    STA CurrentPageLoc
    LDA ScreenLeft_PageLoc  ; subtract four from page location
    SEC  ; of screen's left border
    SBC #$04
    STA ScreenLeft_PageLoc
    LDA ScreenRight_PageLoc  ; do the same for the page location
    SEC  ; of screen's right border
    SBC #$04
    STA ScreenRight_PageLoc
    LDA AreaObjectPageLoc  ; subtract four from page control
    SEC  ; for area objects
    SBC #$04
    STA AreaObjectPageLoc
    LDA #$00  ; initialize page select for both
    STA EnemyObjectPageSel  ; area and enemy objects
    STA AreaObjectPageSel
    STA EnemyDataOffset  ; initialize enemy object data offset
    STA EnemyObjectPageLoc  ; and enemy object page control
    LDA off_smb2_main_area_object_loopback_offsets,y  ; adjust area object offset based on
    STA AreaDataOffset  ; which loop command we encountered
    RTS

loc_smb2_main_process_game_loop_command:
    LDA LoopCommand  ; check if loop command was found
    BEQ bra_smb2_main_spawn_queued_frenzy_enemy
    LDA CurrentColumnPos  ; check to see if we're still on the first page
    BNE bra_smb2_main_spawn_queued_frenzy_enemy  ; if not, do not loop yet
    LDY #$0c  ; start at the end of each set of loop data
bra_smb2_main_find_matching_loop_command:
    DEY
    BMI bra_smb2_main_spawn_queued_frenzy_enemy  ; if all data is checked and not match, do not loop
    LDA WorldNumber  ; check to see if one of the world numbers
    CMP tbl_smb2_main_loop_command_world_numbers,y  ; matches our current world number
    BNE bra_smb2_main_find_matching_loop_command
    LDA CurrentPageLoc  ; check to see if one of the page numbers
    CMP tbl_smb2_main_loop_command_page_numbers,y  ; matches the page we're currently on
    BNE bra_smb2_main_find_matching_loop_command
    LDA Player_Y_Position  ; check to see if the player is at the correct position
    CMP tbl_smb2_main_loop_command_player_y_positions,y  ; if not, branch to check for world 7
    BNE bra_smb2_main_handle_incorrect_loop_path
    LDA Player_State  ; check to see if the player is
    CMP #$00  ; on solid ground (i.e. not jumping or falling)
    BNE bra_smb2_main_handle_incorrect_loop_path  ; if not, player fails to pass loop, and loopback
    INC MultiLoopCorrectCntr  ; increment counter for correct progression
bra_smb2_main_handle_incorrect_loop_path:
    INC MultiLoopPassCntr  ; increment master multi-part counter
    LDA MultiLoopPassCntr  ; have we done all parts?
    CMP tbl_smb2_main_multi_loop_count,y
    BNE bra_smb2_main_clear_loop_command  ; if not, skip this part
    LDA MultiLoopCorrectCntr  ; if so, have we done them all correctly?
    CMP tbl_smb2_main_multi_loop_count,y
    BEQ bra_smb2_main_reset_multi_loop_state  ; if so, branch past unnecessary check here
    JSR sub_smb2_main_exec_game_loopback  ; if player is not in right place, loop back
    JSR sub_smb2_main_kill_all_enemies
bra_smb2_main_reset_multi_loop_state:
    LDA #$00  ; initialize counters used for multi-part loop commands
    STA MultiLoopPassCntr
    STA MultiLoopCorrectCntr
bra_smb2_main_clear_loop_command:
    LDA #$00  ; initialize loop command flag
    STA LoopCommand

; --------------------------------
