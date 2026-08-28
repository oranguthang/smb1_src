; Standalone ANN NSMDATA3 verification entrypoint

.include "profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../memory/hardware.inc"
.include "../memory/ram.inc"
.include "../platforms/ann/ending_audio_ram.inc"

sub_handle_square_2_sound_effect = $d591

.p02

.segment "OVERLAY"
.org $c5d0

.include "../platforms/ann/ending_overlay.asm"

; Preserve the unused disk-file window before the alternate audio engine
    .res $30d, $ff

.include "../platforms/ann/ending_audio_engine.asm"
.include "../platforms/ann/ending_audio_fds.asm"
.include "../platforms/ann/ending_audio_music.asm"
.include "../platforms/ann/ending_audio_output.asm"
