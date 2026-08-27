; -------------------------------------------------------------------------------------

; CONSTANTS

.ifndef con_initial_lives
con_initial_lives = $02
.endif

.if con_revision_profile = con_revision_profile_pal
con_interval_timer_reload = $11
con_player_gravity_initial = $70
con_jump_speed_cutoff_a = $0a
con_jump_speed_cutoff_b = $12
con_jump_speed_cutoff_c = $1d
con_jump_speed_cutoff_d = $22
con_player_slow_speed_cap = $27
con_player_friction_high = $01
con_animation_speed_cutoff_a = $20
con_animation_speed_cutoff_b = $10
con_animation_speed_cutoff_c = $0d
con_fireball_x_speed = $4c
con_fireball_y_speed = $05
con_fireball_gravity = $60
con_fireball_maximum_y_speed = $05
con_game_timer_reload = $14
con_jumpspring_y_speed = $f2
con_jumpspring_collision_y_speed = $f8
con_bullet_bill_x_speed = $1c
con_bullet_bill_animation_timer = $09
con_hammer_x_speed = $14
con_hammer_gravity = $23
con_hammer_initial_y_speed = $fd
con_block_bounce_timer = $0c
con_enemy_gravity = $05
con_enemy_slow_gravity = $12
con_enemy_medium_gravity = $1f
con_enemy_maximum_y_speed = $04
con_block_gravity = $58
con_normal_enemy_x_speed = $0a
con_hard_enemy_x_speed = $0f
con_spiny_player_speed_cutoff = $0c
con_firebar_slow_speed = $30
con_firebar_fast_speed = $43
con_flying_cheep_cheep_y_speed = $fa
con_flying_cheep_cheep_player_speed_offset = $1d
con_hammer_bro_x_speed = $05
con_hammer_bro_chase_x_speed = $f6
con_stunned_goomba_erase_timer = $0b
con_blooper_player_y_offset = $0c
con_lakitu_player_speed_cutoff = $1d
con_bowser_flame_x_force = $70
con_hard_bowser_flame_x_force = $90
con_right_platform_x_speed = $13
con_kicked_enemy_x_speed = $38
con_player_ground_collision_limit = $06
con_pipe_transition_timer = $28
con_player_skid_speed_cutoff = $0a
.else
con_interval_timer_reload = $14
con_player_gravity_initial = $28
con_jump_speed_cutoff_a = $09
con_jump_speed_cutoff_b = $10
con_jump_speed_cutoff_c = $19
con_jump_speed_cutoff_d = $1c
con_player_slow_speed_cap = $21
con_player_friction_high = $00
con_animation_speed_cutoff_a = $1c
con_animation_speed_cutoff_b = $0e
con_animation_speed_cutoff_c = $0b
con_fireball_x_speed = $40
con_fireball_y_speed = $04
con_fireball_gravity = $50
con_fireball_maximum_y_speed = $03
con_game_timer_reload = $18
con_jumpspring_y_speed = $f4
con_jumpspring_collision_y_speed = $f9
con_bullet_bill_x_speed = $18
con_bullet_bill_animation_timer = $0a
con_hammer_x_speed = $10
con_hammer_gravity = $10
con_hammer_initial_y_speed = $fe
con_block_bounce_timer = $10
con_enemy_gravity = $04
con_enemy_slow_gravity = $0f
con_enemy_medium_gravity = $1c
con_enemy_maximum_y_speed = $03
con_block_gravity = $50
con_normal_enemy_x_speed = $08
con_hard_enemy_x_speed = $0c
con_spiny_player_speed_cutoff = $08
con_firebar_slow_speed = $28
con_firebar_fast_speed = $38
con_flying_cheep_cheep_y_speed = $fb
con_flying_cheep_cheep_player_speed_offset = $19
con_hammer_bro_x_speed = $04
con_hammer_bro_chase_x_speed = $f8
con_stunned_goomba_erase_timer = $0e
con_blooper_player_y_offset = $10
con_lakitu_player_speed_cutoff = $19
con_bowser_flame_x_force = $40
con_hard_bowser_flame_x_force = $60
con_right_platform_x_speed = $10
con_kicked_enemy_x_speed = $30
con_player_ground_collision_limit = $05
con_pipe_transition_timer = $30
con_player_skid_speed_cutoff = $09
.endif

con_vs_request_irq_release = %00000010
con_vs_request_controller_strobe = %00000001
con_vs_request_chr_high = %00000100
con_vs_status_service = %00000100
con_vs_status_dip_1 = %00001000
con_vs_status_dip_2 = %00010000
con_vs_status2_dips = %11111100

; sound effects constants
con_sfx_small_jump         = %10000000
con_sfx_flagpole          = %01000000
con_sfx_fireball          = %00100000
con_sfx_pipe_down_injury   = %00010000
con_sfx_enemy_smack        = %00001000
con_sfx_enemy_stomp        = %00000100
con_sfx_bump              = %00000010
con_sfx_big_jump           = %00000001

con_sfx_bowser_fall        = %10000000
con_sfx_extra_life         = %01000000
con_sfx_power_up_grab       = %00100000
con_sfx_timer_tick         = %00010000
con_sfx_blast             = %00001000
con_sfx_grow_vine          = %00000100
con_sfx_grow_power_up       = %00000010
con_sfx_coin_grab          = %00000001

con_sfx_bowser_flame       = %00000010
con_sfx_brick_shatter      = %00000001

; music constants
con_silence               = %10000000

con_star_power_music        = %01000000
con_pipe_intro_music        = %00100000
con_cloud_music            = %00010000
con_castle_music           = %00001000
con_underground_music      = %00000100
con_water_music            = %00000010
con_ground_music           = %00000001

con_time_running_out_music   = %01000000
con_end_of_level_music       = %00100000
con_alt_game_over_music      = %00010000
con_end_of_castle_music      = %00001000
con_victory_music          = %00000100
con_game_over_music         = %00000010
con_death_music            = %00000001

; enemy object constants
con_green_koopa            = $00
con_buzzy_beetle           = $02
con_red_koopa              = $03
con_hammer_bro             = $05
con_goomba                = $06
con_bloober               = $07
con_bullet_bill_frenzy_var  = $08
con_grey_cheep_cheep        = $0a
con_red_cheep_cheep         = $0b
con_podoboo               = $0c
con_piranha_plant          = $0d
con_green_paratroopa_jump   = $0e
con_red_paratroopa         = $0f
con_green_paratroopa_fly    = $10
con_lakitu                = $11
con_spiny                 = $12
con_fly_cheep_cheep_frenzy   = $14
con_flying_cheep_cheep      = $14
con_bowser_flame           = $15
con_fireworks             = $16
con_b_bill_c_cheep_frenzy   = $17
con_stop_frenzy           = $18
con_bowser                = $2d
con_power_up_object         = $2e
con_vine_object            = $2f
con_flagpole_flag_object    = $30
con_star_flag_object        = $31
con_jumpspring_object      = $32
con_bullet_bill_cannon_var  = $33
con_retainer_object        = $35
con_tall_enemy             = $09

; other constants
con_world1 = 0
con_world2 = 1
con_world3 = 2
con_world4 = 3
con_world5 = 4
con_vs_hard_mode_world = 3
con_world6 = 5
con_world7 = 6
con_world8 = 7
con_level1 = 0
con_level2 = 1
con_level3 = 2
con_vs_hard_mode_level = 1
con_level4 = 3

con_warm_boot_offset        = <$07d6
con_cold_boot_offset        = <$07fe
con_title_screen_data_offset = $1ec0
con_swim_tile_replacement_offset     = tbl_player_graphics_tiles + $9e
con_music_header_offset_table_base = tbl_music_header_offsets - 1
con_music_header_data_base                   = tbl_music_header_offsets

con_btn_a              = %10000000
con_btn_b              = %01000000
con_btn_select         = %00100000
con_btn_start          = %00010000
con_btn_up                = %00001000
con_btn_down              = %00000100
con_btn_left              = %00000010
con_btn_right             = %00000001

con_mode_title_screen  = 0
con_mode_game         = 1
con_mode_victory      = 2
con_mode_game_over     = 3
con_vs_mode_game       = 2
con_vs_mode_game_over  = 4
