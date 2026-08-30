; Super Mario Bros. 2 hard-courses payload
; Reconstructed from the pinned doppelganger ca65 listing

.scope smb2_hard_courses
    .include "../../platforms/late_fds/smb2/system/hardware.inc"
    .org $c2b4
    .include "../../platforms/late_fds/smb2/overlays/hard_courses/worlds_a_d_setup.asm"
    .include "../../platforms/late_fds/smb2/overlays/hard_courses/wind_and_pipes.asm"
    .include "../../platforms/late_fds/smb2/overlays/hard_courses/course_bank.asm"
    .reloc
.endscope
