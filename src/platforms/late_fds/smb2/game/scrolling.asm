sub_smb2_main_get_screen_position:
    LDA ScreenLeft_X_Pos  ; get coordinate of screen's left boundary
    CLC
    ADC #$ff  ; add 255 pixels
    STA ScreenRight_X_Pos  ; store as coordinate of screen's right boundary
    LDA ScreenLeft_PageLoc  ; get page number where left boundary is
    ADC #$00  ; add carry from before
    STA ScreenRight_PageLoc  ; store as page number where right boundary is
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_game_routines:
    LDA GameEngineSubroutine  ; run routine based on number (a few of these routines are
    JSR sub_smb2_main_dispatch_inline_handler  ; merely placeholders as conditions for other routines)

    .word handler_smb2_main_setup_entrance_and_game_timer
    .word handler_smb2_main_vine_automatic_climb
    .word handler_smb2_main_side_exit_pipe_entry
    .word handler_smb2_main_vertical_pipe_entry
    .word handler_smb2_main_flagpole_slide
    .word handler_smb2_main_player_end_level
    .word handler_smb2_main_player_lose_life
    .word handler_smb2_main_player_entrance
    .word handler_smb2_main_player_control
    .word handler_smb2_main_player_size_transition
    .word handler_smb2_main_player_injury_blink
    .word handler_smb2_main_player_death
    .word handler_smb2_main_player_fire_flower_transition

handler_smb2_main_player_entrance:
    LDA AltEntranceControl  ; check for mode of alternate entry
    CMP #$02
    BEQ bra_smb2_main_enter_from_pipe_or_vine  ; if found, branch to enter from pipe or with vine
    LDA #$00
    LDY Player_Y_Position  ; if vertical position above a certain
    CPY #$30  ; point, nullify controller bits and continue
    BCC sub_smb2_main_auto_control_player  ; with player movement code, do not return
    LDA PlayerEntranceCtrl  ; check player entry bits from header
    CMP #$06
    BEQ bra_smb2_main_check_pipe_intro  ; if set to 6 or 7, execute pipe intro code
    CMP #$07  ; otherwise branch to normal entry
    BNE bra_smb2_main_finish_player_entrance
bra_smb2_main_check_pipe_intro:
    LDA Player_SprAttrib  ; check for sprite attributes
    BNE bra_smb2_main_run_pipe_intro  ; branch if found
    LDA #$01
    JMP sub_smb2_main_auto_control_player  ; force player to walk to the right
bra_smb2_main_run_pipe_intro:
    JSR sub_smb2_main_enter_side_pipe  ; execute sub to move player to the right
    DEC ChangeAreaTimer  ; decrement timer for change of area
    BNE bra_smb2_main_exit_player_entrance  ; branch to exit if not yet expired
    INC DisableIntermediate  ; set flag to skip world and lives display
    JMP bra_smb2_main_advance_to_next_area  ; jump to increment to next area and set modes
bra_smb2_main_enter_from_pipe_or_vine:
    LDA JoypadOverride  ; if controller override bits set here,
    BNE bra_smb2_main_enter_from_vine  ; branch to enter with vine
    LDA #$ff  ; otherwise, set value here then execute sub
    JSR sub_smb2_main_move_player_y_axis  ; to move player upwards
    LDA Player_Y_Position  ; check to see if player is at a specific coordinate
    CMP #$91  ; if player risen to a certain point (this requires pipes
    BCC bra_smb2_main_finish_player_entrance  ; to be at specific height to look/function right) branch
    RTS  ; to the last part, otherwise leave
bra_smb2_main_enter_from_vine:
    LDA VineHeight
    CMP #$60  ; check vine height
    BNE bra_smb2_main_exit_player_entrance  ; if vine not yet reached maximum height, branch to leave
    LDA Player_Y_Position  ; get player's vertical coordinate
    CMP #$99  ; check player's vertical coordinate against preset value
    LDY #$00  ; load default values to be written to
    LDA #$01  ; this value moves player to the right off the vine
    BCC bra_smb2_main_auto_move_off_vine  ; if vertical coordinate < preset value, use defaults
    LDA #$03
    STA Player_State  ; otherwise set player state to climbing
    INY  ; increment value in Y
    LDA #$08  ; set block in block buffer to cover hole, then
    STA Block_Buffer_1+$b4  ; use same value to force player to climb
bra_smb2_main_auto_move_off_vine:
    STY DisableCollisionDet  ; set collision detection disable flag
    JSR sub_smb2_main_auto_control_player  ; use contents of A to move player up or right, execute sub
    LDA Player_X_Position
    CMP #$48  ; check player's horizontal position
    BCC bra_smb2_main_exit_player_entrance  ; if not far enough to the right, branch to leave
bra_smb2_main_finish_player_entrance:
    LDA #$08  ; set routine to be executed by game engine next frame
    STA GameEngineSubroutine
    LDA #$01  ; set to face player to the right
    STA PlayerFacingDir
    LSR  ; init A
    STA AltEntranceControl  ; init mode of entry
    STA DisableCollisionDet  ; init collision detection disable flag
    STA JoypadOverride  ; nullify controller override bits
bra_smb2_main_exit_player_entrance:
    RTS  ; leave!

; -------------------------------------------------------------------------------------
; $07 - used to hold upper limit of high byte when player falls down hole

sub_smb2_main_auto_control_player:
    STA SavedJoypadBits  ; override controller bits with contents of A if executing here

handler_smb2_main_player_control:
    LDA GameEngineSubroutine  ; check task here
    CMP #$0b  ; if certain value is set, branch to skip controller bit loading
    BEQ bra_smb2_main_update_player_collision_box
    LDA AreaType  ; are we in a water type area?
    BNE bra_smb2_main_split_player_input_bits  ; if not, branch
    LDY Player_Y_HighPos
    DEY  ; if not in vertical area between
    BNE bra_smb2_main_disable_player_input  ; status bar and bottom, branch
    LDA Player_Y_Position
    CMP #$d0  ; if nearing the bottom of the screen or
    BCC bra_smb2_main_split_player_input_bits  ; not in the vertical area between status bar or bottom,
bra_smb2_main_disable_player_input:
    LDA #$00  ; disable controller bits
    STA SavedJoypadBits
bra_smb2_main_split_player_input_bits:
    LDA SavedJoypadBits  ; otherwise store A and B buttons in $0a
    AND #%11000000
    STA A_B_Buttons
    LDA SavedJoypadBits  ; store left and right buttons in $0c
    AND #%00000011
    STA Left_Right_Buttons
    LDA SavedJoypadBits  ; store up and down buttons in $0b
    AND #%00001100
    STA Up_Down_Buttons
    AND #%00000100  ; check for pressing down
    BEQ bra_smb2_main_update_player_collision_box  ; if not, branch
    LDA Player_State  ; check player's state
    BNE bra_smb2_main_update_player_collision_box  ; if not on the ground, branch
    LDY Left_Right_Buttons  ; check left and right
    BEQ bra_smb2_main_update_player_collision_box  ; if neither pressed, branch
    LDA #$00
    STA Left_Right_Buttons  ; if pressing down while on the ground,
    STA Up_Down_Buttons  ; nullify directional bits
bra_smb2_main_update_player_collision_box:
    JSR sub_smb2_main_update_player_movement  ; run movement subroutines
    LDY #$01  ; is player small?
    LDA PlayerSize
    BNE bra_smb2_main_update_player_moving_direction
    LDY #$00  ; check for if crouching
    LDA CrouchingFlag
    BEQ bra_smb2_main_update_player_moving_direction  ; if not, branch ahead
    LDY #$02  ; if big and crouching, load y with 2
bra_smb2_main_update_player_moving_direction:
    STY Player_BoundBoxCtrl  ; set contents of Y as player's bounding box size control
    LDA #$01  ; set moving direction to right by default
    LDY Player_X_Speed  ; check player's horizontal speed
    BEQ bra_smb2_main_run_player_frame_subsystems  ; if not moving at all horizontally, skip this part
    BPL bra_smb2_main_store_player_moving_direction  ; if moving to the right, use default moving direction
    ASL  ; otherwise change to move to the left
bra_smb2_main_store_player_moving_direction:
    STA Player_MovingDir  ; set moving direction
bra_smb2_main_run_player_frame_subsystems:
    JSR sub_smb2_main_scroll_handler  ; move the screen if necessary
    JSR sub_smb2_main_get_player_offscreen_bits  ; get player's offscreen bits
    JSR sub_smb2_main_relative_player_position  ; get coordinates relative to the screen
    LDX #$00  ; set offset for player object
    JSR sub_smb2_main_bounding_box_core  ; get player's bounding box coordinates
    JSR sub_smb2_main_handle_player_background_collision  ; do collision detection and process
    LDA Player_Y_Position
    CMP #$40  ; check to see if player is higher than 64th pixel
    BCC bra_smb2_main_check_player_below_screen  ; if so, branch ahead
    LDA GameEngineSubroutine
    CMP #$05  ; if running end-of-level routine, branch ahead
    BEQ bra_smb2_main_check_player_below_screen
    CMP #$07  ; if running player entrance routine, branch ahead
    BEQ bra_smb2_main_check_player_below_screen
    CMP #$04  ; if running routines $00-$03, branch ahead
    BCC bra_smb2_main_check_player_below_screen
    LDA Player_SprAttrib
    AND #%11011111  ; otherwise nullify player's
    STA Player_SprAttrib  ; background priority flag
bra_smb2_main_check_player_below_screen:
    LDA Player_Y_HighPos  ; check player's vertical high byte
    CMP #$02  ; for below the screen
    BMI bra_smb2_main_exit_game_engine_control  ; branch to leave if not that far down
    LDX #$01
    STX ScrollLock  ; set scroll lock
    LDY #$04
    STY $07  ; set value here
    LDX #$00  ; use X as flag, and clear for cloud level
    LDY GameTimerExpiredFlag  ; check game timer expiration flag
    BNE bra_smb2_main_prepare_player_death  ; if set, branch
    LDY CloudTypeOverride  ; check for cloud type override
    BNE bra_smb2_main_compare_player_depth_limit  ; skip to last part if found
bra_smb2_main_prepare_player_death:
    INX  ; set flag in X for player death
    LDY GameEngineSubroutine
    CPY #$0b  ; check for some other routine running
    BEQ bra_smb2_main_compare_player_depth_limit  ; if so, branch ahead
    LDY DeathMusicLoaded  ; check value here
    BNE bra_smb2_main_set_death_depth_limit  ; if already set, branch to next part
    INY
    STY EventMusicQueue  ; otherwise play death music
    STY DeathMusicLoaded  ; and set value here
bra_smb2_main_set_death_depth_limit:
    LDY #$06
    STY $07  ; change value here
bra_smb2_main_compare_player_depth_limit:
    CMP $07  ; compare vertical high byte with value set here
    BMI bra_smb2_main_exit_game_engine_control  ; if less, branch to leave
    DEX  ; otherwise decrement flag in X
    BMI bra_smb2_main_exit_cloud_area  ; if flag was clear, branch to set modes and other values
    LDY EventMusicBuffer  ; check to see if music is still playing
    BNE bra_smb2_main_exit_game_engine_control  ; branch to leave if so
    LDA #$06  ; otherwise set to run lose life routine
    STA GameEngineSubroutine  ; on next frame
bra_smb2_main_exit_game_engine_control:
    RTS  ; leave

bra_smb2_main_exit_cloud_area:
    LDA #$00
    STA JoypadOverride  ; clear controller override bits if any are set
    JSR sub_smb2_main_setup_player_entrance  ; do sub to set secondary mode
    INC AltEntranceControl  ; set mode of entry to 3
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_vine_automatic_climb:
    LDA Player_Y_HighPos  ; check to see whether player reached position
    BNE bra_smb2_main_force_vine_climb  ; above the status bar yet and if so, set modes
    LDA Player_Y_Position
    CMP #$e4
    BCC sub_smb2_main_setup_player_entrance
bra_smb2_main_force_vine_climb:
    LDA #%00001000  ; set controller bits override to up
    STA JoypadOverride
    LDY #$03  ; set player state to climbing
    STY Player_State
    JMP sub_smb2_main_auto_control_player
sub_smb2_main_setup_player_entrance:
    LDA #$02  ; set starting position to override
    STA AltEntranceControl
    JMP sub_smb2_main_change_area_mode  ; set modes

; -------------------------------------------------------------------------------------

handler_smb2_main_vertical_pipe_entry:
    LDA #$01  ; set 1 as movement amount
    JSR sub_smb2_main_move_player_y_axis  ; do sub to move player downwards
    JSR sub_smb2_main_scroll_handler  ; do sub to scroll screen with saved force if necessary
    LDY #$00  ; load default mode of entry
    LDA WarpZoneControl  ; check warp zone control variable/flag
    BNE bra_smb2_main_finish_pipe_area_change  ; if set, branch to use mode 0
    INY
    LDA AreaType  ; check for castle level type
    CMP #$03
    BNE bra_smb2_main_finish_pipe_area_change  ; if not castle type level, use mode 1
    INY
    JMP bra_smb2_main_finish_pipe_area_change  ; otherwise use mode 2

sub_smb2_main_move_player_y_axis:
    CLC
    ADC Player_Y_Position  ; add contents of A to player position
    STA Player_Y_Position
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_side_exit_pipe_entry:
    JSR sub_smb2_main_enter_side_pipe  ; execute sub to move player to the right
    LDY #$02
bra_smb2_main_finish_pipe_area_change:
    DEC ChangeAreaTimer  ; decrement timer for change of area
    BNE bra_smb2_main_exit_pipe_area_change
    STY AltEntranceControl  ; when timer expires set mode of alternate entry
sub_smb2_main_change_area_mode:
    INC DisableScreenFlag  ; set flag to disable screen output
    LDA #$00
    STA OperMode_Task  ; set secondary mode of operation
    STA IRQUpdateFlag  ; disable sprite 0 check
bra_smb2_main_exit_pipe_area_change:
    RTS  ; leave

sub_smb2_main_enter_side_pipe:
    LDA #$08  ; set player's horizontal speed
    STA Player_X_Speed
    LDY #$01  ; set controller right button by default
    LDA Player_X_Position  ; mask out higher nybble of player's
    AND #%00001111  ; horizontal position
    BNE bra_smb2_main_apply_side_pipe_control
    STA Player_X_Speed  ; if lower nybble = 0, set as horizontal speed
    TAY  ; and nullify controller bit override here
bra_smb2_main_apply_side_pipe_control:
    TYA  ; use contents of Y to
    JSR sub_smb2_main_auto_control_player  ; execute player control routine with ctrl bits nulled
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_player_size_transition:
    LDA TimerControl  ; check master timer control
    CMP #$f8  ; for specific moment in time
    BNE bra_smb2_main_check_size_change_completion  ; branch if before or after that point
    JMP loc_smb2_main_finish_player_size_transition  ; otherwise run code to get growing/shrinking going
bra_smb2_main_check_size_change_completion:
    CMP #$c4  ; check again for another specific moment
    BNE bra_smb2_main_exit_size_change  ; and branch to leave if before or after that point
    JSR sub_smb2_main_done_player_task  ; otherwise do sub to init timer control and set routine
bra_smb2_main_exit_size_change:
    RTS  ; and then leave

; -------------------------------------------------------------------------------------

handler_smb2_main_player_injury_blink:
    LDA TimerControl  ; check master timer control
    CMP #$f0  ; for specific moment in time
    BCS bra_smb2_main_exit_player_blink  ; branch if before that point
    CMP #$c8  ; check again for another specific point
    BEQ sub_smb2_main_done_player_task  ; branch if at that point, and not before or after
    JMP handler_smb2_main_player_control  ; otherwise run player control routine
bra_smb2_main_exit_player_blink:
    BNE bra_smb2_main_exit_player_transition  ; do unconditional branch to leave

loc_smb2_main_finish_player_size_transition:
    LDY PlayerChangeSizeFlag  ; if growing/shrinking flag already set
    BNE bra_smb2_main_exit_player_transition  ; then branch to leave
    STY PlayerAnimCtrl  ; otherwise initialize player's animation frame control
    INC PlayerChangeSizeFlag  ; set growing/shrinking flag
    LDA PlayerSize
    EOR #$01  ; invert player's size
    STA PlayerSize
bra_smb2_main_exit_player_transition:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00 - used in CyclePlayerPalette to store current palette to cycle

handler_smb2_main_player_death:
    LDA TimerControl  ; check master timer control
    CMP #$f0  ; for specific moment in time
    BCS bra_smb2_main_exit_player_death_handler  ; branch to leave if before that point
    JMP handler_smb2_main_player_control  ; otherwise run player control routine

sub_smb2_main_done_player_task:
    LDA #$00
    STA TimerControl  ; initialize master timer control to continue timers
    LDA #$08
    STA GameEngineSubroutine  ; set player control routine to run next frame
    RTS  ; leave

handler_smb2_main_player_fire_flower_transition:
    LDA TimerControl  ; check master timer control
    CMP #$c0  ; for specific moment in time
    BEQ bra_smb2_main_reset_fire_flower_palette_cycle  ; branch if at moment, not before or after
    LDA FrameCounter  ; get frame counter
    LSR
    LSR  ; divide by four to change every four frames

sub_smb2_main_cycle_player_palette:
    AND #$03  ; mask out all but d1-d0 (previously d3-d2)
    STA $00  ; store result here to use as palette bits
    LDA Player_SprAttrib  ; get player attributes
    AND #%11111100  ; save any other bits but palette bits
    ORA $00  ; add palette bits
    STA Player_SprAttrib  ; store as new player attributes
    RTS  ; and leave

bra_smb2_main_reset_fire_flower_palette_cycle:
    JSR sub_smb2_main_done_player_task  ; do sub to init timer control and run player control routine

sub_smb2_main_reset_star_palette_cycle:
    LDA Player_SprAttrib  ; get player attributes
    AND #%11111100  ; mask out palette bits to force palette 0
    STA Player_SprAttrib  ; store as new player attributes
bra_smb2_main_exit_player_death_handler:
    RTS  ; and leave

; -------------------------------------------------------------------------------------

handler_smb2_main_flagpole_slide:
    LDA Enemy_ID+5  ; check special use enemy slot
    CMP #FlagpoleFlagObject  ; for flagpole flag object
    BNE bra_smb2_main_handle_missing_flagpole_object  ; if not found, branch to something residual
    LDA FlagpoleSoundQueue  ; load flagpole sound
    STA Square1SoundQueue  ; into square 1's sfx queue
    LDA #$00
    STA FlagpoleSoundQueue  ; init flagpole sound queue
    LDY Player_Y_Position
    CPY #$9e  ; check to see if player has slid down
    BCS bra_smb2_main_slide_player_to_castle_exit  ; far enough, and if so, branch with no controller bits set
    LDA #$04  ; otherwise force player to climb down (to slide)
bra_smb2_main_slide_player_to_castle_exit:
    JMP sub_smb2_main_auto_control_player  ; jump to player control routine
bra_smb2_main_handle_missing_flagpole_object:
    INC GameEngineSubroutine  ; increment to next routine (this may
    RTS  ; be residual code)

; -------------------------------------------------------------------------------------

handler_smb2_main_player_end_level:
    LDA #$01  ; force player to walk to the right
    JSR sub_smb2_main_auto_control_player
    LDA Player_Y_Position  ; check player's vertical position
    CMP #$ae
    BCC bra_smb2_main_check_player_end_level_stop  ; if player is not yet off the flagpole, skip this part
    LDA #$00
    STA ScrollLock  ; reactivate scroll
    LDA FlagpoleMusicFlag  ; check flag to see if music was already queued
    BNE bra_smb2_main_check_player_end_level_stop  ; if so, skip this
    LDA #EndOfLevelMusic
    STA EventMusicQueue  ; load win level music in event music queue
    INC FlagpoleMusicFlag  ; set flag to keep music from getting queued more than once
bra_smb2_main_check_player_end_level_stop:
    LDA Player_CollisionBits  ; get player collision bits
    LSR  ; check for d0 set
    BCS bra_smb2_main_check_end_level_task_complete  ; if d0 set, skip to next part
    LDA StarFlagTaskControl  ; if star flag task control already set,
    BNE bra_smb2_main_finish_castle_end_level_walk  ; go ahead with the rest of the code
    INC StarFlagTaskControl  ; otherwise set task control now (this gets ball rolling!)
bra_smb2_main_finish_castle_end_level_walk:
    LDA #%00100000  ; set player's background priority bit to
    STA Player_SprAttrib  ; give illusion of being inside the castle
bra_smb2_main_check_end_level_task_complete:
    LDA StarFlagTaskControl
    CMP #$05  ; if star flag task control not yet set
    BNE bra_smb2_main_exit_next_area  ; beyond last valid task number, branch to leave
    INC LevelNumber  ; increment level number used for game logic
    LDA LevelNumber
    CMP #$03  ; check to see if we have yet reached level -4
    BNE bra_smb2_main_advance_to_next_area  ; and skip this last part here if not
    LDY WorldNumber  ; get world number as offset
    LDA CoinTallyFor1Ups  ; check third area coin tally for bonus 1-ups
    CMP #$0a  ; against minimum value, if player has not collected
    BCC bra_smb2_main_advance_to_next_area  ; at least this number of coins, leave flag clear
    INC Hidden1UpFlag  ; otherwise set hidden 1-up box control flag
bra_smb2_main_advance_to_next_area:
    INC AreaNumber  ; increment area number used for address loader
    LDA WorldNumber
    CMP #$08
    BNE bra_smb2_main_not_w9  ; if not at end of world 9-4, branch
    LDA LevelNumber  ; otherwise reset level and area numbers properly
    CMP #$04
    BNE bra_smb2_main_not_w9
    LDA #$00
    STA LevelNumber
    STA AreaNumber
bra_smb2_main_not_w9:
    JSR sub_smb2_main_load_area_pointer  ; get new level pointer
    INC FetchNewGameTimerFlag  ; set flag to load new game timer
    JSR sub_smb2_main_change_area_mode  ; do sub to set secondary mode, disable screen and sprite 0
    STA HalfwayPage  ; reset halfway page to 0 (beginning)
    LDA #Silence
    STA EventMusicQueue  ; silence music and leave
bra_smb2_main_exit_next_area:
    RTS

; -------------------------------------------------------------------------------------
