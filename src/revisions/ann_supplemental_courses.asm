; Standalone ANN NSMDATA2 verification entrypoint

.include "profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../memory/ram.inc"

sub_get_pipe_height = $77c9
sub_initialize_ann_pipe_piranha_plant = $77da
sub_find_empty_enemy_slot = $77f9
sub_render_under_part = $7a2e
tbl_vertical_pipe_metatiles = $7786

.p02

.segment "OVERLAY"
.org $c470

.include "../platforms/ann/overlay_gameplay.asm"

; Original disk alignment before the first course stream
    .res $b7, $ff

.include "../platforms/ann/supplemental_course_enemy_streams.asm"
.include "../platforms/ann/supplemental_course_area_streams.asm"
.include "../platforms/ann/supplemental_guest_chr.asm"

; NSMDATA2 occupies the complete $C470-$D270 disk-file window
    .byte $ff
