; -------------------------------------------------------------------------------------

; Platform position offsets and the shared null initializer

tbl_platform_x_offsets_low:
    .byte $08,$0c,$f8

tbl_platform_x_offsets_high:
    .byte $00,$00,$ff

sub_offset_platform_x_position:
    LDA ram_enemy_x_position,x  ; get horizontal coordinate
    CLC
    ADC tbl_platform_x_offsets_low,y  ; add or subtract pixels depending on offset
    STA ram_enemy_x_position,x  ; store as new horizontal coordinate
    LDA ram_enemy_page_loc,x
    ADC tbl_platform_x_offsets_high,y  ; add or subtract page location depending on offset
    STA ram_enemy_page_loc,x  ; store as new page location
.if con_revision_profile <> con_revision_profile_ann
    RTS  ; and go back
.endif

; --------------------------------

handler_end_enemy_initialization:
    RTS
