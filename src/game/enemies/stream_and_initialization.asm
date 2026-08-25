; -------------------------------------------------------------------------------------

; Decode enemy-stream commands and initialize eligible enemy slots

; Inputs:
; Enemy stream pointer/offset and current screen position

; Outputs:
; Enemy slots, loop state, and stream offset may be updated

; Clobbers:
; A, X, Y
sub_enemies_and_loops_core:
    LDA ram_enemy_flag,x  ; check data here for MSB set
    PHA  ; save in stack
    ASL
    BCS ChkBowserF  ; if MSB set in enemy flag, branch ahead of jumps
    PLA  ; get from stack
    BEQ ChkAreaTsk  ; if data zero, branch
    JMP RunEnemyObjectsCore  ; otherwise, jump to run enemy subroutines
ChkAreaTsk:
    LDA ram_area_parser_task_num  ; check number of tasks to perform
    AND #$07
    CMP #$07  ; if at a specific task, jump and leave
    BEQ ExitELCore
    JMP ProcLoopCommand  ; otherwise, jump to process loop command/load enemies
ChkBowserF:
    PLA  ; get data from stack
    AND #%00001111  ; mask out high nybble
    TAY
    LDA ram_enemy_flag,y  ; use as pointer and load same place with different offset
    BNE ExitELCore
    STA ram_enemy_flag,x  ; if second enemy flag not set, also clear first one
ExitELCore:
    RTS

; --------------------------------

; loop command data
LoopCmdWorldNumber:
    .byte $03, $03, $06, $06, $06, $06, $06, $06, $07, $07, $07

LoopCmdPageNumber:
    .byte $05, $09, $04, $05, $06, $08, $09, $0a, $06, $0b, $10

LoopCmdYPosition:
    .byte $40, $b0, $b0, $80, $40, $40, $80, $40, $f0, $f0, $f0

sub_exec_game_loopback:
    LDA ram_player_page_loc  ; send player back four pages
    SEC
    SBC #$04
    STA ram_player_page_loc
    LDA ram_current_page_loc  ; send current page back four pages
    SEC
    SBC #$04
    STA ram_current_page_loc
    LDA ram_screen_left_page_loc  ; subtract four from page location
    SEC  ; of screen's left border
    SBC #$04
    STA ram_screen_left_page_loc
    LDA ram_screen_right_page_loc  ; do the same for the page location
    SEC  ; of screen's right border
    SBC #$04
    STA ram_screen_right_page_loc
    LDA ram_area_object_page_loc  ; subtract four from page control
    SEC  ; for area objects
    SBC #$04
    STA ram_area_object_page_loc
    LDA #$00  ; initialize page select for both
    STA ram_enemy_object_page_sel  ; area and enemy objects
    STA ram_area_object_page_sel
    STA ram_enemy_data_offset  ; initialize enemy object data offset
    STA ram_enemy_object_page_loc  ; and enemy object page control
    LDA AreaDataOfsLoopback,y  ; adjust area object offset based on
    STA ram_area_data_offset  ; which loop command we encountered
    RTS

ProcLoopCommand:
    LDA ram_loop_command  ; check if loop command was found
    BEQ ChkEnemyFrenzy
    LDA ram_current_column_pos  ; check to see if we're still on the first page
    BNE ChkEnemyFrenzy  ; if not, do not loop yet
    LDY #$0b  ; start at the end of each set of loop data
FindLoop:
    DEY
    BMI ChkEnemyFrenzy  ; if all data is checked and not match, do not loop
    LDA ram_world_number  ; check to see if one of the world numbers
    CMP LoopCmdWorldNumber,y  ; matches our current world number
    BNE FindLoop
    LDA ram_current_page_loc  ; check to see if one of the page numbers
    CMP LoopCmdPageNumber,y  ; matches the page we're currently on
    BNE FindLoop
    LDA ram_player_y_position  ; check to see if the player is at the correct position
    CMP LoopCmdYPosition,y  ; if not, branch to check for world 7
    BNE WrongChk
    LDA ram_player_state  ; check to see if the player is
    CMP #$00  ; on solid ground (i.e. not jumping or falling)
    BNE WrongChk  ; if not, player fails to pass loop, and loopback
    LDA ram_world_number  ; are we in world 7? (check performed on correct
    CMP #con_world7  ; vertical position and on solid ground)
    BNE InitMLp  ; if not, initialize flags used there, otherwise
    INC ram_multi_loop_correct_cntr  ; increment counter for correct progression
IncMLoop:
    INC ram_multi_loop_pass_cntr  ; increment master multi-part counter
    LDA ram_multi_loop_pass_cntr  ; have we done all three parts?
    CMP #$03
    BNE InitLCmd  ; if not, skip this part
    LDA ram_multi_loop_correct_cntr  ; if so, have we done them all correctly?
    CMP #$03
    BEQ InitMLp  ; if so, branch past unnecessary check here
    BNE DoLpBack  ; unconditional branch if previous branch fails
WrongChk:
    LDA ram_world_number  ; are we in world 7? (check performed on
    CMP #con_world7  ; incorrect vertical position or not on solid ground)
    BEQ IncMLoop
DoLpBack:
    JSR sub_exec_game_loopback  ; if player is not in right place, loop back
    JSR sub_kill_all_enemies
InitMLp:
    LDA #$00  ; initialize counters used for multi-part loop commands
    STA ram_multi_loop_pass_cntr
    STA ram_multi_loop_correct_cntr
InitLCmd:
    LDA #$00  ; initialize loop command flag
    STA ram_loop_command

; --------------------------------

ChkEnemyFrenzy:
    LDA ram_enemy_frenzy_queue  ; check for enemy object in frenzy queue
    BEQ ProcessEnemyData  ; if not, skip this part
    STA ram_enemy_id,x  ; store as enemy object identifier here
    LDA #$01
    STA ram_enemy_flag,x  ; activate enemy object flag
    LDA #$00
    STA ram_enemy_state,x  ; initialize state and frenzy queue
    STA ram_enemy_frenzy_queue
    JMP sub_init_enemy_object  ; and then jump to deal with this enemy

; --------------------------------
; $06 - used to hold page location of extended right boundary
; $07 - used to hold high nybble of position of extended right boundary

ProcessEnemyData:
    LDY ram_enemy_data_offset  ; get offset of enemy object data
    LDA (ram_enemy_data),y  ; load first byte
    CMP #$ff  ; check for EOD terminator
    BNE CheckEndofBuffer
    JMP CheckFrenzyBuffer  ; if found, jump to check frenzy buffer, otherwise

CheckEndofBuffer:
    AND #%00001111  ; check for special row $0e
    CMP #$0e
    BEQ CheckRightBounds  ; if found, branch, otherwise
    CPX #$05  ; check for end of buffer
    BCC CheckRightBounds  ; if not at end of buffer, branch
    INY
    LDA (ram_enemy_data),y  ; check for specific value here
    AND #%00111111  ; !(WHY?) CODE-002 - residual object-range check
    CMP #$2e
    BEQ CheckRightBounds  ; but it has the effect of keeping enemies out of
    RTS  ; the sixth slot

CheckRightBounds:
    LDA ram_screen_right_x_pos  ; add 48 to pixel coordinate of right boundary
    CLC
    ADC #$30
    AND #%11110000  ; store high nybble
    STA $07
    LDA ram_screen_right_page_loc  ; add carry to page location of right boundary
    ADC #$00
    STA $06  ; store page location + carry
    LDY ram_enemy_data_offset
    INY
    LDA (ram_enemy_data),y  ; if MSB of enemy object is clear, branch to check for row $0f
    ASL
    BCC CheckPageCtrlRow
    LDA ram_enemy_object_page_sel  ; if page select already set, do not set again
    BNE CheckPageCtrlRow
    INC ram_enemy_object_page_sel  ; otherwise, if MSB is set, set page select
    INC ram_enemy_object_page_loc  ; and increment page control

CheckPageCtrlRow:
    DEY
    LDA (ram_enemy_data),y  ; reread first byte
    AND #$0f
    CMP #$0f  ; check for special row $0f
    BNE PositionEnemyObj  ; if not found, branch to position enemy object
    LDA ram_enemy_object_page_sel  ; if page select set,
    BNE PositionEnemyObj  ; branch without reading second byte
    INY
    LDA (ram_enemy_data),y  ; otherwise, get second byte, mask out 2 MSB
    AND #%00111111
    STA ram_enemy_object_page_loc  ; store as page control for enemy object data
    INC ram_enemy_data_offset  ; increment enemy object data offset 2 bytes
    INC ram_enemy_data_offset
    INC ram_enemy_object_page_sel  ; set page select for enemy object data and
    JMP ProcLoopCommand  ; jump back to process loop commands again

PositionEnemyObj:
    LDA ram_enemy_object_page_loc  ; store page control as page location
    STA ram_enemy_page_loc,x  ; for enemy object
    LDA (ram_enemy_data),y  ; get first byte of enemy object
    AND #%11110000
    STA ram_enemy_x_position,x  ; store column position
    CMP ram_screen_right_x_pos  ; check column position against right boundary
    LDA ram_enemy_page_loc,x  ; without subtracting, then subtract borrow
    SBC ram_screen_right_page_loc  ; from page location
    BCS CheckRightExtBounds  ; if enemy object beyond or at boundary, branch
    LDA (ram_enemy_data),y
    AND #%00001111  ; check for special row $0e
    CMP #$0e  ; if found, jump elsewhere
    BEQ ParseRow0e
    JMP CheckThreeBytes  ; if not found, unconditional jump

CheckRightExtBounds:
    LDA $07  ; check right boundary + 48 against
    CMP ram_enemy_x_position,x  ; column position without subtracting,
    LDA $06  ; then subtract borrow from page control temp
    SBC ram_enemy_page_loc,x  ; plus carry
    BCC CheckFrenzyBuffer  ; if enemy object beyond extended boundary, branch
    LDA #$01  ; store value in vertical high byte
    STA ram_enemy_y_high_pos,x
    LDA (ram_enemy_data),y  ; get first byte again
    ASL  ; multiply by four to get the vertical
    ASL  ; coordinate
    ASL
    ASL
    STA ram_enemy_y_position,x
    CMP #$e0  ; do one last check for special row $0e
    BEQ ParseRow0e  ; (necessary if branched to $c1cb)
    INY
    LDA (ram_enemy_data),y  ; get second byte of object
    AND #%01000000  ; check to see if hard mode bit is set
    BEQ CheckForEnemyGroup  ; if not, branch to check for group enemy objects
    LDA ram_secondary_hard_mode  ; if set, check to see if secondary hard mode flag
    BEQ Inc2B  ; is on, and if not, branch to skip this object completely

CheckForEnemyGroup:
    LDA (ram_enemy_data),y  ; get second byte and mask out 2 MSB
    AND #%00111111
    CMP #$37  ; check for value below $37
    BCC BuzzyBeetleMutate
    CMP #$3f  ; if $37 or greater, check for value
    BCC DoGroup  ; below $3f, branch if below $3f

BuzzyBeetleMutate:
    CMP #con_goomba  ; if below $37, check for goomba
    BNE StrID  ; value ($3f or more always fails)
    LDY ram_primary_hard_mode  ; check if primary hard mode flag is set
    BEQ StrID  ; and if so, change goomba to buzzy beetle
    LDA #con_buzzy_beetle
StrID:
    STA ram_enemy_id,x  ; store enemy object number into buffer
    LDA #$01
    STA ram_enemy_flag,x  ; set flag for enemy in buffer
    JSR sub_init_enemy_object
    LDA ram_enemy_flag,x  ; check to see if flag is set
    BNE Inc2B  ; if not, leave, otherwise branch
    RTS

CheckFrenzyBuffer:
    LDA ram_enemy_frenzy_buffer  ; if enemy object stored in frenzy buffer
    BNE StrFre  ; then branch ahead to store in enemy object buffer
    LDA ram_vine_flag_offset  ; otherwise check vine flag offset
    CMP #$01
    BNE ExEPar  ; if other value <> 1, leave
    LDA #con_vine_object  ; otherwise put vine in enemy identifier
StrFre:
    STA ram_enemy_id,x  ; store contents of frenzy buffer into enemy identifier value

sub_init_enemy_object:
    LDA #$00  ; initialize enemy state
    STA ram_enemy_state,x
    JSR sub_checkpoint_enemy_id  ; jump ahead to run jump engine and subroutines
ExEPar:
    RTS  ; then leave

DoGroup:
    JMP HandleGroupEnemies  ; handle enemy group objects

ParseRow0e:
    INY  ; increment Y to load third byte of object
    INY
    LDA (ram_enemy_data),y
    LSR  ; move 3 MSB to the bottom, effectively
    LSR  ; making %xxx00000 into %00000xxx
    LSR
    LSR
    LSR
    CMP ram_world_number  ; is it the same world number as we're on?
    BNE NotUse  ; if not, do not use (this allows multiple uses
    DEY  ; of the same area, like the underground bonus areas)
    LDA (ram_enemy_data),y  ; otherwise, get second byte and use as offset
    STA ram_area_pointer  ; to addresses for level and enemy object data
    INY
    LDA (ram_enemy_data),y  ; get third byte again, and this time mask out
    AND #%00011111  ; the 3 MSB from before, save as page number to be
    STA ram_entrance_page  ; used upon entry to area, if area is entered
NotUse:
    JMP Inc3B

CheckThreeBytes:
    LDY ram_enemy_data_offset  ; load current offset for enemy object data
    LDA (ram_enemy_data),y  ; get first byte
    AND #%00001111  ; check for special row $0e
    CMP #$0e
    BNE Inc2B
Inc3B:
    INC ram_enemy_data_offset  ; if row = $0e, increment three bytes
Inc2B:
    INC ram_enemy_data_offset  ; otherwise increment two bytes
    INC ram_enemy_data_offset
    LDA #$00  ; init page select for enemy objects
    STA ram_enemy_object_page_sel
    LDX ram_object_offset  ; reload current offset in enemy buffers
    RTS  ; and leave

sub_checkpoint_enemy_id:
    LDA ram_enemy_id,x
    CMP #$15  ; check enemy object identifier for $15 or greater
    BCS InitEnemyRoutines  ; and branch straight to the jump engine if found
    TAY  ; save identifier in Y register for now
    LDA ram_enemy_y_position,x
    ADC #$08  ; add eight pixels to what will eventually be the
    STA ram_enemy_y_position,x  ; enemy object's vertical coordinate ($00-$14 only)
    LDA #$01
    STA ram_enemy_offscr_bits_masked,x  ; set offscreen masked bit
    TYA  ; get identifier back and use as offset for jump engine

InitEnemyRoutines:
    JSR sub_dispatch_inline_handler

; jump engine table for newly loaded enemy objects

    .word sub_init_normal_enemy  ; for objects $00-$0f
    .word sub_init_normal_enemy
    .word sub_init_normal_enemy
    .word InitRedKoopa
    .word NoInitCode
    .word InitHammerBro
    .word InitGoomba
    .word InitBloober
    .word InitBulletBill
    .word NoInitCode
    .word InitCheepCheep
    .word InitCheepCheep
    .word sub_init_podoboo
    .word sub_init_piranha_plant
    .word InitJumpGPTroopa
    .word InitRedPTroopa

    .word sub_init_horiz_fly_swim_enemy  ; for objects $10-$1f
    .word InitLakitu
    .word InitEnemyFrenzy
    .word NoInitCode
    .word InitEnemyFrenzy
    .word InitEnemyFrenzy
    .word InitEnemyFrenzy
    .word InitEnemyFrenzy
    .word EndFrenzy
    .word NoInitCode
    .word NoInitCode
    .word InitShortFirebar
    .word InitShortFirebar
    .word InitShortFirebar
    .word InitShortFirebar
    .word InitLongFirebar

    .word NoInitCode  ; for objects $20-$2f
    .word NoInitCode
    .word NoInitCode
    .word NoInitCode
    .word InitBalPlatform
    .word InitVertPlatform
    .word LargeLiftUp
    .word LargeLiftDown
    .word InitHoriPlatform
    .word InitDropPlatform
    .word InitHoriPlatform
    .word sub_plat_lift_up
    .word sub_plat_lift_down
    .word InitBowser
    .word PwrUpJmp  ; possibly dummy value
    .word sub_setup_vine

    .word NoInitCode  ; for objects $30-$36
    .word NoInitCode
    .word NoInitCode
    .word NoInitCode
    .word NoInitCode
    .word InitRetainerObj
    .word EndOfEnemyInitCode

; -------------------------------------------------------------------------------------

NoInitCode:
    RTS  ; this executed when enemy object has no init code

; --------------------------------

InitGoomba:
    JSR sub_init_normal_enemy  ; set appropriate horizontal speed
    JMP sub_small_b_box  ; set $09 as bounding box control, set other values

; --------------------------------

sub_init_podoboo:
    LDA #$02  ; set enemy position to below
    STA ram_enemy_y_high_pos,x  ; the bottom of the screen
    STA ram_enemy_y_position,x
    LSR
    STA ram_enemy_interval_timer,x  ; set timer for enemy
    LSR
    STA ram_enemy_state,x  ; initialize enemy state, then jump to use
    JMP sub_small_b_box  ; $09 as bounding box size and set other things

; --------------------------------

InitRetainerObj:
    LDA #$b8  ; set fixed vertical position for
    STA ram_enemy_y_position,x  ; princess/mushroom retainer object
    RTS

; --------------------------------

NormalXSpdData:
    .byte $f8, $f4

sub_init_normal_enemy:
    LDY #$01  ; load offset of 1 by default
    LDA ram_primary_hard_mode  ; check for primary hard mode flag set
    BNE GetESpd
    DEY  ; if not set, decrement offset
GetESpd:
    LDA NormalXSpdData,y  ; get appropriate horizontal speed
SetESpd:
    STA ram_enemy_x_speed,x  ; store as speed for enemy object
    JMP TallBBox  ; branch to set bounding box control and other data

; --------------------------------

InitRedKoopa:
    JSR sub_init_normal_enemy  ; load appropriate horizontal speed
    LDA #$01  ; set enemy state for red koopa troopa $03
    STA ram_enemy_state,x
    RTS

; --------------------------------

HBroWalkingTimerData:
    .byte $80, $50

InitHammerBro:
    LDA #$00  ; init horizontal speed and timer used by hammer bro
    STA ram_hammer_throwing_timer,x  ; apparently to time hammer throwing
    STA ram_enemy_x_speed,x
    LDY ram_secondary_hard_mode  ; get secondary hard mode flag
    LDA HBroWalkingTimerData,y
    STA ram_enemy_interval_timer,x  ; set value as delay for hammer bro to walk left
    LDA #$0b  ; set specific value for bounding box size control
    JMP SetBBox

; --------------------------------

sub_init_horiz_fly_swim_enemy:
    LDA #$00  ; initialize horizontal speed
    JMP SetESpd

; --------------------------------

InitBloober:
    LDA #$00  ; initialize horizontal speed
    STA ram_blooper_move_speed,x
sub_small_b_box:
    LDA #$09  ; set specific bounding box size control
    BNE SetBBox  ; unconditional branch

; --------------------------------

InitRedPTroopa:
    LDY #$30  ; load central position adder for 48 pixels down
    LDA ram_enemy_y_position,x  ; set vertical coordinate into location to
    STA ram_red_p_troopa_orig_x_pos,x  ; be used as original vertical coordinate
    BPL GetCent  ; if vertical coordinate < $80
    LDY #$e0  ; if => $80, load position adder for 32 pixels up
GetCent:
    TYA  ; send central position adder to A
    ADC ram_enemy_y_position,x  ; add to current vertical coordinate
    STA ram_red_p_troopa_center_y_pos,x  ; store as central vertical coordinate
TallBBox:
    LDA #$03  ; set specific bounding box size control
SetBBox:
    STA ram_enemy_bound_box_ctrl,x  ; set bounding box control here
    LDA #$02  ; set moving direction for left
    STA ram_enemy_moving_dir,x
sub_init_v_stf:
    LDA #$00  ; initialize vertical speed
    STA ram_enemy_y_speed,x  ; and movement force
    STA ram_enemy_y_move_force,x
    RTS

; --------------------------------

InitBulletBill:
    LDA #$02  ; set moving direction for left
    STA ram_enemy_moving_dir,x
    LDA #$09  ; set bounding box control for $09
    STA ram_enemy_bound_box_ctrl,x
    RTS

; --------------------------------

InitCheepCheep:
    JSR sub_small_b_box  ; set vertical bounding box, speed, init others
    LDA ram_pseudo_random_bit_reg,x  ; check one portion of LSFR
    AND #%00010000  ; get d4 from it
    STA ram_cheep_cheep_move_m_flag,x  ; save as movement flag of some sort
    LDA ram_enemy_y_position,x
    STA ram_cheep_cheep_orig_y_pos,x  ; save original vertical coordinate here
    RTS

; --------------------------------

InitLakitu:
    LDA ram_enemy_frenzy_buffer  ; check to see if an enemy is already in
    BNE KillLakitu  ; the frenzy buffer, and branch to kill lakitu if so

sub_setup_lakitu:
    LDA #$00  ; erase counter for lakitu's reappearance
    STA ram_lakitu_reappear_timer
    JSR sub_init_horiz_fly_swim_enemy  ; set $03 as bounding box, set other attributes
    JMP TallBBox2  ; set $03 as bounding box again (not necessary) and leave

KillLakitu:
    JMP sub_erase_enemy_object

; --------------------------------
; $01-$03 - used to hold pseudorandom difference adjusters

PRDiffAdjustData:
    .byte $26, $2c, $32, $38
    .byte $20, $22, $24, $26
    .byte $13, $14, $15, $16

LakituAndSpinyHandler:
    LDA ram_frenzy_enemy_timer  ; if timer here not expired, leave
    BNE ExLSHand
    CPX #$05  ; if we are on the special use slot, leave
    BCS ExLSHand
    LDA #$80  ; set timer
    STA ram_frenzy_enemy_timer
    LDY #$04  ; start with the last enemy slot
ChkLak:
    LDA ram_enemy_id,y  ; check all enemy slots to see
    CMP #con_lakitu  ; if lakitu is on one of them
    BEQ CreateSpiny  ; if so, branch out of this loop
    DEY  ; otherwise check another slot
    BPL ChkLak  ; loop until all slots are checked
    INC ram_lakitu_reappear_timer  ; increment reappearance timer
    LDA ram_lakitu_reappear_timer
    CMP #$07  ; check to see if we're up to a certain value yet
    BCC ExLSHand  ; if not, leave
    LDX #$04  ; start with the last enemy slot again
ChkNoEn:
    LDA ram_enemy_flag,x  ; check enemy buffer flag for non-active enemy slot
    BEQ CreateL  ; branch out of loop if found
    DEX  ; otherwise check next slot
    BPL ChkNoEn  ; branch until all slots are checked
    BMI RetEOfs  ; if no empty slots were found, branch to leave
CreateL:
    LDA #$00  ; initialize enemy state
    STA ram_enemy_state,x
    LDA #con_lakitu  ; create lakitu enemy object
    STA ram_enemy_id,x
    JSR sub_setup_lakitu  ; do a sub to set up lakitu
    LDA #$20
    JSR sub_put_at_right_extent  ; finish setting up lakitu
RetEOfs:
    LDX ram_object_offset  ; get enemy object buffer offset again and leave
ExLSHand:
    RTS

; --------------------------------

CreateSpiny:
    LDA ram_player_y_position  ; if player above a certain point, branch to leave
    CMP #$2c
    BCC ExLSHand
    LDA ram_enemy_state,y  ; if lakitu is not in normal state, branch to leave
    BNE ExLSHand
    LDA ram_enemy_page_loc,y  ; store horizontal coordinates (high and low) of lakitu
    STA ram_enemy_page_loc,x  ; into the coordinates of the spiny we're going to create
    LDA ram_enemy_x_position,y
    STA ram_enemy_x_position,x
    LDA #$01  ; put spiny within vertical screen unit
    STA ram_enemy_y_high_pos,x
    LDA ram_enemy_y_position,y  ; put spiny eight pixels above where lakitu is
    SEC
    SBC #$08
    STA ram_enemy_y_position,x
    LDA ram_pseudo_random_bit_reg,x  ; get 2 LSB of LSFR and save to Y
    AND #%00000011
    TAY
    LDX #$02
DifLoop:
    LDA PRDiffAdjustData,y  ; get three values and save them
    STA $01,x  ; to $01-$03
    INY
    INY  ; increment Y four bytes for each value
    INY
    INY
    DEX  ; decrement X for each one
    BPL DifLoop  ; loop until all three are written
    LDX ram_object_offset  ; get enemy object buffer offset
    JSR sub_player_lakitu_diff  ; move enemy, change direction, get value - difference
    LDY ram_player_x_speed  ; check player's horizontal speed
    CPY #$08
    BCS SetSpSpd  ; if moving faster than a certain amount, branch elsewhere
    TAY  ; otherwise save value in A to Y for now
    LDA ram_pseudo_random_bit_reg+1,x
    AND #%00000011  ; get one of the LSFR parts and save the 2 LSB
    BEQ UsePosv  ; branch if neither bits are set
    TYA
    EOR #%11111111  ; otherwise get two's compliment of Y
    TAY
    INY
UsePosv:
    TYA  ; put value from A in Y back to A (they will be lost anyway)
SetSpSpd:
    JSR sub_small_b_box  ; set bounding box control, init attributes, lose contents of A
    LDY #$02
    STA ram_enemy_x_speed,x  ; set horizontal speed to zero because previous contents
    CMP #$00  ; of A were lost...branch here will never be taken for
    BMI SpinyRte  ; the same reason
    DEY
SpinyRte:
    STY ram_enemy_moving_dir,x  ; set moving direction to the right
    LDA #$fd
    STA ram_enemy_y_speed,x  ; set vertical speed to move upwards
    LDA #$01
    STA ram_enemy_flag,x  ; enable enemy object by setting flag
    LDA #$05
    STA ram_enemy_state,x  ; put spiny in egg state and leave
ChpChpEx:
    RTS
