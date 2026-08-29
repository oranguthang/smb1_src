; NSMMAIN symbols imported by dynamically loaded ANN payloads

.ifndef ANN_MAIN_INTERFACE_INC
ANN_MAIN_INTERFACE_INC = 1

sub_dispatch_inline_handler = $6d0f
sub_move_sprites_offscreen = $628d
sub_print_status_bar_numbers = $6e0b
handler_initialize_screen_step = $657d
handler_write_top_status_line = $662e
handler_write_bottom_status_line = $6636
handler_select_area_palette = $65a6
handler_prepare_background_and_player_colors = $65c6
handler_show_ann_disk_prompt = $c129
handler_wait_for_ann_disk_eject = $c13c
handler_wait_for_ann_disk_insert = $c14e
handler_reset_ann_disk_loader = $c156
handler_print_ann_disk_error = $c198
handler_run_ann_disk_loader = $bfbf
tbl_ann_disk_header_id = $c0e8
off_ann_nmi_sound_handler_low = $6120
off_ann_nmi_sound_handler_high = $6121
sub_ann_award_end_area_points = $9f74

sub_get_pipe_height = $77c9
sub_initialize_ann_pipe_piranha_plant = $77da
sub_find_empty_enemy_slot = $77f9
sub_render_under_part = $7a2e
tbl_vertical_pipe_metatiles = $7786
sub_ann_get_course_type = $c28c
tbl_halfway_page_nibbles = $7088

sub_handle_square_2_sound_effect = $d591

.endif
