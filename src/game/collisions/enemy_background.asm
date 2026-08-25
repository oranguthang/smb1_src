; -------------------------------------------------------------------------------------
; $06-$07 - address from block buffer routine

EnemyBGCStateData:
    .byte $01, $01, $02, $02, $02, $05

EnemyBGCXSpdData:
    .byte $10, $f0

sub_enemy_to_bg_collision_det:
    LDA ram_enemy_state,x  ; check enemy state for d6 set
    AND #%00100000
    BNE ExEBG  ; if set, branch to leave
    JSR sub_subt_enemy_y_pos  ; otherwise, do a subroutine here
    BCC ExEBG  ; if enemy vertical coord + 62 < 68, branch to leave
    LDY ram_enemy_id,x
    CPY #con_spiny  ; if enemy object is not spiny, branch elsewhere
    BNE DoIDCheckBGColl
    LDA ram_enemy_y_position,x
    CMP #$25  ; if enemy vertical coordinate < 36 branch to leave
    BCC ExEBG

DoIDCheckBGColl:
    CPY #con_green_paratroopa_jump  ; check for some other enemy object
    BNE HBChk  ; branch if not found
    JMP sub_enemy_jump  ; otherwise jump elsewhere
HBChk:
    CPY #con_hammer_bro  ; check for hammer bro
    BNE CInvu  ; branch if not found
    JMP HammerBroBGColl  ; otherwise jump elsewhere
CInvu:
    CPY #con_spiny  ; if enemy object is spiny, branch
    BEQ YesIn
    CPY #con_power_up_object  ; if special power-up object, branch
    BEQ YesIn
    CPY #$07  ; if enemy object =>$07, branch to leave
    BCS ExEBGChk
YesIn:
    JSR sub_chk_under_enemy  ; if enemy object < $07, or = $12 or $2e, do this sub
    BNE HandleEToBGCollision  ; if block underneath enemy, branch

NoEToBGCollision:
    JMP ChkForRedKoopa  ; otherwise skip and do something else

; --------------------------------
; $02 - vertical coordinate from block buffer routine

HandleEToBGCollision:
    JSR sub_chk_for_non_solids  ; if something is underneath enemy, find out what
    BEQ NoEToBGCollision  ; if blank $26, coins, or hidden blocks, jump, enemy falls through
    CMP #$23
    BNE LandEnemyProperly  ; check for blank metatile $23 and branch if not found
    LDY $02  ; get vertical coordinate used to find block
    LDA #$00  ; store default blank metatile in that spot so we won't
    STA ($06),y  ; trigger this routine accidentally again
    LDA ram_enemy_id,x
    CMP #$15  ; if enemy object => $15, branch ahead
    BCS sub_chk_to_stun_enemies
    CMP #con_goomba  ; if enemy object not goomba, branch ahead of this routine
    BNE GiveOEPoints
    JSR sub_kill_enemy_above_block  ; if enemy object IS goomba, do this sub

GiveOEPoints:
    LDA #$01  ; award 100 points for hitting block beneath enemy
    JSR sub_setup_floatey_number

sub_chk_to_stun_enemies:
    CMP #$09  ; perform many comparisons on enemy object identifier
    BCC sub_set_stun
    CMP #$11  ; if the enemy object identifier is equal to the values
    BCS sub_set_stun  ; $09, $0e, $0f or $10, it will be modified, and not
    CMP #$0a  ; modified if not any of those values, note that piranha plant will
    BCC Demote  ; always fail this test because A will still have vertical
    CMP #con_piranha_plant  ; coordinate from previous addition, also these comparisons
    BCC sub_set_stun  ; are only necessary if branching from $d7a1
Demote:
    AND #%00000001  ; erase all but LSB, essentially turning enemy object
    STA ram_enemy_id,x  ; into green or red koopa troopa to demote them
sub_set_stun:
    LDA ram_enemy_state,x  ; load enemy state
    AND #%11110000  ; save high nybble
    ORA #%00000010
    STA ram_enemy_state,x  ; set d1 of enemy state
    DEC ram_enemy_y_position,x
    DEC ram_enemy_y_position,x  ; subtract two pixels from enemy's vertical position
    LDA ram_enemy_id,x
    CMP #con_bloober  ; check for bloober object
    BEQ SetWYSpd
    LDA #$fd  ; set default vertical speed
    LDY ram_area_type
    BNE SetNotW  ; if area type not water, set as speed, otherwise
SetWYSpd:
    LDA #$ff  ; change the vertical speed
SetNotW:
    STA ram_enemy_y_speed,x  ; set vertical speed now
    LDY #$01
    JSR sub_player_enemy_diff  ; get horizontal difference between player and enemy object
    BPL ChkBBill  ; branch if enemy is to the right of player
    INY  ; increment Y if not
ChkBBill:
    LDA ram_enemy_id,x
    CMP #con_bullet_bill_cannon_var  ; check for bullet bill (cannon variant)
    BEQ NoCDirF
    CMP #con_bullet_bill_frenzy_var  ; check for bullet bill (frenzy variant)
    BEQ NoCDirF  ; branch if either found, direction does not change
    STY ram_enemy_moving_dir,x  ; store as moving direction
NoCDirF:
    DEY  ; decrement and use as offset
    LDA EnemyBGCXSpdData,y  ; get proper horizontal speed
    STA ram_enemy_x_speed,x  ; and store, then leave
ExEBGChk:
    RTS

; --------------------------------
; $04 - low nybble of vertical coordinate from block buffer routine

LandEnemyProperly:
    LDA $04  ; check lower nybble of vertical coordinate saved earlier
    SEC
    SBC #$08  ; subtract eight pixels
    CMP #$05  ; used to determine whether enemy landed from falling
    BCS ChkForRedKoopa  ; branch if lower nybble in range of $0d-$0f before subtract
    LDA ram_enemy_state,x
    AND #%01000000  ; branch if d6 in enemy state is set
    BNE LandEnemyInitState
    LDA ram_enemy_state,x
    ASL  ; branch if d7 in enemy state is not set
    BCC ChkLandedEnemyState
SChkA:
    JMP DoEnemySideCheck  ; if lower nybble < $0d, d7 set but d6 not set, jump here

ChkLandedEnemyState:
    LDA ram_enemy_state,x  ; if enemy in normal state, branch back to jump here
    BEQ SChkA
    CMP #$05  ; if in state used by spiny's egg
    BEQ ProcEnemyDirection  ; then branch elsewhere
    CMP #$03  ; if already in state used by koopas and buzzy beetles
    BCS ExSteChk  ; or in higher numbered state, branch to leave
    LDA ram_enemy_state,x  ; load enemy state again (why?)
    CMP #$02  ; if not in $02 state (used by koopas and buzzy beetles)
    BNE ProcEnemyDirection  ; then branch elsewhere
    LDA #$10  ; load default timer here
    LDY ram_enemy_id,x  ; check enemy identifier for spiny
    CPY #con_spiny
    BNE SetForStn  ; branch if not found
    LDA #$00  ; set timer for $00 if spiny
SetForStn:
    STA ram_enemy_interval_timer,x  ; set timer here
    LDA #$03  ; set state here, apparently used to render
    STA ram_enemy_state,x  ; upside-down koopas and buzzy beetles
    JSR sub_enemy_landing  ; then land it properly
ExSteChk:
    RTS  ; then leave

ProcEnemyDirection:
    LDA ram_enemy_id,x  ; check enemy identifier for goomba
    CMP #con_goomba  ; branch if found
    BEQ LandEnemyInitState
    CMP #con_spiny  ; check for spiny
    BNE InvtD  ; branch if not found
    LDA #$01
    STA ram_enemy_moving_dir,x  ; send enemy moving to the right by default
    LDA #$08
    STA ram_enemy_x_speed,x  ; set horizontal speed accordingly
    LDA ram_frame_counter
    AND #%00000111  ; if timed appropriately, spiny will skip over
    BEQ LandEnemyInitState  ; trying to face the player
InvtD:
    LDY #$01  ; load 1 for enemy to face the left (inverted here)
    JSR sub_player_enemy_diff  ; get horizontal difference between player and enemy
    BPL CNwCDir  ; if enemy to the right of player, branch
    INY  ; if to the left, increment by one for enemy to face right (inverted)
CNwCDir:
    TYA
    CMP ram_enemy_moving_dir,x  ; compare direction in A with current direction in memory
    BNE LandEnemyInitState
    JSR sub_chk_for_bump_hammer_bro_j  ; if equal, not facing in correct dir, do sub to turn around

LandEnemyInitState:
    JSR sub_enemy_landing  ; land enemy properly
    LDA ram_enemy_state,x
    AND #%10000000  ; if d7 of enemy state is set, branch
    BNE NMovShellFallBit
    LDA #$00  ; otherwise initialize enemy state and leave
    STA ram_enemy_state,x  ; note this will also turn spiny's egg into spiny
    RTS

NMovShellFallBit:
    LDA ram_enemy_state,x  ; nullify d6 of enemy state, save other bits
    AND #%10111111  ; and store, then leave
    STA ram_enemy_state,x
    RTS

; --------------------------------

ChkForRedKoopa:
    LDA ram_enemy_id,x  ; check for red koopa troopa $03
    CMP #con_red_koopa
    BNE Chk2MSBSt  ; branch if not found
    LDA ram_enemy_state,x
    BEQ sub_chk_for_bump_hammer_bro_j  ; if enemy found and in normal state, branch
Chk2MSBSt:
    LDA ram_enemy_state,x  ; save enemy state into Y
    TAY
    ASL  ; check for d7 set
    BCC GetSteFromD  ; branch if not set
    LDA ram_enemy_state,x
    ORA #%01000000  ; set d6
    JMP SetD6Ste  ; jump ahead of this part
GetSteFromD:
    LDA EnemyBGCStateData,y  ; load new enemy state with old as offset
SetD6Ste:
    STA ram_enemy_state,x  ; set as new state

; --------------------------------
; $00 - used to store bitmask (not used but initialized here)
; $eb - used in DoEnemySideCheck as counter and to compare moving directions

DoEnemySideCheck:
    LDA ram_enemy_y_position,x  ; if enemy within status bar, branch to leave
    CMP #$20  ; because there's nothing there that impedes movement
    BCC ExESdeC
    LDY #$16  ; start by finding block to the left of enemy ($00,$14)
    LDA #$02  ; set value here in what is also used as
    STA $eb  ; OAM data offset
SdeCLoop:
    LDA $eb  ; check value
    CMP ram_enemy_moving_dir,x  ; compare value against moving direction
    BNE NextSdeC  ; branch if different and do not seek block there
    LDA #$01  ; set flag in A for save horizontal coordinate
    JSR sub_block_buffer_chk_enemy  ; find block to left or right of enemy object
    BEQ NextSdeC  ; if nothing found, branch
    JSR sub_chk_for_non_solids  ; check for non-solid blocks
    BNE sub_chk_for_bump_hammer_bro_j  ; branch if not found
NextSdeC:
    DEC $eb  ; move to the next direction
    INY
    CPY #$18  ; increment Y, loop only if Y < $18, thus we check
    BCC SdeCLoop  ; enemy ($00, $14) and ($10, $14) pixel coordinates
ExESdeC:
    RTS

sub_chk_for_bump_hammer_bro_j:
    CPX #$05  ; check if we're on the special use slot
    BEQ NoBump  ; and if so, branch ahead and do not play sound
    LDA ram_enemy_state,x  ; if enemy state d7 not set, branch
    ASL  ; ahead and do not play sound
    BCC NoBump
    LDA #con_sfx_bump  ; otherwise, play bump sound
    STA ram_square1_sound_queue  ; sound will never be played if branching from ChkForRedKoopa
NoBump:
    LDA ram_enemy_id,x  ; check for hammer bro
    CMP #$05
    BNE InvEnemyDir  ; branch if not found
    LDA #$00
    STA $00  ; initialize value here for bitmask
    LDY #$fa  ; load default vertical speed for jumping
    JMP SetHJ  ; jump to code that makes hammer bro jump

InvEnemyDir:
    JMP RXSpd  ; jump to turn the enemy around

; --------------------------------
; $00 - used to hold horizontal difference between player and enemy

sub_player_enemy_diff:
    LDA ram_enemy_x_position,x  ; get distance between enemy object's
    SEC  ; horizontal coordinate and the player's
    SBC ram_player_x_position  ; horizontal coordinate
    STA $00  ; and store here
    LDA ram_enemy_page_loc,x
    SBC ram_player_page_loc  ; subtract borrow, then leave
    RTS

; --------------------------------

sub_enemy_landing:
    JSR sub_init_v_stf  ; do something here to vertical speed and something else
    LDA ram_enemy_y_position,x
    AND #%11110000  ; save high nybble of vertical coordinate, and
    ORA #%00001000  ; set d3, then store, probably used to set enemy object
    STA ram_enemy_y_position,x  ; neatly on whatever it's landing on
    RTS

sub_subt_enemy_y_pos:
    LDA ram_enemy_y_position,x  ; add 62 pixels to enemy object's
    CLC  ; vertical coordinate
    ADC #$3e
    CMP #$44  ; compare against a certain range
    RTS  ; and leave with flags set for conditional branch

sub_enemy_jump:
    JSR sub_subt_enemy_y_pos  ; do a sub here
    BCC DoSide  ; if enemy vertical coord + 62 < 68, branch to leave
    LDA ram_enemy_y_speed,x
    CLC  ; add two to vertical speed
    ADC #$02
    CMP #$03  ; if green paratroopa not falling, branch ahead
    BCC DoSide
    JSR sub_chk_under_enemy  ; otherwise, check to see if green paratroopa is
    BEQ DoSide  ; standing on anything, then branch to same place if not
    JSR sub_chk_for_non_solids  ; check for non-solid blocks
    BEQ DoSide  ; branch if found
    JSR sub_enemy_landing  ; change vertical coordinate and speed
    LDA #$fd
    STA ram_enemy_y_speed,x  ; make the paratroopa jump again
DoSide:
    JMP DoEnemySideCheck  ; check for horizontal blockage, then leave

; --------------------------------

HammerBroBGColl:
    JSR sub_chk_under_enemy  ; check to see if hammer bro is standing on anything
    BEQ NoUnderHammerBro
    CMP #$23  ; check for blank metatile $23 and branch if not found
    BNE UnderHammerBro

sub_kill_enemy_above_block:
    JSR sub_shell_or_block_defeat  ; do this sub to kill enemy
    LDA #$fc  ; alter vertical speed of enemy and leave
    STA ram_enemy_y_speed,x
    RTS

UnderHammerBro:
    LDA ram_enemy_frame_timer,x  ; check timer used by hammer bro
    BNE NoUnderHammerBro  ; branch if not expired
    LDA ram_enemy_state,x
    AND #%10001000  ; save d7 and d3 from enemy state, nullify other bits
    STA ram_enemy_state,x  ; and store
    JSR sub_enemy_landing  ; modify vertical coordinate, speed and something else
    JMP DoEnemySideCheck  ; then check for horizontal blockage and leave

NoUnderHammerBro:
    LDA ram_enemy_state,x  ; if hammer bro is not standing on anything, set d0
    ORA #$01  ; in the enemy state to indicate jumping or falling, then leave
    STA ram_enemy_state,x
    RTS

sub_chk_under_enemy:
    LDA #$00  ; set flag in A for save vertical coordinate
    LDY #$15  ; set Y to check the bottom middle (8,18) of enemy object
    JMP sub_block_buffer_chk_enemy  ; hop to it!

sub_chk_for_non_solids:
    CMP #$26  ; blank metatile used for vines?
    BEQ NSFnd
    CMP #$c2  ; regular coin?
    BEQ NSFnd
    CMP #$c3  ; underwater coin?
    BEQ NSFnd
    CMP #$5f  ; hidden coin block?
    BEQ NSFnd
    CMP #$60  ; hidden 1-up block?
NSFnd:
    RTS

; -------------------------------------------------------------------------------------

sub_fireball_bg_collision:
    LDA ram_fireball_y_position,x  ; check fireball's vertical coordinate
    CMP #$18
    BCC ClearBounceFlag  ; if within the status bar area of the screen, branch ahead
    JSR sub_block_buffer_chk_f_ball  ; do fireball to background collision detection on bottom of it
    BEQ ClearBounceFlag  ; if nothing underneath fireball, branch
    JSR sub_chk_for_non_solids  ; check for non-solid metatiles
    BEQ ClearBounceFlag  ; branch if any found
    LDA ram_fireball_y_speed,x  ; if fireball's vertical speed set to move upwards,
    BMI InitFireballExplode  ; branch to set exploding bit in fireball's state
    LDA ram_fireball_bouncing_flag,x  ; if bouncing flag already set,
    BNE InitFireballExplode  ; branch to set exploding bit in fireball's state
    LDA #$fd
    STA ram_fireball_y_speed,x  ; otherwise set vertical speed to move upwards (give it bounce)
    LDA #$01
    STA ram_fireball_bouncing_flag,x  ; set bouncing flag
    LDA ram_fireball_y_position,x
    AND #$f8  ; modify vertical coordinate to land it properly
    STA ram_fireball_y_position,x  ; store as new vertical coordinate
    RTS  ; leave

ClearBounceFlag:
    LDA #$00
    STA ram_fireball_bouncing_flag,x  ; clear bouncing flag by default
    RTS  ; leave

InitFireballExplode:
    LDA #$80
    STA ram_fireball_state,x  ; set exploding flag in fireball's state
    LDA #con_sfx_bump
    STA ram_square1_sound_queue  ; load bump sound
    RTS  ; leave
