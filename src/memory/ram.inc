; GAME SPECIFIC DEFINES

ram_temp_byte              = $00
ram_temp_byte_high         = $01
ram_temp_byte_4            = $04
ram_temp_byte_6            = $06
ram_object_offset          = $08

ram_frame_counter          = $09

ram_saved_joypad_bits       = $06fc
ram_saved_joypad1_bits      = $06fc
ram_saved_joypad2_bits      = $06fd
ram_joypad_bit_mask         = $074a
ram_joypad_override        = $0758

ram_a_b_buttons           = $0a
ram_previous_a_b_buttons   = $0d
ram_up_down_buttons       = $0b
ram_left_right_buttons    = $0c

ram_game_engine_subroutine  = $0e

ram_mirror_ppu_ctrl_reg1  = $0778
ram_mirror_ppu_ctrl_reg2  = $0779

ram_oper_mode              = $0770
ram_oper_mode_task         = $0772
ram_screen_routine_task     = $073c

ram_game_pause_status       = $0776
ram_game_pause_timer        = $0777

ram_demo_action            = $0717
ram_demo_action_timer       = $0718

ram_timer_control          = $0747
ram_interval_timer_control  = $077f

ram_timers                = $0780
ram_select_timer           = $0780
ram_player_anim_timer       = $0781
ram_jump_swim_timer         = $0782
ram_running_timer          = $0783
ram_block_bounce_timer      = $0784
ram_side_collision_timer    = $0785
ram_jumpspring_timer       = $0786
ram_game_timer_ctrl_timer    = $0787
ram_climb_side_timer        = $0789
ram_enemy_frame_timer       = $078a
ram_frenzy_enemy_timer      = $078f
ram_bowser_fire_breath_timer = $0790
ram_stomp_timer            = $0791
ram_air_bubble_timer        = $0792
ram_scroll_interval_timer   = $0795
ram_enemy_interval_timer    = $0796
ram_brick_coin_timer        = $079d
ram_injury_timer           = $079e
ram_star_invincible_timer   = $079f
ram_screen_timer           = $07a0
ram_world_end_timer         = $07a1
ram_demo_timer             = $07a2

ram_sprite_data           = $0200

ram_sprite_y_position     = $0200
ram_sprite_tilenumber     = $0201
ram_sprite_attributes     = $0202
ram_sprite_x_position     = $0203

ram_screen_edge_page_loc    = $071a
ram_screen_edge_x_pos      = $071c
ram_screen_left_page_loc    = $071a
ram_screen_right_page_loc   = $071b
ram_screen_left_x_pos      = $071c
ram_screen_right_x_pos     = $071d

ram_player_facing_dir       = $33
ram_destination_page_loc    = $34
ram_victory_walk_control    = $35
ram_scroll_fractional      = $0768
ram_primary_msg_counter     = $0719
ram_secondary_msg_counter   = $0749

ram_horizontal_scroll      = $073f
ram_vertical_scroll        = $0740
ram_scroll_lock            = $0723
ram_scroll_thirty_two       = $073d
ram_player_x_scroll       = $06ff
ram_player_pos_for_scroll  = $0755
ram_scroll_amount          = $0775

ram_area_data              = $e7
ram_area_data_low           = $e7
ram_area_data_high          = $e8
ram_enemy_data             = $e9
ram_enemy_data_low          = $e9
ram_enemy_data_high         = $ea

ram_area_parser_task_num     = $071f
ram_column_sets            = $071e
ram_current_page_loc        = $0725
ram_current_column_pos      = $0726
ram_backloading_flag       = $0728
ram_behind_area_parser_flag  = $0729
ram_area_object_page_loc     = $072a
ram_area_object_page_sel     = $072b
ram_area_data_offset        = $072c
ram_area_obj_offset_buffer   = $072d
ram_area_object_length      = $0730
ram_staircase_control      = $0734
ram_area_object_height      = $0735
ram_mushroom_ledge_half_len  = $0736
ram_enemy_data_offset       = $0739
ram_enemy_object_page_loc    = $073a
ram_enemy_object_page_sel    = $073b
ram_metatile_buffer        = $06a1
ram_block_buffer_column_pos  = $06a0
ram_current_nt_addr_low     = $0721
ram_current_nt_addr_high    = $0720
ram_attribute_buffer       = $03f9

ram_loop_command           = $0745

ram_display_digits         = $07d7
ram_top_score_display       = $07d7
ram_score_and_coin_display   = $07dd
ram_player_score_display    = $07dd
.if con_revision_profile = con_revision_profile_ann
ram_game_timer_display      = $07ec
.else
ram_game_timer_display      = $07f8
.endif
ram_ann_game_timer_digits   = $07ec
ram_ann_game_timer_last_digit = $07ee
ram_ann_coin_display_second_last_digit = $07e7
ram_ann_coin_display_last_digit = $07e8
ram_ann_game_level_end_apu_on = $07f6
ram_ann_game_over_choice    = $07f8
ram_digit_modifier         = $0134

ram_vertical_flip_flag      = $0109
ram_floatey_num_control    = $0110
ram_shell_chain_counter     = $0125
ram_floatey_num_timer      = $012c
ram_floatey_num_x_pos      = $0117
ram_floatey_num_y_pos      = $011e
ram_flagpole_f_num_y_pos    = $010d
ram_flagpole_f_num_ymf_dummy = $010e
ram_flagpole_score         = $010f
ram_flagpole_collision_y_pos = $070f
ram_stomp_chain_counter     = $0484

ram_vram_buffer1_offset   = $0300
ram_vram_buffer1          = $0301
ram_vram_buffer2_offset   = $0340
ram_vram_buffer2          = $0341
ram_vram_buffer_addr_ctrl  = $0773
ram_sprite0_hit_detect_flag  = $0722
ram_ann_ppu_background_select = $077a
ram_disable_screen_flag     = $0774
ram_disable_intermediate   = $0769
ram_color_rotate_offset     = $06d4

ram_terrain_control        = $0727
ram_area_style             = $0733
ram_foreground_scenery     = $0741
ram_background_scenery     = $0742
ram_cloud_type_override     = $0743
ram_background_color_ctrl   = $0744
ram_area_type              = $074e
ram_area_addrs_l_offset      = $074f
ram_area_pointer           = $0750

ram_player_entrance_ctrl    = $0710
ram_game_timer_setting      = $0715
ram_alt_entrance_control    = $0752
ram_entrance_page          = $0751
ram_number_of_players       = $077a
ram_warp_zone_control       = $06d6
ram_change_area_timer       = $06de

ram_multi_loop_correct_cntr  = $06d9
ram_multi_loop_pass_cntr     = $06da

ram_fetch_new_game_timer_flag = $0757
ram_game_timer_expired_flag  = $0759

ram_primary_hard_mode       = $076a
ram_ann_primary_hard_mode   = $077d
ram_secondary_hard_mode     = $06cc
ram_world_select_number     = $076b
ram_world_select_enable_flag = $07fc
ram_continue_world         = $07fd

ram_ann_course_number       = $075f
ram_ann_hard_mode           = $07fb
ram_fds_sprite0_irq_flag    = $077b
ram_ann_render_clear_skip   = $077c
ram_fds_background_pattern_bits = $077a
ram_fds_disk_loader_task    = $07fc
ram_fds_control_mirror      = $fa
ram_fds_irq_mode            = $0101

ram_current_player         = $0753
ram_player_size            = $0754
ram_player_status          = $0756

ram_onscreen_player_info    = $075a
ram_numberof_lives         = $075a  ; used by current player
ram_halfway_page           = $075b
ram_level_number           = $075c  ; the actual dash number
ram_hidden1_up_flag         = $075d
ram_coin_tally             = $075e
ram_world_number           = $075f
ram_area_number            = $0760  ; internal number used to find areas

ram_coin_tally_for1_ups      = $0748

ram_offscreen_player_info   = $0761
ram_off_scr_numberof_lives  = $0761  ; used by offscreen player
ram_off_scr_halfway_page    = $0762
ram_off_scr_level_number    = $0763
ram_off_scr_hidden1_up_flag  = $0764
ram_off_scr_coin_tally      = $0765
ram_off_scr_world_number    = $0766
ram_off_scr_area_number     = $0767

ram_bal_platform_alignment  = $03a0
ram_platform_x_scroll     = $03a1
ram_platform_collision_flag = $03a2
ram_y_platform_top_y_pos      = $0401
ram_y_platform_center_y_pos   = $58

ram_brick_coin_timer_flag    = $06bc
ram_star_flag_task_control   = $0746

ram_pseudo_random_bit_reg    = $07a7

.if con_revision_profile = con_revision_profile_vs
ram_vs_coin_threshold_mode   = $6602
ram_vs_timer_mode            = $6603
ram_vs_player_start_mode     = $6605
.endif
ram_warm_boot_validation    = $07ff

ram_spr_shuffle_amt_offset   = $06e0
ram_spr_shuffle_amt         = $06e1
ram_spr_data_offset         = $06e4
ram_player_spr_data_offset  = $06e4
ram_enemy_spr_data_offset   = $06e5
ram_block_spr_data_offset   = $06ec
ram_alt_spr_data_offset     = $06ec
ram_bubble_spr_data_offset  = $06ee
ram_f_ball_spr_data_offset   = $06f1
ram_misc_spr_data_offset    = $06f3
ram_spr_data_offset_ctrl    = $03ee

ram_player_state          = $1d
ram_enemy_state           = $1e
ram_fireball_state        = $24
ram_block_state           = $26
ram_misc_state            = $2a

ram_player_moving_dir      = $45
ram_enemy_moving_dir       = $46

ram_spr_object_x_speed     = $57
ram_player_x_speed        = $57
ram_enemy_x_speed         = $58
ram_fireball_x_speed      = $5e
ram_block_x_speed         = $60
ram_misc_x_speed          = $64

ram_jumpspring_fixed_y_pos  = $58
ram_jumpspring_anim_ctrl    = $070e
ram_jumpspring_force       = $06db

ram_spr_object_page_loc     = $6d
ram_player_page_loc        = $6d
ram_enemy_page_loc         = $6e
ram_fireball_page_loc      = $74
ram_block_page_loc         = $76
ram_misc_page_loc          = $7a
ram_bubble_page_loc        = $83

ram_spr_object_x_position  = $86
ram_player_x_position     = $86
ram_enemy_x_position      = $87
ram_fireball_x_position   = $8d
ram_block_x_position      = $8f
ram_misc_x_position       = $93
ram_bubble_x_position     = $9c

ram_spr_object_y_speed     = $9f
ram_player_y_speed        = $9f
ram_enemy_y_speed         = $a0
ram_fireball_y_speed      = $a6
ram_block_y_speed         = $a8
ram_misc_y_speed          = $ac

ram_spr_object_y_high_pos   = $b5
ram_player_y_high_pos      = $b5
ram_enemy_y_high_pos       = $b6
ram_fireball_y_high_pos    = $bc
ram_block_y_high_pos       = $be
ram_misc_y_high_pos        = $c2
ram_bubble_y_high_pos      = $cb

ram_spr_object_y_position  = $ce
ram_player_y_position     = $ce
ram_enemy_y_position      = $cf
ram_fireball_y_position   = $d5
ram_block_y_position      = $d7
ram_misc_y_position       = $db
ram_bubble_y_position     = $e4

ram_spr_object_rel_x_pos    = $03ad
ram_player_rel_x_pos       = $03ad
ram_enemy_rel_x_pos        = $03ae
ram_fireball_rel_x_pos     = $03af
ram_bubble_rel_x_pos       = $03b0
ram_block_rel_x_pos        = $03b1
ram_misc_rel_x_pos         = $03b3

ram_spr_object_rel_y_pos    = $03b8
ram_player_rel_y_pos       = $03b8
ram_enemy_rel_y_pos        = $03b9
ram_fireball_rel_y_pos     = $03ba
ram_bubble_rel_y_pos       = $03bb
ram_block_rel_y_pos        = $03bc
ram_misc_rel_y_pos         = $03be

ram_spr_object_spr_attrib   = $03c4
ram_player_spr_attrib      = $03c4
ram_enemy_spr_attrib       = $03c5

ram_spr_object_x_move_force = $0400
ram_enemy_x_move_force     = $0401

ram_spr_object_ymf_dummy   = $0416
ram_player_y_position_fraction      = $0416
ram_enemy_ymf_dummy       = $0417
ram_bubble_ymf_dummy      = $042c

ram_spr_object_y_move_force = $0433
ram_player_y_speed_fraction    = $0433
ram_enemy_y_move_force     = $0434
ram_block_y_move_force     = $043c

ram_disable_collision_det   = $0716
ram_player_collision_bits  = $0490
ram_enemy_collision_bits   = $0491

ram_spr_obj_bound_box_ctrl   = $0499
ram_player_bound_box_ctrl   = $0499
ram_enemy_bound_box_ctrl    = $049a
ram_fireball_bound_box_ctrl = $04a0
ram_misc_bound_box_ctrl     = $04a2

ram_enemy_frenzy_buffer     = $06cb
ram_enemy_frenzy_queue      = $06cd
ram_enemy_flag            = $0f
ram_enemy_id              = $16

ram_player_gfx_offset       = $06d5
ram_player_x_speed_absolute = $0700
ram_player_friction_high     = $0701
ram_player_friction_low      = $0702
ram_running_speed          = $0703
ram_swimming_flag          = $0704
ram_player_x_speed_fraction    = $0705
ram_jump_release_min_displacement        = $0706
ram_jump_origin_y_high_pos  = $0707
ram_jump_origin_y_position = $0708
ram_player_active_gravity         = $0709
ram_player_fall_gravity     = $070a
ram_player_change_size_flag  = $070b
ram_player_anim_timer_reload    = $070c
ram_player_anim_ctrl        = $070d
ram_death_music_loaded      = $0712
ram_flagpole_sound_queue    = $0713
ram_crouching_flag         = $0714
ram_player_maximum_left_speed      = $0450
ram_player_maximum_right_speed     = $0456

ram_spr_object_offscr_bits  = $03d0
ram_player_offscreen_bits  = $03d0
ram_enemy_offscreen_bits   = $03d1
ram_f_ball_offscreen_bits   = $03d2
ram_bubble_offscreen_bits  = $03d3
ram_block_offscreen_bits   = $03d4
ram_misc_offscreen_bits    = $03d6
ram_enemy_offscr_bits_masked = $03d8

ram_cannon_offset         = $046a
ram_cannon_page_loc        = $046b
ram_cannon_x_position     = $0471
ram_cannon_y_position     = $0477
ram_cannon_timer          = $047d

ram_whirlpool_offset      = $046a
ram_whirlpool_page_loc     = $046b
ram_whirlpool_left_extent  = $0471
ram_whirlpool_length      = $0477
ram_whirlpool_flag        = $047d

ram_vine_flag_offset        = $0398
ram_vine_height            = $0399
ram_vine_obj_offset         = $039a
ram_vine_start_y_position  = $039d

ram_block_orig_y_pos       = $03e4
ram_block_b_buf_low        = $03e6
ram_block_metatile        = $03e8
ram_block_page_loc2        = $03ea
ram_block_rep_flag         = $03ec
ram_block_residual_counter = $03f0
ram_block_orig_x_pos       = $03f1

ram_bounding_box_ul_x_pos   = $04ac
ram_bounding_box_ul_y_pos   = $04ad
ram_bounding_box_dr_x_pos   = $04ae
ram_bounding_box_dr_y_pos   = $04af
ram_bounding_box_ul_corner = $04ac
ram_bounding_box_lr_corner = $04ae
ram_enemy_bounding_box_coord = $04b0

ram_power_up_type           = $39

ram_fireball_bouncing_flag  = $3a
ram_fireball_counter       = $06ce
ram_fireball_throwing_timer = $0711

ram_hammer_enemy_offset     = $06ae
ram_jump_coin_misc_offset    = $06b7

ram_block_buffer_1        = $0500
ram_block_buffer_2        = $05d0

ram_hammer_throwing_timer   = $03a2
ram_hammer_bro_jump_timer    = $3c
ram_misc_collision_flag   = $06be

ram_red_p_troopa_orig_x_pos    = $0401
ram_red_p_troopa_center_y_pos  = $58

ram_x_move_primary_counter   = $a0
ram_x_move_secondary_counter = $58

ram_cheep_cheep_move_m_flag   = $58
ram_cheep_cheep_orig_y_pos    = $0434
ram_bit_m_filter            = $06dd

ram_lakitu_reappear_timer   = $06d1
ram_lakitu_move_speed       = $58
ram_lakitu_move_direction   = $a0

ram_firebar_spin_state_low  = $58
ram_firebar_spin_state_high = $a0
ram_firebar_spin_speed      = $0388
ram_firebar_spin_direction  = $34

ram_duplicate_obj_offset   = $06cf
ram_numberof_group_enemies  = $06d3

ram_blooper_move_counter    = $a0
ram_blooper_move_speed      = $58

ram_bowser_body_controls    = $0363
ram_bowser_feet_counter     = $0364
ram_bowser_movement_speed   = $0365
ram_bowser_orig_x_pos        = $0366
ram_bowser_flame_timer_ctrl  = $0367
ram_bowser_front_offset    = $0368
ram_bridge_collapse_offset  = $0369
ram_bowser_gfx_flag         = $036a
ram_bowser_hit_points       = $0483
ram_max_range_from_origin    = $06dc

ram_bowser_flame_p_random_ofs = $0417

ram_piranha_plant_up_y_pos    = $0417
ram_piranha_plant_down_y_pos  = $0434
ram_piranha_plant_y_speed  = $58
ram_piranha_plant_move_flag = $a0

ram_fireworks_counter      = $06d7
ram_explosion_gfx_counter   = $58
ram_explosion_timer_counter = $a0

; -------------------------------------------------------------------------------------
; SOUND ENGINE RAM

ram_sound_memory           = $07b0
ram_music_offset_noise     = $07b0
ram_event_music_buffer      = $07b1
ram_pause_sound_buffer      = $07b2
ram_squ2_note_len_buffer    = $07b3
ram_squ2_note_len_counter   = $07b4
ram_squ2_envelope_data_ctrl = $07b5
ram_squ1_note_len_counter   = $07b6
ram_squ1_envelope_data_ctrl = $07b7
ram_tri_note_len_buffer     = $07b8
ram_tri_note_len_counter    = $07b9
ram_noise_beat_len_counter  = $07ba
ram_squ1_sfx_len_counter    = $07bb
ram_squ2_sfx_len_counter    = $07bd
ram_sfx_secondary_counter  = $07be
ram_noise_sfx_len_counter   = $07bf
ram_dac_counter           = $07c0
ram_noise_data_loopback_ofs  = $07c1
ram_note_length_tbl_adder    = $07c4
ram_area_music_buffer_alt   = $07c5
ram_pause_mode_flag         = $07c6
ram_ground_music_header_ofs  = $07c7
ram_vs_star_music_header_ofs = $07c9
ram_alt_reg_content_flag     = $07ca
ram_vs_music_counter         = $07cc

ram_vs_io_buffer             = $6000
ram_vs_enemy_data            = $6100
ram_vs_area_data             = $6200
ram_vs_ppu_display_list      = $6300
ram_vs_title_buffer          = $6400
ram_vs_arena0                = $6600
ram_vs_saved_data            = $6674
ram_vs_saved_top_score       = $66ba
ram_vs_arena1                = $6700

ram_note_len_lookup_tbl_ofs   = $f0
ram_square1_sound_buffer    = $f1
ram_square2_sound_buffer    = $f2
ram_noise_sound_buffer      = $f3
ram_area_music_buffer       = $f4
ram_music_data             = $f5
ram_music_data_low          = $f5
ram_music_data_high         = $f6
ram_music_offset_square2   = $f7
ram_music_offset_square1   = $f8
ram_music_offset_triangle  = $f9
ram_pause_sound_queue       = $fa
ram_area_music_queue        = $fb
ram_event_music_queue       = $fc
ram_noise_sound_queue       = $fd
ram_square2_sound_queue     = $fe
ram_square1_sound_queue     = $ff
