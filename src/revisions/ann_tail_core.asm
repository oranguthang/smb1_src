; Standalone ANN tail-core verification entrypoint

.include "profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../memory/hardware.inc"
.include "../memory/ram.inc"

sub_dispatch_inline_handler = $6d0f
sub_move_all_sprites_offscreen = $628a
sub_initialize_name_tables = $6d24
handler_run_screen_task = $654c
sub_ann_initialize_life_down_extension = $c3b7
handler_ann_ending_text_player_setup = $c86f
off_ann_save_data = $d2e3
off_ann_player_physics_parameters = $7fe4
off_ann_player_friction_shift_opcode = $8145
off_ann_title_player_name = $66ed
off_ann_thanks_player_name = $6cdc
off_ann_player_palette = $65be
sub_game_core_routine = $7ab9
sub_update_number = $883a
sub_initialize_memory = $6f93
handler_initialize_area = $6ec9
handler_secondary_game_setup = $6f48
loc_finish_ann_title_screen = $63b9
sub_terminate_game = $7109
loc_restart_game = $7119

.p02

.segment "PRG"
.org $bfbf

.include "../platforms/ann/disk_loader.asm"
.include "../platforms/ann/game_over_and_physics.asm"
.include "../platforms/ann/course_loader.asm"
.include "../platforms/ann/course_tables.asm"
.include "../platforms/ann/title_menu.asm"
.include "../platforms/ann/title_setup.asm"
.include "../platforms/ann/title_map.asm"
