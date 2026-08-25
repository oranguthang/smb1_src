;-------------------------------------------------------------------------------------
;$00 - used to store player's vertical offscreen bits

PlayerGfxTblOffsets:
      .byte $20, $28, $c8, $18, $00, $40, $50, $58
      .byte $80, $88, $b8, $78, $60, $a0, $b0, $b8

;tiles arranged in order, 2 tiles per row, top to bottom

PlayerGraphicsTable:
;big player table
      .byte $00, $01, $02, $03, $04, $05, $06, $07 ;walking frame 1
      .byte $08, $09, $0a, $0b, $0c, $0d, $0e, $0f ;        frame 2
      .byte $10, $11, $12, $13, $14, $15, $16, $17 ;        frame 3
      .byte $18, $19, $1a, $1b, $1c, $1d, $1e, $1f ;skidding
      .byte $20, $21, $22, $23, $24, $25, $26, $27 ;jumping
      .byte $08, $09, $28, $29, $2a, $2b, $2c, $2d ;swimming frame 1
      .byte $08, $09, $0a, $0b, $0c, $30, $2c, $2d ;         frame 2
      .byte $08, $09, $0a, $0b, $2e, $2f, $2c, $2d ;         frame 3
      .byte $08, $09, $28, $29, $2a, $2b, $5c, $5d ;climbing frame 1
      .byte $08, $09, $0a, $0b, $0c, $0d, $5e, $5f ;         frame 2
      .byte $fc, $fc, $08, $09, $58, $59, $5a, $5a ;crouching
      .byte $08, $09, $28, $29, $2a, $2b, $0e, $0f ;fireball throwing

;small player table
      .byte $fc, $fc, $fc, $fc, $32, $33, $34, $35 ;walking frame 1
      .byte $fc, $fc, $fc, $fc, $36, $37, $38, $39 ;        frame 2
      .byte $fc, $fc, $fc, $fc, $3a, $37, $3b, $3c ;        frame 3
      .byte $fc, $fc, $fc, $fc, $3d, $3e, $3f, $40 ;skidding
      .byte $fc, $fc, $fc, $fc, $32, $41, $42, $43 ;jumping
      .byte $fc, $fc, $fc, $fc, $32, $33, $44, $45 ;swimming frame 1
      .byte $fc, $fc, $fc, $fc, $32, $33, $44, $47 ;         frame 2
      .byte $fc, $fc, $fc, $fc, $32, $33, $48, $49 ;         frame 3
      .byte $fc, $fc, $fc, $fc, $32, $33, $90, $91 ;climbing frame 1
      .byte $fc, $fc, $fc, $fc, $3a, $37, $92, $93 ;         frame 2
      .byte $fc, $fc, $fc, $fc, $9e, $9e, $9f, $9f ;killed

;used by both player sizes
      .byte $fc, $fc, $fc, $fc, $3a, $37, $4f, $4f ;small player standing
      .byte $fc, $fc, $00, $01, $4c, $4d, $4e, $4e ;intermediate grow frame
      .byte $00, $01, $4c, $4d, $4a, $4a, $4b, $4b ;big player standing

SwimKickTileNum:
      .byte $31, $46

PlayerGfxHandler:
        lda InjuryTimer             ;if player's injured invincibility timer
        beq CntPl                   ;not set, skip checkpoint and continue code
        lda FrameCounter
        lsr                         ;otherwise check frame counter and branch
        bcs ExPGH                   ;to leave on every other frame (when d0 is set)
CntPl:  lda GameEngineSubroutine    ;if executing specific game engine routine,
        cmp #$0b                    ;branch ahead to some other part
        beq PlayerKilled
        lda PlayerChangeSizeFlag    ;if grow/shrink flag set
        bne DoChangeSize            ;then branch to some other code
        ldy SwimmingFlag            ;if swimming flag set, branch to
        beq FindPlayerAction        ;different part, do not return
        lda Player_State
        cmp #$00                    ;if player status normal,
        beq FindPlayerAction        ;branch and do not return
        jsr FindPlayerAction        ;otherwise jump and return
        lda FrameCounter
        and #%00000100              ;check frame counter for d2 set (8 frames every
        bne ExPGH                   ;eighth frame), and branch if set to leave
        tax                         ;initialize X to zero
        ldy Player_SprDataOffset    ;get player sprite data offset
        lda PlayerFacingDir         ;get player's facing direction
        lsr
        bcs SwimKT                  ;if player facing to the right, use current offset
        iny
        iny                         ;otherwise move to next OAM data
        iny
        iny
SwimKT: lda PlayerSize              ;check player's size
        beq BigKTS                  ;if big, use first tile
        lda Sprite_Tilenumber+24,y  ;check tile number of seventh/eighth sprite
        cmp SwimTileRepOffset       ;against tile number in player graphics table
        beq ExPGH                   ;if spr7/spr8 tile number = value, branch to leave
        inx                         ;otherwise increment X for second tile
BigKTS: lda SwimKickTileNum,x       ;overwrite tile number in sprite 7/8
        sta Sprite_Tilenumber+24,y  ;to animate player's feet when swimming
ExPGH:  rts                         ;then leave

FindPlayerAction:
      jsr ProcessPlayerAction       ;find proper offset to graphics table by player's actions
      jmp PlayerGfxProcessing       ;draw player, then process for fireball throwing

DoChangeSize:
      jsr HandleChangeSize          ;find proper offset to graphics table for grow/shrink
      jmp PlayerGfxProcessing       ;draw player, then process for fireball throwing

PlayerKilled:
      ldy #$0e                      ;load offset for player killed
      lda PlayerGfxTblOffsets,y     ;get offset to graphics table

PlayerGfxProcessing:
       sta PlayerGfxOffset           ;store offset to graphics table here
       lda #$04
       jsr RenderPlayerSub           ;draw player based on offset loaded
       jsr ChkForPlayerAttrib        ;set horizontal flip bits as necessary
       lda FireballThrowingTimer
       beq PlayerOffscreenChk        ;if fireball throw timer not set, skip to the end
       ldy #$00                      ;set value to initialize by default
       lda PlayerAnimTimer           ;get animation frame timer
       cmp FireballThrowingTimer     ;compare to fireball throw timer
       sty FireballThrowingTimer     ;initialize fireball throw timer
       bcs PlayerOffscreenChk        ;if animation frame timer => fireball throw timer skip to end
       sta FireballThrowingTimer     ;otherwise store animation timer into fireball throw timer
       ldy #$07                      ;load offset for throwing
       lda PlayerGfxTblOffsets,y     ;get offset to graphics table
       sta PlayerGfxOffset           ;store it for use later
       ldy #$04                      ;set to update four sprite rows by default
       lda Player_X_Speed
       ora Left_Right_Buttons        ;check for horizontal speed or left/right button press
       beq SUpdR                     ;if no speed or button press, branch using set value in Y
       dey                           ;otherwise set to update only three sprite rows
SUpdR: tya                           ;save in A for use
       jsr RenderPlayerSub           ;in sub, draw player object again

PlayerOffscreenChk:
           lda Player_OffscreenBits      ;get player's offscreen bits
           lsr
           lsr                           ;move vertical bits to low nybble
           lsr
           lsr
           sta $00                       ;store here
           ldx #$03                      ;check all four rows of player sprites
           lda Player_SprDataOffset      ;get player's sprite data offset
           clc
           adc #$18                      ;add 24 bytes to start at bottom row
           tay                           ;set as offset here
PROfsLoop: lda #$f8                      ;load offscreen Y coordinate just in case
           lsr $00                       ;shift bit into carry
           bcc NPROffscr                 ;if bit not set, skip, do not move sprites
           jsr DumpTwoSpr                ;otherwise dump offscreen Y coordinate into sprite data
NPROffscr: tya
           sec                           ;subtract eight bytes to do
           sbc #$08                      ;next row up
           tay
           dex                           ;decrement row counter
           bpl PROfsLoop                 ;do this until all sprite rows are checked
           rts                           ;then we are done!

;-------------------------------------------------------------------------------------

IntermediatePlayerData:
        .byte $58, $01, $00, $60, $ff, $04

DrawPlayer_Intermediate:
          ldx #$05                       ;store data into zero page memory
PIntLoop: lda IntermediatePlayerData,x   ;load data to display player as he always
          sta $02,x                      ;appears on world/lives display
          dex
          bpl PIntLoop                   ;do this until all data is loaded
          ldx #$b8                       ;load offset for small standing
          ldy #$04                       ;load sprite data offset
          jsr DrawPlayerLoop             ;draw player accordingly
          lda Sprite_Attributes+36       ;get empty sprite attributes
          ora #%01000000                 ;set horizontal flip bit for bottom-right sprite
          sta Sprite_Attributes+32       ;store and leave
          rts

;-------------------------------------------------------------------------------------
;$00-$01 - used to hold tile numbers, $00 also used to hold upper extent of animation frames
;$02 - vertical position
;$03 - facing direction, used as horizontal flip control
;$04 - attributes
;$05 - horizontal position
;$07 - number of rows to draw
;these also used in IntermediatePlayerData

RenderPlayerSub:
        sta $07                      ;store number of rows of sprites to draw
        lda Player_Rel_XPos
        sta Player_Pos_ForScroll     ;store player's relative horizontal position
        sta $05                      ;store it here also
        lda Player_Rel_YPos
        sta $02                      ;store player's vertical position
        lda PlayerFacingDir
        sta $03                      ;store player's facing direction
        lda Player_SprAttrib
        sta $04                      ;store player's sprite attributes
        ldx PlayerGfxOffset          ;load graphics table offset
        ldy Player_SprDataOffset     ;get player's sprite data offset

DrawPlayerLoop:
        lda PlayerGraphicsTable,x    ;load player's left side
        sta $00
        lda PlayerGraphicsTable+1,x  ;now load right side
        jsr DrawOneSpriteRow
        dec $07                      ;decrement rows of sprites to draw
        bne DrawPlayerLoop           ;do this until all rows are drawn
        rts

ProcessPlayerAction:
        lda Player_State      ;get player's state
        cmp #$03
        beq ActionClimbing    ;if climbing, branch here
        cmp #$02
        beq ActionFalling     ;if falling, branch here
        cmp #$01
        bne ProcOnGroundActs  ;if not jumping, branch here
        lda SwimmingFlag
        bne ActionSwimming    ;if swimming flag set, branch elsewhere
        ldy #$06              ;load offset for crouching
        lda CrouchingFlag     ;get crouching flag
        bne NonAnimatedActs   ;if set, branch to get offset for graphics table
        ldy #$00              ;otherwise load offset for jumping
        jmp NonAnimatedActs   ;go to get offset to graphics table

ProcOnGroundActs:
        ldy #$06                   ;load offset for crouching
        lda CrouchingFlag          ;get crouching flag
        bne NonAnimatedActs        ;if set, branch to get offset for graphics table
        ldy #$02                   ;load offset for standing
        lda Player_X_Speed         ;check player's horizontal speed
        ora Left_Right_Buttons     ;and left/right controller bits
        beq NonAnimatedActs        ;if no speed or buttons pressed, use standing offset
        lda Player_XSpeedAbsolute  ;load walking/running speed
        cmp #$09
        bcc ActionWalkRun          ;if less than a certain amount, branch, too slow to skid
        lda Player_MovingDir       ;otherwise check to see if moving direction
        and PlayerFacingDir        ;and facing direction are the same
        bne ActionWalkRun          ;if moving direction = facing direction, branch, don't skid
        iny                        ;otherwise increment to skid offset ($03)

NonAnimatedActs:
        jsr GetGfxOffsetAdder      ;do a sub here to get offset adder for graphics table
        lda #$00
        sta PlayerAnimCtrl         ;initialize animation frame control
        lda PlayerGfxTblOffsets,y  ;load offset to graphics table using size as offset
        rts

ActionFalling:
        ldy #$04                  ;load offset for walking/running
        jsr GetGfxOffsetAdder     ;get offset to graphics table
        jmp GetCurrentAnimOffset  ;execute instructions for falling state

ActionWalkRun:
        ldy #$04               ;load offset for walking/running
        jsr GetGfxOffsetAdder  ;get offset to graphics table
        jmp FourFrameExtent    ;execute instructions for normal state

ActionClimbing:
        ldy #$05               ;load offset for climbing
        lda Player_Y_Speed     ;check player's vertical speed
        beq NonAnimatedActs    ;if no speed, branch, use offset as-is
        jsr GetGfxOffsetAdder  ;otherwise get offset for graphics table
        jmp ThreeFrameExtent   ;then skip ahead to more code

ActionSwimming:
        ldy #$01               ;load offset for swimming
        jsr GetGfxOffsetAdder
        lda JumpSwimTimer      ;check jump/swim timer
        ora PlayerAnimCtrl     ;and animation frame control
        bne FourFrameExtent    ;if any one of these set, branch ahead
        lda A_B_Buttons
        asl                    ;check for A button pressed
        bcs FourFrameExtent    ;branch to same place if A button pressed

GetCurrentAnimOffset:
        lda PlayerAnimCtrl         ;get animation frame control
        jmp GetOffsetFromAnimCtrl  ;jump to get proper offset to graphics table

FourFrameExtent:
        lda #$03              ;load upper extent for frame control
        jmp AnimationControl  ;jump to get offset and animate player object

ThreeFrameExtent:
        lda #$02              ;load upper extent for frame control for climbing

AnimationControl:
          sta $00                   ;store upper extent here
          jsr GetCurrentAnimOffset  ;get proper offset to graphics table
          pha                       ;save offset to stack
          lda PlayerAnimTimer       ;load animation frame timer
          bne ExAnimC               ;branch if not expired
          lda PlayerAnimTimerSet    ;get animation frame timer amount
          sta PlayerAnimTimer       ;and set timer accordingly
          lda PlayerAnimCtrl
          clc                       ;add one to animation frame control
          adc #$01
          cmp $00                   ;compare to upper extent
          bcc SetAnimC              ;if frame control + 1 < upper extent, use as next
          lda #$00                  ;otherwise initialize frame control
SetAnimC: sta PlayerAnimCtrl        ;store as new animation frame control
ExAnimC:  pla                       ;get offset to graphics table from stack and leave
          rts

GetGfxOffsetAdder:
        lda PlayerSize  ;get player's size
        beq SzOfs       ;if player big, use current offset as-is
        tya             ;for big player
        clc             ;otherwise add eight bytes to offset
        adc #$08        ;for small player
        tay
SzOfs:  rts             ;go back

ChangeSizeOffsetAdder:
        .byte $00, $01, $00, $01, $00, $01, $02, $00, $01, $02
        .byte $02, $00, $02, $00, $02, $00, $02, $00, $02, $00

HandleChangeSize:
         ldy PlayerAnimCtrl           ;get animation frame control
         lda FrameCounter
         and #%00000011               ;get frame counter and execute this code every
         bne GorSLog                  ;fourth frame, otherwise branch ahead
         iny                          ;increment frame control
         cpy #$0a                     ;check for preset upper extent
         bcc CSzNext                  ;if not there yet, skip ahead to use
         ldy #$00                     ;otherwise initialize both grow/shrink flag
         sty PlayerChangeSizeFlag     ;and animation frame control
CSzNext: sty PlayerAnimCtrl           ;store proper frame control
GorSLog: lda PlayerSize               ;get player's size
         bne ShrinkPlayer             ;if player small, skip ahead to next part
         lda ChangeSizeOffsetAdder,y  ;get offset adder based on frame control as offset
         ldy #$0f                     ;load offset for player growing

GetOffsetFromAnimCtrl:
        asl                        ;multiply animation frame control
        asl                        ;by eight to get proper amount
        asl                        ;to add to our offset
        adc PlayerGfxTblOffsets,y  ;add to offset to graphics table
        rts                        ;and return with result in A

ShrinkPlayer:
        tya                          ;add ten bytes to frame control as offset
        clc
        adc #$0a                     ;this thing apparently uses two of the swimming frames
        tax                          ;to draw the player shrinking
        ldy #$09                     ;load offset for small player swimming
        lda ChangeSizeOffsetAdder,x  ;get what would normally be offset adder
        bne ShrPlF                   ;and branch to use offset if nonzero
        ldy #$01                     ;otherwise load offset for big player swimming
ShrPlF: lda PlayerGfxTblOffsets,y    ;get offset to graphics table based on offset loaded
        rts                          ;and leave

ChkForPlayerAttrib:
           ldy Player_SprDataOffset    ;get sprite data offset
           lda GameEngineSubroutine
           cmp #$0b                    ;if executing specific game engine routine,
           beq KilledAtt               ;branch to change third and fourth row OAM attributes
           lda PlayerGfxOffset         ;get graphics table offset
           cmp #$50
           beq C_S_IGAtt               ;if crouch offset, either standing offset,
           cmp #$b8                    ;or intermediate growing offset,
           beq C_S_IGAtt               ;go ahead and execute code to change
           cmp #$c0                    ;fourth row OAM attributes only
           beq C_S_IGAtt
           cmp #$c8
           bne ExPlyrAt                ;if none of these, branch to leave
KilledAtt: lda Sprite_Attributes+16,y
           and #%00111111              ;mask out horizontal and vertical flip bits
           sta Sprite_Attributes+16,y  ;for third row sprites and save
           lda Sprite_Attributes+20,y
           and #%00111111
           ora #%01000000              ;set horizontal flip bit for second
           sta Sprite_Attributes+20,y  ;sprite in the third row
C_S_IGAtt: lda Sprite_Attributes+24,y
           and #%00111111              ;mask out horizontal and vertical flip bits
           sta Sprite_Attributes+24,y  ;for fourth row sprites and save
           lda Sprite_Attributes+28,y
           and #%00111111
           ora #%01000000              ;set horizontal flip bit for second
           sta Sprite_Attributes+28,y  ;sprite in the fourth row
ExPlyrAt:  rts                         ;leave
