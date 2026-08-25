; -------------------------------------------------------------------------------------

; indirect jump routine called when
; $0770 is set to 1
GameMode:
    LDA OperMode_Task
    JSR sub_dispatch_inline_handler

    .word InitializeArea
    .word ScreenRoutines
    .word SecondaryGameSetup
    .word GameCoreRoutine

; -------------------------------------------------------------------------------------

GameCoreRoutine:
    LDX CurrentPlayer  ; get which player is on the screen
    LDA SavedJoypadBits,x  ; use appropriate player's controller bits
    STA SavedJoypadBits  ; as the master controller bits
    JSR GameRoutines  ; execute one of many possible subs
    LDA OperMode_Task  ; check major task of operating mode
    CMP #$03  ; if we are supposed to be here,
    BCS GameEngine  ; branch to the game engine itself
    RTS

GameEngine:
    JSR ProcFireball_Bubble  ; process fireballs and air bubbles
    LDX #$00
ProcELoop:
    STX ObjectOffset  ; put incremented offset in X as enemy object offset
    JSR EnemiesAndLoopsCore  ; process enemy objects
    JSR FloateyNumbersRoutine  ; process floatey numbers
    INX
    CPX #$06  ; do these two subroutines until the whole buffer is done
    BNE ProcELoop
    JSR GetPlayerOffscreenBits  ; get offscreen bits for player object
    JSR RelativePlayerPosition  ; get relative coordinates for player object
    JSR PlayerGfxHandler  ; draw the player
    JSR BlockObjMT_Updater  ; replace block objects with metatiles if necessary
    LDX #$01
    STX ObjectOffset  ; set offset for second
    JSR BlockObjectsCore  ; process second block object
    DEX
    STX ObjectOffset  ; set offset for first
    JSR BlockObjectsCore  ; process first block object
    JSR MiscObjectsCore  ; process misc objects (hammer, jumping coins)
    JSR ProcessCannons  ; process bullet bill cannons
    JSR ProcessWhirlpools  ; process whirlpools
    JSR FlagpoleRoutine  ; process the flagpole
    JSR RunGameTimer  ; count down the game timer
    JSR ColorRotation  ; cycle one of the background colors
    LDA Player_Y_HighPos
    CMP #$02  ; if player is below the screen, don't bother with the music
    BPL NoChgMus
    LDA StarInvincibleTimer  ; if star mario invincibility timer at zero,
    BEQ ClrPlrPal  ; skip this part
    CMP #$04
    BNE NoChgMus  ; if not yet at a certain point, continue
    LDA IntervalTimerControl  ; if interval timer not yet expired,
    BNE NoChgMus  ; branch ahead, don't bother with the music
    JSR GetAreaMusic  ; to re-attain appropriate level music
NoChgMus:
    LDY StarInvincibleTimer  ; get invincibility timer
    LDA FrameCounter  ; get frame counter
    CPY #$08  ; if timer still above certain point,
    BCS CycleTwo  ; branch to cycle player's palette quickly
    LSR  ; otherwise, divide by 8 to cycle every eighth frame
    LSR
CycleTwo:
    LSR  ; if branched here, divide by 2 to cycle every other frame
    JSR CyclePlayerPalette  ; do sub to cycle the palette (note: shares fire flower code)
    JMP SaveAB  ; then skip this sub to finish up the game engine
ClrPlrPal:
    JSR ResetPalStar  ; do sub to clear player's palette bits in attributes
SaveAB:
    LDA A_B_Buttons  ; save current A and B button
    STA PreviousA_B_Buttons  ; into temp variable to be used on next frame
    LDA #$00
    STA Left_Right_Buttons  ; nullify left and right buttons temp variable
UpdScrollVar:
    LDA VRAM_Buffer_AddrCtrl
    CMP #$06  ; if vram address controller set to 6 (one of two $0341s)
    BEQ ExitEng  ; then branch to leave
    LDA AreaParserTaskNum  ; otherwise check number of tasks
    BNE RunParser
    LDA ScrollThirtyTwo  ; get horizontal scroll in 0-31 or $00-$20 range
    CMP #$20  ; check to see if exceeded $21
    BMI ExitEng  ; branch to leave if not
    LDA ScrollThirtyTwo
    SBC #$20  ; otherwise subtract $20 to set appropriately
    STA ScrollThirtyTwo  ; and store
    LDA #$00  ; reset vram buffer offset used in conjunction with
    STA VRAM_Buffer2_Offset  ; level graphics buffer at $0341-$035f
RunParser:
    JSR AreaParserTaskHandler  ; update the name table with more level graphics
ExitEng:
    RTS  ; and after all that, we're finally done!

; -------------------------------------------------------------------------------------

ScrollHandler:
    LDA Player_X_Scroll  ; load value saved here
    CLC
    ADC Platform_X_Scroll  ; add value used by left/right platforms
    STA Player_X_Scroll  ; save as new value here to impose force on scroll
    LDA ScrollLock  ; check scroll lock flag
    BNE InitScrlAmt  ; skip a bunch of code here if set
    LDA Player_Pos_ForScroll
    CMP #$50  ; check player's horizontal screen position
    BCC InitScrlAmt  ; if less than 80 pixels to the right, branch
    LDA SideCollisionTimer  ; if timer related to player's side collision
    BNE InitScrlAmt  ; not expired, branch
    LDY Player_X_Scroll  ; get value and decrement by one
    DEY  ; if value originally set to zero or otherwise
    BMI InitScrlAmt  ; negative for left movement, branch
    INY
    CPY #$02  ; if value $01, branch and do not decrement
    BCC ChkNearMid
    DEY  ; otherwise decrement by one
ChkNearMid:
    LDA Player_Pos_ForScroll
    CMP #$70  ; check player's horizontal screen position
    BCC ScrollScreen  ; if less than 112 pixels to the right, branch
    LDY Player_X_Scroll  ; otherwise get original value undecremented

ScrollScreen:
    TYA
    STA ScrollAmount  ; save value here
    CLC
    ADC ScrollThirtyTwo  ; add to value already set here
    STA ScrollThirtyTwo  ; save as new value here
    TYA
    CLC
    ADC ScreenLeft_X_Pos  ; add to left side coordinate
    STA ScreenLeft_X_Pos  ; save as new left side coordinate
    STA HorizontalScroll  ; save here also
    LDA ScreenLeft_PageLoc
    ADC #$00  ; add carry to page location for left
    STA ScreenLeft_PageLoc  ; side of the screen
    AND #$01  ; get LSB of page location
    STA $00  ; save as temp variable for PPU register 1 mirror
    LDA Mirror_PPU_CTRL_REG1  ; get PPU register 1 mirror
    AND #%11111110  ; save all bits except d0
    ORA $00  ; get saved bit here and save in PPU register 1
    STA Mirror_PPU_CTRL_REG1  ; mirror to be used to set name table later
    JSR GetScreenPosition  ; figure out where the right side is
    LDA #$08
    STA ScrollIntervalTimer  ; set scroll timer (residual, not used elsewhere)
    JMP ChkPOffscr  ; skip this part
InitScrlAmt:
    LDA #$00
    STA ScrollAmount  ; initialize value here
ChkPOffscr:
    LDX #$00  ; set X for player offset
    JSR GetXOffscreenBits  ; get horizontal offscreen bits for player
    STA $00  ; save them here
    LDY #$00  ; load default offset (left side)
    ASL  ; if d7 of offscreen bits are set,
    BCS KeepOnscr  ; branch with default offset
    INY  ; otherwise use different offset (right side)
    LDA $00
    AND #%00100000  ; check offscreen bits for d5 set
    BEQ InitPlatScrl  ; if not set, branch ahead of this part
KeepOnscr:
    LDA ScreenEdge_X_Pos,y  ; get left or right side coordinate based on offset
    SEC
    SBC X_SubtracterData,y  ; subtract amount based on offset
    STA Player_X_Position  ; store as player position to prevent movement further
    LDA ScreenEdge_PageLoc,y  ; get left or right page location based on offset
    SBC #$00  ; subtract borrow
    STA Player_PageLoc  ; save as player's page location
    LDA Left_Right_Buttons  ; check saved controller bits
    CMP OffscrJoypadBitsData,y  ; against bits based on offset
    BEQ InitPlatScrl  ; if not equal, branch
    LDA #$00
    STA Player_X_Speed  ; otherwise nullify horizontal speed of player
InitPlatScrl:
    LDA #$00  ; nullify platform force imposed on scroll
    STA Platform_X_Scroll
    RTS

X_SubtracterData:
    .byte $00, $10

OffscrJoypadBitsData:
    .byte $01, $02

; -------------------------------------------------------------------------------------

GetScreenPosition:
    LDA ScreenLeft_X_Pos  ; get coordinate of screen's left boundary
    CLC
    ADC #$ff  ; add 255 pixels
    STA ScreenRight_X_Pos  ; store as coordinate of screen's right boundary
    LDA ScreenLeft_PageLoc  ; get page number where left boundary is
    ADC #$00  ; add carry from before
    STA ScreenRight_PageLoc  ; store as page number where right boundary is
    RTS

; -------------------------------------------------------------------------------------

GameRoutines:
    LDA GameEngineSubroutine  ; run routine based on number (a few of these routines are
    JSR sub_dispatch_inline_handler  ; merely placeholders as conditions for other routines)

    .word Entrance_GameTimerSetup
    .word Vine_AutoClimb
    .word SideExitPipeEntry
    .word VerticalPipeEntry
    .word FlagpoleSlide
    .word PlayerEndLevel
    .word PlayerLoseLife
    .word PlayerEntrance
    .word PlayerCtrlRoutine
    .word PlayerChangeSize
    .word PlayerInjuryBlink
    .word PlayerDeath
    .word PlayerFireFlower

; -------------------------------------------------------------------------------------

PlayerEntrance:
    LDA AltEntranceControl  ; check for mode of alternate entry
    CMP #$02
    BEQ EntrMode2  ; if found, branch to enter from pipe or with vine
    LDA #$00
    LDY Player_Y_Position  ; if vertical position above a certain
    CPY #$30  ; point, nullify controller bits and continue
    BCC AutoControlPlayer  ; with player movement code, do not return
    LDA PlayerEntranceCtrl  ; check player entry bits from header
    CMP #$06
    BEQ ChkBehPipe  ; if set to 6 or 7, execute pipe intro code
    CMP #$07  ; otherwise branch to normal entry
    BNE PlayerRdy
ChkBehPipe:
    LDA Player_SprAttrib  ; check for sprite attributes
    BNE IntroEntr  ; branch if found
    LDA #$01
    JMP AutoControlPlayer  ; force player to walk to the right
IntroEntr:
    JSR EnterSidePipe  ; execute sub to move player to the right
    DEC ChangeAreaTimer  ; decrement timer for change of area
    BNE ExitEntr  ; branch to exit if not yet expired
    INC DisableIntermediate  ; set flag to skip world and lives display
    JMP NextArea  ; jump to increment to next area and set modes
EntrMode2:
    LDA JoypadOverride  ; if controller override bits set here,
    BNE VineEntr  ; branch to enter with vine
    LDA #$ff  ; otherwise, set value here then execute sub
    JSR MovePlayerYAxis  ; to move player upwards (note $ff = -1)
    LDA Player_Y_Position  ; check to see if player is at a specific coordinate
    CMP #$91  ; if player risen to a certain point (this requires pipes
    BCC PlayerRdy  ; to be at specific height to look/function right) branch
    RTS  ; to the last part, otherwise leave
VineEntr:
    LDA VineHeight
    CMP #$60  ; check vine height
    BNE ExitEntr  ; if vine not yet reached maximum height, branch to leave
    LDA Player_Y_Position  ; get player's vertical coordinate
    CMP #$99  ; check player's vertical coordinate against preset value
    LDY #$00  ; load default values to be written to
    LDA #$01  ; this value moves player to the right off the vine
    BCC OffVine  ; if vertical coordinate < preset value, use defaults
    LDA #$03
    STA Player_State  ; otherwise set player state to climbing
    INY  ; increment value in Y
    LDA #$08  ; set block in block buffer to cover hole, then
    STA Block_Buffer_1+$b4  ; use same value to force player to climb
OffVine:
    STY DisableCollisionDet  ; set collision detection disable flag
    JSR AutoControlPlayer  ; use contents of A to move player up or right, execute sub
    LDA Player_X_Position
    CMP #$48  ; check player's horizontal position
    BCC ExitEntr  ; if not far enough to the right, branch to leave
PlayerRdy:
    LDA #$08  ; set routine to be executed by game engine next frame
    STA GameEngineSubroutine
    LDA #$01  ; set to face player to the right
    STA PlayerFacingDir
    LSR  ; init A
    STA AltEntranceControl  ; init mode of entry
    STA DisableCollisionDet  ; init collision detection disable flag
    STA JoypadOverride  ; nullify controller override bits
ExitEntr:
    RTS  ; leave!

; -------------------------------------------------------------------------------------
; $07 - used to hold upper limit of high byte when player falls down hole

AutoControlPlayer:
    STA SavedJoypadBits  ; override controller bits with contents of A if executing here

PlayerCtrlRoutine:
    LDA GameEngineSubroutine  ; check task here
    CMP #$0b  ; if certain value is set, branch to skip controller bit loading
    BEQ SizeChk
    LDA AreaType  ; are we in a water type area?
    BNE SaveJoyp  ; if not, branch
    LDY Player_Y_HighPos
    DEY  ; if not in vertical area between
    BNE DisJoyp  ; status bar and bottom, branch
    LDA Player_Y_Position
    CMP #$d0  ; if nearing the bottom of the screen or
    BCC SaveJoyp  ; not in the vertical area between status bar or bottom,
DisJoyp:
    LDA #$00  ; disable controller bits
    STA SavedJoypadBits
SaveJoyp:
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
    BEQ SizeChk  ; if not, branch
    LDA Player_State  ; check player's state
    BNE SizeChk  ; if not on the ground, branch
    LDY Left_Right_Buttons  ; check left and right
    BEQ SizeChk  ; if neither pressed, branch
    LDA #$00
    STA Left_Right_Buttons  ; if pressing down while on the ground,
    STA Up_Down_Buttons  ; nullify directional bits
SizeChk:
    JSR sub_update_player_movement  ; run movement subroutines
    LDY #$01  ; is player small?
    LDA PlayerSize
    BNE ChkMoveDir
    LDY #$00  ; check for if crouching
    LDA CrouchingFlag
    BEQ ChkMoveDir  ; if not, branch ahead
    LDY #$02  ; if big and crouching, load y with 2
ChkMoveDir:
    STY Player_BoundBoxCtrl  ; set contents of Y as player's bounding box size control
    LDA #$01  ; set moving direction to right by default
    LDY Player_X_Speed  ; check player's horizontal speed
    BEQ PlayerSubs  ; if not moving at all horizontally, skip this part
    BPL SetMoveDir  ; if moving to the right, use default moving direction
    ASL  ; otherwise change to move to the left
SetMoveDir:
    STA Player_MovingDir  ; set moving direction
PlayerSubs:
    JSR ScrollHandler  ; move the screen if necessary
    JSR GetPlayerOffscreenBits  ; get player's offscreen bits
    JSR RelativePlayerPosition  ; get coordinates relative to the screen
    LDX #$00  ; set offset for player object
    JSR BoundingBoxCore  ; get player's bounding box coordinates
    JSR PlayerBGCollision  ; do collision detection and process
    LDA Player_Y_Position
    CMP #$40  ; check to see if player is higher than 64th pixel
    BCC PlayerHole  ; if so, branch ahead
    LDA GameEngineSubroutine
    CMP #$05  ; if running end-of-level routine, branch ahead
    BEQ PlayerHole
    CMP #$07  ; if running player entrance routine, branch ahead
    BEQ PlayerHole
    CMP #$04  ; if running routines $00-$03, branch ahead
    BCC PlayerHole
    LDA Player_SprAttrib
    AND #%11011111  ; otherwise nullify player's
    STA Player_SprAttrib  ; background priority flag
PlayerHole:
    LDA Player_Y_HighPos  ; check player's vertical high byte
    CMP #$02  ; for below the screen
    BMI ExitCtrl  ; branch to leave if not that far down
    LDX #$01
    STX ScrollLock  ; set scroll lock
    LDY #$04
    STY $07  ; set value here
    LDX #$00  ; use X as flag, and clear for cloud level
    LDY GameTimerExpiredFlag  ; check game timer expiration flag
    BNE HoleDie  ; if set, branch
    LDY CloudTypeOverride  ; check for cloud type override
    BNE ChkHoleX  ; skip to last part if found
HoleDie:
    INX  ; set flag in X for player death
    LDY GameEngineSubroutine
    CPY #$0b  ; check for some other routine running
    BEQ ChkHoleX  ; if so, branch ahead
    LDY DeathMusicLoaded  ; check value here
    BNE HoleBottom  ; if already set, branch to next part
    INY
    STY EventMusicQueue  ; otherwise play death music
    STY DeathMusicLoaded  ; and set value here
HoleBottom:
    LDY #$06
    STY $07  ; change value here
ChkHoleX:
    CMP $07  ; compare vertical high byte with value set here
    BMI ExitCtrl  ; if less, branch to leave
    DEX  ; otherwise decrement flag in X
    BMI CloudExit  ; if flag was clear, branch to set modes and other values
    LDY EventMusicBuffer  ; check to see if music is still playing
    BNE ExitCtrl  ; branch to leave if so
    LDA #$06  ; otherwise set to run lose life routine
    STA GameEngineSubroutine  ; on next frame
ExitCtrl:
    RTS  ; leave

CloudExit:
    LDA #$00
    STA JoypadOverride  ; clear controller override bits if any are set
    JSR SetEntr  ; do sub to set secondary mode
    INC AltEntranceControl  ; set mode of entry to 3
    RTS

; -------------------------------------------------------------------------------------

Vine_AutoClimb:
    LDA Player_Y_HighPos  ; check to see whether player reached position
    BNE AutoClimb  ; above the status bar yet and if so, set modes
    LDA Player_Y_Position
    CMP #$e4
    BCC SetEntr
AutoClimb:
    LDA #%00001000  ; set controller bits override to up
    STA JoypadOverride
    LDY #$03  ; set player state to climbing
    STY Player_State
    JMP AutoControlPlayer
SetEntr:
    LDA #$02  ; set starting position to override
    STA AltEntranceControl
    JMP ChgAreaMode  ; set modes

; -------------------------------------------------------------------------------------

VerticalPipeEntry:
    LDA #$01  ; set 1 as movement amount
    JSR MovePlayerYAxis  ; do sub to move player downwards
    JSR ScrollHandler  ; do sub to scroll screen with saved force if necessary
    LDY #$00  ; load default mode of entry
    LDA WarpZoneControl  ; check warp zone control variable/flag
    BNE ChgAreaPipe  ; if set, branch to use mode 0
    INY
    LDA AreaType  ; check for castle level type
    CMP #$03
    BNE ChgAreaPipe  ; if not castle type level, use mode 1
    INY
    JMP ChgAreaPipe  ; otherwise use mode 2

MovePlayerYAxis:
    CLC
    ADC Player_Y_Position  ; add contents of A to player position
    STA Player_Y_Position
    RTS

; -------------------------------------------------------------------------------------

SideExitPipeEntry:
    JSR EnterSidePipe  ; execute sub to move player to the right
    LDY #$02
ChgAreaPipe:
    DEC ChangeAreaTimer  ; decrement timer for change of area
    BNE ExitCAPipe
    STY AltEntranceControl  ; when timer expires set mode of alternate entry
ChgAreaMode:
    INC DisableScreenFlag  ; set flag to disable screen output
    LDA #$00
    STA OperMode_Task  ; set secondary mode of operation
    STA Sprite0HitDetectFlag  ; disable sprite 0 check
ExitCAPipe:
    RTS  ; leave

EnterSidePipe:
    LDA #$08  ; set player's horizontal speed
    STA Player_X_Speed
    LDY #$01  ; set controller right button by default
    LDA Player_X_Position  ; mask out higher nybble of player's
    AND #%00001111  ; horizontal position
    BNE RightPipe
    STA Player_X_Speed  ; if lower nybble = 0, set as horizontal speed
    TAY  ; and nullify controller bit override here
RightPipe:
    TYA  ; use contents of Y to
    JSR AutoControlPlayer  ; execute player control routine with ctrl bits nulled
    RTS

; -------------------------------------------------------------------------------------

PlayerChangeSize:
    LDA TimerControl  ; check master timer control
    CMP #$f8  ; for specific moment in time
    BNE EndChgSize  ; branch if before or after that point
    JMP InitChangeSize  ; otherwise run code to get growing/shrinking going
EndChgSize:
    CMP #$c4  ; check again for another specific moment
    BNE ExitChgSize  ; and branch to leave if before or after that point
    JSR DonePlayerTask  ; otherwise do sub to init timer control and set routine
ExitChgSize:
    RTS  ; and then leave

; -------------------------------------------------------------------------------------

PlayerInjuryBlink:
    LDA TimerControl  ; check master timer control
    CMP #$f0  ; for specific moment in time
    BCS ExitBlink  ; branch if before that point
    CMP #$c8  ; check again for another specific point
    BEQ DonePlayerTask  ; branch if at that point, and not before or after
    JMP PlayerCtrlRoutine  ; otherwise run player control routine
ExitBlink:
    BNE ExitBoth  ; do unconditional branch to leave

InitChangeSize:
    LDY PlayerChangeSizeFlag  ; if growing/shrinking flag already set
    BNE ExitBoth  ; then branch to leave
    STY PlayerAnimCtrl  ; otherwise initialize player's animation frame control
    INC PlayerChangeSizeFlag  ; set growing/shrinking flag
    LDA PlayerSize
    EOR #$01  ; invert player's size
    STA PlayerSize
ExitBoth:
    RTS  ; leave

; -------------------------------------------------------------------------------------
; $00 - used in CyclePlayerPalette to store current palette to cycle

PlayerDeath:
    LDA TimerControl  ; check master timer control
    CMP #$f0  ; for specific moment in time
    BCS ExitDeath  ; branch to leave if before that point
    JMP PlayerCtrlRoutine  ; otherwise run player control routine

DonePlayerTask:
    LDA #$00
    STA TimerControl  ; initialize master timer control to continue timers
    LDA #$08
    STA GameEngineSubroutine  ; set player control routine to run next frame
    RTS  ; leave

PlayerFireFlower:
    LDA TimerControl  ; check master timer control
    CMP #$c0  ; for specific moment in time
    BEQ ResetPalFireFlower  ; branch if at moment, not before or after
    LDA FrameCounter  ; get frame counter
    LSR
    LSR  ; divide by four to change every four frames

CyclePlayerPalette:
    AND #$03  ; mask out all but d1-d0 (previously d3-d2)
    STA $00  ; store result here to use as palette bits
    LDA Player_SprAttrib  ; get player attributes
    AND #%11111100  ; save any other bits but palette bits
    ORA $00  ; add palette bits
    STA Player_SprAttrib  ; store as new player attributes
    RTS  ; and leave

ResetPalFireFlower:
    JSR DonePlayerTask  ; do sub to init timer control and run player control routine

ResetPalStar:
    LDA Player_SprAttrib  ; get player attributes
    AND #%11111100  ; mask out palette bits to force palette 0
    STA Player_SprAttrib  ; store as new player attributes
    RTS  ; and leave

ExitDeath:
    RTS  ; leave from death routine

; -------------------------------------------------------------------------------------

FlagpoleSlide:
    LDA Enemy_ID+5  ; check special use enemy slot
    CMP #FlagpoleFlagObject  ; for flagpole flag object
    BNE NoFPObj  ; if not found, branch to something residual
    LDA FlagpoleSoundQueue  ; load flagpole sound
    STA Square1SoundQueue  ; into square 1's sfx queue
    LDA #$00
    STA FlagpoleSoundQueue  ; init flagpole sound queue
    LDY Player_Y_Position
    CPY #$9e  ; check to see if player has slid down
    BCS SlidePlayer  ; far enough, and if so, branch with no controller bits set
    LDA #$04  ; otherwise force player to climb down (to slide)
SlidePlayer:
    JMP AutoControlPlayer  ; jump to player control routine
NoFPObj:
    INC GameEngineSubroutine  ; increment to next routine (this may
    RTS  ; be residual code)

; -------------------------------------------------------------------------------------

Hidden1UpCoinAmts:
    .byte $15, $23, $16, $1b, $17, $18, $23, $63

PlayerEndLevel:
    LDA #$01  ; force player to walk to the right
    JSR AutoControlPlayer
    LDA Player_Y_Position  ; check player's vertical position
    CMP #$ae
    BCC ChkStop  ; if player is not yet off the flagpole, skip this part
    LDA ScrollLock  ; if scroll lock not set, branch ahead to next part
    BEQ ChkStop  ; because we only need to do this part once
    LDA #EndOfLevelMusic
    STA EventMusicQueue  ; load win level music in event music queue
    LDA #$00
    STA ScrollLock  ; turn off scroll lock to skip this part later
ChkStop:
    LDA Player_CollisionBits  ; get player collision bits
    LSR  ; check for d0 set
    BCS RdyNextA  ; if d0 set, skip to next part
    LDA StarFlagTaskControl  ; if star flag task control already set,
    BNE InCastle  ; go ahead with the rest of the code
    INC StarFlagTaskControl  ; otherwise set task control now (this gets ball rolling!)
InCastle:
    LDA #%00100000  ; set player's background priority bit to
    STA Player_SprAttrib  ; give illusion of being inside the castle
RdyNextA:
    LDA StarFlagTaskControl
    CMP #$05  ; if star flag task control not yet set
    BNE ExitNA  ; beyond last valid task number, branch to leave
    INC LevelNumber  ; increment level number used for game logic
    LDA LevelNumber
    CMP #$03  ; check to see if we have yet reached level -4
    BNE NextArea  ; and skip this last part here if not
    LDY WorldNumber  ; get world number as offset
    LDA CoinTallyFor1Ups  ; check third area coin tally for bonus 1-ups
    CMP Hidden1UpCoinAmts,y  ; against minimum value, if player has not collected
    BCC NextArea  ; at least this number of coins, leave flag clear
    INC Hidden1UpFlag  ; otherwise set hidden 1-up box control flag
NextArea:
    INC AreaNumber  ; increment area number used for address loader
    JSR LoadAreaPointer  ; get new level pointer
    INC FetchNewGameTimerFlag  ; set flag to load new game timer
    JSR ChgAreaMode  ; do sub to set secondary mode, disable screen and sprite 0
    STA HalfwayPage  ; reset halfway page to 0 (beginning)
    LDA #Silence
    STA EventMusicQueue  ; silence music and leave
ExitNA:
    RTS
