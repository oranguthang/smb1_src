;-------------------------------------------------------------------------------------
;$00 - used to store downward movement force in FireballObjCore
;$02 - used to store maximum vertical speed in FireballObjCore
;$07 - used to store pseudorandom bit in BubbleCheck

ProcFireball_Bubble:
      lda PlayerStatus           ;check player's status
      cmp #$02
      bcc ProcAirBubbles         ;if not fiery, branch
      lda A_B_Buttons
      and #B_Button              ;check for b button pressed
      beq ProcFireballs          ;branch if not pressed
      and PreviousA_B_Buttons
      bne ProcFireballs          ;if button pressed in previous frame, branch
      lda FireballCounter        ;load fireball counter
      and #%00000001             ;get LSB and use as offset for buffer
      tax
      lda Fireball_State,x       ;load fireball state
      bne ProcFireballs          ;if not inactive, branch
      ldy Player_Y_HighPos       ;if player too high or too low, branch
      dey
      bne ProcFireballs
      lda CrouchingFlag          ;if player crouching, branch
      bne ProcFireballs
      lda Player_State           ;if player's state = climbing, branch
      cmp #$03
      beq ProcFireballs
      lda #Sfx_Fireball          ;play fireball sound effect
      sta Square1SoundQueue
      lda #$02                   ;load state
      sta Fireball_State,x
      ldy PlayerAnimTimerSet     ;copy animation frame timer setting
      sty FireballThrowingTimer  ;into fireball throwing timer
      dey
      sty PlayerAnimTimer        ;decrement and store in player's animation timer
      inc FireballCounter        ;increment fireball counter

ProcFireballs:
      ldx #$00
      jsr FireballObjCore  ;process first fireball object
      ldx #$01
      jsr FireballObjCore  ;process second fireball object, then do air bubbles

ProcAirBubbles:
          lda AreaType                ;if not water type level, skip the rest of this
          bne BublExit
          ldx #$02                    ;otherwise load counter and use as offset
BublLoop: stx ObjectOffset            ;store offset
          jsr BubbleCheck             ;check timers and coordinates, create air bubble
          jsr RelativeBubblePosition  ;get relative coordinates
          jsr GetBubbleOffscreenBits  ;get offscreen information
          jsr DrawBubble              ;draw the air bubble
          dex
          bpl BublLoop                ;do this until all three are handled
BublExit: rts                         ;then leave

FireballXSpdData:
      .byte $40, $c0

FireballObjCore:
         stx ObjectOffset             ;store offset as current object
         lda Fireball_State,x         ;check for d7 = 1
         asl
         bcs FireballExplosion        ;if so, branch to get relative coordinates and draw explosion
         ldy Fireball_State,x         ;if fireball inactive, branch to leave
         beq NoFBall
         dey                          ;if fireball state set to 1, skip this part and just run it
         beq RunFB
         lda Player_X_Position        ;get player's horizontal position
         adc #$04                     ;add four pixels and store as fireball's horizontal position
         sta Fireball_X_Position,x
         lda Player_PageLoc           ;get player's page location
         adc #$00                     ;add carry and store as fireball's page location
         sta Fireball_PageLoc,x
         lda Player_Y_Position        ;get player's vertical position and store
         sta Fireball_Y_Position,x
         lda #$01                     ;set high byte of vertical position
         sta Fireball_Y_HighPos,x
         ldy PlayerFacingDir          ;get player's facing direction
         dey                          ;decrement to use as offset here
         lda FireballXSpdData,y       ;set horizontal speed of fireball accordingly
         sta Fireball_X_Speed,x
         lda #$04                     ;set vertical speed of fireball
         sta Fireball_Y_Speed,x
         lda #$07
         sta Fireball_BoundBoxCtrl,x  ;set bounding box size control for fireball
         dec Fireball_State,x         ;decrement state to 1 to skip this part from now on
RunFB:   txa                          ;add 7 to offset to use
         clc                          ;as fireball offset for next routines
         adc #$07
         tax
         lda #$50                     ;set downward movement force here
         sta $00
         lda #$03                     ;set maximum speed here
         sta $02
         lda #$00
         jsr ImposeGravity            ;do sub here to impose gravity on fireball and move vertically
         jsr MoveObjectHorizontally   ;do another sub to move it horizontally
         ldx ObjectOffset             ;return fireball offset to X
         jsr RelativeFireballPosition ;get relative coordinates
         jsr GetFireballOffscreenBits ;get offscreen information
         jsr GetFireballBoundBox      ;get bounding box coordinates
         jsr FireballBGCollision      ;do fireball to background collision detection
         lda FBall_OffscreenBits      ;get fireball offscreen bits
         and #%11001100               ;mask out certain bits
         bne EraseFB                  ;if any bits still set, branch to kill fireball
         jsr FireballEnemyCollision   ;do fireball to enemy collision detection and deal with collisions
         jmp DrawFireball             ;draw fireball appropriately and leave
EraseFB: lda #$00                     ;erase fireball state
         sta Fireball_State,x
NoFBall: rts                          ;leave

FireballExplosion:
      jsr RelativeFireballPosition
      jmp DrawExplosion_Fireball

BubbleCheck:
      lda PseudoRandomBitReg+1,x  ;get part of LSFR
      and #$01
      sta $07                     ;store pseudorandom bit here
      lda Bubble_Y_Position,x     ;get vertical coordinate for air bubble
      cmp #$f8                    ;if offscreen coordinate not set,
      bne MoveBubl                ;branch to move air bubble
      lda AirBubbleTimer          ;if air bubble timer not expired,
      bne ExitBubl                ;branch to leave, otherwise create new air bubble

SetupBubble:
          ldy #$00                 ;load default value here
          lda PlayerFacingDir      ;get player's facing direction
          lsr                      ;move d0 to carry
          bcc PosBubl              ;branch to use default value if facing left
          ldy #$08                 ;otherwise load alternate value here
PosBubl:  tya                      ;use value loaded as adder
          adc Player_X_Position    ;add to player's horizontal position
          sta Bubble_X_Position,x  ;save as horizontal position for airbubble
          lda Player_PageLoc
          adc #$00                 ;add carry to player's page location
          sta Bubble_PageLoc,x     ;save as page location for airbubble
          lda Player_Y_Position
          clc                      ;add eight pixels to player's vertical position
          adc #$08
          sta Bubble_Y_Position,x  ;save as vertical position for air bubble
          lda #$01
          sta Bubble_Y_HighPos,x   ;set vertical high byte for air bubble
          ldy $07                  ;get pseudorandom bit, use as offset
          lda BubbleTimerData,y    ;get data for air bubble timer
          sta AirBubbleTimer       ;set air bubble timer
MoveBubl: ldy $07                  ;get pseudorandom bit again, use as offset
          lda Bubble_YMF_Dummy,x
          sec                      ;subtract pseudorandom amount from dummy variable
          sbc Bubble_MForceData,y
          sta Bubble_YMF_Dummy,x   ;save dummy variable
          lda Bubble_Y_Position,x
          sbc #$00                 ;subtract borrow from airbubble's vertical coordinate
          cmp #$20                 ;if below the status bar,
          bcs Y_Bubl               ;branch to go ahead and use to move air bubble upwards
          lda #$f8                 ;otherwise set offscreen coordinate
Y_Bubl:   sta Bubble_Y_Position,x  ;store as new vertical coordinate for air bubble
ExitBubl: rts                      ;leave

Bubble_MForceData:
      .byte $ff, $50

BubbleTimerData:
      .byte $40, $20

;-------------------------------------------------------------------------------------

RunGameTimer:
           lda OperMode               ;get primary mode of operation
           beq ExGTimer               ;branch to leave if in title screen mode
           lda GameEngineSubroutine
           cmp #$08                   ;if routine number less than eight running,
           bcc ExGTimer               ;branch to leave
           cmp #$0b                   ;if running death routine,
           beq ExGTimer               ;branch to leave
           lda Player_Y_HighPos
           cmp #$02                   ;if player below the screen,
           bcs ExGTimer               ;branch to leave regardless of level type
           lda GameTimerCtrlTimer     ;if game timer control not yet expired,
           bne ExGTimer               ;branch to leave
           lda GameTimerDisplay
           ora GameTimerDisplay+1     ;otherwise check game timer digits
           ora GameTimerDisplay+2
           beq TimeUpOn               ;if game timer digits at 000, branch to time-up code
           ldy GameTimerDisplay       ;otherwise check first digit
           dey                        ;if first digit not on 1,
           bne ResGTCtrl              ;branch to reset game timer control
           lda GameTimerDisplay+1     ;otherwise check second and third digits
           ora GameTimerDisplay+2
           bne ResGTCtrl              ;if timer not at 100, branch to reset game timer control
           lda #TimeRunningOutMusic
           sta EventMusicQueue        ;otherwise load time running out music
ResGTCtrl: lda #$18                   ;reset game timer control
           sta GameTimerCtrlTimer
           ldy #$23                   ;set offset for last digit
           lda #$ff                   ;set value to decrement game timer digit
           sta DigitModifier+5
           jsr DigitsMathRoutine      ;do sub to decrement game timer slowly
           lda #$a4                   ;set status nybbles to update game timer display
           jmp PrintStatusBarNumbers  ;do sub to update the display
TimeUpOn:  sta PlayerStatus           ;init player status (note A will always be zero here)
           jsr ForceInjury            ;do sub to kill the player (note player is small here)
           inc GameTimerExpiredFlag   ;set game timer expiration flag
ExGTimer:  rts                        ;leave

;-------------------------------------------------------------------------------------

WarpZoneObject:
      lda ScrollLock         ;check for scroll lock flag
      beq ExGTimer           ;branch if not set to leave
      lda Player_Y_Position  ;check to see if player's vertical coordinate has
      and Player_Y_HighPos   ;same bits set as in vertical high byte (why?)
      bne ExGTimer           ;if so, branch to leave
      sta ScrollLock         ;otherwise nullify scroll lock flag
      inc WarpZoneControl    ;increment warp zone flag to make warp pipes for warp zone
      jmp EraseEnemyObject   ;kill this object

;-------------------------------------------------------------------------------------
;$00 - used in WhirlpoolActivate to store whirlpool length / 2, page location of center of whirlpool
;and also to store movement force exerted on player
;$01 - used in ProcessWhirlpools to store page location of right extent of whirlpool
;and in WhirlpoolActivate to store center of whirlpool
;$02 - used in ProcessWhirlpools to store right extent of whirlpool and in
;WhirlpoolActivate to store maximum vertical speed

ProcessWhirlpools:
        lda AreaType                ;check for water type level
        bne ExitWh                  ;branch to leave if not found
        sta Whirlpool_Flag          ;otherwise initialize whirlpool flag
        lda TimerControl            ;if master timer control set,
        bne ExitWh                  ;branch to leave
        ldy #$04                    ;otherwise start with last whirlpool data
WhLoop: lda Whirlpool_LeftExtent,y  ;get left extent of whirlpool
        clc
        adc Whirlpool_Length,y      ;add length of whirlpool
        sta $02                     ;store result as right extent here
        lda Whirlpool_PageLoc,y     ;get page location
        beq NextWh                  ;if none or page 0, branch to get next data
        adc #$00                    ;add carry
        sta $01                     ;store result as page location of right extent here
        lda Player_X_Position       ;get player's horizontal position
        sec
        sbc Whirlpool_LeftExtent,y  ;subtract left extent
        lda Player_PageLoc          ;get player's page location
        sbc Whirlpool_PageLoc,y     ;subtract borrow
        bmi NextWh                  ;if player too far left, branch to get next data
        lda $02                     ;otherwise get right extent
        sec
        sbc Player_X_Position       ;subtract player's horizontal coordinate
        lda $01                     ;get right extent's page location
        sbc Player_PageLoc          ;subtract borrow
        bpl WhirlpoolActivate       ;if player within right extent, branch to whirlpool code
NextWh: dey                         ;move onto next whirlpool data
        bpl WhLoop                  ;do this until all whirlpools are checked
ExitWh: rts                         ;leave

WhirlpoolActivate:
        lda Whirlpool_Length,y      ;get length of whirlpool
        lsr                         ;divide by 2
        sta $00                     ;save here
        lda Whirlpool_LeftExtent,y  ;get left extent of whirlpool
        clc
        adc $00                     ;add length divided by 2
        sta $01                     ;save as center of whirlpool
        lda Whirlpool_PageLoc,y     ;get page location
        adc #$00                    ;add carry
        sta $00                     ;save as page location of whirlpool center
        lda FrameCounter            ;get frame counter
        lsr                         ;shift d0 into carry (to run on every other frame)
        bcc WhPull                  ;if d0 not set, branch to last part of code
        lda $01                     ;get center
        sec
        sbc Player_X_Position       ;subtract player's horizontal coordinate
        lda $00                     ;get page location of center
        sbc Player_PageLoc          ;subtract borrow
        bpl LeftWh                  ;if player to the left of center, branch
        lda Player_X_Position       ;otherwise slowly pull player left, towards the center
        sec
        sbc #$01                    ;subtract one pixel
        sta Player_X_Position       ;set player's new horizontal coordinate
        lda Player_PageLoc
        sbc #$00                    ;subtract borrow
        jmp SetPWh                  ;jump to set player's new page location
LeftWh: lda Player_CollisionBits    ;get player's collision bits
        lsr                         ;shift d0 into carry
        bcc WhPull                  ;if d0 not set, branch
        lda Player_X_Position       ;otherwise slowly pull player right, towards the center
        clc
        adc #$01                    ;add one pixel
        sta Player_X_Position       ;set player's new horizontal coordinate
        lda Player_PageLoc
        adc #$00                    ;add carry
SetPWh: sta Player_PageLoc          ;set player's new page location
WhPull: lda #$10
        sta $00                     ;set vertical movement force
        lda #$01
        sta Whirlpool_Flag          ;set whirlpool flag to be used later
        sta $02                     ;also set maximum vertical speed
        lsr
        tax                         ;set X for player offset
        jmp ImposeGravity           ;jump to put whirlpool effect on player vertically, do not return

;-------------------------------------------------------------------------------------

FlagpoleScoreMods:
      .byte $05, $02, $08, $04, $01

FlagpoleScoreDigits:
      .byte $03, $03, $04, $04, $04

FlagpoleRoutine:
           ldx #$05                  ;set enemy object offset
           stx ObjectOffset          ;to special use slot
           lda Enemy_ID,x
           cmp #FlagpoleFlagObject   ;if flagpole flag not found,
           bne ExitFlagP             ;branch to leave
           lda GameEngineSubroutine
           cmp #$04                  ;if flagpole slide routine not running,
           bne SkipScore             ;branch to near the end of code
           lda Player_State
           cmp #$03                  ;if player state not climbing,
           bne SkipScore             ;branch to near the end of code
           lda Enemy_Y_Position,x    ;check flagpole flag's vertical coordinate
           cmp #$aa                  ;if flagpole flag down to a certain point,
           bcs GiveFPScr             ;branch to end the level
           lda Player_Y_Position     ;check player's vertical coordinate
           cmp #$a2                  ;if player down to a certain point,
           bcs GiveFPScr             ;branch to end the level
           lda Enemy_YMF_Dummy,x
           adc #$ff                  ;add movement amount to dummy variable
           sta Enemy_YMF_Dummy,x     ;save dummy variable
           lda Enemy_Y_Position,x    ;get flag's vertical coordinate
           adc #$01                  ;add 1 plus carry to move flag, and
           sta Enemy_Y_Position,x    ;store vertical coordinate
           lda FlagpoleFNum_YMFDummy
           sec                       ;subtract movement amount from dummy variable
           sbc #$ff
           sta FlagpoleFNum_YMFDummy ;save dummy variable
           lda FlagpoleFNum_Y_Pos
           sbc #$01                  ;subtract one plus borrow to move floatey number,
           sta FlagpoleFNum_Y_Pos    ;and store vertical coordinate here
SkipScore: jmp FPGfx                 ;jump to skip ahead and draw flag and floatey number
GiveFPScr: ldy FlagpoleScore         ;get score offset from earlier (when player touched flagpole)
           lda FlagpoleScoreMods,y   ;get amount to award player points
           ldx FlagpoleScoreDigits,y ;get digit with which to award points
           sta DigitModifier,x       ;store in digit modifier
           jsr AddToScore            ;do sub to award player points depending on height of collision
           lda #$05
           sta GameEngineSubroutine  ;set to run end-of-level subroutine on next frame
FPGfx:     jsr GetEnemyOffscreenBits ;get offscreen information
           jsr RelativeEnemyPosition ;get relative coordinates
           jsr FlagpoleGfxHandler    ;draw flagpole flag and floatey number
ExitFlagP: rts

;-------------------------------------------------------------------------------------

Jumpspring_Y_PosData:
      .byte $08, $10, $08, $00

JumpspringHandler:
           jsr GetEnemyOffscreenBits   ;get offscreen information
           lda TimerControl            ;check master timer control
           bne DrawJSpr                ;branch to last section if set
           lda JumpspringAnimCtrl      ;check jumpspring frame control
           beq DrawJSpr                ;branch to last section if not set
           tay
           dey                         ;subtract one from frame control,
           tya                         ;the only way a poor nmos 6502 can
           and #%00000010              ;mask out all but d1, original value still in Y
           bne DownJSpr                ;if set, branch to move player up
           inc Player_Y_Position
           inc Player_Y_Position       ;move player's vertical position down two pixels
           jmp PosJSpr                 ;skip to next part
DownJSpr:  dec Player_Y_Position       ;move player's vertical position up two pixels
           dec Player_Y_Position
PosJSpr:   lda Jumpspring_FixedYPos,x  ;get permanent vertical position
           clc
           adc Jumpspring_Y_PosData,y  ;add value using frame control as offset
           sta Enemy_Y_Position,x      ;store as new vertical position
           cpy #$01                    ;check frame control offset (second frame is $00)
           bcc BounceJS                ;if offset not yet at third frame ($01), skip to next part
           lda A_B_Buttons
           and #A_Button               ;check saved controller bits for A button press
           beq BounceJS                ;skip to next part if A not pressed
           and PreviousA_B_Buttons     ;check for A button pressed in previous frame
           bne BounceJS                ;skip to next part if so
           lda #$f4
           sta JumpspringForce         ;otherwise write new jumpspring force here
BounceJS:  cpy #$03                    ;check frame control offset again
           bne DrawJSpr                ;skip to last part if not yet at fifth frame ($03)
           lda JumpspringForce
           sta Player_Y_Speed          ;store jumpspring force as player's new vertical speed
           lda #$00
           sta JumpspringAnimCtrl      ;initialize jumpspring frame control
DrawJSpr:  jsr RelativeEnemyPosition   ;get jumpspring's relative coordinates
           jsr EnemyGfxHandler         ;draw jumpspring
           jsr OffscreenBoundsCheck    ;check to see if we need to kill it
           lda JumpspringAnimCtrl      ;if frame control at zero, don't bother
           beq ExJSpring               ;trying to animate it, just leave
           lda JumpspringTimer
           bne ExJSpring               ;if jumpspring timer not expired yet, leave
           lda #$04
           sta JumpspringTimer         ;otherwise initialize jumpspring timer
           inc JumpspringAnimCtrl      ;increment frame control to animate jumpspring
ExJSpring: rts                         ;leave

;-------------------------------------------------------------------------------------

Setup_Vine:
        lda #VineObject          ;load identifier for vine object
        sta Enemy_ID,x           ;store in buffer
        lda #$01
        sta Enemy_Flag,x         ;set flag for enemy object buffer
        lda Block_PageLoc,y
        sta Enemy_PageLoc,x      ;copy page location from previous object
        lda Block_X_Position,y
        sta Enemy_X_Position,x   ;copy horizontal coordinate from previous object
        lda Block_Y_Position,y
        sta Enemy_Y_Position,x   ;copy vertical coordinate from previous object
        ldy VineFlagOffset       ;load vine flag/offset to next available vine slot
        bne NextVO               ;if set at all, don't bother to store vertical
        sta VineStart_Y_Position ;otherwise store vertical coordinate here
NextVO: txa                      ;store object offset to next available vine slot
        sta VineObjOffset,y      ;using vine flag as offset
        inc VineFlagOffset       ;increment vine flag offset
        lda #Sfx_GrowVine
        sta Square2SoundQueue    ;load vine grow sound
        rts

;-------------------------------------------------------------------------------------
;$06-$07 - used as address to block buffer data
;$02 - used as vertical high nybble of block buffer offset

VineHeightData:
      .byte $30, $60

VineObjectHandler:
           cpx #$05                  ;check enemy offset for special use slot
           bne ExitVH                ;if not in last slot, branch to leave
           ldy VineFlagOffset
           dey                       ;decrement vine flag in Y, use as offset
           lda VineHeight
           cmp VineHeightData,y      ;if vine has reached certain height,
           beq RunVSubs              ;branch ahead to skip this part
           lda FrameCounter          ;get frame counter
           lsr                       ;shift d1 into carry
           lsr
           bcc RunVSubs              ;if d1 not set (2 frames every 4) skip this part
           lda Enemy_Y_Position+5
           sbc #$01                  ;subtract vertical position of vine
           sta Enemy_Y_Position+5    ;one pixel every frame it's time
           inc VineHeight            ;increment vine height
RunVSubs:  lda VineHeight            ;if vine still very small,
           cmp #$08                  ;branch to leave
           bcc ExitVH
           jsr RelativeEnemyPosition ;get relative coordinates of vine,
           jsr GetEnemyOffscreenBits ;and any offscreen bits
           ldy #$00                  ;initialize offset used in draw vine sub
VDrawLoop: jsr DrawVine              ;draw vine
           iny                       ;increment offset
           cpy VineFlagOffset        ;if offset in Y and offset here
           bne VDrawLoop             ;do not yet match, loop back to draw more vine
           lda Enemy_OffscreenBits
           and #%00001100            ;mask offscreen bits
           beq WrCMTile              ;if none of the saved offscreen bits set, skip ahead
           dey                       ;otherwise decrement Y to get proper offset again
KillVine:  ldx VineObjOffset,y       ;get enemy object offset for this vine object
           jsr EraseEnemyObject      ;kill this vine object
           dey                       ;decrement Y
           bpl KillVine              ;if any vine objects left, loop back to kill it
           sta VineFlagOffset        ;initialize vine flag/offset
           sta VineHeight            ;initialize vine height
WrCMTile:  lda VineHeight            ;check vine height
           cmp #$20                  ;if vine small (less than 32 pixels tall)
           bcc ExitVH                ;then branch ahead to leave
           ldx #$06                  ;set offset in X to last enemy slot
           lda #$01                  ;set A to obtain horizontal in $04, but we don't care
           ldy #$1b                  ;set Y to offset to get block at ($04, $10) of coordinates
           jsr BlockBufferCollision  ;do a sub to get block buffer address set, return contents
           ldy $02
           cpy #$d0                  ;if vertical high nybble offset beyond extent of
           bcs ExitVH                ;current block buffer, branch to leave, do not write
           lda ($06),y               ;otherwise check contents of block buffer at
           bne ExitVH                ;current offset, if not empty, branch to leave
           lda #$26
           sta ($06),y               ;otherwise, write climbing metatile to block buffer
ExitVH:    ldx ObjectOffset          ;get enemy object offset and leave
           rts
