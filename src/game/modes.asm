; -------------------------------------------------------------------------------------

TitleScreenMode:
    LDA OperMode_Task
    JSR sub_dispatch_inline_handler

    .word InitializeGame
    .word ScreenRoutines
    .word PrimaryGameSetup
    .word GameMenuRoutine

; -------------------------------------------------------------------------------------

WSelectBufferTemplate:
    .byte $04, $20, $73, $01, $00, $00

GameMenuRoutine:
    LDY #$00
    LDA SavedJoypad1Bits  ; check to see if either player pressed
    ORA SavedJoypad2Bits  ; only the start button (either joypad)
    CMP #Start_Button
    BEQ StartGame
    CMP #A_Button+Start_Button  ; check to see if A + start was pressed
    BNE ChkSelect  ; if not, branch to check select button
StartGame:
    JMP ChkContinue  ; if either start or A + start, execute here
ChkSelect:
    CMP #Select_Button  ; check to see if the select button was pressed
    BEQ SelectBLogic  ; if so, branch reset demo timer
    LDX DemoTimer  ; otherwise check demo timer
    BNE ChkWorldSel  ; if demo timer not expired, branch to check world selection
    STA SelectTimer  ; set controller bits here if running demo
    JSR DemoEngine  ; run through the demo actions
    BCS ResetTitle  ; if carry flag set, demo over, thus branch
    JMP RunDemo  ; otherwise, run game engine for demo
ChkWorldSel:
    LDX WorldSelectEnableFlag  ; check to see if world selection has been enabled
    BEQ NullJoypad
    CMP #B_Button  ; if so, check to see if the B button was pressed
    BNE NullJoypad
    INY  ; if so, increment Y and execute same code as select
SelectBLogic:
    LDA DemoTimer  ; if select or B pressed, check demo timer one last time
    BEQ ResetTitle  ; if demo timer expired, branch to reset title screen mode
    LDA #$18  ; otherwise reset demo timer
    STA DemoTimer
    LDA SelectTimer  ; check select/B button timer
    BNE NullJoypad  ; if not expired, branch
    LDA #$10  ; otherwise reset select button timer
    STA SelectTimer
    CPY #$01  ; was the B button pressed earlier?  if so, branch
    BEQ IncWorldSel  ; note this will not be run if world selection is disabled
    LDA NumberOfPlayers  ; if no, must have been the select button, therefore
    EOR #%00000001  ; change number of players and draw icon accordingly
    STA NumberOfPlayers
    JSR DrawMushroomIcon
    JMP NullJoypad
IncWorldSel:
    LDX WorldSelectNumber  ; increment world select number
    INX
    TXA
    AND #%00000111  ; mask out higher bits
    STA WorldSelectNumber  ; store as current world select number
    JSR GoContinue
UpdateShroom:
    LDA WSelectBufferTemplate,x  ; write template for world select in vram buffer
    STA VRAM_Buffer1-1,x  ; do this until all bytes are written
    INX
    CPX #$06
    BMI UpdateShroom
    LDY WorldNumber  ; get world number from variable and increment for
    INY  ; proper display, and put in blank byte before
    STY VRAM_Buffer1+3  ; null terminator
NullJoypad:
    LDA #$00  ; clear joypad bits for player 1
    STA SavedJoypad1Bits
RunDemo:
    JSR GameCoreRoutine  ; run game engine
    LDA GameEngineSubroutine  ; check to see if we're running lose life routine
    CMP #$06
    BNE ExitMenu  ; if not, do not do all the resetting below
ResetTitle:
    LDA #$00  ; reset game modes, disable
    STA OperMode  ; sprite 0 check and disable
    STA OperMode_Task  ; screen output
    STA Sprite0HitDetectFlag
    INC DisableScreenFlag
    RTS
ChkContinue:
    LDY DemoTimer  ; if timer for demo has expired, reset modes
    BEQ ResetTitle
    ASL  ; check to see if A button was also pushed
    BCC StartWorld1  ; if not, don't load continue function's world number
    LDA ContinueWorld  ; load previously saved world number for secret
    JSR GoContinue  ; continue function when pressing A + start
StartWorld1:
    JSR LoadAreaPointer
    INC Hidden1UpFlag  ; set 1-up box flag for both players
    INC OffScr_Hidden1UpFlag
    INC FetchNewGameTimerFlag  ; set fetch new game timer flag
    INC OperMode  ; set next game mode
    LDA WorldSelectEnableFlag  ; if world select flag is on, then primary
    STA PrimaryHardMode  ; hard mode must be on as well
    LDA #$00
    STA OperMode_Task  ; set game mode here, and clear demo timer
    STA DemoTimer
    LDX #$17
    LDA #$00
InitScores:
    STA ScoreAndCoinDisplay,x  ; clear player scores and coin displays
    DEX
    BPL InitScores
ExitMenu:
    RTS
GoContinue:
    STA WorldNumber  ; start both players at the first area
    STA OffScr_WorldNumber  ; of the previously saved world number
    LDX #$00  ; note that on power-up using this function
    STX AreaNumber  ; will make no difference
    STX OffScr_AreaNumber
    RTS

; -------------------------------------------------------------------------------------

MushroomIconData:
    .byte $07, $22, $49, $83, $ce, $24, $24, $00

DrawMushroomIcon:
    LDY #$07  ; read eight bytes to be read by transfer routine
IconDataRead:
    LDA MushroomIconData,y  ; note that the default position is set for a
    STA VRAM_Buffer1-1,y  ; 1-player game
    DEY
    BPL IconDataRead
    LDA NumberOfPlayers  ; check number of players
    BEQ ExitIcon  ; if set to 1-player game, we're done
    LDA #$24  ; otherwise, load blank tile in 1-player position
    STA VRAM_Buffer1+3
    LDA #$ce  ; then load shroom icon tile in 2-player position
    STA VRAM_Buffer1+5
ExitIcon:
    RTS

; -------------------------------------------------------------------------------------

DemoActionData:
    .byte $01, $80, $02, $81, $41, $80, $01
    .byte $42, $c2, $02, $80, $41, $c1, $41, $c1
    .byte $01, $c1, $01, $02, $80, $00

DemoTimingData:
    .byte $9b, $10, $18, $05, $2c, $20, $24
    .byte $15, $5a, $10, $20, $28, $30, $20, $10
    .byte $80, $20, $30, $30, $01, $ff, $00

DemoEngine:
    LDX DemoAction  ; load current demo action
    LDA DemoActionTimer  ; load current action timer
    BNE DoAction  ; if timer still counting down, skip
    INX
    INC DemoAction  ; if expired, increment action, X, and
    SEC  ; set carry by default for demo over
    LDA DemoTimingData-1,x  ; get next timer
    STA DemoActionTimer  ; store as current timer
    BEQ DemoOver  ; if timer already at zero, skip
DoAction:
    LDA DemoActionData-1,x  ; get and perform action (current or next)
    STA SavedJoypad1Bits
    DEC DemoActionTimer  ; decrement action timer
    CLC  ; clear carry if demo still going
DemoOver:
    RTS

; -------------------------------------------------------------------------------------

VictoryMode:
    JSR VictoryModeSubroutines  ; run victory mode subroutines
    LDA OperMode_Task  ; get current task of victory mode
    BEQ AutoPlayer  ; if on bridge collapse, skip enemy processing
    LDX #$00
    STX ObjectOffset  ; otherwise reset enemy object offset
    JSR EnemiesAndLoopsCore  ; and run enemy code
AutoPlayer:
    JSR RelativePlayerPosition  ; get player's relative coordinates
    JMP PlayerGfxHandler  ; draw the player, then leave

VictoryModeSubroutines:
    LDA OperMode_Task
    JSR sub_dispatch_inline_handler

    .word BridgeCollapse
    .word SetupVictoryMode
    .word PlayerVictoryWalk
    .word PrintVictoryMessages
    .word PlayerEndWorld

; -------------------------------------------------------------------------------------

SetupVictoryMode:
    LDX ScreenRight_PageLoc  ; get page location of right side of screen
    INX  ; increment to next page
    STX DestinationPageLoc  ; store here
    LDA #EndOfCastleMusic
    STA EventMusicQueue  ; play win castle music
    JMP IncModeTask_B  ; jump to set next major task in victory mode

; -------------------------------------------------------------------------------------

PlayerVictoryWalk:
    LDY #$00  ; set value here to not walk player by default
    STY VictoryWalkControl
    LDA Player_PageLoc  ; get player's page location
    CMP DestinationPageLoc  ; compare with destination page location
    BNE PerformWalk  ; if page locations don't match, branch
    LDA Player_X_Position  ; otherwise get player's horizontal position
    CMP #$60  ; compare with preset horizontal position
    BCS DontWalk  ; if still on other page, branch ahead
PerformWalk:
    INC VictoryWalkControl  ; otherwise increment value and Y
    INY  ; note Y will be used to walk the player
DontWalk:
    TYA  ; put contents of Y in A and
    JSR AutoControlPlayer  ; use A to move player to the right or not
    LDA ScreenLeft_PageLoc  ; check page location of left side of screen
    CMP DestinationPageLoc  ; against set value here
    BEQ ExitVWalk  ; branch if equal to change modes if necessary
    LDA ScrollFractional
    CLC  ; do fixed point math on fractional part of scroll
    ADC #$80
    STA ScrollFractional  ; save fractional movement amount
    LDA #$01  ; set 1 pixel per frame
    ADC #$00  ; add carry from previous addition
    TAY  ; use as scroll amount
    JSR ScrollScreen  ; do sub to scroll the screen
    JSR UpdScrollVar  ; do another sub to update screen and scroll variables
    INC VictoryWalkControl  ; increment value to stay in this routine
ExitVWalk:
    LDA VictoryWalkControl  ; load value set here
    BEQ IncModeTask_A  ; if zero, branch to change modes
    RTS  ; otherwise leave

; -------------------------------------------------------------------------------------

PrintVictoryMessages:
    LDA SecondaryMsgCounter  ; load secondary message counter
    BNE IncMsgCounter  ; if set, branch to increment message counters
    LDA PrimaryMsgCounter  ; otherwise load primary message counter
    BEQ ThankPlayer  ; if set to zero, branch to print first message
    CMP #$09  ; if at 9 or above, branch elsewhere (this comparison
    BCS IncMsgCounter  ; is residual code, counter never reaches 9)
    LDY WorldNumber  ; check world number
    CPY #World8
    BNE MRetainerMsg  ; if not at world 8, skip to next part
    CMP #$03  ; check primary message counter again
    BCC IncMsgCounter  ; if not at 3 yet (world 8 only), branch to increment
    SBC #$01  ; otherwise subtract one
    JMP ThankPlayer  ; and skip to next part
MRetainerMsg:
    CMP #$02  ; check primary message counter
    BCC IncMsgCounter  ; if not at 2 yet (world 1-7 only), branch
ThankPlayer:
    TAY  ; put primary message counter into Y
    BNE SecondPartMsg  ; if counter nonzero, skip this part, do not print first message
    LDA CurrentPlayer  ; otherwise get player currently on the screen
    BEQ EvalForMusic  ; if mario, branch
    INY  ; otherwise increment Y once for luigi and
    BNE EvalForMusic  ; do an unconditional branch to the same place
SecondPartMsg:
    INY  ; increment Y to do world 8's message
    LDA WorldNumber
    CMP #World8  ; check world number
    BEQ EvalForMusic  ; if at world 8, branch to next part
    DEY  ; otherwise decrement Y for world 1-7's message
    CPY #$04  ; if counter at 4 (world 1-7 only)
    BCS SetEndTimer  ; branch to set victory end timer
    CPY #$03  ; if counter at 3 (world 1-7 only)
    BCS IncMsgCounter  ; branch to keep counting
EvalForMusic:
    CPY #$03  ; if counter not yet at 3 (world 8 only), branch
    BNE PrintMsg  ; to print message only (note world 1-7 will only
    LDA #VictoryMusic  ; reach this code if counter = 0, and will always branch)
    STA EventMusicQueue  ; otherwise load victory music first (world 8 only)
PrintMsg:
    TYA  ; put primary message counter in A
    CLC  ; add $0c or 12 to counter thus giving an appropriate value,
    ADC #$0c  ; ($0c-$0d = first), ($0e = world 1-7's), ($0f-$12 = world 8's)
    STA VRAM_Buffer_AddrCtrl  ; write message counter to vram address controller
IncMsgCounter:
    LDA SecondaryMsgCounter
    CLC
    ADC #$04  ; add four to secondary message counter
    STA SecondaryMsgCounter
    LDA PrimaryMsgCounter
    ADC #$00  ; add carry to primary message counter
    STA PrimaryMsgCounter
    CMP #$07  ; check primary counter one more time
SetEndTimer:
    BCC ExitMsgs  ; if not reached value yet, branch to leave
    LDA #$06
    STA WorldEndTimer  ; otherwise set world end timer
IncModeTask_A:
    INC OperMode_Task  ; move onto next task in mode
ExitMsgs:
    RTS  ; leave

; -------------------------------------------------------------------------------------

PlayerEndWorld:
    LDA WorldEndTimer  ; check to see if world end timer expired
    BNE EndExitOne  ; branch to leave if not
    LDY WorldNumber  ; check world number
    CPY #World8  ; if on world 8, player is done with game,
    BCS EndChkBButton  ; thus branch to read controller
    LDA #$00
    STA AreaNumber  ; otherwise initialize area number used as offset
    STA LevelNumber  ; and level number control to start at area 1
    STA OperMode_Task  ; initialize secondary mode of operation
    INC WorldNumber  ; increment world number to move onto the next world
    JSR LoadAreaPointer  ; get area address offset for the next area
    INC FetchNewGameTimerFlag  ; set flag to load game timer from header
    LDA #GameModeValue
    STA OperMode  ; set mode of operation to game mode
EndExitOne:
    RTS  ; and leave
EndChkBButton:
    LDA SavedJoypad1Bits
    ORA SavedJoypad2Bits  ; check to see if B button was pressed on
    AND #B_Button  ; either controller
    BEQ EndExitTwo  ; branch to leave if not
    LDA #$01  ; otherwise set world selection flag
    STA WorldSelectEnableFlag
    LDA #$ff  ; remove onscreen player's lives
    STA NumberofLives
    JSR TerminateGame  ; do sub to continue other player or end game
EndExitTwo:
    RTS  ; leave

; -------------------------------------------------------------------------------------

; data is used as tiles for numbers
; that appear when you defeat enemies
FloateyNumTileData:
    .byte $ff, $ff  ; dummy
    .byte $f6, $fb  ; "100"
    .byte $f7, $fb  ; "200"
    .byte $f8, $fb  ; "400"
    .byte $f9, $fb  ; "500"
    .byte $fa, $fb  ; "800"
    .byte $f6, $50  ; "1000"
    .byte $f7, $50  ; "2000"
    .byte $f8, $50  ; "4000"
    .byte $f9, $50  ; "5000"
    .byte $fa, $50  ; "8000"
    .byte $fd, $fe  ; "1-UP"

; high nybble is digit number, low nybble is number to
; add to the digit of the player's score
ScoreUpdateData:
    .byte $ff  ; dummy
    .byte $41, $42, $44, $45, $48
    .byte $31, $32, $34, $35, $38, $00

FloateyNumbersRoutine:
    LDA FloateyNum_Control,x  ; load control for floatey number
    BEQ EndExitOne  ; if zero, branch to leave
    CMP #$0b  ; if less than $0b, branch
    BCC ChkNumTimer
    LDA #$0b  ; otherwise set to $0b, thus keeping
    STA FloateyNum_Control,x  ; it in range
ChkNumTimer:
    TAY  ; use as Y
    LDA FloateyNum_Timer,x  ; check value here
    BNE DecNumTimer  ; if nonzero, branch ahead
    STA FloateyNum_Control,x  ; initialize floatey number control and leave
    RTS
DecNumTimer:
    DEC FloateyNum_Timer,x  ; decrement value here
    CMP #$2b  ; if not reached a certain point, branch
    BNE ChkTallEnemy
    CPY #$0b  ; check offset for $0b
    BNE LoadNumTiles  ; branch ahead if not found
    INC NumberofLives  ; give player one extra life (1-up)
    LDA #Sfx_ExtraLife
    STA Square2SoundQueue  ; and play the 1-up sound
LoadNumTiles:
    LDA ScoreUpdateData,y  ; load point value here
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    TAX  ; use as X offset, essentially the digit
    LDA ScoreUpdateData,y  ; load again and this time
    AND #%00001111  ; mask out the high nybble
    STA DigitModifier,x  ; store as amount to add to the digit
    JSR AddToScore  ; update the score accordingly
ChkTallEnemy:
    LDY Enemy_SprDataOffset,x  ; get OAM data offset for enemy object
    LDA Enemy_ID,x  ; get enemy object identifier
    CMP #Spiny
    BEQ FloateyPart  ; branch if spiny
    CMP #PiranhaPlant
    BEQ FloateyPart  ; branch if piranha plant
    CMP #HammerBro
    BEQ GetAltOffset  ; branch elsewhere if hammer bro
    CMP #GreyCheepCheep
    BEQ FloateyPart  ; branch if cheep-cheep of either color
    CMP #RedCheepCheep
    BEQ FloateyPart
    CMP #TallEnemy
    BCS GetAltOffset  ; branch elsewhere if enemy object => $09
    LDA Enemy_State,x
    CMP #$02  ; if enemy state defeated or otherwise
    BCS FloateyPart  ; $02 or greater, branch beyond this part
GetAltOffset:
    LDX SprDataOffset_Ctrl  ; load some kind of control bit
    LDY Alt_SprDataOffset,x  ; get alternate OAM data offset
    LDX ObjectOffset  ; get enemy object offset again
FloateyPart:
    LDA FloateyNum_Y_Pos,x  ; get vertical coordinate for
    CMP #$18  ; floatey number, if coordinate in the
    BCC SetupNumSpr  ; status bar, branch
    SBC #$01
    STA FloateyNum_Y_Pos,x  ; otherwise subtract one and store as new
SetupNumSpr:
    LDA FloateyNum_Y_Pos,x  ; get vertical coordinate
    SBC #$08  ; subtract eight and dump into the
    JSR DumpTwoSpr  ; left and right sprite's Y coordinates
    LDA FloateyNum_X_Pos,x  ; get horizontal coordinate
    STA Sprite_X_Position,y  ; store into X coordinate of left sprite
    CLC
    ADC #$08  ; add eight pixels and store into X
    STA Sprite_X_Position+4,y  ; coordinate of right sprite
    LDA #$02
    STA Sprite_Attributes,y  ; set palette control in attribute bytes
    STA Sprite_Attributes+4,y  ; of left and right sprites
    LDA FloateyNum_Control,x
    ASL  ; multiply our floatey number control by 2
    TAX  ; and use as offset for look-up table
    LDA FloateyNumTileData,x
    STA Sprite_Tilenumber,y  ; display first half of number of points
    LDA FloateyNumTileData+1,x
    STA Sprite_Tilenumber+4,y  ; display the second half
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS
