; -------------------------------------------------------------------------------------
; $00-$01 - used in DrawEnemyObjRow to hold sprite tile numbers
; $02 - used to store Y position
; $03 - used to store moving direction, used to flip enemies horizontally
; $04 - used to store enemy's sprite attributes
; $05 - used to store X position
; $eb - used to hold sprite data offset
; $ec - used to hold either altered enemy state or special value used in gfx handler as condition
; $ed - used to hold enemy state from buffer
; $ef - used to hold enemy code used in gfx handler (may or may not resemble Enemy_ID values)

; tiles arranged in top left, right, middle left, right, bottom left, right order
EnemyGraphicsTable:
    .byte $fc, $fc, $aa, $ab, $ac, $ad  ; buzzy beetle frame 1
    .byte $fc, $fc, $ae, $af, $b0, $b1  ; frame 2
    .byte $fc, $a5, $a6, $a7, $a8, $a9  ; koopa troopa frame 1
    .byte $fc, $a0, $a1, $a2, $a3, $a4  ; frame 2
    .byte $69, $a5, $6a, $a7, $a8, $a9  ; koopa paratroopa frame 1
    .byte $6b, $a0, $6c, $a2, $a3, $a4  ; frame 2
    .byte $fc, $fc, $96, $97, $98, $99  ; spiny frame 1
    .byte $fc, $fc, $9a, $9b, $9c, $9d  ; frame 2
    .byte $fc, $fc, $8f, $8e, $8e, $8f  ; spiny's egg frame 1
    .byte $fc, $fc, $95, $94, $94, $95  ; frame 2
    .byte $fc, $fc, $dc, $dc, $df, $df  ; bloober frame 1
    .byte $dc, $dc, $dd, $dd, $de, $de  ; frame 2
    .byte $fc, $fc, $b2, $b3, $b4, $b5  ; cheep-cheep frame 1
    .byte $fc, $fc, $b6, $b3, $b7, $b5  ; frame 2
    .byte $fc, $fc, $70, $71, $72, $73  ; goomba
    .byte $fc, $fc, $6e, $6e, $6f, $6f  ; koopa shell frame 1 (upside-down)
    .byte $fc, $fc, $6d, $6d, $6f, $6f  ; frame 2
    .byte $fc, $fc, $6f, $6f, $6e, $6e  ; koopa shell frame 1 (rightsideup)
    .byte $fc, $fc, $6f, $6f, $6d, $6d  ; frame 2
    .byte $fc, $fc, $f4, $f4, $f5, $f5  ; buzzy beetle shell frame 1 (rightsideup)
    .byte $fc, $fc, $f4, $f4, $f5, $f5  ; frame 2
    .byte $fc, $fc, $f5, $f5, $f4, $f4  ; buzzy beetle shell frame 1 (upside-down)
    .byte $fc, $fc, $f5, $f5, $f4, $f4  ; frame 2
    .byte $fc, $fc, $fc, $fc, $ef, $ef  ; defeated goomba
    .byte $b9, $b8, $bb, $ba, $bc, $bc  ; lakitu frame 1
    .byte $fc, $fc, $bd, $bd, $bc, $bc  ; frame 2
    .byte $7a, $7b, $da, $db, $d8, $d8  ; princess
    .byte $cd, $cd, $ce, $ce, $cf, $cf  ; mushroom retainer
    .byte $7d, $7c, $d1, $8c, $d3, $d2  ; hammer bro frame 1
    .byte $7d, $7c, $89, $88, $8b, $8a  ; frame 2
    .byte $d5, $d4, $e3, $e2, $d3, $d2  ; frame 3
    .byte $d5, $d4, $e3, $e2, $8b, $8a  ; frame 4
    .byte $e5, $e5, $e6, $e6, $eb, $eb  ; piranha plant frame 1
    .byte $ec, $ec, $ed, $ed, $ee, $ee  ; frame 2
    .byte $fc, $fc, $d0, $d0, $d7, $d7  ; podoboo
    .byte $bf, $be, $c1, $c0, $c2, $fc  ; bowser front frame 1
    .byte $c4, $c3, $c6, $c5, $c8, $c7  ; bowser rear frame 1
    .byte $bf, $be, $ca, $c9, $c2, $fc  ; front frame 2
    .byte $c4, $c3, $c6, $c5, $cc, $cb  ; rear frame 2
    .byte $fc, $fc, $e8, $e7, $ea, $e9  ; bullet bill
    .byte $f2, $f2, $f3, $f3, $f2, $f2  ; jumpspring frame 1
    .byte $f1, $f1, $f1, $f1, $fc, $fc  ; frame 2
    .byte $f0, $f0, $fc, $fc, $fc, $fc  ; frame 3

EnemyGfxTableOffsets:
    .byte $0c, $0c, $00, $0c, $0c, $a8, $54, $3c
    .byte $ea, $18, $48, $48, $cc, $c0, $18, $18
    .byte $18, $90, $24, $ff, $48, $9c, $d2, $d8
    .byte $f0, $f6, $fc

EnemyAttributeData:
    .byte $01, $02, $03, $02, $01, $01, $03, $03
    .byte $03, $01, $01, $02, $02, $21, $01, $02
    .byte $01, $01, $02, $ff, $02, $02, $01, $01
    .byte $02, $02, $02

EnemyAnimTimingBMask:
    .byte $08, $18

JumpspringFrameOffsets:
    .byte $18, $19, $1a, $19, $18

EnemyGfxHandler:
    LDA Enemy_Y_Position,x  ; get enemy object vertical position
    STA $02
    LDA Enemy_Rel_XPos  ; get enemy object horizontal position
    STA $05  ; relative to screen
    LDY Enemy_SprDataOffset,x
    STY $eb  ; get sprite data offset
    LDA #$00
    STA VerticalFlipFlag  ; initialize vertical flip flag by default
    LDA Enemy_MovingDir,x
    STA $03  ; get enemy object moving direction
    LDA Enemy_SprAttrib,x
    STA $04  ; get enemy object sprite attributes
    LDA Enemy_ID,x
    CMP #PiranhaPlant  ; is enemy object piranha plant?
    BNE CheckForRetainerObj  ; if not, branch
    LDY PiranhaPlant_Y_Speed,x
    BMI CheckForRetainerObj  ; if piranha plant moving upwards, branch
    LDY EnemyFrameTimer,x
    BEQ CheckForRetainerObj  ; if timer for movement expired, branch
    RTS  ; if all conditions fail, leave

CheckForRetainerObj:
    LDA Enemy_State,x  ; store enemy state
    STA $ed
    AND #%00011111  ; nullify all but 5 LSB and use as Y
    TAY
    LDA Enemy_ID,x  ; check for mushroom retainer/princess object
    CMP #RetainerObject
    BNE CheckForBulletBillCV  ; if not found, branch
    LDY #$00  ; if found, nullify saved state in Y
    LDA #$01  ; set value that will not be used
    STA $03
    LDA #$15  ; set value $15 as code for mushroom retainer/princess object

CheckForBulletBillCV:
    CMP #BulletBill_CannonVar  ; otherwise check for bullet bill object
    BNE CheckForJumpspring  ; if not found, branch again
    DEC $02  ; decrement saved vertical position
    LDA #$03
    LDY EnemyFrameTimer,x  ; get timer for enemy object
    BEQ SBBAt  ; if expired, do not set priority bit
    ORA #%00100000  ; otherwise do so
SBBAt:
    STA $04  ; set new sprite attributes
    LDY #$00  ; nullify saved enemy state both in Y and in
    STY $ed  ; memory location here
    LDA #$08  ; set specific value to unconditionally branch once

CheckForJumpspring:
    CMP #JumpspringObject  ; check for jumpspring object
    BNE CheckForPodoboo
    LDY #$03  ; set enemy state -2 MSB here for jumpspring object
    LDX JumpspringAnimCtrl  ; get current frame number for jumpspring object
    LDA JumpspringFrameOffsets,x  ; load data using frame number as offset

CheckForPodoboo:
    STA $ef  ; store saved enemy object value here
    STY $ec  ; and Y here (enemy state -2 MSB if not changed)
    LDX ObjectOffset  ; get enemy object offset
    CMP #$0c  ; check for podoboo object
    BNE CheckBowserGfxFlag  ; branch if not found
    LDA Enemy_Y_Speed,x  ; if moving upwards, branch
    BMI CheckBowserGfxFlag
    INC VerticalFlipFlag  ; otherwise, set flag for vertical flip

CheckBowserGfxFlag:
    LDA BowserGfxFlag  ; if not drawing bowser at all, skip to something else
    BEQ CheckForGoomba
    LDY #$16  ; if set to 1, draw bowser's front
    CMP #$01
    BEQ SBwsrGfxOfs
    INY  ; otherwise draw bowser's rear
SBwsrGfxOfs:
    STY $ef

CheckForGoomba:
    LDY $ef  ; check value for goomba object
    CPY #Goomba
    BNE CheckBowserFront  ; branch if not found
    LDA Enemy_State,x
    CMP #$02  ; check for defeated state
    BCC GmbaAnim  ; if not defeated, go ahead and animate
    LDX #$04  ; if defeated, write new value here
    STX $ec
GmbaAnim:
    AND #%00100000  ; check for d5 set in enemy object state
    ORA TimerControl  ; or timer disable flag set
    BNE CheckBowserFront  ; if either condition true, do not animate goomba
    LDA FrameCounter
    AND #%00001000  ; check for every eighth frame
    BNE CheckBowserFront
    LDA $03
    EOR #%00000011  ; invert bits to flip horizontally every eight frames
    STA $03  ; leave alone otherwise

CheckBowserFront:
    LDA EnemyAttributeData,y  ; load sprite attribute using enemy object
    ORA $04  ; as offset, and add to bits already loaded
    STA $04
    LDA EnemyGfxTableOffsets,y  ; load value based on enemy object as offset
    TAX  ; save as X
    LDY $ec  ; get previously saved value
    LDA BowserGfxFlag
    BEQ CheckForSpiny  ; if not drawing bowser object at all, skip all of this
    CMP #$01
    BNE CheckBowserRear  ; if not drawing front part, branch to draw the rear part
    LDA BowserBodyControls  ; check bowser's body control bits
    BPL ChkFrontSte  ; branch if d7 not set (control's bowser's mouth)
    LDX #$de  ; otherwise load offset for second frame
ChkFrontSte:
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; if bowser not defeated, do not set flag
    BEQ DrawBowser

FlipBowserOver:
    STX VerticalFlipFlag  ; set vertical flip flag to nonzero

DrawBowser:
    JMP DrawEnemyObject  ; draw bowser's graphics now

CheckBowserRear:
    LDA BowserBodyControls  ; check bowser's body control bits
    AND #$01
    BEQ ChkRearSte  ; branch if d0 not set (control's bowser's feet)
    LDX #$e4  ; otherwise load offset for second frame
ChkRearSte:
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; if bowser not defeated, do not set flag
    BEQ DrawBowser
    LDA $02  ; subtract 16 pixels from
    SEC  ; saved vertical coordinate
    SBC #$10
    STA $02
    JMP FlipBowserOver  ; jump to set vertical flip flag

CheckForSpiny:
    CPX #$24  ; check if value loaded is for spiny
    BNE CheckForLakitu  ; if not found, branch
    CPY #$05  ; if enemy state set to $05, do this,
    BNE NotEgg  ; otherwise branch
    LDX #$30  ; set to spiny egg offset
    LDA #$02
    STA $03  ; set enemy direction to reverse sprites horizontally
    LDA #$05
    STA $ec  ; set enemy state
NotEgg:
    JMP CheckForHammerBro  ; skip a big chunk of this if we found spiny but not in egg

CheckForLakitu:
    CPX #$90  ; check value for lakitu's offset loaded
    BNE CheckUpsideDownShell  ; branch if not loaded
    LDA $ed
    AND #%00100000  ; check for d5 set in enemy state
    BNE NoLAFr  ; branch if set
    LDA FrenzyEnemyTimer
    CMP #$10  ; check timer to see if we've reached a certain range
    BCS NoLAFr  ; branch if not
    LDX #$96  ; if d6 not set and timer in range, load alt frame for lakitu
NoLAFr:
    JMP CheckDefeatedState  ; skip this next part if we found lakitu but alt frame not needed

CheckUpsideDownShell:
    LDA $ef  ; check for enemy object => $04
    CMP #$04
    BCS CheckRightSideUpShell  ; branch if true
    CPY #$02
    BCC CheckRightSideUpShell  ; branch if enemy state < $02
    LDX #$5a  ; set for upside-down koopa shell by default
    LDY $ef
    CPY #BuzzyBeetle  ; check for buzzy beetle object
    BNE CheckRightSideUpShell
    LDX #$7e  ; set for upside-down buzzy beetle shell if found
    INC $02  ; increment vertical position by one pixel

CheckRightSideUpShell:
    LDA $ec  ; check for value set here
    CMP #$04  ; if enemy state < $02, do not change to shell, if
    BNE CheckForHammerBro  ; enemy state => $02 but not = $04, leave shell upside-down
    LDX #$72  ; set right-side up buzzy beetle shell by default
    INC $02  ; increment saved vertical position by one pixel
    LDY $ef
    CPY #BuzzyBeetle  ; check for buzzy beetle object
    BEQ CheckForDefdGoomba  ; branch if found
    LDX #$66  ; change to right-side up koopa shell if not found
    INC $02  ; and increment saved vertical position again

CheckForDefdGoomba:
    CPY #Goomba  ; check for goomba object (necessary if previously
    BNE CheckForHammerBro  ; failed buzzy beetle object test)
    LDX #$54  ; load for regular goomba
    LDA $ed  ; note that this only gets performed if enemy state => $02
    AND #%00100000  ; check saved enemy state for d5 set
    BNE CheckForHammerBro  ; branch if set
    LDX #$8a  ; load offset for defeated goomba
    DEC $02  ; set different value and decrement saved vertical position

CheckForHammerBro:
    LDY ObjectOffset
    LDA $ef  ; check for hammer bro object
    CMP #HammerBro
    BNE CheckForBloober  ; branch if not found
    LDA $ed
    BEQ CheckToAnimateEnemy  ; branch if not in normal enemy state
    AND #%00001000
    BEQ CheckDefeatedState  ; if d3 not set, branch further away
    LDX #$b4  ; otherwise load offset for different frame
    BNE CheckToAnimateEnemy  ; unconditional branch

CheckForBloober:
    CPX #$48  ; check for cheep-cheep offset loaded
    BEQ CheckToAnimateEnemy  ; branch if found
    LDA EnemyIntervalTimer,y
    CMP #$05
    BCS CheckDefeatedState  ; branch if some timer is above a certain point
    CPX #$3c  ; check for bloober offset loaded
    BNE CheckToAnimateEnemy  ; branch if not found this time
    CMP #$01
    BEQ CheckDefeatedState  ; branch if timer is set to certain point
    INC $02  ; increment saved vertical coordinate three pixels
    INC $02
    INC $02
    JMP CheckAnimationStop  ; and do something else

CheckToAnimateEnemy:
    LDA $ef  ; check for specific enemy objects
    CMP #Goomba
    BEQ CheckDefeatedState  ; branch if goomba
    CMP #$08
    BEQ CheckDefeatedState  ; branch if bullet bill (note both variants use $08 here)
    CMP #Podoboo
    BEQ CheckDefeatedState  ; branch if podoboo
    CMP #$18  ; branch if => $18
    BCS CheckDefeatedState
    LDY #$00
    CMP #$15  ; check for mushroom retainer/princess object
    BNE CheckForSecondFrame  ; which uses different code here, branch if not found
    INY  ; residual instruction
    LDA WorldNumber  ; are we on world 8?
    CMP #World8
    BCS CheckDefeatedState  ; if so, leave the offset alone (use princess)
    LDX #$a2  ; otherwise, set for mushroom retainer object instead
    LDA #$03  ; set alternate state here
    STA $ec
    BNE CheckDefeatedState  ; unconditional branch

CheckForSecondFrame:
    LDA FrameCounter  ; load frame counter
    AND EnemyAnimTimingBMask,y  ; mask it (partly residual, one byte not ever used)
    BNE CheckDefeatedState  ; branch if timing is off

CheckAnimationStop:
    LDA $ed  ; check saved enemy state
    AND #%10100000  ; for d7 or d5, or check for timers stopped
    ORA TimerControl
    BNE CheckDefeatedState  ; if either condition true, branch
    TXA
    CLC
    ADC #$06  ; add $06 to current enemy offset
    TAX  ; to animate various enemy objects

CheckDefeatedState:
    LDA $ed  ; check saved enemy state
    AND #%00100000  ; for d5 set
    BEQ DrawEnemyObject  ; branch if not set
    LDA $ef
    CMP #$04  ; check for saved enemy object => $04
    BCC DrawEnemyObject  ; branch if less
    LDY #$01
    STY VerticalFlipFlag  ; set vertical flip flag
    DEY
    STY $ec  ; init saved value here

DrawEnemyObject:
    LDY $eb  ; load sprite data offset
    JSR DrawEnemyObjRow  ; draw six tiles of data
    JSR DrawEnemyObjRow  ; into sprite data
    JSR DrawEnemyObjRow
    LDX ObjectOffset  ; get enemy object offset
    LDY Enemy_SprDataOffset,x  ; get sprite data offset
    LDA $ef
    CMP #$08  ; get saved enemy object and check
    BNE CheckForVerticalFlip  ; for bullet bill, branch if not found

SkipToOffScrChk:
    JMP SprObjectOffscrChk  ; jump if found

CheckForVerticalFlip:
    LDA VerticalFlipFlag  ; check if vertical flip flag is set here
    BEQ CheckForESymmetry  ; branch if not
    LDA Sprite_Attributes,y  ; get attributes of first sprite we dealt with
    ORA #%10000000  ; set bit for vertical flip
    INY
    INY  ; increment two bytes so that we store the vertical flip
    JSR DumpSixSpr  ; in attribute bytes of enemy obj sprite data
    DEY
    DEY  ; now go back to the Y coordinate offset
    TYA
    TAX  ; give offset to X
    LDA $ef
    CMP #HammerBro  ; check saved enemy object for hammer bro
    BEQ FlipEnemyVertically
    CMP #Lakitu  ; check saved enemy object for lakitu
    BEQ FlipEnemyVertically  ; branch for hammer bro or lakitu
    CMP #$15
    BCS FlipEnemyVertically  ; also branch if enemy object => $15
    TXA
    CLC
    ADC #$08  ; if not selected objects or => $15, set
    TAX  ; offset in X for next row

FlipEnemyVertically:
    LDA Sprite_Tilenumber,x  ; load first or second row tiles
    PHA  ; and save tiles to the stack
    LDA Sprite_Tilenumber+4,x
    PHA
    LDA Sprite_Tilenumber+16,y  ; exchange third row tiles
    STA Sprite_Tilenumber,x  ; with first or second row tiles
    LDA Sprite_Tilenumber+20,y
    STA Sprite_Tilenumber+4,x
    PLA  ; pull first or second row tiles from stack
    STA Sprite_Tilenumber+20,y  ; and save in third row
    PLA
    STA Sprite_Tilenumber+16,y

CheckForESymmetry:
    LDA BowserGfxFlag  ; are we drawing bowser at all?
    BNE SkipToOffScrChk  ; branch if so
    LDA $ef
    LDX $ec  ; get alternate enemy state
    CMP #$05  ; check for hammer bro object
    BNE ContES
    JMP SprObjectOffscrChk  ; jump if found
ContES:
    CMP #Bloober  ; check for bloober object
    BEQ MirrorEnemyGfx
    CMP #PiranhaPlant  ; check for piranha plant object
    BEQ MirrorEnemyGfx
    CMP #Podoboo  ; check for podoboo object
    BEQ MirrorEnemyGfx  ; branch if either of three are found
    CMP #Spiny  ; check for spiny object
    BNE ESRtnr  ; branch closer if not found
    CPX #$05  ; check spiny's state
    BNE CheckToMirrorLakitu  ; branch if not an egg, otherwise
ESRtnr:
    CMP #$15  ; check for princess/mushroom retainer object
    BNE SpnySC
    LDA #$42  ; set horizontal flip on bottom right sprite
    STA Sprite_Attributes+20,y  ; note that palette bits were already set earlier
SpnySC:
    CPX #$02  ; if alternate enemy state set to 1 or 0, branch
    BCC CheckToMirrorLakitu

MirrorEnemyGfx:
    LDA BowserGfxFlag  ; if enemy object is bowser, skip all of this
    BNE CheckToMirrorLakitu
    LDA Sprite_Attributes,y  ; load attribute bits of first sprite
    AND #%10100011
    STA Sprite_Attributes,y  ; save vertical flip, priority, and palette bits
    STA Sprite_Attributes+8,y  ; in left sprite column of enemy object OAM data
    STA Sprite_Attributes+16,y
    ORA #%01000000  ; set horizontal flip
    CPX #$05  ; check for state used by spiny's egg
    BNE EggExc  ; if alternate state not set to $05, branch
    ORA #%10000000  ; otherwise set vertical flip
EggExc:
    STA Sprite_Attributes+4,y  ; set bits of right sprite column
    STA Sprite_Attributes+12,y  ; of enemy object sprite data
    STA Sprite_Attributes+20,y
    CPX #$04  ; check alternate enemy state
    BNE CheckToMirrorLakitu  ; branch if not $04
    LDA Sprite_Attributes+8,y  ; get second row left sprite attributes
    ORA #%10000000
    STA Sprite_Attributes+8,y  ; store bits with vertical flip in
    STA Sprite_Attributes+16,y  ; second and third row left sprites
    ORA #%01000000
    STA Sprite_Attributes+12,y  ; store with horizontal and vertical flip in
    STA Sprite_Attributes+20,y  ; second and third row right sprites

CheckToMirrorLakitu:
    LDA $ef  ; check for lakitu enemy object
    CMP #Lakitu
    BNE CheckToMirrorJSpring  ; branch if not found
    LDA VerticalFlipFlag
    BNE NVFLak  ; branch if vertical flip flag not set
    LDA Sprite_Attributes+16,y  ; save vertical flip and palette bits
    AND #%10000001  ; in third row left sprite
    STA Sprite_Attributes+16,y
    LDA Sprite_Attributes+20,y  ; set horizontal flip and palette bits
    ORA #%01000001  ; in third row right sprite
    STA Sprite_Attributes+20,y
    LDX FrenzyEnemyTimer  ; check timer
    CPX #$10
    BCS SprObjectOffscrChk  ; branch if timer has not reached a certain range
    STA Sprite_Attributes+12,y  ; otherwise set same for second row right sprite
    AND #%10000001
    STA Sprite_Attributes+8,y  ; preserve vertical flip and palette bits for left sprite
    BCC SprObjectOffscrChk  ; unconditional branch
NVFLak:
    LDA Sprite_Attributes,y  ; get first row left sprite attributes
    AND #%10000001
    STA Sprite_Attributes,y  ; save vertical flip and palette bits
    LDA Sprite_Attributes+4,y  ; get first row right sprite attributes
    ORA #%01000001  ; set horizontal flip and palette bits
    STA Sprite_Attributes+4,y  ; note that vertical flip is left as-is

CheckToMirrorJSpring:
    LDA $ef  ; check for jumpspring object (any frame)
    CMP #$18
    BCC SprObjectOffscrChk  ; branch if not jumpspring object at all
    LDA #$82
    STA Sprite_Attributes+8,y  ; set vertical flip and palette bits of
    STA Sprite_Attributes+16,y  ; second and third row left sprites
    ORA #%01000000
    STA Sprite_Attributes+12,y  ; set, in addition to those, horizontal flip
    STA Sprite_Attributes+20,y  ; for second and third row right sprites

SprObjectOffscrChk:
    LDX ObjectOffset  ; get enemy buffer offset
    LDA Enemy_OffscreenBits  ; check offscreen information
    LSR
    LSR  ; shift three times to the right
    LSR  ; which puts d2 into carry
    PHA  ; save to stack
    BCC LcChk  ; branch if not set
    LDA #$04  ; set for right column sprites
    JSR MoveESprColOffscreen  ; and move them offscreen
LcChk:
    PLA  ; get from stack
    LSR  ; move d3 to carry
    PHA  ; save to stack
    BCC Row3C  ; branch if not set
    LDA #$00  ; set for left column sprites,
    JSR MoveESprColOffscreen  ; move them offscreen
Row3C:
    PLA  ; get from stack again
    LSR  ; move d5 to carry this time
    LSR
    PHA  ; save to stack again
    BCC Row23C  ; branch if carry not set
    LDA #$10  ; set for third row of sprites
    JSR MoveESprRowOffscreen  ; and move them offscreen
Row23C:
    PLA  ; get from stack
    LSR  ; move d6 into carry
    PHA  ; save to stack
    BCC AllRowC
    LDA #$08  ; set for second and third rows
    JSR MoveESprRowOffscreen  ; move them offscreen
AllRowC:
    PLA  ; get from stack once more
    LSR  ; move d7 into carry
    BCC ExEGHandler
    JSR MoveESprRowOffscreen  ; move all sprites offscreen (A should be 0 by now)
    LDA Enemy_ID,x
    CMP #Podoboo  ; check enemy identifier for podoboo
    BEQ ExEGHandler  ; skip this part if found, we do not want to erase podoboo!
    LDA Enemy_Y_HighPos,x  ; check high byte of vertical position
    CMP #$02  ; if not yet past the bottom of the screen, branch
    BNE ExEGHandler
    JSR EraseEnemyObject  ; what it says

ExEGHandler:
    RTS

DrawEnemyObjRow:
    LDA EnemyGraphicsTable,x  ; load two tiles of enemy graphics
    STA $00
    LDA EnemyGraphicsTable+1,x

DrawOneSpriteRow:
    STA $01
    JMP DrawSpriteObject  ; draw them

MoveESprRowOffscreen:
    CLC  ; add A to enemy object OAM data offset
    ADC Enemy_SprDataOffset,x
    TAY  ; use as offset
    LDA #$f8
    JMP DumpTwoSpr  ; move first row of sprites offscreen

MoveESprColOffscreen:
    CLC  ; add A to enemy object OAM data offset
    ADC Enemy_SprDataOffset,x
    TAY  ; use as offset
    JSR MoveColOffscreen  ; move first and second row sprites in column offscreen
    STA Sprite_Data+16,y  ; move third row sprite in column offscreen
    RTS
