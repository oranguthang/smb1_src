;-------------------------------------------------------------------------------------
;These apply to all routines in this section unless otherwise noted:
;$00 - used to store metatile from block buffer routine
;$02 - used to store vertical high nybble offset from block buffer routine
;$05 - used to store metatile stored in A at beginning of PlayerHeadCollision
;$06-$07 - used as block buffer address indirect

BlockYPosAdderData:
      .byte $04, $12

PlayerHeadCollision:
           pha                      ;store metatile number to stack
           lda #$11                 ;load unbreakable block object state by default
           ldx SprDataOffset_Ctrl   ;load offset control bit here
           ldy PlayerSize           ;check player's size
           bne DBlockSte            ;if small, branch
           lda #$12                 ;otherwise load breakable block object state
DBlockSte: sta Block_State,x        ;store into block object buffer
           jsr DestroyBlockMetatile ;store blank metatile in vram buffer to write to name table
           ldx SprDataOffset_Ctrl   ;load offset control bit
           lda $02                  ;get vertical high nybble offset used in block buffer routine
           sta Block_Orig_YPos,x    ;set as vertical coordinate for block object
           tay
           lda $06                  ;get low byte of block buffer address used in same routine
           sta Block_BBuf_Low,x     ;save as offset here to be used later
           lda ($06),y              ;get contents of block buffer at old address at $06, $07
           jsr BlockBumpedChk       ;do a sub to check which block player bumped head on
           sta $00                  ;store metatile here
           ldy PlayerSize           ;check player's size
           bne ChkBrick             ;if small, use metatile itself as contents of A
           tya                      ;otherwise init A (note: big = 0)
ChkBrick:  bcc PutMTileB            ;if no match was found in previous sub, skip ahead
           ldy #$11                 ;otherwise load unbreakable state into block object buffer
           sty Block_State,x        ;note this applies to both player sizes
           lda #$c4                 ;load empty block metatile into A for now
           ldy $00                  ;get metatile from before
           cpy #$58                 ;is it brick with coins (with line)?
           beq StartBTmr            ;if so, branch
           cpy #$5d                 ;is it brick with coins (without line)?
           bne PutMTileB            ;if not, branch ahead to store empty block metatile
StartBTmr: lda BrickCoinTimerFlag   ;check brick coin timer flag
           bne ContBTmr             ;if set, timer expired or counting down, thus branch
           lda #$0b
           sta BrickCoinTimer       ;if not set, set brick coin timer
           inc BrickCoinTimerFlag   ;and set flag linked to it
ContBTmr:  lda BrickCoinTimer       ;check brick coin timer
           bne PutOldMT             ;if not yet expired, branch to use current metatile
           ldy #$c4                 ;otherwise use empty block metatile
PutOldMT:  tya                      ;put metatile into A
PutMTileB: sta Block_Metatile,x     ;store whatever metatile be appropriate here
           jsr InitBlock_XY_Pos     ;get block object horizontal coordinates saved
           ldy $02                  ;get vertical high nybble offset
           lda #$23
           sta ($06),y              ;write blank metatile $23 to block buffer
           lda #$10
           sta BlockBounceTimer     ;set block bounce timer
           pla                      ;pull original metatile from stack
           sta $05                  ;and save here
           ldy #$00                 ;set default offset
           lda CrouchingFlag        ;is player crouching?
           bne SmallBP              ;if so, branch to increment offset
           lda PlayerSize           ;is player big?
           beq BigBP                ;if so, branch to use default offset
SmallBP:   iny                      ;increment for small or big and crouching
BigBP:     lda Player_Y_Position    ;get player's vertical coordinate
           clc
           adc BlockYPosAdderData,y ;add value determined by size
           and #$f0                 ;mask out low nybble to get 16-pixel correspondence
           sta Block_Y_Position,x   ;save as vertical coordinate for block object
           ldy Block_State,x        ;get block object state
           cpy #$11
           beq Unbreak              ;if set to value loaded for unbreakable, branch
           jsr BrickShatter         ;execute code for breakable brick
           jmp InvOBit              ;skip subroutine to do last part of code here
Unbreak:   jsr BumpBlock            ;execute code for unbreakable brick or question block
InvOBit:   lda SprDataOffset_Ctrl   ;invert control bit used by block objects
           eor #$01                 ;and floatey numbers
           sta SprDataOffset_Ctrl
           rts                      ;leave!

;--------------------------------

InitBlock_XY_Pos:
      lda Player_X_Position   ;get player's horizontal coordinate
      clc
      adc #$08                ;add eight pixels
      and #$f0                ;mask out low nybble to give 16-pixel correspondence
      sta Block_X_Position,x  ;save as horizontal coordinate for block object
      lda Player_PageLoc
      adc #$00                ;add carry to page location of player
      sta Block_PageLoc,x     ;save as page location of block object
      sta Block_PageLoc2,x    ;save elsewhere to be used later
      lda Player_Y_HighPos
      sta Block_Y_HighPos,x   ;save vertical high byte of player into
      rts                     ;vertical high byte of block object and leave

;--------------------------------

BumpBlock:
           jsr CheckTopOfBlock     ;check to see if there's a coin directly above this block
           lda #Sfx_Bump
           sta Square1SoundQueue   ;play bump sound
           lda #$00
           sta Block_X_Speed,x     ;initialize horizontal speed for block object
           sta Block_Y_MoveForce,x ;init fractional movement force
           sta Player_Y_Speed      ;init player's vertical speed
           lda #$fe
           sta Block_Y_Speed,x     ;set vertical speed for block object
           lda $05                 ;get original metatile from stack
           jsr BlockBumpedChk      ;do a sub to check which block player bumped head on
           bcc ExitBlockChk        ;if no match was found, branch to leave
           tya                     ;move block number to A
           cmp #$09                ;if block number was within 0-8 range,
           bcc BlockCode           ;branch to use current number
           sbc #$05                ;otherwise subtract 5 for second set to get proper number
BlockCode: jsr JumpEngine          ;run appropriate subroutine depending on block number

      .word MushFlowerBlock
      .word CoinBlock
      .word CoinBlock
      .word ExtraLifeMushBlock
      .word MushFlowerBlock
      .word VineBlock
      .word StarBlock
      .word CoinBlock
      .word ExtraLifeMushBlock

;--------------------------------

MushFlowerBlock:
      lda #$00       ;load mushroom/fire flower into power-up type
      .byte $2c        ;BIT instruction opcode

StarBlock:
      lda #$02       ;load star into power-up type
      .byte $2c        ;BIT instruction opcode

ExtraLifeMushBlock:
      lda #$03         ;load 1-up mushroom into power-up type
      sta $39          ;store correct power-up type
      jmp SetupPowerUp

VineBlock:
      ldx #$05                ;load last slot for enemy object buffer
      ldy SprDataOffset_Ctrl  ;get control bit
      jsr Setup_Vine          ;set up vine object

ExitBlockChk:
      rts                     ;leave

;--------------------------------

BrickQBlockMetatiles:
      .byte $c1, $c0, $5f, $60 ;used by question blocks

      ;these two sets are functionally identical, but look different
      .byte $55, $56, $57, $58, $59 ;used by ground level types
      .byte $5a, $5b, $5c, $5d, $5e ;used by other level types

BlockBumpedChk:
             ldy #$0d                    ;start at end of metatile data
BumpChkLoop: cmp BrickQBlockMetatiles,y  ;check to see if current metatile matches
             beq MatchBump               ;metatile found in block buffer, branch if so
             dey                         ;otherwise move onto next metatile
             bpl BumpChkLoop             ;do this until all metatiles are checked
             clc                         ;if none match, return with carry clear
MatchBump:   rts                         ;note carry is set if found match

;--------------------------------

BrickShatter:
      jsr CheckTopOfBlock    ;check to see if there's a coin directly above this block
      lda #Sfx_BrickShatter
      sta Block_RepFlag,x    ;set flag for block object to immediately replace metatile
      sta NoiseSoundQueue    ;load brick shatter sound
      jsr SpawnBrickChunks   ;create brick chunk objects
      lda #$fe
      sta Player_Y_Speed     ;set vertical speed for player
      lda #$05
      sta DigitModifier+5    ;set digit modifier to give player 50 points
      jsr AddToScore         ;do sub to update the score
      ldx SprDataOffset_Ctrl ;load control bit and leave
      rts

;--------------------------------

CheckTopOfBlock:
       ldx SprDataOffset_Ctrl  ;load control bit
       ldy $02                 ;get vertical high nybble offset used in block buffer
       beq TopEx               ;branch to leave if set to zero, because we're at the top
       tya                     ;otherwise set to A
       sec
       sbc #$10                ;subtract $10 to move up one row in the block buffer
       sta $02                 ;store as new vertical high nybble offset
       tay
       lda ($06),y             ;get contents of block buffer in same column, one row up
       cmp #$c2                ;is it a coin? (not underwater)
       bne TopEx               ;if not, branch to leave
       lda #$00
       sta ($06),y             ;otherwise put blank metatile where coin was
       jsr RemoveCoin_Axe      ;write blank metatile to vram buffer
       ldx SprDataOffset_Ctrl  ;get control bit
       jsr SetupJumpCoin       ;create jumping coin object and update coin variables
TopEx: rts                     ;leave!

;--------------------------------

SpawnBrickChunks:
      lda Block_X_Position,x     ;set horizontal coordinate of block object
      sta Block_Orig_XPos,x      ;as original horizontal coordinate here
      lda #$f0
      sta Block_X_Speed,x        ;set horizontal speed for brick chunk objects
      sta Block_X_Speed+2,x
      lda #$fa
      sta Block_Y_Speed,x        ;set vertical speed for one
      lda #$fc
      sta Block_Y_Speed+2,x      ;set lower vertical speed for the other
      lda #$00
      sta Block_Y_MoveForce,x    ;init fractional movement force for both
      sta Block_Y_MoveForce+2,x
      lda Block_PageLoc,x
      sta Block_PageLoc+2,x      ;copy page location
      lda Block_X_Position,x
      sta Block_X_Position+2,x   ;copy horizontal coordinate
      lda Block_Y_Position,x
      clc                        ;add 8 pixels to vertical coordinate
      adc #$08                   ;and save as vertical coordinate for one of them
      sta Block_Y_Position+2,x
      lda #$fa
      sta Block_Y_Speed,x        ;set vertical speed...again??? (redundant)
      rts

;-------------------------------------------------------------------------------------

BlockObjectsCore:
        lda Block_State,x           ;get state of block object
        beq UpdSte                  ;if not set, branch to leave
        and #$0f                    ;mask out high nybble
        pha                         ;push to stack
        tay                         ;put in Y for now
        txa
        clc
        adc #$09                    ;add 9 bytes to offset (note two block objects are created
        tax                         ;when using brick chunks, but only one offset for both)
        dey                         ;decrement Y to check for solid block state
        beq BouncingBlockHandler    ;branch if found, otherwise continue for brick chunks
        jsr ImposeGravityBlock      ;do sub to impose gravity on one block object object
        jsr MoveObjectHorizontally  ;do another sub to move horizontally
        txa
        clc                         ;move onto next block object
        adc #$02
        tax
        jsr ImposeGravityBlock      ;do sub to impose gravity on other block object
        jsr MoveObjectHorizontally  ;do another sub to move horizontally
        ldx ObjectOffset            ;get block object offset used for both
        jsr RelativeBlockPosition   ;get relative coordinates
        jsr GetBlockOffscreenBits   ;get offscreen information
        jsr DrawBrickChunks         ;draw the brick chunks
        pla                         ;get lower nybble of saved state
        ldy Block_Y_HighPos,x       ;check vertical high byte of block object
        beq UpdSte                  ;if above the screen, branch to kill it
        pha                         ;otherwise save state back into stack
        lda #$f0
        cmp Block_Y_Position+2,x    ;check to see if bottom block object went
        bcs ChkTop                  ;to the bottom of the screen, and branch if not
        sta Block_Y_Position+2,x    ;otherwise set offscreen coordinate
ChkTop: lda Block_Y_Position,x      ;get top block object's vertical coordinate
        cmp #$f0                    ;see if it went to the bottom of the screen
        pla                         ;pull block object state from stack
        bcc UpdSte                  ;if not, branch to save state
        bcs KillBlock               ;otherwise do unconditional branch to kill it

BouncingBlockHandler:
           jsr ImposeGravityBlock     ;do sub to impose gravity on block object
           ldx ObjectOffset           ;get block object offset
           jsr RelativeBlockPosition  ;get relative coordinates
           jsr GetBlockOffscreenBits  ;get offscreen information
           jsr DrawBlock              ;draw the block
           lda Block_Y_Position,x     ;get vertical coordinate
           and #$0f                   ;mask out high nybble
           cmp #$05                   ;check to see if low nybble wrapped around
           pla                        ;pull state from stack
           bcs UpdSte                 ;if still above amount, not time to kill block yet, thus branch
           lda #$01
           sta Block_RepFlag,x        ;otherwise set flag to replace metatile
KillBlock: lda #$00                   ;if branched here, nullify object state
UpdSte:    sta Block_State,x          ;store contents of A in block object state
           rts

;-------------------------------------------------------------------------------------
;$02 - used to store offset to block buffer
;$06-$07 - used to store block buffer address

BlockObjMT_Updater:
            ldx #$01                  ;set offset to start with second block object
UpdateLoop: stx ObjectOffset          ;set offset here
            lda VRAM_Buffer1          ;if vram buffer already being used here,
            bne NextBUpd              ;branch to move onto next block object
            lda Block_RepFlag,x       ;if flag for block object already clear,
            beq NextBUpd              ;branch to move onto next block object
            lda Block_BBuf_Low,x      ;get low byte of block buffer
            sta $06                   ;store into block buffer address
            lda #$05
            sta $07                   ;set high byte of block buffer address
            lda Block_Orig_YPos,x     ;get original vertical coordinate of block object
            sta $02                   ;store here and use as offset to block buffer
            tay
            lda Block_Metatile,x      ;get metatile to be written
            sta ($06),y               ;write it to the block buffer
            jsr ReplaceBlockMetatile  ;do sub to replace metatile where block object is
            lda #$00
            sta Block_RepFlag,x       ;clear block object flag
NextBUpd:   dex                       ;decrement block object offset
            bpl UpdateLoop            ;do this until both block objects are dealt with
            rts                       ;then leave
