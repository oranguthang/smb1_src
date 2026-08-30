; Super Mario Bros. 2 ending payload
; Reconstructed from the pinned doppelganger ca65 listing

.scope smb2_ending
    .include "../../platforms/late_fds/smb2/system/hardware.inc"
    .org $c5d0
    .include "../../platforms/late_fds/smb2/overlays/ending/ending.asm"
    .include "../../platforms/late_fds/smb2/overlays/ending/world_9.asm"
    .include "../../platforms/late_fds/smb2/overlays/ending/ending_audio.asm"
    .include "../../platforms/late_fds/smb2/overlays/ending/victory_music.asm"
    .reloc
.endscope
