; -------------------------------------------------------------------------------------
; $00 - used to hold collision flag, Y movement force + 5 or low byte of name table for rope
; $01 - used to hold high byte of name table for rope
; $02 - used to hold page location of rope

BalancePlatform:
    LDA Enemy_Y_HighPos,x  ; check high byte of vertical position
    CMP #$03
    BNE DoBPl
    JMP EraseEnemyObject  ; if far below screen, kill the object
DoBPl:
    LDA Enemy_State,x  ; get object's state (set to $ff or other platform offset)
    BPL CheckBalPlatform  ; if doing other balance platform, branch to leave
    RTS

CheckBalPlatform:
    TAY  ; save offset from state as Y
    LDA PlatformCollisionFlag,x  ; get collision flag of platform
    STA $00  ; store here
    LDA Enemy_MovingDir,x  ; get moving direction
    BEQ ChkForFall
    JMP PlatformFall  ; if set, jump here

ChkForFall:
    LDA #$2d  ; check if platform is above a certain point
    CMP Enemy_Y_Position,x
    BCC ChkOtherForFall  ; if not, branch elsewhere
    CPY $00  ; if collision flag is set to same value as
    BEQ MakePlatformFall  ; enemy state, branch to make platforms fall
    CLC
    ADC #$02  ; otherwise add 2 pixels to vertical position
    STA Enemy_Y_Position,x  ; of current platform and branch elsewhere
    JMP StopPlatforms  ; to make platforms stop

MakePlatformFall:
    JMP InitPlatformFall  ; make platforms fall

ChkOtherForFall:
    CMP Enemy_Y_Position,y  ; check if other platform is above a certain point
    BCC ChkToMoveBalPlat  ; if not, branch elsewhere
    CPX $00  ; if collision flag is set to same value as
    BEQ MakePlatformFall  ; enemy state, branch to make platforms fall
    CLC
    ADC #$02  ; otherwise add 2 pixels to vertical position
    STA Enemy_Y_Position,y  ; of other platform and branch elsewhere
    JMP StopPlatforms  ; jump to stop movement and do not return

ChkToMoveBalPlat:
    LDA Enemy_Y_Position,x  ; save vertical position to stack
    PHA
    LDA PlatformCollisionFlag,x  ; get collision flag
    BPL ColFlg  ; branch if collision
    LDA Enemy_Y_MoveForce,x
    CLC  ; add $05 to contents of moveforce, whatever they be
    ADC #$05
    STA $00  ; store here
    LDA Enemy_Y_Speed,x
    ADC #$00  ; add carry to vertical speed
    BMI PlatDn  ; branch if moving downwards
    BNE PlatUp  ; branch elsewhere if moving upwards
    LDA $00
    CMP #$0b  ; check if there's still a little force left
    BCC PlatSt  ; if not enough, branch to stop movement
    BCS PlatUp  ; otherwise keep branch to move upwards
ColFlg:
    CMP ObjectOffset  ; if collision flag matches
    BEQ PlatDn  ; current enemy object offset, branch
PlatUp:
    JSR sub_move_platform_up  ; do a sub to move upwards
    JMP DoOtherPlatform  ; jump ahead to remaining code
PlatSt:
    JSR StopPlatforms  ; do a sub to stop movement
    JMP DoOtherPlatform  ; jump ahead to remaining code
PlatDn:
    JSR sub_move_platform_down  ; do a sub to move downwards

DoOtherPlatform:
    LDY Enemy_State,x  ; get offset of other platform
    PLA  ; get old vertical coordinate from stack
    SEC
    SBC Enemy_Y_Position,x  ; get difference of old vs. new coordinate
    CLC
    ADC Enemy_Y_Position,y  ; add difference to vertical coordinate of other
    STA Enemy_Y_Position,y  ; platform to move it in the opposite direction
    LDA PlatformCollisionFlag,x  ; if no collision, skip this part here
    BMI DrawEraseRope
    TAX  ; put offset which collision occurred here
    JSR PositionPlayerOnVPlat  ; and use it to position player accordingly

DrawEraseRope:
    LDY ObjectOffset  ; get enemy object offset
    LDA Enemy_Y_Speed,y  ; check to see if current platform is
    ORA Enemy_Y_MoveForce,y  ; moving at all
    BEQ ExitRp  ; if not, skip all of this and branch to leave
    LDX VRAM_Buffer1_Offset  ; get vram buffer offset
    CPX #$20  ; if offset beyond a certain point, go ahead
    BCS ExitRp  ; and skip this, branch to leave
    LDA Enemy_Y_Speed,y
    PHA  ; save two copies of vertical speed to stack
    PHA
    JSR SetupPlatformRope  ; do a sub to figure out where to put new bg tiles
    LDA $01  ; write name table address to vram buffer
    STA VRAM_Buffer1,x  ; first the high byte, then the low
    LDA $00
    STA VRAM_Buffer1+1,x
    LDA #$02  ; set length for 2 bytes
    STA VRAM_Buffer1+2,x
    LDA Enemy_Y_Speed,y  ; if platform moving upwards, branch
    BMI EraseR1  ; to do something else
    LDA #$a2
    STA VRAM_Buffer1+3,x  ; otherwise put tile numbers for left
    LDA #$a3  ; and right sides of rope in vram buffer
    STA VRAM_Buffer1+4,x
    JMP OtherRope  ; jump to skip this part
EraseR1:
    LDA #$24  ; put blank tiles in vram buffer
    STA VRAM_Buffer1+3,x  ; to erase rope
    STA VRAM_Buffer1+4,x

OtherRope:
    LDA Enemy_State,y  ; get offset of other platform from state
    TAY  ; use as Y here
    PLA  ; pull second copy of vertical speed from stack
    EOR #$ff  ; invert bits to reverse speed
    JSR SetupPlatformRope  ; do sub again to figure out where to put bg tiles
    LDA $01  ; write name table address to vram buffer
    STA VRAM_Buffer1+5,x  ; this time we're doing putting tiles for
    LDA $00  ; the other platform
    STA VRAM_Buffer1+6,x
    LDA #$02
    STA VRAM_Buffer1+7,x  ; set length again for 2 bytes
    PLA  ; pull first copy of vertical speed from stack
    BPL EraseR2  ; if moving upwards (note inversion earlier), skip this
    LDA #$a2
    STA VRAM_Buffer1+8,x  ; otherwise put tile numbers for left
    LDA #$a3  ; and right sides of rope in vram
    STA VRAM_Buffer1+9,x  ; transfer buffer
    JMP EndRp  ; jump to skip this part
EraseR2:
    LDA #$24  ; put blank tiles in vram buffer
    STA VRAM_Buffer1+8,x  ; to erase rope
    STA VRAM_Buffer1+9,x
EndRp:
    LDA #$00  ; put null terminator at the end
    STA VRAM_Buffer1+10,x
    LDA VRAM_Buffer1_Offset  ; add ten bytes to the vram buffer offset
    CLC  ; and store
    ADC #10
    STA VRAM_Buffer1_Offset
ExitRp:
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

SetupPlatformRope:
    PHA  ; save second/third copy to stack
    LDA Enemy_X_Position,y  ; get horizontal coordinate
    CLC
    ADC #$08  ; add eight pixels
    LDX SecondaryHardMode  ; if secondary hard mode flag set,
    BNE GetLRp  ; use coordinate as-is
    CLC
    ADC #$10  ; otherwise add sixteen more pixels
GetLRp:
    PHA  ; save modified horizontal coordinate to stack
    LDA Enemy_PageLoc,y
    ADC #$00  ; add carry to page location
    STA $02  ; and save here
    PLA  ; pull modified horizontal coordinate
    AND #%11110000  ; from the stack, mask out low nybble
    LSR  ; and shift three bits to the right
    LSR
    LSR
    STA $00  ; store result here as part of name table low byte
    LDX Enemy_Y_Position,y  ; get vertical coordinate
    PLA  ; get second/third copy of vertical speed from stack
    BPL GetHRp  ; skip this part if moving downwards or not at all
    TXA
    CLC
    ADC #$08  ; add eight to vertical coordinate and
    TAX  ; save as X
GetHRp:
    TXA  ; move vertical coordinate to A
    LDX VRAM_Buffer1_Offset  ; get vram buffer offset
    ASL
    ROL  ; rotate d7 to d0 and d6 into carry
    PHA  ; save modified vertical coordinate to stack
    ROL  ; rotate carry to d0, thus d7 and d6 are at 2 LSB
    AND #%00000011  ; mask out all bits but d7 and d6, then set
    ORA #%00100000  ; d5 to get appropriate high byte of name table
    STA $01  ; address, then store
    LDA $02  ; get saved page location from earlier
    AND #$01  ; mask out all but LSB
    ASL
    ASL  ; shift twice to the left and save with the
    ORA $01  ; rest of the bits of the high byte, to get
    STA $01  ; the proper name table and the right place on it
    PLA  ; get modified vertical coordinate from stack
    AND #%11100000  ; mask out low nybble and LSB of high nybble
    CLC
    ADC $00  ; add to horizontal part saved here
    STA $00  ; save as name table low byte
    LDA Enemy_Y_Position,y
    CMP #$e8  ; if vertical position not below the
    BCC ExPRp  ; bottom of the screen, we're done, branch to leave
    LDA $00
    AND #%10111111  ; mask out d6 of low byte of name table address
    STA $00
ExPRp:
    RTS  ; leave!

InitPlatformFall:
    TYA  ; move offset of other platform from Y to X
    TAX
    JSR GetEnemyOffscreenBits  ; get offscreen bits
    LDA #$06
    JSR SetupFloateyNumber  ; award 1000 points to player
    LDA Player_Rel_XPos
    STA FloateyNum_X_Pos,x  ; put floatey number coordinates where player is
    LDA Player_Y_Position
    STA FloateyNum_Y_Pos,x
    LDA #$01  ; set moving direction as flag for
    STA Enemy_MovingDir,x  ; falling platforms

StopPlatforms:
    JSR InitVStf  ; initialize vertical speed and low byte
    STA Enemy_Y_Speed,y  ; for both platforms and leave
    STA Enemy_Y_MoveForce,y
    RTS

PlatformFall:
    TYA  ; save offset for other platform to stack
    PHA
    JSR sub_move_falling_platform  ; make current platform fall
    PLA
    TAX  ; pull offset from stack and save to X
    JSR sub_move_falling_platform  ; make other platform fall
    LDX ObjectOffset
    LDA PlatformCollisionFlag,x  ; if player not standing on either platform,
    BMI ExPF  ; skip this part
    TAX  ; transfer collision flag offset as offset to X
    JSR PositionPlayerOnVPlat  ; and position player appropriately
ExPF:
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------

YMovingPlatform:
    LDA Enemy_Y_Speed,x  ; if platform moving up or down, skip ahead to
    ORA Enemy_Y_MoveForce,x  ; check on other position
    BNE ChkYCenterPos
    STA Enemy_YMF_Dummy,x  ; initialize dummy variable
    LDA Enemy_Y_Position,x
    CMP YPlatformTopYPos,x  ; if current vertical position => top position, branch
    BCS ChkYCenterPos  ; ahead of all this
    LDA FrameCounter
    AND #%00000111  ; check for every eighth frame
    BNE SkipIY
    INC Enemy_Y_Position,x  ; increase vertical position every eighth frame
SkipIY:
    JMP ChkYPCollision  ; skip ahead to last part

ChkYCenterPos:
    LDA Enemy_Y_Position,x  ; if current vertical position < central position, branch
    CMP YPlatformCenterYPos,x  ; to slow ascent/move downwards
    BCC YMDown
    JSR sub_move_platform_up  ; otherwise start slowing descent/moving upwards
    JMP ChkYPCollision
YMDown:
    JSR sub_move_platform_down  ; start slowing ascent/moving downwards

ChkYPCollision:
    LDA PlatformCollisionFlag,x  ; if collision flag not set here, branch
    BMI ExYPl  ; to leave
    JSR PositionPlayerOnVPlat  ; otherwise position player appropriately
ExYPl:
    RTS  ; leave

; --------------------------------
; $00 - used as adder to position player hotizontally

XMovingPlatform:
    LDA #$0e  ; load preset maximum value for secondary counter
    JSR XMoveCntr_Platform  ; do a sub to increment counters for movement
    JSR MoveWithXMCntrs  ; do a sub to move platform accordingly, and return value
    LDA PlatformCollisionFlag,x  ; if no collision with player,
    BMI ExXMP  ; branch ahead to leave

PositionPlayerOnHPlat:
    LDA Player_X_Position
    CLC  ; add saved value from second subroutine to
    ADC $00  ; current player's position to position
    STA Player_X_Position  ; player accordingly in horizontal position
    LDA Player_PageLoc  ; get player's page location
    LDY $00  ; check to see if saved value here is positive or negative
    BMI PPHSubt  ; if negative, branch to subtract
    ADC #$00  ; otherwise add carry to page location
    JMP SetPVar  ; jump to skip subtraction
PPHSubt:
    SBC #$00  ; subtract borrow from page location
SetPVar:
    STA Player_PageLoc  ; save result to player's page location
    STY Platform_X_Scroll  ; put saved value from second sub here to be used later
    JSR PositionPlayerOnVPlat  ; position player vertically and appropriately
ExXMP:
    RTS  ; and we are done here

; --------------------------------

DropPlatform:
    LDA PlatformCollisionFlag,x  ; if no collision between platform and player
    BMI ExDPl  ; occurred, just leave without moving anything
    JSR sub_move_drop_platform  ; otherwise do a sub to move platform down very quickly
    JSR PositionPlayerOnVPlat  ; do a sub to position player appropriately
ExDPl:
    RTS  ; leave

; --------------------------------
; $00 - residual value from sub

RightPlatform:
    JSR sub_move_enemy_horizontally  ; move platform with current horizontal speed, if any
    STA $00  ; store saved value here (residual code)
    LDA PlatformCollisionFlag,x  ; check collision flag, if no collision between player
    BMI ExRPl  ; and platform, branch ahead, leave speed unaltered
    LDA #$10
    STA Enemy_X_Speed,x  ; otherwise set new speed (gets moving if motionless)
    JSR PositionPlayerOnHPlat  ; use saved value from earlier sub to position player
ExRPl:
    RTS  ; then leave

; --------------------------------

MoveLargeLiftPlat:
    JSR MoveLiftPlatforms  ; execute common to all large and small lift platforms
    JMP ChkYPCollision  ; branch to position player correctly

MoveSmallPlatform:
    JSR MoveLiftPlatforms  ; execute common to all large and small lift platforms
    JMP ChkSmallPlatCollision  ; branch to position player correctly

MoveLiftPlatforms:
    LDA TimerControl  ; if master timer control set, skip all of this
    BNE ExLiftP  ; and branch to leave
    LDA Enemy_YMF_Dummy,x
    CLC  ; add contents of movement amount to whatever's here
    ADC Enemy_Y_MoveForce,x
    STA Enemy_YMF_Dummy,x
    LDA Enemy_Y_Position,x  ; add whatever vertical speed is set to current
    ADC Enemy_Y_Speed,x  ; vertical position plus carry to move up or down
    STA Enemy_Y_Position,x  ; and then leave
    RTS

ChkSmallPlatCollision:
    LDA PlatformCollisionFlag,x  ; get bounding box counter saved in collision flag
    BEQ ExLiftP  ; if none found, leave player position alone
    JSR PositionPlayerOnS_Plat  ; use to position player correctly
ExLiftP:
    RTS  ; then leave

; -------------------------------------------------------------------------------------
; $00 - page location of extended left boundary
; $01 - extended left boundary position
; $02 - page location of extended right boundary
; $03 - extended right boundary position

OffscreenBoundsCheck:
    LDA Enemy_ID,x  ; check for cheep-cheep object
    CMP #FlyingCheepCheep  ; branch to leave if found
    BEQ ExScrnBd
    LDA ScreenLeft_X_Pos  ; get horizontal coordinate for left side of screen
    LDY Enemy_ID,x
    CPY #HammerBro  ; check for hammer bro object
    BEQ LimitB
    CPY #PiranhaPlant  ; check for piranha plant object
    BNE ExtendLB  ; these two will be erased sooner than others if too far left
LimitB:
    ADC #$38  ; add 56 pixels to coordinate if hammer bro or piranha plant
ExtendLB:
    SBC #$48  ; subtract 72 pixels regardless of enemy object
    STA $01  ; store result here
    LDA ScreenLeft_PageLoc
    SBC #$00  ; subtract borrow from page location of left side
    STA $00  ; store result here
    LDA ScreenRight_X_Pos  ; add 72 pixels to the right side horizontal coordinate
    ADC #$48
    STA $03  ; store result here
    LDA ScreenRight_PageLoc
    ADC #$00  ; then add the carry to the page location
    STA $02  ; and store result here
    LDA Enemy_X_Position,x  ; compare horizontal coordinate of the enemy object
    CMP $01  ; to modified horizontal left edge coordinate to get carry
    LDA Enemy_PageLoc,x
    SBC $00  ; then subtract it from the page coordinate of the enemy object
    BMI TooFar  ; if enemy object is too far left, branch to erase it
    LDA Enemy_X_Position,x  ; compare horizontal coordinate of the enemy object
    CMP $03  ; to modified horizontal right edge coordinate to get carry
    LDA Enemy_PageLoc,x
    SBC $02  ; then subtract it from the page coordinate of the enemy object
    BMI ExScrnBd  ; if enemy object is on the screen, leave, do not erase enemy
    LDA Enemy_State,x  ; if at this point, enemy is offscreen to the right, so check
    CMP #HammerBro  ; if in state used by spiny's egg, do not erase
    BEQ ExScrnBd
    CPY #PiranhaPlant  ; if piranha plant, do not erase
    BEQ ExScrnBd
    CPY #FlagpoleFlagObject  ; if flagpole flag, do not erase
    BEQ ExScrnBd
    CPY #StarFlagObject  ; if star flag, do not erase
    BEQ ExScrnBd
    CPY #JumpspringObject  ; if jumpspring, do not erase
    BEQ ExScrnBd  ; erase all others too far to the right
TooFar:
    JSR EraseEnemyObject  ; erase object if necessary
ExScrnBd:
    RTS  ; leave

; -------------------------------------------------------------------------------------

; some unused space
    .byte $ff, $ff, $ff
