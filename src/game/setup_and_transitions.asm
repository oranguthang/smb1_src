; -------------------------------------------------------------------------------------

DefaultSprOffsets:
    .byte $04, $30, $48, $60, $78, $90, $a8, $c0
    .byte $d8, $e8, $24, $f8, $fc, $28, $2c

Sprite0Data:
    .byte $18, $ff, $23, $58

; -------------------------------------------------------------------------------------

InitializeGame:
    LDY #$6f  ; clear all memory as in initialization procedure,
    JSR sub_initialize_memory  ; but this time, clear only as far as $076f
    LDY #$1f
ClrSndLoop:
    STA ram_sound_memory,y  ; clear out memory used
    DEY  ; by the sound engines
    BPL ClrSndLoop
    LDA #$18  ; set demo timer
    STA ram_demo_timer
    JSR sub_load_area_pointer

InitializeArea:
    LDY #$4b  ; clear all memory again, only as far as $074b
    JSR sub_initialize_memory  ; this is only necessary if branching from
    LDX #$21
    LDA #$00
ClrTimersLoop:
    STA ram_timers,x  ; clear out memory between
    DEX  ; $0780 and $07a1
    BPL ClrTimersLoop
    LDA ram_halfway_page
    LDY ram_alt_entrance_control  ; if ram_alt_entrance_control not set, use halfway page, if any found
    BEQ StartPage
    LDA ram_entrance_page  ; otherwise use saved entry page number here
StartPage:
    STA ram_screen_left_page_loc  ; set as value here
    STA ram_current_page_loc  ; also set as current page
    STA ram_backloading_flag  ; set flag here if halfway page or saved entry page number found
    JSR sub_get_screen_position  ; get pixel coordinates for screen borders
    LDY #$20  ; if on odd numbered page, use $2480 as start of rendering
    AND #%00000001  ; otherwise use $2080, this address used later as name table
    BEQ SetInitNTHigh  ; address for rendering of game area
    LDY #$24
SetInitNTHigh:
    STY ram_current_nt_addr_high  ; store name table address
    LDY #$80
    STY ram_current_nt_addr_low
    ASL  ; store LSB of page number in high nybble
    ASL  ; of block buffer column position
    ASL
    ASL
    STA ram_block_buffer_column_pos
    DEC ram_area_object_length  ; set area object lengths for all empty
    DEC ram_area_object_length+1
    DEC ram_area_object_length+2
    LDA #$0b  ; set value for renderer to update 12 column sets
    STA ram_column_sets  ; 12 column sets = 24 metatile columns = 1 1/2 screens
    JSR sub_get_area_data_addrs  ; get enemy and level addresses and load header
    LDA ram_primary_hard_mode  ; check to see if primary hard mode has been activated
    BNE SetSecHard  ; if so, activate the secondary no matter where we're at
    LDA ram_world_number  ; otherwise check world number
    CMP #con_world5  ; if less than 5, do not activate secondary
    BCC CheckHalfway
    BNE SetSecHard  ; if not equal to, then world > 5, thus activate
    LDA ram_level_number  ; otherwise, world 5, so check level number
    CMP #con_level3  ; if 1 or 2, do not set secondary hard mode flag
    BCC CheckHalfway
SetSecHard:
    INC ram_secondary_hard_mode  ; set secondary hard mode flag for areas 5-3 and beyond
CheckHalfway:
    LDA ram_halfway_page
    BEQ DoneInitArea
    LDA #$02  ; if halfway page set, overwrite start position from header
    STA ram_player_entrance_ctrl
DoneInitArea:
    LDA #con_silence  ; silence music
    STA ram_area_music_queue
    LDA #$01  ; disable screen output
    STA ram_disable_screen_flag
    INC ram_oper_mode_task  ; increment one of the modes
    RTS

; -------------------------------------------------------------------------------------

PrimaryGameSetup:
    LDA #$01
    STA ram_fetch_new_game_timer_flag  ; set flag to load game timer from header
    STA ram_player_size  ; set player's size to small
    LDA #$02
    STA ram_numberof_lives  ; give each player three lives
    STA ram_off_scr_numberof_lives

SecondaryGameSetup:
    LDA #$00
    STA ram_disable_screen_flag  ; enable screen output
    TAY
ClearVRLoop:
    STA ram_vram_buffer1-1,y  ; clear buffer at $0300-$03ff
    INY
    BNE ClearVRLoop
    STA ram_game_timer_expired_flag  ; clear game timer exp flag
    STA ram_disable_intermediate  ; clear skip lives display flag
    STA ram_backloading_flag  ; clear value here
    LDA #$ff
    STA ram_bal_platform_alignment  ; initialize balance platform assignment flag
    LDA ram_screen_left_page_loc  ; get left side page location
    LSR ram_mirror_ppu_ctrl_reg1  ; shift LSB of ppu register #1 mirror out
    AND #$01  ; mask out all but LSB of page location
    ROR  ; rotate LSB of page location into carry then onto mirror
    ROL ram_mirror_ppu_ctrl_reg1  ; this is to set the proper PPU name table
    JSR sub_get_area_music  ; load proper music into queue
    LDA #$38  ; load sprite shuffle amounts to be used later
    STA ram_spr_shuffle_amt+2
    LDA #$48
    STA ram_spr_shuffle_amt+1
    LDA #$58
    STA ram_spr_shuffle_amt
    LDX #$0e  ; load default OAM offsets into $06e4-$06f2
ShufAmtLoop:
    LDA DefaultSprOffsets,x
    STA ram_spr_data_offset,x
    DEX  ; do this until they're all set
    BPL ShufAmtLoop
    LDY #$03  ; set up sprite #0
ISpr0Loop:
    LDA Sprite0Data,y
    STA ram_sprite_data,y
    DEY
    BPL ISpr0Loop
    JSR sub_do_nothing2  ; these jsrs doesn't do anything useful
    JSR sub_do_nothing1
    INC ram_sprite0_hit_detect_flag  ; set sprite #0 check flag
    INC ram_oper_mode_task  ; increment to next task
    RTS

; -------------------------------------------------------------------------------------

; $06 - RAM address low
; $07 - RAM address high

sub_initialize_memory:
    LDX #$07  ; set initial high byte to $0700-$07ff
    LDA #$00  ; set initial low byte to start of page (at $00 of page)
    STA $06
InitPageLoop:
    STX $07
InitByteLoop:
    CPX #$01  ; check to see if we're on the stack ($0100-$01ff)
    BNE InitByte  ; if not, go ahead anyway
    CPY #$60  ; otherwise, check to see if we're at $0160-$01ff
    BCS SkipByte  ; if so, skip write
InitByte:
    STA ($06),y  ; otherwise, initialize byte with current low byte in Y
SkipByte:
    DEY
    CPY #$ff  ; do this until all bytes in page have been erased
    BNE InitByteLoop
    DEX  ; go onto the next page
    BPL InitPageLoop  ; do this until all pages of memory have been erased
    RTS

; -------------------------------------------------------------------------------------

MusicSelectData:
    .byte con_water_music, con_ground_music, con_underground_music, con_castle_music
    .byte con_cloud_music, con_pipe_intro_music

sub_get_area_music:
    LDA ram_oper_mode  ; if in title screen mode, leave
    BEQ ExitGetM
    LDA ram_alt_entrance_control  ; check for specific alternate mode of entry
    CMP #$02  ; if found, branch without checking starting position
    BEQ ChkAreaType  ; from area object data header
    LDY #$05  ; select music for pipe intro scene by default
    LDA ram_player_entrance_ctrl  ; check value from level header for certain values
    CMP #$06
    BEQ StoreMusic  ; load music for pipe intro scene if header
    CMP #$07  ; start position either value $06 or $07
    BEQ StoreMusic
ChkAreaType:
    LDY ram_area_type  ; load area type as offset for music bit
    LDA ram_cloud_type_override
    BEQ StoreMusic  ; check for cloud type override
    LDY #$04  ; select music for cloud type level if found
StoreMusic:
    LDA MusicSelectData,y  ; otherwise select appropriate music for level type
    STA ram_area_music_queue  ; store in queue and leave
ExitGetM:
    RTS

; -------------------------------------------------------------------------------------

PlayerStarting_X_Pos:
    .byte $28, $18
    .byte $38, $28

AltYPosOffset:
    .byte $08, $00

PlayerStarting_Y_Pos:
    .byte $00, $20, $b0, $50, $00, $00, $b0, $b0
    .byte $f0

PlayerBGPriorityData:
    .byte $00, $20, $00, $00, $00, $00, $00, $00

GameTimerData:
    .byte $20  ; dummy byte, used as part of bg priority data
    .byte $04, $03, $02

Entrance_GameTimerSetup:
    LDA ram_screen_left_page_loc  ; set current page for area objects
    STA ram_player_page_loc  ; as page location for player
    LDA #$28  ; store value here
    STA ram_vertical_force_down  ; for fractional movement downwards if necessary
    LDA #$01  ; set high byte of player position and
    STA ram_player_facing_dir  ; set facing direction so that player faces right
    STA ram_player_y_high_pos
    LDA #$00  ; set player state to on the ground by default
    STA ram_player_state
    DEC ram_player_collision_bits  ; initialize player's collision bits
    LDY #$00  ; initialize halfway page
    STY ram_halfway_page
    LDA ram_area_type  ; check area type
    BNE ChkStPos  ; if water type, set swimming flag, otherwise do not set
    INY
ChkStPos:
    STY ram_swimming_flag
    LDX ram_player_entrance_ctrl  ; get starting position loaded from header
    LDY ram_alt_entrance_control  ; check alternate mode of entry flag for 0 or 1
    BEQ SetStPos
    CPY #$01
    BEQ SetStPos
    LDX AltYPosOffset-2,y  ; if not 0 or 1, override $0710 with new offset in X
SetStPos:
    LDA PlayerStarting_X_Pos,y  ; load appropriate horizontal position
    STA ram_player_x_position  ; and vertical positions for the player, using
    LDA PlayerStarting_Y_Pos,x  ; ram_alt_entrance_control as offset for horizontal and either $0710
    STA ram_player_y_position  ; or value that overwrote $0710 as offset for vertical
    LDA PlayerBGPriorityData,x
    STA ram_player_spr_attrib  ; set player sprite attributes using offset in X
    JSR sub_get_player_colors  ; get appropriate player palette
    LDY ram_game_timer_setting  ; get timer control value from header
    BEQ ChkOverR  ; if set to zero, branch (do not use dummy byte for this)
    LDA ram_fetch_new_game_timer_flag  ; do we need to set the game timer? if not, use
    BEQ ChkOverR  ; old game timer setting
    LDA GameTimerData,y  ; if game timer is set and game timer flag is also set,
    STA ram_game_timer_display  ; use value of game timer control for first digit of game timer
    LDA #$01
    STA ram_game_timer_display+2  ; set last digit of game timer to 1
    LSR
    STA ram_game_timer_display+1  ; set second digit of game timer
    STA ram_fetch_new_game_timer_flag  ; clear flag for game timer reset
    STA ram_star_invincible_timer  ; clear star mario timer
ChkOverR:
    LDY ram_joypad_override  ; if controller bits not set, branch to skip this part
    BEQ ChkSwimE
    LDA #$03  ; set player state to climbing
    STA ram_player_state
    LDX #$00  ; set offset for first slot, for block object
    JSR sub_init_block_xy_pos
    LDA #$f0  ; set vertical coordinate for block object
    STA ram_block_y_position
    LDX #$05  ; set offset in X for last enemy object buffer slot
    LDY #$00  ; set offset in Y for object coordinates used earlier
    JSR sub_setup_vine  ; do a sub to grow vine
ChkSwimE:
    LDY ram_area_type  ; if level not water-type,
    BNE SetPESub  ; skip this subroutine
    JSR sub_setup_bubble  ; otherwise, execute sub to set up air bubbles
SetPESub:
    LDA #$07  ; set to run player entrance subroutine
    STA ram_game_engine_subroutine  ; on the next frame of game engine
    RTS

; -------------------------------------------------------------------------------------

; page numbers are in order from -1 to -4
HalfwayPageNybbles:
    .byte $56, $40
    .byte $65, $70
    .byte $66, $40
    .byte $66, $40
    .byte $66, $40
    .byte $66, $60
    .byte $65, $70
    .byte $00, $00

PlayerLoseLife:
    INC ram_disable_screen_flag  ; disable screen and sprite 0 check
    LDA #$00
    STA ram_sprite0_hit_detect_flag
    LDA #con_silence  ; silence music
    STA ram_event_music_queue
    DEC ram_numberof_lives  ; take one life from player
    BPL StillInGame  ; if player still has lives, branch
    LDA #$00
    STA ram_oper_mode_task  ; initialize mode task,
    LDA #con_mode_game_over  ; switch to game over mode
    STA ram_oper_mode  ; and leave
    RTS
StillInGame:
    LDA ram_world_number  ; multiply world number by 2 and use
    ASL  ; as offset
    TAX
    LDA ram_level_number  ; if in area -3 or -4, increment
    AND #$02  ; offset by one byte, otherwise
    BEQ GetHalfway  ; leave offset alone
    INX
GetHalfway:
    LDY HalfwayPageNybbles,x  ; get halfway page number with offset
    LDA ram_level_number  ; check area number's LSB
    LSR
    TYA  ; if in area -2 or -4, use lower nybble
    BCS MaskHPNyb
    LSR  ; move higher nybble to lower if area
    LSR  ; number is -1 or -3
    LSR
    LSR
MaskHPNyb:
    AND #%00001111  ; mask out all but lower nybble
    CMP ram_screen_left_page_loc
    BEQ SetHalfway  ; left side of screen must be at the halfway page,
    BCC SetHalfway  ; otherwise player must start at the
    LDA #$00  ; beginning of the level
SetHalfway:
    STA ram_halfway_page  ; store as halfway page for player
    JSR sub_transpose_players  ; switch players around if 2-player game
    JMP ContinueGame  ; continue the game

; -------------------------------------------------------------------------------------

GameOverMode:
    LDA ram_oper_mode_task
    JSR sub_dispatch_inline_handler

    .word SetupGameOver
    .word ScreenRoutines
    .word RunGameOver

; -------------------------------------------------------------------------------------

SetupGameOver:
    LDA #$00  ; reset screen routine task control for title screen, game,
    STA ram_screen_routine_task  ; and game over modes
    STA ram_sprite0_hit_detect_flag  ; disable sprite 0 check
    LDA #con_game_over_music
    STA ram_event_music_queue  ; put game over music in secondary queue
    INC ram_disable_screen_flag  ; disable screen output
    INC ram_oper_mode_task  ; set secondary mode to 1
    RTS

; -------------------------------------------------------------------------------------

RunGameOver:
    LDA #$00  ; reenable screen
    STA ram_disable_screen_flag
    LDA ram_saved_joypad1_bits  ; check controller for start pressed
    AND #con_btn_start
    BNE sub_terminate_game
    LDA ram_screen_timer  ; if not pressed, wait for
    BNE GameIsOn  ; screen timer to expire
sub_terminate_game:
    LDA #con_silence  ; silence music
    STA ram_event_music_queue
    JSR sub_transpose_players  ; check if other player can keep
    BCC ContinueGame  ; going, and do so if possible
    LDA ram_world_number  ; otherwise put world number of current
    STA ram_continue_world  ; player into secret continue function variable
    LDA #$00
    ASL  ; residual ASL instruction
    STA ram_oper_mode_task  ; reset all modes to title screen and
    STA ram_screen_timer  ; leave
    STA ram_oper_mode
    RTS

ContinueGame:
    JSR sub_load_area_pointer  ; update level pointer with
    LDA #$01  ; actual world and area numbers, then
    STA ram_player_size  ; reset player's size, status, and
    INC ram_fetch_new_game_timer_flag  ; set game timer flag to reload
    LDA #$00  ; game timer from header
    STA ram_timer_control  ; also set flag for timers to count again
    STA ram_player_status
    STA ram_game_engine_subroutine  ; reset task for game core
    STA ram_oper_mode_task  ; set modes and leave
    LDA #$01  ; if in game over mode, switch back to
    STA ram_oper_mode  ; game mode, because game is still on
GameIsOn:
    RTS

sub_transpose_players:
    SEC  ; set carry flag by default to end game
    LDA ram_number_of_players  ; if only a 1 player game, leave
    BEQ ExTrans
    LDA ram_off_scr_numberof_lives  ; does offscreen player have any lives left?
    BMI ExTrans  ; branch if not
    LDA ram_current_player  ; invert bit to update
    EOR #%00000001  ; which player is on the screen
    STA ram_current_player
    LDX #$06
TransLoop:
    LDA ram_onscreen_player_info,x  ; transpose the information
    PHA  ; of the onscreen player
    LDA ram_offscreen_player_info,x  ; with that of the offscreen player
    STA ram_onscreen_player_info,x
    PLA
    STA ram_offscreen_player_info,x
    DEX
    BPL TransLoop
    CLC  ; clear carry flag to get game going
ExTrans:
    RTS

; -------------------------------------------------------------------------------------

sub_do_nothing1:
    LDA #$ff  ; this is residual code, this value is
    STA $06c9  ; not used anywhere in the program
sub_do_nothing2:
    RTS
