;-------------------------------------------------------------------------------------
;$06-$07 - address from block buffer routine

EnemyBGCStateData:
      .byte $01, $01, $02, $02, $02, $05

EnemyBGCXSpdData:
      .byte $10, $f0

EnemyToBGCollisionDet:
      lda Enemy_State,x        ;check enemy state for d6 set
      and #%00100000
      bne ExEBG                ;if set, branch to leave
      jsr SubtEnemyYPos        ;otherwise, do a subroutine here
      bcc ExEBG                ;if enemy vertical coord + 62 < 68, branch to leave
      ldy Enemy_ID,x
      cpy #Spiny               ;if enemy object is not spiny, branch elsewhere
      bne DoIDCheckBGColl
      lda Enemy_Y_Position,x
      cmp #$25                 ;if enemy vertical coordinate < 36 branch to leave
      bcc ExEBG

DoIDCheckBGColl:
       cpy #GreenParatroopaJump ;check for some other enemy object
       bne HBChk                ;branch if not found
       jmp EnemyJump            ;otherwise jump elsewhere
HBChk: cpy #HammerBro           ;check for hammer bro
       bne CInvu                ;branch if not found
       jmp HammerBroBGColl      ;otherwise jump elsewhere
CInvu: cpy #Spiny               ;if enemy object is spiny, branch
       beq YesIn
       cpy #PowerUpObject       ;if special power-up object, branch
       beq YesIn
       cpy #$07                 ;if enemy object =>$07, branch to leave
       bcs ExEBGChk
YesIn: jsr ChkUnderEnemy        ;if enemy object < $07, or = $12 or $2e, do this sub
       bne HandleEToBGCollision ;if block underneath enemy, branch

NoEToBGCollision:
       jmp ChkForRedKoopa       ;otherwise skip and do something else

;--------------------------------
;$02 - vertical coordinate from block buffer routine

HandleEToBGCollision:
      jsr ChkForNonSolids       ;if something is underneath enemy, find out what
      beq NoEToBGCollision      ;if blank $26, coins, or hidden blocks, jump, enemy falls through
      cmp #$23
      bne LandEnemyProperly     ;check for blank metatile $23 and branch if not found
      ldy $02                   ;get vertical coordinate used to find block
      lda #$00                  ;store default blank metatile in that spot so we won't
      sta ($06),y               ;trigger this routine accidentally again
      lda Enemy_ID,x
      cmp #$15                  ;if enemy object => $15, branch ahead
      bcs ChkToStunEnemies
      cmp #Goomba               ;if enemy object not goomba, branch ahead of this routine
      bne GiveOEPoints
      jsr KillEnemyAboveBlock   ;if enemy object IS goomba, do this sub

GiveOEPoints:
      lda #$01                  ;award 100 points for hitting block beneath enemy
      jsr SetupFloateyNumber

ChkToStunEnemies:
          cmp #$09                   ;perform many comparisons on enemy object identifier
          bcc SetStun
          cmp #$11                   ;if the enemy object identifier is equal to the values
          bcs SetStun                ;$09, $0e, $0f or $10, it will be modified, and not
          cmp #$0a                   ;modified if not any of those values, note that piranha plant will
          bcc Demote                 ;always fail this test because A will still have vertical
          cmp #PiranhaPlant          ;coordinate from previous addition, also these comparisons
          bcc SetStun                ;are only necessary if branching from $d7a1
Demote:   and #%00000001             ;erase all but LSB, essentially turning enemy object
          sta Enemy_ID,x             ;into green or red koopa troopa to demote them
SetStun:  lda Enemy_State,x          ;load enemy state
          and #%11110000             ;save high nybble
          ora #%00000010
          sta Enemy_State,x          ;set d1 of enemy state
          dec Enemy_Y_Position,x
          dec Enemy_Y_Position,x     ;subtract two pixels from enemy's vertical position
          lda Enemy_ID,x
          cmp #Bloober               ;check for bloober object
          beq SetWYSpd
          lda #$fd                   ;set default vertical speed
          ldy AreaType
          bne SetNotW                ;if area type not water, set as speed, otherwise
SetWYSpd: lda #$ff                   ;change the vertical speed
SetNotW:  sta Enemy_Y_Speed,x        ;set vertical speed now
          ldy #$01
          jsr PlayerEnemyDiff        ;get horizontal difference between player and enemy object
          bpl ChkBBill               ;branch if enemy is to the right of player
          iny                        ;increment Y if not
ChkBBill: lda Enemy_ID,x
          cmp #BulletBill_CannonVar  ;check for bullet bill (cannon variant)
          beq NoCDirF
          cmp #BulletBill_FrenzyVar  ;check for bullet bill (frenzy variant)
          beq NoCDirF                ;branch if either found, direction does not change
          sty Enemy_MovingDir,x      ;store as moving direction
NoCDirF:  dey                        ;decrement and use as offset
          lda EnemyBGCXSpdData,y     ;get proper horizontal speed
          sta Enemy_X_Speed,x        ;and store, then leave
ExEBGChk: rts

;--------------------------------
;$04 - low nybble of vertical coordinate from block buffer routine

LandEnemyProperly:
       lda $04                 ;check lower nybble of vertical coordinate saved earlier
       sec
       sbc #$08                ;subtract eight pixels
       cmp #$05                ;used to determine whether enemy landed from falling
       bcs ChkForRedKoopa      ;branch if lower nybble in range of $0d-$0f before subtract
       lda Enemy_State,x
       and #%01000000          ;branch if d6 in enemy state is set
       bne LandEnemyInitState
       lda Enemy_State,x
       asl                     ;branch if d7 in enemy state is not set
       bcc ChkLandedEnemyState
SChkA: jmp DoEnemySideCheck    ;if lower nybble < $0d, d7 set but d6 not set, jump here

ChkLandedEnemyState:
           lda Enemy_State,x         ;if enemy in normal state, branch back to jump here
           beq SChkA
           cmp #$05                  ;if in state used by spiny's egg
           beq ProcEnemyDirection    ;then branch elsewhere
           cmp #$03                  ;if already in state used by koopas and buzzy beetles
           bcs ExSteChk              ;or in higher numbered state, branch to leave
           lda Enemy_State,x         ;load enemy state again (why?)
           cmp #$02                  ;if not in $02 state (used by koopas and buzzy beetles)
           bne ProcEnemyDirection    ;then branch elsewhere
           lda #$10                  ;load default timer here
           ldy Enemy_ID,x            ;check enemy identifier for spiny
           cpy #Spiny
           bne SetForStn             ;branch if not found
           lda #$00                  ;set timer for $00 if spiny
SetForStn: sta EnemyIntervalTimer,x  ;set timer here
           lda #$03                  ;set state here, apparently used to render
           sta Enemy_State,x         ;upside-down koopas and buzzy beetles
           jsr EnemyLanding          ;then land it properly
ExSteChk:  rts                       ;then leave

ProcEnemyDirection:
         lda Enemy_ID,x            ;check enemy identifier for goomba
         cmp #Goomba               ;branch if found
         beq LandEnemyInitState
         cmp #Spiny                ;check for spiny
         bne InvtD                 ;branch if not found
         lda #$01
         sta Enemy_MovingDir,x     ;send enemy moving to the right by default
         lda #$08
         sta Enemy_X_Speed,x       ;set horizontal speed accordingly
         lda FrameCounter
         and #%00000111            ;if timed appropriately, spiny will skip over
         beq LandEnemyInitState    ;trying to face the player
InvtD:   ldy #$01                  ;load 1 for enemy to face the left (inverted here)
         jsr PlayerEnemyDiff       ;get horizontal difference between player and enemy
         bpl CNwCDir               ;if enemy to the right of player, branch
         iny                       ;if to the left, increment by one for enemy to face right (inverted)
CNwCDir: tya
         cmp Enemy_MovingDir,x     ;compare direction in A with current direction in memory
         bne LandEnemyInitState
         jsr ChkForBump_HammerBroJ ;if equal, not facing in correct dir, do sub to turn around

LandEnemyInitState:
      jsr EnemyLanding       ;land enemy properly
      lda Enemy_State,x
      and #%10000000         ;if d7 of enemy state is set, branch
      bne NMovShellFallBit
      lda #$00               ;otherwise initialize enemy state and leave
      sta Enemy_State,x      ;note this will also turn spiny's egg into spiny
      rts

NMovShellFallBit:
      lda Enemy_State,x   ;nullify d6 of enemy state, save other bits
      and #%10111111      ;and store, then leave
      sta Enemy_State,x
      rts

;--------------------------------

ChkForRedKoopa:
             lda Enemy_ID,x            ;check for red koopa troopa $03
             cmp #RedKoopa
             bne Chk2MSBSt             ;branch if not found
             lda Enemy_State,x
             beq ChkForBump_HammerBroJ ;if enemy found and in normal state, branch
Chk2MSBSt:   lda Enemy_State,x         ;save enemy state into Y
             tay
             asl                       ;check for d7 set
             bcc GetSteFromD           ;branch if not set
             lda Enemy_State,x
             ora #%01000000            ;set d6
             jmp SetD6Ste              ;jump ahead of this part
GetSteFromD: lda EnemyBGCStateData,y   ;load new enemy state with old as offset
SetD6Ste:    sta Enemy_State,x         ;set as new state

;--------------------------------
;$00 - used to store bitmask (not used but initialized here)
;$eb - used in DoEnemySideCheck as counter and to compare moving directions

DoEnemySideCheck:
          lda Enemy_Y_Position,x     ;if enemy within status bar, branch to leave
          cmp #$20                   ;because there's nothing there that impedes movement
          bcc ExESdeC
          ldy #$16                   ;start by finding block to the left of enemy ($00,$14)
          lda #$02                   ;set value here in what is also used as
          sta $eb                    ;OAM data offset
SdeCLoop: lda $eb                    ;check value
          cmp Enemy_MovingDir,x      ;compare value against moving direction
          bne NextSdeC               ;branch if different and do not seek block there
          lda #$01                   ;set flag in A for save horizontal coordinate
          jsr BlockBufferChk_Enemy   ;find block to left or right of enemy object
          beq NextSdeC               ;if nothing found, branch
          jsr ChkForNonSolids        ;check for non-solid blocks
          bne ChkForBump_HammerBroJ  ;branch if not found
NextSdeC: dec $eb                    ;move to the next direction
          iny
          cpy #$18                   ;increment Y, loop only if Y < $18, thus we check
          bcc SdeCLoop               ;enemy ($00, $14) and ($10, $14) pixel coordinates
ExESdeC:  rts

ChkForBump_HammerBroJ:
        cpx #$05               ;check if we're on the special use slot
        beq NoBump             ;and if so, branch ahead and do not play sound
        lda Enemy_State,x      ;if enemy state d7 not set, branch
        asl                    ;ahead and do not play sound
        bcc NoBump
        lda #Sfx_Bump          ;otherwise, play bump sound
        sta Square1SoundQueue  ;sound will never be played if branching from ChkForRedKoopa
NoBump: lda Enemy_ID,x         ;check for hammer bro
        cmp #$05
        bne InvEnemyDir        ;branch if not found
        lda #$00
        sta $00                ;initialize value here for bitmask
        ldy #$fa               ;load default vertical speed for jumping
        jmp SetHJ              ;jump to code that makes hammer bro jump

InvEnemyDir:
      jmp RXSpd     ;jump to turn the enemy around

;--------------------------------
;$00 - used to hold horizontal difference between player and enemy

PlayerEnemyDiff:
      lda Enemy_X_Position,x  ;get distance between enemy object's
      sec                     ;horizontal coordinate and the player's
      sbc Player_X_Position   ;horizontal coordinate
      sta $00                 ;and store here
      lda Enemy_PageLoc,x
      sbc Player_PageLoc      ;subtract borrow, then leave
      rts

;--------------------------------

EnemyLanding:
      jsr InitVStf            ;do something here to vertical speed and something else
      lda Enemy_Y_Position,x
      and #%11110000          ;save high nybble of vertical coordinate, and
      ora #%00001000          ;set d3, then store, probably used to set enemy object
      sta Enemy_Y_Position,x  ;neatly on whatever it's landing on
      rts

SubtEnemyYPos:
      lda Enemy_Y_Position,x  ;add 62 pixels to enemy object's
      clc                     ;vertical coordinate
      adc #$3e
      cmp #$44                ;compare against a certain range
      rts                     ;and leave with flags set for conditional branch

EnemyJump:
        jsr SubtEnemyYPos     ;do a sub here
        bcc DoSide            ;if enemy vertical coord + 62 < 68, branch to leave
        lda Enemy_Y_Speed,x
        clc                   ;add two to vertical speed
        adc #$02
        cmp #$03              ;if green paratroopa not falling, branch ahead
        bcc DoSide
        jsr ChkUnderEnemy     ;otherwise, check to see if green paratroopa is
        beq DoSide            ;standing on anything, then branch to same place if not
        jsr ChkForNonSolids   ;check for non-solid blocks
        beq DoSide            ;branch if found
        jsr EnemyLanding      ;change vertical coordinate and speed
        lda #$fd
        sta Enemy_Y_Speed,x   ;make the paratroopa jump again
DoSide: jmp DoEnemySideCheck  ;check for horizontal blockage, then leave

;--------------------------------

HammerBroBGColl:
      jsr ChkUnderEnemy    ;check to see if hammer bro is standing on anything
      beq NoUnderHammerBro
      cmp #$23             ;check for blank metatile $23 and branch if not found
      bne UnderHammerBro

KillEnemyAboveBlock:
      jsr ShellOrBlockDefeat  ;do this sub to kill enemy
      lda #$fc                ;alter vertical speed of enemy and leave
      sta Enemy_Y_Speed,x
      rts

UnderHammerBro:
      lda EnemyFrameTimer,x ;check timer used by hammer bro
      bne NoUnderHammerBro  ;branch if not expired
      lda Enemy_State,x
      and #%10001000        ;save d7 and d3 from enemy state, nullify other bits
      sta Enemy_State,x     ;and store
      jsr EnemyLanding      ;modify vertical coordinate, speed and something else
      jmp DoEnemySideCheck  ;then check for horizontal blockage and leave

NoUnderHammerBro:
      lda Enemy_State,x  ;if hammer bro is not standing on anything, set d0
      ora #$01           ;in the enemy state to indicate jumping or falling, then leave
      sta Enemy_State,x
      rts

ChkUnderEnemy:
      lda #$00                  ;set flag in A for save vertical coordinate
      ldy #$15                  ;set Y to check the bottom middle (8,18) of enemy object
      jmp BlockBufferChk_Enemy  ;hop to it!

ChkForNonSolids:
       cmp #$26       ;blank metatile used for vines?
       beq NSFnd
       cmp #$c2       ;regular coin?
       beq NSFnd
       cmp #$c3       ;underwater coin?
       beq NSFnd
       cmp #$5f       ;hidden coin block?
       beq NSFnd
       cmp #$60       ;hidden 1-up block?
NSFnd: rts

;-------------------------------------------------------------------------------------

FireballBGCollision:
      lda Fireball_Y_Position,x   ;check fireball's vertical coordinate
      cmp #$18
      bcc ClearBounceFlag         ;if within the status bar area of the screen, branch ahead
      jsr BlockBufferChk_FBall    ;do fireball to background collision detection on bottom of it
      beq ClearBounceFlag         ;if nothing underneath fireball, branch
      jsr ChkForNonSolids         ;check for non-solid metatiles
      beq ClearBounceFlag         ;branch if any found
      lda Fireball_Y_Speed,x      ;if fireball's vertical speed set to move upwards,
      bmi InitFireballExplode     ;branch to set exploding bit in fireball's state
      lda FireballBouncingFlag,x  ;if bouncing flag already set,
      bne InitFireballExplode     ;branch to set exploding bit in fireball's state
      lda #$fd
      sta Fireball_Y_Speed,x      ;otherwise set vertical speed to move upwards (give it bounce)
      lda #$01
      sta FireballBouncingFlag,x  ;set bouncing flag
      lda Fireball_Y_Position,x
      and #$f8                    ;modify vertical coordinate to land it properly
      sta Fireball_Y_Position,x   ;store as new vertical coordinate
      rts                         ;leave

ClearBounceFlag:
      lda #$00
      sta FireballBouncingFlag,x  ;clear bouncing flag by default
      rts                         ;leave

InitFireballExplode:
      lda #$80
      sta Fireball_State,x        ;set exploding flag in fireball's state
      lda #Sfx_Bump
      sta Square1SoundQueue       ;load bump sound
      rts                         ;leave
