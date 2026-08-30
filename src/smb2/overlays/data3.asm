; Super Mario Bros. 2 DATA3 payload
; Reconstructed from the pinned doppelganger ca65 listing

.scope smb2_data3
    .include "../system/hardware.inc"
    .org $c5d0
    .include "data3/ending.inc"
    .include "data3/world_9.inc"
    .include "data3/ending_audio.inc"
    .include "data3/victory_music.inc"
    .reloc
.endscope
