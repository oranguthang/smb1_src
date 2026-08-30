; Standalone ANN NSMDATA4 verification entrypoint

.include "../profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../../memory/ram.inc"
.include "main_interface.inc"

.p02

.segment "OVERLAY"
.org $c296

.include "../../platforms/late_fds/ann/courses/hard/loader.asm"
.include "../../platforms/late_fds/ann/courses/hard/tables.asm"
.include "../../platforms/late_fds/ann/courses/hard/life_down.asm"

; Align the shared gameplay extensions with their supplemental-course addresses
    .res $ad, $ff

.include "../../platforms/late_fds/ann/gameplay/overlay.asm"

; Original disk alignment before the first extended course stream
    .res $b7, $ff

.include "../../platforms/late_fds/ann/courses/hard/enemy_streams.asm"
.include "../../platforms/late_fds/ann/courses/hard/area_streams.asm"
