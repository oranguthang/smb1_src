; Standalone ANN NSMDATA4 verification entrypoint

.include "../profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../../memory/ram.inc"
.include "main_interface.inc"

.p02

.segment "OVERLAY"
.org $c296

.include "../../platforms/ann/courses/extended/loader.asm"
.include "../../platforms/ann/courses/extended/tables.asm"
.include "../../platforms/ann/courses/extended/life_down.asm"

; Align the shared gameplay extensions with their supplemental-course addresses
    .res $ad, $ff

.include "../../platforms/ann/gameplay/overlay.asm"

; Original disk alignment before the first extended course stream
    .res $b7, $ff

.include "../../platforms/ann/courses/extended/enemy_streams.asm"
.include "../../platforms/ann/courses/extended/area_streams.asm"
