; Super Mario Bros. 2 DATA2 payload
; Reconstructed from the pinned doppelganger ca65 listing

.scope smb2_data2
    .include "../system/hardware.inc"
    .org $c470
    .include "data2/course_bank.inc"
    .reloc
.endscope
