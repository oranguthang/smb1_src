; Standalone ANN NSMDATA3 verification entrypoint

.include "../profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../../memory/hardware.inc"
.include "../../memory/ram.inc"
.include "../../platforms/late_fds/ann/audio/ram.inc"
.include "main_interface.inc"

.p02

.segment "OVERLAY"
.org $c5d0

.include "../../platforms/late_fds/ann/ending/overlay.asm"

; Preserve the unused disk-file window before the alternate audio engine
    .res $30d, $ff

.include "../../platforms/late_fds/ann/audio/engine.asm"
.include "../../platforms/late_fds/ann/audio/fds.asm"
.include "../../platforms/late_fds/ann/audio/music.asm"
.include "../../platforms/late_fds/ann/audio/output.asm"
