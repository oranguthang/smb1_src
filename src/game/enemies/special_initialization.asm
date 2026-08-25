;--------------------------------

FirebarSpinSpdData:
      .byte $28, $38, $28, $38, $28

FirebarSpinDirData:
      .byte $00, $00, $10, $10, $00

InitLongFirebar:
      jsr DuplicateEnemyObj       ;create enemy object for long firebar

InitShortFirebar:
      lda #$00                    ;initialize low byte of spin state
      sta FirebarSpinState_Low,x
      lda Enemy_ID,x              ;subtract $1b from enemy identifier
      sec                         ;to get proper offset for firebar data
      sbc #$1b
      tay
      lda FirebarSpinSpdData,y    ;get spinning speed of firebar
      sta FirebarSpinSpeed,x
      lda FirebarSpinDirData,y    ;get spinning direction of firebar
      sta FirebarSpinDirection,x
      lda Enemy_Y_Position,x
      clc                         ;add four pixels to vertical coordinate
      adc #$04
      sta Enemy_Y_Position,x
      lda Enemy_X_Position,x
      clc                         ;add four pixels to horizontal coordinate
      adc #$04
      sta Enemy_X_Position,x
      lda Enemy_PageLoc,x
      adc #$00                    ;add carry to page location
      sta Enemy_PageLoc,x
      jmp TallBBox2               ;set bounding box control (not used) and leave

;--------------------------------
;$00-$01 - used to hold pseudorandom bits

FlyCCXPositionData:
      .byte $80, $30, $40, $80
      .byte $30, $50, $50, $70
      .byte $20, $40, $80, $a0
      .byte $70, $40, $90, $68

FlyCCXSpeedData:
      .byte $0e, $05, $06, $0e
      .byte $1c, $20, $10, $0c
      .byte $1e, $22, $18, $14

FlyCCTimerData:
      .byte $10, $60, $20, $48

InitFlyingCheepCheep:
         lda FrenzyEnemyTimer       ;if timer here not expired yet, branch to leave
         bne ChpChpEx
         jsr SmallBBox              ;jump to set bounding box size $09 and init other values
         lda PseudoRandomBitReg+1,x
         and #%00000011             ;set pseudorandom offset here
         tay
         lda FlyCCTimerData,y       ;load timer with pseudorandom offset
         sta FrenzyEnemyTimer
         ldy #$03                   ;load Y with default value
         lda SecondaryHardMode
         beq MaxCC                  ;if secondary hard mode flag not set, do not increment Y
         iny                        ;otherwise, increment Y to allow as many as four onscreen
MaxCC:   sty $00                    ;store whatever pseudorandom bits are in Y
         cpx $00                    ;compare enemy object buffer offset with Y
         bcs ChpChpEx               ;if X => Y, branch to leave
         lda PseudoRandomBitReg,x
         and #%00000011             ;get last two bits of LSFR, first part
         sta $00                    ;and store in two places
         sta $01
         lda #$fb                   ;set vertical speed for cheep-cheep
         sta Enemy_Y_Speed,x
         lda #$00                   ;load default value
         ldy Player_X_Speed         ;check player's horizontal speed
         beq GSeed                  ;if player not moving left or right, skip this part
         lda #$04
         cpy #$19                   ;if moving to the right but not very quickly,
         bcc GSeed                  ;do not change A
         asl                        ;otherwise, multiply A by 2
GSeed:   pha                        ;save to stack
         clc
         adc $00                    ;add to last two bits of LSFR we saved earlier
         sta $00                    ;save it there
         lda PseudoRandomBitReg+1,x
         and #%00000011             ;if neither of the last two bits of second LSFR set,
         beq RSeed                  ;skip this part and save contents of $00
         lda PseudoRandomBitReg+2,x
         and #%00001111             ;otherwise overwrite with lower nybble of
         sta $00                    ;third LSFR part
RSeed:   pla                        ;get value from stack we saved earlier
         clc
         adc $01                    ;add to last two bits of LSFR we saved in other place
         tay                        ;use as pseudorandom offset here
         lda FlyCCXSpeedData,y      ;get horizontal speed using pseudorandom offset
         sta Enemy_X_Speed,x
         lda #$01                   ;set to move towards the right
         sta Enemy_MovingDir,x
         lda Player_X_Speed         ;if player moving left or right, branch ahead of this part
         bne D2XPos1
         ldy $00                    ;get first LSFR or third LSFR lower nybble
         tya                        ;and check for d1 set
         and #%00000010
         beq D2XPos1                ;if d1 not set, branch
         lda Enemy_X_Speed,x
         eor #$ff                   ;if d1 set, change horizontal speed
         clc                        ;into two's compliment, thus moving in the opposite
         adc #$01                   ;direction
         sta Enemy_X_Speed,x
         inc Enemy_MovingDir,x      ;increment to move towards the left
D2XPos1: tya                        ;get first LSFR or third LSFR lower nybble again
         and #%00000010
         beq D2XPos2                ;check for d1 set again, branch again if not set
         lda Player_X_Position      ;get player's horizontal position
         clc
         adc FlyCCXPositionData,y   ;if d1 set, add value obtained from pseudorandom offset
         sta Enemy_X_Position,x     ;and save as enemy's horizontal position
         lda Player_PageLoc         ;get player's page location
         adc #$00                   ;add carry and jump past this part
         jmp FinCCSt
D2XPos2: lda Player_X_Position      ;get player's horizontal position
         sec
         sbc FlyCCXPositionData,y   ;if d1 not set, subtract value obtained from pseudorandom
         sta Enemy_X_Position,x     ;offset and save as enemy's horizontal position
         lda Player_PageLoc         ;get player's page location
         sbc #$00                   ;subtract borrow
FinCCSt: sta Enemy_PageLoc,x        ;save as enemy's page location
         lda #$01
         sta Enemy_Flag,x           ;set enemy's buffer flag
         sta Enemy_Y_HighPos,x      ;set enemy's high vertical byte
         lda #$f8
         sta Enemy_Y_Position,x     ;put enemy below the screen, and we are done
         rts

;--------------------------------

InitBowser:
      jsr DuplicateEnemyObj     ;jump to create another bowser object
      stx BowserFront_Offset    ;save offset of first here
      lda #$00
      sta BowserBodyControls    ;initialize bowser's body controls
      sta BridgeCollapseOffset  ;and bridge collapse offset
      lda Enemy_X_Position,x
      sta BowserOrigXPos        ;store original horizontal position here
      lda #$df
      sta BowserFireBreathTimer ;store something here
      sta Enemy_MovingDir,x     ;and in moving direction
      lda #$20
      sta BowserFeetCounter     ;set bowser's feet timer and in enemy timer
      sta EnemyFrameTimer,x
      lda #$05
      sta BowserHitPoints       ;give bowser 5 hit points
      lsr
      sta BowserMovementSpeed   ;set default movement speed here
      rts

;--------------------------------

DuplicateEnemyObj:
        ldy #$ff                ;start at beginning of enemy slots
FSLoop: iny                     ;increment one slot
        lda Enemy_Flag,y        ;check enemy buffer flag for empty slot
        bne FSLoop              ;if set, branch and keep checking
        sty DuplicateObj_Offset ;otherwise set offset here
        txa                     ;transfer original enemy buffer offset
        ora #%10000000          ;store with d7 set as flag in new enemy
        sta Enemy_Flag,y        ;slot as well as enemy offset
        lda Enemy_PageLoc,x
        sta Enemy_PageLoc,y     ;copy page location and horizontal coordinates
        lda Enemy_X_Position,x  ;from original enemy to new enemy
        sta Enemy_X_Position,y
        lda #$01
        sta Enemy_Flag,x        ;set flag as normal for original enemy
        sta Enemy_Y_HighPos,y   ;set high vertical byte for new enemy
        lda Enemy_Y_Position,x
        sta Enemy_Y_Position,y  ;copy vertical coordinate from original to new
FlmEx:  rts                     ;and then leave

;--------------------------------

FlameYPosData:
      .byte $90, $80, $70, $90

FlameYMFAdderData:
      .byte $ff, $01

InitBowserFlame:
        lda FrenzyEnemyTimer        ;if timer not expired yet, branch to leave
        bne FlmEx
        sta Enemy_Y_MoveForce,x     ;reset something here
        lda NoiseSoundQueue
        ora #Sfx_BowserFlame        ;load bowser's flame sound into queue
        sta NoiseSoundQueue
        ldy BowserFront_Offset      ;get bowser's buffer offset
        lda Enemy_ID,y              ;check for bowser
        cmp #Bowser
        beq SpawnFromMouth          ;branch if found
        jsr SetFlameTimer           ;get timer data based on flame counter
        clc
        adc #$20                    ;add 32 frames by default
        ldy SecondaryHardMode
        beq SetFrT                  ;if secondary mode flag not set, use as timer setting
        sec
        sbc #$10                    ;otherwise subtract 16 frames for secondary hard mode
SetFrT: sta FrenzyEnemyTimer        ;set timer accordingly
        lda PseudoRandomBitReg,x
        and #%00000011              ;get 2 LSB from first part of LSFR
        sta BowserFlamePRandomOfs,x ;set here
        tay                         ;use as offset
        lda FlameYPosData,y         ;load vertical position based on pseudorandom offset

PutAtRightExtent:
      sta Enemy_Y_Position,x    ;set vertical position
      lda ScreenRight_X_Pos
      clc
      adc #$20                  ;place enemy 32 pixels beyond right side of screen
      sta Enemy_X_Position,x
      lda ScreenRight_PageLoc
      adc #$00                  ;add carry
      sta Enemy_PageLoc,x
      jmp FinishFlame           ;skip this part to finish setting values

SpawnFromMouth:
       lda Enemy_X_Position,y    ;get bowser's horizontal position
       sec
       sbc #$0e                  ;subtract 14 pixels
       sta Enemy_X_Position,x    ;save as flame's horizontal position
       lda Enemy_PageLoc,y
       sta Enemy_PageLoc,x       ;copy page location from bowser to flame
       lda Enemy_Y_Position,y
       clc                       ;add 8 pixels to bowser's vertical position
       adc #$08
       sta Enemy_Y_Position,x    ;save as flame's vertical position
       lda PseudoRandomBitReg,x
       and #%00000011            ;get 2 LSB from first part of LSFR
       sta Enemy_YMF_Dummy,x     ;save here
       tay                       ;use as offset
       lda FlameYPosData,y       ;get value here using bits as offset
       ldy #$00                  ;load default offset
       cmp Enemy_Y_Position,x    ;compare value to flame's current vertical position
       bcc SetMF                 ;if less, do not increment offset
       iny                       ;otherwise increment now
SetMF: lda FlameYMFAdderData,y   ;get value here and save
       sta Enemy_Y_MoveForce,x   ;to vertical movement force
       lda #$00
       sta EnemyFrenzyBuffer     ;clear enemy frenzy buffer

FinishFlame:
      lda #$08                 ;set $08 for bounding box control
      sta Enemy_BoundBoxCtrl,x
      lda #$01                 ;set high byte of vertical and
      sta Enemy_Y_HighPos,x    ;enemy buffer flag
      sta Enemy_Flag,x
      lsr
      sta Enemy_X_MoveForce,x  ;initialize horizontal movement force, and
      sta Enemy_State,x        ;enemy state
      rts

;--------------------------------

FireworksXPosData:
      .byte $00, $30, $60, $60, $00, $20

FireworksYPosData:
      .byte $60, $40, $70, $40, $60, $30

InitFireworks:
          lda FrenzyEnemyTimer         ;if timer not expired yet, branch to leave
          bne ExitFWk
          lda #$20                     ;otherwise reset timer
          sta FrenzyEnemyTimer
          dec FireworksCounter         ;decrement for each explosion
          ldy #$06                     ;start at last slot
StarFChk: dey
          lda Enemy_ID,y               ;check for presence of star flag object
          cmp #StarFlagObject          ;if there isn't a star flag object,
          bne StarFChk                 ;routine goes into infinite loop = crash
          lda Enemy_X_Position,y
          sec                          ;get horizontal coordinate of star flag object, then
          sbc #$30                     ;subtract 48 pixels from it and save to
          pha                          ;the stack
          lda Enemy_PageLoc,y
          sbc #$00                     ;subtract the carry from the page location
          sta $00                      ;of the star flag object
          lda FireworksCounter         ;get fireworks counter
          clc
          adc Enemy_State,y            ;add state of star flag object (possibly not necessary)
          tay                          ;use as offset
          pla                          ;get saved horizontal coordinate of star flag - 48 pixels
          clc
          adc FireworksXPosData,y      ;add number based on offset of fireworks counter
          sta Enemy_X_Position,x       ;store as the fireworks object horizontal coordinate
          lda $00
          adc #$00                     ;add carry and store as page location for
          sta Enemy_PageLoc,x          ;the fireworks object
          lda FireworksYPosData,y      ;get vertical position using same offset
          sta Enemy_Y_Position,x       ;and store as vertical coordinate for fireworks object
          lda #$01
          sta Enemy_Y_HighPos,x        ;store in vertical high byte
          sta Enemy_Flag,x             ;and activate enemy buffer flag
          lsr
          sta ExplosionGfxCounter,x    ;initialize explosion counter
          lda #$08
          sta ExplosionTimerCounter,x  ;set explosion timing counter
ExitFWk:  rts

;--------------------------------

Bitmasks:
      .byte %00000001, %00000010, %00000100, %00001000, %00010000, %00100000, %01000000, %10000000

Enemy17YPosData:
      .byte $40, $30, $90, $50, $20, $60, $a0, $70

SwimCC_IDData:
      .byte $0a, $0b

BulletBillCheepCheep:
         lda FrenzyEnemyTimer      ;if timer not expired yet, branch to leave
         bne ExF17
         lda AreaType              ;are we in a water-type level?
         bne DoBulletBills         ;if not, branch elsewhere
         cpx #$03                  ;are we past third enemy slot?
         bcs ExF17                 ;if so, branch to leave
         ldy #$00                  ;load default offset
         lda PseudoRandomBitReg,x
         cmp #$aa                  ;check first part of LSFR against preset value
         bcc ChkW2                 ;if less than preset, do not increment offset
         iny                       ;otherwise increment
ChkW2:   lda WorldNumber           ;check world number
         cmp #World2
         beq Get17ID               ;if we're on world 2, do not increment offset
         iny                       ;otherwise increment
Get17ID: tya
         and #%00000001            ;mask out all but last bit of offset
         tay
         lda SwimCC_IDData,y       ;load identifier for cheep-cheeps
Set17ID: sta Enemy_ID,x            ;store whatever's in A as enemy identifier
         lda BitMFilter
         cmp #$ff                  ;if not all bits set, skip init part and compare bits
         bne GetRBit
         lda #$00                  ;initialize vertical position filter
         sta BitMFilter
GetRBit: lda PseudoRandomBitReg,x  ;get first part of LSFR
         and #%00000111            ;mask out all but 3 LSB
ChkRBit: tay                       ;use as offset
         lda Bitmasks,y            ;load bitmask
         bit BitMFilter            ;perform AND on filter without changing it
         beq AddFBit
         iny                       ;increment offset
         tya
         and #%00000111            ;mask out all but 3 LSB thus keeping it 0-7
         jmp ChkRBit               ;do another check
AddFBit: ora BitMFilter            ;add bit to already set bits in filter
         sta BitMFilter            ;and store
         lda Enemy17YPosData,y     ;load vertical position using offset
         jsr PutAtRightExtent      ;set vertical position and other values
         sta Enemy_YMF_Dummy,x     ;initialize dummy variable
         lda #$20                  ;set timer
         sta FrenzyEnemyTimer
         jmp CheckpointEnemyID     ;process our new enemy object

DoBulletBills:
          ldy #$ff                   ;start at beginning of enemy slots
BB_SLoop: iny                        ;move onto the next slot
          cpy #$05                   ;branch to play sound if we've done all slots
          bcs FireBulletBill
          lda Enemy_Flag,y           ;if enemy buffer flag not set,
          beq BB_SLoop               ;loop back and check another slot
          lda Enemy_ID,y
          cmp #BulletBill_FrenzyVar  ;check enemy identifier for
          bne BB_SLoop               ;bullet bill object (frenzy variant)
ExF17:    rts                        ;if found, leave

FireBulletBill:
      lda Square2SoundQueue
      ora #Sfx_Blast            ;play fireworks/gunfire sound
      sta Square2SoundQueue
      lda #BulletBill_FrenzyVar ;load identifier for bullet bill object
      bne Set17ID               ;unconditional branch

;--------------------------------
;$00 - used to store Y position of group enemies
;$01 - used to store enemy ID
;$02 - used to store page location of right side of screen
;$03 - used to store X position of right side of screen

HandleGroupEnemies:
        ldy #$00                  ;load value for green koopa troopa
        sec
        sbc #$37                  ;subtract $37 from second byte read
        pha                       ;save result in stack for now
        cmp #$04                  ;was byte in $3b-$3e range?
        bcs SnglID                ;if so, branch
        pha                       ;save another copy to stack
        ldy #Goomba               ;load value for goomba enemy
        lda PrimaryHardMode       ;if primary hard mode flag not set,
        beq PullID                ;branch, otherwise change to value
        ldy #BuzzyBeetle          ;for buzzy beetle
PullID: pla                       ;get second copy from stack
SnglID: sty $01                   ;save enemy id here
        ldy #$b0                  ;load default y coordinate
        and #$02                  ;check to see if d1 was set
        beq SetYGp                ;if so, move y coordinate up,
        ldy #$70                  ;otherwise branch and use default
SetYGp: sty $00                   ;save y coordinate here
        lda ScreenRight_PageLoc   ;get page number of right edge of screen
        sta $02                   ;save here
        lda ScreenRight_X_Pos     ;get pixel coordinate of right edge
        sta $03                   ;save here
        ldy #$02                  ;load two enemies by default
        pla                       ;get first copy from stack
        lsr                       ;check to see if d0 was set
        bcc CntGrp                ;if not, use default value
        iny                       ;otherwise increment to three enemies
CntGrp: sty NumberofGroupEnemies  ;save number of enemies here
GrLoop: ldx #$ff                  ;start at beginning of enemy buffers
GSltLp: inx                       ;increment and branch if past
        cpx #$05                  ;end of buffers
        bcs NextED
        lda Enemy_Flag,x          ;check to see if enemy is already
        bne GSltLp                ;stored in buffer, and branch if so
        lda $01
        sta Enemy_ID,x            ;store enemy object identifier
        lda $02
        sta Enemy_PageLoc,x       ;store page location for enemy object
        lda $03
        sta Enemy_X_Position,x    ;store x coordinate for enemy object
        clc
        adc #$18                  ;add 24 pixels for next enemy
        sta $03
        lda $02                   ;add carry to page location for
        adc #$00                  ;next enemy
        sta $02
        lda $00                   ;store y coordinate for enemy object
        sta Enemy_Y_Position,x
        lda #$01                  ;activate flag for buffer, and
        sta Enemy_Y_HighPos,x     ;put enemy within the screen vertically
        sta Enemy_Flag,x
        jsr CheckpointEnemyID     ;process each enemy object separately
        dec NumberofGroupEnemies  ;do this until we run out of enemy objects
        bne GrLoop
NextED: jmp Inc2B                 ;jump to increment data offset and leave

;--------------------------------

InitPiranhaPlant:
      lda #$01                     ;set initial speed
      sta PiranhaPlant_Y_Speed,x
      lsr
      sta Enemy_State,x            ;initialize enemy state and what would normally
      sta PiranhaPlant_MoveFlag,x  ;be used as vertical speed, but not in this case
      lda Enemy_Y_Position,x
      sta PiranhaPlantDownYPos,x   ;save original vertical coordinate here
      sec
      sbc #$18
      sta PiranhaPlantUpYPos,x     ;save original vertical coordinate - 24 pixels here
      lda #$09
      jmp SetBBox2                 ;set specific value for bounding box control

;--------------------------------

InitEnemyFrenzy:
      lda Enemy_ID,x        ;load enemy identifier
      sta EnemyFrenzyBuffer ;save in enemy frenzy buffer
      sec
      sbc #$12              ;subtract 12 and use as offset for jump engine
      jsr JumpEngine

;frenzy object jump table
      .word LakituAndSpinyHandler
      .word NoFrenzyCode
      .word InitFlyingCheepCheep
      .word InitBowserFlame
      .word InitFireworks
      .word BulletBillCheepCheep

;--------------------------------

NoFrenzyCode:
      rts

;--------------------------------

EndFrenzy:
           ldy #$05               ;start at last slot
LakituChk: lda Enemy_ID,y         ;check enemy identifiers
           cmp #Lakitu            ;for lakitu
           bne NextFSlot
           lda #$01               ;if found, set state
           sta Enemy_State,y
NextFSlot: dey                    ;move onto the next slot
           bpl LakituChk          ;do this until all slots are checked
           lda #$00
           sta EnemyFrenzyBuffer  ;empty enemy frenzy buffer
           sta Enemy_Flag,x       ;disable enemy buffer flag for this object
           rts

;--------------------------------

InitJumpGPTroopa:
           lda #$02                  ;set for movement to the left
           sta Enemy_MovingDir,x
           lda #$f8                  ;set horizontal speed
           sta Enemy_X_Speed,x
TallBBox2: lda #$03                  ;set specific value for bounding box control
SetBBox2:  sta Enemy_BoundBoxCtrl,x  ;set bounding box control then leave
           rts

;--------------------------------

InitBalPlatform:
        dec Enemy_Y_Position,x    ;raise vertical position by two pixels
        dec Enemy_Y_Position,x
        ldy SecondaryHardMode     ;if secondary hard mode flag not set,
        bne AlignP                ;branch ahead
        ldy #$02                  ;otherwise set value here
        jsr PosPlatform           ;do a sub to add or subtract pixels
AlignP: ldy #$ff                  ;set default value here for now
        lda BalPlatformAlignment  ;get current balance platform alignment
        sta Enemy_State,x         ;set platform alignment to object state here
        bpl SetBPA                ;if old alignment $ff, put $ff as alignment for negative
        txa                       ;if old contents already $ff, put
        tay                       ;object offset as alignment to make next positive
SetBPA: sty BalPlatformAlignment  ;store whatever value's in Y here
        lda #$00
        sta Enemy_MovingDir,x     ;init moving direction
        tay                       ;init Y
        jsr PosPlatform           ;do a sub to add 8 pixels, then run shared code here

;--------------------------------

InitDropPlatform:
      lda #$ff
      sta PlatformCollisionFlag,x  ;set some value here
      jmp CommonPlatCode           ;then jump ahead to execute more code

;--------------------------------

InitHoriPlatform:
      lda #$00
      sta XMoveSecondaryCounter,x  ;init one of the moving counters
      jmp CommonPlatCode           ;jump ahead to execute more code

;--------------------------------

InitVertPlatform:
       ldy #$40                    ;set default value here
       lda Enemy_Y_Position,x      ;check vertical position
       bpl SetYO                   ;if above a certain point, skip this part
       eor #$ff
       clc                         ;otherwise get two's compliment
       adc #$01
       ldy #$c0                    ;get alternate value to add to vertical position
SetYO: sta YPlatformTopYPos,x      ;save as top vertical position
       tya
       clc                         ;load value from earlier, add number of pixels
       adc Enemy_Y_Position,x      ;to vertical position
       sta YPlatformCenterYPos,x   ;save result as central vertical position

;--------------------------------

CommonPlatCode:
        jsr InitVStf              ;do a sub to init certain other values
SPBBox: lda #$05                  ;set default bounding box size control
        ldy AreaType
        cpy #$03                  ;check for castle-type level
        beq CasPBB                ;use default value if found
        ldy SecondaryHardMode     ;otherwise check for secondary hard mode flag
        bne CasPBB                ;if set, use default value
        lda #$06                  ;use alternate value if not castle or secondary not set
CasPBB: sta Enemy_BoundBoxCtrl,x  ;set bounding box size control here and leave
        rts

;--------------------------------

LargeLiftUp:
      jsr PlatLiftUp       ;execute code for platforms going up
      jmp LargeLiftBBox    ;overwrite bounding box for large platforms

LargeLiftDown:
      jsr PlatLiftDown     ;execute code for platforms going down

LargeLiftBBox:
      jmp SPBBox           ;jump to overwrite bounding box size control

;--------------------------------

PlatLiftUp:
      lda #$10                 ;set movement amount here
      sta Enemy_Y_MoveForce,x
      lda #$ff                 ;set moving speed for platforms going up
      sta Enemy_Y_Speed,x
      jmp CommonSmallLift      ;skip ahead to part we should be executing

;--------------------------------

PlatLiftDown:
      lda #$f0                 ;set movement amount here
      sta Enemy_Y_MoveForce,x
      lda #$00                 ;set moving speed for platforms going down
      sta Enemy_Y_Speed,x

;--------------------------------

CommonSmallLift:
      ldy #$01
      jsr PosPlatform           ;do a sub to add 12 pixels due to preset value
      lda #$04
      sta Enemy_BoundBoxCtrl,x  ;set bounding box control for small platforms
      rts

;--------------------------------

PlatPosDataLow:
      .byte $08,$0c,$f8

PlatPosDataHigh:
      .byte $00,$00,$ff

PosPlatform:
      lda Enemy_X_Position,x  ;get horizontal coordinate
      clc
      adc PlatPosDataLow,y    ;add or subtract pixels depending on offset
      sta Enemy_X_Position,x  ;store as new horizontal coordinate
      lda Enemy_PageLoc,x
      adc PlatPosDataHigh,y   ;add or subtract page location depending on offset
      sta Enemy_PageLoc,x     ;store as new page location
      rts                     ;and go back

;--------------------------------

EndOfEnemyInitCode:
      rts
