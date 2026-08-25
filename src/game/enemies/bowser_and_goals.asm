;-------------------------------------------------------------------------------------
;$04-$05 - used to store name table address in little endian order

BridgeCollapseData:
      .byte $1a ;axe
      .byte $58 ;chain
      .byte $98, $96, $94, $92, $90, $8e, $8c ;bridge
      .byte $8a, $88, $86, $84, $82, $80

BridgeCollapse:
       ldx BowserFront_Offset    ;get enemy offset for bowser
       lda Enemy_ID,x            ;check enemy object identifier for bowser
       cmp #Bowser               ;if not found, branch ahead,
       bne SetM2                 ;metatile removal not necessary
       stx ObjectOffset          ;store as enemy offset here
       lda Enemy_State,x         ;if bowser in normal state, skip all of this
       beq RemoveBridge
       and #%01000000            ;if bowser's state has d6 clear, skip to silence music
       beq SetM2
       lda Enemy_Y_Position,x    ;check bowser's vertical coordinate
       cmp #$e0                  ;if bowser not yet low enough, skip this part ahead
       bcc MoveD_Bowser
SetM2: lda #Silence              ;silence music
       sta EventMusicQueue
       inc OperMode_Task         ;move onto next secondary mode in autoctrl mode
       jmp KillAllEnemies        ;jump to empty all enemy slots and then leave

MoveD_Bowser:
       jsr MoveEnemySlowVert     ;do a sub to move bowser downwards
       jmp BowserGfxHandler      ;jump to draw bowser's front and rear, then leave

RemoveBridge:
         dec BowserFeetCounter     ;decrement timer to control bowser's feet
         bne NoBFall               ;if not expired, skip all of this
         lda #$04
         sta BowserFeetCounter     ;otherwise, set timer now
         lda BowserBodyControls
         eor #$01                  ;invert bit to control bowser's feet
         sta BowserBodyControls
         lda #$22                  ;put high byte of name table address here for now
         sta $05
         ldy BridgeCollapseOffset  ;get bridge collapse offset here
         lda BridgeCollapseData,y  ;load low byte of name table address and store here
         sta $04
         ldy VRAM_Buffer1_Offset   ;increment vram buffer offset
         iny
         ldx #$0c                  ;set offset for tile data for sub to draw blank metatile
         jsr RemBridge             ;do sub here to remove bowser's bridge metatiles
         ldx ObjectOffset          ;get enemy offset
         jsr MoveVOffset           ;set new vram buffer offset
         lda #Sfx_Blast            ;load the fireworks/gunfire sound into the square 2 sfx
         sta Square2SoundQueue     ;queue while at the same time loading the brick
         lda #Sfx_BrickShatter     ;shatter sound into the noise sfx queue thus
         sta NoiseSoundQueue       ;producing the unique sound of the bridge collapsing
         inc BridgeCollapseOffset  ;increment bridge collapse offset
         lda BridgeCollapseOffset
         cmp #$0f                  ;if bridge collapse offset has not yet reached
         bne NoBFall               ;the end, go ahead and skip this part
         jsr InitVStf              ;initialize whatever vertical speed bowser has
         lda #%01000000
         sta Enemy_State,x         ;set bowser's state to one of defeated states (d6 set)
         lda #Sfx_BowserFall
         sta Square2SoundQueue     ;play bowser defeat sound
NoBFall: jmp BowserGfxHandler      ;jump to code that draws bowser

;--------------------------------

PRandomRange:
      .byte $21, $41, $11, $31

RunBowser:
      lda Enemy_State,x       ;if d5 in enemy state is not set
      and #%00100000          ;then branch elsewhere to run bowser
      beq BowserControl
      lda Enemy_Y_Position,x  ;otherwise check vertical position
      cmp #$e0                ;if above a certain point, branch to move defeated bowser
      bcc MoveD_Bowser        ;otherwise proceed to KillAllEnemies

KillAllEnemies:
          ldx #$04              ;start with last enemy slot
KillLoop: jsr EraseEnemyObject  ;branch to kill enemy objects
          dex                   ;move onto next enemy slot
          bpl KillLoop          ;do this until all slots are emptied
          sta EnemyFrenzyBuffer ;empty frenzy buffer
          ldx ObjectOffset      ;get enemy object offset and leave
          rts

BowserControl:
           lda #$00
           sta EnemyFrenzyBuffer      ;empty frenzy buffer
           lda TimerControl           ;if master timer control not set,
           beq ChkMouth               ;skip jump and execute code here
           jmp SkipToFB               ;otherwise, jump over a bunch of code
ChkMouth:  lda BowserBodyControls     ;check bowser's mouth
           bpl FeetTmr                ;if bit clear, go ahead with code here
           jmp HammerChk              ;otherwise skip a whole section starting here
FeetTmr:   dec BowserFeetCounter      ;decrement timer to control bowser's feet
           bne ResetMDr               ;if not expired, skip this part
           lda #$20                   ;otherwise, reset timer
           sta BowserFeetCounter
           lda BowserBodyControls     ;and invert bit used
           eor #%00000001             ;to control bowser's feet
           sta BowserBodyControls
ResetMDr:  lda FrameCounter           ;check frame counter
           and #%00001111             ;if not on every sixteenth frame, skip
           bne B_FaceP                ;ahead to continue code
           lda #$02                   ;otherwise reset moving/facing direction every
           sta Enemy_MovingDir,x      ;sixteen frames
B_FaceP:   lda EnemyFrameTimer,x      ;if timer set here expired,
           beq GetPRCmp               ;branch to next section
           jsr PlayerEnemyDiff        ;get horizontal difference between player and bowser,
           bpl GetPRCmp               ;and branch if bowser to the right of the player
           lda #$01
           sta Enemy_MovingDir,x      ;set bowser to move and face to the right
           lda #$02
           sta BowserMovementSpeed    ;set movement speed
           lda #$20
           sta EnemyFrameTimer,x      ;set timer here
           sta BowserFireBreathTimer  ;set timer used for bowser's flame
           lda Enemy_X_Position,x
           cmp #$c8                   ;if bowser to the right past a certain point,
           bcs HammerChk              ;skip ahead to some other section
GetPRCmp:  lda FrameCounter           ;get frame counter
           and #%00000011
           bne HammerChk              ;execute this code every fourth frame, otherwise branch
           lda Enemy_X_Position,x
           cmp BowserOrigXPos         ;if bowser not at original horizontal position,
           bne GetDToO                ;branch to skip this part
           lda PseudoRandomBitReg,x
           and #%00000011             ;get pseudorandom offset
           tay
           lda PRandomRange,y         ;load value using pseudorandom offset
           sta MaxRangeFromOrigin     ;and store here
GetDToO:   lda Enemy_X_Position,x
           clc                        ;add movement speed to bowser's horizontal
           adc BowserMovementSpeed    ;coordinate and save as new horizontal position
           sta Enemy_X_Position,x
           ldy Enemy_MovingDir,x
           cpy #$01                   ;if bowser moving and facing to the right, skip ahead
           beq HammerChk
           ldy #$ff                   ;set default movement speed here (move left)
           sec                        ;get difference of current vs. original
           sbc BowserOrigXPos         ;horizontal position
           bpl CompDToO               ;if current position to the right of original, skip ahead
           eor #$ff
           clc                        ;get two's compliment
           adc #$01
           ldy #$01                   ;set alternate movement speed here (move right)
CompDToO:  cmp MaxRangeFromOrigin     ;compare difference with pseudorandom value
           bcc HammerChk              ;if difference < pseudorandom value, leave speed alone
           sty BowserMovementSpeed    ;otherwise change bowser's movement speed
HammerChk: lda EnemyFrameTimer,x      ;if timer set here not expired yet, skip ahead to
           bne MakeBJump              ;some other section of code
           jsr MoveEnemySlowVert      ;otherwise start by moving bowser downwards
           lda WorldNumber            ;check world number
           cmp #World6
           bcc SetHmrTmr              ;if world 1-5, skip this part (not time to throw hammers yet)
           lda FrameCounter
           and #%00000011             ;check to see if it's time to execute sub
           bne SetHmrTmr              ;if not, skip sub, otherwise
           jsr SpawnHammerObj         ;execute sub on every fourth frame to spawn misc object (hammer)
SetHmrTmr: lda Enemy_Y_Position,x     ;get current vertical position
           cmp #$80                   ;if still above a certain point
           bcc ChkFireB               ;then skip to world number check for flames
           lda PseudoRandomBitReg,x
           and #%00000011             ;get pseudorandom offset
           tay
           lda PRandomRange,y         ;get value using pseudorandom offset
           sta EnemyFrameTimer,x      ;set for timer here
SkipToFB:  jmp ChkFireB               ;jump to execute flames code
MakeBJump: cmp #$01                   ;if timer not yet about to expire,
           bne ChkFireB               ;skip ahead to next part
           dec Enemy_Y_Position,x     ;otherwise decrement vertical coordinate
           jsr InitVStf               ;initialize movement amount
           lda #$fe
           sta Enemy_Y_Speed,x        ;set vertical speed to move bowser upwards
ChkFireB:  lda WorldNumber            ;check world number here
           cmp #World8                ;world 8?
           beq SpawnFBr               ;if so, execute this part here
           cmp #World6                ;world 6-7?
           bcs BowserGfxHandler       ;if so, skip this part here
SpawnFBr:  lda BowserFireBreathTimer  ;check timer here
           bne BowserGfxHandler       ;if not expired yet, skip all of this
           lda #$20
           sta BowserFireBreathTimer  ;set timer here
           lda BowserBodyControls
           eor #%10000000             ;invert bowser's mouth bit to open
           sta BowserBodyControls     ;and close bowser's mouth
           bmi ChkFireB               ;if bowser's mouth open, loop back
           jsr SetFlameTimer          ;get timing for bowser's flame
           ldy SecondaryHardMode
           beq SetFBTmr               ;if secondary hard mode flag not set, skip this
           sec
           sbc #$10                   ;otherwise subtract from value in A
SetFBTmr:  sta BowserFireBreathTimer  ;set value as timer here
           lda #BowserFlame           ;put bowser's flame identifier
           sta EnemyFrenzyBuffer      ;in enemy frenzy buffer

;--------------------------------

BowserGfxHandler:
          jsr ProcessBowserHalf    ;do a sub here to process bowser's front
          ldy #$10                 ;load default value here to position bowser's rear
          lda Enemy_MovingDir,x    ;check moving direction
          lsr
          bcc CopyFToR             ;if moving left, use default
          ldy #$f0                 ;otherwise load alternate positioning value here
CopyFToR: tya                      ;move bowser's rear object position value to A
          clc
          adc Enemy_X_Position,x   ;add to bowser's front object horizontal coordinate
          ldy DuplicateObj_Offset  ;get bowser's rear object offset
          sta Enemy_X_Position,y   ;store A as bowser's rear horizontal coordinate
          lda Enemy_Y_Position,x
          clc                      ;add eight pixels to bowser's front object
          adc #$08                 ;vertical coordinate and store as vertical coordinate
          sta Enemy_Y_Position,y   ;for bowser's rear
          lda Enemy_State,x
          sta Enemy_State,y        ;copy enemy state directly from front to rear
          lda Enemy_MovingDir,x
          sta Enemy_MovingDir,y    ;copy moving direction also
          lda ObjectOffset         ;save enemy object offset of front to stack
          pha
          ldx DuplicateObj_Offset  ;put enemy object offset of rear as current
          stx ObjectOffset
          lda #Bowser              ;set bowser's enemy identifier
          sta Enemy_ID,x           ;store in bowser's rear object
          jsr ProcessBowserHalf    ;do a sub here to process bowser's rear
          pla
          sta ObjectOffset         ;get original enemy object offset
          tax
          lda #$00                 ;nullify bowser's front/rear graphics flag
          sta BowserGfxFlag
ExBGfxH:  rts                      ;leave!

ProcessBowserHalf:
      inc BowserGfxFlag         ;increment bowser's graphics flag, then run subroutines
      jsr RunRetainerObj        ;to get offscreen bits, relative position and draw bowser (finally!)
      lda Enemy_State,x
      bne ExBGfxH               ;if either enemy object not in normal state, branch to leave
      lda #$0a
      sta Enemy_BoundBoxCtrl,x  ;set bounding box size control
      jsr GetEnemyBoundBox      ;get bounding box coordinates
      jmp PlayerEnemyCollision  ;do player-to-enemy collision detection

;-------------------------------------------------------------------------------------
;$00 - used to hold movement force and tile number
;$01 - used to hold sprite attribute data

FlameTimerData:
      .byte $bf, $40, $bf, $bf, $bf, $40, $40, $bf

SetFlameTimer:
      ldy BowserFlameTimerCtrl  ;load counter as offset
      inc BowserFlameTimerCtrl  ;increment
      lda BowserFlameTimerCtrl  ;mask out all but 3 LSB
      and #%00000111            ;to keep in range of 0-7
      sta BowserFlameTimerCtrl
      lda FlameTimerData,y      ;load value to be used then leave
ExFl: rts

ProcBowserFlame:
         lda TimerControl            ;if master timer control flag set,
         bne SetGfxF                 ;skip all of this
         lda #$40                    ;load default movement force
         ldy SecondaryHardMode
         beq SFlmX                   ;if secondary hard mode flag not set, use default
         lda #$60                    ;otherwise load alternate movement force to go faster
SFlmX:   sta $00                     ;store value here
         lda Enemy_X_MoveForce,x
         sec                         ;subtract value from movement force
         sbc $00
         sta Enemy_X_MoveForce,x     ;save new value
         lda Enemy_X_Position,x
         sbc #$01                    ;subtract one from horizontal position to move
         sta Enemy_X_Position,x      ;to the left
         lda Enemy_PageLoc,x
         sbc #$00                    ;subtract borrow from page location
         sta Enemy_PageLoc,x
         ldy BowserFlamePRandomOfs,x ;get some value here and use as offset
         lda Enemy_Y_Position,x      ;load vertical coordinate
         cmp FlameYPosData,y         ;compare against coordinate data using $0417,x as offset
         beq SetGfxF                 ;if equal, branch and do not modify coordinate
         clc
         adc Enemy_Y_MoveForce,x     ;otherwise add value here to coordinate and store
         sta Enemy_Y_Position,x      ;as new vertical coordinate
SetGfxF: jsr RelativeEnemyPosition   ;get new relative coordinates
         lda Enemy_State,x           ;if bowser's flame not in normal state,
         bne ExFl                    ;branch to leave
         lda #$51                    ;otherwise, continue
         sta $00                     ;write first tile number
         ldy #$02                    ;load attributes without vertical flip by default
         lda FrameCounter
         and #%00000010              ;invert vertical flip bit every 2 frames
         beq FlmeAt                  ;if d1 not set, write default value
         ldy #$82                    ;otherwise write value with vertical flip bit set
FlmeAt:  sty $01                     ;set bowser's flame sprite attributes here
         ldy Enemy_SprDataOffset,x   ;get OAM data offset
         ldx #$00

DrawFlameLoop:
         lda Enemy_Rel_YPos         ;get Y relative coordinate of current enemy object
         sta Sprite_Y_Position,y    ;write into Y coordinate of OAM data
         lda $00
         sta Sprite_Tilenumber,y    ;write current tile number into OAM data
         inc $00                    ;increment tile number to draw more bowser's flame
         lda $01
         sta Sprite_Attributes,y    ;write saved attributes into OAM data
         lda Enemy_Rel_XPos
         sta Sprite_X_Position,y    ;write X relative coordinate of current enemy object
         clc
         adc #$08
         sta Enemy_Rel_XPos         ;then add eight to it and store
         iny
         iny
         iny
         iny                        ;increment Y four times to move onto the next OAM
         inx                        ;move onto the next OAM, and branch if three
         cpx #$03                   ;have not yet been done
         bcc DrawFlameLoop
         ldx ObjectOffset           ;reload original enemy offset
         jsr GetEnemyOffscreenBits  ;get offscreen information
         ldy Enemy_SprDataOffset,x  ;get OAM data offset
         lda Enemy_OffscreenBits    ;get enemy object offscreen bits
         lsr                        ;move d0 to carry and result to stack
         pha
         bcc M3FOfs                 ;branch if carry not set
         lda #$f8                   ;otherwise move sprite offscreen, this part likely
         sta Sprite_Y_Position+12,y ;residual since flame is only made of three sprites
M3FOfs:  pla                        ;get bits from stack
         lsr                        ;move d1 to carry and move bits back to stack
         pha
         bcc M2FOfs                 ;branch if carry not set again
         lda #$f8                   ;otherwise move third sprite offscreen
         sta Sprite_Y_Position+8,y
M2FOfs:  pla                        ;get bits from stack again
         lsr                        ;move d2 to carry and move bits back to stack again
         pha
         bcc M1FOfs                 ;branch if carry not set yet again
         lda #$f8                   ;otherwise move second sprite offscreen
         sta Sprite_Y_Position+4,y
M1FOfs:  pla                        ;get bits from stack one last time
         lsr                        ;move d3 to carry
         bcc ExFlmeD                ;branch if carry not set one last time
         lda #$f8
         sta Sprite_Y_Position,y    ;otherwise move first sprite offscreen
ExFlmeD: rts                        ;leave

;--------------------------------

RunFireworks:
           dec ExplosionTimerCounter,x ;decrement explosion timing counter here
           bne SetupExpl               ;if not expired, skip this part
           lda #$08
           sta ExplosionTimerCounter,x ;reset counter
           inc ExplosionGfxCounter,x   ;increment explosion graphics counter
           lda ExplosionGfxCounter,x
           cmp #$03                    ;check explosion graphics counter
           bcs FireworksSoundScore     ;if at a certain point, branch to kill this object
SetupExpl: jsr RelativeEnemyPosition   ;get relative coordinates of explosion
           lda Enemy_Rel_YPos          ;copy relative coordinates
           sta Fireball_Rel_YPos       ;from the enemy object to the fireball object
           lda Enemy_Rel_XPos          ;first vertical, then horizontal
           sta Fireball_Rel_XPos
           ldy Enemy_SprDataOffset,x   ;get OAM data offset
           lda ExplosionGfxCounter,x   ;get explosion graphics counter
           jsr DrawExplosion_Fireworks ;do a sub to draw the explosion then leave
           rts

FireworksSoundScore:
      lda #$00               ;disable enemy buffer flag
      sta Enemy_Flag,x
      lda #Sfx_Blast         ;play fireworks/gunfire sound
      sta Square2SoundQueue
      lda #$05               ;set part of score modifier for 500 points
      sta DigitModifier+4
      jmp EndAreaPoints     ;jump to award points accordingly then leave

;--------------------------------

StarFlagYPosAdder:
      .byte $00, $00, $08, $08

StarFlagXPosAdder:
      .byte $00, $08, $00, $08

StarFlagTileData:
      .byte $54, $55, $56, $57

RunStarFlagObj:
      lda #$00                 ;initialize enemy frenzy buffer
      sta EnemyFrenzyBuffer
      lda StarFlagTaskControl  ;check star flag object task number here
      cmp #$05                 ;if greater than 5, branch to exit
      bcs StarFlagExit
      jsr JumpEngine           ;otherwise jump to appropriate sub

      .word StarFlagExit
      .word GameTimerFireworks
      .word AwardGameTimerPoints
      .word RaiseFlagSetoffFWorks
      .word DelayToAreaEnd

GameTimerFireworks:
        ldy #$05               ;set default state for star flag object
        lda GameTimerDisplay+2 ;get game timer's last digit
        cmp #$01
        beq SetFWC             ;if last digit of game timer set to 1, skip ahead
        ldy #$03               ;otherwise load new value for state
        cmp #$03
        beq SetFWC             ;if last digit of game timer set to 3, skip ahead
        ldy #$00               ;otherwise load one more potential value for state
        cmp #$06
        beq SetFWC             ;if last digit of game timer set to 6, skip ahead
        lda #$ff               ;otherwise set value for no fireworks
SetFWC: sta FireworksCounter   ;set fireworks counter here
        sty Enemy_State,x      ;set whatever state we have in star flag object

IncrementSFTask1:
      inc StarFlagTaskControl  ;increment star flag object task number

StarFlagExit:
      rts                      ;leave

AwardGameTimerPoints:
         lda GameTimerDisplay   ;check all game timer digits for any intervals left
         ora GameTimerDisplay+1
         ora GameTimerDisplay+2
         beq IncrementSFTask1   ;if no time left on game timer at all, branch to next task
         lda FrameCounter
         and #%00000100         ;check frame counter for d2 set (skip ahead
         beq NoTTick            ;for four frames every four frames) branch if not set
         lda #Sfx_TimerTick
         sta Square2SoundQueue  ;load timer tick sound
NoTTick: ldy #$23               ;set offset here to subtract from game timer's last digit
         lda #$ff               ;set adder here to $ff, or -1, to subtract one
         sta DigitModifier+5    ;from the last digit of the game timer
         jsr DigitsMathRoutine  ;subtract digit
         lda #$05               ;set now to add 50 points
         sta DigitModifier+5    ;per game timer interval subtracted

EndAreaPoints:
         ldy #$0b               ;load offset for mario's score by default
         lda CurrentPlayer      ;check player on the screen
         beq ELPGive            ;if mario, do not change
         ldy #$11               ;otherwise load offset for luigi's score
ELPGive: jsr DigitsMathRoutine  ;award 50 points per game timer interval
         lda CurrentPlayer      ;get player on the screen (or 500 points per
         asl                    ;fireworks explosion if branched here from there)
         asl                    ;shift to high nybble
         asl
         asl
         ora #%00000100         ;add four to set nybble for game timer
         jmp UpdateNumber       ;jump to print the new score and game timer

RaiseFlagSetoffFWorks:
         lda Enemy_Y_Position,x  ;check star flag's vertical position
         cmp #$72                ;against preset value
         bcc SetoffF             ;if star flag higher vertically, branch to other code
         dec Enemy_Y_Position,x  ;otherwise, raise star flag by one pixel
         jmp DrawStarFlag        ;and skip this part here
SetoffF: lda FireworksCounter    ;check fireworks counter
         beq DrawFlagSetTimer    ;if no fireworks left to go off, skip this part
         bmi DrawFlagSetTimer    ;if no fireworks set to go off, skip this part
         lda #Fireworks
         sta EnemyFrenzyBuffer   ;otherwise set fireworks object in frenzy queue

DrawStarFlag:
         jsr RelativeEnemyPosition  ;get relative coordinates of star flag
         ldy Enemy_SprDataOffset,x  ;get OAM data offset
         ldx #$03                   ;do four sprites
DSFLoop: lda Enemy_Rel_YPos         ;get relative vertical coordinate
         clc
         adc StarFlagYPosAdder,x    ;add Y coordinate adder data
         sta Sprite_Y_Position,y    ;store as Y coordinate
         lda StarFlagTileData,x     ;get tile number
         sta Sprite_Tilenumber,y    ;store as tile number
         lda #$22                   ;set palette and background priority bits
         sta Sprite_Attributes,y    ;store as attributes
         lda Enemy_Rel_XPos         ;get relative horizontal coordinate
         clc
         adc StarFlagXPosAdder,x    ;add X coordinate adder data
         sta Sprite_X_Position,y    ;store as X coordinate
         iny
         iny                        ;increment OAM data offset four bytes
         iny                        ;for next sprite
         iny
         dex                        ;move onto next sprite
         bpl DSFLoop                ;do this until all sprites are done
         ldx ObjectOffset           ;get enemy object offset and leave
         rts

DrawFlagSetTimer:
      jsr DrawStarFlag          ;do sub to draw star flag
      lda #$06
      sta EnemyIntervalTimer,x  ;set interval timer here

IncrementSFTask2:
      inc StarFlagTaskControl   ;move onto next task
      rts

DelayToAreaEnd:
      jsr DrawStarFlag          ;do sub to draw star flag
      lda EnemyIntervalTimer,x  ;if interval timer set in previous task
      bne StarFlagExit2         ;not yet expired, branch to leave
      lda EventMusicBuffer      ;if event music buffer empty,
      beq IncrementSFTask2      ;branch to increment task

StarFlagExit2:
      rts                       ;otherwise leave

;--------------------------------
;$00 - used to store horizontal difference between player and piranha plant

MovePiranhaPlant:
      lda Enemy_State,x           ;check enemy state
      bne PutinPipe               ;if set at all, branch to leave
      lda EnemyFrameTimer,x       ;check enemy's timer here
      bne PutinPipe               ;branch to end if not yet expired
      lda PiranhaPlant_MoveFlag,x ;check movement flag
      bne SetupToMovePPlant       ;if moving, skip to part ahead
      lda PiranhaPlant_Y_Speed,x  ;if currently rising, branch
      bmi ReversePlantSpeed       ;to move enemy upwards out of pipe
      jsr PlayerEnemyDiff         ;get horizontal difference between player and
      bpl ChkPlayerNearPipe       ;piranha plant, and branch if enemy to right of player
      lda $00                     ;otherwise get saved horizontal difference
      eor #$ff
      clc                         ;and change to two's compliment
      adc #$01
      sta $00                     ;save as new horizontal difference

ChkPlayerNearPipe:
      lda $00                     ;get saved horizontal difference
      cmp #$21
      bcc PutinPipe               ;if player within a certain distance, branch to leave

ReversePlantSpeed:
      lda PiranhaPlant_Y_Speed,x  ;get vertical speed
      eor #$ff
      clc                         ;change to two's compliment
      adc #$01
      sta PiranhaPlant_Y_Speed,x  ;save as new vertical speed
      inc PiranhaPlant_MoveFlag,x ;increment to set movement flag

SetupToMovePPlant:
      lda PiranhaPlantDownYPos,x  ;get original vertical coordinate (lowest point)
      ldy PiranhaPlant_Y_Speed,x  ;get vertical speed
      bpl RiseFallPiranhaPlant    ;branch if moving downwards
      lda PiranhaPlantUpYPos,x    ;otherwise get other vertical coordinate (highest point)

RiseFallPiranhaPlant:
      sta $00                     ;save vertical coordinate here
      lda FrameCounter            ;get frame counter
      lsr
      bcc PutinPipe               ;branch to leave if d0 set (execute code every other frame)
      lda TimerControl            ;get master timer control
      bne PutinPipe               ;branch to leave if set (likely not necessary)
      lda Enemy_Y_Position,x      ;get current vertical coordinate
      clc
      adc PiranhaPlant_Y_Speed,x  ;add vertical speed to move up or down
      sta Enemy_Y_Position,x      ;save as new vertical coordinate
      cmp $00                     ;compare against low or high coordinate
      bne PutinPipe               ;branch to leave if not yet reached
      lda #$00
      sta PiranhaPlant_MoveFlag,x ;otherwise clear movement flag
      lda #$40
      sta EnemyFrameTimer,x       ;set timer to delay piranha plant movement

PutinPipe:
      lda #%00100000              ;set background priority bit in sprite
      sta Enemy_SprAttrib,x       ;attributes to give illusion of being inside pipe
      rts                         ;then leave

;-------------------------------------------------------------------------------------
;$07 - spinning speed

FirebarSpin:
      sta $07                     ;save spinning speed here
      lda FirebarSpinDirection,x  ;check spinning direction
      bne SpinCounterClockwise    ;if moving counter-clockwise, branch to other part
      ldy #$18                    ;possibly residual ldy
      lda FirebarSpinState_Low,x
      clc                         ;add spinning speed to what would normally be
      adc $07                     ;the horizontal speed
      sta FirebarSpinState_Low,x
      lda FirebarSpinState_High,x ;add carry to what would normally be the vertical speed
      adc #$00
      rts

SpinCounterClockwise:
      ldy #$08                    ;possibly residual ldy
      lda FirebarSpinState_Low,x
      sec                         ;subtract spinning speed to what would normally be
      sbc $07                     ;the horizontal speed
      sta FirebarSpinState_Low,x
      lda FirebarSpinState_High,x ;add carry to what would normally be the vertical speed
      sbc #$00
      rts
