off_smb2_main_bullet_bill_x_speeds:
    .byte $18, $e8

sub_smb2_main_bullet_bill_handler:
    LDA TimerControl  ; if master timer control set,
    BNE bra_smb2_main_run_bullet_bill_subsystems  ; branch to run subroutines except movement sub
    LDA Enemy_State,x
    BNE bra_smb2_main_check_bullet_bill_defeated_state  ; if bullet bill's state set, branch to check defeated state
    LDA Enemy_OffscreenBits  ; otherwise load offscreen bits
    AND #%00001100  ; mask out bits
    CMP #%00001100  ; check to see if all bits are set
    BEQ bra_smb2_main_erase_bullet_bill  ; if so, branch to kill this object
    LDY #$01  ; set to move right by default
    JSR sub_smb2_main_player_enemy_diff  ; get horizontal difference between player and bullet bill
    BMI bra_smb2_main_initialize_bullet_bill  ; if enemy to the left of player, branch
    INY  ; otherwise increment to move left
bra_smb2_main_initialize_bullet_bill:
    STY Enemy_MovingDir,x  ; set bullet bill's moving direction
    DEY  ; decrement to use as offset
    LDA off_smb2_main_bullet_bill_x_speeds,y  ; get horizontal speed based on moving direction
    STA Enemy_X_Speed,x  ; and store it
    LDA $00  ; get horizontal difference
    ADC #$28  ; add 40 pixels
    CMP #$50  ; if less than a certain amount, player is too close
    BCC bra_smb2_main_erase_bullet_bill  ; to cannon either on left or right side, thus branch
    LDA #$01
    STA Enemy_State,x  ; otherwise set bullet bill's state
    LDA #$0a
    STA EnemyFrameTimer,x  ; set enemy frame timer
    LDA #Sfx_Blast
    STA Square2SoundQueue  ; play fireworks/gunfire sound
bra_smb2_main_check_bullet_bill_defeated_state:
    LDA Enemy_State,x  ; check enemy state for d5 set
    AND #%00100000
    BEQ bra_smb2_main_update_bullet_bill_flight  ; if not set, skip to move horizontally
    JSR sub_smb2_main_move_enemy_downward_fast  ; otherwise do sub to move bullet bill vertically
bra_smb2_main_update_bullet_bill_flight:
    JSR sub_smb2_main_move_enemy_horizontally  ; do sub to move bullet bill horizontally
bra_smb2_main_run_bullet_bill_subsystems:
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; get offscreen information
    JSR sub_smb2_main_relative_enemy_position  ; get relative coordinates
    JSR sub_smb2_main_get_enemy_bound_box  ; get bounding box coordinates
    JSR sub_smb2_main_player_enemy_collision  ; handle player to enemy collisions
    JMP sub_smb2_main_render_enemy_graphics  ; draw the bullet bill and leave
bra_smb2_main_erase_bullet_bill:
    JSR sub_smb2_main_erase_enemy_object  ; kill bullet bill and leave
    RTS

; -------------------------------------------------------------------------------------

off_smb2_main_hammer_misc_to_enemy_slot_offsets:
    .byte $04, $04, $04, $05, $05, $05
    .byte $06, $06, $06

off_smb2_main_hammer_x_speeds:
    .byte $10, $f0

sub_smb2_main_spawn_hammer_object:
    LDA PseudoRandomBitReg+1  ; get a pseudorandom number from 0 to 8
    AND #%00000111  ; from the second part of LSFR
    BNE bra_smb2_main_select_hammer_misc_slot
    LDA PseudoRandomBitReg+1
    AND #%00001000
bra_smb2_main_select_hammer_misc_slot:
    TAY  ; use as misc object offset
    LDA Misc_State,y  ; check for enemy state, if found, branch to leave
    BNE bra_smb2_main_reject_hammer_spawn
    LDX off_smb2_main_hammer_misc_to_enemy_slot_offsets,y  ; get enemy slot offset number using misc obj offset
    LDA Enemy_Flag,x  ; then check enemy buffer flag at that offset
    BNE bra_smb2_main_reject_hammer_spawn  ; if buffer flag set, branch to leave with carry clear
    LDX ObjectOffset  ; get original enemy object offset
    TXA
    STA HammerEnemyOffset,y  ; save here
    LDA #$90
    STA Misc_State,y  ; save hammer's state here
    LDA #$07
    STA Misc_BoundBoxCtrl,y  ; set something else entirely, here
    SEC  ; return with carry set
    RTS
bra_smb2_main_reject_hammer_spawn:
    LDX ObjectOffset  ; get original enemy object offset
    CLC  ; return with carry clear
    RTS

; --------------------------------
; $00 - used to set downward force
; $01 - used to set upward force (residual)
; $02 - used to set maximum speed

sub_smb2_main_process_hammer_object:
    LDA TimerControl  ; if master timer control set
    BNE bra_smb2_main_run_hammer_subsystems  ; skip all of this code and go to last subs at the end
    LDA Misc_State,x  ; otherwise get hammer's state
    AND #%01111111  ; mask out d7
    LDY HammerEnemyOffset,x  ; get enemy object offset that spawned this hammer
    CMP #$02  ; check hammer's state
    BEQ bra_smb2_main_store_hammer_x_speed  ; if currently at 2, branch
    BCS bra_smb2_main_store_hammer_position  ; if greater than 2, branch elsewhere
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
    JSR sub_smb2_main_apply_object_gravity  ; do sub to impose gravity on hammer and move vertically
    JSR sub_smb2_main_move_object_horizontally  ; do sub to move it horizontally
    LDX ObjectOffset  ; get original misc object offset
    JMP loc_smb2_main_process_all_hammers  ; branch to essential subroutines
bra_smb2_main_store_hammer_x_speed:
    LDA #$fe
    STA Misc_Y_Speed,x  ; set hammer's vertical speed
    LDA Enemy_State,y  ; get enemy object state
    AND #%11110111  ; mask out d3
    STA Enemy_State,y  ; store new state
    LDX Enemy_MovingDir,y  ; get enemy's moving direction
    DEX  ; decrement to use as offset
    LDA off_smb2_main_hammer_x_speeds,x  ; get proper speed to use based on moving direction
    LDX ObjectOffset  ; reobtain hammer's buffer offset
    STA Misc_X_Speed,x  ; set hammer's horizontal speed
bra_smb2_main_store_hammer_position:
    DEC Misc_State,x  ; decrement hammer's state
    LDA Enemy_X_Position,y  ; get enemy's horizontal position
    CLC
    ADC #$02  ; set position 2 pixels to the right
    STA Misc_X_Position,x  ; store as hammer's horizontal position
    LDA Enemy_PageLoc,y  ; get enemy's page location
    ADC #$00  ; add carry
    STA Misc_PageLoc,x  ; store as hammer's page location
    LDA Enemy_Y_Position,y  ; get enemy's vertical position
    SEC
    SBC #$0a  ; move position 10 pixels upward
    STA Misc_Y_Position,x  ; store as hammer's vertical position
    LDA #$01
    STA Misc_Y_HighPos,x  ; set hammer's vertical high byte
    BNE bra_smb2_main_run_hammer_subsystems  ; unconditional branch to skip first routine
loc_smb2_main_process_all_hammers:
    JSR sub_smb2_main_player_hammer_collision  ; handle collisions
bra_smb2_main_run_hammer_subsystems:
    JSR sub_smb2_main_get_misc_offscreen_bits  ; get offscreen information
    JSR sub_smb2_main_relative_misc_position  ; get relative coordinates
    JSR sub_smb2_main_get_misc_bound_box  ; get bounding box coordinates
    JSR sub_smb2_main_draw_hammer  ; draw the hammer
    RTS  ; and we are done here

; -------------------------------------------------------------------------------------
; $02 - used to store vertical high nybble offset from block buffer routine
; $06 - used to store low byte of block buffer address

handler_smb2_main_run_coin_block:
    JSR sub_smb2_main_find_empty_misc_slot  ; set offset for empty or last misc object buffer slot
    LDA Block_PageLoc,x  ; get page location of block object
    STA Misc_PageLoc,y  ; store as page location of misc object
    LDA Block_X_Position,x  ; get horizontal coordinate of block object
    ORA #$05  ; add 5 pixels
    STA Misc_X_Position,y  ; store as horizontal coordinate of misc object
    LDA Block_Y_Position,x  ; get vertical coordinate of block object
    SBC #$10  ; subtract 16 pixels
    STA Misc_Y_Position,y  ; store as vertical coordinate of misc object
    JMP loc_smb2_main_initialize_jump_coin  ; jump to rest of code as applies to this misc object

sub_smb2_main_setup_jump_coin:
    JSR sub_smb2_main_find_empty_misc_slot  ; set offset for empty or last misc object buffer slot
    LDA Block_PageLoc2,x  ; get page location saved earlier
    STA Misc_PageLoc,y  ; and save as page location for misc object
    LDA $06  ; get low byte of block buffer offset
    ASL
    ASL  ; multiply by 16 to use lower nybble
    ASL
    ASL
    ORA #$05  ; add five pixels
    STA Misc_X_Position,y  ; save as horizontal coordinate for misc object
    LDA $02  ; get vertical high nybble offset from earlier
    ADC #$20  ; add 32 pixels for the status bar
    STA Misc_Y_Position,y  ; store as vertical coordinate
loc_smb2_main_initialize_jump_coin:
    LDA #$fb
    STA Misc_Y_Speed,y  ; set vertical speed
    LDA #$01
    STA Misc_Y_HighPos,y  ; set vertical high byte
    STA Misc_State,y  ; set state for misc object
    STA Square2SoundQueue  ; load coin grab sound
    STX ObjectOffset  ; store current control bit as misc object offset
    JSR sub_smb2_main_give_one_coin  ; update coin tally on the screen and coin amount variable
    INC CoinTallyFor1Ups  ; increment coin tally used to activate 1-up block flag
    RTS

sub_smb2_main_find_empty_misc_slot:
    LDY #$08  ; start at end of misc objects buffer
bra_smb2_main_find_empty_misc_slot_loop:
    LDA Misc_State,y  ; get misc object state
    BEQ bra_smb2_main_store_selected_misc_slot  ; branch if none found to use current offset
    DEY  ; decrement offset
    CPY #$05  ; do this for three slots
    BNE bra_smb2_main_find_empty_misc_slot_loop  ; do this until all slots are checked
    LDY #$08  ; if no empty slots found, use last slot
bra_smb2_main_store_selected_misc_slot:
    STY JumpCoinMiscOffset  ; store offset of misc object buffer here (residual)
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_misc_objects_core:
    LDX #$08  ; set at end of misc object buffer
bra_smb2_main_process_misc_object_slots:
    STX ObjectOffset  ; store misc object offset here
    LDA Misc_State,x  ; check misc object state
    BEQ bra_smb2_main_advance_misc_object_slot  ; branch to check next slot
    ASL  ; otherwise shift d7 into carry
    BCC bra_smb2_main_process_jump_coin_or_score  ; if d7 not set, jumping coin, thus skip to rest of code here
    JSR sub_smb2_main_process_hammer_object  ; otherwise go to process hammer,
    JMP bra_smb2_main_advance_misc_object_slot  ; then check next slot

; --------------------------------
; $00 - used to set downward force
; $01 - used to set upward force (residual)
; $02 - used to set maximum speed

bra_smb2_main_process_jump_coin_or_score:
    LDY Misc_State,x  ; check misc object state
    DEY  ; decrement to see if it's set to 1
    BEQ bra_smb2_main_update_jumping_coin  ; if so, branch to handle jumping coin
    INC Misc_State,x  ; otherwise increment state to either start off or as timer
    LDA Misc_X_Position,x  ; get horizontal coordinate for misc object
    CLC  ; whether its jumping coin (state 0 only) or floatey number
    ADC ScrollAmount  ; add current scroll speed
    STA Misc_X_Position,x  ; store as new horizontal coordinate
    LDA Misc_PageLoc,x  ; get page location
    ADC #$00  ; add carry
    STA Misc_PageLoc,x  ; store as new page location
    LDA Misc_State,x
    CMP #$30  ; check state of object for preset value
    BNE bra_smb2_main_run_jump_coin_subsystems  ; if not yet reached, branch to subroutines
    LDA #$00
    STA Misc_State,x  ; otherwise nullify object state
    JMP bra_smb2_main_advance_misc_object_slot  ; and move onto next slot
bra_smb2_main_update_jumping_coin:
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
    JSR sub_smb2_main_apply_object_gravity  ; do sub to move coin vertically and impose gravity on it
    LDX ObjectOffset  ; get original misc object offset
    LDA Misc_Y_Speed,x  ; check vertical speed
    CMP #$05
    BNE bra_smb2_main_run_jump_coin_subsystems  ; if not moving downward fast enough, keep state as-is
    INC Misc_State,x  ; otherwise increment state to change to floatey number
bra_smb2_main_run_jump_coin_subsystems:
    JSR sub_smb2_main_relative_misc_position  ; get relative coordinates
    JSR sub_smb2_main_get_misc_offscreen_bits  ; get offscreen information
    JSR sub_smb2_main_get_misc_bound_box  ; get bounding box coordinates (why?)
    JSR sub_smb2_main_render_jumping_coin_graphics  ; draw the coin or floatey number

bra_smb2_main_advance_misc_object_slot:
    DEX  ; decrement misc object offset
    BPL bra_smb2_main_process_misc_object_slots  ; loop back until all misc objects handled
    RTS  ; then leave

; -------------------------------------------------------------------------------------

sub_smb2_main_give_one_coin:
    LDA #$01  ; set digit modifier to add 1 coin
    STA DigitModifier+5  ; to the current player's coin tally
    LDY #$11  ; set offset for coin tally
    JSR sub_smb2_main_digits_math_routine  ; update the coin tally
    INC CoinTally  ; increment onscreen player's coin amount
    LDA CoinTally
    CMP #100  ; does player have 100 coins yet?
    BNE bra_smb2_main_award_coin_points  ; if not, skip all of this
    LDA #$00
    STA CoinTally  ; otherwise, reinitialize coin amount
    INC NumberofLives  ; give the player an extra life
    LDA #Sfx_ExtraLife
    STA Square2SoundQueue  ; play 1-up sound

bra_smb2_main_award_coin_points:
    LDA #$02  ; set digit modifier to award
    STA DigitModifier+4  ; 200 points to the player

sub_smb2_main_add_to_score:
    LDY #$0b  ; get offset for player's score
    JSR sub_smb2_main_digits_math_routine  ; update the score internally with value in digit modifier

sub_smb2_main_write_score_and_coin_tally:
    LDA #$01
sub_smb2_main_write_digits:
    JSR sub_smb2_main_print_status_bar_numbers  ; print status bar numbers
    LDY VRAM_Buffer1_Offset
    LDA VRAM_Buffer1-6,y  ; check highest digit of score
    BNE bra_smb2_main_finish_score_zero_suppression  ; if zero, overwrite with space tile for zero suppression
    LDA #$24
    STA VRAM_Buffer1-6,y
bra_smb2_main_finish_score_zero_suppression:
    LDX ObjectOffset  ; get enemy object buffer offset
    RTS

; -------------------------------------------------------------------------------------

loc_smb2_main_setup_power_up_object:
    LDA #PowerUpObject  ; load power-up identifier into
    STA Enemy_ID+5  ; special use slot of enemy object buffer
    LDA Block_PageLoc,x  ; store page location of block object
    STA Enemy_PageLoc+5  ; as page location of power-up object
    LDA Block_X_Position,x  ; store horizontal coordinate of block object
    STA Enemy_X_Position+5  ; as horizontal coordinate of power-up object
    LDA #$01
    STA Enemy_Y_HighPos+5  ; set vertical high byte of power-up object
    LDA Block_Y_Position,x  ; get vertical coordinate of block object
    SEC
    SBC #$08  ; subtract 8 pixels
    STA Enemy_Y_Position+5  ; and use as vertical coordinate of power-up object
handler_smb2_main_initialize_power_up_object:
    LDA #$01  ; this is a residual jump point in enemy object jump table
    STA Enemy_State+5  ; set power-up object's state
    STA Enemy_Flag+5  ; set buffer flag
    LDA #$03
    STA Enemy_BoundBoxCtrl+5  ; set bounding box size control for power-up object
    LDA PowerUpType
    CMP #$02  ; check currently loaded power-up type
    BCS bra_smb2_main_put_power_up_behind_background  ; if star or 1-up, branch ahead
    LDA PlayerStatus  ; otherwise check player's current status
    CMP #$02
    BCC bra_smb2_main_store_power_up_type  ; if player not fiery, use status as power-up type
    LSR  ; otherwise shift right to force fire flower type
bra_smb2_main_store_power_up_type:
    STA PowerUpType  ; store type here
bra_smb2_main_put_power_up_behind_background:
    LDA #%00100000
    STA Enemy_SprAttrib+5  ; set background priority bit
    LDA #Sfx_GrowPowerUp
    STA Square2SoundQueue  ; load power-up reveal sound and leave
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_process_power_up_object:
    LDX #$05  ; set object offset for last slot in enemy object buffer
    STX ObjectOffset
    LDA Enemy_State+5  ; check power-up object's state
    BEQ bra_smb2_main_exit_power_up_handler  ; if not set, branch to leave
    ASL  ; shift to check if d7 was set in object state
    BCC bra_smb2_main_raise_power_up_from_block  ; if not set, branch ahead to skip this part
    LDA TimerControl  ; if master timer control set,
    BNE bra_smb2_main_run_power_up_subsystems  ; branch ahead to enemy object routines
    LDA PowerUpType  ; check power-up type
    BEQ bra_smb2_main_move_mushroom_power_up  ; if normal mushroom, branch ahead to move it
    CMP #$03
    BEQ bra_smb2_main_move_mushroom_power_up  ; if 1-up mushroom, branch ahead to move it
    CMP #$04
    BEQ bra_smb2_main_move_mushroom_power_up
    CMP #$05
    BEQ bra_smb2_main_move_mushroom_power_up
    CMP #$02
    BNE bra_smb2_main_run_power_up_subsystems  ; if not star, branch elsewhere to skip movement
    JSR sub_smb2_main_move_jumping_enemy  ; otherwise impose gravity on star power-up and make it jump
    JSR sub_smb2_main_enemy_jump  ; note that green paratroopa shares the same code here
    JMP bra_smb2_main_run_power_up_subsystems  ; then jump to other power-up subroutines
bra_smb2_main_move_mushroom_power_up:
    JSR sub_smb2_main_move_normal_enemy  ; do sub to make mushrooms move
    JSR sub_smb2_main_detect_enemy_background_collision  ; deal with collisions
    JMP bra_smb2_main_run_power_up_subsystems  ; run the other subroutines

bra_smb2_main_raise_power_up_from_block:
    LDA FrameCounter  ; get frame counter
    AND #$03  ; mask out all but 2 LSB
    BNE bra_smb2_main_check_power_up_state  ; if any bits set here, branch
    DEC Enemy_Y_Position+5  ; otherwise decrement vertical coordinate slowly
    LDA Enemy_State+5  ; load power-up object state
    INC Enemy_State+5  ; increment state for next frame (to make power-up rise)
    CMP #$11  ; if power-up object state not yet past 16th pixel,
    BCC bra_smb2_main_check_power_up_state  ; branch ahead to last part here
    LDA #$10
    STA Enemy_X_Speed,x  ; otherwise set horizontal speed
    LDA #%10000000
    STA Enemy_State+5  ; and then set d7 in power-up object's state
    ASL  ; shift once to init A
    STA Enemy_SprAttrib+5  ; initialize background priority bit set here
    ROL  ; rotate A to set right moving direction
    STA Enemy_MovingDir,x  ; set moving direction
bra_smb2_main_check_power_up_state:
    LDA Enemy_State+5  ; check power-up object's state
    CMP #$06  ; for if power-up has risen enough
    BCC bra_smb2_main_exit_power_up_handler  ; if not, don't even bother running these routines
bra_smb2_main_run_power_up_subsystems:
    JSR sub_smb2_main_relative_enemy_position  ; get coordinates relative to screen
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; get offscreen bits
    JSR sub_smb2_main_get_enemy_bound_box  ; get bounding box coordinates
    JSR sub_smb2_main_draw_power_up  ; draw the power-up object
    JSR sub_smb2_main_player_enemy_collision  ; check for collision with player
    JSR sub_smb2_main_offscreen_bounds_check  ; check to see if it went offscreen
bra_smb2_main_exit_power_up_handler:
    RTS  ; and we're done

; -------------------------------------------------------------------------------------
; These apply to all routines in this section unless otherwise noted:
; $00 - used to store metatile from block buffer routine
; $02 - used to store vertical high nybble offset from block buffer routine
; $05 - used to store metatile stored in A at beginning of PlayerHeadCollision
; $06-$07 - used as block buffer address indirect

off_smb2_main_block_y_position_adders:
    .byte $04, $12

sub_smb2_main_player_head_collision:
    PHA  ; store metatile number to stack
    LDA #$11  ; load unbreakable block object state by default
    LDX SprDataOffset_Ctrl  ; load offset control bit here
    LDY PlayerSize  ; check player's size
    BNE bra_smb2_main_store_bumped_block_state  ; if small, branch
    LDA #$12  ; otherwise load breakable block object state
bra_smb2_main_store_bumped_block_state:
    STA Block_State,x  ; store into block object buffer
    JSR sub_smb2_main_destroy_block_metatile  ; store blank metatile in vram buffer to write to name table
    LDX SprDataOffset_Ctrl  ; load offset control bit
    LDA $02  ; get vertical high nybble offset used in block buffer routine
    STA Block_Orig_YPos,x  ; set as vertical coordinate for block object
    TAY
    LDA $06  ; get low byte of block buffer address used in same routine
    STA Block_BBuf_Low,x  ; save as offset here to be used later
    LDA ($06),y  ; get contents of block buffer at old address at $06, $07
    JSR sub_smb2_main_check_bumped_block  ; do a sub to check which block player bumped head on
    STA $00  ; store metatile here
    LDY PlayerSize  ; check player's size
    BNE bra_smb2_main_check_bumped_brick  ; if small, use metatile itself as contents of A
    TYA  ; otherwise init A (note: big = 0)
bra_smb2_main_check_bumped_brick:
    BCC bra_smb2_main_store_block_replacement_metatile  ; if no match was found in previous sub, skip ahead
    LDY #$11  ; otherwise load unbreakable state into block object buffer
    STY Block_State,x  ; note this applies to both player sizes
    LDA #$c5  ; load empty block metatile into A for now
    LDY $00  ; get metatile from before
    CPY #$56  ; is it brick with coins (with line)?
    BEQ bra_smb2_main_start_brick_coin_timer  ; if so, branch
    CPY #$5c  ; is it brick with coins (without line)?
    BNE bra_smb2_main_store_block_replacement_metatile  ; if not, branch ahead to store empty block metatile
bra_smb2_main_start_brick_coin_timer:
    LDA BrickCoinTimerFlag  ; check brick coin timer flag
    BNE bra_smb2_main_continue_brick_coin_timer  ; if set, timer expired or counting down, thus branch
    LDA #$0b
    STA BrickCoinTimer  ; if not set, set brick coin timer
    INC BrickCoinTimerFlag  ; and set flag linked to it
bra_smb2_main_continue_brick_coin_timer:
    LDA BrickCoinTimer  ; check brick coin timer
    BNE bra_smb2_main_use_existing_brick_metatile  ; if not yet expired, branch to use current metatile
    LDY #$c5  ; otherwise use empty block metatile
bra_smb2_main_use_existing_brick_metatile:
    TYA  ; put metatile into A
bra_smb2_main_store_block_replacement_metatile:
    STA Block_Metatile,x  ; store whatever metatile be appropriate here
    JSR sub_smb2_main_initialize_block_position  ; get block object horizontal coordinates saved
    LDY $02  ; get vertical high nybble offset
    LDA #$20
    STA ($06),y  ; write blank metatile $20 to block buffer
    LDA #$10
    STA BlockBounceTimer  ; set block bounce timer
    PLA  ; pull original metatile from stack
    STA $05  ; and save here
    LDY #$00  ; set default offset
    LDA CrouchingFlag  ; is player crouching?
    BNE bra_smb2_main_use_small_player_block_y_offset  ; if so, branch to increment offset
    LDA PlayerSize  ; is player big?
    BEQ bra_smb2_main_set_bumped_block_y_position  ; if so, branch to use default offset
bra_smb2_main_use_small_player_block_y_offset:
    INY  ; increment for small or big and crouching
bra_smb2_main_set_bumped_block_y_position:
    LDA Player_Y_Position  ; get player's vertical coordinate
    CLC
    ADC off_smb2_main_block_y_position_adders,y  ; add value determined by size
    AND #$f0  ; mask out low nybble to get 16-pixel correspondence
    STA Block_Y_Position,x  ; save as vertical coordinate for block object
    LDY Block_State,x  ; get block object state
    CPY #$11
    BEQ bra_smb2_main_bump_unbreakable_block  ; if set to value loaded for unbreakable, branch
    JSR sub_smb2_main_brick_shatter  ; execute code for breakable brick
    JMP loc_smb2_main_toggle_block_object_slot  ; skip subroutine to do last part of code here
bra_smb2_main_bump_unbreakable_block:
    JSR sub_smb2_main_bump_block  ; execute code for unbreakable brick or question block
loc_smb2_main_toggle_block_object_slot:
    LDA SprDataOffset_Ctrl  ; invert control bit used by block objects
    EOR #$01  ; and floatey numbers
    STA SprDataOffset_Ctrl
    RTS  ; leave!

; --------------------------------

sub_smb2_main_initialize_block_position:
    LDA Player_X_Position  ; get player's horizontal coordinate
    CLC
    ADC #$08  ; add eight pixels
    AND #$f0  ; mask out low nybble to give 16-pixel correspondence
    STA Block_X_Position,x  ; save as horizontal coordinate for block object
    LDA Player_PageLoc
    ADC #$00  ; add carry to page location of player
    STA Block_PageLoc,x  ; save as page location of block object
    STA Block_PageLoc2,x  ; save elsewhere to be used later
    LDA Player_Y_HighPos
    STA Block_Y_HighPos,x  ; save vertical high byte of player into
    RTS  ; vertical high byte of block object and leave

; --------------------------------

sub_smb2_main_bump_block:
    JSR sub_smb2_main_check_top_of_block  ; check to see if there's a coin directly above this block
    LDA #Sfx_Bump
    STA Square1SoundQueue  ; play bump sound
    LDA #$00
    STA Block_X_Speed,x  ; initialize horizontal speed for block object
    STA Block_Y_MoveForce,x  ; init fractional movement force
    STA Player_Y_Speed  ; init player's vertical speed
    LDA #$fe
    STA Block_Y_Speed,x  ; set vertical speed for block object
    LDA $05  ; get original metatile from stack
    JSR sub_smb2_main_check_bumped_block  ; do a sub to check which block player bumped head on
    BCC bra_smb2_main_exit_block_content_check  ; if no match was found, branch to leave
    TYA  ; move block number to A
    CMP #$0d  ; if block number was within 0-$c range,
    BCC bra_smb2_main_dispatch_block_contents  ; branch to use current number
    SBC #$06  ; otherwise subtract 6 for second set to get proper number
bra_smb2_main_dispatch_block_contents:
    JSR sub_smb2_main_dispatch_inline_handler  ; run appropriate subroutine depending on block number

    .word handler_smb2_main_mushroom_or_flower_block
    .word handler_smb2_main_poison_mush_block
    .word handler_smb2_main_run_coin_block
    .word handler_smb2_main_run_coin_block
    .word handler_smb2_main_extra_life_mushroom_block
    .word handler_smb2_main_poison_mush_block
    .word handler_smb2_main_mushroom_or_flower_block
    .word handler_smb2_main_mushroom_or_flower_block
    .word handler_smb2_main_poison_mush_block
    .word handler_smb2_main_release_vine_from_block
    .word handler_smb2_main_release_star_from_block
    .word handler_smb2_main_run_coin_block
    .word handler_smb2_main_extra_life_mushroom_block

handler_smb2_main_mushroom_or_flower_block:
    LDA #$00  ; load mushroom/flower type
    .byte $2c

handler_smb2_main_release_star_from_block:
    LDA #$02  ; load star type
    .byte $2c

handler_smb2_main_poison_mush_block:
    LDA #$04  ; load poison mushroom type
    .byte $2c

handler_smb2_main_extra_life_mushroom_block:
    LDA #$03  ; load 1-up mushroom type
    STA $39  ; store correct power-up type
    JMP loc_smb2_main_setup_power_up_object

handler_smb2_main_release_vine_from_block:
    LDX #$05  ; load last slot for enemy object buffer
    LDY SprDataOffset_Ctrl  ; get control bit
    JSR sub_smb2_main_setup_vine  ; set up vine object

bra_smb2_main_exit_block_content_check:
    RTS  ; leave

; --------------------------------
