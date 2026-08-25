; -------------------------------------------------------------------------------------
; $00 - used to store downward movement force in FireballObjCore
; $02 - used to store maximum vertical speed in FireballObjCore
; $07 - used to store pseudorandom bit in BubbleCheck

ProcFireball_Bubble:
    LDA ram_player_status  ; check player's status
    CMP #$02
    BCC ProcAirBubbles  ; if not fiery, branch
    LDA ram_a_b_buttons
    AND #con_btn_b  ; check for b button pressed
    BEQ ProcFireballs  ; branch if not pressed
    AND ram_previous_a_b_buttons
    BNE ProcFireballs  ; if button pressed in previous frame, branch
    LDA ram_fireball_counter  ; load fireball counter
    AND #%00000001  ; get LSB and use as offset for buffer
    TAX
    LDA ram_fireball_state,x  ; load fireball state
    BNE ProcFireballs  ; if not inactive, branch
    LDY ram_player_y_high_pos  ; if player too high or too low, branch
    DEY
    BNE ProcFireballs
    LDA ram_crouching_flag  ; if player crouching, branch
    BNE ProcFireballs
    LDA ram_player_state  ; if player's state = climbing, branch
    CMP #$03
    BEQ ProcFireballs
    LDA #con_sfx_fireball  ; play fireball sound effect
    STA ram_square1_sound_queue
    LDA #$02  ; load state
    STA ram_fireball_state,x
    LDY ram_player_anim_timer_set  ; copy animation frame timer setting
    STY ram_fireball_throwing_timer  ; into fireball throwing timer
    DEY
    STY ram_player_anim_timer  ; decrement and store in player's animation timer
    INC ram_fireball_counter  ; increment fireball counter

ProcFireballs:
    LDX #$00
    JSR FireballObjCore  ; process first fireball object
    LDX #$01
    JSR FireballObjCore  ; process second fireball object, then do air bubbles

ProcAirBubbles:
    LDA ram_area_type  ; if not water type level, skip the rest of this
    BNE BublExit
    LDX #$02  ; otherwise load counter and use as offset
BublLoop:
    STX ram_object_offset  ; store offset
    JSR BubbleCheck  ; check timers and coordinates, create air bubble
    JSR RelativeBubblePosition  ; get relative coordinates
    JSR GetBubbleOffscreenBits  ; get offscreen information
    JSR DrawBubble  ; draw the air bubble
    DEX
    BPL BublLoop  ; do this until all three are handled
BublExit:
    RTS  ; then leave

FireballXSpdData:
    .byte $40, $c0

FireballObjCore:
    STX ram_object_offset  ; store offset as current object
    LDA ram_fireball_state,x  ; check for d7 = 1
    ASL
    BCS FireballExplosion  ; if so, branch to get relative coordinates and draw explosion
    LDY ram_fireball_state,x  ; if fireball inactive, branch to leave
    BEQ NoFBall
    DEY  ; if fireball state set to 1, skip this part and just run it
    BEQ RunFB
    LDA ram_player_x_position  ; get player's horizontal position
    ADC #$04  ; add four pixels and store as fireball's horizontal position
    STA ram_fireball_x_position,x
    LDA ram_player_page_loc  ; get player's page location
    ADC #$00  ; add carry and store as fireball's page location
    STA ram_fireball_page_loc,x
    LDA ram_player_y_position  ; get player's vertical position and store
    STA ram_fireball_y_position,x
    LDA #$01  ; set high byte of vertical position
    STA ram_fireball_y_high_pos,x
    LDY ram_player_facing_dir  ; get player's facing direction
    DEY  ; decrement to use as offset here
    LDA FireballXSpdData,y  ; set horizontal speed of fireball accordingly
    STA ram_fireball_x_speed,x
    LDA #$04  ; set vertical speed of fireball
    STA ram_fireball_y_speed,x
    LDA #$07
    STA ram_fireball_bound_box_ctrl,x  ; set bounding box size control for fireball
    DEC ram_fireball_state,x  ; decrement state to 1 to skip this part from now on
RunFB:
    TXA  ; add 7 to offset to use
    CLC  ; as fireball offset for next routines
    ADC #$07
    TAX
    LDA #$50  ; set downward movement force here
    STA $00
    LDA #$03  ; set maximum speed here
    STA $02
    LDA #$00
    JSR sub_apply_object_gravity  ; do sub here to impose gravity on fireball and move vertically
    JSR sub_move_object_horizontally  ; do another sub to move it horizontally
    LDX ram_object_offset  ; return fireball offset to X
    JSR RelativeFireballPosition  ; get relative coordinates
    JSR GetFireballOffscreenBits  ; get offscreen information
    JSR GetFireballBoundBox  ; get bounding box coordinates
    JSR FireballBGCollision  ; do fireball to background collision detection
    LDA ram_f_ball_offscreen_bits  ; get fireball offscreen bits
    AND #%11001100  ; mask out certain bits
    BNE EraseFB  ; if any bits still set, branch to kill fireball
    JSR FireballEnemyCollision  ; do fireball to enemy collision detection and deal with collisions
    JMP DrawFireball  ; draw fireball appropriately and leave
EraseFB:
    LDA #$00  ; erase fireball state
    STA ram_fireball_state,x
NoFBall:
    RTS  ; leave

FireballExplosion:
    JSR RelativeFireballPosition
    JMP DrawExplosion_Fireball

BubbleCheck:
    LDA ram_pseudo_random_bit_reg+1,x  ; get part of LSFR
    AND #$01
    STA $07  ; store pseudorandom bit here
    LDA ram_bubble_y_position,x  ; get vertical coordinate for air bubble
    CMP #$f8  ; if offscreen coordinate not set,
    BNE MoveBubl  ; branch to move air bubble
    LDA ram_air_bubble_timer  ; if air bubble timer not expired,
    BNE ExitBubl  ; branch to leave, otherwise create new air bubble

SetupBubble:
    LDY #$00  ; load default value here
    LDA ram_player_facing_dir  ; get player's facing direction
    LSR  ; move d0 to carry
    BCC PosBubl  ; branch to use default value if facing left
    LDY #$08  ; otherwise load alternate value here
PosBubl:
    TYA  ; use value loaded as adder
    ADC ram_player_x_position  ; add to player's horizontal position
    STA ram_bubble_x_position,x  ; save as horizontal position for airbubble
    LDA ram_player_page_loc
    ADC #$00  ; add carry to player's page location
    STA ram_bubble_page_loc,x  ; save as page location for airbubble
    LDA ram_player_y_position
    CLC  ; add eight pixels to player's vertical position
    ADC #$08
    STA ram_bubble_y_position,x  ; save as vertical position for air bubble
    LDA #$01
    STA ram_bubble_y_high_pos,x  ; set vertical high byte for air bubble
    LDY $07  ; get pseudorandom bit, use as offset
    LDA BubbleTimerData,y  ; get data for air bubble timer
    STA ram_air_bubble_timer  ; set air bubble timer
MoveBubl:
    LDY $07  ; get pseudorandom bit again, use as offset
    LDA ram_bubble_ymf_dummy,x
    SEC  ; subtract pseudorandom amount from dummy variable
    SBC Bubble_MForceData,y
    STA ram_bubble_ymf_dummy,x  ; save dummy variable
    LDA ram_bubble_y_position,x
    SBC #$00  ; subtract borrow from airbubble's vertical coordinate
    CMP #$20  ; if below the status bar,
    BCS Y_Bubl  ; branch to go ahead and use to move air bubble upwards
    LDA #$f8  ; otherwise set offscreen coordinate
Y_Bubl:
    STA ram_bubble_y_position,x  ; store as new vertical coordinate for air bubble
ExitBubl:
    RTS  ; leave

Bubble_MForceData:
    .byte $ff, $50

BubbleTimerData:
    .byte $40, $20

; -------------------------------------------------------------------------------------

RunGameTimer:
    LDA ram_oper_mode  ; get primary mode of operation
    BEQ ExGTimer  ; branch to leave if in title screen mode
    LDA ram_game_engine_subroutine
    CMP #$08  ; if routine number less than eight running,
    BCC ExGTimer  ; branch to leave
    CMP #$0b  ; if running death routine,
    BEQ ExGTimer  ; branch to leave
    LDA ram_player_y_high_pos
    CMP #$02  ; if player below the screen,
    BCS ExGTimer  ; branch to leave regardless of level type
    LDA ram_game_timer_ctrl_timer  ; if game timer control not yet expired,
    BNE ExGTimer  ; branch to leave
    LDA ram_game_timer_display
    ORA ram_game_timer_display+1  ; otherwise check game timer digits
    ORA ram_game_timer_display+2
    BEQ TimeUpOn  ; if game timer digits at 000, branch to time-up code
    LDY ram_game_timer_display  ; otherwise check first digit
    DEY  ; if first digit not on 1,
    BNE ResGTCtrl  ; branch to reset game timer control
    LDA ram_game_timer_display+1  ; otherwise check second and third digits
    ORA ram_game_timer_display+2
    BNE ResGTCtrl  ; if timer not at 100, branch to reset game timer control
    LDA #con_time_running_out_music
    STA ram_event_music_queue  ; otherwise load time running out music
ResGTCtrl:
    LDA #$18  ; reset game timer control
    STA ram_game_timer_ctrl_timer
    LDY #$23  ; set offset for last digit
    LDA #$ff  ; set value to decrement game timer digit
    STA ram_digit_modifier+5
    JSR DigitsMathRoutine  ; do sub to decrement game timer slowly
    LDA #$a4  ; set status nybbles to update game timer display
    JMP PrintStatusBarNumbers  ; do sub to update the display
TimeUpOn:
    STA ram_player_status  ; init player status (note A will always be zero here)
    JSR ForceInjury  ; do sub to kill the player (note player is small here)
    INC ram_game_timer_expired_flag  ; set game timer expiration flag
ExGTimer:
    RTS  ; leave

; -------------------------------------------------------------------------------------

WarpZoneObject:
    LDA ram_scroll_lock  ; check for scroll lock flag
    BEQ ExGTimer  ; branch if not set to leave
    LDA ram_player_y_position  ; check to see if player's vertical coordinate has
    AND ram_player_y_high_pos  ; same bits set as in vertical high byte (why?)
    BNE ExGTimer  ; if so, branch to leave
    STA ram_scroll_lock  ; otherwise nullify scroll lock flag
    INC ram_warp_zone_control  ; increment warp zone flag to make warp pipes for warp zone
    JMP EraseEnemyObject  ; kill this object

; -------------------------------------------------------------------------------------
; $00 - used in WhirlpoolActivate to store whirlpool length / 2, page location of center of whirlpool
; and also to store movement force exerted on player
; $01 - used in ProcessWhirlpools to store page location of right extent of whirlpool
; and in WhirlpoolActivate to store center of whirlpool
; $02 - used in ProcessWhirlpools to store right extent of whirlpool and in
; WhirlpoolActivate to store maximum vertical speed

ProcessWhirlpools:
    LDA ram_area_type  ; check for water type level
    BNE ExitWh  ; branch to leave if not found
    STA ram_whirlpool_flag  ; otherwise initialize whirlpool flag
    LDA ram_timer_control  ; if master timer control set,
    BNE ExitWh  ; branch to leave
    LDY #$04  ; otherwise start with last whirlpool data
WhLoop:
    LDA ram_whirlpool_left_extent,y  ; get left extent of whirlpool
    CLC
    ADC ram_whirlpool_length,y  ; add length of whirlpool
    STA $02  ; store result as right extent here
    LDA ram_whirlpool_page_loc,y  ; get page location
    BEQ NextWh  ; if none or page 0, branch to get next data
    ADC #$00  ; add carry
    STA $01  ; store result as page location of right extent here
    LDA ram_player_x_position  ; get player's horizontal position
    SEC
    SBC ram_whirlpool_left_extent,y  ; subtract left extent
    LDA ram_player_page_loc  ; get player's page location
    SBC ram_whirlpool_page_loc,y  ; subtract borrow
    BMI NextWh  ; if player too far left, branch to get next data
    LDA $02  ; otherwise get right extent
    SEC
    SBC ram_player_x_position  ; subtract player's horizontal coordinate
    LDA $01  ; get right extent's page location
    SBC ram_player_page_loc  ; subtract borrow
    BPL WhirlpoolActivate  ; if player within right extent, branch to whirlpool code
NextWh:
    DEY  ; move onto next whirlpool data
    BPL WhLoop  ; do this until all whirlpools are checked
ExitWh:
    RTS  ; leave

WhirlpoolActivate:
    LDA ram_whirlpool_length,y  ; get length of whirlpool
    LSR  ; divide by 2
    STA $00  ; save here
    LDA ram_whirlpool_left_extent,y  ; get left extent of whirlpool
    CLC
    ADC $00  ; add length divided by 2
    STA $01  ; save as center of whirlpool
    LDA ram_whirlpool_page_loc,y  ; get page location
    ADC #$00  ; add carry
    STA $00  ; save as page location of whirlpool center
    LDA ram_frame_counter  ; get frame counter
    LSR  ; shift d0 into carry (to run on every other frame)
    BCC WhPull  ; if d0 not set, branch to last part of code
    LDA $01  ; get center
    SEC
    SBC ram_player_x_position  ; subtract player's horizontal coordinate
    LDA $00  ; get page location of center
    SBC ram_player_page_loc  ; subtract borrow
    BPL LeftWh  ; if player to the left of center, branch
    LDA ram_player_x_position  ; otherwise slowly pull player left, towards the center
    SEC
    SBC #$01  ; subtract one pixel
    STA ram_player_x_position  ; set player's new horizontal coordinate
    LDA ram_player_page_loc
    SBC #$00  ; subtract borrow
    JMP SetPWh  ; jump to set player's new page location
LeftWh:
    LDA ram_player_collision_bits  ; get player's collision bits
    LSR  ; shift d0 into carry
    BCC WhPull  ; if d0 not set, branch
    LDA ram_player_x_position  ; otherwise slowly pull player right, towards the center
    CLC
    ADC #$01  ; add one pixel
    STA ram_player_x_position  ; set player's new horizontal coordinate
    LDA ram_player_page_loc
    ADC #$00  ; add carry
SetPWh:
    STA ram_player_page_loc  ; set player's new page location
WhPull:
    LDA #$10
    STA $00  ; set vertical movement force
    LDA #$01
    STA ram_whirlpool_flag  ; set whirlpool flag to be used later
    STA $02  ; also set maximum vertical speed
    LSR
    TAX  ; set X for player offset
    JMP sub_apply_object_gravity  ; jump to put whirlpool effect on player vertically, do not return

; -------------------------------------------------------------------------------------

FlagpoleScoreMods:
    .byte $05, $02, $08, $04, $01

FlagpoleScoreDigits:
    .byte $03, $03, $04, $04, $04

FlagpoleRoutine:
    LDX #$05  ; set enemy object offset
    STX ram_object_offset  ; to special use slot
    LDA ram_enemy_id,x
    CMP #con_flagpole_flag_object  ; if flagpole flag not found,
    BNE ExitFlagP  ; branch to leave
    LDA ram_game_engine_subroutine
    CMP #$04  ; if flagpole slide routine not running,
    BNE SkipScore  ; branch to near the end of code
    LDA ram_player_state
    CMP #$03  ; if player state not climbing,
    BNE SkipScore  ; branch to near the end of code
    LDA ram_enemy_y_position,x  ; check flagpole flag's vertical coordinate
    CMP #$aa  ; if flagpole flag down to a certain point,
    BCS GiveFPScr  ; branch to end the level
    LDA ram_player_y_position  ; check player's vertical coordinate
    CMP #$a2  ; if player down to a certain point,
    BCS GiveFPScr  ; branch to end the level
    LDA ram_enemy_ymf_dummy,x
    ADC #$ff  ; add movement amount to dummy variable
    STA ram_enemy_ymf_dummy,x  ; save dummy variable
    LDA ram_enemy_y_position,x  ; get flag's vertical coordinate
    ADC #$01  ; add 1 plus carry to move flag, and
    STA ram_enemy_y_position,x  ; store vertical coordinate
    LDA ram_flagpole_f_num_ymf_dummy
    SEC  ; subtract movement amount from dummy variable
    SBC #$ff
    STA ram_flagpole_f_num_ymf_dummy  ; save dummy variable
    LDA ram_flagpole_f_num_y_pos
    SBC #$01  ; subtract one plus borrow to move floatey number,
    STA ram_flagpole_f_num_y_pos  ; and store vertical coordinate here
SkipScore:
    JMP FPGfx  ; jump to skip ahead and draw flag and floatey number
GiveFPScr:
    LDY ram_flagpole_score  ; get score offset from earlier (when player touched flagpole)
    LDA FlagpoleScoreMods,y  ; get amount to award player points
    LDX FlagpoleScoreDigits,y  ; get digit with which to award points
    STA ram_digit_modifier,x  ; store in digit modifier
    JSR AddToScore  ; do sub to award player points depending on height of collision
    LDA #$05
    STA ram_game_engine_subroutine  ; set to run end-of-level subroutine on next frame
FPGfx:
    JSR GetEnemyOffscreenBits  ; get offscreen information
    JSR RelativeEnemyPosition  ; get relative coordinates
    JSR FlagpoleGfxHandler  ; draw flagpole flag and floatey number
ExitFlagP:
    RTS

; -------------------------------------------------------------------------------------

Jumpspring_Y_PosData:
    .byte $08, $10, $08, $00

JumpspringHandler:
    JSR GetEnemyOffscreenBits  ; get offscreen information
    LDA ram_timer_control  ; check master timer control
    BNE DrawJSpr  ; branch to last section if set
    LDA ram_jumpspring_anim_ctrl  ; check jumpspring frame control
    BEQ DrawJSpr  ; branch to last section if not set
    TAY
    DEY  ; subtract one from frame control,
    TYA  ; the only way a poor nmos 6502 can
    AND #%00000010  ; mask out all but d1, original value still in Y
    BNE DownJSpr  ; if set, branch to move player up
    INC ram_player_y_position
    INC ram_player_y_position  ; move player's vertical position down two pixels
    JMP PosJSpr  ; skip to next part
DownJSpr:
    DEC ram_player_y_position  ; move player's vertical position up two pixels
    DEC ram_player_y_position
PosJSpr:
    LDA ram_jumpspring_fixed_y_pos,x  ; get permanent vertical position
    CLC
    ADC Jumpspring_Y_PosData,y  ; add value using frame control as offset
    STA ram_enemy_y_position,x  ; store as new vertical position
    CPY #$01  ; check frame control offset (second frame is $00)
    BCC BounceJS  ; if offset not yet at third frame ($01), skip to next part
    LDA ram_a_b_buttons
    AND #con_btn_a  ; check saved controller bits for A button press
    BEQ BounceJS  ; skip to next part if A not pressed
    AND ram_previous_a_b_buttons  ; check for A button pressed in previous frame
    BNE BounceJS  ; skip to next part if so
    LDA #$f4
    STA ram_jumpspring_force  ; otherwise write new jumpspring force here
BounceJS:
    CPY #$03  ; check frame control offset again
    BNE DrawJSpr  ; skip to last part if not yet at fifth frame ($03)
    LDA ram_jumpspring_force
    STA ram_player_y_speed  ; store jumpspring force as player's new vertical speed
    LDA #$00
    STA ram_jumpspring_anim_ctrl  ; initialize jumpspring frame control
DrawJSpr:
    JSR RelativeEnemyPosition  ; get jumpspring's relative coordinates
    JSR EnemyGfxHandler  ; draw jumpspring
    JSR OffscreenBoundsCheck  ; check to see if we need to kill it
    LDA ram_jumpspring_anim_ctrl  ; if frame control at zero, don't bother
    BEQ ExJSpring  ; trying to animate it, just leave
    LDA ram_jumpspring_timer
    BNE ExJSpring  ; if jumpspring timer not expired yet, leave
    LDA #$04
    STA ram_jumpspring_timer  ; otherwise initialize jumpspring timer
    INC ram_jumpspring_anim_ctrl  ; increment frame control to animate jumpspring
ExJSpring:
    RTS  ; leave

; -------------------------------------------------------------------------------------

Setup_Vine:
    LDA #con_vine_object  ; load identifier for vine object
    STA ram_enemy_id,x  ; store in buffer
    LDA #$01
    STA ram_enemy_flag,x  ; set flag for enemy object buffer
    LDA ram_block_page_loc,y
    STA ram_enemy_page_loc,x  ; copy page location from previous object
    LDA ram_block_x_position,y
    STA ram_enemy_x_position,x  ; copy horizontal coordinate from previous object
    LDA ram_block_y_position,y
    STA ram_enemy_y_position,x  ; copy vertical coordinate from previous object
    LDY ram_vine_flag_offset  ; load vine flag/offset to next available vine slot
    BNE NextVO  ; if set at all, don't bother to store vertical
    STA ram_vine_start_y_position  ; otherwise store vertical coordinate here
NextVO:
    TXA  ; store object offset to next available vine slot
    STA ram_vine_obj_offset,y  ; using vine flag as offset
    INC ram_vine_flag_offset  ; increment vine flag offset
    LDA #con_sfx_grow_vine
    STA ram_square2_sound_queue  ; load vine grow sound
    RTS

; -------------------------------------------------------------------------------------
; $06-$07 - used as address to block buffer data
; $02 - used as vertical high nybble of block buffer offset

VineHeightData:
    .byte $30, $60

VineObjectHandler:
    CPX #$05  ; check enemy offset for special use slot
    BNE ExitVH  ; if not in last slot, branch to leave
    LDY ram_vine_flag_offset
    DEY  ; decrement vine flag in Y, use as offset
    LDA ram_vine_height
    CMP VineHeightData,y  ; if vine has reached certain height,
    BEQ RunVSubs  ; branch ahead to skip this part
    LDA ram_frame_counter  ; get frame counter
    LSR  ; shift d1 into carry
    LSR
    BCC RunVSubs  ; if d1 not set (2 frames every 4) skip this part
    LDA ram_enemy_y_position+5
    SBC #$01  ; subtract vertical position of vine
    STA ram_enemy_y_position+5  ; one pixel every frame it's time
    INC ram_vine_height  ; increment vine height
RunVSubs:
    LDA ram_vine_height  ; if vine still very small,
    CMP #$08  ; branch to leave
    BCC ExitVH
    JSR RelativeEnemyPosition  ; get relative coordinates of vine,
    JSR GetEnemyOffscreenBits  ; and any offscreen bits
    LDY #$00  ; initialize offset used in draw vine sub
VDrawLoop:
    JSR DrawVine  ; draw vine
    INY  ; increment offset
    CPY ram_vine_flag_offset  ; if offset in Y and offset here
    BNE VDrawLoop  ; do not yet match, loop back to draw more vine
    LDA ram_enemy_offscreen_bits
    AND #%00001100  ; mask offscreen bits
    BEQ WrCMTile  ; if none of the saved offscreen bits set, skip ahead
    DEY  ; otherwise decrement Y to get proper offset again
KillVine:
    LDX ram_vine_obj_offset,y  ; get enemy object offset for this vine object
    JSR EraseEnemyObject  ; kill this vine object
    DEY  ; decrement Y
    BPL KillVine  ; if any vine objects left, loop back to kill it
    STA ram_vine_flag_offset  ; initialize vine flag/offset
    STA ram_vine_height  ; initialize vine height
WrCMTile:
    LDA ram_vine_height  ; check vine height
    CMP #$20  ; if vine small (less than 32 pixels tall)
    BCC ExitVH  ; then branch ahead to leave
    LDX #$06  ; set offset in X to last enemy slot
    LDA #$01  ; set A to obtain horizontal in $04, but we don't care
    LDY #$1b  ; set Y to offset to get block at ($04, $10) of coordinates
    JSR BlockBufferCollision  ; do a sub to get block buffer address set, return contents
    LDY $02
    CPY #$d0  ; if vertical high nybble offset beyond extent of
    BCS ExitVH  ; current block buffer, branch to leave, do not write
    LDA ($06),y  ; otherwise check contents of block buffer at
    BNE ExitVH  ; current offset, if not empty, branch to leave
    LDA #$26
    STA ($06),y  ; otherwise, write climbing metatile to block buffer
ExitVH:
    LDX ram_object_offset  ; get enemy object offset and leave
    RTS
