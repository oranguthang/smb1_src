;-------------------------------------------------------------------------------------

ScreenRoutines:
      lda ScreenRoutineTask        ;run one of the following subroutines
      jsr JumpEngine

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

;-------------------------------------------------------------------------------------

InitScreen:
      jsr MoveAllSpritesOffscreen ;initialize all sprites including sprite #0
      jsr InitializeNameTables    ;and erase both name and attribute tables
      lda OperMode
      beq NextSubtask             ;if mode still 0, do not load
      ldx #$03                    ;into buffer pointer
      jmp SetVRAMAddr_A

;-------------------------------------------------------------------------------------

SetupIntermediate:
      lda BackgroundColorCtrl  ;save current background color control
      pha                      ;and player status to stack
      lda PlayerStatus
      pha
      lda #$00                 ;set background color to black
      sta PlayerStatus         ;and player status to not fiery
      lda #$02                 ;this is the ONLY time background color control
      sta BackgroundColorCtrl  ;is set to less than 4
      jsr GetPlayerColors
      pla                      ;we only execute this routine for
      sta PlayerStatus         ;the intermediate lives display
      pla                      ;and once we're done, we return bg
      sta BackgroundColorCtrl  ;color ctrl and player status from stack
      jmp IncSubtask           ;then move onto the next task

;-------------------------------------------------------------------------------------

AreaPalette:
      .byte $01, $02, $03, $04

GetAreaPalette:
               ldy AreaType             ;select appropriate palette to load
               ldx AreaPalette,y        ;based on area type
SetVRAMAddr_A: stx VRAM_Buffer_AddrCtrl ;store offset into buffer control
NextSubtask:   jmp IncSubtask           ;move onto next task

;-------------------------------------------------------------------------------------
;$00 - used as temp counter in GetPlayerColors

BGColorCtrl_Addr:
      .byte $00, $09, $0a, $04

BackgroundColors:
      .byte $22, $22, $0f, $0f ;used by area type if bg color ctrl not set
      .byte $0f, $22, $0f, $0f ;used by background color control if set

PlayerColors:
      .byte $22, $16, $27, $18 ;mario's colors
      .byte $22, $30, $27, $19 ;luigi's colors
      .byte $22, $37, $27, $16 ;fiery (used by both)

GetBackgroundColor:
           ldy BackgroundColorCtrl   ;check background color control
           beq NoBGColor             ;if not set, increment task and fetch palette
           lda BGColorCtrl_Addr-4,y  ;put appropriate palette into vram
           sta VRAM_Buffer_AddrCtrl  ;note that if set to 5-7, $0301 will not be read
NoBGColor: inc ScreenRoutineTask     ;increment to next subtask and plod on through

GetPlayerColors:
               ldx VRAM_Buffer1_Offset  ;get current buffer offset
               ldy #$00
               lda CurrentPlayer        ;check which player is on the screen
               beq ChkFiery
               ldy #$04                 ;load offset for luigi
ChkFiery:      lda PlayerStatus         ;check player status
               cmp #$02
               bne StartClrGet          ;if fiery, load alternate offset for fiery player
               ldy #$08
StartClrGet:   lda #$03                 ;do four colors
               sta $00
ClrGetLoop:    lda PlayerColors,y       ;fetch player colors and store them
               sta VRAM_Buffer1+3,x     ;in the buffer
               iny
               inx
               dec $00
               bpl ClrGetLoop
               ldx VRAM_Buffer1_Offset  ;load original offset from before
               ldy BackgroundColorCtrl  ;if this value is four or greater, it will be set
               bne SetBGColor           ;therefore use it as offset to background color
               ldy AreaType             ;otherwise use area type bits from area offset as offset
SetBGColor:    lda BackgroundColors,y   ;to background color instead
               sta VRAM_Buffer1+3,x
               lda #$3f                 ;set for sprite palette address
               sta VRAM_Buffer1,x       ;save to buffer
               lda #$10
               sta VRAM_Buffer1+1,x
               lda #$04                 ;write length byte to buffer
               sta VRAM_Buffer1+2,x
               lda #$00                 ;now the null terminator
               sta VRAM_Buffer1+7,x
               txa                      ;move the buffer pointer ahead 7 bytes
               clc                      ;in case we want to write anything else later
               adc #$07
SetVRAMOffset: sta VRAM_Buffer1_Offset  ;store as new vram buffer offset
               rts

;-------------------------------------------------------------------------------------

GetAlternatePalette1:
               lda AreaStyle            ;check for mushroom level style
               cmp #$01
               bne NoAltPal
               lda #$0b                 ;if found, load appropriate palette
SetVRAMAddr_B: sta VRAM_Buffer_AddrCtrl
NoAltPal:      jmp IncSubtask           ;now onto the next task

;-------------------------------------------------------------------------------------

WriteTopStatusLine:
      lda #$00          ;select main status bar
      jsr WriteGameText ;output it
      jmp IncSubtask    ;onto the next task

;-------------------------------------------------------------------------------------

WriteBottomStatusLine:
      jsr GetSBNybbles        ;write player's score and coin tally to screen
      ldx VRAM_Buffer1_Offset
      lda #$20                ;write address for world-area number on screen
      sta VRAM_Buffer1,x
      lda #$73
      sta VRAM_Buffer1+1,x
      lda #$03                ;write length for it
      sta VRAM_Buffer1+2,x
      ldy WorldNumber         ;first the world number
      iny
      tya
      sta VRAM_Buffer1+3,x
      lda #$28                ;next the dash
      sta VRAM_Buffer1+4,x
      ldy LevelNumber         ;next the level number
      iny                     ;increment for proper number display
      tya
      sta VRAM_Buffer1+5,x
      lda #$00                ;put null terminator on
      sta VRAM_Buffer1+6,x
      txa                     ;move the buffer offset up by 6 bytes
      clc
      adc #$06
      sta VRAM_Buffer1_Offset
      jmp IncSubtask

;-------------------------------------------------------------------------------------

DisplayTimeUp:
          lda GameTimerExpiredFlag  ;if game timer not expired, increment task
          beq NoTimeUp              ;control 2 tasks forward, otherwise, stay here
          lda #$00
          sta GameTimerExpiredFlag  ;reset timer expiration flag
          lda #$02                  ;output time-up screen to buffer
          jmp OutputInter
NoTimeUp: inc ScreenRoutineTask     ;increment control task 2 tasks forward
          jmp IncSubtask

;-------------------------------------------------------------------------------------

DisplayIntermediate:
               lda OperMode                 ;check primary mode of operation
               beq NoInter                  ;if in title screen mode, skip this
               cmp #GameOverModeValue       ;are we in game over mode?
               beq GameOverInter            ;if so, proceed to display game over screen
               lda AltEntranceControl       ;otherwise check for mode of alternate entry
               bne NoInter                  ;and branch if found
               ldy AreaType                 ;check if we are on castle level
               cpy #$03                     ;and if so, branch (possibly residual)
               beq PlayerInter
               lda DisableIntermediate      ;if this flag is set, skip intermediate lives display
               bne NoInter                  ;and jump to specific task, otherwise
PlayerInter:   jsr DrawPlayer_Intermediate  ;put player in appropriate place for
               lda #$01                     ;lives display, then output lives display to buffer
OutputInter:   jsr WriteGameText
               jsr ResetScreenTimer
               lda #$00
               sta DisableScreenFlag        ;reenable screen output
               rts
GameOverInter: lda #$12                     ;set screen timer
               sta ScreenTimer
               lda #$03                     ;output game over screen to buffer
               jsr WriteGameText
               jmp IncModeTask_B
NoInter:       lda #$08                     ;set for specific task and leave
               sta ScreenRoutineTask
               rts

;-------------------------------------------------------------------------------------

AreaParserTaskControl:
           inc DisableScreenFlag     ;turn off screen
TaskLoop:  jsr AreaParserTaskHandler ;render column set of current area
           lda AreaParserTaskNum     ;check number of tasks
           bne TaskLoop              ;if tasks still not all done, do another one
           dec ColumnSets            ;do we need to render more column sets?
           bpl OutputCol
           inc ScreenRoutineTask     ;if not, move on to the next task
OutputCol: lda #$06                  ;set vram buffer to output rendered column set
           sta VRAM_Buffer_AddrCtrl  ;on next NMI
           rts

;-------------------------------------------------------------------------------------

;$00 - vram buffer address table low
;$01 - vram buffer address table high

DrawTitleScreen:
            lda OperMode                 ;are we in title screen mode?
            bne IncModeTask_B            ;if not, exit
            lda #>TitleScreenDataOffset  ;load address $1ec0 into
            sta PPU_ADDRESS              ;the vram address register
            lda #<TitleScreenDataOffset
            sta PPU_ADDRESS
            lda #$03                     ;put address $0300 into
            sta $01                      ;the indirect at $00
            ldy #$00
            sty $00
            lda PPU_DATA                 ;do one garbage read
OutputTScr: lda PPU_DATA                 ;get title screen from chr-rom
            sta ($00),y                  ;store 256 bytes into buffer
            iny
            bne ChkHiByte                ;if not past 256 bytes, do not increment
            inc $01                      ;otherwise increment high byte of indirect
ChkHiByte:  lda $01                      ;check high byte?
            cmp #$04                     ;at $0400?
            bne OutputTScr               ;if not, loop back and do another
            cpy #$3a                     ;check if offset points past end of data
            bcc OutputTScr               ;if not, loop back and do another
            lda #$05                     ;set buffer transfer control to $0300,
            jmp SetVRAMAddr_B            ;increment task and exit

;-------------------------------------------------------------------------------------

ClearBuffersDrawIcon:
             lda OperMode               ;check game mode
             bne IncModeTask_B          ;if not title screen mode, leave
             ldx #$00                   ;otherwise, clear buffer space
TScrClear:   sta VRAM_Buffer1-1,x
             sta VRAM_Buffer1-1+$100,x
             dex
             bne TScrClear
             jsr DrawMushroomIcon       ;draw player select icon
IncSubtask:  inc ScreenRoutineTask      ;move onto next task
             rts

;-------------------------------------------------------------------------------------

WriteTopScore:
               lda #$fa           ;run display routine to display top score on title
               jsr UpdateNumber
IncModeTask_B: inc OperMode_Task  ;move onto next mode
               rts

;-------------------------------------------------------------------------------------

GameText:
TopStatusBarLine:
  .byte $20, $43, $05, $16, $0a, $1b, $12, $18 ; "MARIO"
  .byte $20, $52, $0b, $20, $18, $1b, $15, $0d ; "WORLD  TIME"
  .byte $24, $24, $1d, $12, $16, $0e
  .byte $20, $68, $05, $00, $24, $24, $2e, $29 ; score trailing digit and coin display
  .byte $23, $c0, $7f, $aa ; attribute table data, clears name table 0 to palette 2
  .byte $23, $c2, $01, $ea ; attribute table data, used for coin icon in status bar
  .byte $ff ; end of data block

WorldLivesDisplay:
  .byte $21, $cd, $07, $24, $24 ; cross with spaces used on
  .byte $29, $24, $24, $24, $24 ; lives display
  .byte $21, $4b, $09, $20, $18 ; "WORLD  - " used on lives display
  .byte $1b, $15, $0d, $24, $24, $28, $24
  .byte $22, $0c, $47, $24 ; possibly used to clear time up
  .byte $23, $dc, $01, $ba ; attribute table data for crown if more than 9 lives
  .byte $ff

TwoPlayerTimeUp:
  .byte $21, $cd, $05, $16, $0a, $1b, $12, $18 ; "MARIO"
OnePlayerTimeUp:
  .byte $22, $0c, $07, $1d, $12, $16, $0e, $24, $1e, $19 ; "TIME UP"
  .byte $ff

TwoPlayerGameOver:
  .byte $21, $cd, $05, $16, $0a, $1b, $12, $18 ; "MARIO"
OnePlayerGameOver:
  .byte $22, $0b, $09, $10, $0a, $16, $0e, $24 ; "GAME OVER"
  .byte $18, $1f, $0e, $1b
  .byte $ff

WarpZoneWelcome:
  .byte $25, $84, $15, $20, $0e, $15, $0c, $18, $16 ; "WELCOME TO WARP ZONE!"
  .byte $0e, $24, $1d, $18, $24, $20, $0a, $1b, $19
  .byte $24, $23, $18, $17, $0e, $2b
  .byte $26, $25, $01, $24         ; placeholder for left pipe
  .byte $26, $2d, $01, $24         ; placeholder for middle pipe
  .byte $26, $35, $01, $24         ; placeholder for right pipe
  .byte $27, $d9, $46, $aa         ; attribute data
  .byte $27, $e1, $45, $aa
  .byte $ff

LuigiName:
  .byte $15, $1e, $12, $10, $12    ; "LUIGI", no address or length

WarpZoneNumbers:
  .byte $04, $03, $02, $00         ; warp zone numbers, note spaces on middle
  .byte $24, $05, $24, $00         ; zone, partly responsible for
  .byte $08, $07, $06, $00         ; the minus world

GameTextOffsets:
  .byte TopStatusBarLine-GameText, TopStatusBarLine-GameText
  .byte WorldLivesDisplay-GameText, WorldLivesDisplay-GameText
  .byte TwoPlayerTimeUp-GameText, OnePlayerTimeUp-GameText
  .byte TwoPlayerGameOver-GameText, OnePlayerGameOver-GameText
  .byte WarpZoneWelcome-GameText, WarpZoneWelcome-GameText

WriteGameText:
               pha                      ;save text number to stack
               asl
               tay                      ;multiply by 2 and use as offset
               cpy #$04                 ;if set to do top status bar or world/lives display,
               bcc LdGameText           ;branch to use current offset as-is
               cpy #$08                 ;if set to do time-up or game over,
               bcc Chk2Players          ;branch to check players
               ldy #$08                 ;otherwise warp zone, therefore set offset
Chk2Players:   lda NumberOfPlayers      ;check for number of players
               bne LdGameText           ;if there are two, use current offset to also print name
               iny                      ;otherwise increment offset by one to not print name
LdGameText:    ldx GameTextOffsets,y    ;get offset to message we want to print
               ldy #$00
GameTextLoop:  lda GameText,x           ;load message data
               cmp #$ff                 ;check for terminator
               beq EndGameText          ;branch to end text if found
               sta VRAM_Buffer1,y       ;otherwise write data to buffer
               inx                      ;and increment increment
               iny
               bne GameTextLoop         ;do this for 256 bytes if no terminator found
EndGameText:   lda #$00                 ;put null terminator at end
               sta VRAM_Buffer1,y
               pla                      ;pull original text number from stack
               tax
               cmp #$04                 ;are we printing warp zone?
               bcs PrintWarpZoneNumbers
               dex                      ;are we printing the world/lives display?
               bne CheckPlayerName      ;if not, branch to check player's name
               lda NumberofLives        ;otherwise, check number of lives
               clc                      ;and increment by one for display
               adc #$01
               cmp #10                  ;more than 9 lives?
               bcc PutLives
               sbc #10                  ;if so, subtract 10 and put a crown tile
               ldy #$9f                 ;next to the difference...strange things happen if
               sty VRAM_Buffer1+7       ;the number of lives exceeds 19
PutLives:      sta VRAM_Buffer1+8
               ldy WorldNumber          ;write world and level numbers (incremented for display)
               iny                      ;to the buffer in the spaces surrounding the dash
               sty VRAM_Buffer1+19
               ldy LevelNumber
               iny
               sty VRAM_Buffer1+21      ;we're done here
               rts

CheckPlayerName:
             lda NumberOfPlayers    ;check number of players
             beq ExitChkName        ;if only 1 player, leave
             lda CurrentPlayer      ;load current player
             dex                    ;check to see if current message number is for time up
             bne ChkLuigi
             ldy OperMode           ;check for game over mode
             cpy #GameOverModeValue
             beq ChkLuigi
             eor #%00000001         ;if not, must be time up, invert d0 to do other player
ChkLuigi:    lsr
             bcc ExitChkName        ;if mario is current player, do not change the name
             ldy #$04
NameLoop:    lda LuigiName,y        ;otherwise, replace "MARIO" with "LUIGI"
             sta VRAM_Buffer1+3,y
             dey
             bpl NameLoop           ;do this until each letter is replaced
ExitChkName: rts

PrintWarpZoneNumbers:
             sbc #$04               ;subtract 4 and then shift to the left
             asl                    ;twice to get proper warp zone number
             asl                    ;offset
             tax
             ldy #$00
WarpNumLoop: lda WarpZoneNumbers,x  ;print warp zone numbers into the
             sta VRAM_Buffer1+27,y  ;placeholders from earlier
             inx
             iny                    ;put a number in every fourth space
             iny
             iny
             iny
             cpy #$0c
             bcc WarpNumLoop
             lda #$2c               ;load new buffer pointer at end of message
             jmp SetVRAMOffset

;-------------------------------------------------------------------------------------

ResetSpritesAndScreenTimer:
         lda ScreenTimer             ;check if screen timer has expired
         bne NoReset                 ;if not, branch to leave
         jsr MoveAllSpritesOffscreen ;otherwise reset sprites now

ResetScreenTimer:
         lda #$07                    ;reset timer again
         sta ScreenTimer
         inc ScreenRoutineTask       ;move onto next task
NoReset: rts
