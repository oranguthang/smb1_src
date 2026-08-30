sub_smb2_main_run_game_timer:
    LDA OperMode  ; get primary mode of operation
    BEQ bra_smb2_main_exit_game_timer  ; branch to leave if in attract mode
    LDA GameEngineSubroutine
    CMP #$08  ; if routine number less than eight running,
    BCC bra_smb2_main_exit_game_timer  ; branch to leave
    CMP #$0b  ; if running death routine,
    BEQ bra_smb2_main_exit_game_timer  ; branch to leave
    LDA Player_Y_HighPos
    CMP #$02  ; if player below the screen,
    BPL bra_smb2_main_exit_game_timer  ; branch to leave regardless of level type
    LDA GameTimerCtrlTimer  ; if game timer control not yet expired,
    BNE bra_smb2_main_exit_game_timer  ; branch to leave
    LDA GameTimerDisplay
    ORA GameTimerDisplay+1  ; otherwise check game timer digits
    ORA GameTimerDisplay+2
    BEQ bra_smb2_main_trigger_time_up  ; if game timer digits at 000, branch to time-up code
    LDY GameTimerDisplay  ; otherwise check first digit
    DEY  ; if first digit not on 1,
    BNE bra_smb2_main_decrement_game_timer  ; branch to reset game timer control
    LDA GameTimerDisplay+1  ; otherwise check second and third digits
    ORA GameTimerDisplay+2
    BNE bra_smb2_main_decrement_game_timer  ; if timer not at 100, branch to reset game timer control
    LDA #TimeRunningOutMusic
    STA EventMusicQueue  ; otherwise load time running out music
bra_smb2_main_decrement_game_timer:
    LDA #$18  ; reset game timer control
    STA GameTimerCtrlTimer
    LDY #$17  ; set offset for last digit
    LDA #$ff  ; set value to decrement game timer digit
    STA DigitModifier+5
    JSR sub_smb2_main_digits_math_routine  ; do sub to decrement game timer slowly
    LDA #$a2  ; set status nybbles to update game timer display
    JMP sub_smb2_main_print_status_bar_numbers  ; do sub to update the display
bra_smb2_main_trigger_time_up:
    STA PlayerStatus  ; init player status (note A will always be zero here)
    JSR sub_smb2_main_force_injury  ; do sub to kill the player (note player is small here)
    INC GameTimerExpiredFlag  ; set game timer expiration flag
bra_smb2_main_exit_game_timer:
    RTS  ; leave

; -------------------------------------------------------------------------------------

handler_smb2_main_run_warp_zone_object:
    LDA ScrollLock  ; check for scroll lock flag
    BEQ bra_smb2_main_exit_game_timer  ; branch if not set to leave
    LDA Player_Y_Position  ; check to see if player's vertical coordinate has
    AND Player_Y_HighPos  ; same bits set as in vertical high byte (why?)
    BNE bra_smb2_main_exit_game_timer  ; if so, branch to leave
    STA ScrollLock  ; otherwise nullify scroll lock flag
    JMP sub_smb2_main_erase_enemy_object  ; kill this object

; -------------------------------------------------------------------------------------
; $00 - used in WhirlpoolActivate to store whirlpool length / 2, page location of center of whirlpool
; and also to store movement force exerted on player
; $01 - used in ProcessWhirlpools to store page location of right extent of whirlpool
; and in WhirlpoolActivate to store center of whirlpool
; $02 - used in ProcessWhirlpools to store right extent of whirlpool and in
; WhirlpoolActivate to store maximum vertical speed

sub_smb2_main_process_whirlpool_pull:
    LDA AreaType  ; check for water type level
    BNE bra_smb2_main_exit_whirlpool_processing  ; branch to leave if not found
    STA Whirlpool_Flag  ; otherwise initialize whirlpool flag
    LDA TimerControl  ; if master timer control set,
    BNE bra_smb2_main_exit_whirlpool_processing  ; branch to leave
    LDY #$04  ; otherwise start with last whirlpool data
bra_smb2_main_process_whirlpool_slots:
    LDA Whirlpool_LeftExtent,y  ; get left extent of whirlpool
    CLC
    ADC Whirlpool_Length,y  ; add length of whirlpool
    STA $02  ; store result as right extent here
    LDA Whirlpool_PageLoc,y  ; get page location
    BEQ bra_smb2_main_advance_whirlpool_slot  ; if none or page 0, branch to get next data
    ADC #$00  ; add carry
    STA $01  ; store result as page location of right extent here
    LDA Player_X_Position  ; get player's horizontal position
    SEC
    SBC Whirlpool_LeftExtent,y  ; subtract left extent
    LDA Player_PageLoc  ; get player's page location
    SBC Whirlpool_PageLoc,y  ; subtract borrow
    BMI bra_smb2_main_advance_whirlpool_slot  ; if player too far left, branch to get next data
    LDA $02  ; otherwise get right extent
    SEC
    SBC Player_X_Position  ; subtract player's horizontal coordinate
    LDA $01  ; get right extent's page location
    SBC Player_PageLoc  ; subtract borrow
    BPL bra_smb2_main_activate_whirlpool_pull  ; if player within right extent, branch to whirlpool code
bra_smb2_main_advance_whirlpool_slot:
    DEY  ; move onto next whirlpool data
    BPL bra_smb2_main_process_whirlpool_slots  ; do this until all whirlpools are checked
bra_smb2_main_exit_whirlpool_processing:
    RTS  ; leave

bra_smb2_main_activate_whirlpool_pull:
    LDA Whirlpool_Length,y  ; get length of whirlpool
    LSR  ; divide by 2
    STA $00  ; save here
    LDA Whirlpool_LeftExtent,y  ; get left extent of whirlpool
    CLC
    ADC $00  ; add length divided by 2
    STA $01  ; save as center of whirlpool
    LDA Whirlpool_PageLoc,y  ; get page location
    ADC #$00  ; add carry
    STA $00  ; save as page location of whirlpool center
    LDA FrameCounter  ; get frame counter
    LSR  ; shift d0 into carry (to run on every other frame)
    BCC bra_smb2_main_apply_whirlpool_vertical_pull  ; if d0 not set, branch to last part of code
    LDA $01  ; get center
    SEC
    SBC Player_X_Position  ; subtract player's horizontal coordinate
    LDA $00  ; get page location of center
    SBC Player_PageLoc  ; subtract borrow
    BPL bra_smb2_main_pull_player_right_to_whirlpool  ; if player to the left of center, branch
    LDA Player_X_Position  ; otherwise slowly pull player left, towards the center
    SEC
    SBC #$01  ; subtract one pixel
    STA Player_X_Position  ; set player's new horizontal coordinate
    LDA Player_PageLoc
    SBC #$00  ; subtract borrow
    JMP loc_smb2_main_store_whirlpool_player_page  ; jump to set player's new page location
bra_smb2_main_pull_player_right_to_whirlpool:
    LDA Player_CollisionBits  ; get player's collision bits
    LSR  ; shift d0 into carry
    BCC bra_smb2_main_apply_whirlpool_vertical_pull  ; if d0 not set, branch
    LDA Player_X_Position  ; otherwise slowly pull player right, towards the center
    CLC
    ADC #$01  ; add one pixel
    STA Player_X_Position  ; set player's new horizontal coordinate
    LDA Player_PageLoc
    ADC #$00  ; add carry
loc_smb2_main_store_whirlpool_player_page:
    STA Player_PageLoc  ; set player's new page location
bra_smb2_main_apply_whirlpool_vertical_pull:
    LDA #$10
    STA $00  ; set vertical movement force
    LDA #$01
    STA Whirlpool_Flag  ; set whirlpool flag to be used later
    STA $02  ; also set maximum vertical speed
    LSR
    TAX  ; set X for player offset
    JMP sub_smb2_main_apply_object_gravity  ; jump to put whirlpool effect on player vertically, do not return

; -------------------------------------------------------------------------------------

tbl_smb2_main_flagpole_score_modifiers:
    .byte $05, $02, $08, $04, $01

tbl_smb2_main_flagpole_score_digits:
    .byte $03, $03, $04, $04, $04

sub_smb2_main_flagpole_routine:
    LDX #$05  ; set enemy object offset
    STX ObjectOffset  ; to special use slot
    LDA Enemy_ID,x
    CMP #FlagpoleFlagObject  ; if flagpole flag not found,
    BNE bra_smb2_main_exit_flagpole  ; branch to leave
    LDA GameEngineSubroutine
    CMP #$04  ; if flagpole slide routine not running,
    BNE bra_smb2_main_skip_flagpole_score_award  ; branch to near the end of code
    LDA Player_State
    CMP #$03  ; if player state not climbing,
    BNE bra_smb2_main_skip_flagpole_score_award  ; branch to near the end of code
    LDA Enemy_Y_Position,x  ; check flagpole flag's vertical coordinate
    CMP #$aa  ; if flagpole flag down to a certain point,
    BCS bra_smb2_main_award_flagpole_score  ; branch to end the level
    LDA Player_Y_Position  ; check player's vertical coordinate
    CMP #$a2  ; if player down to a certain point,
    BCS bra_smb2_main_award_flagpole_score  ; branch to end the level
    LDA Enemy_YMF_Dummy,x
    ADC #$ff  ; add movement amount to dummy variable
    STA Enemy_YMF_Dummy,x  ; save dummy variable
    LDA Enemy_Y_Position,x  ; get flag's vertical coordinate
    ADC #$01  ; add 1 plus carry to move flag, and
    STA Enemy_Y_Position,x  ; store vertical coordinate
    LDA FlagpoleFNum_YMFDummy
    SEC  ; subtract movement amount from dummy variable
    SBC #$ff
    STA FlagpoleFNum_YMFDummy  ; save dummy variable
    LDA FlagpoleFNum_Y_Pos
    SBC #$01  ; subtract one plus borrow to move floatey number,
    STA FlagpoleFNum_Y_Pos  ; and store vertical coordinate here
bra_smb2_main_skip_flagpole_score_award:
    JMP loc_smb2_main_render_flagpole_objects  ; jump to skip ahead and draw flag and floatey number
bra_smb2_main_award_flagpole_score:
    LDY FlagpoleScore  ; get score offset from earlier (when player touched flagpole)
    CPY #$05
    BNE bra_smb2_main_award_flagpole_points  ; if set to give player an extra life, do so now
    INC NumberofLives
    LDA #$40
    STA $fe
    JMP loc_smb2_main_finish_flagpole_score_award
bra_smb2_main_award_flagpole_points:
    LDA tbl_smb2_main_flagpole_score_modifiers,y  ; get amount to award player points
    LDX tbl_smb2_main_flagpole_score_digits,y  ; get digit with which to award points
    STA DigitModifier,x  ; store in digit modifier
    JSR sub_smb2_main_add_to_score  ; do sub to award player points depending on height of collision
loc_smb2_main_finish_flagpole_score_award:
    LDA #$05
    STA GameEngineSubroutine  ; set to run end-of-level subroutine on next frame
loc_smb2_main_render_flagpole_objects:
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; get offscreen information
    JSR sub_smb2_main_relative_enemy_position  ; get relative coordinates
    JSR sub_smb2_main_render_flagpole_graphics  ; draw flagpole flag and floatey number
bra_smb2_main_exit_flagpole:
    RTS

; -------------------------------------------------------------------------------------

off_smb2_main_jumpspring_y_positions:
    .byte $08, $10, $08, $00

handler_smb2_main_process_jumpspring:
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; get offscreen information
    LDA TimerControl  ; check master timer control
    BNE bra_smb2_main_draw_jumpspring_object  ; branch to last section if set
    LDA JumpspringAnimCtrl  ; check jumpspring frame control
    BEQ bra_smb2_main_draw_jumpspring_object  ; branch to last section if not set
    TAY
    DEY  ; subtract one from frame control in A,
    TYA  ; the only way a poor NMOS 6502 can
    AND #%00000010  ; mask out all but d1, original value still in Y
    BNE bra_smb2_main_move_player_up_with_jumpspring  ; if set, branch to move player up
    INC Player_Y_Position
    INC Player_Y_Position  ; move player's vertical position down two pixels
    JMP loc_smb2_main_position_jumpspring  ; skip to next part
bra_smb2_main_move_player_up_with_jumpspring:
    DEC Player_Y_Position  ; move player's vertical position up two pixels
    DEC Player_Y_Position
loc_smb2_main_position_jumpspring:
    LDA Jumpspring_FixedYPos,x  ; get permanent vertical position
    CLC
    ADC off_smb2_main_jumpspring_y_positions,y  ; add value using frame control as offset
    STA Enemy_Y_Position,x  ; store as new vertical position
    CPY #$01  ; check frame control offset (second frame is $00)
    BCC bra_smb2_main_apply_jumpspring_bounce  ; if offset not yet at third frame ($01), skip to next part
    LDA A_B_Buttons
    AND #A_Button  ; check saved controller bits for A button press
    BEQ bra_smb2_main_apply_jumpspring_bounce  ; skip to next part if A not pressed
    AND PreviousA_B_Buttons  ; check for A button pressed in previous frame
    BNE bra_smb2_main_apply_jumpspring_bounce  ; skip to next part if so
    TYA
    PHA
    LDA #$f4  ; set jumpspring force for red jumpsprings
    LDY WorldNumber
    CPY #World2
    BEQ bra_smb2_main_use_green_jumpspring  ; if world number is 2, 3 or 7
    CPY #World3  ; set jumpspring force for green jumpsprings
    BEQ bra_smb2_main_use_green_jumpspring
    CPY #World7  ; otherwise use red jumpspring force
    BNE bra_smb2_main_set_jumpspring_force
bra_smb2_main_use_green_jumpspring:
    LDA #$e0
bra_smb2_main_set_jumpspring_force:
    STA JumpspringForce  ; otherwise write new jumpspring force here
    PLA
    TAY
bra_smb2_main_apply_jumpspring_bounce:
    CPY #$03  ; check frame control offset again
    BNE bra_smb2_main_draw_jumpspring_object  ; skip to last part if not yet at fifth frame ($03)
    LDA JumpspringForce
    STA Player_Y_Speed  ; store jumpspring force as player's new vertical speed
    LDA #$00
    STA JumpspringAnimCtrl  ; initialize jumpspring frame control
bra_smb2_main_draw_jumpspring_object:
    JSR sub_smb2_main_relative_enemy_position  ; get jumpspring's relative coordinates
    JSR sub_smb2_main_render_enemy_graphics  ; draw jumpspring
    JSR sub_smb2_main_offscreen_bounds_check  ; check to see if we need to kill it
    LDA JumpspringAnimCtrl  ; if frame control at zero, don't bother
    BEQ bra_smb2_main_exit_jumpspring  ; trying to animate it, just leave
    LDA JumpspringTimer
    BNE bra_smb2_main_exit_jumpspring  ; if jumpspring timer not expired yet, leave
    LDA #$04
    STA JumpspringTimer  ; otherwise initialize jumpspring timer
    INC JumpspringAnimCtrl  ; increment frame control to animate jumpspring
bra_smb2_main_exit_jumpspring:
    RTS  ; leave

; -------------------------------------------------------------------------------------

sub_smb2_main_setup_vine:
    LDA #VineObject  ; load identifier for vine object
    STA Enemy_ID,x  ; store in buffer
    LDA #$01
    STA Enemy_Flag,x  ; set flag for enemy object buffer
    LDA Block_PageLoc,y
    STA Enemy_PageLoc,x  ; copy page location from previous object
    LDA Block_X_Position,y
    STA Enemy_X_Position,x  ; copy horizontal coordinate from previous object
    LDA Block_Y_Position,y
    STA Enemy_Y_Position,x  ; copy vertical coordinate from previous object
    LDY VineFlagOffset  ; load vine flag/offset to next available vine slot
    BNE bra_smb2_main_store_next_vine_object  ; if set at all, don't bother to store vertical
    STA VineStart_Y_Position  ; otherwise store vertical coordinate here
bra_smb2_main_store_next_vine_object:
    TXA  ; store object offset to next available vine slot
    STA VineObjOffset,y  ; using vine flag as offset
    INC VineFlagOffset  ; increment vine flag offset
    LDA #Sfx_GrowVine
    STA Square2SoundQueue  ; load vine grow sound
    RTS

; -------------------------------------------------------------------------------------
; $06-$07 - used as address to block buffer data
; $02 - used as vertical high nybble of block buffer offset

off_smb2_main_vine_growth_heights:
    .byte $30, $60

handler_smb2_main_run_vine_object:
    CPX #$05  ; check enemy offset for special use slot
    BEQ bra_smb2_main_process_vine_object  ; if in special use slot, continue
    RTS
bra_smb2_main_process_vine_object:
    LDY VineFlagOffset
    DEY  ; decrement vine flag in Y, use as offset
    LDA VineHeight
    CMP off_smb2_main_vine_growth_heights,y  ; if vine has reached certain height,
    BEQ bra_smb2_main_run_vine_subsystems  ; branch ahead to skip this part
    LDA FrameCounter  ; get frame counter
    LSR  ; shift d1 into carry
    LSR
    BCC bra_smb2_main_run_vine_subsystems  ; if d1 not set (2 frames every 4) skip this part
    LDA Enemy_Y_Position+5
    SBC #$01  ; subtract vertical position of vine
    STA Enemy_Y_Position+5  ; one pixel every frame it's time
    INC VineHeight  ; increment vine height
bra_smb2_main_run_vine_subsystems:
    LDA VineHeight  ; if vine still very small,
    CMP #$08  ; branch to last part
    BCC bra_smb2_main_check_vertical_offscreen
    JSR sub_smb2_main_relative_enemy_position  ; get relative coordinates of vine,
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; and any offscreen bits
    LDY #$00  ; initialize offset used in draw vine sub
bra_smb2_main_draw_vine_segments_loop:
    JSR sub_smb2_main_draw_vine  ; draw vine
    INY  ; increment offset
    CPY VineFlagOffset  ; if offset in Y and offset here
    BNE bra_smb2_main_draw_vine_segments_loop  ; do not yet match, loop back to draw more vine
    LDA Enemy_OffscreenBits
    AND #%00001100  ; mask offscreen bits
    BEQ bra_smb2_main_write_vine_climb_metatile  ; if none of the saved offscreen bits set, skip ahead
    DEY  ; otherwise decrement Y to get proper offset again
bra_smb2_main_erase_vine_objects_loop:
    LDX VineObjOffset,y  ; get enemy object offset for this vine object
    JSR sub_smb2_main_erase_enemy_object  ; kill this vine object
    DEY  ; decrement Y
    BPL bra_smb2_main_erase_vine_objects_loop  ; if any vine objects left, loop back to kill it
    STA VineFlagOffset  ; initialize vine flag/offset
    STA VineHeight  ; initialize vine height
bra_smb2_main_write_vine_climb_metatile:
    LDA VineHeight  ; check vine height
    CMP #$20  ; if vine small (less than 32 pixels tall)
    BCC bra_smb2_main_check_vertical_offscreen  ; then branch ahead to last part to skip this
    LDX #$06  ; set offset in X to last enemy slot
    LDA #$01  ; set A to obtain horizontal in $04, but we don't care
    LDY #$1b  ; set Y to offset to get block at ($04, $10) of coordinates
    JSR sub_smb2_main_block_buffer_collision  ; do a sub to get block buffer address set, return contents
    LDY $02
    CPY #$d0  ; if vertical high nybble offset beyond extent of
    BCS bra_smb2_main_check_vertical_offscreen  ; current block buffer, branch to leave, do not write
    LDA ($06),y  ; otherwise check contents of block buffer at
    BNE bra_smb2_main_check_vertical_offscreen  ; current offset, if not empty, branch to leave
    LDA #$23
    STA ($06),y  ; otherwise, write climbing metatile to block buffer
bra_smb2_main_check_vertical_offscreen:
    LDA Enemy_X_Position+5
    SEC
    SBC ScreenLeft_X_Pos
    TAY
    LDA Enemy_PageLoc+5  ; compare horizontal position of vine
    SBC ScreenLeft_PageLoc  ; to that of the left side of the screen
    BMI bra_smb2_main_vine_offscr  ; if vine isn't within 8 pixels of the edge
    CPY #$09  ; or past the left edge, branch to leave
    BCS bra_smb2_main_exit_vine_handler
bra_smb2_main_vine_offscr:
    LDA #$00  ; erase vine's flag to kill it
    STA Enemy_Flag+5
    LDA Enemy_PageLoc+5
    AND #$01  ; fetch the right block buffer address
    TAY
    LDA tbl_smb2_main_block_buffer_addresses,y
    STA $06
    LDA tbl_smb2_main_block_buffer_addresses+2,y
    STA $07
    LDA Enemy_X_Position+5  ; divide upper nybble of X position by 16
    LSR  ; to get appropriate offset
    LSR
    LSR
    LSR
bra_smb2_main_erase_climbing_metatile_loop:
    TAY
    LDA ($06),y  ; check for climbing metatile
    CMP #$23  ; if not found, move down a row
    BNE bra_smb2_main_no_climb_m
    LDA #$00  ; otherwise erase climbing metatile
    STA ($06),y
bra_smb2_main_no_climb_m:
    TYA
    CLC
    ADC #$10  ; move 16 bytes (one row) ahead in block buffer
    CMP #$d0  ; if not at bottom row, loop
    BCC bra_smb2_main_erase_climbing_metatile_loop
bra_smb2_main_exit_vine_handler:
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

; -------------------------------------------------------------------------------------

tbl_smb2_main_cannon_slot_masks_by_hard_mode:
    .byte %00001111, %00000111

sub_smb2_main_process_cannons:
    LDA AreaType  ; get area type
    BEQ bra_smb2_main_exit_cannon_processing  ; if water type area, branch to leave
    LDX #$02
bra_smb2_main_check_cannon_slots:
    STX ObjectOffset  ; start at third enemy slot
    LDA Enemy_Flag,x  ; check enemy buffer flag
    BNE bra_smb2_main_check_bullet_bill_slot  ; if set, branch to check enemy
    LDA PseudoRandomBitReg+1,x  ; otherwise get part of LSFR
    LDY SecondaryHardMode  ; get secondary hard mode flag, use as offset
    AND tbl_smb2_main_cannon_slot_masks_by_hard_mode,y  ; mask out bits of LSFR as decided by flag
    CMP #$06  ; check to see if lower nybble is above certain value
    BCS bra_smb2_main_check_bullet_bill_slot  ; if so, branch to check enemy
    TAY  ; transfer masked contents of LSFR to Y as pseudorandom offset
    LDA Cannon_PageLoc,y  ; get page location
    BEQ bra_smb2_main_check_bullet_bill_slot  ; if not set or on page 0, branch to check enemy
    LDA Cannon_Timer,y  ; get cannon timer
    BEQ bra_smb2_main_fire_bullet_bill_cannon  ; if expired, branch to fire cannon
    SBC #$00  ; otherwise subtract borrow (note carry will always be clear here)
    STA Cannon_Timer,y  ; to count timer down
    JMP bra_smb2_main_check_bullet_bill_slot  ; then jump ahead to check enemy

bra_smb2_main_fire_bullet_bill_cannon:
    LDA TimerControl  ; if master timer control set,
    BNE bra_smb2_main_check_bullet_bill_slot  ; branch to check enemy
    LDA #$0e  ; otherwise we start creating one
    STA Cannon_Timer,y  ; first, reset cannon timer
    LDA Cannon_PageLoc,y  ; get page location of cannon
    STA Enemy_PageLoc,x  ; save as page location of bullet bill
    LDA Cannon_X_Position,y  ; get horizontal coordinate of cannon
    STA Enemy_X_Position,x  ; save as horizontal coordinate of bullet bill
    LDA Cannon_Y_Position,y  ; get vertical coordinate of cannon
    SEC
    SBC #$08  ; subtract eight pixels (because enemies are 24 pixels tall)
    STA Enemy_Y_Position,x  ; save as vertical coordinate of bullet bill
    LDA #$01
    STA Enemy_Y_HighPos,x  ; set vertical high byte of bullet bill
    STA Enemy_Flag,x  ; set buffer flag
    LSR  ; shift right once to init A
    STA Enemy_State,x  ; then initialize enemy's state
    LDA #$09
    STA Enemy_BoundBoxCtrl,x  ; set bounding box size control for bullet bill
    LDA #BulletBill_CannonVar
    STA Enemy_ID,x  ; load identifier for bullet bill (cannon variant)
    JMP bra_smb2_main_advance_cannon_slot  ; move onto next slot
bra_smb2_main_check_bullet_bill_slot:
    LDA Enemy_ID,x  ; check enemy identifier for bullet bill (cannon variant)
    CMP #BulletBill_CannonVar
    BNE bra_smb2_main_advance_cannon_slot  ; if not found, branch to get next slot
    JSR sub_smb2_main_offscreen_bounds_check  ; otherwise, check to see if it went offscreen
    LDA Enemy_Flag,x  ; check enemy buffer flag
    BEQ bra_smb2_main_advance_cannon_slot  ; if not set, branch to get next slot
    JSR sub_smb2_main_get_enemy_offscreen_bits  ; otherwise, get offscreen information
    JSR sub_smb2_main_bullet_bill_handler  ; then do sub to handle bullet bill
bra_smb2_main_advance_cannon_slot:
    DEX  ; move onto next slot
    BPL bra_smb2_main_check_cannon_slots  ; do this until first three slots are checked
bra_smb2_main_exit_cannon_processing:
    RTS  ; then leave

; --------------------------------
