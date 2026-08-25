;-------------------------------------------------------------------------------------

TitleScreenMode:
      lda OperMode_Task
      jsr JumpEngine

      .word InitializeGame
      .word ScreenRoutines
      .word PrimaryGameSetup
      .word GameMenuRoutine

;-------------------------------------------------------------------------------------

WSelectBufferTemplate:
      .byte $04, $20, $73, $01, $00, $00

GameMenuRoutine:
              ldy #$00
              lda SavedJoypad1Bits        ;check to see if either player pressed
              ora SavedJoypad2Bits        ;only the start button (either joypad)
              cmp #Start_Button
              beq StartGame
              cmp #A_Button+Start_Button  ;check to see if A + start was pressed
              bne ChkSelect               ;if not, branch to check select button
StartGame:    jmp ChkContinue             ;if either start or A + start, execute here
ChkSelect:    cmp #Select_Button          ;check to see if the select button was pressed
              beq SelectBLogic            ;if so, branch reset demo timer
              ldx DemoTimer               ;otherwise check demo timer
              bne ChkWorldSel             ;if demo timer not expired, branch to check world selection
              sta SelectTimer             ;set controller bits here if running demo
              jsr DemoEngine              ;run through the demo actions
              bcs ResetTitle              ;if carry flag set, demo over, thus branch
              jmp RunDemo                 ;otherwise, run game engine for demo
ChkWorldSel:  ldx WorldSelectEnableFlag   ;check to see if world selection has been enabled
              beq NullJoypad
              cmp #B_Button               ;if so, check to see if the B button was pressed
              bne NullJoypad
              iny                         ;if so, increment Y and execute same code as select
SelectBLogic: lda DemoTimer               ;if select or B pressed, check demo timer one last time
              beq ResetTitle              ;if demo timer expired, branch to reset title screen mode
              lda #$18                    ;otherwise reset demo timer
              sta DemoTimer
              lda SelectTimer             ;check select/B button timer
              bne NullJoypad              ;if not expired, branch
              lda #$10                    ;otherwise reset select button timer
              sta SelectTimer
              cpy #$01                    ;was the B button pressed earlier?  if so, branch
              beq IncWorldSel             ;note this will not be run if world selection is disabled
              lda NumberOfPlayers         ;if no, must have been the select button, therefore
              eor #%00000001              ;change number of players and draw icon accordingly
              sta NumberOfPlayers
              jsr DrawMushroomIcon
              jmp NullJoypad
IncWorldSel:  ldx WorldSelectNumber       ;increment world select number
              inx
              txa
              and #%00000111              ;mask out higher bits
              sta WorldSelectNumber       ;store as current world select number
              jsr GoContinue
UpdateShroom: lda WSelectBufferTemplate,x ;write template for world select in vram buffer
              sta VRAM_Buffer1-1,x        ;do this until all bytes are written
              inx
              cpx #$06
              bmi UpdateShroom
              ldy WorldNumber             ;get world number from variable and increment for
              iny                         ;proper display, and put in blank byte before
              sty VRAM_Buffer1+3          ;null terminator
NullJoypad:   lda #$00                    ;clear joypad bits for player 1
              sta SavedJoypad1Bits
RunDemo:      jsr GameCoreRoutine         ;run game engine
              lda GameEngineSubroutine    ;check to see if we're running lose life routine
              cmp #$06
              bne ExitMenu                ;if not, do not do all the resetting below
ResetTitle:   lda #$00                    ;reset game modes, disable
              sta OperMode                ;sprite 0 check and disable
              sta OperMode_Task           ;screen output
              sta Sprite0HitDetectFlag
              inc DisableScreenFlag
              rts
ChkContinue:  ldy DemoTimer               ;if timer for demo has expired, reset modes
              beq ResetTitle
              asl                         ;check to see if A button was also pushed
              bcc StartWorld1             ;if not, don't load continue function's world number
              lda ContinueWorld           ;load previously saved world number for secret
              jsr GoContinue              ;continue function when pressing A + start
StartWorld1:  jsr LoadAreaPointer
              inc Hidden1UpFlag           ;set 1-up box flag for both players
              inc OffScr_Hidden1UpFlag
              inc FetchNewGameTimerFlag   ;set fetch new game timer flag
              inc OperMode                ;set next game mode
              lda WorldSelectEnableFlag   ;if world select flag is on, then primary
              sta PrimaryHardMode         ;hard mode must be on as well
              lda #$00
              sta OperMode_Task           ;set game mode here, and clear demo timer
              sta DemoTimer
              ldx #$17
              lda #$00
InitScores:   sta ScoreAndCoinDisplay,x   ;clear player scores and coin displays
              dex
              bpl InitScores
ExitMenu:     rts
GoContinue:   sta WorldNumber             ;start both players at the first area
              sta OffScr_WorldNumber      ;of the previously saved world number
              ldx #$00                    ;note that on power-up using this function
              stx AreaNumber              ;will make no difference
              stx OffScr_AreaNumber
              rts

;-------------------------------------------------------------------------------------

MushroomIconData:
      .byte $07, $22, $49, $83, $ce, $24, $24, $00

DrawMushroomIcon:
              ldy #$07                ;read eight bytes to be read by transfer routine
IconDataRead: lda MushroomIconData,y  ;note that the default position is set for a
              sta VRAM_Buffer1-1,y    ;1-player game
              dey
              bpl IconDataRead
              lda NumberOfPlayers     ;check number of players
              beq ExitIcon            ;if set to 1-player game, we're done
              lda #$24                ;otherwise, load blank tile in 1-player position
              sta VRAM_Buffer1+3
              lda #$ce                ;then load shroom icon tile in 2-player position
              sta VRAM_Buffer1+5
ExitIcon:     rts

;-------------------------------------------------------------------------------------

DemoActionData:
      .byte $01, $80, $02, $81, $41, $80, $01
      .byte $42, $c2, $02, $80, $41, $c1, $41, $c1
      .byte $01, $c1, $01, $02, $80, $00

DemoTimingData:
      .byte $9b, $10, $18, $05, $2c, $20, $24
      .byte $15, $5a, $10, $20, $28, $30, $20, $10
      .byte $80, $20, $30, $30, $01, $ff, $00

DemoEngine:
          ldx DemoAction         ;load current demo action
          lda DemoActionTimer    ;load current action timer
          bne DoAction           ;if timer still counting down, skip
          inx
          inc DemoAction         ;if expired, increment action, X, and
          sec                    ;set carry by default for demo over
          lda DemoTimingData-1,x ;get next timer
          sta DemoActionTimer    ;store as current timer
          beq DemoOver           ;if timer already at zero, skip
DoAction: lda DemoActionData-1,x ;get and perform action (current or next)
          sta SavedJoypad1Bits
          dec DemoActionTimer    ;decrement action timer
          clc                    ;clear carry if demo still going
DemoOver: rts

;-------------------------------------------------------------------------------------

VictoryMode:
            jsr VictoryModeSubroutines  ;run victory mode subroutines
            lda OperMode_Task           ;get current task of victory mode
            beq AutoPlayer              ;if on bridge collapse, skip enemy processing
            ldx #$00
            stx ObjectOffset            ;otherwise reset enemy object offset
            jsr EnemiesAndLoopsCore     ;and run enemy code
AutoPlayer: jsr RelativePlayerPosition  ;get player's relative coordinates
            jmp PlayerGfxHandler        ;draw the player, then leave

VictoryModeSubroutines:
      lda OperMode_Task
      jsr JumpEngine

      .word BridgeCollapse
      .word SetupVictoryMode
      .word PlayerVictoryWalk
      .word PrintVictoryMessages
      .word PlayerEndWorld

;-------------------------------------------------------------------------------------

SetupVictoryMode:
      ldx ScreenRight_PageLoc  ;get page location of right side of screen
      inx                      ;increment to next page
      stx DestinationPageLoc   ;store here
      lda #EndOfCastleMusic
      sta EventMusicQueue      ;play win castle music
      jmp IncModeTask_B        ;jump to set next major task in victory mode

;-------------------------------------------------------------------------------------

PlayerVictoryWalk:
             ldy #$00                ;set value here to not walk player by default
             sty VictoryWalkControl
             lda Player_PageLoc      ;get player's page location
             cmp DestinationPageLoc  ;compare with destination page location
             bne PerformWalk         ;if page locations don't match, branch
             lda Player_X_Position   ;otherwise get player's horizontal position
             cmp #$60                ;compare with preset horizontal position
             bcs DontWalk            ;if still on other page, branch ahead
PerformWalk: inc VictoryWalkControl  ;otherwise increment value and Y
             iny                     ;note Y will be used to walk the player
DontWalk:    tya                     ;put contents of Y in A and
             jsr AutoControlPlayer   ;use A to move player to the right or not
             lda ScreenLeft_PageLoc  ;check page location of left side of screen
             cmp DestinationPageLoc  ;against set value here
             beq ExitVWalk           ;branch if equal to change modes if necessary
             lda ScrollFractional
             clc                     ;do fixed point math on fractional part of scroll
             adc #$80
             sta ScrollFractional    ;save fractional movement amount
             lda #$01                ;set 1 pixel per frame
             adc #$00                ;add carry from previous addition
             tay                     ;use as scroll amount
             jsr ScrollScreen        ;do sub to scroll the screen
             jsr UpdScrollVar        ;do another sub to update screen and scroll variables
             inc VictoryWalkControl  ;increment value to stay in this routine
ExitVWalk:   lda VictoryWalkControl  ;load value set here
             beq IncModeTask_A       ;if zero, branch to change modes
             rts                     ;otherwise leave

;-------------------------------------------------------------------------------------

PrintVictoryMessages:
               lda SecondaryMsgCounter   ;load secondary message counter
               bne IncMsgCounter         ;if set, branch to increment message counters
               lda PrimaryMsgCounter     ;otherwise load primary message counter
               beq ThankPlayer           ;if set to zero, branch to print first message
               cmp #$09                  ;if at 9 or above, branch elsewhere (this comparison
               bcs IncMsgCounter         ;is residual code, counter never reaches 9)
               ldy WorldNumber           ;check world number
               cpy #World8
               bne MRetainerMsg          ;if not at world 8, skip to next part
               cmp #$03                  ;check primary message counter again
               bcc IncMsgCounter         ;if not at 3 yet (world 8 only), branch to increment
               sbc #$01                  ;otherwise subtract one
               jmp ThankPlayer           ;and skip to next part
MRetainerMsg:  cmp #$02                  ;check primary message counter
               bcc IncMsgCounter         ;if not at 2 yet (world 1-7 only), branch
ThankPlayer:   tay                       ;put primary message counter into Y
               bne SecondPartMsg         ;if counter nonzero, skip this part, do not print first message
               lda CurrentPlayer         ;otherwise get player currently on the screen
               beq EvalForMusic          ;if mario, branch
               iny                       ;otherwise increment Y once for luigi and
               bne EvalForMusic          ;do an unconditional branch to the same place
SecondPartMsg: iny                       ;increment Y to do world 8's message
               lda WorldNumber
               cmp #World8               ;check world number
               beq EvalForMusic          ;if at world 8, branch to next part
               dey                       ;otherwise decrement Y for world 1-7's message
               cpy #$04                  ;if counter at 4 (world 1-7 only)
               bcs SetEndTimer           ;branch to set victory end timer
               cpy #$03                  ;if counter at 3 (world 1-7 only)
               bcs IncMsgCounter         ;branch to keep counting
EvalForMusic:  cpy #$03                  ;if counter not yet at 3 (world 8 only), branch
               bne PrintMsg              ;to print message only (note world 1-7 will only
               lda #VictoryMusic         ;reach this code if counter = 0, and will always branch)
               sta EventMusicQueue       ;otherwise load victory music first (world 8 only)
PrintMsg:      tya                       ;put primary message counter in A
               clc                       ;add $0c or 12 to counter thus giving an appropriate value,
               adc #$0c                  ;($0c-$0d = first), ($0e = world 1-7's), ($0f-$12 = world 8's)
               sta VRAM_Buffer_AddrCtrl  ;write message counter to vram address controller
IncMsgCounter: lda SecondaryMsgCounter
               clc
               adc #$04                      ;add four to secondary message counter
               sta SecondaryMsgCounter
               lda PrimaryMsgCounter
               adc #$00                      ;add carry to primary message counter
               sta PrimaryMsgCounter
               cmp #$07                      ;check primary counter one more time
SetEndTimer:   bcc ExitMsgs                  ;if not reached value yet, branch to leave
               lda #$06
               sta WorldEndTimer             ;otherwise set world end timer
IncModeTask_A: inc OperMode_Task             ;move onto next task in mode
ExitMsgs:      rts                           ;leave

;-------------------------------------------------------------------------------------

PlayerEndWorld:
               lda WorldEndTimer          ;check to see if world end timer expired
               bne EndExitOne             ;branch to leave if not
               ldy WorldNumber            ;check world number
               cpy #World8                ;if on world 8, player is done with game,
               bcs EndChkBButton          ;thus branch to read controller
               lda #$00
               sta AreaNumber             ;otherwise initialize area number used as offset
               sta LevelNumber            ;and level number control to start at area 1
               sta OperMode_Task          ;initialize secondary mode of operation
               inc WorldNumber            ;increment world number to move onto the next world
               jsr LoadAreaPointer        ;get area address offset for the next area
               inc FetchNewGameTimerFlag  ;set flag to load game timer from header
               lda #GameModeValue
               sta OperMode               ;set mode of operation to game mode
EndExitOne:    rts                        ;and leave
EndChkBButton: lda SavedJoypad1Bits
               ora SavedJoypad2Bits       ;check to see if B button was pressed on
               and #B_Button              ;either controller
               beq EndExitTwo             ;branch to leave if not
               lda #$01                   ;otherwise set world selection flag
               sta WorldSelectEnableFlag
               lda #$ff                   ;remove onscreen player's lives
               sta NumberofLives
               jsr TerminateGame          ;do sub to continue other player or end game
EndExitTwo:    rts                        ;leave

;-------------------------------------------------------------------------------------

;data is used as tiles for numbers
;that appear when you defeat enemies
FloateyNumTileData:
      .byte $ff, $ff ;dummy
      .byte $f6, $fb ; "100"
      .byte $f7, $fb ; "200"
      .byte $f8, $fb ; "400"
      .byte $f9, $fb ; "500"
      .byte $fa, $fb ; "800"
      .byte $f6, $50 ; "1000"
      .byte $f7, $50 ; "2000"
      .byte $f8, $50 ; "4000"
      .byte $f9, $50 ; "5000"
      .byte $fa, $50 ; "8000"
      .byte $fd, $fe ; "1-UP"

;high nybble is digit number, low nybble is number to
;add to the digit of the player's score
ScoreUpdateData:
      .byte $ff ;dummy
      .byte $41, $42, $44, $45, $48
      .byte $31, $32, $34, $35, $38, $00

FloateyNumbersRoutine:
              lda FloateyNum_Control,x     ;load control for floatey number
              beq EndExitOne               ;if zero, branch to leave
              cmp #$0b                     ;if less than $0b, branch
              bcc ChkNumTimer
              lda #$0b                     ;otherwise set to $0b, thus keeping
              sta FloateyNum_Control,x     ;it in range
ChkNumTimer:  tay                          ;use as Y
              lda FloateyNum_Timer,x       ;check value here
              bne DecNumTimer              ;if nonzero, branch ahead
              sta FloateyNum_Control,x     ;initialize floatey number control and leave
              rts
DecNumTimer:  dec FloateyNum_Timer,x       ;decrement value here
              cmp #$2b                     ;if not reached a certain point, branch
              bne ChkTallEnemy
              cpy #$0b                     ;check offset for $0b
              bne LoadNumTiles             ;branch ahead if not found
              inc NumberofLives            ;give player one extra life (1-up)
              lda #Sfx_ExtraLife
              sta Square2SoundQueue        ;and play the 1-up sound
LoadNumTiles: lda ScoreUpdateData,y        ;load point value here
              lsr                          ;move high nybble to low
              lsr
              lsr
              lsr
              tax                          ;use as X offset, essentially the digit
              lda ScoreUpdateData,y        ;load again and this time
              and #%00001111               ;mask out the high nybble
              sta DigitModifier,x          ;store as amount to add to the digit
              jsr AddToScore               ;update the score accordingly
ChkTallEnemy: ldy Enemy_SprDataOffset,x    ;get OAM data offset for enemy object
              lda Enemy_ID,x               ;get enemy object identifier
              cmp #Spiny
              beq FloateyPart              ;branch if spiny
              cmp #PiranhaPlant
              beq FloateyPart              ;branch if piranha plant
              cmp #HammerBro
              beq GetAltOffset             ;branch elsewhere if hammer bro
              cmp #GreyCheepCheep
              beq FloateyPart              ;branch if cheep-cheep of either color
              cmp #RedCheepCheep
              beq FloateyPart
              cmp #TallEnemy
              bcs GetAltOffset             ;branch elsewhere if enemy object => $09
              lda Enemy_State,x
              cmp #$02                     ;if enemy state defeated or otherwise
              bcs FloateyPart              ;$02 or greater, branch beyond this part
GetAltOffset: ldx SprDataOffset_Ctrl       ;load some kind of control bit
              ldy Alt_SprDataOffset,x      ;get alternate OAM data offset
              ldx ObjectOffset             ;get enemy object offset again
FloateyPart:  lda FloateyNum_Y_Pos,x       ;get vertical coordinate for
              cmp #$18                     ;floatey number, if coordinate in the
              bcc SetupNumSpr              ;status bar, branch
              sbc #$01
              sta FloateyNum_Y_Pos,x       ;otherwise subtract one and store as new
SetupNumSpr:  lda FloateyNum_Y_Pos,x       ;get vertical coordinate
              sbc #$08                     ;subtract eight and dump into the
              jsr DumpTwoSpr               ;left and right sprite's Y coordinates
              lda FloateyNum_X_Pos,x       ;get horizontal coordinate
              sta Sprite_X_Position,y      ;store into X coordinate of left sprite
              clc
              adc #$08                     ;add eight pixels and store into X
              sta Sprite_X_Position+4,y    ;coordinate of right sprite
              lda #$02
              sta Sprite_Attributes,y      ;set palette control in attribute bytes
              sta Sprite_Attributes+4,y    ;of left and right sprites
              lda FloateyNum_Control,x
              asl                          ;multiply our floatey number control by 2
              tax                          ;and use as offset for look-up table
              lda FloateyNumTileData,x
              sta Sprite_Tilenumber,y      ;display first half of number of points
              lda FloateyNumTileData+1,x
              sta Sprite_Tilenumber+4,y    ;display the second half
              ldx ObjectOffset             ;get enemy object offset and leave
              rts
