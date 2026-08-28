; ANN DATA2 GUEST GRAPHICS

; Guest portraits remain private extracted assets and never enter Git
off_ann_guest_portrait_chr_5:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_guest_chr.bin", $000, $060

off_ann_guest_portrait_chr_6:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_guest_chr.bin", $060, $060

off_ann_guest_portrait_chr_7:
    .incbin "../../../../../assets/generated/platforms/ann_fds/source/supplemental_guest_chr.bin", $0c0, $060

off_ann_guest_portrait_chr_supplemental_end:
.assert off_ann_guest_portrait_chr_supplemental_end - off_ann_guest_portrait_chr_5 = $120, error, "ANN DATA2 guest CHR must be 288 bytes"
