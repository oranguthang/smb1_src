; -------------------------------------------------------------------------------------
; $00 - used to store downward movement force in FireballObjCore
; $02 - used to store maximum vertical speed in FireballObjCore
; $07 - used to store pseudorandom bit in BubbleCheck

ProcFireball_Bubble:
    LDA PlayerStatus  ; check player's status
    CMP #$02
    BCC ProcAirBubbles  ; if not fiery, branch
    LDA A_B_Buttons
    AND #B_Button  ; check for b button pressed
    BEQ ProcFireballs  ; branch if not pressed
    AND PreviousA_B_Buttons
    BNE ProcFireballs  ; if button pressed in previous frame, branch
    LDA FireballCounter  ; load fireball counter
    AND #%00000001  ; get LSB and use as offset for buffer
    TAX
    LDA Fireball_State,x  ; load fireball state
    BNE ProcFireballs  ; if not inactive, branch
    LDY Player_Y_HighPos  ; if player too high or too low, branch
    DEY
    BNE ProcFireballs
    LDA CrouchingFlag  ; if player crouching, branch
    BNE ProcFireballs
    LDA Player_State  ; if player's state = climbing, branch
    CMP #$03
    BEQ ProcFireballs
    LDA #Sfx_Fireball  ; play fireball sound effect
    STA Square1SoundQueue
    LDA #$02  ; load state
    STA Fireball_State,x
    LDY PlayerAnimTimerSet  ; copy animation frame timer setting
    STY FireballThrowingTimer  ; into fireball throwing timer
    DEY
    STY PlayerAnimTimer  ; decrement and store in player's animation timer
    INC FireballCounter  ; increment fireball counter

ProcFireballs:
    LDX #$00
    JSR FireballObjCore  ; process first fireball object
    LDX #$01
    JSR FireballObjCore  ; process second fireball object, then do air bubbles

ProcAirBubbles:
    LDA AreaType  ; if not water type level, skip the rest of this
    BNE BublExit
    LDX #$02  ; otherwise load counter and use as offset
BublLoop:
    STX ObjectOffset  ; store offset
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
    STX ObjectOffset  ; store offset as current object
    LDA Fireball_State,x  ; check for d7 = 1
    ASL
    BCS FireballExplosion  ; if so, branch to get relative coordinates and draw explosion
    LDY Fireball_State,x  ; if fireball inactive, branch to leave
    BEQ NoFBall
    DEY  ; if fireball state set to 1, skip this part and just run it
    BEQ RunFB
    LDA Player_X_Position  ; get player's horizontal position
    ADC #$04  ; add four pixels and store as fireball's horizontal position
    STA Fireball_X_Position,x
    LDA Player_PageLoc  ; get player's page location
    ADC #$00  ; add carry and store as fireball's page location
    STA Fireball_PageLoc,x
    LDA Player_Y_Position  ; get player's vertical position and store
    STA Fireball_Y_Position,x
    LDA #$01  ; set high byte of vertical position
    STA Fireball_Y_HighPos,x
    LDY PlayerFacingDir  ; get player's facing direction
    DEY  ; decrement to use as offset here
    LDA FireballXSpdData,y  ; set horizontal speed of fireball accordingly
    STA Fireball_X_Speed,x
    LDA #$04  ; set vertical speed of fireball
    STA Fireball_Y_Speed,x
    LDA #$07
    STA Fireball_BoundBoxCtrl,x  ; set bounding box size control for fireball
    DEC Fireball_State,x  ; decrement state to 1 to skip this part from now on
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
    JSR ImposeGravity  ; do sub here to impose gravity on fireball and move vertically
    JSR MoveObjectHorizontally  ; do another sub to move it horizontally
    LDX ObjectOffset  ; return fireball offset to X
    JSR RelativeFireballPosition  ; get relative coordinates
    JSR GetFireballOffscreenBits  ; get offscreen information
    JSR GetFireballBoundBox  ; get bounding box coordinates
    JSR FireballBGCollision  ; do fireball to background collision detection
    LDA FBall_OffscreenBits  ; get fireball offscreen bits
    AND #%11001100  ; mask out certain bits
    BNE EraseFB  ; if any bits still set, branch to kill fireball
    JSR FireballEnemyCollision  ; do fireball to enemy collision detection and deal with collisions
    JMP DrawFireball  ; draw fireball appropriately and leave
EraseFB:
    LDA #$00  ; erase fireball state
    STA Fireball_State,x
NoFBall:
    RTS  ; leave

FireballExplosion:
    JSR RelativeFireballPosition
    JMP DrawExplosion_Fireball

BubbleCheck:
    LDA PseudoRandomBitReg+1,x  ; get part of LSFR
    AND #$01
    STA $07  ; store pseudorandom bit here
    LDA Bubble_Y_Position,x  ; get vertical coordinate for air bubble
    CMP #$f8  ; if offscreen coordinate not set,
    BNE MoveBubl  ; branch to move air bubble
    LDA AirBubbleTimer  ; if air bubble timer not expired,
    BNE ExitBubl  ; branch to leave, otherwise create new air bubble

SetupBubble:
    LDY #$00  ; load default value here
    LDA PlayerFacingDir  ; get player's facing direction
    LSR  ; move d0 to carry
    BCC PosBubl  ; branch to use default value if facing left
    LDY #$08  ; otherwise load alternate value here
PosBubl:
    TYA  ; use value loaded as adder
    ADC Player_X_Position  ; add to player's horizontal position
    STA Bubble_X_Position,x  ; save as horizontal position for airbubble
    LDA Player_PageLoc
    ADC #$00  ; add carry to player's page location
    STA Bubble_PageLoc,x  ; save as page location for airbubble
    LDA Player_Y_Position
    CLC  ; add eight pixels to player's vertical position
    ADC #$08
    STA Bubble_Y_Position,x  ; save as vertical position for air bubble
    LDA #$01
    STA Bubble_Y_HighPos,x  ; set vertical high byte for air bubble
    LDY $07  ; get pseudorandom bit, use as offset
    LDA BubbleTimerData,y  ; get data for air bubble timer
    STA AirBubbleTimer  ; set air bubble timer
MoveBubl:
    LDY $07  ; get pseudorandom bit again, use as offset
    LDA Bubble_YMF_Dummy,x
    SEC  ; subtract pseudorandom amount from dummy variable
    SBC Bubble_MForceData,y
    STA Bubble_YMF_Dummy,x  ; save dummy variable
    LDA Bubble_Y_Position,x
    SBC #$00  ; subtract borrow from airbubble's vertical coordinate
    CMP #$20  ; if below the status bar,
    BCS Y_Bubl  ; branch to go ahead and use to move air bubble upwards
    LDA #$f8  ; otherwise set offscreen coordinate
Y_Bubl:
    STA Bubble_Y_Position,x  ; store as new vertical coordinate for air bubble
ExitBubl:
    RTS  ; leave

Bubble_MForceData:
    .byte $ff, $50

BubbleTimerData:
    .byte $40, $20

; -------------------------------------------------------------------------------------

RunGameTimer:
    LDA OperMode  ; get primary mode of operation
    BEQ ExGTimer  ; branch to leave if in title screen mode
    LDA GameEngineSubroutine
    CMP #$08  ; if routine number less than eight running,
    BCC ExGTimer  ; branch to leave
    CMP #$0b  ; if running death routine,
    BEQ ExGTimer  ; branch to leave
    LDA Player_Y_HighPos
    CMP #$02  ; if player below the screen,
    BCS ExGTimer  ; branch to leave regardless of level type
    LDA GameTimerCtrlTimer  ; if game timer control not yet expired,
    BNE ExGTimer  ; branch to leave
    LDA GameTimerDisplay
    ORA GameTimerDisplay+1  ; otherwise check game timer digits
    ORA GameTimerDisplay+2
    BEQ TimeUpOn  ; if game timer digits at 000, branch to time-up code
    LDY GameTimerDisplay  ; otherwise check first digit
    DEY  ; if first digit not on 1,
    BNE ResGTCtrl  ; branch to reset game timer control
    LDA GameTimerDisplay+1  ; otherwise check second and third digits
    ORA GameTimerDisplay+2
    BNE ResGTCtrl  ; if timer not at 100, branch to reset game timer control
    LDA #TimeRunningOutMusic
    STA EventMusicQueue  ; otherwise load time running out music
ResGTCtrl:
    LDA #$18  ; reset game timer control
    STA GameTimerCtrlTimer
    LDY #$23  ; set offset for last digit
    LDA #$ff  ; set value to decrement game timer digit
    STA DigitModifier+5
    JSR DigitsMathRoutine  ; do sub to decrement game timer slowly
    LDA #$a4  ; set status nybbles to update game timer display
    JMP PrintStatusBarNumbers  ; do sub to update the display
TimeUpOn:
    STA PlayerStatus  ; init player status (note A will always be zero here)
    JSR ForceInjury  ; do sub to kill the player (note player is small here)
    INC GameTimerExpiredFlag  ; set game timer expiration flag
ExGTimer:
    RTS  ; leave

; -------------------------------------------------------------------------------------

WarpZoneObject:
    LDA ScrollLock  ; check for scroll lock flag
    BEQ ExGTimer  ; branch if not set to leave
    LDA Player_Y_Position  ; check to see if player's vertical coordinate has
    AND Player_Y_HighPos  ; same bits set as in vertical high byte (why?)
    BNE ExGTimer  ; if so, branch to leave
    STA ScrollLock  ; otherwise nullify scroll lock flag
    INC WarpZoneControl  ; increment warp zone flag to make warp pipes for warp zone
    JMP EraseEnemyObject  ; kill this object

; -------------------------------------------------------------------------------------
; $00 - used in WhirlpoolActivate to store whirlpool length / 2, page location of center of whirlpool
; and also to store movement force exerted on player
; $01 - used in ProcessWhirlpools to store page location of right extent of whirlpool
; and in WhirlpoolActivate to store center of whirlpool
; $02 - used in ProcessWhirlpools to store right extent of whirlpool and in
; WhirlpoolActivate to store maximum vertical speed

ProcessWhirlpools:
    LDA AreaType  ; check for water type level
    BNE ExitWh  ; branch to leave if not found
    STA Whirlpool_Flag  ; otherwise initialize whirlpool flag
    LDA TimerControl  ; if master timer control set,
    BNE ExitWh  ; branch to leave
    LDY #$04  ; otherwise start with last whirlpool data
WhLoop:
    LDA Whirlpool_LeftExtent,y  ; get left extent of whirlpool
    CLC
    ADC Whirlpool_Length,y  ; add length of whirlpool
    STA $02  ; store result as right extent here
    LDA Whirlpool_PageLoc,y  ; get page location
    BEQ NextWh  ; if none or page 0, branch to get next data
    ADC #$00  ; add carry
    STA $01  ; store result as page location of right extent here
    LDA Player_X_Position  ; get player's horizontal position
    SEC
    SBC Whirlpool_LeftExtent,y  ; subtract left extent
    LDA Player_PageLoc  ; get player's page location
    SBC Whirlpool_PageLoc,y  ; subtract borrow
    BMI NextWh  ; if player too far left, branch to get next data
    LDA $02  ; otherwise get right extent
    SEC
    SBC Player_X_Position  ; subtract player's horizontal coordinate
    LDA $01  ; get right extent's page location
    SBC Player_PageLoc  ; subtract borrow
    BPL WhirlpoolActivate  ; if player within right extent, branch to whirlpool code
NextWh:
    DEY  ; move onto next whirlpool data
    BPL WhLoop  ; do this until all whirlpools are checked
ExitWh:
    RTS  ; leave

WhirlpoolActivate:
    LDA Whirlpool_Length,y  ; get length of whirlpool
    LSR  ; divide by 2
    STA $00  ; save here
    LDA Whirlpool_LeftExtent,y  ; get left extent of whirlpool
    CLC
    ADC $00  ; add length divided by 2
    STA $01  ; save as center of whirlpool
    LDA Whirlpool_PageLoc,y  ; get page location
    ADC #$00  ; add carry
    STA $00  ; save as page location of whirlpool center
    LDA FrameCounter  ; get frame counter
    LSR  ; shift d0 into carry (to run on every other frame)
    BCC WhPull  ; if d0 not set, branch to last part of code
    LDA $01  ; get center
    SEC
    SBC Player_X_Position  ; subtract player's horizontal coordinate
    LDA $00  ; get page location of center
    SBC Player_PageLoc  ; subtract borrow
    BPL LeftWh  ; if player to the left of center, branch
    LDA Player_X_Position  ; otherwise slowly pull player left, towards the center
    SEC
    SBC #$01  ; subtract one pixel
    STA Player_X_Position  ; set player's new horizontal coordinate
    LDA Player_PageLoc
    SBC #$00  ; subtract borrow
    JMP SetPWh  ; jump to set player's new page location
LeftWh:
    LDA Player_CollisionBits  ; get player's collision bits
    LSR  ; shift d0 into carry
    BCC WhPull  ; if d0 not set, branch
    LDA Player_X_Position  ; otherwise slowly pull player right, towards the center
    CLC
    ADC #$01  ; add one pixel
    STA Player_X_Position  ; set player's new horizontal coordinate
    LDA Player_PageLoc
    ADC #$00  ; add carry
SetPWh:
    STA Player_PageLoc  ; set player's new page location
WhPull:
    LDA #$10
    STA $00  ; set vertical movement force
    LDA #$01
    STA Whirlpool_Flag  ; set whirlpool flag to be used later
    STA $02  ; also set maximum vertical speed
    LSR
    TAX  ; set X for player offset
    JMP ImposeGravity  ; jump to put whirlpool effect on player vertically, do not return

; -------------------------------------------------------------------------------------

FlagpoleScoreMods:
    .byte $05, $02, $08, $04, $01

FlagpoleScoreDigits:
    .byte $03, $03, $04, $04, $04

FlagpoleRoutine:
    LDX #$05  ; set enemy object offset
    STX ObjectOffset  ; to special use slot
    LDA Enemy_ID,x
    CMP #FlagpoleFlagObject  ; if flagpole flag not found,
    BNE ExitFlagP  ; branch to leave
    LDA GameEngineSubroutine
    CMP #$04  ; if flagpole slide routine not running,
    BNE SkipScore  ; branch to near the end of code
    LDA Player_State
    CMP #$03  ; if player state not climbing,
    BNE SkipScore  ; branch to near the end of code
    LDA Enemy_Y_Position,x  ; check flagpole flag's vertical coordinate
    CMP #$aa  ; if flagpole flag down to a certain point,
    BCS GiveFPScr  ; branch to end the level
    LDA Player_Y_Position  ; check player's vertical coordinate
    CMP #$a2  ; if player down to a certain point,
    BCS GiveFPScr  ; branch to end the level
    LDA Enemy_YMF_Dummy,x
    ADC #$ff  ; add movement amount to dummy variable
    STA Enemy_YMF_Dummy,x  ; save dummy variable
    LDA Enemy_Y_Position,x  ; get flag's vertical coordinate
    ADC #$01  ; add 1 plus carry to move flag, and
    STA Enemy_Y_Position,x  ; store vertical coordinate
    LDA FlagpoleFNum_YMFDummy
    SEC  ; subtract movement amount from dummy variable
    SBC #$ff
    STA FlagpoleFNum_YMFDummy  ; save dummy variable
    LDA FlagpoleFNum_Y_Pos
    SBC #$01  ; subtract one plus borrow to move floatey number,
    STA FlagpoleFNum_Y_Pos  ; and store vertical coordinate here
SkipScore:
    JMP FPGfx  ; jump to skip ahead and draw flag and floatey number
GiveFPScr:
    LDY FlagpoleScore  ; get score offset from earlier (when player touched flagpole)
    LDA FlagpoleScoreMods,y  ; get amount to award player points
    LDX FlagpoleScoreDigits,y  ; get digit with which to award points
    STA DigitModifier,x  ; store in digit modifier
    JSR AddToScore  ; do sub to award player points depending on height of collision
    LDA #$05
    STA GameEngineSubroutine  ; set to run end-of-level subroutine on next frame
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
    LDA TimerControl  ; check master timer control
    BNE DrawJSpr  ; branch to last section if set
    LDA JumpspringAnimCtrl  ; check jumpspring frame control
    BEQ DrawJSpr  ; branch to last section if not set
    TAY
    DEY  ; subtract one from frame control,
    TYA  ; the only way a poor nmos 6502 can
    AND #%00000010  ; mask out all but d1, original value still in Y
    BNE DownJSpr  ; if set, branch to move player up
    INC Player_Y_Position
    INC Player_Y_Position  ; move player's vertical position down two pixels
    JMP PosJSpr  ; skip to next part
DownJSpr:
    DEC Player_Y_Position  ; move player's vertical position up two pixels
    DEC Player_Y_Position
PosJSpr:
    LDA Jumpspring_FixedYPos,x  ; get permanent vertical position
    CLC
    ADC Jumpspring_Y_PosData,y  ; add value using frame control as offset
    STA Enemy_Y_Position,x  ; store as new vertical position
    CPY #$01  ; check frame control offset (second frame is $00)
    BCC BounceJS  ; if offset not yet at third frame ($01), skip to next part
    LDA A_B_Buttons
    AND #A_Button  ; check saved controller bits for A button press
    BEQ BounceJS  ; skip to next part if A not pressed
    AND PreviousA_B_Buttons  ; check for A button pressed in previous frame
    BNE BounceJS  ; skip to next part if so
    LDA #$f4
    STA JumpspringForce  ; otherwise write new jumpspring force here
BounceJS:
    CPY #$03  ; check frame control offset again
    BNE DrawJSpr  ; skip to last part if not yet at fifth frame ($03)
    LDA JumpspringForce
    STA Player_Y_Speed  ; store jumpspring force as player's new vertical speed
    LDA #$00
    STA JumpspringAnimCtrl  ; initialize jumpspring frame control
DrawJSpr:
    JSR RelativeEnemyPosition  ; get jumpspring's relative coordinates
    JSR EnemyGfxHandler  ; draw jumpspring
    JSR OffscreenBoundsCheck  ; check to see if we need to kill it
    LDA JumpspringAnimCtrl  ; if frame control at zero, don't bother
    BEQ ExJSpring  ; trying to animate it, just leave
    LDA JumpspringTimer
    BNE ExJSpring  ; if jumpspring timer not expired yet, leave
    LDA #$04
    STA JumpspringTimer  ; otherwise initialize jumpspring timer
    INC JumpspringAnimCtrl  ; increment frame control to animate jumpspring
ExJSpring:
    RTS  ; leave

; -------------------------------------------------------------------------------------

Setup_Vine:
    LDA #VineObject  ; load identifier for vine object
    STA Enemy_ID,x  ; store in buffer
    LDA #$01
    STA Enemy_Flag,x  ; set flag for enemy object buffer
    LDA Block_PageLoc,y
    STA Enemy_PageLoc,x  ; copy page location from previous object
    LDA Block_X_Position,y
    STA Enemy_X_Position,x  ; copy horizontal coordinate from previous object
    LDA Block_Y_Position,y
    STA Enemy_Y_Position,x  ; copy vertical coordinate from previous object
    LDY VineFlagOffset  ; load vine flag/offset to next available vine slot
    BNE NextVO  ; if set at all, don't bother to store vertical
    STA VineStart_Y_Position  ; otherwise store vertical coordinate here
NextVO:
    TXA  ; store object offset to next available vine slot
    STA VineObjOffset,y  ; using vine flag as offset
    INC VineFlagOffset  ; increment vine flag offset
    LDA #Sfx_GrowVine
    STA Square2SoundQueue  ; load vine grow sound
    RTS

; -------------------------------------------------------------------------------------
; $06-$07 - used as address to block buffer data
; $02 - used as vertical high nybble of block buffer offset

VineHeightData:
    .byte $30, $60

VineObjectHandler:
    CPX #$05  ; check enemy offset for special use slot
    BNE ExitVH  ; if not in last slot, branch to leave
    LDY VineFlagOffset
    DEY  ; decrement vine flag in Y, use as offset
    LDA VineHeight
    CMP VineHeightData,y  ; if vine has reached certain height,
    BEQ RunVSubs  ; branch ahead to skip this part
    LDA FrameCounter  ; get frame counter
    LSR  ; shift d1 into carry
    LSR
    BCC RunVSubs  ; if d1 not set (2 frames every 4) skip this part
    LDA Enemy_Y_Position+5
    SBC #$01  ; subtract vertical position of vine
    STA Enemy_Y_Position+5  ; one pixel every frame it's time
    INC VineHeight  ; increment vine height
RunVSubs:
    LDA VineHeight  ; if vine still very small,
    CMP #$08  ; branch to leave
    BCC ExitVH
    JSR RelativeEnemyPosition  ; get relative coordinates of vine,
    JSR GetEnemyOffscreenBits  ; and any offscreen bits
    LDY #$00  ; initialize offset used in draw vine sub
VDrawLoop:
    JSR DrawVine  ; draw vine
    INY  ; increment offset
    CPY VineFlagOffset  ; if offset in Y and offset here
    BNE VDrawLoop  ; do not yet match, loop back to draw more vine
    LDA Enemy_OffscreenBits
    AND #%00001100  ; mask offscreen bits
    BEQ WrCMTile  ; if none of the saved offscreen bits set, skip ahead
    DEY  ; otherwise decrement Y to get proper offset again
KillVine:
    LDX VineObjOffset,y  ; get enemy object offset for this vine object
    JSR EraseEnemyObject  ; kill this vine object
    DEY  ; decrement Y
    BPL KillVine  ; if any vine objects left, loop back to kill it
    STA VineFlagOffset  ; initialize vine flag/offset
    STA VineHeight  ; initialize vine height
WrCMTile:
    LDA VineHeight  ; check vine height
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
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS
