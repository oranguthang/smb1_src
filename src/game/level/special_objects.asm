;-------------------------------------------------------------------------------------
;(these apply to all area object subroutines in this section unless otherwise stated)
;$00 - used to store offset used to find object code
;$07 - starts with adder from area parser, used to store row offset

AlterAreaAttributes:
         ldy AreaObjOffsetBuffer,x ;load offset for level object data saved in buffer
         iny                       ;load second byte
         lda (AreaData),y
         pha                       ;save in stack for now
         and #%01000000
         bne Alter2                ;branch if d6 is set
         pla
         pha                       ;pull and push offset to copy to A
         and #%00001111            ;mask out high nybble and store as
         sta TerrainControl        ;new terrain height type bits
         pla
         and #%00110000            ;pull and mask out all but d5 and d4
         lsr                       ;move bits to lower nybble and store
         lsr                       ;as new background scenery bits
         lsr
         lsr
         sta BackgroundScenery     ;then leave
         rts
Alter2:  pla
         and #%00000111            ;mask out all but 3 LSB
         cmp #$04                  ;if four or greater, set color control bits
         bcc SetFore               ;and nullify foreground scenery bits
         sta BackgroundColorCtrl
         lda #$00
SetFore: sta ForegroundScenery     ;otherwise set new foreground scenery bits
         rts

;--------------------------------

ScrollLockObject_Warp:
         ldx #$04            ;load value of 4 for game text routine as default
         lda WorldNumber     ;warp zone (4-3-2), then check world number
         beq WarpNum
         inx                 ;if world number > 1, increment for next warp zone (5)
         ldy AreaType        ;check area type
         dey
         bne WarpNum         ;if ground area type, increment for last warp zone
         inx                 ;(8-7-6) and move on
WarpNum: txa
         sta WarpZoneControl ;store number here to be used by warp zone routine
         jsr WriteGameText   ;print text and warp zone numbers
         lda #PiranhaPlant
         jsr KillEnemies     ;load identifier for piranha plants and do sub

ScrollLockObject:
      lda ScrollLock      ;invert scroll lock to turn it on
      eor #%00000001
      sta ScrollLock
      rts

;--------------------------------
;$00 - used to store enemy identifier in KillEnemies

KillEnemies:
           sta $00           ;store identifier here
           lda #$00
           ldx #$04          ;check for identifier in enemy object buffer
KillELoop: ldy Enemy_ID,x
           cpy $00           ;if not found, branch
           bne NoKillE
           sta Enemy_Flag,x  ;if found, deactivate enemy object flag
NoKillE:   dex               ;do this until all slots are checked
           bpl KillELoop
           rts

;--------------------------------

FrenzyIDData:
      .byte FlyCheepCheepFrenzy, BBill_CCheep_Frenzy, Stop_Frenzy

AreaFrenzy:  ldx $00               ;use area object identifier bit as offset
             lda FrenzyIDData-8,x  ;note that it starts at 8, thus weird address here
             ldy #$05
FreCompLoop: dey                   ;check regular slots of enemy object buffer
             bmi ExitAFrenzy       ;if all slots checked and enemy object not found, branch to store
             cmp Enemy_ID,y    ;check for enemy object in buffer versus frenzy object
             bne FreCompLoop
             lda #$00              ;if enemy object already present, nullify queue and leave
ExitAFrenzy: sta EnemyFrenzyQueue  ;store enemy into frenzy queue
             rts

;--------------------------------
;$06 - used by MushroomLedge to store length

AreaStyleObject:
      lda AreaStyle        ;load level object style and jump to the right sub
      jsr JumpEngine
      .word TreeLedge        ;also used for cloud type levels
      .word MushroomLedge
      .word BulletBillCannon

TreeLedge:
          jsr GetLrgObjAttrib     ;get row and length of green ledge
          lda AreaObjectLength,x  ;check length counter for expiration
          beq EndTreeL
          bpl MidTreeL
          tya
          sta AreaObjectLength,x  ;store lower nybble into buffer flag as length of ledge
          lda CurrentPageLoc
          ora CurrentColumnPos    ;are we at the start of the level?
          beq MidTreeL
          lda #$16                ;render start of tree ledge
          jmp NoUnder
MidTreeL: ldx $07
          lda #$17                ;render middle of tree ledge
          sta MetatileBuffer,x    ;note that this is also used if ledge position is
          lda #$4c                ;at the start of level for continuous effect
          jmp AllUnder            ;now render the part underneath
EndTreeL: lda #$18                ;render end of tree ledge
          jmp NoUnder

MushroomLedge:
          jsr ChkLrgObjLength        ;get shroom dimensions
          sty $06                    ;store length here for now
          bcc EndMushL
          lda AreaObjectLength,x     ;divide length by 2 and store elsewhere
          lsr
          sta MushroomLedgeHalfLen,x
          lda #$19                   ;render start of mushroom
          jmp NoUnder
EndMushL: lda #$1b                   ;if at the end, render end of mushroom
          ldy AreaObjectLength,x
          beq NoUnder
          lda MushroomLedgeHalfLen,x ;get divided length and store where length
          sta $06                    ;was stored originally
          ldx $07
          lda #$1a
          sta MetatileBuffer,x       ;render middle of mushroom
          cpy $06                    ;are we smack dab in the center?
          bne MushLExit              ;if not, branch to leave
          inx
          lda #$4f
          sta MetatileBuffer,x       ;render stem top of mushroom underneath the middle
          lda #$50
AllUnder: inx
          ldy #$0f                   ;set $0f to render all way down
          jmp RenderUnderPart       ;now render the stem of mushroom
NoUnder:  ldx $07                    ;load row of ledge
          ldy #$00                   ;set 0 for no bottom on this part
          jmp RenderUnderPart

;--------------------------------

;tiles used by pulleys and rope object
PulleyRopeMetatiles:
      .byte $42, $41, $43

PulleyRopeObject:
           jsr ChkLrgObjLength       ;get length of pulley/rope object
           ldy #$00                  ;initialize metatile offset
           bcs RenderPul             ;if starting, render left pulley
           iny
           lda AreaObjectLength,x    ;if not at the end, render rope
           bne RenderPul
           iny                       ;otherwise render right pulley
RenderPul: lda PulleyRopeMetatiles,y
           sta MetatileBuffer        ;render at the top of the screen
MushLExit: rts                       ;and leave

;--------------------------------
;$06 - used to store upper limit of rows for CastleObject

CastleMetatiles:
      .byte $00, $45, $45, $45, $00
      .byte $00, $48, $47, $46, $00
      .byte $45, $49, $49, $49, $45
      .byte $47, $47, $4a, $47, $47
      .byte $47, $47, $4b, $47, $47
      .byte $49, $49, $49, $49, $49
      .byte $47, $4a, $47, $4a, $47
      .byte $47, $4b, $47, $4b, $47
      .byte $47, $47, $47, $47, $47
      .byte $4a, $47, $4a, $47, $4a
      .byte $4b, $47, $4b, $47, $4b

CastleObject:
            jsr GetLrgObjAttrib      ;save lower nybble as starting row
            sty $07                  ;if starting row is above $0a, game will crash!!!
            ldy #$04
            jsr ChkLrgObjFixedLength ;load length of castle if not already loaded
            txa
            pha                      ;save obj buffer offset to stack
            ldy AreaObjectLength,x   ;use current length as offset for castle data
            ldx $07                  ;begin at starting row
            lda #$0b
            sta $06                  ;load upper limit of number of rows to print
CRendLoop:  lda CastleMetatiles,y    ;load current byte using offset
            sta MetatileBuffer,x
            inx                      ;store in buffer and increment buffer offset
            lda $06
            beq ChkCFloor            ;have we reached upper limit yet?
            iny                      ;if not, increment column-wise
            iny                      ;to byte in next row
            iny
            iny
            iny
            dec $06                  ;move closer to upper limit
ChkCFloor:  cpx #$0b                 ;have we reached the row just before floor?
            bne CRendLoop            ;if not, go back and do another row
            pla
            tax                      ;get obj buffer offset from before
            lda CurrentPageLoc
            beq ExitCastle           ;if we're at page 0, we do not need to do anything else
            lda AreaObjectLength,x   ;check length
            cmp #$01                 ;if length almost about to expire, put brick at floor
            beq PlayerStop
            ldy $07                  ;check starting row for tall castle ($00)
            bne NotTall
            cmp #$03                 ;if found, then check to see if we're at the second column
            beq PlayerStop
NotTall:    cmp #$02                 ;if not tall castle, check to see if we're at the third column
            bne ExitCastle           ;if we aren't and the castle is tall, don't create flag yet
            jsr GetAreaObjXPosition  ;otherwise, obtain and save horizontal pixel coordinate
            pha
            jsr FindEmptyEnemySlot   ;find an empty place on the enemy object buffer
            pla
            sta Enemy_X_Position,x   ;then write horizontal coordinate for star flag
            lda CurrentPageLoc
            sta Enemy_PageLoc,x      ;set page location for star flag
            lda #$01
            sta Enemy_Y_HighPos,x    ;set vertical high byte
            sta Enemy_Flag,x         ;set flag for buffer
            lda #$90
            sta Enemy_Y_Position,x   ;set vertical coordinate
            lda #StarFlagObject      ;set star flag value in buffer itself
            sta Enemy_ID,x
            rts
PlayerStop: ldy #$52                 ;put brick at floor to stop player at end of level
            sty MetatileBuffer+10    ;this is only done if we're on the second column
ExitCastle: rts

;--------------------------------

WaterPipe:
      jsr GetLrgObjAttrib     ;get row and lower nybble
      ldy AreaObjectLength,x  ;get length (residual code, water pipe is 1 col thick)
      ldx $07                 ;get row
      lda #$6b
      sta MetatileBuffer,x    ;draw something here and below it
      lda #$6c
      sta MetatileBuffer+1,x
      rts

;--------------------------------
;$05 - used to store length of vertical shaft in RenderSidewaysPipe
;$06 - used to store leftover horizontal length in RenderSidewaysPipe
; and vertical length in VerticalPipe and GetPipeHeight

IntroPipe:
               ldy #$03                 ;check if length set, if not set, set it
               jsr ChkLrgObjFixedLength
               ldy #$0a                 ;set fixed value and render the sideways part
               jsr RenderSidewaysPipe
               bcs NoBlankP             ;if carry flag set, not time to draw vertical pipe part
               ldx #$06                 ;blank everything above the vertical pipe part
VPipeSectLoop: lda #$00                 ;all the way to the top of the screen
               sta MetatileBuffer,x     ;because otherwise it will look like exit pipe
               dex
               bpl VPipeSectLoop
               lda VerticalPipeData,y   ;draw the end of the vertical pipe part
               sta MetatileBuffer+7
NoBlankP:      rts

SidePipeShaftData:
      .byte $15, $14  ;used to control whether or not vertical pipe shaft
      .byte $00, $00  ;is drawn, and if so, controls the metatile number
SidePipeTopPart:
      .byte $15, $1e  ;top part of sideways part of pipe
      .byte $1d, $1c
SidePipeBottomPart:
      .byte $15, $21  ;bottom part of sideways part of pipe
      .byte $20, $1f

ExitPipe:
      ldy #$03                 ;check if length set, if not set, set it
      jsr ChkLrgObjFixedLength
      jsr GetLrgObjAttrib      ;get vertical length, then plow on through RenderSidewaysPipe

RenderSidewaysPipe:
              dey                       ;decrement twice to make room for shaft at bottom
              dey                       ;and store here for now as vertical length
              sty $05
              ldy AreaObjectLength,x    ;get length left over and store here
              sty $06
              ldx $05                   ;get vertical length plus one, use as buffer offset
              inx
              lda SidePipeShaftData,y   ;check for value $00 based on horizontal offset
              cmp #$00
              beq DrawSidePart          ;if found, do not draw the vertical pipe shaft
              ldx #$00
              ldy $05                   ;init buffer offset and get vertical length
              jsr RenderUnderPart       ;and render vertical shaft using tile number in A
              clc                       ;clear carry flag to be used by IntroPipe
DrawSidePart: ldy $06                   ;render side pipe part at the bottom
              lda SidePipeTopPart,y
              sta MetatileBuffer,x      ;note that the pipe parts are stored
              lda SidePipeBottomPart,y  ;backwards horizontally
              sta MetatileBuffer+1,x
              rts

VerticalPipeData:
      .byte $11, $10 ;used by pipes that lead somewhere
      .byte $15, $14
      .byte $13, $12 ;used by decoration pipes
      .byte $15, $14

VerticalPipe:
          jsr GetPipeHeight
          lda $00                  ;check to see if value was nullified earlier
          beq WarpPipe             ;(if d3, the usage control bit of second byte, was set)
          iny
          iny
          iny
          iny                      ;add four if usage control bit was not set
WarpPipe: tya                      ;save value in stack
          pha
          lda AreaNumber
          ora WorldNumber          ;if at world 1-1, do not add piranha plant ever
          beq DrawPipe
          ldy AreaObjectLength,x   ;if on second column of pipe, branch
          beq DrawPipe             ;(because we only need to do this once)
          jsr FindEmptyEnemySlot   ;check for an empty moving data buffer space
          bcs DrawPipe             ;if not found, too many enemies, thus skip
          jsr GetAreaObjXPosition  ;get horizontal pixel coordinate
          clc
          adc #$08                 ;add eight to put the piranha plant in the center
          sta Enemy_X_Position,x   ;store as enemy's horizontal coordinate
          lda CurrentPageLoc       ;add carry to current page number
          adc #$00
          sta Enemy_PageLoc,x      ;store as enemy's page coordinate
          lda #$01
          sta Enemy_Y_HighPos,x
          sta Enemy_Flag,x         ;activate enemy flag
          jsr GetAreaObjYPosition  ;get piranha plant's vertical coordinate and store here
          sta Enemy_Y_Position,x
          lda #PiranhaPlant        ;write piranha plant's value into buffer
          sta Enemy_ID,x
          jsr InitPiranhaPlant
DrawPipe: pla                      ;get value saved earlier and use as Y
          tay
          ldx $07                  ;get buffer offset
          lda VerticalPipeData,y   ;draw the appropriate pipe with the Y we loaded earlier
          sta MetatileBuffer,x     ;render the top of the pipe
          inx
          lda VerticalPipeData+2,y ;render the rest of the pipe
          ldy $06                  ;subtract one from length and render the part underneath
          dey
          jmp RenderUnderPart

GetPipeHeight:
      ldy #$01       ;check for length loaded, if not, load
      jsr ChkLrgObjFixedLength ;pipe length of 2 (horizontal)
      jsr GetLrgObjAttrib
      tya            ;get saved lower nybble as height
      and #$07       ;save only the three lower bits as
      sta $06        ;vertical length, then load Y with
      ldy AreaObjectLength,x    ;length left over
      rts

FindEmptyEnemySlot:
              ldx #$00          ;start at first enemy slot
EmptyChkLoop: clc               ;clear carry flag by default
              lda Enemy_Flag,x  ;check enemy buffer for nonzero
              beq ExitEmptyChk  ;if zero, leave
              inx
              cpx #$05          ;if nonzero, check next value
              bne EmptyChkLoop
ExitEmptyChk: rts               ;if all values nonzero, carry flag is set
