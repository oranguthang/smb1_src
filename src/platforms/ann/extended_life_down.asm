; ANN NSMDATA4 LIFE-DOWN EXTENSION

off_ann_life_down_extension_starts:
    .byte $76, $50, $d5, $70, $75, $b0, $00, $00

sub_ann_initialize_life_down_extension:
    LDY #$07

bra_copy_ann_life_down_extension:
    LDA off_ann_life_down_extension_starts,y
    STA tbl_halfway_page_nibbles,y
    DEY
    BPL bra_copy_ann_life_down_extension
    RTS

.assert * - off_ann_life_down_extension_starts = $14, error, "ANN DATA4 life-down extension must be 20 bytes"
