off_smb2_main_player_name_data:
    .byte $16, $0a, $1b, $12, $18  ; "MARIO"
    .byte $15, $1e, $12, $10, $12  ; "LUIGI"

off_smb2_main_player_palette_data:
    .byte $22, $16, $27, $18
    .byte $22, $30, $27, $19

tbl_smb2_main_player_name_offsets:
    .byte $04, $09  ; note that offsets point to last byte

sub_smb2_main_patch_player_name_pal:
    LDY SelectedPlayer  ; get offset based on selected player
    LDA tbl_smb2_main_player_name_offsets,y
    PHA
    INY
    STY $00  ; save player + 1 temporarily (mario = 1, luigi = 2)
    TAY
    LDX #$04
bra_smb2_main_name_patch:
    LDA off_smb2_main_player_name_data,y  ; get name of selected player
    STA tbl_smb2_main_top_status_bar_packet+3,x  ; patch to top status bar and victory message
    STA off_smb2_main_thank_you_message+$d,x
    DEY
    DEX
    BPL bra_smb2_main_name_patch
    PLA  ; subtract player + 1 from offset loaded earlier
    SEC  ; to get proper offset for palette loading
    SBC $00
    TAY
    LDX #$03
bra_smb2_main_pal_patch:
    LDA off_smb2_main_player_palette_data,y  ; overwrite palette with the appropriate one
    STA tbl_smb2_main_player_palette_colors,x
    DEY
    DEX
    BPL bra_smb2_main_pal_patch
    RTS

; -------------------------------------------------------------------------------------

off_smb2_main_title_screen_gfx_data:
    .byte $20, $84, $01, $44
    .byte $20, $85, $57, $48
    .byte $20, $9c, $01, $49
    .byte $20, $a4, $c9, $46
    .byte $20, $a5, $57, $26
    .byte $20, $bc, $c9, $4a
    .byte $20, $a5, $0a, $d0, $d1, $d8, $d8, $de, $d1, $d0, $da, $de, $d1
    .byte $20, $c5, $17, $d2, $d3, $db, $db, $db, $d9, $db, $dc, $db, $df
    .byte $26, $26, $26, $26, $26, $26, $26, $26, $26, $26, $26, $26, $26
    .byte $20, $e5, $17, $d4, $d5, $d4, $d9, $db, $e2, $d4, $da, $db, $e0
    .byte $26, $26, $26, $26, $26, $26, $26, $26, $26, $26, $26, $26, $26
    .byte $21, $05, $57, $26
    .byte $21, $05, $0a, $d6, $d7, $d6, $d7, $e1, $26, $d6, $dd, $e1, $e1
    .byte $21, $25, $17, $d0, $e8, $d1, $d0, $d1, $de, $d1, $d8, $d0, $d1
    .byte $26, $de, $d1, $de, $d1, $d0, $d1, $d0, $d1, $26, $26, $d0, $d1
    .byte $21, $45, $17, $db, $42, $42, $db, $42, $db, $42, $db, $db, $42
    .byte $26, $db, $42, $db, $42, $db, $42, $db, $42, $26, $26, $db, $42
    .byte $21, $65, $46, $db
    .byte $21, $6b, $11, $df, $db, $db, $db, $26, $db, $df, $db, $df, $db
    .byte $db, $e4, $e5, $26, $26, $ec, $ed
    .byte $21, $85, $17, $db, $db, $db, $de, $43, $db, $e0, $db, $db, $db
    .byte $26, $db, $e3, $db, $e0, $db, $db, $e6, $e3, $26, $26, $ee, $ef
    .byte $21, $a5, $17, $db, $db, $db, $db, $42, $db, $db, $db, $d4, $d9
    .byte $26, $db, $d9, $db, $db, $d4, $d9, $d4, $d9, $e7, $26, $de, $da
    .byte $21, $c4, $19, $5f, $95, $95, $95, $95, $95, $95, $95, $95, $97
    .byte $98, $78, $95, $96, $95, $95, $97, $98, $97, $98, $95, $78, $95
    .byte $f0, $7a
    .byte $21, $ef, $0e, $cf, $01, $09, $08, $06, $24, $17, $12, $17, $1d
    .byte $0e, $17, $0d, $18
    .byte $22, $4d, $0a, $16, $0a, $1b, $12, $18, $24, $10, $0a, $16, $0e
    .byte $22, $8d, $0a, $15, $1e, $12, $10, $12, $24, $10, $0a, $16, $0e
    .byte $22, $eb, $04, $1d, $18, $19, $28
    .byte $22, $f5, $01, $00
    .byte $23, $c9, $47, $55
    .byte $23, $d1, $47, $55
    .byte $23, $d9, $47, $55
    .byte $23, $cc, $43, $f5
    .byte $23, $d6, $01, $dd
    .byte $23, $de, $01, $5d
    .byte $23, $e2, $04, $55, $aa, $aa, $aa
    .byte $23, $ea, $04, $95, $aa, $aa, $2a
    .byte $00, $ff, $ff

; -------------------------------------------------------------------------------------

; GAME LEVELS DATA

; level 1-4
