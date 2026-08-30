sub_smb2_main_initialize_name_tables:
    LDA PPU_STATUS  ; reset flip-flop
    LDA Mirror_PPU_CTRL  ; load mirror of first ppu control reg
    ORA #%00010000  ; set sprites for first 4k and background for second 4k
    AND #%11110000  ; clear rest of lower nybble, leave higher alone
    JSR sub_smb2_main_write_ppu_reg1
    LDA #$24  ; set vram address to start of name table 1
    JSR sub_smb2_main_write_nametable_address
    LDA #$20  ; and then set it to name table 0
sub_smb2_main_write_nametable_address:
    STA PPU_ADDRESS
    LDA #$00
    STA PPU_ADDRESS
    LDX #$04  ; clear name table with blank tile $24
    LDY #$c0
    LDA #$24
bra_smb2_main_initialize_nametable_loop:
    STA PPU_DATA  ; count out exactly 768 tiles
    DEY
    BNE bra_smb2_main_initialize_nametable_loop
    DEX
    BNE bra_smb2_main_initialize_nametable_loop
    LDY #64  ; now to clear the attribute table (with zero this time)
    TXA
    STA VRAM_Buffer1_Offset  ; init vram buffer 1 offset
    STA VRAM_Buffer1  ; init vram buffer 1
bra_smb2_main_initialize_attribute_table_loop:
    STA PPU_DATA
    DEY
    BNE bra_smb2_main_initialize_attribute_table_loop
    STA HorizontalScroll  ; reset scroll variables
    STA VerticalScroll
    JMP sub_smb2_main_initialize_ppu_scroll  ; initialize scroll registers to zero

; ------------------------------------------------------------------------------------

sub_smb2_main_read_joypads:
    LDA #$01  ; reset and clear strobe of joypad ports
    STA JOYPAD_PORT
    LSR
    TAX  ; start with joypad 1's port
    STA JOYPAD_PORT
    JSR sub_smb2_main_read_port_bits
    INX  ; increment for joypad 2's port
sub_smb2_main_read_port_bits:
    LDY #$08
bra_smb2_main_read_controller_port_loop:
    PHA  ; push previous bit onto stack
    LDA JOYPAD_PORT,x  ; read current bit on joypad port
    STA $00  ; check d1 and d0 of port output
    LSR  ; this is necessary on the old
    ORA $00  ; famicom systems in japan
    LSR
    PLA  ; read bits from stack
    ROL  ; rotate bit from carry flag
    DEY
    BNE bra_smb2_main_read_controller_port_loop  ; count down bits left
    STA SavedJoypadBits,x  ; save controller status here always
    PHA
    AND #%00110000  ; check for select or start
    AND JoypadBitMask,x  ; if neither saved state nor current state
    BEQ bra_smb2_main_store_controller_bits  ; have any of these two set, branch
    PLA
    AND #%11001111  ; otherwise store without select
    STA SavedJoypadBits,x  ; or start bits and leave
    RTS
bra_smb2_main_store_controller_bits:
    PLA
    STA JoypadBitMask,x  ; save with all bits in another place and leave
    RTS

; ------------------------------------------------------------------------------------

bra_smb2_main_write_vram_buffer:
    STA PPU_ADDRESS  ; store high byte of vram address
    INY
    LDA ($00),y  ; load next byte (second)
    STA PPU_ADDRESS  ; store low byte of vram address
    INY
    LDA ($00),y  ; load next byte (third)
    ASL  ; shift to left and save in stack
    PHA
    LDA Mirror_PPU_CTRL
    ORA #%00000100  ; set ppu to increment by 32 by default
    BCS bra_smb2_main_prepare_vram_buffer_entry  ; if d7 of third byte was clear, ppu will
    AND #%11111011  ; only increment by 1
bra_smb2_main_prepare_vram_buffer_entry:
    JSR sub_smb2_main_write_ppu_reg1  ; write to register
    PLA  ; pull from stack and shift to left again
    ASL
    BCC bra_smb2_main_decode_vram_buffer_length  ; if d6 of third byte was clear, do not repeat byte
    ORA #%00000010  ; otherwise set d1 and increment Y
    INY
bra_smb2_main_decode_vram_buffer_length:
    LSR  ; shift back to the right to get proper length
    LSR  ; note that d1 will now be in carry
    TAX
bra_smb2_main_write_vram_buffer_bytes:
    BCS bra_smb2_main_repeat_vram_buffer_byte  ; if carry set, repeat loading the same byte
    INY  ; otherwise increment Y to load next byte
bra_smb2_main_repeat_vram_buffer_byte:
    LDA ($00),y  ; load more data from buffer and write to vram
    STA PPU_DATA
    DEX  ; done writing?
    BNE bra_smb2_main_write_vram_buffer_bytes
    SEC
    TYA
    ADC $00  ; add end length plus one to the indirect at $00
    STA $00  ; to allow this routine to read another set of updates
    LDA #$00
    ADC $01
    STA $01
    LDA #$3f  ; sets vram address to palette memory
    STA PPU_ADDRESS
    LDA #$00
    STA PPU_ADDRESS
    STA PPU_ADDRESS  ; then reinitializes it for some reason
    STA PPU_ADDRESS
sub_smb2_main_update_screen:
    LDX PPU_STATUS  ; reset flip-flop
    LDY #$00  ; load first byte from indirect as a pointer
    LDA ($00),y
    BNE bra_smb2_main_write_vram_buffer  ; if byte is zero we have no further updates to make here
sub_smb2_main_initialize_ppu_scroll:
    STA PPU_SCROLL  ; store contents of A into scroll registers
    STA PPU_SCROLL  ; and end whatever subroutine led us here
    RTS

; ------------------------------------------------------------------------------------

sub_smb2_main_write_ppu_reg1:
    STA PPU_CTRL  ; write contents of A to PPU register 1
    STA Mirror_PPU_CTRL  ; and its mirror
    RTS

; ------------------------------------------------------------------------------------
; $00 - used to store status bar nybbles
; $02 - used as temp vram offset
; $03 - used to store length of status bar number

; status bar name table offset and length data
off_smb2_main_status_bar_vram_address_and_length:
    .byte $ef, $06  ; top score display on title screen
    .byte $62, $06  ; player score
    .byte $6d, $02  ; coin tally
    .byte $7a, $03  ; game timer

tbl_smb2_main_status_bar_digit_offsets:
    .byte $06, $0c, $12, $18

sub_smb2_main_print_status_bar_numbers:
    STA $00  ; store player-specific offset
    JSR sub_smb2_main_output_numbers  ; use first nybble to print the coin display
    LDA $00  ; move high nybble to low
    LSR  ; and print the score display
    LSR
    LSR
    LSR

sub_smb2_main_output_numbers:
    CLC  ; add 1 to low nybble
    ADC #$01
    AND #%00001111  ; mask out high nybble
    CMP #$06
    BCS bra_smb2_main_exit_status_bar_number_output
    PHA  ; save incremented value to stack for now and
    ASL  ; multiply by 2 to use as offset
    TAY
    LDX VRAM_Buffer1_Offset  ; get current buffer pointer
    LDA #$20  ; put at top of screen by default
    CPY #$00  ; are we writing top score on title screen?
    BNE bra_smb2_main_store_status_bar_vram_address
    LDA #$22  ; if so, put further down on the screen
bra_smb2_main_store_status_bar_vram_address:
    STA VRAM_Buffer1,x
    LDA off_smb2_main_status_bar_vram_address_and_length,y  ; write vram address low and length of thing
    STA VRAM_Buffer1+1,x  ; we're printing to the buffer
    LDA off_smb2_main_status_bar_vram_address_and_length+1,y
    STA VRAM_Buffer1+2,x
    STA $03  ; save length byte in counter
    STX $02  ; and buffer pointer elsewhere for now
    PLA  ; pull original incremented value from stack
    TAX
    LDA tbl_smb2_main_status_bar_digit_offsets,x  ; load offset to value we want to write
    SEC
    SBC off_smb2_main_status_bar_vram_address_and_length+1,y  ; subtract from length byte we read before
    TAY  ; use value as offset to display digits
    LDX $02
bra_smb2_main_write_status_bar_digits:
    LDA DisplayDigits,y  ; write digits to the buffer
    STA VRAM_Buffer1+3,x
    INX
    INY
    DEC $03  ; do this until all the digits are written
    BNE bra_smb2_main_write_status_bar_digits
    LDA #$00  ; put null terminator at end
    STA VRAM_Buffer1+3,x
    INX  ; increment buffer pointer by 3
    INX
    INX
    STX VRAM_Buffer1_Offset  ; store it in case we want to use it again
bra_smb2_main_exit_status_bar_number_output:
    RTS

sub_smb2_main_digits_math_routine:
    LDA OperMode  ; check mode of operation
    BEQ bra_smb2_main_clear_digit_modifiers  ; if in attract mode, branch to lock score
    LDX #$05
bra_smb2_main_apply_digit_modifiers_loop:
    LDA DigitModifier,x  ; load digit amount to increment
    CLC
    ADC DisplayDigits,y  ; add to current digit
    BMI bra_smb2_main_borrow_decimal_digit  ; if result is a negative number, branch to subtract
    CMP #10
    BCS bra_smb2_main_carry_decimal_digit  ; if digit greater than $09, branch to add
bra_smb2_main_store_modified_digit:
    STA DisplayDigits,y  ; store as new score or game timer digit
    DEY  ; move onto next digits in score or game timer
    DEX  ; and digit amounts to increment
    BPL bra_smb2_main_apply_digit_modifiers_loop  ; loop back if we're not done yet
bra_smb2_main_clear_digit_modifiers:
    LDA #$00  ; now we need to erase the digit modifiers
    LDX #$06  ; start with the last digit
bra_smb2_main_clear_digit_modifiers_loop:
    STA DigitModifier-1,x  ; initialize the digit amounts to increment
    DEX
    BPL bra_smb2_main_clear_digit_modifiers_loop  ; do this until they're all reset, then leave
    RTS

bra_smb2_main_borrow_decimal_digit:
    DEC DigitModifier-1,x  ; decrement the previous digit, then put $09 in
    LDA #$09  ; the game timer digit we're currently on to "borrow
    BNE bra_smb2_main_store_modified_digit  ; the one", then do an unconditional branch back
bra_smb2_main_carry_decimal_digit:
    SEC  ; subtract ten from our digit to make it a
    SBC #10  ; proper BCD number, then increment the digit
    INC DigitModifier-1,x  ; preceding current digit to "carry the one" properly
    JMP bra_smb2_main_store_modified_digit  ; go back to just after we branched here

sub_smb2_main_update_top_score:
    LDX #$05  ; start with the lowest digit
    LDY #$05
    SEC
bra_smb2_main_compare_score_digits:
    LDA PlayerScoreDisplay,x  ; subtract the regular score digit from each high score digit
    SBC TopScoreDisplay,y  ; from lowest to highest, if any top score digit exceeds
    DEX  ; the player score digit, borrow will be set until a subsequent
    DEY  ; subtraction clears it (player digit is higher than top)
    BPL bra_smb2_main_compare_score_digits
    BCC bra_smb2_main_exit_top_score_check  ; check to see if borrow is still set, if so, no new high score
    INX  ; increment X and Y once to the start of the score
    INY
bra_smb2_main_copy_new_top_score:
    LDA PlayerScoreDisplay,x  ; store player's score digits into high score memory area
    STA TopScoreDisplay,y
    INX
    INY
    CPY #$06  ; do this until we have stored them all
    BCC bra_smb2_main_copy_new_top_score
bra_smb2_main_exit_top_score_check:
    RTS

; -------------------------------------------------------------------------------------

; unused memory
    .byte $ff, $ff

tbl_smb2_main_default_oam_offsets:
    .byte $04, $30, $48, $60, $78, $90, $a8, $c0
    .byte $d8, $e8, $24, $f8, $fc, $28, $2c

; -------------------------------------------------------------------------------------

handler_smb2_main_initialize_area:
    LDY #$4b  ; clear all memory again, only as far as $074b
    JSR sub_smb2_main_initialize_memory  ; this is only necessary in game mode
    LDX #$21
    LDA #$00
bra_smb2_main_clear_game_timers_loop:
    STA Timers,x  ; clear out timer memory
    DEX
    BPL bra_smb2_main_clear_game_timers_loop
    LDA HalfwayPage
    LDY AltEntranceControl  ; if AltEntranceControl not set, use halfway page, if any found
    BEQ bra_smb2_main_use_area_start_page
    LDA EntrancePage  ; otherwise use saved entry page number here
bra_smb2_main_use_area_start_page:
    STA ScreenLeft_PageLoc  ; set as value here
    STA CurrentPageLoc  ; also set as current page
    STA BackloadingFlag  ; set flag here if halfway page or saved entry page number found
    JSR sub_smb2_main_get_screen_position  ; get pixel coordinates for screen borders
    LDY #$20  ; if on odd numbered page, use $2480 as start of rendering
    AND #%00000001  ; otherwise use $2080, this address used later as name table
    BEQ bra_smb2_main_store_initial_nametable_address  ; address for rendering of game area
    LDY #$24
bra_smb2_main_store_initial_nametable_address:
    STY CurrentNTAddr_High  ; store name table address
    LDY #$80
    STY CurrentNTAddr_Low
    ASL  ; store LSB of page number in high nybble
    ASL  ; of block buffer column position
    ASL
    ASL
    STA BlockBufferColumnPos
    DEC AreaObjectLength  ; set area object lengths for all empty
    DEC AreaObjectLength+1
    DEC AreaObjectLength+2
    LDA #$0b  ; set value for renderer to update 12 column sets
    STA ColumnSets  ; 12 column sets = 24 metatile columns = 1 1/2 screens
    JSR sub_smb2_main_get_area_data_addresses  ; get enemy and level addresses and load header
    LDA HardWorldFlag  ; check to see if we're in worlds A-D
    BNE bra_smb2_main_enable_secondary_hard_mode  ; if so, activate the secondary no matter where we're at
    LDA WorldNumber  ; otherwise check world number
    CMP #World4  ; if less than 4, do not activate secondary
    BCC bra_smb2_main_apply_halfway_entrance
    BNE bra_smb2_main_enable_secondary_hard_mode  ; if not equal to, then world > 4, thus activate
    LDA LevelNumber  ; otherwise, world 4, so check level number
    CMP #Level4  ; if not 4, do not set secondary hard mode flag
    BCC bra_smb2_main_apply_halfway_entrance
bra_smb2_main_enable_secondary_hard_mode:
    INC SecondaryHardMode  ; set secondary hard mode flag for areas 4-4 and beyond
bra_smb2_main_apply_halfway_entrance:
    LDA HalfwayPage
    BEQ bra_smb2_main_finish_area_initialization
    LDA #$02  ; if halfway page set, overwrite start position from header
    STA PlayerEntranceCtrl
bra_smb2_main_finish_area_initialization:
    LDA #Silence  ; silence music
    STA AreaMusicQueue
    LDA #$01  ; disable screen output
    STA DisableScreenFlag
    JSR sub_smb2_main_load_physics_data
    INC OperMode_Task  ; increment task for this mode
    RTS

; -------------------------------------------------------------------------------------

handler_smb2_main_secondary_game_setup:
    LDA #$00
    STA DisableScreenFlag  ; reenable screen, reset some flags
    STA WindFlag
    STA FlagpoleMusicFlag
    TAY
bra_smb2_main_clear_vram_buffer_loop:
    STA VRAM_Buffer1-1,y  ; clear buffer at $0300-$03ff
    INY
    BNE bra_smb2_main_clear_vram_buffer_loop
    STA GameTimerExpiredFlag  ; clear game timer exp flag
    STA DisableIntermediate  ; clear skip lives display flag
    STA BackloadingFlag  ; clear value here
    LDA #$ff
    STA BalPlatformAlignment  ; initialize balance platform assignment flag
    LDA ScreenLeft_PageLoc  ; get left side page location
    AND #$01
    STA NameTableSelect
    JSR sub_smb2_main_get_area_music
    LDA #$38  ; load sprite shuffle amounts to be used later
    STA SprShuffleAmt+2
    LDA #$48
    STA SprShuffleAmt+1
    LDA #$58
    STA SprShuffleAmt
    LDX #$0e  ; load default OAM offsets
bra_smb2_main_initialize_oam_offsets_loop:
    LDA tbl_smb2_main_default_oam_offsets,x
    STA SprDataOffset,x
    DEX  ; do this until they're all set
    BPL bra_smb2_main_initialize_oam_offsets_loop
    JSR sub_smb2_main_do_nothing  ; do slightly less of nothing than in super mario bros 1
    INC IRQUpdateFlag
    INC OperMode_Task
    RTS

; -------------------------------------------------------------------------------------

sub_smb2_main_initialize_memory:
    LDX #$07  ; set initial high byte to $0700-$07ff
    LDA #$00  ; set initial low byte to start of page (at $00 of page)
    STA $06
bra_smb2_main_initialize_page_state_loop:
    STX $07
bra_smb2_main_initialize_area_state_bytes:
    CPX #$01  ; check to see if we're on the stack ($0100-$01ff)
    BNE bra_smb2_main_clear_memory_byte  ; if not, go ahead anyway
    CPY #$60  ; otherwise, check to see if we're at $0160-$01ff
    BCS bra_smb2_main_skip_preserved_area_state_byte  ; if so, skip write
    CPY #$09  ; otherwise, check to see if we're at $0100-$0108
    BCC bra_smb2_main_skip_preserved_area_state_byte  ; if so, skip write
bra_smb2_main_clear_memory_byte:
    STA ($06),y  ; otherwise, initialize memory
bra_smb2_main_skip_preserved_area_state_byte:
    DEY
    CPY #$ff  ; do this until all bytes in page have been erased
    BNE bra_smb2_main_initialize_area_state_bytes
    DEX  ; go onto the next page
    BPL bra_smb2_main_initialize_page_state_loop  ; do this until all desired pages of memory have been erased
    RTS

; -------------------------------------------------------------------------------------

off_smb2_main_area_music_selection:
    .byte WaterMusic, GroundMusic, UndergroundMusic, CastleMusic
    .byte CloudMusic, PipeIntroMusic

sub_smb2_main_get_area_music:
    LDA OperMode  ; if in attract mode, leave
    BEQ bra_smb2_main_exit_music_selection
    LDA AltEntranceControl  ; check for specific alternate mode of entry
    CMP #$02  ; if found, branch without checking starting position
    BEQ bra_smb2_main_select_music_by_area_type  ; from area object data header
    LDY #$05  ; select music for pipe intro scene by default
    LDA PlayerEntranceCtrl  ; check value from level header for certain values
    CMP #$06
    BEQ bra_smb2_main_queue_selected_area_music  ; load music for pipe intro scene if header
    CMP #$07  ; start position either value $06 or $07
    BEQ bra_smb2_main_queue_selected_area_music
bra_smb2_main_select_music_by_area_type:
    LDY AreaType  ; load area type as offset for music bit
    LDA CloudTypeOverride
    BEQ bra_smb2_main_queue_selected_area_music  ; check for cloud type override
    LDY #$04  ; select music for cloud type level if found
bra_smb2_main_queue_selected_area_music:
    LDA off_smb2_main_area_music_selection,y  ; otherwise select appropriate music for level type
    STA AreaMusicQueue  ; store in queue and leave
bra_smb2_main_exit_music_selection:
    RTS

; -------------------------------------------------------------------------------------

tbl_smb2_main_player_starting_x_positions:
    .byte $28, $18
    .byte $38, $28

tbl_smb2_main_alternate_entrance_y_position_offsets:
    .byte $08, $00

tbl_smb2_main_player_starting_y_positions:
    .byte $00, $20, $b0, $50, $00, $00, $b0, $b0
    .byte $f0

off_smb2_main_player_background_priorities:
    .byte $00, $20, $00, $00, $00, $00, $00, $00

off_smb2_main_game_timer_hundreds_digits:
    .byte $20  ; dummy byte, used as part of bg priority data
    .byte $04, $03, $02

handler_smb2_main_setup_entrance_and_game_timer:
    LDA ScreenLeft_PageLoc  ; set current page for area objects
    STA Player_PageLoc  ; as page location for player
    LDA #$28  ; store value here
    STA VerticalForceDown  ; for fractional movement downwards if necessary
    LDA #$01  ; set high byte of player position and
    STA PlayerFacingDir  ; set facing direction so that player faces right
    STA Player_Y_HighPos
    LDA #$00  ; set player state to on the ground by default
    STA Player_State
    DEC Player_CollisionBits  ; initialize player's collision bits
    LDY #$00  ; initialize halfway page
    STY HalfwayPage
    LDA AreaType  ; check area type
    BNE bra_smb2_main_set_swimming_flag  ; if water type, set swimming flag, otherwise do not set
    INY
bra_smb2_main_set_swimming_flag:
    STY SwimmingFlag
    LDX PlayerEntranceCtrl  ; get starting position loaded from header
    LDY AltEntranceControl  ; check alternate mode of entry flag for 0 or 1
    BEQ bra_smb2_main_set_player_starting_position
    CPY #$01
    BEQ bra_smb2_main_set_player_starting_position
    LDX tbl_smb2_main_alternate_entrance_y_position_offsets-2,y  ; if not 0 or 1, override start pos from header with alt offset
bra_smb2_main_set_player_starting_position:
    LDA tbl_smb2_main_player_starting_x_positions,y  ; load appropriate horizontal position
    STA Player_X_Position  ; and vertical positions for the player, using
    LDA tbl_smb2_main_player_starting_y_positions,x  ; AltEntranceControl as offset for horizontal and either
    STA Player_Y_Position  ; the original offset from the header or alt offset for vertical
    LDA off_smb2_main_player_background_priorities,x
    STA Player_SprAttrib  ; set player sprite attributes using offset in X
    JSR sub_smb2_main_get_player_colors  ; get appropriate player palette
    LDY GameTimerSetting  ; get timer control value from header
    BEQ bra_smb2_main_check_joypad_override  ; if set to zero, branch (do not use dummy byte for this)
    LDA FetchNewGameTimerFlag  ; do we need to set the game timer? if not, use
    BEQ bra_smb2_main_check_joypad_override  ; old game timer setting
    LDA off_smb2_main_game_timer_hundreds_digits,y  ; if game timer is set and game timer flag is also set,
    STA GameTimerDisplay  ; use value of game timer control for first digit of game timer
    LDA #$01
    STA GameTimerDisplay+2  ; set last digit of game timer to 1
    LSR
    STA GameTimerDisplay+1  ; set second digit of game timer
    STA FetchNewGameTimerFlag  ; clear flag for game timer reset
    STA StarInvincibleTimer  ; clear star mario timer
bra_smb2_main_check_joypad_override:
    LDY JoypadOverride  ; if controller bits not set, branch to skip this part
    BEQ bra_smb2_main_check_swimming_entrance
    LDA #$03  ; set player state to climbing
    STA Player_State
    LDX #$00  ; set offset for first slot, for block object
    JSR sub_smb2_main_initialize_block_position
    LDA #$f0  ; set vertical coordinate for block object
    STA Block_Y_Position
    LDX #$05  ; set offset in X for last enemy object buffer slot
    LDY #$00  ; set offset in Y for object coordinates used earlier
    JSR sub_smb2_main_setup_vine  ; do a sub to grow vine
bra_smb2_main_check_swimming_entrance:
    LDY AreaType  ; if level not water-type,
    BNE bra_smb2_main_select_player_entrance_handler  ; skip this subroutine
    JSR sub_smb2_main_setup_bubble  ; otherwise, execute sub to set up air bubbles
bra_smb2_main_select_player_entrance_handler:
    LDA #$07  ; set to run player entrance subroutine
    STA GameEngineSubroutine  ; on the next frame of game engine
    RTS

; -------------------------------------------------------------------------------------

; page numbers are in order from level numbers 1 to 4
tbl_smb2_main_halfway_page_nibbles:
    .byte $66, $60
    .byte $88, $60
    .byte $66, $70
    .byte $77, $60
    .byte $d6, $00
    .byte $77, $80
    .byte $70, $b0
    .byte $00, $00
    .byte $00, $00

handler_smb2_main_player_lose_life:
    INC DisableScreenFlag  ; disable screen and IRQ updates
    LDA #$00
    STA IRQUpdateFlag
    LDA #Silence  ; silence music
    STA EventMusicQueue
    DEC NumberofLives  ; take one life from player
    BPL bra_smb2_main_prepare_life_restart  ; if player still has lives, branch
    LDA #$00
    STA OperMode_Task  ; initialize mode task,
    LDA #GameOverMode  ; switch to game over mode
    STA OperMode  ; and leave
    RTS
bra_smb2_main_prepare_life_restart:
    LDA WorldNumber  ; multiply world number by 2 and use
    ASL  ; as offset
    TAX
    LDA LevelNumber  ; if in level 3 or 4, increment
    AND #$02  ; offset by one byte, otherwise
    BEQ bra_smb2_main_select_halfway_page_nibble  ; leave offset alone
    INX
bra_smb2_main_select_halfway_page_nibble:
    LDY tbl_smb2_main_halfway_page_nibbles,x  ; get halfway page number with offset
    LDA LevelNumber  ; check area number's LSB
    LSR
    TYA  ; if in level 2 or 4, use lower nybble
    BCS bra_smb2_main_mask_halfway_page_nibble
    LSR  ; move higher nybble to lower if
    LSR  ; level number is 1 or 3
    LSR
    LSR
bra_smb2_main_mask_halfway_page_nibble:
    AND #%00001111  ; mask out all but lower nybble
    CMP ScreenLeft_PageLoc
    BEQ bra_smb2_main_store_halfway_page  ; left side of screen must be at the halfway page,
    BCC bra_smb2_main_store_halfway_page  ; otherwise player must start at the
    LDA #$00  ; beginning of the level
bra_smb2_main_store_halfway_page:
    STA HalfwayPage  ; store as halfway page for player
    JMP loc_smb2_main_restart_game  ; continue the game

; -------------------------------------------------------------------------------------
