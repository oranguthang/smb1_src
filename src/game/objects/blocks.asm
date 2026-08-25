; -------------------------------------------------------------------------------------
; These apply to all routines in this section unless otherwise noted:
; $00 - used to store metatile from block buffer routine
; $02 - used to store vertical high nybble offset from block buffer routine
; $05 - used to store metatile stored in A at beginning of PlayerHeadCollision
; $06-$07 - used as block buffer address indirect

BlockYPosAdderData:
    .byte $04, $12

PlayerHeadCollision:
    PHA  ; store metatile number to stack
    LDA #$11  ; load unbreakable block object state by default
    LDX SprDataOffset_Ctrl  ; load offset control bit here
    LDY PlayerSize  ; check player's size
    BNE DBlockSte  ; if small, branch
    LDA #$12  ; otherwise load breakable block object state
DBlockSte:
    STA Block_State,x  ; store into block object buffer
    JSR DestroyBlockMetatile  ; store blank metatile in vram buffer to write to name table
    LDX SprDataOffset_Ctrl  ; load offset control bit
    LDA $02  ; get vertical high nybble offset used in block buffer routine
    STA Block_Orig_YPos,x  ; set as vertical coordinate for block object
    TAY
    LDA $06  ; get low byte of block buffer address used in same routine
    STA Block_BBuf_Low,x  ; save as offset here to be used later
    LDA ($06),y  ; get contents of block buffer at old address at $06, $07
    JSR BlockBumpedChk  ; do a sub to check which block player bumped head on
    STA $00  ; store metatile here
    LDY PlayerSize  ; check player's size
    BNE ChkBrick  ; if small, use metatile itself as contents of A
    TYA  ; otherwise init A (note: big = 0)
ChkBrick:
    BCC PutMTileB  ; if no match was found in previous sub, skip ahead
    LDY #$11  ; otherwise load unbreakable state into block object buffer
    STY Block_State,x  ; note this applies to both player sizes
    LDA #$c4  ; load empty block metatile into A for now
    LDY $00  ; get metatile from before
    CPY #$58  ; is it brick with coins (with line)?
    BEQ StartBTmr  ; if so, branch
    CPY #$5d  ; is it brick with coins (without line)?
    BNE PutMTileB  ; if not, branch ahead to store empty block metatile
StartBTmr:
    LDA BrickCoinTimerFlag  ; check brick coin timer flag
    BNE ContBTmr  ; if set, timer expired or counting down, thus branch
    LDA #$0b
    STA BrickCoinTimer  ; if not set, set brick coin timer
    INC BrickCoinTimerFlag  ; and set flag linked to it
ContBTmr:
    LDA BrickCoinTimer  ; check brick coin timer
    BNE PutOldMT  ; if not yet expired, branch to use current metatile
    LDY #$c4  ; otherwise use empty block metatile
PutOldMT:
    TYA  ; put metatile into A
PutMTileB:
    STA Block_Metatile,x  ; store whatever metatile be appropriate here
    JSR InitBlock_XY_Pos  ; get block object horizontal coordinates saved
    LDY $02  ; get vertical high nybble offset
    LDA #$23
    STA ($06),y  ; write blank metatile $23 to block buffer
    LDA #$10
    STA BlockBounceTimer  ; set block bounce timer
    PLA  ; pull original metatile from stack
    STA $05  ; and save here
    LDY #$00  ; set default offset
    LDA CrouchingFlag  ; is player crouching?
    BNE SmallBP  ; if so, branch to increment offset
    LDA PlayerSize  ; is player big?
    BEQ BigBP  ; if so, branch to use default offset
SmallBP:
    INY  ; increment for small or big and crouching
BigBP:
    LDA Player_Y_Position  ; get player's vertical coordinate
    CLC
    ADC BlockYPosAdderData,y  ; add value determined by size
    AND #$f0  ; mask out low nybble to get 16-pixel correspondence
    STA Block_Y_Position,x  ; save as vertical coordinate for block object
    LDY Block_State,x  ; get block object state
    CPY #$11
    BEQ Unbreak  ; if set to value loaded for unbreakable, branch
    JSR BrickShatter  ; execute code for breakable brick
    JMP InvOBit  ; skip subroutine to do last part of code here
Unbreak:
    JSR BumpBlock  ; execute code for unbreakable brick or question block
InvOBit:
    LDA SprDataOffset_Ctrl  ; invert control bit used by block objects
    EOR #$01  ; and floatey numbers
    STA SprDataOffset_Ctrl
    RTS  ; leave!

; --------------------------------

InitBlock_XY_Pos:
    LDA Player_X_Position  ; get player's horizontal coordinate
    CLC
    ADC #$08  ; add eight pixels
    AND #$f0  ; mask out low nybble to give 16-pixel correspondence
    STA Block_X_Position,x  ; save as horizontal coordinate for block object
    LDA Player_PageLoc
    ADC #$00  ; add carry to page location of player
    STA Block_PageLoc,x  ; save as page location of block object
    STA Block_PageLoc2,x  ; save elsewhere to be used later
    LDA Player_Y_HighPos
    STA Block_Y_HighPos,x  ; save vertical high byte of player into
    RTS  ; vertical high byte of block object and leave

; --------------------------------

BumpBlock:
    JSR CheckTopOfBlock  ; check to see if there's a coin directly above this block
    LDA #Sfx_Bump
    STA Square1SoundQueue  ; play bump sound
    LDA #$00
    STA Block_X_Speed,x  ; initialize horizontal speed for block object
    STA Block_Y_MoveForce,x  ; init fractional movement force
    STA Player_Y_Speed  ; init player's vertical speed
    LDA #$fe
    STA Block_Y_Speed,x  ; set vertical speed for block object
    LDA $05  ; get original metatile from stack
    JSR BlockBumpedChk  ; do a sub to check which block player bumped head on
    BCC ExitBlockChk  ; if no match was found, branch to leave
    TYA  ; move block number to A
    CMP #$09  ; if block number was within 0-8 range,
    BCC BlockCode  ; branch to use current number
    SBC #$05  ; otherwise subtract 5 for second set to get proper number
BlockCode:
    JSR JumpEngine  ; run appropriate subroutine depending on block number

    .word MushFlowerBlock
    .word CoinBlock
    .word CoinBlock
    .word ExtraLifeMushBlock
    .word MushFlowerBlock
    .word VineBlock
    .word StarBlock
    .word CoinBlock
    .word ExtraLifeMushBlock

; --------------------------------

MushFlowerBlock:
    LDA #$00  ; load mushroom/fire flower into power-up type
    .byte $2c  ; BIT instruction opcode

StarBlock:
    LDA #$02  ; load star into power-up type
    .byte $2c  ; BIT instruction opcode

ExtraLifeMushBlock:
    LDA #$03  ; load 1-up mushroom into power-up type
    STA $39  ; store correct power-up type
    JMP SetupPowerUp

VineBlock:
    LDX #$05  ; load last slot for enemy object buffer
    LDY SprDataOffset_Ctrl  ; get control bit
    JSR Setup_Vine  ; set up vine object

ExitBlockChk:
    RTS  ; leave

; --------------------------------

BrickQBlockMetatiles:
    .byte $c1, $c0, $5f, $60  ; used by question blocks

; these two sets are functionally identical, but look different
    .byte $55, $56, $57, $58, $59  ; used by ground level types
    .byte $5a, $5b, $5c, $5d, $5e  ; used by other level types

BlockBumpedChk:
    LDY #$0d  ; start at end of metatile data
BumpChkLoop:
    CMP BrickQBlockMetatiles,y  ; check to see if current metatile matches
    BEQ MatchBump  ; metatile found in block buffer, branch if so
    DEY  ; otherwise move onto next metatile
    BPL BumpChkLoop  ; do this until all metatiles are checked
    CLC  ; if none match, return with carry clear
MatchBump:
    RTS  ; note carry is set if found match

; --------------------------------

BrickShatter:
    JSR CheckTopOfBlock  ; check to see if there's a coin directly above this block
    LDA #Sfx_BrickShatter
    STA Block_RepFlag,x  ; set flag for block object to immediately replace metatile
    STA NoiseSoundQueue  ; load brick shatter sound
    JSR SpawnBrickChunks  ; create brick chunk objects
    LDA #$fe
    STA Player_Y_Speed  ; set vertical speed for player
    LDA #$05
    STA DigitModifier+5  ; set digit modifier to give player 50 points
    JSR AddToScore  ; do sub to update the score
    LDX SprDataOffset_Ctrl  ; load control bit and leave
    RTS

; --------------------------------

CheckTopOfBlock:
    LDX SprDataOffset_Ctrl  ; load control bit
    LDY $02  ; get vertical high nybble offset used in block buffer
    BEQ TopEx  ; branch to leave if set to zero, because we're at the top
    TYA  ; otherwise set to A
    SEC
    SBC #$10  ; subtract $10 to move up one row in the block buffer
    STA $02  ; store as new vertical high nybble offset
    TAY
    LDA ($06),y  ; get contents of block buffer in same column, one row up
    CMP #$c2  ; is it a coin? (not underwater)
    BNE TopEx  ; if not, branch to leave
    LDA #$00
    STA ($06),y  ; otherwise put blank metatile where coin was
    JSR RemoveCoin_Axe  ; write blank metatile to vram buffer
    LDX SprDataOffset_Ctrl  ; get control bit
    JSR SetupJumpCoin  ; create jumping coin object and update coin variables
TopEx:
    RTS  ; leave!

; --------------------------------

SpawnBrickChunks:
    LDA Block_X_Position,x  ; set horizontal coordinate of block object
    STA Block_Orig_XPos,x  ; as original horizontal coordinate here
    LDA #$f0
    STA Block_X_Speed,x  ; set horizontal speed for brick chunk objects
    STA Block_X_Speed+2,x
    LDA #$fa
    STA Block_Y_Speed,x  ; set vertical speed for one
    LDA #$fc
    STA Block_Y_Speed+2,x  ; set lower vertical speed for the other
    LDA #$00
    STA Block_Y_MoveForce,x  ; init fractional movement force for both
    STA Block_Y_MoveForce+2,x
    LDA Block_PageLoc,x
    STA Block_PageLoc+2,x  ; copy page location
    LDA Block_X_Position,x
    STA Block_X_Position+2,x  ; copy horizontal coordinate
    LDA Block_Y_Position,x
    CLC  ; add 8 pixels to vertical coordinate
    ADC #$08  ; and save as vertical coordinate for one of them
    STA Block_Y_Position+2,x
    LDA #$fa
    STA Block_Y_Speed,x  ; set vertical speed...again??? (redundant)
    RTS

; -------------------------------------------------------------------------------------

BlockObjectsCore:
    LDA Block_State,x  ; get state of block object
    BEQ UpdSte  ; if not set, branch to leave
    AND #$0f  ; mask out high nybble
    PHA  ; push to stack
    TAY  ; put in Y for now
    TXA
    CLC
    ADC #$09  ; add 9 bytes to offset (note two block objects are created
    TAX  ; when using brick chunks, but only one offset for both)
    DEY  ; decrement Y to check for solid block state
    BEQ BouncingBlockHandler  ; branch if found, otherwise continue for brick chunks
    JSR ImposeGravityBlock  ; do sub to impose gravity on one block object object
    JSR MoveObjectHorizontally  ; do another sub to move horizontally
    TXA
    CLC  ; move onto next block object
    ADC #$02
    TAX
    JSR ImposeGravityBlock  ; do sub to impose gravity on other block object
    JSR MoveObjectHorizontally  ; do another sub to move horizontally
    LDX ObjectOffset  ; get block object offset used for both
    JSR RelativeBlockPosition  ; get relative coordinates
    JSR GetBlockOffscreenBits  ; get offscreen information
    JSR DrawBrickChunks  ; draw the brick chunks
    PLA  ; get lower nybble of saved state
    LDY Block_Y_HighPos,x  ; check vertical high byte of block object
    BEQ UpdSte  ; if above the screen, branch to kill it
    PHA  ; otherwise save state back into stack
    LDA #$f0
    CMP Block_Y_Position+2,x  ; check to see if bottom block object went
    BCS ChkTop  ; to the bottom of the screen, and branch if not
    STA Block_Y_Position+2,x  ; otherwise set offscreen coordinate
ChkTop:
    LDA Block_Y_Position,x  ; get top block object's vertical coordinate
    CMP #$f0  ; see if it went to the bottom of the screen
    PLA  ; pull block object state from stack
    BCC UpdSte  ; if not, branch to save state
    BCS KillBlock  ; otherwise do unconditional branch to kill it

BouncingBlockHandler:
    JSR ImposeGravityBlock  ; do sub to impose gravity on block object
    LDX ObjectOffset  ; get block object offset
    JSR RelativeBlockPosition  ; get relative coordinates
    JSR GetBlockOffscreenBits  ; get offscreen information
    JSR DrawBlock  ; draw the block
    LDA Block_Y_Position,x  ; get vertical coordinate
    AND #$0f  ; mask out high nybble
    CMP #$05  ; check to see if low nybble wrapped around
    PLA  ; pull state from stack
    BCS UpdSte  ; if still above amount, not time to kill block yet, thus branch
    LDA #$01
    STA Block_RepFlag,x  ; otherwise set flag to replace metatile
KillBlock:
    LDA #$00  ; if branched here, nullify object state
UpdSte:
    STA Block_State,x  ; store contents of A in block object state
    RTS

; -------------------------------------------------------------------------------------
; $02 - used to store offset to block buffer
; $06-$07 - used to store block buffer address

BlockObjMT_Updater:
    LDX #$01  ; set offset to start with second block object
UpdateLoop:
    STX ObjectOffset  ; set offset here
    LDA VRAM_Buffer1  ; if vram buffer already being used here,
    BNE NextBUpd  ; branch to move onto next block object
    LDA Block_RepFlag,x  ; if flag for block object already clear,
    BEQ NextBUpd  ; branch to move onto next block object
    LDA Block_BBuf_Low,x  ; get low byte of block buffer
    STA $06  ; store into block buffer address
    LDA #$05
    STA $07  ; set high byte of block buffer address
    LDA Block_Orig_YPos,x  ; get original vertical coordinate of block object
    STA $02  ; store here and use as offset to block buffer
    TAY
    LDA Block_Metatile,x  ; get metatile to be written
    STA ($06),y  ; write it to the block buffer
    JSR ReplaceBlockMetatile  ; do sub to replace metatile where block object is
    LDA #$00
    STA Block_RepFlag,x  ; clear block object flag
NextBUpd:
    DEX  ; decrement block object offset
    BPL UpdateLoop  ; do this until both block objects are dealt with
    RTS  ; then leave
