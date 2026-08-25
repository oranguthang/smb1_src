; -------------------------------------------------------------------------------------
; $00-$01 - used to hold many values, essentially temp variables
; $04 - holds lower nybble of vertical coordinate from block buffer routine
; $eb - used to hold block buffer adder

PlayerBGUpperExtent:
    .byte $20, $10

sub_player_bg_collision:
    LDA ram_disable_collision_det  ; if collision detection disabled flag set,
    BNE ExPBGCol  ; branch to leave
    LDA ram_game_engine_subroutine
    CMP #$0b  ; if running routine #11 or $0b
    BEQ ExPBGCol  ; branch to leave
    CMP #$04
    BCC ExPBGCol  ; if running routines $00-$03 branch to leave
    LDA #$01  ; load default player state for swimming
    LDY ram_swimming_flag  ; if swimming flag set,
    BNE SetPSte  ; branch ahead to set default state
    LDA ram_player_state  ; if player in normal state,
    BEQ SetFallS  ; branch to set default state for falling
    CMP #$03
    BNE ChkOnScr  ; if in any other state besides climbing, skip to next part
SetFallS:
    LDA #$02  ; load default player state for falling
SetPSte:
    STA ram_player_state  ; set whatever player state is appropriate
ChkOnScr:
    LDA ram_player_y_high_pos
    CMP #$01  ; check player's vertical high byte for still on the screen
    BNE ExPBGCol  ; branch to leave if not
    LDA #$ff
    STA ram_player_collision_bits  ; initialize player's collision flag
    LDA ram_player_y_position
    CMP #$cf  ; check player's vertical coordinate
    BCC ChkCollSize  ; if not too close to the bottom of screen, continue
ExPBGCol:
    RTS  ; otherwise leave

ChkCollSize:
    LDY #$02  ; load default offset
    LDA ram_crouching_flag
    BNE GBBAdr  ; if player crouching, skip ahead
    LDA ram_player_size
    BNE GBBAdr  ; if player small, skip ahead
    DEY  ; otherwise decrement offset for big player not crouching
    LDA ram_swimming_flag
    BNE GBBAdr  ; if swimming flag set, skip ahead
    DEY  ; otherwise decrement offset
GBBAdr:
    LDA BlockBufferAdderData,y  ; get value using offset
    STA $eb  ; store value here
    TAY  ; put value into Y, as offset for block buffer routine
    LDX ram_player_size  ; get player's size as offset
    LDA ram_crouching_flag
    BEQ HeadChk  ; if player not crouching, branch ahead
    INX  ; otherwise increment size as offset
HeadChk:
    LDA ram_player_y_position  ; get player's vertical coordinate
    CMP PlayerBGUpperExtent,x  ; compare with upper extent value based on offset
    BCC DoFootCheck  ; if player is too high, skip this part
    JSR sub_block_buffer_colli_head  ; do player-to-bg collision detection on top of
    BEQ DoFootCheck  ; player, and branch if nothing above player's head
    JSR sub_check_for_coin_m_tiles  ; check to see if player touched coin with their head
    BCS AwardTouchedCoin  ; if so, branch to some other part of code
    LDY ram_player_y_speed  ; check player's vertical speed
    BPL DoFootCheck  ; if player not moving upwards, branch elsewhere
    LDY $04  ; check lower nybble of vertical coordinate returned
    CPY #$04  ; from collision detection routine
    BCC DoFootCheck  ; if low nybble < 4, branch
    JSR sub_check_for_solid_m_tiles  ; check to see what player's head bumped on
    BCS SolidOrClimb  ; if player collided with solid metatile, branch
    LDY ram_area_type  ; otherwise check area type
    BEQ NYSpd  ; if water level, branch ahead
    LDY ram_block_bounce_timer  ; if block bounce timer not expired,
    BNE NYSpd  ; branch ahead, do not process collision
    JSR sub_player_head_collision  ; otherwise do a sub to process collision
    JMP DoFootCheck  ; jump ahead to skip these other parts here

SolidOrClimb:
    CMP #$26  ; if climbing metatile,
    BEQ NYSpd  ; branch ahead and do not play sound
    LDA #con_sfx_bump
    STA ram_square1_sound_queue  ; otherwise load bump sound
NYSpd:
    LDA #$01  ; set player's vertical speed to nullify
    STA ram_player_y_speed  ; jump or swim

DoFootCheck:
    LDY $eb  ; get block buffer adder offset
    LDA ram_player_y_position
    CMP #$cf  ; check to see how low player is
    BCS DoPlayerSideCheck  ; if player is too far down on screen, skip all of this
    JSR sub_block_buffer_colli_feet  ; do player-to-bg collision detection on bottom left of player
    JSR sub_check_for_coin_m_tiles  ; check to see if player touched coin with their left foot
    BCS AwardTouchedCoin  ; if so, branch to some other part of code
    PHA  ; save bottom left metatile to stack
    JSR sub_block_buffer_colli_feet  ; do player-to-bg collision detection on bottom right of player
    STA $00  ; save bottom right metatile here
    PLA
    STA $01  ; pull bottom left metatile and save here
    BNE ChkFootMTile  ; if anything here, skip this part
    LDA $00  ; otherwise check for anything in bottom right metatile
    BEQ DoPlayerSideCheck  ; and skip ahead if not
    JSR sub_check_for_coin_m_tiles  ; check to see if player touched coin with their right foot
    BCC ChkFootMTile  ; if not, skip unconditional jump and continue code

AwardTouchedCoin:
    JMP HandleCoinMetatile  ; follow the code to erase coin and award to player 1 coin

ChkFootMTile:
    JSR sub_check_for_climb_m_tiles  ; check to see if player landed on climbable metatiles
    BCS DoPlayerSideCheck  ; if so, branch
    LDY ram_player_y_speed  ; check player's vertical speed
    BMI DoPlayerSideCheck  ; if player moving upwards, branch
    CMP #$c5
    BNE ContChk  ; if player did not touch axe, skip ahead
    JMP HandleAxeMetatile  ; otherwise jump to set modes of operation
ContChk:
    JSR sub_chk_invisible_m_tiles  ; do sub to check for hidden coin or 1-up blocks
    BEQ DoPlayerSideCheck  ; if either found, branch
    LDY ram_jumpspring_anim_ctrl  ; if jumpspring animating right now,
    BNE InitSteP  ; branch ahead
    LDY $04  ; check lower nybble of vertical coordinate returned
    CPY #$05  ; from collision detection routine
    BCC LandPlyr  ; if lower nybble < 5, branch
    LDA ram_player_moving_dir
    STA $00  ; use player's moving direction as temp variable
    JMP sub_impede_player_move  ; jump to impede player's movement in that direction
LandPlyr:
    JSR sub_chk_for_land_jump_spring  ; do sub to check for jumpspring metatiles and deal with it
    LDA #$f0
    AND ram_player_y_position  ; mask out lower nybble of player's vertical position
    STA ram_player_y_position  ; and store as new vertical position to land player properly
    JSR sub_handle_pipe_entry  ; do sub to process potential pipe entry
    LDA #$00
    STA ram_player_y_speed  ; initialize vertical speed and fractional
    STA ram_player_y_move_force  ; movement force to stop player's vertical movement
    STA ram_stomp_chain_counter  ; initialize enemy stomp counter
InitSteP:
    LDA #$00
    STA ram_player_state  ; set player's state to normal

DoPlayerSideCheck:
    LDY $eb  ; get block buffer adder offset
    INY
    INY  ; increment offset 2 bytes to use adders for side collisions
    LDA #$02  ; set value here to be used as counter
    STA $00

SideCheckLoop:
    INY  ; move onto the next one
    STY $eb  ; store it
    LDA ram_player_y_position
    CMP #$20  ; check player's vertical position
    BCC BHalf  ; if player is in status bar area, branch ahead to skip this part
    CMP #$e4
    BCS ExSCH  ; branch to leave if player is too far down
    JSR sub_block_buffer_colli_side  ; do player-to-bg collision detection on one half of player
    BEQ BHalf  ; branch ahead if nothing found
    CMP #$1c  ; otherwise check for pipe metatiles
    BEQ BHalf  ; if collided with sideways pipe (top), branch ahead
    CMP #$6b
    BEQ BHalf  ; if collided with water pipe (top), branch ahead
    JSR sub_check_for_climb_m_tiles  ; do sub to see if player bumped into anything climbable
    BCC CheckSideMTiles  ; if not, branch to alternate section of code
BHalf:
    LDY $eb  ; load block adder offset
    INY  ; increment it
    LDA ram_player_y_position  ; get player's vertical position
    CMP #$08
    BCC ExSCH  ; if too high, branch to leave
    CMP #$d0
    BCS ExSCH  ; if too low, branch to leave
    JSR sub_block_buffer_colli_side  ; do player-to-bg collision detection on other half of player
    BNE CheckSideMTiles  ; if something found, branch
    DEC $00  ; otherwise decrement counter
    BNE SideCheckLoop  ; run code until both sides of player are checked
ExSCH:
    RTS  ; leave

CheckSideMTiles:
    JSR sub_chk_invisible_m_tiles  ; check for hidden or coin 1-up blocks
    BEQ ExCSM  ; branch to leave if either found
    JSR sub_check_for_climb_m_tiles  ; check for climbable metatiles
    BCC ContSChk  ; if not found, skip and continue with code
    JMP HandleClimbing  ; otherwise jump to handle climbing
ContSChk:
    JSR sub_check_for_coin_m_tiles  ; check to see if player touched coin
    BCS HandleCoinMetatile  ; if so, execute code to erase coin and award to player 1 coin
    JSR sub_chk_jumpspring_metatiles  ; check for jumpspring metatiles
    BCC ChkPBtm  ; if not found, branch ahead to continue cude
    LDA ram_jumpspring_anim_ctrl  ; otherwise check jumpspring animation control
    BNE ExCSM  ; branch to leave if set
    JMP StopPlayerMove  ; otherwise jump to impede player's movement
ChkPBtm:
    LDY ram_player_state  ; get player's state
    CPY #$00  ; check for player's state set to normal
    BNE StopPlayerMove  ; if not, branch to impede player's movement
    LDY ram_player_facing_dir  ; get player's facing direction
    DEY
    BNE StopPlayerMove  ; if facing left, branch to impede movement
    CMP #$6c  ; otherwise check for pipe metatiles
    BEQ PipeDwnS  ; if collided with sideways pipe (bottom), branch
    CMP #$1f  ; if collided with water pipe (bottom), continue
    BNE StopPlayerMove  ; otherwise branch to impede player's movement
PipeDwnS:
    LDA ram_player_spr_attrib  ; check player's attributes
    BNE PlyrPipe  ; if already set, branch, do not play sound again
    LDY #con_sfx_pipe_down_injury
    STY ram_square1_sound_queue  ; otherwise load pipedown/injury sound
PlyrPipe:
    ORA #%00100000
    STA ram_player_spr_attrib  ; set background priority bit in player attributes
    LDA ram_player_x_position
    AND #%00001111  ; get lower nybble of player's horizontal coordinate
    BEQ ChkGERtn  ; if at zero, branch ahead to skip this part
    LDY #$00  ; set default offset for timer setting data
    LDA ram_screen_left_page_loc  ; load page location for left side of screen
    BEQ SetCATmr  ; if at page zero, use default offset
    INY  ; otherwise increment offset
SetCATmr:
    LDA AreaChangeTimerData,y  ; set timer for change of area as appropriate
    STA ram_change_area_timer
ChkGERtn:
    LDA ram_game_engine_subroutine  ; get number of game engine routine running
    CMP #$07
    BEQ ExCSM  ; if running player entrance routine or
    CMP #$08  ; player control routine, go ahead and branch to leave
    BNE ExCSM
    LDA #$02
    STA ram_game_engine_subroutine  ; otherwise set sideways pipe entry routine to run
    RTS  ; and leave

; --------------------------------
; $02 - high nybble of vertical coordinate from block buffer
; $04 - low nybble of horizontal coordinate from block buffer
; $06-$07 - block buffer address

StopPlayerMove:
    JSR sub_impede_player_move  ; stop player's movement
ExCSM:
    RTS  ; leave

AreaChangeTimerData:
    .byte $a0, $34

HandleCoinMetatile:
    JSR sub_er_acm  ; do sub to erase coin metatile from block buffer
    INC ram_coin_tally_for1_ups  ; increment coin tally used for 1-up blocks
    JMP sub_give_one_coin  ; update coin amount and tally on the screen

HandleAxeMetatile:
    LDA #$00
    STA ram_oper_mode_task  ; reset secondary mode
    LDA #$02
    STA ram_oper_mode  ; set primary mode to autoctrl mode
    LDA #$18
    STA ram_player_x_speed  ; set horizontal speed and continue to erase axe metatile
sub_er_acm:
    LDY $02  ; load vertical high nybble offset for block buffer
    LDA #$00  ; load blank metatile
    STA ($06),y  ; store to remove old contents from block buffer
    JMP sub_remove_coin_axe  ; update the screen accordingly

; --------------------------------
; $02 - high nybble of vertical coordinate from block buffer
; $04 - low nybble of horizontal coordinate from block buffer
; $06-$07 - block buffer address

ClimbXPosAdder:
    .byte $f9, $07

ClimbPLocAdder:
    .byte $ff, $00

FlagpoleYPosData:
    .byte $18, $22, $50, $68, $90

HandleClimbing:
    LDY $04  ; check low nybble of horizontal coordinate returned from
    CPY #$06  ; collision detection routine against certain values, this
    BCC ExHC  ; makes actual physical part of vine or flagpole thinner
    CPY #$0a  ; than 16 pixels
    BCC ChkForFlagpole
ExHC:
    RTS  ; leave if too far left or too far right

ChkForFlagpole:
    CMP #$24  ; check climbing metatiles
    BEQ FlagpoleCollision  ; branch if flagpole ball found
    CMP #$25
    BNE VineCollision  ; branch to alternate code if flagpole shaft not found

FlagpoleCollision:
    LDA ram_game_engine_subroutine
    CMP #$05  ; check for end-of-level routine running
    BEQ PutPlayerOnVine  ; if running, branch to end of climbing code
    LDA #$01
    STA ram_player_facing_dir  ; set player's facing direction to right
    INC ram_scroll_lock  ; set scroll lock flag
    LDA ram_game_engine_subroutine
    CMP #$04  ; check for flagpole slide routine running
    BEQ RunFR  ; if running, branch to end of flagpole code here
    LDA #con_bullet_bill_cannon_var  ; load identifier for bullet bills (cannon variant)
    JSR sub_kill_enemies  ; get rid of them
    LDA #con_silence
    STA ram_event_music_queue  ; silence music
    LSR
    STA ram_flagpole_sound_queue  ; load flagpole sound into flagpole sound queue
    LDX #$04  ; start at end of vertical coordinate data
    LDA ram_player_y_position
    STA ram_flagpole_collision_y_pos  ; store player's vertical coordinate here to be used later

ChkFlagpoleYPosLoop:
    CMP FlagpoleYPosData,x  ; compare with current vertical coordinate data
    BCS MtchF  ; if player's => current, branch to use current offset
    DEX  ; otherwise decrement offset to use
    BNE ChkFlagpoleYPosLoop  ; do this until all data is checked (use last one if all checked)
MtchF:
    STX ram_flagpole_score  ; store offset here to be used later
RunFR:
    LDA #$04
    STA ram_game_engine_subroutine  ; set value to run flagpole slide routine
    JMP PutPlayerOnVine  ; jump to end of climbing code

VineCollision:
    CMP #$26  ; check for climbing metatile used on vines
    BNE PutPlayerOnVine
    LDA ram_player_y_position  ; check player's vertical coordinate
    CMP #$20  ; for being in status bar area
    BCS PutPlayerOnVine  ; branch if not that far up
    LDA #$01
    STA ram_game_engine_subroutine  ; otherwise set to run autoclimb routine next frame

PutPlayerOnVine:
    LDA #$03  ; set player state to climbing
    STA ram_player_state
    LDA #$00  ; nullify player's horizontal speed
    STA ram_player_x_speed  ; and fractional horizontal movement force
    STA ram_player_x_move_force
    LDA ram_player_x_position  ; get player's horizontal coordinate
    SEC
    SBC ram_screen_left_x_pos  ; subtract from left side horizontal coordinate
    CMP #$10
    BCS SetVXPl  ; if 16 or more pixels difference, do not alter facing direction
    LDA #$02
    STA ram_player_facing_dir  ; otherwise force player to face left
SetVXPl:
    LDY ram_player_facing_dir  ; get current facing direction, use as offset
    LDA $06  ; get low byte of block buffer address
    ASL
    ASL  ; move low nybble to high
    ASL
    ASL
    CLC
    ADC ClimbXPosAdder-1,y  ; add pixels depending on facing direction
    STA ram_player_x_position  ; store as player's horizontal coordinate
    LDA $06  ; get low byte of block buffer address again
    BNE ExPVne  ; if not zero, branch
    LDA ram_screen_right_page_loc  ; load page location of right side of screen
    CLC
    ADC ClimbPLocAdder-1,y  ; add depending on facing location
    STA ram_player_page_loc  ; store as player's page location
ExPVne:
    RTS  ; finally, we're done!

; --------------------------------

sub_chk_invisible_m_tiles:
    CMP #$5f  ; check for hidden coin block
    BEQ ExCInvT  ; branch to leave if found
    CMP #$60  ; check for hidden 1-up block
ExCInvT:
    RTS  ; leave with zero flag set if either found

; --------------------------------
; $00-$01 - used to hold bottom right and bottom left metatiles (in that order)
; $00 - used as flag by sub_impede_player_move to restrict specific movement

sub_chk_for_land_jump_spring:
    JSR sub_chk_jumpspring_metatiles  ; do sub to check if player landed on jumpspring
    BCC ExCJSp  ; if carry not set, jumpspring not found, therefore leave
    LDA #$70
    STA ram_vertical_force  ; otherwise set vertical movement force for player
    LDA #$f9
    STA ram_jumpspring_force  ; set default jumpspring force
    LDA #$03
    STA ram_jumpspring_timer  ; set jumpspring timer to be used later
    LSR
    STA ram_jumpspring_anim_ctrl  ; set jumpspring animation control to start animating
ExCJSp:
    RTS  ; and leave

sub_chk_jumpspring_metatiles:
    CMP #$67  ; check for top jumpspring metatile
    BEQ JSFnd  ; branch to set carry if found
    CMP #$68  ; check for bottom jumpspring metatile
    CLC  ; clear carry flag
    BNE NoJSFnd  ; branch to use cleared carry if not found
JSFnd:
    SEC  ; set carry if found
NoJSFnd:
    RTS  ; leave

sub_handle_pipe_entry:
    LDA ram_up_down_buttons  ; check saved controller bits from earlier
    AND #%00000100  ; for pressing down
    BEQ ExPipeE  ; if not pressing down, branch to leave
    LDA $00
    CMP #$11  ; check right foot metatile for warp pipe right metatile
    BNE ExPipeE  ; branch to leave if not found
    LDA $01
    CMP #$10  ; check left foot metatile for warp pipe left metatile
    BNE ExPipeE  ; branch to leave if not found
    LDA #$30
    STA ram_change_area_timer  ; set timer for change of area
    LDA #$03
    STA ram_game_engine_subroutine  ; set to run vertical pipe entry routine on next frame
    LDA #con_sfx_pipe_down_injury
    STA ram_square1_sound_queue  ; load pipedown/injury sound
    LDA #%00100000
    STA ram_player_spr_attrib  ; set background priority bit in player's attributes
    LDA ram_warp_zone_control  ; check warp zone control
    BEQ ExPipeE  ; branch to leave if none found
    AND #%00000011  ; mask out all but 2 LSB
    ASL
    ASL  ; multiply by four
    TAX  ; save as offset to warp zone numbers (starts at left pipe)
    LDA ram_player_x_position  ; get player's horizontal position
    CMP #$60
    BCC GetWNum  ; if player at left, not near middle, use offset and skip ahead
    INX  ; otherwise increment for middle pipe
    CMP #$a0
    BCC GetWNum  ; if player at middle, but not too far right, use offset and skip
    INX  ; otherwise increment for last pipe
GetWNum:
    LDY WarpZoneNumbers,x  ; get warp zone numbers
    DEY  ; decrement for use as world number
    STY ram_world_number  ; store as world number and offset
    LDX WorldAddrOffsets,y  ; get offset to where this world's area offsets are
    LDA AreaAddrOffsets,x  ; get area offset based on world offset
    STA ram_area_pointer  ; store area offset here to be used to change areas
    LDA #con_silence
    STA ram_event_music_queue  ; silence music
    LDA #$00
    STA ram_entrance_page  ; initialize starting page number
    STA ram_area_number  ; initialize area number used for area address offset
    STA ram_level_number  ; initialize level number used for world display
    STA ram_alt_entrance_control  ; initialize mode of entry
    INC ram_hidden1_up_flag  ; set flag for hidden 1-up blocks
    INC ram_fetch_new_game_timer_flag  ; set flag to load new game timer
ExPipeE:
    RTS  ; leave!!!

sub_impede_player_move:
    LDA #$00  ; initialize value here
    LDY ram_player_x_speed  ; get player's horizontal speed
    LDX $00  ; check value set earlier for
    DEX  ; left side collision
    BNE RImpd  ; if right side collision, skip this part
    INX  ; return value to X
    CPY #$00  ; if player moving to the left,
    BMI ExIPM  ; branch to invert bit and leave
    LDA #$ff  ; otherwise load A with value to be used later
    JMP NXSpd  ; and jump to affect movement
RImpd:
    LDX #$02  ; return $02 to X
    CPY #$01  ; if player moving to the right,
    BPL ExIPM  ; branch to invert bit and leave
    LDA #$01  ; otherwise load A with value to be used here
NXSpd:
    LDY #$10
    STY ram_side_collision_timer  ; set timer of some sort
    LDY #$00
    STY ram_player_x_speed  ; nullify player's horizontal speed
    CMP #$00  ; if value set in A not set to $ff,
    BPL PlatF  ; branch ahead, do not decrement Y
    DEY  ; otherwise decrement Y now
PlatF:
    STY $00  ; store Y as high bits of horizontal adder
    CLC
    ADC ram_player_x_position  ; add contents of A to player's horizontal
    STA ram_player_x_position  ; position to move player left or right
    LDA ram_player_page_loc
    ADC $00  ; add high bits and carry to
    STA ram_player_page_loc  ; page location if necessary
ExIPM:
    TXA  ; invert contents of X
    EOR #$ff
    AND ram_player_collision_bits  ; mask out bit that was set here
    STA ram_player_collision_bits  ; store to clear bit
    RTS

; --------------------------------

SolidMTileUpperExt:
    .byte $10, $61, $88, $c4

sub_check_for_solid_m_tiles:
    JSR sub_get_m_tile_attrib  ; find appropriate offset based on metatile's 2 MSB
    CMP SolidMTileUpperExt,x  ; compare current metatile with solid metatiles
    RTS

ClimbMTileUpperExt:
    .byte $24, $6d, $8a, $c6

sub_check_for_climb_m_tiles:
    JSR sub_get_m_tile_attrib  ; find appropriate offset based on metatile's 2 MSB
    CMP ClimbMTileUpperExt,x  ; compare current metatile with climbable metatiles
    RTS

sub_check_for_coin_m_tiles:
    CMP #$c2  ; check for regular coin
    BEQ CoinSd  ; branch if found
    CMP #$c3  ; check for underwater coin
    BEQ CoinSd  ; branch if found
    CLC  ; otherwise clear carry and leave
    RTS
CoinSd:
    LDA #con_sfx_coin_grab
    STA ram_square2_sound_queue  ; load coin grab sound and leave
    RTS

sub_get_m_tile_attrib:
    TAY  ; save metatile value into Y
    AND #%11000000  ; mask out all but 2 MSB
    ASL
    ROL  ; shift and rotate d7-d6 to d1-d0
    ROL
    TAX  ; use as offset for metatile data
    TYA  ; get original metatile value back
ExEBG:
    RTS  ; leave
