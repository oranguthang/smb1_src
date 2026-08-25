; -------------------------------------------------------------------------------------

DefaultSprOffsets:
    .byte $04, $30, $48, $60, $78, $90, $a8, $c0
    .byte $d8, $e8, $24, $f8, $fc, $28, $2c

Sprite0Data:
    .byte $18, $ff, $23, $58

; -------------------------------------------------------------------------------------

InitializeGame:
    LDY #$6f  ; clear all memory as in initialization procedure,
    JSR InitializeMemory  ; but this time, clear only as far as $076f
    LDY #$1f
ClrSndLoop:
    STA SoundMemory,y  ; clear out memory used
    DEY  ; by the sound engines
    BPL ClrSndLoop
    LDA #$18  ; set demo timer
    STA DemoTimer
    JSR LoadAreaPointer

InitializeArea:
    LDY #$4b  ; clear all memory again, only as far as $074b
    JSR InitializeMemory  ; this is only necessary if branching from
    LDX #$21
    LDA #$00
ClrTimersLoop:
    STA Timers,x  ; clear out memory between
    DEX  ; $0780 and $07a1
    BPL ClrTimersLoop
    LDA HalfwayPage
    LDY AltEntranceControl  ; if AltEntranceControl not set, use halfway page, if any found
    BEQ StartPage
    LDA EntrancePage  ; otherwise use saved entry page number here
StartPage:
    STA ScreenLeft_PageLoc  ; set as value here
    STA CurrentPageLoc  ; also set as current page
    STA BackloadingFlag  ; set flag here if halfway page or saved entry page number found
    JSR GetScreenPosition  ; get pixel coordinates for screen borders
    LDY #$20  ; if on odd numbered page, use $2480 as start of rendering
    AND #%00000001  ; otherwise use $2080, this address used later as name table
    BEQ SetInitNTHigh  ; address for rendering of game area
    LDY #$24
SetInitNTHigh:
    STY CurrentNTAddr_High  ; store name table address
    LDY #$80
    STY CurrentNTAddr_Low
    ASL  ; store LSB of page number in high nybble
    ASL  ; of block buffer column position
    ASL
    ASL
    STA BlockBufferColumnPos
    DEC AreaObjectLength  ; set area object lengths for all empty
    DEC AreaObjectLength+1
    DEC AreaObjectLength+2
    LDA #$0b  ; set value for renderer to update 12 column sets
    STA ColumnSets  ; 12 column sets = 24 metatile columns = 1 1/2 screens
    JSR GetAreaDataAddrs  ; get enemy and level addresses and load header
    LDA PrimaryHardMode  ; check to see if primary hard mode has been activated
    BNE SetSecHard  ; if so, activate the secondary no matter where we're at
    LDA WorldNumber  ; otherwise check world number
    CMP #World5  ; if less than 5, do not activate secondary
    BCC CheckHalfway
    BNE SetSecHard  ; if not equal to, then world > 5, thus activate
    LDA LevelNumber  ; otherwise, world 5, so check level number
    CMP #Level3  ; if 1 or 2, do not set secondary hard mode flag
    BCC CheckHalfway
SetSecHard:
    INC SecondaryHardMode  ; set secondary hard mode flag for areas 5-3 and beyond
CheckHalfway:
    LDA HalfwayPage
    BEQ DoneInitArea
    LDA #$02  ; if halfway page set, overwrite start position from header
    STA PlayerEntranceCtrl
DoneInitArea:
    LDA #Silence  ; silence music
    STA AreaMusicQueue
    LDA #$01  ; disable screen output
    STA DisableScreenFlag
    INC OperMode_Task  ; increment one of the modes
    RTS

; -------------------------------------------------------------------------------------

PrimaryGameSetup:
    LDA #$01
    STA FetchNewGameTimerFlag  ; set flag to load game timer from header
    STA PlayerSize  ; set player's size to small
    LDA #$02
    STA NumberofLives  ; give each player three lives
    STA OffScr_NumberofLives

SecondaryGameSetup:
    LDA #$00
    STA DisableScreenFlag  ; enable screen output
    TAY
ClearVRLoop:
    STA VRAM_Buffer1-1,y  ; clear buffer at $0300-$03ff
    INY
    BNE ClearVRLoop
    STA GameTimerExpiredFlag  ; clear game timer exp flag
    STA DisableIntermediate  ; clear skip lives display flag
    STA BackloadingFlag  ; clear value here
    LDA #$ff
    STA BalPlatformAlignment  ; initialize balance platform assignment flag
    LDA ScreenLeft_PageLoc  ; get left side page location
    LSR Mirror_PPU_CTRL_REG1  ; shift LSB of ppu register #1 mirror out
    AND #$01  ; mask out all but LSB of page location
    ROR  ; rotate LSB of page location into carry then onto mirror
    ROL Mirror_PPU_CTRL_REG1  ; this is to set the proper PPU name table
    JSR GetAreaMusic  ; load proper music into queue
    LDA #$38  ; load sprite shuffle amounts to be used later
    STA SprShuffleAmt+2
    LDA #$48
    STA SprShuffleAmt+1
    LDA #$58
    STA SprShuffleAmt
    LDX #$0e  ; load default OAM offsets into $06e4-$06f2
ShufAmtLoop:
    LDA DefaultSprOffsets,x
    STA SprDataOffset,x
    DEX  ; do this until they're all set
    BPL ShufAmtLoop
    LDY #$03  ; set up sprite #0
ISpr0Loop:
    LDA Sprite0Data,y
    STA Sprite_Data,y
    DEY
    BPL ISpr0Loop
    JSR DoNothing2  ; these jsrs doesn't do anything useful
    JSR DoNothing1
    INC Sprite0HitDetectFlag  ; set sprite #0 check flag
    INC OperMode_Task  ; increment to next task
    RTS

; -------------------------------------------------------------------------------------

; $06 - RAM address low
; $07 - RAM address high

InitializeMemory:
    LDX #$07  ; set initial high byte to $0700-$07ff
    LDA #$00  ; set initial low byte to start of page (at $00 of page)
    STA $06
InitPageLoop:
    STX $07
InitByteLoop:
    CPX #$01  ; check to see if we're on the stack ($0100-$01ff)
    BNE InitByte  ; if not, go ahead anyway
    CPY #$60  ; otherwise, check to see if we're at $0160-$01ff
    BCS SkipByte  ; if so, skip write
InitByte:
    STA ($06),y  ; otherwise, initialize byte with current low byte in Y
SkipByte:
    DEY
    CPY #$ff  ; do this until all bytes in page have been erased
    BNE InitByteLoop
    DEX  ; go onto the next page
    BPL InitPageLoop  ; do this until all pages of memory have been erased
    RTS

; -------------------------------------------------------------------------------------

MusicSelectData:
    .byte WaterMusic, GroundMusic, UndergroundMusic, CastleMusic
    .byte CloudMusic, PipeIntroMusic

GetAreaMusic:
    LDA OperMode  ; if in title screen mode, leave
    BEQ ExitGetM
    LDA AltEntranceControl  ; check for specific alternate mode of entry
    CMP #$02  ; if found, branch without checking starting position
    BEQ ChkAreaType  ; from area object data header
    LDY #$05  ; select music for pipe intro scene by default
    LDA PlayerEntranceCtrl  ; check value from level header for certain values
    CMP #$06
    BEQ StoreMusic  ; load music for pipe intro scene if header
    CMP #$07  ; start position either value $06 or $07
    BEQ StoreMusic
ChkAreaType:
    LDY AreaType  ; load area type as offset for music bit
    LDA CloudTypeOverride
    BEQ StoreMusic  ; check for cloud type override
    LDY #$04  ; select music for cloud type level if found
StoreMusic:
    LDA MusicSelectData,y  ; otherwise select appropriate music for level type
    STA AreaMusicQueue  ; store in queue and leave
ExitGetM:
    RTS

; -------------------------------------------------------------------------------------

PlayerStarting_X_Pos:
    .byte $28, $18
    .byte $38, $28

AltYPosOffset:
    .byte $08, $00

PlayerStarting_Y_Pos:
    .byte $00, $20, $b0, $50, $00, $00, $b0, $b0
    .byte $f0

PlayerBGPriorityData:
    .byte $00, $20, $00, $00, $00, $00, $00, $00

GameTimerData:
    .byte $20  ; dummy byte, used as part of bg priority data
    .byte $04, $03, $02

Entrance_GameTimerSetup:
    LDA ScreenLeft_PageLoc  ; set current page for area objects
    STA Player_PageLoc  ; as page location for player
    LDA #$28  ; store value here
    STA VerticalForceDown  ; for fractional movement downwards if necessary
    LDA #$01  ; set high byte of player position and
    STA PlayerFacingDir  ; set facing direction so that player faces right
    STA Player_Y_HighPos
    LDA #$00  ; set player state to on the ground by default
    STA Player_State
    DEC Player_CollisionBits  ; initialize player's collision bits
    LDY #$00  ; initialize halfway page
    STY HalfwayPage
    LDA AreaType  ; check area type
    BNE ChkStPos  ; if water type, set swimming flag, otherwise do not set
    INY
ChkStPos:
    STY SwimmingFlag
    LDX PlayerEntranceCtrl  ; get starting position loaded from header
    LDY AltEntranceControl  ; check alternate mode of entry flag for 0 or 1
    BEQ SetStPos
    CPY #$01
    BEQ SetStPos
    LDX AltYPosOffset-2,y  ; if not 0 or 1, override $0710 with new offset in X
SetStPos:
    LDA PlayerStarting_X_Pos,y  ; load appropriate horizontal position
    STA Player_X_Position  ; and vertical positions for the player, using
    LDA PlayerStarting_Y_Pos,x  ; AltEntranceControl as offset for horizontal and either $0710
    STA Player_Y_Position  ; or value that overwrote $0710 as offset for vertical
    LDA PlayerBGPriorityData,x
    STA Player_SprAttrib  ; set player sprite attributes using offset in X
    JSR GetPlayerColors  ; get appropriate player palette
    LDY GameTimerSetting  ; get timer control value from header
    BEQ ChkOverR  ; if set to zero, branch (do not use dummy byte for this)
    LDA FetchNewGameTimerFlag  ; do we need to set the game timer? if not, use
    BEQ ChkOverR  ; old game timer setting
    LDA GameTimerData,y  ; if game timer is set and game timer flag is also set,
    STA GameTimerDisplay  ; use value of game timer control for first digit of game timer
    LDA #$01
    STA GameTimerDisplay+2  ; set last digit of game timer to 1
    LSR
    STA GameTimerDisplay+1  ; set second digit of game timer
    STA FetchNewGameTimerFlag  ; clear flag for game timer reset
    STA StarInvincibleTimer  ; clear star mario timer
ChkOverR:
    LDY JoypadOverride  ; if controller bits not set, branch to skip this part
    BEQ ChkSwimE
    LDA #$03  ; set player state to climbing
    STA Player_State
    LDX #$00  ; set offset for first slot, for block object
    JSR InitBlock_XY_Pos
    LDA #$f0  ; set vertical coordinate for block object
    STA Block_Y_Position
    LDX #$05  ; set offset in X for last enemy object buffer slot
    LDY #$00  ; set offset in Y for object coordinates used earlier
    JSR Setup_Vine  ; do a sub to grow vine
ChkSwimE:
    LDY AreaType  ; if level not water-type,
    BNE SetPESub  ; skip this subroutine
    JSR SetupBubble  ; otherwise, execute sub to set up air bubbles
SetPESub:
    LDA #$07  ; set to run player entrance subroutine
    STA GameEngineSubroutine  ; on the next frame of game engine
    RTS

; -------------------------------------------------------------------------------------

; page numbers are in order from -1 to -4
HalfwayPageNybbles:
    .byte $56, $40
    .byte $65, $70
    .byte $66, $40
    .byte $66, $40
    .byte $66, $40
    .byte $66, $60
    .byte $65, $70
    .byte $00, $00

PlayerLoseLife:
    INC DisableScreenFlag  ; disable screen and sprite 0 check
    LDA #$00
    STA Sprite0HitDetectFlag
    LDA #Silence  ; silence music
    STA EventMusicQueue
    DEC NumberofLives  ; take one life from player
    BPL StillInGame  ; if player still has lives, branch
    LDA #$00
    STA OperMode_Task  ; initialize mode task,
    LDA #GameOverModeValue  ; switch to game over mode
    STA OperMode  ; and leave
    RTS
StillInGame:
    LDA WorldNumber  ; multiply world number by 2 and use
    ASL  ; as offset
    TAX
    LDA LevelNumber  ; if in area -3 or -4, increment
    AND #$02  ; offset by one byte, otherwise
    BEQ GetHalfway  ; leave offset alone
    INX
GetHalfway:
    LDY HalfwayPageNybbles,x  ; get halfway page number with offset
    LDA LevelNumber  ; check area number's LSB
    LSR
    TYA  ; if in area -2 or -4, use lower nybble
    BCS MaskHPNyb
    LSR  ; move higher nybble to lower if area
    LSR  ; number is -1 or -3
    LSR
    LSR
MaskHPNyb:
    AND #%00001111  ; mask out all but lower nybble
    CMP ScreenLeft_PageLoc
    BEQ SetHalfway  ; left side of screen must be at the halfway page,
    BCC SetHalfway  ; otherwise player must start at the
    LDA #$00  ; beginning of the level
SetHalfway:
    STA HalfwayPage  ; store as halfway page for player
    JSR TransposePlayers  ; switch players around if 2-player game
    JMP ContinueGame  ; continue the game

; -------------------------------------------------------------------------------------

GameOverMode:
    LDA OperMode_Task
    JSR sub_dispatch_inline_handler

    .word SetupGameOver
    .word ScreenRoutines
    .word RunGameOver

; -------------------------------------------------------------------------------------

SetupGameOver:
    LDA #$00  ; reset screen routine task control for title screen, game,
    STA ScreenRoutineTask  ; and game over modes
    STA Sprite0HitDetectFlag  ; disable sprite 0 check
    LDA #GameOverMusic
    STA EventMusicQueue  ; put game over music in secondary queue
    INC DisableScreenFlag  ; disable screen output
    INC OperMode_Task  ; set secondary mode to 1
    RTS

; -------------------------------------------------------------------------------------

RunGameOver:
    LDA #$00  ; reenable screen
    STA DisableScreenFlag
    LDA SavedJoypad1Bits  ; check controller for start pressed
    AND #Start_Button
    BNE TerminateGame
    LDA ScreenTimer  ; if not pressed, wait for
    BNE GameIsOn  ; screen timer to expire
TerminateGame:
    LDA #Silence  ; silence music
    STA EventMusicQueue
    JSR TransposePlayers  ; check if other player can keep
    BCC ContinueGame  ; going, and do so if possible
    LDA WorldNumber  ; otherwise put world number of current
    STA ContinueWorld  ; player into secret continue function variable
    LDA #$00
    ASL  ; residual ASL instruction
    STA OperMode_Task  ; reset all modes to title screen and
    STA ScreenTimer  ; leave
    STA OperMode
    RTS

ContinueGame:
    JSR LoadAreaPointer  ; update level pointer with
    LDA #$01  ; actual world and area numbers, then
    STA PlayerSize  ; reset player's size, status, and
    INC FetchNewGameTimerFlag  ; set game timer flag to reload
    LDA #$00  ; game timer from header
    STA TimerControl  ; also set flag for timers to count again
    STA PlayerStatus
    STA GameEngineSubroutine  ; reset task for game core
    STA OperMode_Task  ; set modes and leave
    LDA #$01  ; if in game over mode, switch back to
    STA OperMode  ; game mode, because game is still on
GameIsOn:
    RTS

TransposePlayers:
    SEC  ; set carry flag by default to end game
    LDA NumberOfPlayers  ; if only a 1 player game, leave
    BEQ ExTrans
    LDA OffScr_NumberofLives  ; does offscreen player have any lives left?
    BMI ExTrans  ; branch if not
    LDA CurrentPlayer  ; invert bit to update
    EOR #%00000001  ; which player is on the screen
    STA CurrentPlayer
    LDX #$06
TransLoop:
    LDA OnscreenPlayerInfo,x  ; transpose the information
    PHA  ; of the onscreen player
    LDA OffscreenPlayerInfo,x  ; with that of the offscreen player
    STA OnscreenPlayerInfo,x
    PLA
    STA OffscreenPlayerInfo,x
    DEX
    BPL TransLoop
    CLC  ; clear carry flag to get game going
ExTrans:
    RTS

; -------------------------------------------------------------------------------------

DoNothing1:
    LDA #$ff  ; this is residual code, this value is
    STA $06c9  ; not used anywhere in the program
DoNothing2:
    RTS
