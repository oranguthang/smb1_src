handler_smb2_main_reset_handler:
    LDA Mirror_FDS_CTRL_REG  ; get setting previously used by FDS bios
    AND #$f7  ; and set for vertical mirroring
    STA FDS_CTRL_REG
    LDA WorldNumber  ; get world number and save it temporarily
    PHA
    LDY #ColdBootOffset  ; load default cold boot pointer
    LDX #$05
bra_smb2_main_check_warm_boot_state:
    LDA TopScoreDisplay,x  ; first checkpoint, check each score digit
    CMP #10  ; in the top score for a valid digit
    BCS bra_smb2_main_initialize_after_boot_check  ; if even one digit isn't valid (greater than 10 decimal)
    DEX  ; then branch to perform cold boot
    BPL bra_smb2_main_check_warm_boot_state
    LDA WarmBootValidation  ; second checkpoint, check to see if
    CMP #$a5  ; another location has a specific value
    BNE bra_smb2_main_initialize_after_boot_check
    LDY #WarmBootOffset  ; if passed both, load warm boot pointer
bra_smb2_main_initialize_after_boot_check:
    JSR sub_smb2_main_initialize_memory  ; clear memory using pointer in Y
    STA SND_DELTA_REG+1
    STA OperMode  ; now manually reset some other stuff
    STA DiskIOTask
    PLA
    STA WorldNumber
    LDA #$a5  ; set warm boot flag in case the player hits reset
    STA WarmBootValidation
    STA PseudoRandomBitReg  ; set seed for pseudorandom register
    LDA #%00001111
    STA SND_MASTERCTRL_REG  ; enable all sound channels except dmc
    LDA #%00000110
    STA PPU_MASK  ; turn off clipping for OAM and background
    JSR sub_smb2_main_move_all_sprites_offscreen
    JSR sub_smb2_main_initialize_name_tables
    INC DisableScreenFlag
    LDA #$c0  ; set FDS BIOS flag to use NMI vector at $dffa
    STA FDSBIOS_IRQFlag  ; enable all interrupts
    CLI
    LDA Mirror_PPU_CTRL
    ORA #%10000000
    JSR sub_smb2_main_write_ppu_reg1
loc_smb2_main_wait_forever_after_reset_failure:
    LDA $00  ; endless loop
    JMP loc_smb2_main_wait_forever_after_reset_failure

; -------------------------------------------------------------------------------------
