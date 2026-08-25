; -------------------------------------------------------------------------------------
; $04-$05 - used to store name table address in little endian order

BridgeCollapseData:
    .byte $1a  ; axe
    .byte $58  ; chain
    .byte $98, $96, $94, $92, $90, $8e, $8c  ; bridge
    .byte $8a, $88, $86, $84, $82, $80

BridgeCollapse:
    LDX ram_bowser_front_offset  ; get enemy offset for bowser
    LDA ram_enemy_id,x  ; check enemy object identifier for bowser
    CMP #con_bowser  ; if not found, branch ahead,
    BNE SetM2  ; metatile removal not necessary
    STX ram_object_offset  ; store as enemy offset here
    LDA ram_enemy_state,x  ; if bowser in normal state, skip all of this
    BEQ RemoveBridge
    AND #%01000000  ; if bowser's state has d6 clear, skip to silence music
    BEQ SetM2
    LDA ram_enemy_y_position,x  ; check bowser's vertical coordinate
    CMP #$e0  ; if bowser not yet low enough, skip this part ahead
    BCC MoveD_Bowser
SetM2:
    LDA #con_silence  ; silence music
    STA ram_event_music_queue
    INC ram_oper_mode_task  ; move onto next secondary mode in autoctrl mode
    JMP sub_kill_all_enemies  ; jump to empty all enemy slots and then leave

MoveD_Bowser:
    JSR sub_move_enemy_downward_slow  ; do a sub to move bowser downwards
    JMP BowserGfxHandler  ; jump to draw bowser's front and rear, then leave

RemoveBridge:
    DEC ram_bowser_feet_counter  ; decrement timer to control bowser's feet
    BNE NoBFall  ; if not expired, skip all of this
    LDA #$04
    STA ram_bowser_feet_counter  ; otherwise, set timer now
    LDA ram_bowser_body_controls
    EOR #$01  ; invert bit to control bowser's feet
    STA ram_bowser_body_controls
    LDA #$22  ; put high byte of name table address here for now
    STA $05
    LDY ram_bridge_collapse_offset  ; get bridge collapse offset here
    LDA BridgeCollapseData,y  ; load low byte of name table address and store here
    STA $04
    LDY ram_vram_buffer1_offset  ; increment vram buffer offset
    INY
    LDX #$0c  ; set offset for tile data for sub to draw blank metatile
    JSR sub_rem_bridge  ; do sub here to remove bowser's bridge metatiles
    LDX ram_object_offset  ; get enemy offset
    JSR sub_move_v_offset  ; set new vram buffer offset
    LDA #con_sfx_blast  ; load the fireworks/gunfire sound into the square 2 sfx
    STA ram_square2_sound_queue  ; queue while at the same time loading the brick
    LDA #con_sfx_brick_shatter  ; shatter sound into the noise sfx queue thus
    STA ram_noise_sound_queue  ; producing the unique sound of the bridge collapsing
    INC ram_bridge_collapse_offset  ; increment bridge collapse offset
    LDA ram_bridge_collapse_offset
    CMP #$0f  ; if bridge collapse offset has not yet reached
    BNE NoBFall  ; the end, go ahead and skip this part
    JSR sub_init_v_stf  ; initialize whatever vertical speed bowser has
    LDA #%01000000
    STA ram_enemy_state,x  ; set bowser's state to one of defeated states (d6 set)
    LDA #con_sfx_bowser_fall
    STA ram_square2_sound_queue  ; play bowser defeat sound
NoBFall:
    JMP BowserGfxHandler  ; jump to code that draws bowser

; --------------------------------

PRandomRange:
    .byte $21, $41, $11, $31

RunBowser:
    LDA ram_enemy_state,x  ; if d5 in enemy state is not set
    AND #%00100000  ; then branch elsewhere to run bowser
    BEQ BowserControl
    LDA ram_enemy_y_position,x  ; otherwise check vertical position
    CMP #$e0  ; if above a certain point, branch to move defeated bowser
    BCC MoveD_Bowser  ; otherwise proceed to sub_kill_all_enemies

sub_kill_all_enemies:
    LDX #$04  ; start with last enemy slot
KillLoop:
    JSR sub_erase_enemy_object  ; branch to kill enemy objects
    DEX  ; move onto next enemy slot
    BPL KillLoop  ; do this until all slots are emptied
    STA ram_enemy_frenzy_buffer  ; empty frenzy buffer
    LDX ram_object_offset  ; get enemy object offset and leave
    RTS

BowserControl:
    LDA #$00
    STA ram_enemy_frenzy_buffer  ; empty frenzy buffer
    LDA ram_timer_control  ; if master timer control not set,
    BEQ ChkMouth  ; skip jump and execute code here
    JMP SkipToFB  ; otherwise, jump over a bunch of code
ChkMouth:
    LDA ram_bowser_body_controls  ; check bowser's mouth
    BPL FeetTmr  ; if bit clear, go ahead with code here
    JMP HammerChk  ; otherwise skip a whole section starting here
FeetTmr:
    DEC ram_bowser_feet_counter  ; decrement timer to control bowser's feet
    BNE ResetMDr  ; if not expired, skip this part
    LDA #$20  ; otherwise, reset timer
    STA ram_bowser_feet_counter
    LDA ram_bowser_body_controls  ; and invert bit used
    EOR #%00000001  ; to control bowser's feet
    STA ram_bowser_body_controls
ResetMDr:
    LDA ram_frame_counter  ; check frame counter
    AND #%00001111  ; if not on every sixteenth frame, skip
    BNE B_FaceP  ; ahead to continue code
    LDA #$02  ; otherwise reset moving/facing direction every
    STA ram_enemy_moving_dir,x  ; sixteen frames
B_FaceP:
    LDA ram_enemy_frame_timer,x  ; if timer set here expired,
    BEQ GetPRCmp  ; branch to next section
    JSR sub_player_enemy_diff  ; get horizontal difference between player and bowser,
    BPL GetPRCmp  ; and branch if bowser to the right of the player
    LDA #$01
    STA ram_enemy_moving_dir,x  ; set bowser to move and face to the right
    LDA #$02
    STA ram_bowser_movement_speed  ; set movement speed
    LDA #$20
    STA ram_enemy_frame_timer,x  ; set timer here
    STA ram_bowser_fire_breath_timer  ; set timer used for bowser's flame
    LDA ram_enemy_x_position,x
    CMP #$c8  ; if bowser to the right past a certain point,
    BCS HammerChk  ; skip ahead to some other section
GetPRCmp:
    LDA ram_frame_counter  ; get frame counter
    AND #%00000011
    BNE HammerChk  ; execute this code every fourth frame, otherwise branch
    LDA ram_enemy_x_position,x
    CMP ram_bowser_orig_x_pos  ; if bowser not at original horizontal position,
    BNE GetDToO  ; branch to skip this part
    LDA ram_pseudo_random_bit_reg,x
    AND #%00000011  ; get pseudorandom offset
    TAY
    LDA PRandomRange,y  ; load value using pseudorandom offset
    STA ram_max_range_from_origin  ; and store here
GetDToO:
    LDA ram_enemy_x_position,x
    CLC  ; add movement speed to bowser's horizontal
    ADC ram_bowser_movement_speed  ; coordinate and save as new horizontal position
    STA ram_enemy_x_position,x
    LDY ram_enemy_moving_dir,x
    CPY #$01  ; if bowser moving and facing to the right, skip ahead
    BEQ HammerChk
    LDY #$ff  ; set default movement speed here (move left)
    SEC  ; get difference of current vs. original
    SBC ram_bowser_orig_x_pos  ; horizontal position
    BPL CompDToO  ; if current position to the right of original, skip ahead
    EOR #$ff
    CLC  ; get two's compliment
    ADC #$01
    LDY #$01  ; set alternate movement speed here (move right)
CompDToO:
    CMP ram_max_range_from_origin  ; compare difference with pseudorandom value
    BCC HammerChk  ; if difference < pseudorandom value, leave speed alone
    STY ram_bowser_movement_speed  ; otherwise change bowser's movement speed
HammerChk:
    LDA ram_enemy_frame_timer,x  ; if timer set here not expired yet, skip ahead to
    BNE MakeBJump  ; some other section of code
    JSR sub_move_enemy_downward_slow  ; otherwise start by moving bowser downwards
    LDA ram_world_number  ; check world number
    CMP #con_world6
    BCC SetHmrTmr  ; if world 1-5, skip this part (not time to throw hammers yet)
    LDA ram_frame_counter
    AND #%00000011  ; check to see if it's time to execute sub
    BNE SetHmrTmr  ; if not, skip sub, otherwise
    JSR sub_spawn_hammer_obj  ; execute sub on every fourth frame to spawn misc object (hammer)
SetHmrTmr:
    LDA ram_enemy_y_position,x  ; get current vertical position
    CMP #$80  ; if still above a certain point
    BCC ChkFireB  ; then skip to world number check for flames
    LDA ram_pseudo_random_bit_reg,x
    AND #%00000011  ; get pseudorandom offset
    TAY
    LDA PRandomRange,y  ; get value using pseudorandom offset
    STA ram_enemy_frame_timer,x  ; set for timer here
SkipToFB:
    JMP ChkFireB  ; jump to execute flames code
MakeBJump:
    CMP #$01  ; if timer not yet about to expire,
    BNE ChkFireB  ; skip ahead to next part
    DEC ram_enemy_y_position,x  ; otherwise decrement vertical coordinate
    JSR sub_init_v_stf  ; initialize movement amount
    LDA #$fe
    STA ram_enemy_y_speed,x  ; set vertical speed to move bowser upwards
ChkFireB:
    LDA ram_world_number  ; check world number here
    CMP #con_world8  ; world 8?
    BEQ SpawnFBr  ; if so, execute this part here
    CMP #con_world6  ; world 6-7?
    BCS BowserGfxHandler  ; if so, skip this part here
SpawnFBr:
    LDA ram_bowser_fire_breath_timer  ; check timer here
    BNE BowserGfxHandler  ; if not expired yet, skip all of this
    LDA #$20
    STA ram_bowser_fire_breath_timer  ; set timer here
    LDA ram_bowser_body_controls
    EOR #%10000000  ; invert bowser's mouth bit to open
    STA ram_bowser_body_controls  ; and close bowser's mouth
    BMI ChkFireB  ; if bowser's mouth open, loop back
    JSR sub_set_flame_timer  ; get timing for bowser's flame
    LDY ram_secondary_hard_mode
    BEQ SetFBTmr  ; if secondary hard mode flag not set, skip this
    SEC
    SBC #$10  ; otherwise subtract from value in A
SetFBTmr:
    STA ram_bowser_fire_breath_timer  ; set value as timer here
    LDA #con_bowser_flame  ; put bowser's flame identifier
    STA ram_enemy_frenzy_buffer  ; in enemy frenzy buffer

; --------------------------------

BowserGfxHandler:
    JSR sub_process_bowser_half  ; do a sub here to process bowser's front
    LDY #$10  ; load default value here to position bowser's rear
    LDA ram_enemy_moving_dir,x  ; check moving direction
    LSR
    BCC CopyFToR  ; if moving left, use default
    LDY #$f0  ; otherwise load alternate positioning value here
CopyFToR:
    TYA  ; move bowser's rear object position value to A
    CLC
    ADC ram_enemy_x_position,x  ; add to bowser's front object horizontal coordinate
    LDY ram_duplicate_obj_offset  ; get bowser's rear object offset
    STA ram_enemy_x_position,y  ; store A as bowser's rear horizontal coordinate
    LDA ram_enemy_y_position,x
    CLC  ; add eight pixels to bowser's front object
    ADC #$08  ; vertical coordinate and store as vertical coordinate
    STA ram_enemy_y_position,y  ; for bowser's rear
    LDA ram_enemy_state,x
    STA ram_enemy_state,y  ; copy enemy state directly from front to rear
    LDA ram_enemy_moving_dir,x
    STA ram_enemy_moving_dir,y  ; copy moving direction also
    LDA ram_object_offset  ; save enemy object offset of front to stack
    PHA
    LDX ram_duplicate_obj_offset  ; put enemy object offset of rear as current
    STX ram_object_offset
    LDA #con_bowser  ; set bowser's enemy identifier
    STA ram_enemy_id,x  ; store in bowser's rear object
    JSR sub_process_bowser_half  ; do a sub here to process bowser's rear
    PLA
    STA ram_object_offset  ; get original enemy object offset
    TAX
    LDA #$00  ; nullify bowser's front/rear graphics flag
    STA ram_bowser_gfx_flag
ExBGfxH:
    RTS  ; leave!

sub_process_bowser_half:
    INC ram_bowser_gfx_flag  ; increment bowser's graphics flag, then run subroutines
    JSR sub_run_retainer_obj  ; to get offscreen bits, relative position and draw bowser (finally!)
    LDA ram_enemy_state,x
    BNE ExBGfxH  ; if either enemy object not in normal state, branch to leave
    LDA #$0a
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box size control
    JSR sub_get_enemy_bound_box  ; get bounding box coordinates
    JMP sub_player_enemy_collision  ; do player-to-enemy collision detection

; -------------------------------------------------------------------------------------
; $00 - used to hold movement force and tile number
; $01 - used to hold sprite attribute data

FlameTimerData:
    .byte $bf, $40, $bf, $bf, $bf, $40, $40, $bf

sub_set_flame_timer:
    LDY ram_bowser_flame_timer_ctrl  ; load counter as offset
    INC ram_bowser_flame_timer_ctrl  ; increment
    LDA ram_bowser_flame_timer_ctrl  ; mask out all but 3 LSB
    AND #%00000111  ; to keep in range of 0-7
    STA ram_bowser_flame_timer_ctrl
    LDA FlameTimerData,y  ; load value to be used then leave
ExFl:
    RTS

sub_proc_bowser_flame:
    LDA ram_timer_control  ; if master timer control flag set,
    BNE SetGfxF  ; skip all of this
    LDA #$40  ; load default movement force
    LDY ram_secondary_hard_mode
    BEQ SFlmX  ; if secondary hard mode flag not set, use default
    LDA #$60  ; otherwise load alternate movement force to go faster
SFlmX:
    STA $00  ; store value here
    LDA ram_enemy_x_move_force,x
    SEC  ; subtract value from movement force
    SBC $00
    STA ram_enemy_x_move_force,x  ; save new value
    LDA ram_enemy_x_position,x
    SBC #$01  ; subtract one from horizontal position to move
    STA ram_enemy_x_position,x  ; to the left
    LDA ram_enemy_page_loc,x
    SBC #$00  ; subtract borrow from page location
    STA ram_enemy_page_loc,x
    LDY ram_bowser_flame_p_random_ofs,x  ; get some value here and use as offset
    LDA ram_enemy_y_position,x  ; load vertical coordinate
    CMP FlameYPosData,y  ; compare against coordinate data using $0417,x as offset
    BEQ SetGfxF  ; if equal, branch and do not modify coordinate
    CLC
    ADC ram_enemy_y_move_force,x  ; otherwise add value here to coordinate and store
    STA ram_enemy_y_position,x  ; as new vertical coordinate
SetGfxF:
    JSR sub_relative_enemy_position  ; get new relative coordinates
    LDA ram_enemy_state,x  ; if bowser's flame not in normal state,
    BNE ExFl  ; branch to leave
    LDA #$51  ; otherwise, continue
    STA $00  ; write first tile number
    LDY #$02  ; load attributes without vertical flip by default
    LDA ram_frame_counter
    AND #%00000010  ; invert vertical flip bit every 2 frames
    BEQ FlmeAt  ; if d1 not set, write default value
    LDY #$82  ; otherwise write value with vertical flip bit set
FlmeAt:
    STY $01  ; set bowser's flame sprite attributes here
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    LDX #$00

DrawFlameLoop:
    LDA ram_enemy_rel_y_pos  ; get Y relative coordinate of current enemy object
    STA ram_sprite_y_position,y  ; write into Y coordinate of OAM data
    LDA $00
    STA ram_sprite_tilenumber,y  ; write current tile number into OAM data
    INC $00  ; increment tile number to draw more bowser's flame
    LDA $01
    STA ram_sprite_attributes,y  ; write saved attributes into OAM data
    LDA ram_enemy_rel_x_pos
    STA ram_sprite_x_position,y  ; write X relative coordinate of current enemy object
    CLC
    ADC #$08
    STA ram_enemy_rel_x_pos  ; then add eight to it and store
    INY
    INY
    INY
    INY  ; increment Y four times to move onto the next OAM
    INX  ; move onto the next OAM, and branch if three
    CPX #$03  ; have not yet been done
    BCC DrawFlameLoop
    LDX ram_object_offset  ; reload original enemy offset
    JSR sub_get_enemy_offscreen_bits  ; get offscreen information
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    LDA ram_enemy_offscreen_bits  ; get enemy object offscreen bits
    LSR  ; move d0 to carry and result to stack
    PHA
    BCC M3FOfs  ; branch if carry not set
    LDA #$f8  ; otherwise move sprite offscreen, this part likely
    STA ram_sprite_y_position+12,y  ; residual since flame is only made of three sprites
M3FOfs:
    PLA  ; get bits from stack
    LSR  ; move d1 to carry and move bits back to stack
    PHA
    BCC M2FOfs  ; branch if carry not set again
    LDA #$f8  ; otherwise move third sprite offscreen
    STA ram_sprite_y_position+8,y
M2FOfs:
    PLA  ; get bits from stack again
    LSR  ; move d2 to carry and move bits back to stack again
    PHA
    BCC M1FOfs  ; branch if carry not set yet again
    LDA #$f8  ; otherwise move second sprite offscreen
    STA ram_sprite_y_position+4,y
M1FOfs:
    PLA  ; get bits from stack one last time
    LSR  ; move d3 to carry
    BCC ExFlmeD  ; branch if carry not set one last time
    LDA #$f8
    STA ram_sprite_y_position,y  ; otherwise move first sprite offscreen
ExFlmeD:
    RTS  ; leave

; --------------------------------

RunFireworks:
    DEC ram_explosion_timer_counter,x  ; decrement explosion timing counter here
    BNE SetupExpl  ; if not expired, skip this part
    LDA #$08
    STA ram_explosion_timer_counter,x  ; reset counter
    INC ram_explosion_gfx_counter,x  ; increment explosion graphics counter
    LDA ram_explosion_gfx_counter,x
    CMP #$03  ; check explosion graphics counter
    BCS FireworksSoundScore  ; if at a certain point, branch to kill this object
SetupExpl:
    JSR sub_relative_enemy_position  ; get relative coordinates of explosion
    LDA ram_enemy_rel_y_pos  ; copy relative coordinates
    STA ram_fireball_rel_y_pos  ; from the enemy object to the fireball object
    LDA ram_enemy_rel_x_pos  ; first vertical, then horizontal
    STA ram_fireball_rel_x_pos
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    LDA ram_explosion_gfx_counter,x  ; get explosion graphics counter
    JSR sub_draw_explosion_fireworks  ; do a sub to draw the explosion then leave
    RTS

FireworksSoundScore:
    LDA #$00  ; disable enemy buffer flag
    STA ram_enemy_flag,x
    LDA #con_sfx_blast  ; play fireworks/gunfire sound
    STA ram_square2_sound_queue
    LDA #$05  ; set part of score modifier for 500 points
    STA ram_digit_modifier+4
    JMP EndAreaPoints  ; jump to award points accordingly then leave

; --------------------------------

StarFlagYPosAdder:
    .byte $00, $00, $08, $08

StarFlagXPosAdder:
    .byte $00, $08, $00, $08

StarFlagTileData:
    .byte $54, $55, $56, $57

RunStarFlagObj:
    LDA #$00  ; initialize enemy frenzy buffer
    STA ram_enemy_frenzy_buffer
    LDA ram_star_flag_task_control  ; check star flag object task number here
    CMP #$05  ; if greater than 5, branch to exit
    BCS StarFlagExit
    JSR sub_dispatch_inline_handler  ; otherwise jump to appropriate sub

    .word StarFlagExit
    .word GameTimerFireworks
    .word AwardGameTimerPoints
    .word RaiseFlagSetoffFWorks
    .word DelayToAreaEnd

GameTimerFireworks:
    LDY #$05  ; set default state for star flag object
    LDA ram_game_timer_display+2  ; get game timer's last digit
    CMP #$01
    BEQ SetFWC  ; if last digit of game timer set to 1, skip ahead
    LDY #$03  ; otherwise load new value for state
    CMP #$03
    BEQ SetFWC  ; if last digit of game timer set to 3, skip ahead
    LDY #$00  ; otherwise load one more potential value for state
    CMP #$06
    BEQ SetFWC  ; if last digit of game timer set to 6, skip ahead
    LDA #$ff  ; otherwise set value for no fireworks
SetFWC:
    STA ram_fireworks_counter  ; set fireworks counter here
    STY ram_enemy_state,x  ; set whatever state we have in star flag object

IncrementSFTask1:
    INC ram_star_flag_task_control  ; increment star flag object task number

StarFlagExit:
    RTS  ; leave

AwardGameTimerPoints:
    LDA ram_game_timer_display  ; check all game timer digits for any intervals left
    ORA ram_game_timer_display+1
    ORA ram_game_timer_display+2
    BEQ IncrementSFTask1  ; if no time left on game timer at all, branch to next task
    LDA ram_frame_counter
    AND #%00000100  ; check frame counter for d2 set (skip ahead
    BEQ NoTTick  ; for four frames every four frames) branch if not set
    LDA #con_sfx_timer_tick
    STA ram_square2_sound_queue  ; load timer tick sound
NoTTick:
    LDY #$23  ; set offset here to subtract from game timer's last digit
    LDA #$ff  ; set adder here to $ff, or -1, to subtract one
    STA ram_digit_modifier+5  ; from the last digit of the game timer
    JSR sub_digits_math_routine  ; subtract digit
    LDA #$05  ; set now to add 50 points
    STA ram_digit_modifier+5  ; per game timer interval subtracted

EndAreaPoints:
    LDY #$0b  ; load offset for mario's score by default
    LDA ram_current_player  ; check player on the screen
    BEQ ELPGive  ; if mario, do not change
    LDY #$11  ; otherwise load offset for luigi's score
ELPGive:
    JSR sub_digits_math_routine  ; award 50 points per game timer interval
    LDA ram_current_player  ; get player on the screen (or 500 points per
    ASL  ; fireworks explosion if branched here from there)
    ASL  ; shift to high nybble
    ASL
    ASL
    ORA #%00000100  ; add four to set nybble for game timer
    JMP sub_update_number  ; jump to print the new score and game timer

RaiseFlagSetoffFWorks:
    LDA ram_enemy_y_position,x  ; check star flag's vertical position
    CMP #$72  ; against preset value
    BCC SetoffF  ; if star flag higher vertically, branch to other code
    DEC ram_enemy_y_position,x  ; otherwise, raise star flag by one pixel
    JMP sub_draw_star_flag  ; and skip this part here
SetoffF:
    LDA ram_fireworks_counter  ; check fireworks counter
    BEQ DrawFlagSetTimer  ; if no fireworks left to go off, skip this part
    BMI DrawFlagSetTimer  ; if no fireworks set to go off, skip this part
    LDA #con_fireworks
    STA ram_enemy_frenzy_buffer  ; otherwise set fireworks object in frenzy queue

sub_draw_star_flag:
    JSR sub_relative_enemy_position  ; get relative coordinates of star flag
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    LDX #$03  ; do four sprites
DSFLoop:
    LDA ram_enemy_rel_y_pos  ; get relative vertical coordinate
    CLC
    ADC StarFlagYPosAdder,x  ; add Y coordinate adder data
    STA ram_sprite_y_position,y  ; store as Y coordinate
    LDA StarFlagTileData,x  ; get tile number
    STA ram_sprite_tilenumber,y  ; store as tile number
    LDA #$22  ; set palette and background priority bits
    STA ram_sprite_attributes,y  ; store as attributes
    LDA ram_enemy_rel_x_pos  ; get relative horizontal coordinate
    CLC
    ADC StarFlagXPosAdder,x  ; add X coordinate adder data
    STA ram_sprite_x_position,y  ; store as X coordinate
    INY
    INY  ; increment OAM data offset four bytes
    INY  ; for next sprite
    INY
    DEX  ; move onto next sprite
    BPL DSFLoop  ; do this until all sprites are done
    LDX ram_object_offset  ; get enemy object offset and leave
    RTS

DrawFlagSetTimer:
    JSR sub_draw_star_flag  ; do sub to draw star flag
    LDA #$06
    STA ram_enemy_interval_timer,x  ; set interval timer here

IncrementSFTask2:
    INC ram_star_flag_task_control  ; move onto next task
    RTS

DelayToAreaEnd:
    JSR sub_draw_star_flag  ; do sub to draw star flag
    LDA ram_enemy_interval_timer,x  ; if interval timer set in previous task
    BNE StarFlagExit2  ; not yet expired, branch to leave
    LDA ram_event_music_buffer  ; if event music buffer empty,
    BEQ IncrementSFTask2  ; branch to increment task

StarFlagExit2:
    RTS  ; otherwise leave

; --------------------------------
; $00 - used to store horizontal difference between player and piranha plant

MovePiranhaPlant:
    LDA ram_enemy_state,x  ; check enemy state
    BNE PutinPipe  ; if set at all, branch to leave
    LDA ram_enemy_frame_timer,x  ; check enemy's timer here
    BNE PutinPipe  ; branch to end if not yet expired
    LDA ram_piranha_plant_move_flag,x  ; check movement flag
    BNE SetupToMovePPlant  ; if moving, skip to part ahead
    LDA ram_piranha_plant_y_speed,x  ; if currently rising, branch
    BMI ReversePlantSpeed  ; to move enemy upwards out of pipe
    JSR sub_player_enemy_diff  ; get horizontal difference between player and
    BPL ChkPlayerNearPipe  ; piranha plant, and branch if enemy to right of player
    LDA $00  ; otherwise get saved horizontal difference
    EOR #$ff
    CLC  ; and change to two's compliment
    ADC #$01
    STA $00  ; save as new horizontal difference

ChkPlayerNearPipe:
    LDA $00  ; get saved horizontal difference
    CMP #$21
    BCC PutinPipe  ; if player within a certain distance, branch to leave

ReversePlantSpeed:
    LDA ram_piranha_plant_y_speed,x  ; get vertical speed
    EOR #$ff
    CLC  ; change to two's compliment
    ADC #$01
    STA ram_piranha_plant_y_speed,x  ; save as new vertical speed
    INC ram_piranha_plant_move_flag,x  ; increment to set movement flag

SetupToMovePPlant:
    LDA ram_piranha_plant_down_y_pos,x  ; get original vertical coordinate (lowest point)
    LDY ram_piranha_plant_y_speed,x  ; get vertical speed
    BPL RiseFallPiranhaPlant  ; branch if moving downwards
    LDA ram_piranha_plant_up_y_pos,x  ; otherwise get other vertical coordinate (highest point)

RiseFallPiranhaPlant:
    STA $00  ; save vertical coordinate here
    LDA ram_frame_counter  ; get frame counter
    LSR
    BCC PutinPipe  ; branch to leave if d0 set (execute code every other frame)
    LDA ram_timer_control  ; get master timer control
    BNE PutinPipe  ; branch to leave if set (likely not necessary)
    LDA ram_enemy_y_position,x  ; get current vertical coordinate
    CLC
    ADC ram_piranha_plant_y_speed,x  ; add vertical speed to move up or down
    STA ram_enemy_y_position,x  ; save as new vertical coordinate
    CMP $00  ; compare against low or high coordinate
    BNE PutinPipe  ; branch to leave if not yet reached
    LDA #$00
    STA ram_piranha_plant_move_flag,x  ; otherwise clear movement flag
    LDA #$40
    STA ram_enemy_frame_timer,x  ; set timer to delay piranha plant movement

PutinPipe:
    LDA #%00100000  ; set background priority bit in sprite
    STA ram_enemy_spr_attrib,x  ; attributes to give illusion of being inside pipe
    RTS  ; then leave

; -------------------------------------------------------------------------------------
; $07 - spinning speed

sub_firebar_spin:
    STA $07  ; save spinning speed here
    LDA ram_firebar_spin_direction,x  ; check spinning direction
    BNE SpinCounterClockwise  ; if moving counter-clockwise, branch to other part
    LDY #$18  ; possibly residual ldy
    LDA ram_firebar_spin_state_low,x
    CLC  ; add spinning speed to what would normally be
    ADC $07  ; the horizontal speed
    STA ram_firebar_spin_state_low,x
    LDA ram_firebar_spin_state_high,x  ; add carry to what would normally be the vertical speed
    ADC #$00
    RTS

SpinCounterClockwise:
    LDY #$08  ; possibly residual ldy
    LDA ram_firebar_spin_state_low,x
    SEC  ; subtract spinning speed to what would normally be
    SBC $07  ; the horizontal speed
    STA ram_firebar_spin_state_low,x
    LDA ram_firebar_spin_state_high,x  ; add carry to what would normally be the vertical speed
    SBC #$00
    RTS
