; Super Mario Bros. 2 DATA4 payload
; Reconstructed from the pinned doppelganger ca65 listing

.scope smb2_data4
    .include "../system/hardware.inc"
    .org $c2b4
    .include "data4/worlds_a_d_setup.inc"
    .include "data4/wind_and_pipes.inc"
    .include "data4/course_bank.inc"
    .reloc
.endscope
