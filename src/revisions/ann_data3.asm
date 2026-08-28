; Standalone ANN NSMDATA3 verification entrypoint

.include "profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../memory/hardware.inc"
.include "../memory/ram.inc"
.include "../platforms/ann/audio_data3_ram.inc"

sub_handle_square_2_sound_effect = $d591

.p02

.segment "OVERLAY"
.org $c5d0

.include "../platforms/ann/ending_data3.asm"

; Preserve the unused disk-file window before the alternate audio engine
    .res $30d, $ff

.include "../platforms/ann/audio_data3_engine.asm"
.include "../platforms/ann/audio_data3_fds.asm"
.include "../platforms/ann/audio_data3_music.asm"
.include "../platforms/ann/audio_data3_output.asm"
