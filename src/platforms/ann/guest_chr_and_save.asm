; ANN GUEST GRAPHICS AND INITIAL SAVE DATA

; Guest portraits remain private extracted assets and never enter Git
off_ann_guest_portrait_chr_1:
    .incbin "../../../assets/generated/platforms/ann_fds/source/guest_chr.bin", $000, $060

off_ann_guest_portrait_chr_2:
    .incbin "../../../assets/generated/platforms/ann_fds/source/guest_chr.bin", $060, $060

off_ann_guest_portrait_chr_3:
    .incbin "../../../assets/generated/platforms/ann_fds/source/guest_chr.bin", $0c0, $060

off_ann_guest_portrait_chr_4:
    .incbin "../../../assets/generated/platforms/ann_fds/source/guest_chr.bin", $120, $060

off_ann_guest_portrait_chr_end:
.assert off_ann_guest_portrait_chr_end - off_ann_guest_portrait_chr_1 = $180, error, "ANN guest CHR must be 384 bytes"

; Align the initialized save byte with its dedicated FDS save-file address
    .res 37, $ff

off_ann_save_data:
    .byte $00
