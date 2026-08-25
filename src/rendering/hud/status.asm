; -------------------------------------------------------------------------------------
; $00 - used to store status bar nybbles
; $02 - used as temp vram offset
; $03 - used to store length of status bar number

; status bar name table offset and length data
tbl_status_bar_vram_address_and_length:
    .byte $f0, $06  ; top score display on title screen
    .byte $62, $06  ; player score
    .byte $62, $06
    .byte $6d, $02  ; coin tally
    .byte $6d, $02
    .byte $7a, $03  ; game timer

tbl_status_bar_digit_offsets:
    .byte $06, $0c, $12, $18, $1e, $24

sub_print_status_bar_numbers:
    STA $00  ; store player-specific offset
    JSR sub_output_numbers  ; use first nybble to print the coin display
    LDA $00  ; move high nybble to low
    LSR  ; and print to score display
    LSR
    LSR
    LSR

sub_output_numbers:
    CLC  ; add 1 to low nybble
    ADC #$01
    AND #%00001111  ; mask out high nybble
    CMP #$06
    BCS bra_exit_status_bar_number_output
    PHA  ; save incremented value to stack for now and
    ASL  ; shift to left and use as offset
    TAY
    LDX ram_vram_buffer1_offset  ; get current buffer pointer
    LDA #$20  ; put at top of screen by default
    CPY #$00  ; are we writing top score on title screen?
    BNE bra_store_status_bar_vram_address
    LDA #$22  ; if so, put further down on the screen
bra_store_status_bar_vram_address:
    STA ram_vram_buffer1,x
    LDA tbl_status_bar_vram_address_and_length,y  ; write low vram address and length of thing
    STA ram_vram_buffer1+1,x  ; we're printing to the buffer
    LDA tbl_status_bar_vram_address_and_length+1,y
    STA ram_vram_buffer1+2,x
    STA $03  ; save length byte in counter
    STX $02  ; and buffer pointer elsewhere for now
    PLA  ; pull original incremented value from stack
    TAX
    LDA tbl_status_bar_digit_offsets,x  ; load offset to value we want to write
    SEC
    SBC tbl_status_bar_vram_address_and_length+1,y  ; subtract from length byte we read before
    TAY  ; use value as offset to display digits
    LDX $02
bra_write_status_bar_digits:
    LDA ram_display_digits,y  ; write digits to the buffer
    STA ram_vram_buffer1+3,x
    INX
    INY
    DEC $03  ; do this until all the digits are written
    BNE bra_write_status_bar_digits
    LDA #$00  ; put null terminator at end
    STA ram_vram_buffer1+3,x
    INX  ; increment buffer pointer by 3
    INX
    INX
    STX ram_vram_buffer1_offset  ; store it in case we want to use it again
bra_exit_status_bar_number_output:
    RTS

; -------------------------------------------------------------------------------------

sub_digits_math_routine:
    LDA ram_oper_mode  ; check mode of operation
    CMP #con_mode_title_screen
    BEQ bra_clear_digit_modifiers  ; if in title screen mode, branch to lock score
    LDX #$05
bra_apply_digit_modifiers_loop:
    LDA ram_digit_modifier,x  ; load digit amount to increment
    CLC
    ADC ram_display_digits,y  ; add to current digit
    BMI bra_borrow_decimal_digit  ; if result is a negative number, branch to subtract
    CMP #10
    BCS bra_carry_decimal_digit  ; if digit greater than $09, branch to add
loc_store_modified_digit:
    STA ram_display_digits,y  ; store as new score or game timer digit
    DEY  ; move onto next digits in score or game timer
    DEX  ; and digit amounts to increment
    BPL bra_apply_digit_modifiers_loop  ; loop back if we're not done yet
bra_clear_digit_modifiers:
    LDA #$00  ; store zero here
    LDX #$06  ; start with the last digit
bra_clear_digit_modifiers_loop:
    STA ram_digit_modifier-1,x  ; initialize the digit amounts to increment
    DEX
    BPL bra_clear_digit_modifiers_loop  ; do this until they're all reset, then leave
    RTS
bra_borrow_decimal_digit:
    DEC ram_digit_modifier-1,x  ; decrement the previous digit, then put $09 in
    LDA #$09  ; the game timer digit we're currently on to "borrow
    BNE loc_store_modified_digit  ; the one", then do an unconditional branch back
bra_carry_decimal_digit:
    SEC  ; subtract ten from our digit to make it a
    SBC #10  ; proper BCD number, then increment the digit
    INC ram_digit_modifier-1,x  ; preceding current digit to "carry the one" properly
    JMP loc_store_modified_digit  ; go back to just after we branched here

; -------------------------------------------------------------------------------------

sub_update_top_score:
    LDX #$05  ; start with mario's score
    JSR sub_top_score_check
    LDX #$0b  ; now do luigi's score

sub_top_score_check:
    LDY #$05  ; start with the lowest digit
    SEC
bra_compare_score_digits:
    LDA ram_player_score_display,x  ; subtract each player digit from each high score digit
    SBC ram_top_score_display,y  ; from lowest to highest, if any top score digit exceeds
    DEX  ; any player digit, borrow will be set until a subsequent
    DEY  ; subtraction clears it (player digit is higher than top)
    BPL bra_compare_score_digits
    BCC bra_exit_top_score_check  ; check to see if borrow is still set, if so, no new high score
    INX  ; increment X and Y once to the start of the score
    INY
bra_copy_new_top_score:
    LDA ram_player_score_display,x  ; store player's score digits into high score memory area
    STA ram_top_score_display,y
    INX
    INY
    CPY #$06  ; do this until we have stored them all
    BCC bra_copy_new_top_score
bra_exit_top_score_check:
    RTS
