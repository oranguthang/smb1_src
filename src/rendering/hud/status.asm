;-------------------------------------------------------------------------------------
;$00 - used to store status bar nybbles
;$02 - used as temp vram offset
;$03 - used to store length of status bar number

;status bar name table offset and length data
StatusBarData:
      .byte $f0, $06 ; top score display on title screen
      .byte $62, $06 ; player score
      .byte $62, $06
      .byte $6d, $02 ; coin tally
      .byte $6d, $02
      .byte $7a, $03 ; game timer

StatusBarOffset:
      .byte $06, $0c, $12, $18, $1e, $24

PrintStatusBarNumbers:
      sta $00            ;store player-specific offset
      jsr OutputNumbers  ;use first nybble to print the coin display
      lda $00            ;move high nybble to low
      lsr                ;and print to score display
      lsr
      lsr
      lsr

OutputNumbers:
             clc                      ;add 1 to low nybble
             adc #$01
             and #%00001111           ;mask out high nybble
             cmp #$06
             bcs ExitOutputN
             pha                      ;save incremented value to stack for now and
             asl                      ;shift to left and use as offset
             tay
             ldx VRAM_Buffer1_Offset  ;get current buffer pointer
             lda #$20                 ;put at top of screen by default
             cpy #$00                 ;are we writing top score on title screen?
             bne SetupNums
             lda #$22                 ;if so, put further down on the screen
SetupNums:   sta VRAM_Buffer1,x
             lda StatusBarData,y      ;write low vram address and length of thing
             sta VRAM_Buffer1+1,x     ;we're printing to the buffer
             lda StatusBarData+1,y
             sta VRAM_Buffer1+2,x
             sta $03                  ;save length byte in counter
             stx $02                  ;and buffer pointer elsewhere for now
             pla                      ;pull original incremented value from stack
             tax
             lda StatusBarOffset,x    ;load offset to value we want to write
             sec
             sbc StatusBarData+1,y    ;subtract from length byte we read before
             tay                      ;use value as offset to display digits
             ldx $02
DigitPLoop:  lda DisplayDigits,y      ;write digits to the buffer
             sta VRAM_Buffer1+3,x
             inx
             iny
             dec $03                  ;do this until all the digits are written
             bne DigitPLoop
             lda #$00                 ;put null terminator at end
             sta VRAM_Buffer1+3,x
             inx                      ;increment buffer pointer by 3
             inx
             inx
             stx VRAM_Buffer1_Offset  ;store it in case we want to use it again
ExitOutputN: rts

;-------------------------------------------------------------------------------------

DigitsMathRoutine:
            lda OperMode              ;check mode of operation
            cmp #TitleScreenModeValue
            beq EraseDMods            ;if in title screen mode, branch to lock score
            ldx #$05
AddModLoop: lda DigitModifier,x       ;load digit amount to increment
            clc
            adc DisplayDigits,y       ;add to current digit
            bmi BorrowOne             ;if result is a negative number, branch to subtract
            cmp #10
            bcs CarryOne              ;if digit greater than $09, branch to add
StoreNewD:  sta DisplayDigits,y       ;store as new score or game timer digit
            dey                       ;move onto next digits in score or game timer
            dex                       ;and digit amounts to increment
            bpl AddModLoop            ;loop back if we're not done yet
EraseDMods: lda #$00                  ;store zero here
            ldx #$06                  ;start with the last digit
EraseMLoop: sta DigitModifier-1,x     ;initialize the digit amounts to increment
            dex
            bpl EraseMLoop            ;do this until they're all reset, then leave
            rts
BorrowOne:  dec DigitModifier-1,x     ;decrement the previous digit, then put $09 in
            lda #$09                  ;the game timer digit we're currently on to "borrow
            bne StoreNewD             ;the one", then do an unconditional branch back
CarryOne:   sec                       ;subtract ten from our digit to make it a
            sbc #10                   ;proper BCD number, then increment the digit
            inc DigitModifier-1,x     ;preceding current digit to "carry the one" properly
            jmp StoreNewD             ;go back to just after we branched here

;-------------------------------------------------------------------------------------

UpdateTopScore:
      ldx #$05          ;start with mario's score
      jsr TopScoreCheck
      ldx #$0b          ;now do luigi's score

TopScoreCheck:
              ldy #$05                 ;start with the lowest digit
              sec
GetScoreDiff: lda PlayerScoreDisplay,x ;subtract each player digit from each high score digit
              sbc TopScoreDisplay,y    ;from lowest to highest, if any top score digit exceeds
              dex                      ;any player digit, borrow will be set until a subsequent
              dey                      ;subtraction clears it (player digit is higher than top)
              bpl GetScoreDiff
              bcc NoTopSc              ;check to see if borrow is still set, if so, no new high score
              inx                      ;increment X and Y once to the start of the score
              iny
CopyScore:    lda PlayerScoreDisplay,x ;store player's score digits into high score memory area
              sta TopScoreDisplay,y
              inx
              iny
              cpy #$06                 ;do this until we have stored them all
              bcc CopyScore
NoTopSc:      rts
