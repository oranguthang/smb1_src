; Standalone ANN NSMDATA4 verification entrypoint

.include "profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../memory/ram.inc"

sub_ann_get_course_type = $c28c
tbl_halfway_page_nibbles = $7088
sub_get_pipe_height = $77c9
sub_initialize_ann_pipe_piranha_plant = $77da
sub_find_empty_enemy_slot = $77f9
sub_render_under_part = $7a2e
tbl_vertical_pipe_metatiles = $7786

.p02

.segment "OVERLAY"
.org $c296

.include "../platforms/ann/extended_course_loader.asm"
.include "../platforms/ann/extended_course_tables.asm"
.include "../platforms/ann/extended_life_down.asm"

; Align the shared gameplay extensions with their supplemental-course addresses
    .res $ad, $ff

.include "../platforms/ann/overlay_gameplay.asm"

; Original disk alignment before the first extended course stream
    .res $b7, $ff

.include "../platforms/ann/extended_course_enemy_streams.asm"
.include "../platforms/ann/extended_course_area_streams.asm"
