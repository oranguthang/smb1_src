; -------------------------------------------------------------------------------------

ScreenRoutines:
    LDA ram_screen_routine_task  ; run one of the following subroutines
    JSR sub_dispatch_inline_handler

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
    LDA ram_oper_mode
    BEQ NextSubtask  ; if mode still 0, do not load
    LDX #$03  ; into buffer pointer
    JMP SetVRAMAddr_A

; -------------------------------------------------------------------------------------

SetupIntermediate:
    LDA ram_background_color_ctrl  ; save current background color control
    PHA  ; and player status to stack
    LDA ram_player_status
    PHA
    LDA #$00  ; set background color to black
    STA ram_player_status  ; and player status to not fiery
    LDA #$02  ; this is the ONLY time background color control
    STA ram_background_color_ctrl  ; is set to less than 4
    JSR GetPlayerColors
    PLA  ; we only execute this routine for
    STA ram_player_status  ; the intermediate lives display
    PLA  ; and once we're done, we return bg
    STA ram_background_color_ctrl  ; color ctrl and player status from stack
    JMP IncSubtask  ; then move onto the next task

; -------------------------------------------------------------------------------------

AreaPalette:
    .byte $01, $02, $03, $04

GetAreaPalette:
    LDY ram_area_type  ; select appropriate palette to load
    LDX AreaPalette,y  ; based on area type
SetVRAMAddr_A:
    STX ram_vram_buffer_addr_ctrl  ; store offset into buffer control
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
    LDY ram_background_color_ctrl  ; check background color control
    BEQ NoBGColor  ; if not set, increment task and fetch palette
    LDA BGColorCtrl_Addr-4,y  ; put appropriate palette into vram
    STA ram_vram_buffer_addr_ctrl  ; note that if set to 5-7, $0301 will not be read
NoBGColor:
    INC ram_screen_routine_task  ; increment to next subtask and plod on through

GetPlayerColors:
    LDX ram_vram_buffer1_offset  ; get current buffer offset
    LDY #$00
    LDA ram_current_player  ; check which player is on the screen
    BEQ ChkFiery
    LDY #$04  ; load offset for luigi
ChkFiery:
    LDA ram_player_status  ; check player status
    CMP #$02
    BNE StartClrGet  ; if fiery, load alternate offset for fiery player
    LDY #$08
StartClrGet:
    LDA #$03  ; do four colors
    STA $00
ClrGetLoop:
    LDA PlayerColors,y  ; fetch player colors and store them
    STA ram_vram_buffer1+3,x  ; in the buffer
    INY
    INX
    DEC $00
    BPL ClrGetLoop
    LDX ram_vram_buffer1_offset  ; load original offset from before
    LDY ram_background_color_ctrl  ; if this value is four or greater, it will be set
    BNE SetBGColor  ; therefore use it as offset to background color
    LDY ram_area_type  ; otherwise use area type bits from area offset as offset
SetBGColor:
    LDA BackgroundColors,y  ; to background color instead
    STA ram_vram_buffer1+3,x
    LDA #$3f  ; set for sprite palette address
    STA ram_vram_buffer1,x  ; save to buffer
    LDA #$10
    STA ram_vram_buffer1+1,x
    LDA #$04  ; write length byte to buffer
    STA ram_vram_buffer1+2,x
    LDA #$00  ; now the null terminator
    STA ram_vram_buffer1+7,x
    TXA  ; move the buffer pointer ahead 7 bytes
    CLC  ; in case we want to write anything else later
    ADC #$07
SetVRAMOffset:
    STA ram_vram_buffer1_offset  ; store as new vram buffer offset
    RTS

; -------------------------------------------------------------------------------------

GetAlternatePalette1:
    LDA ram_area_style  ; check for mushroom level style
    CMP #$01
    BNE NoAltPal
    LDA #$0b  ; if found, load appropriate palette
SetVRAMAddr_B:
    STA ram_vram_buffer_addr_ctrl
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
    LDX ram_vram_buffer1_offset
    LDA #$20  ; write address for world-area number on screen
    STA ram_vram_buffer1,x
    LDA #$73
    STA ram_vram_buffer1+1,x
    LDA #$03  ; write length for it
    STA ram_vram_buffer1+2,x
    LDY ram_world_number  ; first the world number
    INY
    TYA
    STA ram_vram_buffer1+3,x
    LDA #$28  ; next the dash
    STA ram_vram_buffer1+4,x
    LDY ram_level_number  ; next the level number
    INY  ; increment for proper number display
    TYA
    STA ram_vram_buffer1+5,x
    LDA #$00  ; put null terminator on
    STA ram_vram_buffer1+6,x
    TXA  ; move the buffer offset up by 6 bytes
    CLC
    ADC #$06
    STA ram_vram_buffer1_offset
    JMP IncSubtask

; -------------------------------------------------------------------------------------

DisplayTimeUp:
    LDA ram_game_timer_expired_flag  ; if game timer not expired, increment task
    BEQ NoTimeUp  ; control 2 tasks forward, otherwise, stay here
    LDA #$00
    STA ram_game_timer_expired_flag  ; reset timer expiration flag
    LDA #$02  ; output time-up screen to buffer
    JMP OutputInter
NoTimeUp:
    INC ram_screen_routine_task  ; increment control task 2 tasks forward
    JMP IncSubtask

; -------------------------------------------------------------------------------------

DisplayIntermediate:
    LDA ram_oper_mode  ; check primary mode of operation
    BEQ NoInter  ; if in title screen mode, skip this
    CMP #con_mode_game_over  ; are we in game over mode?
    BEQ GameOverInter  ; if so, proceed to display game over screen
    LDA ram_alt_entrance_control  ; otherwise check for mode of alternate entry
    BNE NoInter  ; and branch if found
    LDY ram_area_type  ; check if we are on castle level
    CPY #$03  ; and if so, branch (possibly residual)
    BEQ PlayerInter
    LDA ram_disable_intermediate  ; if this flag is set, skip intermediate lives display
    BNE NoInter  ; and jump to specific task, otherwise
PlayerInter:
    JSR DrawPlayer_Intermediate  ; put player in appropriate place for
    LDA #$01  ; lives display, then output lives display to buffer
OutputInter:
    JSR WriteGameText
    JSR ResetScreenTimer
    LDA #$00
    STA ram_disable_screen_flag  ; reenable screen output
    RTS
GameOverInter:
    LDA #$12  ; set screen timer
    STA ram_screen_timer
    LDA #$03  ; output game over screen to buffer
    JSR WriteGameText
    JMP IncModeTask_B
NoInter:
    LDA #$08  ; set for specific task and leave
    STA ram_screen_routine_task
    RTS

; -------------------------------------------------------------------------------------

AreaParserTaskControl:
    INC ram_disable_screen_flag  ; turn off screen
TaskLoop:
    JSR AreaParserTaskHandler  ; render column set of current area
    LDA ram_area_parser_task_num  ; check number of tasks
    BNE TaskLoop  ; if tasks still not all done, do another one
    DEC ram_column_sets  ; do we need to render more column sets?
    BPL OutputCol
    INC ram_screen_routine_task  ; if not, move on to the next task
OutputCol:
    LDA #$06  ; set vram buffer to output rendered column set
    STA ram_vram_buffer_addr_ctrl  ; on next NMI
    RTS

; -------------------------------------------------------------------------------------

; $00 - vram buffer address table low
; $01 - vram buffer address table high

DrawTitleScreen:
    LDA ram_oper_mode  ; are we in title screen mode?
    BNE IncModeTask_B  ; if not, exit
    LDA #>con_title_screen_data_offset  ; load address $1ec0 into
    STA PPU_ADDRESS  ; the vram address register
    LDA #<con_title_screen_data_offset
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
    LDA ram_oper_mode  ; check game mode
    BNE IncModeTask_B  ; if not title screen mode, leave
    LDX #$00  ; otherwise, clear buffer space
TScrClear:
    STA ram_vram_buffer1-1,x
    STA ram_vram_buffer1-1+$100,x
    DEX
    BNE TScrClear
    JSR DrawMushroomIcon  ; draw player select icon
IncSubtask:
    INC ram_screen_routine_task  ; move onto next task
    RTS

; -------------------------------------------------------------------------------------

WriteTopScore:
    LDA #$fa  ; run display routine to display top score on title
    JSR UpdateNumber
IncModeTask_B:
    INC ram_oper_mode_task  ; move onto next mode
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
    LDA ram_number_of_players  ; check for number of players
    BNE LdGameText  ; if there are two, use current offset to also print name
    INY  ; otherwise increment offset by one to not print name
LdGameText:
    LDX GameTextOffsets,y  ; get offset to message we want to print
    LDY #$00
GameTextLoop:
    LDA GameText,x  ; load message data
    CMP #$ff  ; check for terminator
    BEQ EndGameText  ; branch to end text if found
    STA ram_vram_buffer1,y  ; otherwise write data to buffer
    INX  ; and increment increment
    INY
    BNE GameTextLoop  ; do this for 256 bytes if no terminator found
EndGameText:
    LDA #$00  ; put null terminator at end
    STA ram_vram_buffer1,y
    PLA  ; pull original text number from stack
    TAX
    CMP #$04  ; are we printing warp zone?
    BCS PrintWarpZoneNumbers
    DEX  ; are we printing the world/lives display?
    BNE CheckPlayerName  ; if not, branch to check player's name
    LDA ram_numberof_lives  ; otherwise, check number of lives
    CLC  ; and increment by one for display
    ADC #$01
    CMP #10  ; more than 9 lives?
    BCC PutLives
    SBC #10  ; if so, subtract 10 and put a crown tile
    LDY #$9f  ; next to the difference...strange things happen if
    STY ram_vram_buffer1+7  ; the number of lives exceeds 19
PutLives:
    STA ram_vram_buffer1+8
    LDY ram_world_number  ; write world and level numbers (incremented for display)
    INY  ; to the buffer in the spaces surrounding the dash
    STY ram_vram_buffer1+19
    LDY ram_level_number
    INY
    STY ram_vram_buffer1+21  ; we're done here
    RTS

CheckPlayerName:
    LDA ram_number_of_players  ; check number of players
    BEQ ExitChkName  ; if only 1 player, leave
    LDA ram_current_player  ; load current player
    DEX  ; check to see if current message number is for time up
    BNE ChkLuigi
    LDY ram_oper_mode  ; check for game over mode
    CPY #con_mode_game_over
    BEQ ChkLuigi
    EOR #%00000001  ; if not, must be time up, invert d0 to do other player
ChkLuigi:
    LSR
    BCC ExitChkName  ; if mario is current player, do not change the name
    LDY #$04
NameLoop:
    LDA LuigiName,y  ; otherwise, replace "MARIO" with "LUIGI"
    STA ram_vram_buffer1+3,y
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
    STA ram_vram_buffer1+27,y  ; placeholders from earlier
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
    LDA ram_screen_timer  ; check if screen timer has expired
    BNE NoReset  ; if not, branch to leave
    JSR MoveAllSpritesOffscreen  ; otherwise reset sprites now

ResetScreenTimer:
    LDA #$07  ; reset timer again
    STA ram_screen_timer
    INC ram_screen_routine_task  ; move onto next task
NoReset:
    RTS
