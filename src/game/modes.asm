; -------------------------------------------------------------------------------------

TitleScreenMode:
    LDA ram_oper_mode_task
    JSR sub_dispatch_inline_handler

    .word InitializeGame
    .word ScreenRoutines
    .word PrimaryGameSetup
    .word GameMenuRoutine

; -------------------------------------------------------------------------------------

WSelectBufferTemplate:
    .byte $04, $20, $73, $01, $00, $00

GameMenuRoutine:
    LDY #$00
    LDA ram_saved_joypad1_bits  ; check to see if either player pressed
    ORA ram_saved_joypad2_bits  ; only the start button (either joypad)
    CMP #con_btn_start
    BEQ StartGame
    CMP #con_btn_a+con_btn_start  ; check to see if A + start was pressed
    BNE ChkSelect  ; if not, branch to check select button
StartGame:
    JMP ChkContinue  ; if either start or A + start, execute here
ChkSelect:
    CMP #con_btn_select  ; check to see if the select button was pressed
    BEQ SelectBLogic  ; if so, branch reset demo timer
    LDX ram_demo_timer  ; otherwise check demo timer
    BNE ChkWorldSel  ; if demo timer not expired, branch to check world selection
    STA ram_select_timer  ; set controller bits here if running demo
    JSR sub_demo_engine  ; run through the demo actions
    BCS ResetTitle  ; if carry flag set, demo over, thus branch
    JMP RunDemo  ; otherwise, run game engine for demo
ChkWorldSel:
    LDX ram_world_select_enable_flag  ; check to see if world selection has been enabled
    BEQ NullJoypad
    CMP #con_btn_b  ; if so, check to see if the B button was pressed
    BNE NullJoypad
    INY  ; if so, increment Y and execute same code as select
SelectBLogic:
    LDA ram_demo_timer  ; if select or B pressed, check demo timer one last time
    BEQ ResetTitle  ; if demo timer expired, branch to reset title screen mode
    LDA #$18  ; otherwise reset demo timer
    STA ram_demo_timer
    LDA ram_select_timer  ; check select/B button timer
    BNE NullJoypad  ; if not expired, branch
    LDA #$10  ; otherwise reset select button timer
    STA ram_select_timer
    CPY #$01  ; was the B button pressed earlier?  if so, branch
    BEQ IncWorldSel  ; note this will not be run if world selection is disabled
    LDA ram_number_of_players  ; if no, must have been the select button, therefore
    EOR #%00000001  ; change number of players and draw icon accordingly
    STA ram_number_of_players
    JSR sub_draw_mushroom_icon
    JMP NullJoypad
IncWorldSel:
    LDX ram_world_select_number  ; increment world select number
    INX
    TXA
    AND #%00000111  ; mask out higher bits
    STA ram_world_select_number  ; store as current world select number
    JSR sub_go_continue
UpdateShroom:
    LDA WSelectBufferTemplate,x  ; write template for world select in vram buffer
    STA ram_vram_buffer1-1,x  ; do this until all bytes are written
    INX
    CPX #$06
    BMI UpdateShroom
    LDY ram_world_number  ; get world number from variable and increment for
    INY  ; proper display, and put in blank byte before
    STY ram_vram_buffer1+3  ; null terminator
NullJoypad:
    LDA #$00  ; clear joypad bits for player 1
    STA ram_saved_joypad1_bits
RunDemo:
    JSR sub_game_core_routine  ; run game engine
    LDA ram_game_engine_subroutine  ; check to see if we're running lose life routine
    CMP #$06
    BNE ExitMenu  ; if not, do not do all the resetting below
ResetTitle:
    LDA #$00  ; reset game modes, disable
    STA ram_oper_mode  ; sprite 0 check and disable
    STA ram_oper_mode_task  ; screen output
    STA ram_sprite0_hit_detect_flag
    INC ram_disable_screen_flag
    RTS
ChkContinue:
    LDY ram_demo_timer  ; if timer for demo has expired, reset modes
    BEQ ResetTitle
    ASL  ; check to see if A button was also pushed
    BCC StartWorld1  ; if not, don't load continue function's world number
    LDA ram_continue_world  ; load previously saved world number for secret
    JSR sub_go_continue  ; continue function when pressing A + start
StartWorld1:
    JSR sub_load_area_pointer
    INC ram_hidden1_up_flag  ; set 1-up box flag for both players
    INC ram_off_scr_hidden1_up_flag
    INC ram_fetch_new_game_timer_flag  ; set fetch new game timer flag
    INC ram_oper_mode  ; set next game mode
    LDA ram_world_select_enable_flag  ; if world select flag is on, then primary
    STA ram_primary_hard_mode  ; hard mode must be on as well
    LDA #$00
    STA ram_oper_mode_task  ; set game mode here, and clear demo timer
    STA ram_demo_timer
    LDX #$17
    LDA #$00
InitScores:
    STA ram_score_and_coin_display,x  ; clear player scores and coin displays
    DEX
    BPL InitScores
ExitMenu:
    RTS
sub_go_continue:
    STA ram_world_number  ; start both players at the first area
    STA ram_off_scr_world_number  ; of the previously saved world number
    LDX #$00  ; note that on power-up using this function
    STX ram_area_number  ; will make no difference
    STX ram_off_scr_area_number
    RTS

; -------------------------------------------------------------------------------------

MushroomIconData:
    .byte $07, $22, $49, $83, $ce, $24, $24, $00

sub_draw_mushroom_icon:
    LDY #$07  ; read eight bytes to be read by transfer routine
IconDataRead:
    LDA MushroomIconData,y  ; note that the default position is set for a
    STA ram_vram_buffer1-1,y  ; 1-player game
    DEY
    BPL IconDataRead
    LDA ram_number_of_players  ; check number of players
    BEQ ExitIcon  ; if set to 1-player game, we're done
    LDA #$24  ; otherwise, load blank tile in 1-player position
    STA ram_vram_buffer1+3
    LDA #$ce  ; then load shroom icon tile in 2-player position
    STA ram_vram_buffer1+5
ExitIcon:
    RTS

; -------------------------------------------------------------------------------------

DemoActionData:
    .byte $01, $80, $02, $81, $41, $80, $01
    .byte $42, $c2, $02, $80, $41, $c1, $41, $c1
    .byte $01, $c1, $01, $02, $80, $00

DemoTimingData:
    .byte $9b, $10, $18, $05, $2c, $20, $24
    .byte $15, $5a, $10, $20, $28, $30, $20, $10
    .byte $80, $20, $30, $30, $01, $ff, $00

sub_demo_engine:
    LDX ram_demo_action  ; load current demo action
    LDA ram_demo_action_timer  ; load current action timer
    BNE DoAction  ; if timer still counting down, skip
    INX
    INC ram_demo_action  ; if expired, increment action, X, and
    SEC  ; set carry by default for demo over
    LDA DemoTimingData-1,x  ; get next timer
    STA ram_demo_action_timer  ; store as current timer
    BEQ DemoOver  ; if timer already at zero, skip
DoAction:
    LDA DemoActionData-1,x  ; get and perform action (current or next)
    STA ram_saved_joypad1_bits
    DEC ram_demo_action_timer  ; decrement action timer
    CLC  ; clear carry if demo still going
DemoOver:
    RTS

; -------------------------------------------------------------------------------------

VictoryMode:
    JSR sub_victory_mode_subroutines  ; run victory mode subroutines
    LDA ram_oper_mode_task  ; get current task of victory mode
    BEQ AutoPlayer  ; if on bridge collapse, skip enemy processing
    LDX #$00
    STX ram_object_offset  ; otherwise reset enemy object offset
    JSR sub_enemies_and_loops_core  ; and run enemy code
AutoPlayer:
    JSR sub_relative_player_position  ; get player's relative coordinates
    JMP sub_player_gfx_handler  ; draw the player, then leave

sub_victory_mode_subroutines:
    LDA ram_oper_mode_task
    JSR sub_dispatch_inline_handler

    .word BridgeCollapse
    .word SetupVictoryMode
    .word PlayerVictoryWalk
    .word PrintVictoryMessages
    .word PlayerEndWorld

; -------------------------------------------------------------------------------------

SetupVictoryMode:
    LDX ram_screen_right_page_loc  ; get page location of right side of screen
    INX  ; increment to next page
    STX ram_destination_page_loc  ; store here
    LDA #con_end_of_castle_music
    STA ram_event_music_queue  ; play win castle music
    JMP IncModeTask_B  ; jump to set next major task in victory mode

; -------------------------------------------------------------------------------------

PlayerVictoryWalk:
    LDY #$00  ; set value here to not walk player by default
    STY ram_victory_walk_control
    LDA ram_player_page_loc  ; get player's page location
    CMP ram_destination_page_loc  ; compare with destination page location
    BNE PerformWalk  ; if page locations don't match, branch
    LDA ram_player_x_position  ; otherwise get player's horizontal position
    CMP #$60  ; compare with preset horizontal position
    BCS DontWalk  ; if still on other page, branch ahead
PerformWalk:
    INC ram_victory_walk_control  ; otherwise increment value and Y
    INY  ; note Y will be used to walk the player
DontWalk:
    TYA  ; put contents of Y in A and
    JSR sub_auto_control_player  ; use A to move player to the right or not
    LDA ram_screen_left_page_loc  ; check page location of left side of screen
    CMP ram_destination_page_loc  ; against set value here
    BEQ ExitVWalk  ; branch if equal to change modes if necessary
    LDA ram_scroll_fractional
    CLC  ; do fixed point math on fractional part of scroll
    ADC #$80
    STA ram_scroll_fractional  ; save fractional movement amount
    LDA #$01  ; set 1 pixel per frame
    ADC #$00  ; add carry from previous addition
    TAY  ; use as scroll amount
    JSR sub_scroll_screen  ; do sub to scroll the screen
    JSR sub_upd_scroll_var  ; do another sub to update screen and scroll variables
    INC ram_victory_walk_control  ; increment value to stay in this routine
ExitVWalk:
    LDA ram_victory_walk_control  ; load value set here
    BEQ IncModeTask_A  ; if zero, branch to change modes
    RTS  ; otherwise leave

; -------------------------------------------------------------------------------------

PrintVictoryMessages:
    LDA ram_secondary_msg_counter  ; load secondary message counter
    BNE IncMsgCounter  ; if set, branch to increment message counters
    LDA ram_primary_msg_counter  ; otherwise load primary message counter
    BEQ ThankPlayer  ; if set to zero, branch to print first message
    CMP #$09  ; if at 9 or above, branch elsewhere (this comparison
    BCS IncMsgCounter  ; is residual code, counter never reaches 9)
    LDY ram_world_number  ; check world number
    CPY #con_world8
    BNE MRetainerMsg  ; if not at world 8, skip to next part
    CMP #$03  ; check primary message counter again
    BCC IncMsgCounter  ; if not at 3 yet (world 8 only), branch to increment
    SBC #$01  ; otherwise subtract one
    JMP ThankPlayer  ; and skip to next part
MRetainerMsg:
    CMP #$02  ; check primary message counter
    BCC IncMsgCounter  ; if not at 2 yet (world 1-7 only), branch
ThankPlayer:
    TAY  ; put primary message counter into Y
    BNE SecondPartMsg  ; if counter nonzero, skip this part, do not print first message
    LDA ram_current_player  ; otherwise get player currently on the screen
    BEQ EvalForMusic  ; if mario, branch
    INY  ; otherwise increment Y once for luigi and
    BNE EvalForMusic  ; do an unconditional branch to the same place
SecondPartMsg:
    INY  ; increment Y to do world 8's message
    LDA ram_world_number
    CMP #con_world8  ; check world number
    BEQ EvalForMusic  ; if at world 8, branch to next part
    DEY  ; otherwise decrement Y for world 1-7's message
    CPY #$04  ; if counter at 4 (world 1-7 only)
    BCS SetEndTimer  ; branch to set victory end timer
    CPY #$03  ; if counter at 3 (world 1-7 only)
    BCS IncMsgCounter  ; branch to keep counting
EvalForMusic:
    CPY #$03  ; if counter not yet at 3 (world 8 only), branch
    BNE PrintMsg  ; to print message only (note world 1-7 will only
    LDA #con_victory_music  ; reach this code if counter = 0, and will always branch)
    STA ram_event_music_queue  ; otherwise load victory music first (world 8 only)
PrintMsg:
    TYA  ; put primary message counter in A
    CLC  ; add $0c or 12 to counter thus giving an appropriate value,
    ADC #$0c  ; ($0c-$0d = first), ($0e = world 1-7's), ($0f-$12 = world 8's)
    STA ram_vram_buffer_addr_ctrl  ; write message counter to vram address controller
IncMsgCounter:
    LDA ram_secondary_msg_counter
    CLC
    ADC #$04  ; add four to secondary message counter
    STA ram_secondary_msg_counter
    LDA ram_primary_msg_counter
    ADC #$00  ; add carry to primary message counter
    STA ram_primary_msg_counter
    CMP #$07  ; check primary counter one more time
SetEndTimer:
    BCC ExitMsgs  ; if not reached value yet, branch to leave
    LDA #$06
    STA ram_world_end_timer  ; otherwise set world end timer
IncModeTask_A:
    INC ram_oper_mode_task  ; move onto next task in mode
ExitMsgs:
    RTS  ; leave

; -------------------------------------------------------------------------------------

PlayerEndWorld:
    LDA ram_world_end_timer  ; check to see if world end timer expired
    BNE EndExitOne  ; branch to leave if not
    LDY ram_world_number  ; check world number
    CPY #con_world8  ; if on world 8, player is done with game,
    BCS EndChkBButton  ; thus branch to read controller
    LDA #$00
    STA ram_area_number  ; otherwise initialize area number used as offset
    STA ram_level_number  ; and level number control to start at area 1
    STA ram_oper_mode_task  ; initialize secondary mode of operation
    INC ram_world_number  ; increment world number to move onto the next world
    JSR sub_load_area_pointer  ; get area address offset for the next area
    INC ram_fetch_new_game_timer_flag  ; set flag to load game timer from header
    LDA #con_mode_game
    STA ram_oper_mode  ; set mode of operation to game mode
EndExitOne:
    RTS  ; and leave
EndChkBButton:
    LDA ram_saved_joypad1_bits
    ORA ram_saved_joypad2_bits  ; check to see if B button was pressed on
    AND #con_btn_b  ; either controller
    BEQ EndExitTwo  ; branch to leave if not
    LDA #$01  ; otherwise set world selection flag
    STA ram_world_select_enable_flag
    LDA #$ff  ; remove onscreen player's lives
    STA ram_numberof_lives
    JSR sub_terminate_game  ; do sub to continue other player or end game
EndExitTwo:
    RTS  ; leave

; -------------------------------------------------------------------------------------

; data is used as tiles for numbers
; that appear when you defeat enemies
FloateyNumTileData:
    .byte $ff, $ff  ; dummy
    .byte $f6, $fb  ; "100"
    .byte $f7, $fb  ; "200"
    .byte $f8, $fb  ; "400"
    .byte $f9, $fb  ; "500"
    .byte $fa, $fb  ; "800"
    .byte $f6, $50  ; "1000"
    .byte $f7, $50  ; "2000"
    .byte $f8, $50  ; "4000"
    .byte $f9, $50  ; "5000"
    .byte $fa, $50  ; "8000"
    .byte $fd, $fe  ; "1-UP"

; high nybble is digit number, low nybble is number to
; add to the digit of the player's score
ScoreUpdateData:
    .byte $ff  ; dummy
    .byte $41, $42, $44, $45, $48
    .byte $31, $32, $34, $35, $38, $00

sub_floatey_numbers_routine:
    LDA ram_floatey_num_control,x  ; load control for floatey number
    BEQ EndExitOne  ; if zero, branch to leave
    CMP #$0b  ; if less than $0b, branch
    BCC ChkNumTimer
    LDA #$0b  ; otherwise set to $0b, thus keeping
    STA ram_floatey_num_control,x  ; it in range
ChkNumTimer:
    TAY  ; use as Y
    LDA ram_floatey_num_timer,x  ; check value here
    BNE DecNumTimer  ; if nonzero, branch ahead
    STA ram_floatey_num_control,x  ; initialize floatey number control and leave
    RTS
DecNumTimer:
    DEC ram_floatey_num_timer,x  ; decrement value here
    CMP #$2b  ; if not reached a certain point, branch
    BNE ChkTallEnemy
    CPY #$0b  ; check offset for $0b
    BNE LoadNumTiles  ; branch ahead if not found
    INC ram_numberof_lives  ; give player one extra life (1-up)
    LDA #con_sfx_extra_life
    STA ram_square2_sound_queue  ; and play the 1-up sound
LoadNumTiles:
    LDA ScoreUpdateData,y  ; load point value here
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    TAX  ; use as X offset, essentially the digit
    LDA ScoreUpdateData,y  ; load again and this time
    AND #%00001111  ; mask out the high nybble
    STA ram_digit_modifier,x  ; store as amount to add to the digit
    JSR sub_add_to_score  ; update the score accordingly
ChkTallEnemy:
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset for enemy object
    LDA ram_enemy_id,x  ; get enemy object identifier
    CMP #con_spiny
    BEQ FloateyPart  ; branch if spiny
    CMP #con_piranha_plant
    BEQ FloateyPart  ; branch if piranha plant
    CMP #con_hammer_bro
    BEQ GetAltOffset  ; branch elsewhere if hammer bro
    CMP #con_grey_cheep_cheep
    BEQ FloateyPart  ; branch if cheep-cheep of either color
    CMP #con_red_cheep_cheep
    BEQ FloateyPart
    CMP #con_tall_enemy
    BCS GetAltOffset  ; branch elsewhere if enemy object => $09
    LDA ram_enemy_state,x
    CMP #$02  ; if enemy state defeated or otherwise
    BCS FloateyPart  ; $02 or greater, branch beyond this part
GetAltOffset:
    LDX ram_spr_data_offset_ctrl  ; !(UNKNOWN) RAM-001 - exact allocation role
    LDY ram_alt_spr_data_offset,x  ; get alternate OAM data offset
    LDX ram_object_offset  ; get enemy object offset again
FloateyPart:
    LDA ram_floatey_num_y_pos,x  ; get vertical coordinate for
    CMP #$18  ; floatey number, if coordinate in the
    BCC SetupNumSpr  ; status bar, branch
    SBC #$01
    STA ram_floatey_num_y_pos,x  ; otherwise subtract one and store as new
SetupNumSpr:
    LDA ram_floatey_num_y_pos,x  ; get vertical coordinate
    SBC #$08  ; subtract eight and dump into the
    JSR sub_dump_two_spr  ; left and right sprite's Y coordinates
    LDA ram_floatey_num_x_pos,x  ; get horizontal coordinate
    STA ram_sprite_x_position,y  ; store into X coordinate of left sprite
    CLC
    ADC #$08  ; add eight pixels and store into X
    STA ram_sprite_x_position+4,y  ; coordinate of right sprite
    LDA #$02
    STA ram_sprite_attributes,y  ; set palette control in attribute bytes
    STA ram_sprite_attributes+4,y  ; of left and right sprites
    LDA ram_floatey_num_control,x
    ASL  ; multiply our floatey number control by 2
    TAX  ; and use as offset for look-up table
    LDA FloateyNumTileData,x
    STA ram_sprite_tilenumber,y  ; display first half of number of points
    LDA FloateyNumTileData+1,x
    STA ram_sprite_tilenumber+4,y  ; display the second half
    LDX ram_object_offset  ; get enemy object offset and leave
    RTS
