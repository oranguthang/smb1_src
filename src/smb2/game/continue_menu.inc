off_smb2_main_jump_friction_data:
    .byte $20, $20, $1e, $28, $28, $0d, $04
    .byte $70, $70, $60, $90, $90, $0a, $09

    .byte $e4, $98, $d0

    .byte $18, $18, $18, $22, $22, $0d, $04
    .byte $42, $42, $3e, $5d, $5d, $0a, $09

    .byte $b4, $68, $a0

sub_smb2_main_load_physics_data:
    LDX #$60  ; use luigi's offsets and RTS opcode
    LDY #$21
    LDA SelectedPlayer  ; if selected luigi, branch to continue
    BNE bra_smb2_main_modify_physics
sub_smb2_main_load_mario_physics:
    LDX #$0e  ; otherwise use mario's offsets and ASL opcode
    LDY #$10
bra_smb2_main_modify_physics:
    STX loc_smb2_main_phy_opcode  ; load opcode into friction code to modify it
    LDX #$10
bra_smb2_main_modify_player_physics_loop:
    LDA off_smb2_main_jump_friction_data,y  ; load physics data for the selected player
    STA off_smb2_main_jump_gravity,x
    DEY
    DEX
    BPL bra_smb2_main_modify_player_physics_loop
    RTS

; unused bytes
    .byte $ff, $ff

; -------------------------------------------------------------------------------------

; enemy data used by pipe intro area, warp zone area and exit area
off_smb2_main_ground_area_10_enemies:
off_smb2_main_ground_area_21_enemies:
off_smb2_main_e_ground_area28:
    .byte $ff

; exit area used in levels 1-2, 3-2, 5-2, 6-2, A-2 and B-2
off_smb2_main_l_ground_area28:
    .byte $90, $31, $39, $f1, $bf, $37, $33, $e7, $a3, $03, $a7, $03, $cd, $41, $0f, $a6
    .byte $ed, $47, $fd

; pipe intro area
off_smb2_main_ground_area_10_objects:
    .byte $38, $11, $0f, $26, $ad, $40, $3d, $c7, $fd

; warp zone area used in levels 1-2 and 5-2
off_smb2_main_ground_area_21_objects:
    .byte $10, $00, $0b, $13, $5b, $14, $6a, $42, $c7, $12, $c6, $42, $1b, $94, $2a, $42
    .byte $53, $13, $62, $41, $97, $17, $a6, $45, $6e, $81, $8f, $37, $02, $e8, $12, $3a
    .byte $68, $7a, $de, $0f, $6d, $c5, $fd

sub_smb2_main_load_area_pointer:
    JSR sub_smb2_main_find_area_pointer  ; find it and store it here
    STA AreaPointer
sub_smb2_main_get_area_type:
    AND #%01100000  ; mask out all but d6 and d5
    ASL
    ROL
    ROL
    ROL  ; make %0xx00000 into %000000xx
    STA AreaType  ; save 2 MSB as area type
    RTS

sub_smb2_main_find_area_pointer:
    LDY WorldNumber  ; load offset from world variable
    LDA tbl_smb2_main_world_area_pointer_offsets,y
    CLC  ; add area number used to find data
    ADC AreaNumber
    TAY
    LDA tbl_smb2_main_area_pointers,y  ; from there we have our area pointer
    RTS

sub_smb2_main_get_area_data_addresses:
    LDA AreaPointer  ; use 2 MSB for Y
    JSR sub_smb2_main_get_area_type
    TAY
    LDA AreaPointer  ; mask out all but 5 LSB
    AND #%00011111
    STA AreaAddrsLOffset  ; save as low offset
    LDA tbl_smb2_main_enemy_data_offsets_by_area_type,y  ; load base value with 2 altered MSB,
    CLC  ; then add base value to 5 LSB, result
    ADC AreaAddrsLOffset  ; becomes offset for level data
    ASL
    TAY
    LDA off_smb2_main_enemy_data_addrs+1,y  ; use offset to load pointer
    STA EnemyDataHigh
    LDA off_smb2_main_enemy_data_addrs,y
    STA EnemyDataLow
    LDY AreaType  ; use area type as offset
    LDA tbl_smb2_main_area_object_data_offsets_by_area_type,y  ; do the same thing but with different base value
    CLC
    ADC AreaAddrsLOffset
    ASL
    TAY
    LDA off_smb2_main_area_data_addrs+1,y  ; use this offset to load another pointer
    STA AreaDataHigh
    LDA off_smb2_main_area_data_addrs,y
    STA AreaDataLow
    LDY #$00  ; load first byte of header
    LDA (AreaData),y
    PHA  ; save it to the stack for now
    AND #%00000111  ; save 3 LSB for foreground scenery or bg color control
    CMP #$04
    BCC bra_smb2_main_store_foreground_scenery
    STA BackgroundColorCtrl  ; if 4 or greater, save value here as bg color control
    LDA #$00
bra_smb2_main_store_foreground_scenery:
    STA ForegroundScenery  ; if less, save value here as foreground scenery
    PLA  ; pull byte from stack and push it back
    PHA
    AND #%00111000  ; save player entrance control bits
    LSR  ; shift bits over to LSBs
    LSR
    LSR
    STA PlayerEntranceCtrl  ; save value here as player entrance control
    PLA  ; pull byte again but do not push it back
    AND #%11000000  ; save 2 MSB for game timer setting
    CLC
    ROL  ; rotate bits over to LSBs
    ROL
    ROL
    STA GameTimerSetting  ; save value here as game timer setting
    INY
    LDA (AreaData),y  ; load second byte of header
    PHA  ; save to stack
    AND #%00001111  ; mask out all but lower nybble
    STA TerrainControl
    PLA  ; pull and push byte to copy it to A
    PHA
    AND #%00110000  ; save 2 MSB for background scenery type
    LSR
    LSR  ; shift bits to LSBs
    LSR
    LSR
    STA BackgroundScenery  ; save as background scenery
    PLA
    AND #%11000000
    CLC
    ROL  ; rotate bits over to LSBs
    ROL
    ROL
    CMP #%00000011  ; if set to 3, store here
    BNE bra_smb2_main_store_area_style  ; and nullify other value
    STA CloudTypeOverride  ; otherwise store value in other place
    LDA #$00
bra_smb2_main_store_area_style:
    STA AreaStyle
    LDA AreaDataLow  ; increment area data address by 2 bytes
    CLC
    ADC #$02
    STA AreaDataLow
    LDA AreaDataHigh
    ADC #$00
    STA AreaDataHigh
    RTS

; -------------------------------------------------------------------------------------

tbl_smb2_main_world_area_pointer_offsets:
    .byte tbl_smb2_main_world_1_area_pointers-tbl_smb2_main_area_pointers, tbl_smb2_main_world_2_area_pointers-tbl_smb2_main_area_pointers
    .byte tbl_smb2_main_world_3_area_pointers-tbl_smb2_main_area_pointers, tbl_smb2_main_world_4_area_pointers-tbl_smb2_main_area_pointers
    .byte tbl_smb2_main_world_5_area_pointers-tbl_smb2_main_area_pointers, tbl_smb2_main_world_6_area_pointers-tbl_smb2_main_area_pointers
    .byte tbl_smb2_main_world_7_area_pointers-tbl_smb2_main_area_pointers, tbl_smb2_main_world_8_area_pointers-tbl_smb2_main_area_pointers
    .byte tbl_smb2_main_world9_areas-tbl_smb2_main_area_pointers

tbl_smb2_main_area_pointers:
tbl_smb2_main_world_1_area_pointers:
    .byte $20, $29, $40, $21, $60
tbl_smb2_main_world_2_area_pointers:
    .byte $22, $23, $24, $61
tbl_smb2_main_world_3_area_pointers:
    .byte $25, $29, $00, $26, $62
tbl_smb2_main_world_4_area_pointers:
    .byte $27, $28, $2a, $63
tbl_smb2_main_world_5_area_pointers:
    .byte $2b, $29, $43, $2c, $64
tbl_smb2_main_world_6_area_pointers:
    .byte $2d, $29, $01, $2e, $65
tbl_smb2_main_world_7_area_pointers:
    .byte $2f, $30, $31, $66
tbl_smb2_main_world_8_area_pointers:
    .byte $32, $35, $36, $67
tbl_smb2_main_world9_areas:
    .byte $38, $06, $68, $07

off_smb2_main_area_object_loopback_offsets:
    .byte $0c, $0c, $42, $42, $10, $10, $30, $30, $06, $0c, $54, $06

tbl_smb2_main_enemy_data_offsets_by_area_type:
    .byte $2c, $0a, $27, $00

off_smb2_main_enemy_data_addrs:
    .word off_smb2_main_castle_area_1_enemies, off_smb2_main_castle_area_2_enemies, off_smb2_main_castle_area_3_enemies, off_smb2_main_castle_area_4_enemies, off_smb2_data2_castle_area_5_enemies, off_smb2_data2_castle_area_6_enemies
    .word off_smb2_data2_e_castle_area7, off_smb2_data2_e_castle_area8, off_smb2_data3_e_castle_area9, off_smb2_data3_e_castle_area10, off_smb2_main_ground_area_1_enemies, off_smb2_main_ground_area_2_enemies
    .word off_smb2_main_ground_area_3_enemies, off_smb2_main_ground_area_4_enemies, off_smb2_main_ground_area_5_enemies, off_smb2_main_ground_area_6_enemies, off_smb2_main_ground_area_7_enemies, off_smb2_main_ground_area_8_enemies
    .word off_smb2_main_ground_area_9_enemies, off_smb2_main_ground_area_10_enemies, off_smb2_main_ground_area_11_enemies, off_smb2_data2_ground_area_12_enemies, off_smb2_data2_ground_area_13_enemies, off_smb2_data2_ground_area_14_enemies
    .word off_smb2_data2_ground_area_15_enemies, off_smb2_data2_ground_area_16_enemies, off_smb2_data2_ground_area_17_enemies, off_smb2_data2_ground_area_18_enemies, off_smb2_data2_ground_area_19_enemies, off_smb2_main_ground_area_20_enemies
    .word off_smb2_main_ground_area_21_enemies, off_smb2_data2_ground_area_22_enemies, off_smb2_data2_e_ground_area23, off_smb2_data2_e_ground_area24, off_smb2_data3_e_ground_area25, off_smb2_data3_e_ground_area26
    .word off_smb2_data3_e_ground_area27, off_smb2_main_e_ground_area28, off_smb2_data2_e_ground_area29, off_smb2_main_underground_area_1_enemies, off_smb2_main_underground_area_2_enemies
    .word off_smb2_main_underground_area_3_enemies, off_smb2_data2_e_underground_area4, off_smb2_data2_e_underground_area5, off_smb2_main_water_area_1_enemies, off_smb2_data2_water_area_2_enemies
    .word off_smb2_main_water_area_3_enemies, off_smb2_data2_e_water_area4, off_smb2_data2_e_water_area5, off_smb2_data3_e_water_area6, off_smb2_data3_e_water_area7, off_smb2_data3_e_water_area8

tbl_smb2_main_area_object_data_offsets_by_area_type:
    .byte $2c, $0a, $27, $00

off_smb2_main_area_data_addrs:
    .word off_smb2_main_castle_area_1_objects, off_smb2_main_castle_area_2_objects, off_smb2_main_castle_area_3_objects, off_smb2_main_castle_area_4_objects, off_smb2_data2_castle_area_5_objects, off_smb2_data2_castle_area_6_objects
    .word off_smb2_data2_l_castle_area7, off_smb2_data2_l_castle_area8, off_smb2_data3_l_castle_area9, off_smb2_data3_l_castle_area10, off_smb2_main_ground_area_1_objects, off_smb2_main_ground_area_2_objects
    .word off_smb2_main_ground_area_3_objects, off_smb2_main_ground_area_4_objects, off_smb2_main_ground_area_5_objects, off_smb2_main_ground_area_6_objects, off_smb2_main_ground_area_7_objects, off_smb2_main_ground_area_8_objects
    .word off_smb2_main_ground_area_9_objects, off_smb2_main_ground_area_10_objects, off_smb2_main_ground_area_11_objects, off_smb2_data2_ground_area_12_objects, off_smb2_data2_ground_area_13_objects, off_smb2_data2_ground_area_14_objects
    .word off_smb2_data2_ground_area_15_objects, off_smb2_data2_ground_area_16_objects, off_smb2_data2_ground_area_17_objects, off_smb2_data2_ground_area_18_objects, off_smb2_data2_ground_area_19_objects, off_smb2_main_ground_area_20_objects
    .word off_smb2_main_ground_area_21_objects, off_smb2_data2_ground_area_22_objects, off_smb2_data2_l_ground_area23, off_smb2_data2_l_ground_area24, off_smb2_data3_l_ground_area25, off_smb2_data3_l_ground_area26
    .word off_smb2_data3_l_ground_area27, off_smb2_main_l_ground_area28, off_smb2_data2_l_ground_area29, off_smb2_main_underground_area_1_objects, off_smb2_main_underground_area_2_objects
    .word off_smb2_main_underground_area_3_objects, off_smb2_data2_l_underground_area4, off_smb2_data2_l_underground_area5, off_smb2_main_water_area_1_objects, off_smb2_data2_water_area_2_objects
    .word off_smb2_main_water_area_3_objects, off_smb2_data2_l_water_area4, off_smb2_data2_l_water_area5, off_smb2_data3_l_water_area6, off_smb2_data3_l_water_area7, off_smb2_data3_l_water_area8

; some unused bytes
    .byte $ff, $ff

handler_smb2_main_game_menu:
    LDA SavedJoypadBits  ; check to see if the player pressed start
    AND #Start_Button
    BEQ bra_smb2_main_check_title_select_button  ; if not, branch to check other buttons
    LDA #$00
    STA CompletedWorlds
    STA DiskIOTask
    STA HardWorldFlag
    LDA tbl_smb2_main_games_beaten_count  ; check to see if player has beaten
    CMP #$08  ; the game at least 8 times
    BCC bra_smb2_main_start_selected_game  ; if not, start the game as usual at world 1
    LDA SavedJoypadBits
    AND #A_Button  ; check if the player pressed A + start
    BEQ bra_smb2_main_start_selected_game  ; if not, start the game as usual at world 1
    INC HardWorldFlag  ; otherwise start playing the letter worlds
bra_smb2_main_start_selected_game:
    JMP loc_smb2_main_start_selected_game
bra_smb2_main_check_title_select_button:
    LDA SavedJoypadBits
    CMP #Select_Button  ; branch if pressing select
    BEQ bra_smb2_main_select_logic
    LDX DemoTimer
    BNE bra_smb2_main_clear_menu_joypad
    STA SelectTimer  ; run demo after a certain period of time
    JSR sub_smb2_main_demo_engine
    BCS bra_smb2_main_reset_title_screen
    BCC bra_smb2_main_run_title_demo
bra_smb2_main_select_logic:
    LDA DemoTimer  ; if select pressed, check demo timer one last time
    BEQ bra_smb2_main_reset_title_screen  ; if demo timer expired, branch to reset attract mode
    LDA #$18  ; otherwise reset demo timer
    STA DemoTimer
    LDA FrameCounter  ; erase LSB of frame counter
    AND #$fe
    STA FrameCounter
    LDA SelectTimer  ; if select timer not expired, skip to slow select down
    BNE bra_smb2_main_clear_menu_joypad
    LDA #$10  ; reset select button timer
    STA SelectTimer
    LDA SelectedPlayer  ; switch between the two players to select one
    EOR #$01
    STA SelectedPlayer
    JSR sub_smb2_main_draw_menu_cursor
bra_smb2_main_clear_menu_joypad:
    LDA #$00
    STA SavedJoypadBits
bra_smb2_main_run_title_demo:
    JSR sub_smb2_main_game_core_routine  ; run game engine
    LDA GameEngineSubroutine  ; check to see if we're running lose life routine
    CMP #$06
    BNE bra_smb2_main_exit_game_menu  ; if not, do not do all the resetting below
bra_smb2_main_reset_title_screen:
    LDA #$00  ; reset game modes, disable
    STA OperMode  ; IRQ update and screen output
    STA OperMode_Task  ; screen output
    STA IRQUpdateFlag
    INC DisableScreenFlag
    RTS

loc_smb2_main_start_selected_game:
    LDA DemoTimer
    BEQ bra_smb2_main_reset_title_screen
    INC OperMode_Task
    JSR sub_smb2_main_patch_player_name_pal  ; patch data over based on selected player
    LDA #$00
    STA WorldNumber
    LDA #$00
    STA LevelNumber
    LDA #$00
    STA AreaNumber
    LDX #$0b
    LDA #$00
bra_smb2_main_init_score:
    STA ScoreAndCoinDisplay,x  ; clear player score and coin display
    DEX
    BPL bra_smb2_main_init_score
bra_smb2_main_exit_game_menu:
    RTS

tbl_smb2_main_menu_cursor_template:
    .byte $22, $4b, $83
    .byte $ce, $24, $24
    .byte $00

tbl_smb2_main_menu_cursor_tiles:
    .byte $ce, $24, $ce

sub_smb2_main_draw_menu_cursor:
    LDA #$1c  ; set up VRAM address controller to draw cursor
    STA VRAM_Buffer_AddrCtrl

sub_smb2_main_setup_menu_cursor:
    LDY SelectedPlayer  ; write blank and mushroom icon to template
    LDA tbl_smb2_main_menu_cursor_tiles,y  ; in the order based on selected player
    STA tbl_smb2_main_menu_cursor_template+3
    LDA tbl_smb2_main_menu_cursor_tiles+1,y  ; e.g. if mario, write mushroom, then blank
    STA tbl_smb2_main_menu_cursor_template+5  ; and if luigi, write blank, then mushroom
    RTS

off_smb2_main_demo_joypad_actions:
    .byte $01, $81, $01, $81, $01, $81, $02, $01
    .byte $81, $00, $81, $00, $80, $01, $81, $01
    .byte $00

off_smb2_main_demo_action_durations:
    .byte $b0, $10, $10, $10, $28, $10, $28, $06
    .byte $10, $10, $0c, $80, $10, $28, $08, $90
    .byte $ff, $00

sub_smb2_main_demo_engine:
    LDX DemoAction  ; load current demo action
    LDA DemoActionTimer  ; load current action timer
    BNE bra_smb2_main_apply_demo_action  ; if timer still counting down, skip
    INX
    INC DemoAction  ; if expired, increment action, X, and
    SEC  ; set carry by default for demo over
    LDA off_smb2_main_demo_action_durations-1,x  ; get next timer
    STA DemoActionTimer  ; store as current timer
    BEQ bra_smb2_main_finish_title_demo  ; if timer already at zero, skip
bra_smb2_main_apply_demo_action:
    LDA off_smb2_main_demo_joypad_actions-1,x  ; get and perform action (current or next)
    STA SavedJoypad1Bits
    DEC DemoActionTimer  ; decrement action timer
    CLC  ; clear carry if demo still going
bra_smb2_main_finish_title_demo:
    RTS

handler_smb2_main_clear_title_buffers_and_draw_icon:
    LDA OperMode  ; check game mode
    BNE bra_smb2_main_advance_operation_mode_task  ; if not attract mode, leave
    LDX #$00  ; otherwise, clear buffer space
bra_smb2_main_clear_title_screen_buffers:
    STA VRAM_Buffer1-1,x
    STA VRAM_Buffer1-1+$100,x
    DEX
    BNE bra_smb2_main_clear_title_screen_buffers
    JSR sub_smb2_main_draw_menu_cursor  ; draw player select cursor
    INC ScreenRoutineTask  ; move onto next task
    RTS

handler_smb2_main_write_title_top_score:
    LDA #$fa  ; run display routine to display top score on title
    JSR sub_smb2_main_write_digits
bra_smb2_main_advance_operation_mode_task:
    JMP bra_smb2_main_inc_mode_task

handler_smb2_main_initialize_game:
    LDA #$00
    STA CompletedWorlds  ; clean slate player's progress (except for games beaten)
    STA HardWorldFlag
    STA SelectedPlayer
    JSR sub_smb2_main_patch_player_name_pal  ; set up mario's/luigi's name and palette
    JSR sub_smb2_main_setup_menu_cursor  ; put menu cursor next to mario's name
    LDY #$33  ; set up offset in the title screen tiles
    LDA #$0c  ; set up counter to print up to 12 stars per row
    STA $00
    LDX #$00  ; init star counter
bra_smb2_main_print_stars:
    LDA #$26  ; print blank by default
    CPX tbl_smb2_main_games_beaten_count  ; check star counter against games beaten
    BCS bra_smb2_main_write_title_screen_star  ; if counted up to games beaten, print the blank
    LDA #$f1  ; otherwise print a star for a beaten game
bra_smb2_main_write_title_screen_star:
    STA off_smb2_main_title_screen_gfx_data,y  ; print to title screen
    INY
    DEC $00  ; decrement until done printing a row
    BNE bra_smb2_main_next_star_r
    LDY #$4d  ; set up offset in title screen tiles for next row
bra_smb2_main_next_star_r:
    INX
    CPX #$18  ; printed 24 tiles yet?  if not, go back
    BNE bra_smb2_main_print_stars
    LDY #$6f  ; clear all memory as in initialization procedure,
    JSR sub_smb2_main_initialize_memory  ; but this time, clear only as far as $076f
    LDY #$1f
bra_smb2_main_clear_sound_ram_loop:
    STA SoundMemory,y  ; clear out memory used
    DEY  ; by the sound engines
    BPL bra_smb2_main_clear_sound_ram_loop

handler_smb2_main_demo_reset:
    LDA #$18  ; set demo timer
    STA DemoTimer
    JSR sub_smb2_main_load_area_pointer
    JMP handler_smb2_main_initialize_area

handler_smb2_main_primary_game_setup:
    LDA #$01
    STA FetchNewGameTimerFlag  ; set flag to load game timer from header
    STA PlayerSize  ; set player's size to small
    LDA #$02
    STA NumberofLives  ; give each player three lives
    JMP handler_smb2_main_secondary_game_setup

; -------------------------------------------------------------------------------------
