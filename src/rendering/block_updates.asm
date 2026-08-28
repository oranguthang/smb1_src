; Block replacement data and entry points used by scenery and object interactions
; $00 - temp store for offset control bit
; $01 - temp vram buffer offset
; $02 - temp store for vertical high nybble in block buffer routine
; $03 - temp adder for high byte of name table address
; $04, $05 - name table address low/high
; $06, $07 - block buffer address low/high

tbl_block_metatile_tiles:
    .byte $45, $45, $47, $47
    .byte $47, $47, $47, $47
    .byte $57, $58, $59, $5a
    .byte $24, $24, $24, $24
    .byte $26, $26, $26, $26

sub_remove_coin_axe:
    LDY #$41  ; set low byte so offset points to $0341
    LDA #$03  ; load offset for default blank metatile
    LDX ram_area_type  ; check area type
    BNE bra_write_blank_metatile  ; if not water type, use offset
    LDA #$04  ; otherwise load offset for blank metatile used in water
bra_write_blank_metatile:
    JSR sub_put_block_metatile  ; do a sub to write blank metatile to vram buffer
    LDA #$06
    STA ram_vram_buffer_addr_ctrl  ; set vram address controller to $0341 and leave
    RTS

sub_replace_block_metatile:
    JSR sub_write_block_metatile  ; write metatile to vram buffer to replace block object
    INC ram_block_residual_counter  ; increment unused counter (residual code)
    DEC ram_block_rep_flag,x  ; decrement flag (residual code)
    RTS  ; leave
