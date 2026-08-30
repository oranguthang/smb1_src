.ifndef ANN_CONSTANTS_INC
ANN_CONSTANTS_INC = 1

; Title packet resident in NSMMAIN before an interchangeable payload is loaded
off_ann_title_map_packet = off_ann_title_map

; Packets supplied by the interchangeable ANN disk payloads
off_ann_ending_attribute_packet = $c88d
off_ann_ending_palette_packet = $c896
off_ann_mario_thanks_packet = $c8aa
off_ann_ending_message_1 = $c8c2
off_ann_ending_message_2 = $c8d8
off_ann_ending_message_3 = $c8ee
off_ann_ending_message_4 = $c902
off_ann_ending_message_5 = $c913
off_ann_ending_message_6 = $c92a
off_ann_ending_message_7 = $c942
off_ann_ending_message_8 = $c95a
off_ann_ending_palette_extension = $c973
off_ann_throne_room_map = $c983

; Course streams supplied by the supplemental-course payload
off_ann_supplemental_enemy_castle_4_smb2 = $c5d0
off_ann_supplemental_enemy_castle_2_smb2 = $c605
off_ann_supplemental_enemy_castle_5 = $c62c
off_ann_supplemental_enemy_castle_8_smb2 = $c641
off_ann_supplemental_enemy_overworld_2 = $c681
off_ann_supplemental_enemy_overworld_4 = $c69e
off_ann_supplemental_enemy_overworld_7_vs = $c6c5
off_ann_supplemental_enemy_overworld_8_vs = $c6e8
off_ann_supplemental_enemy_overworld_11 = $c705
off_ann_supplemental_enemy_overworld_26 = $c729
off_ann_supplemental_enemy_overworld_14 = $c72f
off_ann_supplemental_enemy_overworld_15 = $c752
off_ann_supplemental_enemy_overworld_17 = $c75b
off_ann_supplemental_enemy_overworld_18 = $c795
off_ann_supplemental_enemy_overworld_19 = $c7c0
off_ann_supplemental_enemy_overworld_20 = $c7f0
off_ann_supplemental_enemy_overworld_27 = $c80c
off_ann_supplemental_enemy_underground_4 = $c812
off_ann_supplemental_enemy_water_1 = $c82b
off_ann_supplemental_enemy_water_2_vs = $c83c
off_ann_supplemental_enemy_water_4_smb2 = $c86a
off_ann_supplemental_area_castle_4_smb2 = $c878
off_ann_supplemental_area_castle_2_smb2 = $c8ed
off_ann_supplemental_area_castle_5 = $c97a
off_ann_supplemental_area_castle_8_smb2 = $ca05
off_ann_supplemental_area_overworld_2 = $cad8
off_ann_supplemental_area_overworld_4 = $cb45
off_ann_supplemental_area_overworld_7_vs = $cbd6
off_ann_supplemental_area_overworld_8_vs = $cc1f
off_ann_supplemental_area_overworld_11 = $cc8c
off_ann_supplemental_area_overworld_26 = $cccd
off_ann_supplemental_area_overworld_14 = $cce2
off_ann_supplemental_area_overworld_15 = $cd49
off_ann_supplemental_area_overworld_17 = $cdbe
off_ann_supplemental_area_overworld_18 = $ce53
off_ann_supplemental_area_overworld_19 = $ceca
off_ann_supplemental_area_overworld_20 = $cf47
off_ann_supplemental_area_overworld_27 = $cfa8
off_ann_supplemental_area_underground_4 = $cfd3
off_ann_supplemental_area_water_1 = $d02c
off_ann_supplemental_area_water_2_vs = $d06d
off_ann_supplemental_area_water_4_smb2 = $d136

; Entry point reconstructed with the later-engine game-over module
sub_advance_ann_game_after_course = sub_terminate_game
con_ann_course_number_cutoff = 8
con_ann_final_course_number = 7
con_ann_victory_disk_data_task = 5
con_ann_victory_disk_save_task = 13
con_ann_brick_with_coins_line_metatile = $57
con_ann_brick_with_coins_metatile = $5c
con_ann_normal_floor_metatile = $6a
con_ann_water_pipe_top_metatile = $6c
con_ann_water_pipe_bottom_metatile = $6d
con_ann_flagpole_tip_metatile = $6e
con_ann_hard_mode_course = 3
con_ann_hard_mode_goal = 3
con_ann_small_area_object_offset = $18
con_ann_row_13_area_object_offset = $25
con_ann_row_14_area_object_offset = $31
con_ann_game_mode_process = 5
con_ann_player_size_change_routine = 9
con_ann_game_timer_digit_offset = $17
con_ann_game_timer_status_selector = $a2
con_ann_flagpole_one_up_score = 5
con_ann_invisible_blank_metatile = $5e
con_ann_coin_digit_offset = $11
con_ann_score_digit_offset = $0b
con_ann_score_coin_status_nibbles = $01
con_ann_poison_mushroom_power_up = 4
con_ann_special_mushroom_power_up = 5
con_ann_block_item_count = $0a
con_ann_block_metatile_last_index = $0e
con_ann_loop_command_count = $0a
con_ann_lakitu_spawn_delay = 3
con_ann_lakitu_hard_mode_x_offset = $60
con_ann_swimming_cheep_cheep_y_force = $40
con_ann_end_area_status_selector = 2
con_ann_piranha_plant_player_cutoff = $13
con_ann_balance_platform_object = $24
con_ann_piranha_plant_b_object = $04

handler_ann_ending_screen = $c5d0
handler_ann_ending_message = $c61f
handler_ann_victory_extra_lives = $c663
handler_ann_victory_palette_cycle = $c6b1
handler_ann_victory_lives_draw = $c6f7
handler_ann_victory_toad = $c713
handler_ann_victory_disk_save = $c72e
handler_ann_set_ending_player_name = $c86f
handler_late_fds_upside_down_pipe_high = $c470
handler_late_fds_upside_down_pipe_low = $c475
handler_late_fds_move_upside_down_piranha_plant = $c4c0
sub_ann_hard_mode_spring = $c4fe
sub_ann_hard_mode_render_spring = $c50c
sub_late_fds_initialize_hard_course_checkpoints = $c3b7

; Title handlers resident in NSMMAIN before an interchangeable payload is loaded
handler_ann_title_cursor = handler_ann_title_cursor_background
handler_ann_title_score = handler_ann_title_score_background

off_ann_player_palette = tbl_player_palette_colors
off_ann_title_player_name = off_ann_game_text_packets + 3
off_ann_thanks_player_name = off_mario_thanks_message + 13
off_ann_player_physics_parameters = tbl_jump_gravity
off_ann_player_friction_shift_opcode = bra_return_from_player_physics - 6

; Guest portrait slices resident in NSMMAIN
off_ann_toad_graphics_1 = off_ann_guest_portrait_chr_1
off_ann_toad_graphics_2 = off_ann_guest_portrait_chr_2
off_ann_toad_graphics_3 = off_ann_guest_portrait_chr_3
off_ann_toad_graphics_4 = off_ann_guest_portrait_chr_4
off_ann_toad_graphics_5 = off_ann_guest_portrait_chr_1 + $11
off_ann_toad_graphics_6 = off_ann_guest_portrait_chr_2 + $11
off_ann_toad_graphics_7 = off_ann_guest_portrait_chr_3 + $11

con_ann_toad_chr_address = $0cd0
con_ann_guest_chr_address = $07a0
con_ann_guest_letter_chr_address = $0ee0
con_ann_toad_palette_vram_index = 29
sub_ann_tally_timer_score = handler_award_game_timer_points + $0b
sub_ann_bounce_player_from_enemy = loc_bounce_player_from_enemy
sub_draw_ann_warp_text = handler_draw_ann_warp_text
sub_load_area_pointer = sub_ann_load_course
bra_advance_victory_mode_task = bra_advance_ann_victory_mode_task
bra_exit_world_completion = bra_exit_ann_world_completion
sub_write_game_text = handler_write_ann_game_text
tbl_area_object_loopback_offsets = tbl_ann_course_loopback_offsets
tbl_area_pointers = tbl_ann_course_area_offsets
tbl_world_area_pointer_offsets = tbl_ann_course_world_offsets
tbl_warp_zone_number_tiles = tbl_ann_warp_zone_number_tiles

.endif
