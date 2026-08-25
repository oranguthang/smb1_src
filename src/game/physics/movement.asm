; -------------------------------------------------------------------------------------
; $00 - used to store high nybble of horizontal speed as adder
; $01 - used to store low nybble of horizontal speed
; $02 - used to store adder to page location

MoveEnemyHorizontally:
    INX  ; increment offset for enemy offset
    JSR MoveObjectHorizontally  ; position object horizontally according to
    LDX ObjectOffset  ; counters, return with saved value in A,
    RTS  ; put enemy offset back in X and leave

MovePlayerHorizontally:
    LDA JumpspringAnimCtrl  ; if jumpspring currently animating,
    BNE ExXMove  ; branch to leave
    TAX  ; otherwise set zero for offset to use player's stuff

MoveObjectHorizontally:
    LDA SprObject_X_Speed,x  ; get currently saved value (horizontal
    ASL  ; speed, secondary counter, whatever)
    ASL  ; and move low nybble to high
    ASL
    ASL
    STA $01  ; store result here
    LDA SprObject_X_Speed,x  ; get saved value again
    LSR  ; move high nybble to low
    LSR
    LSR
    LSR
    CMP #$08  ; if < 8, branch, do not change
    BCC SaveXSpd
    ORA #%11110000  ; otherwise alter high nybble
SaveXSpd:
    STA $00  ; save result here
    LDY #$00  ; load default Y value here
    CMP #$00  ; if result positive, leave Y alone
    BPL UseAdder
    DEY  ; otherwise decrement Y
UseAdder:
    STY $02  ; save Y here
    LDA SprObject_X_MoveForce,x  ; get whatever number's here
    CLC
    ADC $01  ; add low nybble moved to high
    STA SprObject_X_MoveForce,x  ; store result here
    LDA #$00  ; init A
    ROL  ; rotate carry into d0
    PHA  ; push onto stack
    ROR  ; rotate d0 back onto carry
    LDA SprObject_X_Position,x
    ADC $00  ; add carry plus saved value (high nybble moved to low
    STA SprObject_X_Position,x  ; plus $f0 if necessary) to object's horizontal position
    LDA SprObject_PageLoc,x
    ADC $02  ; add carry plus other saved value to the
    STA SprObject_PageLoc,x  ; object's page location and save
    PLA
    CLC  ; pull old carry from stack and add
    ADC $00  ; to high nybble moved to low
ExXMove:
    RTS  ; and leave

; -------------------------------------------------------------------------------------
; $00 - used for downward force
; $01 - used for upward force
; $02 - used for maximum vertical speed

MovePlayerVertically:
    LDX #$00  ; set X for player offset
    LDA TimerControl
    BNE NoJSChk  ; if master timer control set, branch ahead
    LDA JumpspringAnimCtrl  ; otherwise check to see if jumpspring is animating
    BNE ExXMove  ; branch to leave if so
NoJSChk:
    LDA VerticalForce  ; dump vertical force
    STA $00
    LDA #$04  ; set maximum vertical speed here
    JMP ImposeGravitySprObj  ; then jump to move player vertically

; --------------------------------

MoveD_EnemyVertically:
    LDY #$3d  ; set quick movement amount downwards
    LDA Enemy_State,x  ; then check enemy state
    CMP #$05  ; if not set to unique state for spiny's egg, go ahead
    BNE ContVMove  ; and use, otherwise set different movement amount, continue on

MoveFallingPlatform:
    LDY #$20  ; set movement amount
ContVMove:
    JMP SetHiMax  ; jump to skip the rest of this

; --------------------------------

MoveRedPTroopaDown:
    LDY #$00  ; set Y to move downwards
    JMP MoveRedPTroopa  ; skip to movement routine

MoveRedPTroopaUp:
    LDY #$01  ; set Y to move upwards

MoveRedPTroopa:
    INX  ; increment X for enemy offset
    LDA #$03
    STA $00  ; set downward movement amount here
    LDA #$06
    STA $01  ; set upward movement amount here
    LDA #$02
    STA $02  ; set maximum speed here
    TYA  ; set movement direction in A, and
    JMP RedPTroopaGrav  ; jump to move this thing

; --------------------------------

MoveDropPlatform:
    LDY #$7f  ; set movement amount for drop platform
    BNE SetMdMax  ; skip ahead of other value set here

MoveEnemySlowVert:
    LDY #$0f  ; set movement amount for bowser/other objects
SetMdMax:
    LDA #$02  ; set maximum speed in A
    BNE SetXMoveAmt  ; unconditional branch

; --------------------------------

MoveJ_EnemyVertically:
    LDY #$1c  ; set movement amount for podoboo/other objects
SetHiMax:
    LDA #$03  ; set maximum speed in A
SetXMoveAmt:
    STY $00  ; set movement amount here
    INX  ; increment X for enemy offset
    JSR ImposeGravitySprObj  ; do a sub to move enemy object downwards
    LDX ObjectOffset  ; get enemy object buffer offset and leave
    RTS

; --------------------------------

MaxSpdBlockData:
    .byte $06, $08

ResidualGravityCode:
    LDY #$00  ; this part appears to be residual,
    .byte $2c  ; no code branches or jumps to it

ImposeGravityBlock:
    LDY #$01  ; set offset for maximum speed
    LDA #$50  ; set movement amount here
    STA $00
    LDA MaxSpdBlockData,y  ; get maximum speed

ImposeGravitySprObj:
    STA $02  ; set maximum speed here
    LDA #$00  ; set value to move downwards
    JMP ImposeGravity  ; jump to the code that actually moves it

; --------------------------------

MovePlatformDown:
    LDA #$00  ; save value to stack (if branching here, execute next
    .byte $2c  ; part as BIT instruction)

MovePlatformUp:
    LDA #$01  ; save value to stack
    PHA
    LDY Enemy_ID,x  ; get enemy object identifier
    INX  ; increment offset for enemy object
    LDA #$05  ; load default value here
    CPY #$29  ; residual comparison, object #29 never executes
    BNE SetDplSpd  ; this code, thus unconditional branch here
    LDA #$09  ; residual code
SetDplSpd:
    STA $00  ; save downward movement amount here
    LDA #$0a  ; save upward movement amount here
    STA $01
    LDA #$03  ; save maximum vertical speed here
    STA $02
    PLA  ; get value from stack
    TAY  ; use as Y, then move onto code shared by red koopa

RedPTroopaGrav:
    JSR ImposeGravity  ; do a sub to move object gradually
    LDX ObjectOffset  ; get enemy object offset and leave
    RTS

; -------------------------------------------------------------------------------------
; $00 - used for downward force
; $01 - used for upward force
; $07 - used as adder for vertical position

ImposeGravity:
    PHA  ; push value to stack
    LDA SprObject_YMF_Dummy,x
    CLC  ; add value in movement force to contents of dummy variable
    ADC SprObject_Y_MoveForce,x
    STA SprObject_YMF_Dummy,x
    LDY #$00  ; set Y to zero by default
    LDA SprObject_Y_Speed,x  ; get current vertical speed
    BPL AlterYP  ; if currently moving downwards, do not decrement Y
    DEY  ; otherwise decrement Y
AlterYP:
    STY $07  ; store Y here
    ADC SprObject_Y_Position,x  ; add vertical position to vertical speed plus carry
    STA SprObject_Y_Position,x  ; store as new vertical position
    LDA SprObject_Y_HighPos,x
    ADC $07  ; add carry plus contents of $07 to vertical high byte
    STA SprObject_Y_HighPos,x  ; store as new vertical high byte
    LDA SprObject_Y_MoveForce,x
    CLC
    ADC $00  ; add downward movement amount to contents of $0433
    STA SprObject_Y_MoveForce,x
    LDA SprObject_Y_Speed,x  ; add carry to vertical speed and store
    ADC #$00
    STA SprObject_Y_Speed,x
    CMP $02  ; compare to maximum speed
    BMI ChkUpM  ; if less than preset value, skip this part
    LDA SprObject_Y_MoveForce,x
    CMP #$80  ; if less positively than preset maximum, skip this part
    BCC ChkUpM
    LDA $02
    STA SprObject_Y_Speed,x  ; keep vertical speed within maximum value
    LDA #$00
    STA SprObject_Y_MoveForce,x  ; clear fractional
ChkUpM:
    PLA  ; get value from stack
    BEQ ExVMove  ; if set to zero, branch to leave
    LDA $02
    EOR #%11111111  ; otherwise get two's compliment of maximum speed
    TAY
    INY
    STY $07  ; store two's compliment here
    LDA SprObject_Y_MoveForce,x
    SEC  ; subtract upward movement amount from contents
    SBC $01  ; of movement force, note that $01 is twice as large as $00,
    STA SprObject_Y_MoveForce,x  ; thus it effectively undoes add we did earlier
    LDA SprObject_Y_Speed,x
    SBC #$00  ; subtract borrow from vertical speed and store
    STA SprObject_Y_Speed,x
    CMP $07  ; compare vertical speed to two's compliment
    BPL ExVMove  ; if less negatively than preset maximum, skip this part
    LDA SprObject_Y_MoveForce,x
    CMP #$80  ; check if fractional part is above certain amount,
    BCS ExVMove  ; and if so, branch to leave
    LDA $07
    STA SprObject_Y_Speed,x  ; keep vertical speed within maximum value
    LDA #$ff
    STA SprObject_Y_MoveForce,x  ; clear fractional
ExVMove:
    RTS  ; leave!
