off_smb2_data3_e_castle_area9:
    .byte $1f, $01, $0e, $69, $00, $1f, $0b, $78, $2d, $ff

; cloud level used in level 9-3
off_smb2_data3_e_castle_area10:
    .byte $1f, $01, $1e, $68, $06, $ff

; level 9-1 starting area
off_smb2_data3_e_ground_area25:
    .byte $1e, $05, $00, $ff

; two unused levels that have the same enemy data address as a used level
off_smb2_data3_e_ground_area26:
off_smb2_data3_e_ground_area27:

; level 9-1 water area
off_smb2_data3_e_water_area6:
    .byte $26, $8f, $05, $ac, $46, $0f, $1f, $04, $e8, $10, $38, $90, $66, $11, $fb, $3c
    .byte $9b, $b7, $cb, $85, $29, $87, $95, $07, $eb, $02, $0b, $82, $96, $0e, $c3, $0e
    .byte $ff

; level 9-2
off_smb2_data3_e_water_area7:
    .byte $1f, $01, $e6, $11, $ff

; level 9-4
off_smb2_data3_e_water_area8:
    .byte $3b, $86, $7b, $00, $bb, $02, $2b, $8e, $7a, $05, $57, $87, $27, $8f, $9a, $0c
    .byte $ff

; level 9-3
off_smb2_data3_l_castle_area9:
    .byte $55, $31, $0d, $01, $cf, $33, $fe, $39, $fe, $b2, $2e, $be, $fe, $31, $29, $8f
    .byte $9e, $43, $fe, $30, $16, $b1, $23, $09, $4e, $31, $4e, $40, $d7, $e0, $e6, $61
    .byte $fe, $3e, $f5, $62, $fa, $60, $0c, $df, $0c, $df, $0c, $d1, $1e, $3c, $2d, $40
    .byte $4e, $32, $5e, $36, $5e, $42, $ce, $38, $0d, $0b, $8e, $36, $8e, $40, $87, $37
    .byte $96, $36, $be, $3a, $cc, $5d, $06, $bd, $07, $3e, $a8, $64, $b8, $64, $c8, $64
    .byte $d8, $64, $e8, $64, $f8, $64, $fe, $31, $09, $e1, $1a, $60, $6d, $41, $9f, $26
    .byte $7d, $c7, $fd

; cloud level used by level 9-3
off_smb2_data3_l_castle_area10:
    .byte $00, $f1, $fe, $b5, $0d, $02, $fe, $34, $07, $cf, $ce, $00, $0d, $05, $8d, $47
    .byte $fd

; level 9-1 starting area
off_smb2_data3_l_ground_area25:
    .byte $50, $02, $9f, $38, $ee, $01, $12, $b9, $77, $7b, $de, $0f, $6d, $c7, $fd

; two unused levels
off_smb2_data3_l_ground_area26:
    .byte $fd
off_smb2_data3_l_ground_area27:
    .byte $fd

; level 9-1 water area
off_smb2_data3_l_water_area6:
    .byte $00, $a1, $0a, $60, $19, $61, $28, $62, $39, $71, $58, $62, $69, $61, $7a, $60
    .byte $7c, $f5, $a5, $11, $fe, $20, $1f, $80, $5e, $21, $80, $3f, $8f, $65, $d6, $74
    .byte $5e, $a0, $6f, $66, $9e, $21, $c3, $37, $47, $f3, $9e, $20, $fe, $21, $0d, $06
    .byte $57, $32, $64, $11, $66, $10, $83, $a7, $87, $27, $0d, $09, $1d, $4a, $5f, $38
    .byte $6d, $c1, $af, $26, $6d, $c7, $fd

; level 9-2
off_smb2_data3_l_water_area7:
    .byte $50, $11, $d7, $73, $fe, $1a, $6f, $e2, $1f, $e5, $bf, $63, $c7, $a8, $df, $61
    .byte $15, $f1, $7f, $62, $9b, $2f, $a8, $72, $fe, $10, $69, $f1, $b7, $25, $c5, $71
    .byte $33, $ac, $5f, $71, $8d, $4a, $aa, $14, $d1, $71, $17, $95, $26, $42, $72, $42
    .byte $73, $12, $7a, $14, $c6, $14, $d5, $42, $fe, $11, $7f, $b8, $8d, $c1, $cf, $26
    .byte $6d, $c7, $fd

; level 9-4
off_smb2_data3_l_water_area8:
    .byte $57, $00, $0b, $3f, $0b, $bf, $0b, $bf, $73, $36, $9a, $30, $a5, $64, $b6, $31
    .byte $d4, $61, $0b, $bf, $13, $63, $4a, $60, $53, $66, $a5, $34, $b3, $67, $e5, $65
    .byte $f4, $60, $0b, $bf, $14, $60, $53, $67, $67, $32, $c4, $62, $d4, $31, $f3, $61
    .byte $fa, $60, $0b, $bf, $04, $30, $09, $61, $14, $65, $63, $65, $6a, $60, $0b, $bf
    .byte $0f, $38, $0b, $bf, $1d, $41, $3e, $42, $5f, $20, $ce, $40, $0b, $bf, $3d, $47
    .byte $fd

; -------------------------------------------------------------------------------------

; unused space

    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
