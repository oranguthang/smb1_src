; Encode the ANN title screen as PPU display-list packets

off_ann_title_map:
    .byte >$2085, <$2085, $01, $44  ; Sign upper-left corner
    .byte >$2086, <$2086, $55, $48  ; Sign top edge
    .byte >$209b, <$209b, $01, $49  ; Sign upper-right corner
    .byte >$20a5, <$20a5, $c9, $46  ; Sign left edge
    .byte >$20bb, <$20bb, $c9, $4a  ; Sign right edge

    .byte >$20a6, <$20a6, $15
    .byte $ec, $ed, $ee, $ef, $f3, $f4, $f5, $f6
    .byte $f7, $f8, $d0, $d1, $d8, $d8, $de, $d1
    .byte $d0, $da, $de, $d1, $26  ; Logo row 1

    .byte >$20c6, <$20c6, $15
    .byte $26, $26, $26, $26, $26, $26, $26, $26
    .byte $26, $26, $d2, $d3, $db, $db, $db, $d9
    .byte $db, $dc, $db, $df, $26  ; Logo row 2

    .byte >$20e6, <$20e6, $15
    .byte $26, $26, $26, $26, $26, $26, $26, $26
    .byte $26, $26, $d4, $d5, $d4, $d9, $db, $e2
    .byte $d4, $da, $db, $e0, $26  ; Logo row 3

    .byte >$2106, <$2106, $55, $26  ; Blank logo row
    .byte >$2110, <$2110, $0a
    .byte $d6, $d7, $d6, $d7, $e1, $26, $d6, $dd, $e1, $e1

    .byte >$2126, <$2126, $15
    .byte $d0, $e8, $d1, $d0, $d1, $de, $d1, $d8
    .byte $d0, $d1, $26, $de, $d1, $de, $d1, $d0
    .byte $d1, $d0, $d1, $26, $26

    .byte >$2146, <$2146, $15
    .byte $db, $42, $42, $db, $e3, $db, $e3, $db
    .byte $db, $e3, $26, $db, $e3, $db, $e3, $db
    .byte $e3, $db, $e3, $26, $26

    .byte >$2166, <$2166, $46, $db
    .byte >$216c, <$216c, $0f
    .byte $df, $db, $db, $db, $26, $db, $df, $db
    .byte $df, $db, $db, $d2, $e5, $26, $26

    .byte >$2186, <$2186, $15
    .byte $db, $db, $db, $de, $43, $db, $db, $db
    .byte $db, $db, $26, $db, $e3, $db, $e3, $db
    .byte $db, $db, $e3, $26, $26

    .byte >$21a6, <$21a6, $15
    .byte $db, $db, $db, $db, $db, $db, $db, $db
    .byte $d4, $d9, $26, $db, $d9, $db, $db, $d4
    .byte $d9, $d4, $d9, $da, $26

    .byte >$21c5, <$21c5, $17
    .byte $5f, $95, $95, $95, $95, $95, $95, $95
    .byte $95, $97, $98, $78, $95, $96, $95, $95
    .byte $97, $98, $97, $98, $95, $78, $7a  ; Sign lower edge

    .byte >$21ee, <$21ee, $0e
    .byte $cf, $01, $09, $08, $06, $24, $17
    .byte $12, $17, $1d, $0e, $17, $0d, $18  ; Copyright

    .byte >$224d, <$224d, $0a
    .byte $16, $0a, $1b, $12, $18, $24, $10, $0a, $16, $0e  ; Mario game
    .byte >$228d, <$228d, $0a
    .byte $15, $1e, $12, $10, $12, $24, $10, $0a, $16, $0e  ; Luigi game
    .byte >$22ed, <$22ed, $04, $1d, $18, $19, $28  ; Top score label
    .byte >$22f7, <$22f7, $01, $00  ; Initial top score

    .byte >$23c9, <$23c9, $01, $d5
    .byte >$23ca, <$23ca, $46, $f5
    .byte >$23d1, <$23d1, $47, $55
    .byte >$23d9, <$23d9, $47, $55
    .byte >$23cc, <$23cc, $43, $55
    .byte >$23d6, <$23d6, $01, $dd
    .byte >$23de, <$23de, $01, $5d
    .byte >$23e2, <$23e2, $04, $55, $aa, $aa, $aa
    .byte >$23ea, <$23ea, $05, $95, $aa, $aa, $aa, $2a  ; Attributes

    .byte $00
off_ann_title_map_end:
