; -------------------------------------------------------------------------------------
; (these apply to all area object subroutines in this section unless otherwise stated)
; $00 - used to store offset used to find object code
; $07 - starts with adder from area parser, used to store row offset

AlterAreaAttributes:
    LDY ram_area_obj_offset_buffer,x  ; load offset for level object data saved in buffer
    INY  ; load second byte
    LDA (ram_area_data),y
    PHA  ; save in stack for now
    AND #%01000000
    BNE Alter2  ; branch if d6 is set
    PLA
    PHA  ; pull and push offset to copy to A
    AND #%00001111  ; mask out high nybble and store as
    STA ram_terrain_control  ; new terrain height type bits
    PLA
    AND #%00110000  ; pull and mask out all but d5 and d4
    LSR  ; move bits to lower nybble and store
    LSR  ; as new background scenery bits
    LSR
    LSR
    STA ram_background_scenery  ; then leave
    RTS
Alter2:
    PLA
    AND #%00000111  ; mask out all but 3 LSB
    CMP #$04  ; if four or greater, set color control bits
    BCC SetFore  ; and nullify foreground scenery bits
    STA ram_background_color_ctrl
    LDA #$00
SetFore:
    STA ram_foreground_scenery  ; otherwise set new foreground scenery bits
    RTS

; --------------------------------

ScrollLockObject_Warp:
    LDX #$04  ; load value of 4 for game text routine as default
    LDA ram_world_number  ; warp zone (4-3-2), then check world number
    BEQ WarpNum
    INX  ; if world number > 1, increment for next warp zone (5)
    LDY ram_area_type  ; check area type
    DEY
    BNE WarpNum  ; if ground area type, increment for last warp zone
    INX  ; (8-7-6) and move on
WarpNum:
    TXA
    STA ram_warp_zone_control  ; store number here to be used by warp zone routine
    JSR WriteGameText  ; print text and warp zone numbers
    LDA #con_piranha_plant
    JSR KillEnemies  ; load identifier for piranha plants and do sub

ScrollLockObject:
    LDA ram_scroll_lock  ; invert scroll lock to turn it on
    EOR #%00000001
    STA ram_scroll_lock
    RTS

; --------------------------------
; $00 - used to store enemy identifier in KillEnemies

KillEnemies:
    STA $00  ; store identifier here
    LDA #$00
    LDX #$04  ; check for identifier in enemy object buffer
KillELoop:
    LDY ram_enemy_id,x
    CPY $00  ; if not found, branch
    BNE NoKillE
    STA ram_enemy_flag,x  ; if found, deactivate enemy object flag
NoKillE:
    DEX  ; do this until all slots are checked
    BPL KillELoop
    RTS

; --------------------------------

FrenzyIDData:
    .byte con_fly_cheep_cheep_frenzy, con_b_bill_c_cheep_frenzy, con_stop_frenzy

AreaFrenzy:
    LDX $00  ; use area object identifier bit as offset
    LDA FrenzyIDData-8,x  ; note that it starts at 8, thus weird address here
    LDY #$05
FreCompLoop:
    DEY  ; check regular slots of enemy object buffer
    BMI ExitAFrenzy  ; if all slots checked and enemy object not found, branch to store
    CMP ram_enemy_id,y  ; check for enemy object in buffer versus frenzy object
    BNE FreCompLoop
    LDA #$00  ; if enemy object already present, nullify queue and leave
ExitAFrenzy:
    STA ram_enemy_frenzy_queue  ; store enemy into frenzy queue
    RTS

; --------------------------------
; $06 - used by MushroomLedge to store length

AreaStyleObject:
    LDA ram_area_style  ; load level object style and jump to the right sub
    JSR sub_dispatch_inline_handler
    .word TreeLedge  ; also used for cloud type levels
    .word MushroomLedge
    .word BulletBillCannon

TreeLedge:
    JSR GetLrgObjAttrib  ; get row and length of green ledge
    LDA ram_area_object_length,x  ; check length counter for expiration
    BEQ EndTreeL
    BPL MidTreeL
    TYA
    STA ram_area_object_length,x  ; store lower nybble into buffer flag as length of ledge
    LDA ram_current_page_loc
    ORA ram_current_column_pos  ; are we at the start of the level?
    BEQ MidTreeL
    LDA #$16  ; render start of tree ledge
    JMP NoUnder
MidTreeL:
    LDX $07
    LDA #$17  ; render middle of tree ledge
    STA ram_metatile_buffer,x  ; note that this is also used if ledge position is
    LDA #$4c  ; at the start of level for continuous effect
    JMP AllUnder  ; now render the part underneath
EndTreeL:
    LDA #$18  ; render end of tree ledge
    JMP NoUnder

MushroomLedge:
    JSR ChkLrgObjLength  ; get shroom dimensions
    STY $06  ; store length here for now
    BCC EndMushL
    LDA ram_area_object_length,x  ; divide length by 2 and store elsewhere
    LSR
    STA ram_mushroom_ledge_half_len,x
    LDA #$19  ; render start of mushroom
    JMP NoUnder
EndMushL:
    LDA #$1b  ; if at the end, render end of mushroom
    LDY ram_area_object_length,x
    BEQ NoUnder
    LDA ram_mushroom_ledge_half_len,x  ; get divided length and store where length
    STA $06  ; was stored originally
    LDX $07
    LDA #$1a
    STA ram_metatile_buffer,x  ; render middle of mushroom
    CPY $06  ; are we smack dab in the center?
    BNE MushLExit  ; if not, branch to leave
    INX
    LDA #$4f
    STA ram_metatile_buffer,x  ; render stem top of mushroom underneath the middle
    LDA #$50
AllUnder:
    INX
    LDY #$0f  ; set $0f to render all way down
    JMP RenderUnderPart  ; now render the stem of mushroom
NoUnder:
    LDX $07  ; load row of ledge
    LDY #$00  ; set 0 for no bottom on this part
    JMP RenderUnderPart

; --------------------------------

; tiles used by pulleys and rope object
PulleyRopeMetatiles:
    .byte $42, $41, $43

PulleyRopeObject:
    JSR ChkLrgObjLength  ; get length of pulley/rope object
    LDY #$00  ; initialize metatile offset
    BCS RenderPul  ; if starting, render left pulley
    INY
    LDA ram_area_object_length,x  ; if not at the end, render rope
    BNE RenderPul
    INY  ; otherwise render right pulley
RenderPul:
    LDA PulleyRopeMetatiles,y
    STA ram_metatile_buffer  ; render at the top of the screen
MushLExit:
    RTS  ; and leave

; --------------------------------
; $06 - used to store upper limit of rows for CastleObject

CastleMetatiles:
    .byte $00, $45, $45, $45, $00
    .byte $00, $48, $47, $46, $00
    .byte $45, $49, $49, $49, $45
    .byte $47, $47, $4a, $47, $47
    .byte $47, $47, $4b, $47, $47
    .byte $49, $49, $49, $49, $49
    .byte $47, $4a, $47, $4a, $47
    .byte $47, $4b, $47, $4b, $47
    .byte $47, $47, $47, $47, $47
    .byte $4a, $47, $4a, $47, $4a
    .byte $4b, $47, $4b, $47, $4b

CastleObject:
    JSR GetLrgObjAttrib  ; save lower nybble as starting row
    STY $07  ; if starting row is above $0a, game will crash!!!
    LDY #$04
    JSR ChkLrgObjFixedLength  ; load length of castle if not already loaded
    TXA
    PHA  ; save obj buffer offset to stack
    LDY ram_area_object_length,x  ; use current length as offset for castle data
    LDX $07  ; begin at starting row
    LDA #$0b
    STA $06  ; load upper limit of number of rows to print
CRendLoop:
    LDA CastleMetatiles,y  ; load current byte using offset
    STA ram_metatile_buffer,x
    INX  ; store in buffer and increment buffer offset
    LDA $06
    BEQ ChkCFloor  ; have we reached upper limit yet?
    INY  ; if not, increment column-wise
    INY  ; to byte in next row
    INY
    INY
    INY
    DEC $06  ; move closer to upper limit
ChkCFloor:
    CPX #$0b  ; have we reached the row just before floor?
    BNE CRendLoop  ; if not, go back and do another row
    PLA
    TAX  ; get obj buffer offset from before
    LDA ram_current_page_loc
    BEQ ExitCastle  ; if we're at page 0, we do not need to do anything else
    LDA ram_area_object_length,x  ; check length
    CMP #$01  ; if length almost about to expire, put brick at floor
    BEQ PlayerStop
    LDY $07  ; check starting row for tall castle ($00)
    BNE NotTall
    CMP #$03  ; if found, then check to see if we're at the second column
    BEQ PlayerStop
NotTall:
    CMP #$02  ; if not tall castle, check to see if we're at the third column
    BNE ExitCastle  ; if we aren't and the castle is tall, don't create flag yet
    JSR GetAreaObjXPosition  ; otherwise, obtain and save horizontal pixel coordinate
    PHA
    JSR FindEmptyEnemySlot  ; find an empty place on the enemy object buffer
    PLA
    STA ram_enemy_x_position,x  ; then write horizontal coordinate for star flag
    LDA ram_current_page_loc
    STA ram_enemy_page_loc,x  ; set page location for star flag
    LDA #$01
    STA ram_enemy_y_high_pos,x  ; set vertical high byte
    STA ram_enemy_flag,x  ; set flag for buffer
    LDA #$90
    STA ram_enemy_y_position,x  ; set vertical coordinate
    LDA #con_star_flag_object  ; set star flag value in buffer itself
    STA ram_enemy_id,x
    RTS
PlayerStop:
    LDY #$52  ; put brick at floor to stop player at end of level
    STY ram_metatile_buffer+10  ; this is only done if we're on the second column
ExitCastle:
    RTS

; --------------------------------

WaterPipe:
    JSR GetLrgObjAttrib  ; get row and lower nybble
    LDY ram_area_object_length,x  ; get length (residual code, water pipe is 1 col thick)
    LDX $07  ; get row
    LDA #$6b
    STA ram_metatile_buffer,x  ; draw something here and below it
    LDA #$6c
    STA ram_metatile_buffer+1,x
    RTS

; --------------------------------
; $05 - used to store length of vertical shaft in RenderSidewaysPipe
; $06 - used to store leftover horizontal length in RenderSidewaysPipe
; and vertical length in VerticalPipe and GetPipeHeight

IntroPipe:
    LDY #$03  ; check if length set, if not set, set it
    JSR ChkLrgObjFixedLength
    LDY #$0a  ; set fixed value and render the sideways part
    JSR RenderSidewaysPipe
    BCS NoBlankP  ; if carry flag set, not time to draw vertical pipe part
    LDX #$06  ; blank everything above the vertical pipe part
VPipeSectLoop:
    LDA #$00  ; all the way to the top of the screen
    STA ram_metatile_buffer,x  ; because otherwise it will look like exit pipe
    DEX
    BPL VPipeSectLoop
    LDA VerticalPipeData,y  ; draw the end of the vertical pipe part
    STA ram_metatile_buffer+7
NoBlankP:
    RTS

SidePipeShaftData:
    .byte $15, $14  ; used to control whether or not vertical pipe shaft
    .byte $00, $00  ; is drawn, and if so, controls the metatile number
SidePipeTopPart:
    .byte $15, $1e  ; top part of sideways part of pipe
    .byte $1d, $1c
SidePipeBottomPart:
    .byte $15, $21  ; bottom part of sideways part of pipe
    .byte $20, $1f

ExitPipe:
    LDY #$03  ; check if length set, if not set, set it
    JSR ChkLrgObjFixedLength
    JSR GetLrgObjAttrib  ; get vertical length, then plow on through RenderSidewaysPipe

RenderSidewaysPipe:
    DEY  ; decrement twice to make room for shaft at bottom
    DEY  ; and store here for now as vertical length
    STY $05
    LDY ram_area_object_length,x  ; get length left over and store here
    STY $06
    LDX $05  ; get vertical length plus one, use as buffer offset
    INX
    LDA SidePipeShaftData,y  ; check for value $00 based on horizontal offset
    CMP #$00
    BEQ DrawSidePart  ; if found, do not draw the vertical pipe shaft
    LDX #$00
    LDY $05  ; init buffer offset and get vertical length
    JSR RenderUnderPart  ; and render vertical shaft using tile number in A
    CLC  ; clear carry flag to be used by IntroPipe
DrawSidePart:
    LDY $06  ; render side pipe part at the bottom
    LDA SidePipeTopPart,y
    STA ram_metatile_buffer,x  ; note that the pipe parts are stored
    LDA SidePipeBottomPart,y  ; backwards horizontally
    STA ram_metatile_buffer+1,x
    RTS

VerticalPipeData:
    .byte $11, $10  ; used by pipes that lead somewhere
    .byte $15, $14
    .byte $13, $12  ; used by decoration pipes
    .byte $15, $14

VerticalPipe:
    JSR GetPipeHeight
    LDA $00  ; check to see if value was nullified earlier
    BEQ WarpPipe  ; (if d3, the usage control bit of second byte, was set)
    INY
    INY
    INY
    INY  ; add four if usage control bit was not set
WarpPipe:
    TYA  ; save value in stack
    PHA
    LDA ram_area_number
    ORA ram_world_number  ; if at world 1-1, do not add piranha plant ever
    BEQ DrawPipe
    LDY ram_area_object_length,x  ; if on second column of pipe, branch
    BEQ DrawPipe  ; (because we only need to do this once)
    JSR FindEmptyEnemySlot  ; check for an empty moving data buffer space
    BCS DrawPipe  ; if not found, too many enemies, thus skip
    JSR GetAreaObjXPosition  ; get horizontal pixel coordinate
    CLC
    ADC #$08  ; add eight to put the piranha plant in the center
    STA ram_enemy_x_position,x  ; store as enemy's horizontal coordinate
    LDA ram_current_page_loc  ; add carry to current page number
    ADC #$00
    STA ram_enemy_page_loc,x  ; store as enemy's page coordinate
    LDA #$01
    STA ram_enemy_y_high_pos,x
    STA ram_enemy_flag,x  ; activate enemy flag
    JSR GetAreaObjYPosition  ; get piranha plant's vertical coordinate and store here
    STA ram_enemy_y_position,x
    LDA #con_piranha_plant  ; write piranha plant's value into buffer
    STA ram_enemy_id,x
    JSR InitPiranhaPlant
DrawPipe:
    PLA  ; get value saved earlier and use as Y
    TAY
    LDX $07  ; get buffer offset
    LDA VerticalPipeData,y  ; draw the appropriate pipe with the Y we loaded earlier
    STA ram_metatile_buffer,x  ; render the top of the pipe
    INX
    LDA VerticalPipeData+2,y  ; render the rest of the pipe
    LDY $06  ; subtract one from length and render the part underneath
    DEY
    JMP RenderUnderPart

GetPipeHeight:
    LDY #$01  ; check for length loaded, if not, load
    JSR ChkLrgObjFixedLength  ; pipe length of 2 (horizontal)
    JSR GetLrgObjAttrib
    TYA  ; get saved lower nybble as height
    AND #$07  ; save only the three lower bits as
    STA $06  ; vertical length, then load Y with
    LDY ram_area_object_length,x  ; length left over
    RTS

FindEmptyEnemySlot:
    LDX #$00  ; start at first enemy slot
EmptyChkLoop:
    CLC  ; clear carry flag by default
    LDA ram_enemy_flag,x  ; check enemy buffer for nonzero
    BEQ ExitEmptyChk  ; if zero, leave
    INX
    CPX #$05  ; if nonzero, check next value
    BNE EmptyChkLoop
ExitEmptyChk:
    RTS  ; if all values nonzero, carry flag is set
