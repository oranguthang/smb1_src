;--------------------------------
;$00 - used as counter for firebar parts
;$01 - used for oscillated high byte of spin state or to hold horizontal adder
;$02 - used for oscillated high byte of spin state or to hold vertical adder
;$03 - used for mirror data
;$04 - used to store player's sprite 1 X coordinate
;$05 - used to evaluate mirror data
;$06 - used to store either screen X coordinate or sprite data offset
;$07 - used to store screen Y coordinate
;$ed - used to hold maximum length of firebar
;$ef - used to hold high byte of spinstate

;horizontal adder is at first byte + high byte of spinstate,
;vertical adder is same + 8 bytes, two's compliment
;if greater than $08 for proper oscillation
FirebarPosLookupTbl:
      .byte $00, $01, $03, $04, $05, $06, $07, $07, $08
      .byte $00, $03, $06, $09, $0b, $0d, $0e, $0f, $10
      .byte $00, $04, $09, $0d, $10, $13, $16, $17, $18
      .byte $00, $06, $0c, $12, $16, $1a, $1d, $1f, $20
      .byte $00, $07, $0f, $16, $1c, $21, $25, $27, $28
      .byte $00, $09, $12, $1b, $21, $27, $2c, $2f, $30
      .byte $00, $0b, $15, $1f, $27, $2e, $33, $37, $38
      .byte $00, $0c, $18, $24, $2d, $35, $3b, $3e, $40
      .byte $00, $0e, $1b, $28, $32, $3b, $42, $46, $48
      .byte $00, $0f, $1f, $2d, $38, $42, $4a, $4e, $50
      .byte $00, $11, $22, $31, $3e, $49, $51, $56, $58

FirebarMirrorData:
      .byte $01, $03, $02, $00

FirebarTblOffsets:
      .byte $00, $09, $12, $1b, $24, $2d
      .byte $36, $3f, $48, $51, $5a, $63

FirebarYPos:
      .byte $0c, $18

ProcFirebar:
          jsr GetEnemyOffscreenBits   ;get offscreen information
          lda Enemy_OffscreenBits     ;check for d3 set
          and #%00001000              ;if so, branch to leave
          bne SkipFBar
          lda TimerControl            ;if master timer control set, branch
          bne SusFbar                 ;ahead of this part
          lda FirebarSpinSpeed,x      ;load spinning speed of firebar
          jsr FirebarSpin             ;modify current spinstate
          and #%00011111              ;mask out all but 5 LSB
          sta FirebarSpinState_High,x ;and store as new high byte of spinstate
SusFbar:  lda FirebarSpinState_High,x ;get high byte of spinstate
          ldy Enemy_ID,x              ;check enemy identifier
          cpy #$1f
          bcc SetupGFB                ;if < $1f (long firebar), branch
          cmp #$08                    ;check high byte of spinstate
          beq SkpFSte                 ;if eight, branch to change
          cmp #$18
          bne SetupGFB                ;if not at twenty-four branch to not change
SkpFSte:  clc
          adc #$01                    ;add one to spinning thing to avoid horizontal state
          sta FirebarSpinState_High,x
SetupGFB: sta $ef                     ;save high byte of spinning thing, modified or otherwise
          jsr RelativeEnemyPosition   ;get relative coordinates to screen
          jsr GetFirebarPosition      ;do a sub here (residual, too early to be used now)
          ldy Enemy_SprDataOffset,x   ;get OAM data offset
          lda Enemy_Rel_YPos          ;get relative vertical coordinate
          sta Sprite_Y_Position,y     ;store as Y in OAM data
          sta $07                     ;also save here
          lda Enemy_Rel_XPos          ;get relative horizontal coordinate
          sta Sprite_X_Position,y     ;store as X in OAM data
          sta $06                     ;also save here
          lda #$01
          sta $00                     ;set $01 value here (not necessary)
          jsr FirebarCollision        ;draw fireball part and do collision detection
          ldy #$05                    ;load value for short firebars by default
          lda Enemy_ID,x
          cmp #$1f                    ;are we doing a long firebar?
          bcc SetMFbar                ;no, branch then
          ldy #$0b                    ;otherwise load value for long firebars
SetMFbar: sty $ed                     ;store maximum value for length of firebars
          lda #$00
          sta $00                     ;initialize counter here
DrawFbar: lda $ef                     ;load high byte of spinstate
          jsr GetFirebarPosition      ;get fireball position data depending on firebar part
          jsr DrawFirebar_Collision   ;position it properly, draw it and do collision detection
          lda $00                     ;check which firebar part
          cmp #$04
          bne NextFbar
          ldy DuplicateObj_Offset     ;if we arrive at fifth firebar part,
          lda Enemy_SprDataOffset,y   ;get offset from long firebar and load OAM data offset
          sta $06                     ;using long firebar offset, then store as new one here
NextFbar: inc $00                     ;move onto the next firebar part
          lda $00
          cmp $ed                     ;if we end up at the maximum part, go on and leave
          bcc DrawFbar                ;otherwise go back and do another
SkipFBar: rts

DrawFirebar_Collision:
         lda $03                  ;store mirror data elsewhere
         sta $05
         ldy $06                  ;load OAM data offset for firebar
         lda $01                  ;load horizontal adder we got from position loader
         lsr $05                  ;shift LSB of mirror data
         bcs AddHA                ;if carry was set, skip this part
         eor #$ff
         adc #$01                 ;otherwise get two's compliment of horizontal adder
AddHA:   clc                      ;add horizontal coordinate relative to screen to
         adc Enemy_Rel_XPos       ;horizontal adder, modified or otherwise
         sta Sprite_X_Position,y  ;store as X coordinate here
         sta $06                  ;store here for now, note offset is saved in Y still
         cmp Enemy_Rel_XPos       ;compare X coordinate of sprite to original X of firebar
         bcs SubtR1               ;if sprite coordinate => original coordinate, branch
         lda Enemy_Rel_XPos
         sec                      ;otherwise subtract sprite X from the
         sbc $06                  ;original one and skip this part
         jmp ChkFOfs
SubtR1:  sec                      ;subtract original X from the
         sbc Enemy_Rel_XPos       ;current sprite X
ChkFOfs: cmp #$59                 ;if difference of coordinates within a certain range,
         bcc VAHandl              ;continue by handling vertical adder
         lda #$f8                 ;otherwise, load offscreen Y coordinate
         bne SetVFbr              ;and unconditionally branch to move sprite offscreen
VAHandl: lda Enemy_Rel_YPos       ;if vertical relative coordinate offscreen,
         cmp #$f8                 ;skip ahead of this part and write into sprite Y coordinate
         beq SetVFbr
         lda $02                  ;load vertical adder we got from position loader
         lsr $05                  ;shift LSB of mirror data one more time
         bcs AddVA                ;if carry was set, skip this part
         eor #$ff
         adc #$01                 ;otherwise get two's compliment of second part
AddVA:   clc                      ;add vertical coordinate relative to screen to
         adc Enemy_Rel_YPos       ;the second data, modified or otherwise
SetVFbr: sta Sprite_Y_Position,y  ;store as Y coordinate here
         sta $07                  ;also store here for now

FirebarCollision:
         jsr DrawFirebar          ;run sub here to draw current tile of firebar
         tya                      ;return OAM data offset and save
         pha                      ;to the stack for now
         lda StarInvincibleTimer  ;if star mario invincibility timer
         ora TimerControl         ;or master timer controls set
         bne NoColFB              ;then skip all of this
         sta $05                  ;otherwise initialize counter
         ldy Player_Y_HighPos
         dey                      ;if player's vertical high byte offscreen,
         bne NoColFB              ;skip all of this
         ldy Player_Y_Position    ;get player's vertical position
         lda PlayerSize           ;get player's size
         bne AdjSm                ;if player small, branch to alter variables
         lda CrouchingFlag
         beq BigJp                ;if player big and not crouching, jump ahead
AdjSm:   inc $05                  ;if small or big but crouching, execute this part
         inc $05                  ;first increment our counter twice (setting $02 as flag)
         tya
         clc                      ;then add 24 pixels to the player's
         adc #$18                 ;vertical coordinate
         tay
BigJp:   tya                      ;get vertical coordinate, altered or otherwise, from Y
FBCLoop: sec                      ;subtract vertical position of firebar
         sbc $07                  ;from the vertical coordinate of the player
         bpl ChkVFBD              ;if player lower on the screen than firebar,
         eor #$ff                 ;skip two's compliment part
         clc                      ;otherwise get two's compliment
         adc #$01
ChkVFBD: cmp #$08                 ;if difference => 8 pixels, skip ahead of this part
         bcs Chk2Ofs
         lda $06                  ;if firebar on far right on the screen, skip this,
         cmp #$f0                 ;because, really, what's the point?
         bcs Chk2Ofs
         lda Sprite_X_Position+4  ;get OAM X coordinate for sprite #1
         clc
         adc #$04                 ;add four pixels
         sta $04                  ;store here
         sec                      ;subtract horizontal coordinate of firebar
         sbc $06                  ;from the X coordinate of player's sprite 1
         bpl ChkFBCl              ;if modded X coordinate to the right of firebar
         eor #$ff                 ;skip two's compliment part
         clc                      ;otherwise get two's compliment
         adc #$01
ChkFBCl: cmp #$08                 ;if difference < 8 pixels, collision, thus branch
         bcc ChgSDir              ;to process
Chk2Ofs: lda $05                  ;if value of $02 was set earlier for whatever reason,
         cmp #$02                 ;branch to increment OAM offset and leave, no collision
         beq NoColFB
         ldy $05                  ;otherwise get temp here and use as offset
         lda Player_Y_Position
         clc
         adc FirebarYPos,y        ;add value loaded with offset to player's vertical coordinate
         inc $05                  ;then increment temp and jump back
         jmp FBCLoop
ChgSDir: ldx #$01                 ;set movement direction by default
         lda $04                  ;if OAM X coordinate of player's sprite 1
         cmp $06                  ;is greater than horizontal coordinate of firebar
         bcs SetSDir              ;then do not alter movement direction
         inx                      ;otherwise increment it
SetSDir: stx Enemy_MovingDir      ;store movement direction here
         ldx #$00
         lda $00                  ;save value written to $00 to stack
         pha
         jsr InjurePlayer         ;perform sub to hurt or kill player
         pla
         sta $00                  ;get value of $00 from stack
NoColFB: pla                      ;get OAM data offset
         clc                      ;add four to it and save
         adc #$04
         sta $06
         ldx ObjectOffset         ;get enemy object buffer offset and leave
         rts

GetFirebarPosition:
           pha                        ;save high byte of spinstate to the stack
           and #%00001111             ;mask out low nybble
           cmp #$09
           bcc GetHAdder              ;if lower than $09, branch ahead
           eor #%00001111             ;otherwise get two's compliment to oscillate
           clc
           adc #$01
GetHAdder: sta $01                    ;store result, modified or not, here
           ldy $00                    ;load number of firebar ball where we're at
           lda FirebarTblOffsets,y    ;load offset to firebar position data
           clc
           adc $01                    ;add oscillated high byte of spinstate
           tay                        ;to offset here and use as new offset
           lda FirebarPosLookupTbl,y  ;get data here and store as horizontal adder
           sta $01
           pla                        ;pull whatever was in A from the stack
           pha                        ;save it again because we still need it
           clc
           adc #$08                   ;add eight this time, to get vertical adder
           and #%00001111             ;mask out high nybble
           cmp #$09                   ;if lower than $09, branch ahead
           bcc GetVAdder
           eor #%00001111             ;otherwise get two's compliment
           clc
           adc #$01
GetVAdder: sta $02                    ;store result here
           ldy $00
           lda FirebarTblOffsets,y    ;load offset to firebar position data again
           clc
           adc $02                    ;this time add value in $02 to offset here and use as offset
           tay
           lda FirebarPosLookupTbl,y  ;get data here and store as vertica adder
           sta $02
           pla                        ;pull out whatever was in A one last time
           lsr                        ;divide by eight or shift three to the right
           lsr
           lsr
           tay                        ;use as offset
           lda FirebarMirrorData,y    ;load mirroring data here
           sta $03                    ;store
           rts

;--------------------------------

PRandomSubtracter:
      .byte $f8, $a0, $70, $bd, $00

FlyCCBPriority:
      .byte $20, $20, $20, $00, $00

MoveFlyingCheepCheep:
        lda Enemy_State,x          ;check cheep-cheep's enemy state
        and #%00100000             ;for d5 set
        beq FlyCC                  ;branch to continue code if not set
        lda #$00
        sta Enemy_SprAttrib,x      ;otherwise clear sprite attributes
        jmp MoveJ_EnemyVertically  ;and jump to move defeated cheep-cheep downwards
FlyCC:  jsr MoveEnemyHorizontally  ;move cheep-cheep horizontally based on speed and force
        ldy #$0d                   ;set vertical movement amount
        lda #$05                   ;set maximum speed
        jsr SetXMoveAmt            ;branch to impose gravity on flying cheep-cheep
        lda Enemy_Y_MoveForce,x
        lsr                        ;get vertical movement force and
        lsr                        ;move high nybble to low
        lsr
        lsr
        tay                        ;save as offset (note this tends to go into reach of code)
        lda Enemy_Y_Position,x     ;get vertical position
        sec                        ;subtract pseudorandom value based on offset from position
        sbc PRandomSubtracter,y
        bpl AddCCF                  ;if result within top half of screen, skip this part
        eor #$ff
        clc                        ;otherwise get two's compliment
        adc #$01
AddCCF: cmp #$08                   ;if result or two's compliment greater than eight,
        bcs BPGet                  ;skip to the end without changing movement force
        lda Enemy_Y_MoveForce,x
        clc
        adc #$10                   ;otherwise add to it
        sta Enemy_Y_MoveForce,x
        lsr                        ;move high nybble to low again
        lsr
        lsr
        lsr
        tay
BPGet:  lda FlyCCBPriority,y       ;load bg priority data and store (this is very likely
        sta Enemy_SprAttrib,x      ;broken or residual code, value is overwritten before
        rts                        ;drawing it next frame), then leave

;--------------------------------
;$00 - used to hold horizontal difference
;$01-$03 - used to hold difference adjusters

LakituDiffAdj:
      .byte $15, $30, $40

MoveLakitu:
         lda Enemy_State,x          ;check lakitu's enemy state
         and #%00100000             ;for d5 set
         beq ChkLS                  ;if not set, continue with code
         jmp MoveD_EnemyVertically  ;otherwise jump to move defeated lakitu downwards
ChkLS:   lda Enemy_State,x          ;if lakitu's enemy state not set at all,
         beq Fr12S                  ;go ahead and continue with code
         lda #$00
         sta LakituMoveDirection,x  ;otherwise initialize moving direction to move to left
         sta EnemyFrenzyBuffer      ;initialize frenzy buffer
         lda #$10
         bne SetLSpd                ;load horizontal speed and do unconditional branch
Fr12S:   lda #Spiny
         sta EnemyFrenzyBuffer      ;set spiny identifier in frenzy buffer
         ldy #$02
LdLDa:   lda LakituDiffAdj,y        ;load values
         sta $0001,y                ;store in zero page
         dey
         bpl LdLDa                  ;do this until all values are stired
         jsr PlayerLakituDiff       ;execute sub to set speed and create spinys
SetLSpd: sta LakituMoveSpeed,x      ;set movement speed returned from sub
         ldy #$01                   ;set moving direction to right by default
         lda LakituMoveDirection,x
         and #$01                   ;get LSB of moving direction
         bne SetLMov                ;if set, branch to the end to use moving direction
         lda LakituMoveSpeed,x
         eor #$ff                   ;get two's compliment of moving speed
         clc
         adc #$01
         sta LakituMoveSpeed,x      ;store as new moving speed
         iny                        ;increment moving direction to left
SetLMov: sty Enemy_MovingDir,x      ;store moving direction
         jmp MoveEnemyHorizontally  ;move lakitu horizontally

PlayerLakituDiff:
           ldy #$00                   ;set Y for default value
           jsr PlayerEnemyDiff        ;get horizontal difference between enemy and player
           bpl ChkLakDif              ;branch if enemy is to the right of the player
           iny                        ;increment Y for left of player
           lda $00
           eor #$ff                   ;get two's compliment of low byte of horizontal difference
           clc
           adc #$01                   ;store two's compliment as horizontal difference
           sta $00
ChkLakDif: lda $00                    ;get low byte of horizontal difference
           cmp #$3c                   ;if within a certain distance of player, branch
           bcc ChkPSpeed
           lda #$3c                   ;otherwise set maximum distance
           sta $00
           lda Enemy_ID,x             ;check if lakitu is in our current enemy slot
           cmp #Lakitu
           bne ChkPSpeed              ;if not, branch elsewhere
           tya                        ;compare contents of Y, now in A
           cmp LakituMoveDirection,x  ;to what is being used as horizontal movement direction
           beq ChkPSpeed              ;if moving toward the player, branch, do not alter
           lda LakituMoveDirection,x  ;if moving to the left beyond maximum distance,
           beq SetLMovD               ;branch and alter without delay
           dec LakituMoveSpeed,x      ;decrement horizontal speed
           lda LakituMoveSpeed,x      ;if horizontal speed not yet at zero, branch to leave
           bne ExMoveLak
SetLMovD:  tya                        ;set horizontal direction depending on horizontal
           sta LakituMoveDirection,x  ;difference between enemy and player if necessary
ChkPSpeed: lda $00
           and #%00111100             ;mask out all but four bits in the middle
           lsr                        ;divide masked difference by four
           lsr
           sta $00                    ;store as new value
           ldy #$00                   ;init offset
           lda Player_X_Speed
           beq SubDifAdj              ;if player not moving horizontally, branch
           lda ScrollAmount
           beq SubDifAdj              ;if scroll speed not set, branch to same place
           iny                        ;otherwise increment offset
           lda Player_X_Speed
           cmp #$19                   ;if player not running, branch
           bcc ChkSpinyO
           lda ScrollAmount
           cmp #$02                   ;if scroll speed below a certain amount, branch
           bcc ChkSpinyO              ;to same place
           iny                        ;otherwise increment once more
ChkSpinyO: lda Enemy_ID,x             ;check for spiny object
           cmp #Spiny
           bne ChkEmySpd              ;branch if not found
           lda Player_X_Speed         ;if player not moving, skip this part
           bne SubDifAdj
ChkEmySpd: lda Enemy_Y_Speed,x        ;check vertical speed
           bne SubDifAdj              ;branch if nonzero
           ldy #$00                   ;otherwise reinit offset
SubDifAdj: lda $0001,y                ;get one of three saved values from earlier
           ldy $00                    ;get saved horizontal difference
SPixelLak: sec                        ;subtract one for each pixel of horizontal difference
           sbc #$01                   ;from one of three saved values
           dey
           bpl SPixelLak              ;branch until all pixels are subtracted, to adjust difference
ExMoveLak: rts                        ;leave!!!
