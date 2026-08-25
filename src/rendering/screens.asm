; -------------------------------------------------------------------------------------

ScreenRoutines:
    LDA ScreenRoutineTask  ; run one of the following subroutines
    JSR JumpEngine

    .word InitScreen
    .word SetupIntermediate
    .word WriteTopStatusLine
    .word WriteBottomStatusLine
    .word DisplayTimeUp
    .word ResetSpritesAndScreenTimer
    .word DisplayIntermediate
    .word ResetSpritesAndScreenTimer
    .word AreaParserTaskControl
    .word GetAreaPalette
    .word GetBackgroundColor
    .word GetAlternatePalette1
    .word DrawTitleScreen
    .word ClearBuffersDrawIcon
    .word WriteTopScore

; -------------------------------------------------------------------------------------

InitScreen:
    JSR MoveAllSpritesOffscreen  ; initialize all sprites including sprite #0
    JSR InitializeNameTables  ; and erase both name and attribute tables
    LDA OperMode
    BEQ NextSubtask  ; if mode still 0, do not load
    LDX #$03  ; into buffer pointer
    JMP SetVRAMAddr_A

; -------------------------------------------------------------------------------------

SetupIntermediate:
    LDA BackgroundColorCtrl  ; save current background color control
    PHA  ; and player status to stack
    LDA PlayerStatus
    PHA
    LDA #$00  ; set background color to black
    STA PlayerStatus  ; and player status to not fiery
    LDA #$02  ; this is the ONLY time background color control
    STA BackgroundColorCtrl  ; is set to less than 4
    JSR GetPlayerColors
    PLA  ; we only execute this routine for
    STA PlayerStatus  ; the intermediate lives display
    PLA  ; and once we're done, we return bg
    STA BackgroundColorCtrl  ; color ctrl and player status from stack
    JMP IncSubtask  ; then move onto the next task

; -------------------------------------------------------------------------------------

AreaPalette:
    .byte $01, $02, $03, $04

GetAreaPalette:
    LDY AreaType  ; select appropriate palette to load
    LDX AreaPalette,y  ; based on area type
SetVRAMAddr_A:
    STX VRAM_Buffer_AddrCtrl  ; store offset into buffer control
NextSubtask:
    JMP IncSubtask  ; move onto next task

; -------------------------------------------------------------------------------------
; $00 - used as temp counter in GetPlayerColors

BGColorCtrl_Addr:
    .byte $00, $09, $0a, $04

BackgroundColors:
    .byte $22, $22, $0f, $0f  ; used by area type if bg color ctrl not set
    .byte $0f, $22, $0f, $0f  ; used by background color control if set

PlayerColors:
    .byte $22, $16, $27, $18  ; mario's colors
    .byte $22, $30, $27, $19  ; luigi's colors
    .byte $22, $37, $27, $16  ; fiery (used by both)

GetBackgroundColor:
    LDY BackgroundColorCtrl  ; check background color control
    BEQ NoBGColor  ; if not set, increment task and fetch palette
    LDA BGColorCtrl_Addr-4,y  ; put appropriate palette into vram
    STA VRAM_Buffer_AddrCtrl  ; note that if set to 5-7, $0301 will not be read
NoBGColor:
    INC ScreenRoutineTask  ; increment to next subtask and plod on through

GetPlayerColors:
    LDX VRAM_Buffer1_Offset  ; get current buffer offset
    LDY #$00
    LDA CurrentPlayer  ; check which player is on the screen
    BEQ ChkFiery
    LDY #$04  ; load offset for luigi
ChkFiery:
    LDA PlayerStatus  ; check player status
    CMP #$02
    BNE StartClrGet  ; if fiery, load alternate offset for fiery player
    LDY #$08
StartClrGet:
    LDA #$03  ; do four colors
    STA $00
ClrGetLoop:
    LDA PlayerColors,y  ; fetch player colors and store them
    STA VRAM_Buffer1+3,x  ; in the buffer
    INY
    INX
    DEC $00
    BPL ClrGetLoop
    LDX VRAM_Buffer1_Offset  ; load original offset from before
    LDY BackgroundColorCtrl  ; if this value is four or greater, it will be set
    BNE SetBGColor  ; therefore use it as offset to background color
    LDY AreaType  ; otherwise use area type bits from area offset as offset
SetBGColor:
    LDA BackgroundColors,y  ; to background color instead
    STA VRAM_Buffer1+3,x
    LDA #$3f  ; set for sprite palette address
    STA VRAM_Buffer1,x  ; save to buffer
    LDA #$10
    STA VRAM_Buffer1+1,x
    LDA #$04  ; write length byte to buffer
    STA VRAM_Buffer1+2,x
    LDA #$00  ; now the null terminator
    STA VRAM_Buffer1+7,x
    TXA  ; move the buffer pointer ahead 7 bytes
    CLC  ; in case we want to write anything else later
    ADC #$07
SetVRAMOffset:
    STA VRAM_Buffer1_Offset  ; store as new vram buffer offset
    RTS

; -------------------------------------------------------------------------------------

GetAlternatePalette1:
    LDA AreaStyle  ; check for mushroom level style
    CMP #$01
    BNE NoAltPal
    LDA #$0b  ; if found, load appropriate palette
SetVRAMAddr_B:
    STA VRAM_Buffer_AddrCtrl
NoAltPal:
    JMP IncSubtask  ; now onto the next task

; -------------------------------------------------------------------------------------

WriteTopStatusLine:
    LDA #$00  ; select main status bar
    JSR WriteGameText  ; output it
    JMP IncSubtask  ; onto the next task

; -------------------------------------------------------------------------------------

WriteBottomStatusLine:
    JSR GetSBNybbles  ; write player's score and coin tally to screen
    LDX VRAM_Buffer1_Offset
    LDA #$20  ; write address for world-area number on screen
    STA VRAM_Buffer1,x
    LDA #$73
    STA VRAM_Buffer1+1,x
    LDA #$03  ; write length for it
    STA VRAM_Buffer1+2,x
    LDY WorldNumber  ; first the world number
    INY
    TYA
    STA VRAM_Buffer1+3,x
    LDA #$28  ; next the dash
    STA VRAM_Buffer1+4,x
    LDY LevelNumber  ; next the level number
    INY  ; increment for proper number display
    TYA
    STA VRAM_Buffer1+5,x
    LDA #$00  ; put null terminator on
    STA VRAM_Buffer1+6,x
    TXA  ; move the buffer offset up by 6 bytes
    CLC
    ADC #$06
    STA VRAM_Buffer1_Offset
    JMP IncSubtask

; -------------------------------------------------------------------------------------

DisplayTimeUp:
    LDA GameTimerExpiredFlag  ; if game timer not expired, increment task
    BEQ NoTimeUp  ; control 2 tasks forward, otherwise, stay here
    LDA #$00
    STA GameTimerExpiredFlag  ; reset timer expiration flag
    LDA #$02  ; output time-up screen to buffer
    JMP OutputInter
NoTimeUp:
    INC ScreenRoutineTask  ; increment control task 2 tasks forward
    JMP IncSubtask

; -------------------------------------------------------------------------------------

DisplayIntermediate:
    LDA OperMode  ; check primary mode of operation
    BEQ NoInter  ; if in title screen mode, skip this
    CMP #GameOverModeValue  ; are we in game over mode?
    BEQ GameOverInter  ; if so, proceed to display game over screen
    LDA AltEntranceControl  ; otherwise check for mode of alternate entry
    BNE NoInter  ; and branch if found
    LDY AreaType  ; check if we are on castle level
    CPY #$03  ; and if so, branch (possibly residual)
    BEQ PlayerInter
    LDA DisableIntermediate  ; if this flag is set, skip intermediate lives display
    BNE NoInter  ; and jump to specific task, otherwise
PlayerInter:
    JSR DrawPlayer_Intermediate  ; put player in appropriate place for
    LDA #$01  ; lives display, then output lives display to buffer
OutputInter:
    JSR WriteGameText
    JSR ResetScreenTimer
    LDA #$00
    STA DisableScreenFlag  ; reenable screen output
    RTS
GameOverInter:
    LDA #$12  ; set screen timer
    STA ScreenTimer
    LDA #$03  ; output game over screen to buffer
    JSR WriteGameText
    JMP IncModeTask_B
NoInter:
    LDA #$08  ; set for specific task and leave
    STA ScreenRoutineTask
    RTS

; -------------------------------------------------------------------------------------

AreaParserTaskControl:
    INC DisableScreenFlag  ; turn off screen
TaskLoop:
    JSR AreaParserTaskHandler  ; render column set of current area
    LDA AreaParserTaskNum  ; check number of tasks
    BNE TaskLoop  ; if tasks still not all done, do another one
    DEC ColumnSets  ; do we need to render more column sets?
    BPL OutputCol
    INC ScreenRoutineTask  ; if not, move on to the next task
OutputCol:
    LDA #$06  ; set vram buffer to output rendered column set
    STA VRAM_Buffer_AddrCtrl  ; on next NMI
    RTS

; -------------------------------------------------------------------------------------

; $00 - vram buffer address table low
; $01 - vram buffer address table high

DrawTitleScreen:
    LDA OperMode  ; are we in title screen mode?
    BNE IncModeTask_B  ; if not, exit
    LDA #>TitleScreenDataOffset  ; load address $1ec0 into
    STA PPU_ADDRESS  ; the vram address register
    LDA #<TitleScreenDataOffset
    STA PPU_ADDRESS
    LDA #$03  ; put address $0300 into
    STA $01  ; the indirect at $00
    LDY #$00
    STY $00
    LDA PPU_DATA  ; do one garbage read
OutputTScr:
    LDA PPU_DATA  ; get title screen from chr-rom
    STA ($00),y  ; store 256 bytes into buffer
    INY
    BNE ChkHiByte  ; if not past 256 bytes, do not increment
    INC $01  ; otherwise increment high byte of indirect
ChkHiByte:
    LDA $01  ; check high byte?
    CMP #$04  ; at $0400?
    BNE OutputTScr  ; if not, loop back and do another
    CPY #$3a  ; check if offset points past end of data
    BCC OutputTScr  ; if not, loop back and do another
    LDA #$05  ; set buffer transfer control to $0300,
    JMP SetVRAMAddr_B  ; increment task and exit

; -------------------------------------------------------------------------------------

ClearBuffersDrawIcon:
    LDA OperMode  ; check game mode
    BNE IncModeTask_B  ; if not title screen mode, leave
    LDX #$00  ; otherwise, clear buffer space
TScrClear:
    STA VRAM_Buffer1-1,x
    STA VRAM_Buffer1-1+$100,x
    DEX
    BNE TScrClear
    JSR DrawMushroomIcon  ; draw player select icon
IncSubtask:
    INC ScreenRoutineTask  ; move onto next task
    RTS

; -------------------------------------------------------------------------------------

WriteTopScore:
    LDA #$fa  ; run display routine to display top score on title
    JSR UpdateNumber
IncModeTask_B:
    INC OperMode_Task  ; move onto next mode
    RTS

; -------------------------------------------------------------------------------------

GameText:
TopStatusBarLine:
    .byte $20, $43, $05, $16, $0a, $1b, $12, $18  ; "MARIO"
    .byte $20, $52, $0b, $20, $18, $1b, $15, $0d  ; "WORLD  TIME"
    .byte $24, $24, $1d, $12, $16, $0e
    .byte $20, $68, $05, $00, $24, $24, $2e, $29  ; score trailing digit and coin display
    .byte $23, $c0, $7f, $aa  ; attribute table data, clears name table 0 to palette 2
    .byte $23, $c2, $01, $ea  ; attribute table data, used for coin icon in status bar
    .byte $ff  ; end of data block

WorldLivesDisplay:
    .byte $21, $cd, $07, $24, $24  ; cross with spaces used on
    .byte $29, $24, $24, $24, $24  ; lives display
    .byte $21, $4b, $09, $20, $18  ; "WORLD  - " used on lives display
    .byte $1b, $15, $0d, $24, $24, $28, $24
    .byte $22, $0c, $47, $24  ; possibly used to clear time up
    .byte $23, $dc, $01, $ba  ; attribute table data for crown if more than 9 lives
    .byte $ff

TwoPlayerTimeUp:
    .byte $21, $cd, $05, $16, $0a, $1b, $12, $18  ; "MARIO"
OnePlayerTimeUp:
    .byte $22, $0c, $07, $1d, $12, $16, $0e, $24, $1e, $19  ; "TIME UP"
    .byte $ff

TwoPlayerGameOver:
    .byte $21, $cd, $05, $16, $0a, $1b, $12, $18  ; "MARIO"
OnePlayerGameOver:
    .byte $22, $0b, $09, $10, $0a, $16, $0e, $24  ; "GAME OVER"
    .byte $18, $1f, $0e, $1b
    .byte $ff

WarpZoneWelcome:
    .byte $25, $84, $15, $20, $0e, $15, $0c, $18, $16  ; "WELCOME TO WARP ZONE!"
    .byte $0e, $24, $1d, $18, $24, $20, $0a, $1b, $19
    .byte $24, $23, $18, $17, $0e, $2b
    .byte $26, $25, $01, $24  ; placeholder for left pipe
    .byte $26, $2d, $01, $24  ; placeholder for middle pipe
    .byte $26, $35, $01, $24  ; placeholder for right pipe
    .byte $27, $d9, $46, $aa  ; attribute data
    .byte $27, $e1, $45, $aa
    .byte $ff

LuigiName:
    .byte $15, $1e, $12, $10, $12  ; "LUIGI", no address or length

WarpZoneNumbers:
    .byte $04, $03, $02, $00  ; warp zone numbers, note spaces on middle
    .byte $24, $05, $24, $00  ; zone, partly responsible for
    .byte $08, $07, $06, $00  ; the minus world

GameTextOffsets:
    .byte TopStatusBarLine-GameText, TopStatusBarLine-GameText
    .byte WorldLivesDisplay-GameText, WorldLivesDisplay-GameText
    .byte TwoPlayerTimeUp-GameText, OnePlayerTimeUp-GameText
    .byte TwoPlayerGameOver-GameText, OnePlayerGameOver-GameText
    .byte WarpZoneWelcome-GameText, WarpZoneWelcome-GameText

WriteGameText:
    PHA  ; save text number to stack
    ASL
    TAY  ; multiply by 2 and use as offset
    CPY #$04  ; if set to do top status bar or world/lives display,
    BCC LdGameText  ; branch to use current offset as-is
    CPY #$08  ; if set to do time-up or game over,
    BCC Chk2Players  ; branch to check players
    LDY #$08  ; otherwise warp zone, therefore set offset
Chk2Players:
    LDA NumberOfPlayers  ; check for number of players
    BNE LdGameText  ; if there are two, use current offset to also print name
    INY  ; otherwise increment offset by one to not print name
LdGameText:
    LDX GameTextOffsets,y  ; get offset to message we want to print
    LDY #$00
GameTextLoop:
    LDA GameText,x  ; load message data
    CMP #$ff  ; check for terminator
    BEQ EndGameText  ; branch to end text if found
    STA VRAM_Buffer1,y  ; otherwise write data to buffer
    INX  ; and increment increment
    INY
    BNE GameTextLoop  ; do this for 256 bytes if no terminator found
EndGameText:
    LDA #$00  ; put null terminator at end
    STA VRAM_Buffer1,y
    PLA  ; pull original text number from stack
    TAX
    CMP #$04  ; are we printing warp zone?
    BCS PrintWarpZoneNumbers
    DEX  ; are we printing the world/lives display?
    BNE CheckPlayerName  ; if not, branch to check player's name
    LDA NumberofLives  ; otherwise, check number of lives
    CLC  ; and increment by one for display
    ADC #$01
    CMP #10  ; more than 9 lives?
    BCC PutLives
    SBC #10  ; if so, subtract 10 and put a crown tile
    LDY #$9f  ; next to the difference...strange things happen if
    STY VRAM_Buffer1+7  ; the number of lives exceeds 19
PutLives:
    STA VRAM_Buffer1+8
    LDY WorldNumber  ; write world and level numbers (incremented for display)
    INY  ; to the buffer in the spaces surrounding the dash
    STY VRAM_Buffer1+19
    LDY LevelNumber
    INY
    STY VRAM_Buffer1+21  ; we're done here
    RTS

CheckPlayerName:
    LDA NumberOfPlayers  ; check number of players
    BEQ ExitChkName  ; if only 1 player, leave
    LDA CurrentPlayer  ; load current player
    DEX  ; check to see if current message number is for time up
    BNE ChkLuigi
    LDY OperMode  ; check for game over mode
    CPY #GameOverModeValue
    BEQ ChkLuigi
    EOR #%00000001  ; if not, must be time up, invert d0 to do other player
ChkLuigi:
    LSR
    BCC ExitChkName  ; if mario is current player, do not change the name
    LDY #$04
NameLoop:
    LDA LuigiName,y  ; otherwise, replace "MARIO" with "LUIGI"
    STA VRAM_Buffer1+3,y
    DEY
    BPL NameLoop  ; do this until each letter is replaced
ExitChkName:
    RTS

PrintWarpZoneNumbers:
    SBC #$04  ; subtract 4 and then shift to the left
    ASL  ; twice to get proper warp zone number
    ASL  ; offset
    TAX
    LDY #$00
WarpNumLoop:
    LDA WarpZoneNumbers,x  ; print warp zone numbers into the
    STA VRAM_Buffer1+27,y  ; placeholders from earlier
    INX
    INY  ; put a number in every fourth space
    INY
    INY
    INY
    CPY #$0c
    BCC WarpNumLoop
    LDA #$2c  ; load new buffer pointer at end of message
    JMP SetVRAMOffset

; -------------------------------------------------------------------------------------

ResetSpritesAndScreenTimer:
    LDA ScreenTimer  ; check if screen timer has expired
    BNE NoReset  ; if not, branch to leave
    JSR MoveAllSpritesOffscreen  ; otherwise reset sprites now

ResetScreenTimer:
    LDA #$07  ; reset timer again
    STA ScreenTimer
    INC ScreenRoutineTask  ; move onto next task
NoReset:
    RTS
