; --------------------------------
; $00 - used as counter for firebar parts
; $01 - used for oscillated high byte of spin state or to hold horizontal adder
; $02 - used for oscillated high byte of spin state or to hold vertical adder
; $03 - used for mirror data
; $04 - used to store player's sprite 1 X coordinate
; $05 - used to evaluate mirror data
; $06 - used to store either screen X coordinate or sprite data offset
; $07 - used to store screen Y coordinate
; $ed - used to hold maximum length of firebar
; $ef - used to hold high byte of spinstate

; horizontal adder is at first byte + high byte of spinstate,
; vertical adder is same + 8 bytes, two's compliment
; if greater than $08 for proper oscillation
FirebarPosLookupTbl:
    .byte $00, $01, $03, $04, $05, $06, $07, $07, $08
    .byte $00, $03, $06, $09, $0b, $0d, $0e, $0f, $10
    .byte $00, $04, $09, $0d, $10, $13, $16, $17, $18
    .byte $00, $06, $0c, $12, $16, $1a, $1d, $1f, $20
    .byte $00, $07, $0f, $16, $1c, $21, $25, $27, $28
    .byte $00, $09, $12, $1b, $21, $27, $2c, $2f, $30
    .byte $00, $0b, $15, $1f, $27, $2e, $33, $37, $38
    .byte $00, $0c, $18, $24, $2d, $35, $3b, $3e, $40
    .byte $00, $0e, $1b, $28, $32, $3b, $42, $46, $48
    .byte $00, $0f, $1f, $2d, $38, $42, $4a, $4e, $50
    .byte $00, $11, $22, $31, $3e, $49, $51, $56, $58

FirebarMirrorData:
    .byte $01, $03, $02, $00

FirebarTblOffsets:
    .byte $00, $09, $12, $1b, $24, $2d
    .byte $36, $3f, $48, $51, $5a, $63

FirebarYPos:
    .byte $0c, $18

ProcFirebar:
    JSR GetEnemyOffscreenBits  ; get offscreen information
    LDA ram_enemy_offscreen_bits  ; check for d3 set
    AND #%00001000  ; if so, branch to leave
    BNE SkipFBar
    LDA ram_timer_control  ; if master timer control set, branch
    BNE SusFbar  ; ahead of this part
    LDA ram_firebar_spin_speed,x  ; load spinning speed of firebar
    JSR FirebarSpin  ; modify current spinstate
    AND #%00011111  ; mask out all but 5 LSB
    STA ram_firebar_spin_state_high,x  ; and store as new high byte of spinstate
SusFbar:
    LDA ram_firebar_spin_state_high,x  ; get high byte of spinstate
    LDY ram_enemy_id,x  ; check enemy identifier
    CPY #$1f
    BCC SetupGFB  ; if < $1f (long firebar), branch
    CMP #$08  ; check high byte of spinstate
    BEQ SkpFSte  ; if eight, branch to change
    CMP #$18
    BNE SetupGFB  ; if not at twenty-four branch to not change
SkpFSte:
    CLC
    ADC #$01  ; add one to spinning thing to avoid horizontal state
    STA ram_firebar_spin_state_high,x
SetupGFB:
    STA $ef  ; save high byte of spinning thing, modified or otherwise
    JSR RelativeEnemyPosition  ; get relative coordinates to screen
    JSR GetFirebarPosition  ; do a sub here (residual, too early to be used now)
    LDY ram_enemy_spr_data_offset,x  ; get OAM data offset
    LDA ram_enemy_rel_y_pos  ; get relative vertical coordinate
    STA ram_sprite_y_position,y  ; store as Y in OAM data
    STA $07  ; also save here
    LDA ram_enemy_rel_x_pos  ; get relative horizontal coordinate
    STA ram_sprite_x_position,y  ; store as X in OAM data
    STA $06  ; also save here
    LDA #$01
    STA $00  ; set $01 value here (not necessary)
    JSR FirebarCollision  ; draw fireball part and do collision detection
    LDY #$05  ; load value for short firebars by default
    LDA ram_enemy_id,x
    CMP #$1f  ; are we doing a long firebar?
    BCC SetMFbar  ; no, branch then
    LDY #$0b  ; otherwise load value for long firebars
SetMFbar:
    STY $ed  ; store maximum value for length of firebars
    LDA #$00
    STA $00  ; initialize counter here
DrawFbar:
    LDA $ef  ; load high byte of spinstate
    JSR GetFirebarPosition  ; get fireball position data depending on firebar part
    JSR DrawFirebar_Collision  ; position it properly, draw it and do collision detection
    LDA $00  ; check which firebar part
    CMP #$04
    BNE NextFbar
    LDY ram_duplicate_obj_offset  ; if we arrive at fifth firebar part,
    LDA ram_enemy_spr_data_offset,y  ; get offset from long firebar and load OAM data offset
    STA $06  ; using long firebar offset, then store as new one here
NextFbar:
    INC $00  ; move onto the next firebar part
    LDA $00
    CMP $ed  ; if we end up at the maximum part, go on and leave
    BCC DrawFbar  ; otherwise go back and do another
SkipFBar:
    RTS

DrawFirebar_Collision:
    LDA $03  ; store mirror data elsewhere
    STA $05
    LDY $06  ; load OAM data offset for firebar
    LDA $01  ; load horizontal adder we got from position loader
    LSR $05  ; shift LSB of mirror data
    BCS AddHA  ; if carry was set, skip this part
    EOR #$ff
    ADC #$01  ; otherwise get two's compliment of horizontal adder
AddHA:
    CLC  ; add horizontal coordinate relative to screen to
    ADC ram_enemy_rel_x_pos  ; horizontal adder, modified or otherwise
    STA ram_sprite_x_position,y  ; store as X coordinate here
    STA $06  ; store here for now, note offset is saved in Y still
    CMP ram_enemy_rel_x_pos  ; compare X coordinate of sprite to original X of firebar
    BCS SubtR1  ; if sprite coordinate => original coordinate, branch
    LDA ram_enemy_rel_x_pos
    SEC  ; otherwise subtract sprite X from the
    SBC $06  ; original one and skip this part
    JMP ChkFOfs
SubtR1:
    SEC  ; subtract original X from the
    SBC ram_enemy_rel_x_pos  ; current sprite X
ChkFOfs:
    CMP #$59  ; if difference of coordinates within a certain range,
    BCC VAHandl  ; continue by handling vertical adder
    LDA #$f8  ; otherwise, load offscreen Y coordinate
    BNE SetVFbr  ; and unconditionally branch to move sprite offscreen
VAHandl:
    LDA ram_enemy_rel_y_pos  ; if vertical relative coordinate offscreen,
    CMP #$f8  ; skip ahead of this part and write into sprite Y coordinate
    BEQ SetVFbr
    LDA $02  ; load vertical adder we got from position loader
    LSR $05  ; shift LSB of mirror data one more time
    BCS AddVA  ; if carry was set, skip this part
    EOR #$ff
    ADC #$01  ; otherwise get two's compliment of second part
AddVA:
    CLC  ; add vertical coordinate relative to screen to
    ADC ram_enemy_rel_y_pos  ; the second data, modified or otherwise
SetVFbr:
    STA ram_sprite_y_position,y  ; store as Y coordinate here
    STA $07  ; also store here for now

FirebarCollision:
    JSR DrawFirebar  ; run sub here to draw current tile of firebar
    TYA  ; return OAM data offset and save
    PHA  ; to the stack for now
    LDA ram_star_invincible_timer  ; if star mario invincibility timer
    ORA ram_timer_control  ; or master timer controls set
    BNE NoColFB  ; then skip all of this
    STA $05  ; otherwise initialize counter
    LDY ram_player_y_high_pos
    DEY  ; if player's vertical high byte offscreen,
    BNE NoColFB  ; skip all of this
    LDY ram_player_y_position  ; get player's vertical position
    LDA ram_player_size  ; get player's size
    BNE AdjSm  ; if player small, branch to alter variables
    LDA ram_crouching_flag
    BEQ BigJp  ; if player big and not crouching, jump ahead
AdjSm:
    INC $05  ; if small or big but crouching, execute this part
    INC $05  ; first increment our counter twice (setting $02 as flag)
    TYA
    CLC  ; then add 24 pixels to the player's
    ADC #$18  ; vertical coordinate
    TAY
BigJp:
    TYA  ; get vertical coordinate, altered or otherwise, from Y
FBCLoop:
    SEC  ; subtract vertical position of firebar
    SBC $07  ; from the vertical coordinate of the player
    BPL ChkVFBD  ; if player lower on the screen than firebar,
    EOR #$ff  ; skip two's compliment part
    CLC  ; otherwise get two's compliment
    ADC #$01
ChkVFBD:
    CMP #$08  ; if difference => 8 pixels, skip ahead of this part
    BCS Chk2Ofs
    LDA $06  ; if firebar on far right on the screen, skip this,
    CMP #$f0  ; because, really, what's the point?
    BCS Chk2Ofs
    LDA ram_sprite_x_position+4  ; get OAM X coordinate for sprite #1
    CLC
    ADC #$04  ; add four pixels
    STA $04  ; store here
    SEC  ; subtract horizontal coordinate of firebar
    SBC $06  ; from the X coordinate of player's sprite 1
    BPL ChkFBCl  ; if modded X coordinate to the right of firebar
    EOR #$ff  ; skip two's compliment part
    CLC  ; otherwise get two's compliment
    ADC #$01
ChkFBCl:
    CMP #$08  ; if difference < 8 pixels, collision, thus branch
    BCC ChgSDir  ; to process
Chk2Ofs:
    LDA $05  ; if value of $02 was set earlier for whatever reason,
    CMP #$02  ; branch to increment OAM offset and leave, no collision
    BEQ NoColFB
    LDY $05  ; otherwise get temp here and use as offset
    LDA ram_player_y_position
    CLC
    ADC FirebarYPos,y  ; add value loaded with offset to player's vertical coordinate
    INC $05  ; then increment temp and jump back
    JMP FBCLoop
ChgSDir:
    LDX #$01  ; set movement direction by default
    LDA $04  ; if OAM X coordinate of player's sprite 1
    CMP $06  ; is greater than horizontal coordinate of firebar
    BCS SetSDir  ; then do not alter movement direction
    INX  ; otherwise increment it
SetSDir:
    STX ram_enemy_moving_dir  ; store movement direction here
    LDX #$00
    LDA $00  ; save value written to $00 to stack
    PHA
    JSR InjurePlayer  ; perform sub to hurt or kill player
    PLA
    STA $00  ; get value of $00 from stack
NoColFB:
    PLA  ; get OAM data offset
    CLC  ; add four to it and save
    ADC #$04
    STA $06
    LDX ram_object_offset  ; get enemy object buffer offset and leave
    RTS

GetFirebarPosition:
    PHA  ; save high byte of spinstate to the stack
    AND #%00001111  ; mask out low nybble
    CMP #$09
    BCC GetHAdder  ; if lower than $09, branch ahead
    EOR #%00001111  ; otherwise get two's compliment to oscillate
    CLC
    ADC #$01
GetHAdder:
    STA $01  ; store result, modified or not, here
    LDY $00  ; load number of firebar ball where we're at
    LDA FirebarTblOffsets,y  ; load offset to firebar position data
    CLC
    ADC $01  ; add oscillated high byte of spinstate
    TAY  ; to offset here and use as new offset
    LDA FirebarPosLookupTbl,y  ; get data here and store as horizontal adder
    STA $01
    PLA  ; pull whatever was in A from the stack
    PHA  ; save it again because we still need it
    CLC
    ADC #$08  ; add eight this time, to get vertical adder
    AND #%00001111  ; mask out high nybble
    CMP #$09  ; if lower than $09, branch ahead
    BCC GetVAdder
    EOR #%00001111  ; otherwise get two's compliment
    CLC
    ADC #$01
GetVAdder:
    STA $02  ; store result here
    LDY $00
    LDA FirebarTblOffsets,y  ; load offset to firebar position data again
    CLC
    ADC $02  ; this time add value in $02 to offset here and use as offset
    TAY
    LDA FirebarPosLookupTbl,y  ; get data here and store as vertica adder
    STA $02
    PLA  ; pull out whatever was in A one last time
    LSR  ; divide by eight or shift three to the right
    LSR
    LSR
    TAY  ; use as offset
    LDA FirebarMirrorData,y  ; load mirroring data here
    STA $03  ; store
    RTS

; --------------------------------

PRandomSubtracter:
    .byte $f8, $a0, $70, $bd, $00

FlyCCBPriority:
    .byte $20, $20, $20, $00, $00

MoveFlyingCheepCheep:
    LDA ram_enemy_state,x  ; check cheep-cheep's enemy state
    AND #%00100000  ; for d5 set
    BEQ FlyCC  ; branch to continue code if not set
    LDA #$00
    STA ram_enemy_spr_attrib,x  ; otherwise clear sprite attributes
    JMP sub_move_enemy_with_gravity  ; and jump to move defeated cheep-cheep downwards
FlyCC:
    JSR sub_move_enemy_horizontally  ; move cheep-cheep horizontally based on speed and force
    LDY #$0d  ; set vertical movement amount
    LDA #$05  ; set maximum speed
    JSR sub_apply_enemy_vertical_motion  ; branch to impose gravity on flying cheep-cheep
    LDA ram_enemy_y_move_force,x
    LSR  ; get vertical movement force and
    LSR  ; move high nybble to low
    LSR
    LSR
    TAY  ; save as offset (note this tends to go into reach of code)
    LDA ram_enemy_y_position,x  ; get vertical position
    SEC  ; subtract pseudorandom value based on offset from position
    SBC PRandomSubtracter,y
    BPL AddCCF  ; if result within top half of screen, skip this part
    EOR #$ff
    CLC  ; otherwise get two's compliment
    ADC #$01
AddCCF:
    CMP #$08  ; if result or two's compliment greater than eight,
    BCS BPGet  ; skip to the end without changing movement force
    LDA ram_enemy_y_move_force,x
    CLC
    ADC #$10  ; otherwise add to it
    STA ram_enemy_y_move_force,x
    LSR  ; move high nybble to low again
    LSR
    LSR
    LSR
    TAY
BPGet:
    LDA FlyCCBPriority,y  ; load bg priority data and store (this is very likely
    STA ram_enemy_spr_attrib,x  ; broken or residual code, value is overwritten before
    RTS  ; drawing it next frame), then leave

; --------------------------------
; $00 - used to hold horizontal difference
; $01-$03 - used to hold difference adjusters

LakituDiffAdj:
    .byte $15, $30, $40

MoveLakitu:
    LDA ram_enemy_state,x  ; check lakitu's enemy state
    AND #%00100000  ; for d5 set
    BEQ ChkLS  ; if not set, continue with code
    JMP sub_move_enemy_downward_fast  ; otherwise jump to move defeated lakitu downwards
ChkLS:
    LDA ram_enemy_state,x  ; if lakitu's enemy state not set at all,
    BEQ Fr12S  ; go ahead and continue with code
    LDA #$00
    STA ram_lakitu_move_direction,x  ; otherwise initialize moving direction to move to left
    STA ram_enemy_frenzy_buffer  ; initialize frenzy buffer
    LDA #$10
    BNE SetLSpd  ; load horizontal speed and do unconditional branch
Fr12S:
    LDA #con_spiny
    STA ram_enemy_frenzy_buffer  ; set spiny identifier in frenzy buffer
    LDY #$02
LdLDa:
    LDA LakituDiffAdj,y  ; load values
    STA $0001,y  ; store in zero page
    DEY
    BPL LdLDa  ; do this until all values are stired
    JSR PlayerLakituDiff  ; execute sub to set speed and create spinys
SetLSpd:
    STA ram_lakitu_move_speed,x  ; set movement speed returned from sub
    LDY #$01  ; set moving direction to right by default
    LDA ram_lakitu_move_direction,x
    AND #$01  ; get LSB of moving direction
    BNE SetLMov  ; if set, branch to the end to use moving direction
    LDA ram_lakitu_move_speed,x
    EOR #$ff  ; get two's compliment of moving speed
    CLC
    ADC #$01
    STA ram_lakitu_move_speed,x  ; store as new moving speed
    INY  ; increment moving direction to left
SetLMov:
    STY ram_enemy_moving_dir,x  ; store moving direction
    JMP sub_move_enemy_horizontally  ; move lakitu horizontally

PlayerLakituDiff:
    LDY #$00  ; set Y for default value
    JSR PlayerEnemyDiff  ; get horizontal difference between enemy and player
    BPL ChkLakDif  ; branch if enemy is to the right of the player
    INY  ; increment Y for left of player
    LDA $00
    EOR #$ff  ; get two's compliment of low byte of horizontal difference
    CLC
    ADC #$01  ; store two's compliment as horizontal difference
    STA $00
ChkLakDif:
    LDA $00  ; get low byte of horizontal difference
    CMP #$3c  ; if within a certain distance of player, branch
    BCC ChkPSpeed
    LDA #$3c  ; otherwise set maximum distance
    STA $00
    LDA ram_enemy_id,x  ; check if lakitu is in our current enemy slot
    CMP #con_lakitu
    BNE ChkPSpeed  ; if not, branch elsewhere
    TYA  ; compare contents of Y, now in A
    CMP ram_lakitu_move_direction,x  ; to what is being used as horizontal movement direction
    BEQ ChkPSpeed  ; if moving toward the player, branch, do not alter
    LDA ram_lakitu_move_direction,x  ; if moving to the left beyond maximum distance,
    BEQ SetLMovD  ; branch and alter without delay
    DEC ram_lakitu_move_speed,x  ; decrement horizontal speed
    LDA ram_lakitu_move_speed,x  ; if horizontal speed not yet at zero, branch to leave
    BNE ExMoveLak
SetLMovD:
    TYA  ; set horizontal direction depending on horizontal
    STA ram_lakitu_move_direction,x  ; difference between enemy and player if necessary
ChkPSpeed:
    LDA $00
    AND #%00111100  ; mask out all but four bits in the middle
    LSR  ; divide masked difference by four
    LSR
    STA $00  ; store as new value
    LDY #$00  ; init offset
    LDA ram_player_x_speed
    BEQ SubDifAdj  ; if player not moving horizontally, branch
    LDA ram_scroll_amount
    BEQ SubDifAdj  ; if scroll speed not set, branch to same place
    INY  ; otherwise increment offset
    LDA ram_player_x_speed
    CMP #$19  ; if player not running, branch
    BCC ChkSpinyO
    LDA ram_scroll_amount
    CMP #$02  ; if scroll speed below a certain amount, branch
    BCC ChkSpinyO  ; to same place
    INY  ; otherwise increment once more
ChkSpinyO:
    LDA ram_enemy_id,x  ; check for spiny object
    CMP #con_spiny
    BNE ChkEmySpd  ; branch if not found
    LDA ram_player_x_speed  ; if player not moving, skip this part
    BNE SubDifAdj
ChkEmySpd:
    LDA ram_enemy_y_speed,x  ; check vertical speed
    BNE SubDifAdj  ; branch if nonzero
    LDY #$00  ; otherwise reinit offset
SubDifAdj:
    LDA $0001,y  ; get one of three saved values from earlier
    LDY $00  ; get saved horizontal difference
SPixelLak:
    SEC  ; subtract one for each pixel of horizontal difference
    SBC #$01  ; from one of three saved values
    DEY
    BPL SPixelLak  ; branch until all pixels are subtracted, to adjust difference
ExMoveLak:
    RTS  ; leave!!!
