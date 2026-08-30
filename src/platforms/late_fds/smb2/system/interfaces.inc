; SUBROUTINES IN FAMICOM DISK SYSTEM BIOS
sub_smb2_main_fdsbios_delay     = $e149
sub_smb2_main_fdsbios_loadfiles = $e1f8
FDSBIOS_WRITEFILE = $e239

; -------------------------------------------------------------------------------------
; CONSTANTS

; sound effects constants
Sfx_SmallJump         = %10000000
Sfx_Flagpole          = %01000000
Sfx_Fireball          = %00100000
Sfx_PipeDown_Injury   = %00010000
Sfx_EnemySmack        = %00001000
Sfx_EnemyStomp        = %00000100
Sfx_Bump              = %00000010
Sfx_BigJump           = %00000001

Sfx_BowserFall        = %10000000
Sfx_ExtraLife         = %01000000
Sfx_PowerUpGrab       = %00100000
Sfx_TimerTick         = %00010000
Sfx_Blast             = %00001000
Sfx_GrowVine          = %00000100
Sfx_GrowPowerUp       = %00000010
Sfx_CoinGrab          = %00000001

Sfx_BowserFlame       = %00000010
Sfx_BrickShatter      = %00000001

; music constants
Silence               = %10000000

StarPowerMusic        = %01000000
PipeIntroMusic        = %00100000
CloudMusic            = %00010000
CastleMusic           = %00001000
UndergroundMusic      = %00000100
WaterMusic            = %00000010
GroundMusic           = %00000001

TimeRunningOutMusic   = %01000000
EndOfLevelMusic       = %00100000
AltGameOverMusic      = %00010000
EndOfCastleMusic      = %00001000
VictoryMusic          = %00000100
GameOverMusic         = %00000010
DeathMusic            = %00000001

; enemy object constants
GreenKoopa            = $00
BuzzyBeetle           = $02
RedKoopa              = $03
HammerBro             = $05
Goomba                = $06
Bloober               = $07
BulletBill_FrenzyVar  = $08
GreyCheepCheep        = $0a
RedCheepCheep         = $0b
Podoboo               = $0c
PiranhaPlant          = $0d
GreenParatroopaJump   = $0e
RedParatroopa         = $0f
GreenParatroopaFly    = $10
Lakitu                = $11
Spiny                 = $12
FlyCheepCheepFrenzy   = $14
FlyingCheepCheep      = $14
BowserFlame           = $15
Fireworks             = $16
BBill_CCheep_Frenzy   = $17
Stop_Frenzy           = $18
Bowser                = $2d
PowerUpObject         = $2e
VineObject            = $2f
FlagpoleFlagObject    = $30
StarFlagObject        = $31
JumpspringObject      = $32
BulletBill_CannonVar  = $33
RetainerObject        = $35
TallEnemy             = $09
UpsideDownPiranhaP    = $04

; other constants
World1 = 0
World2 = 1
World3 = 2
World4 = 3
World5 = 4
World6 = 5
World7 = 6
World8 = 7
World9 = 8
Level1 = 0
Level2 = 1
Level3 = 2
Level4 = 3

WarmBootOffset        = <$07d6
ColdBootOffset        = <$07fe
SoundMemory           = $07b0
SwimTileRepOffset     = tbl_smb2_main_player_graphics_tiles + $9e
MusicHeaderOffsetData = off_smb2_main_music_header_offsets - 1
MHD                   = off_smb2_main_music_header_offsets

A_Button              = %10000000
B_Button              = %01000000
Select_Button         = %00100000
Start_Button          = %00010000
Up_Dir                = %00001000
Down_Dir              = %00000100
Left_Dir              = %00000010
Right_Dir             = %00000001

AttractMode           = 0
GameMode              = 1
VictoryMode           = 2
GameOverMode          = 3

; imports from other files
; SUBROUTINES IN SM2DATA2 AND SM2DATA4
.import handler_late_fds_upside_down_pipe_high
.import handler_late_fds_upside_down_pipe_low
.import handler_smb2_data4_wind_on
.import handler_smb2_data4_wind_off
.import sub_smb2_data4_simulate_wind
.import sub_smb2_data4_blow_player_around
.import handler_late_fds_move_upside_down_piranha_plant
.import sub_late_fds_initialize_hard_course_checkpoints
; SUBROUTINES IN SM2DATA3
.import handler_smb2_data3_erase_lives_lines
.import handler_smb2_data3_run_mushroom_retainers
.import handler_smb2_data3_ending_disk_routines
.import handler_smb2_data3_award_extra_lives
.import handler_smb2_data3_print_victory_msgs_for_world8
.import handler_smb2_data3_fade_to_blue
.import handler_smb2_data3_screen_subs_for_final_room
; LABELS FROM SM2DATA3
.import loc_smb2_data3_write_name_to_victory_msg
.import unused_smb2_data3_unused_attrib_data
.import off_smb2_data3_final_room_palette
.import off_smb2_data3_thank_you_message_final
.import off_smb2_data3_peace_is_paved_msg
.import off_smb2_data3_with_kingdom_saved_msg
.import off_smb2_data3_hurrah_msg
.import off_smb2_data3_our_only_hero_msg
.import off_smb2_data3_this_ends_your_trip_msg
.import off_smb2_data3_of_a_long_friendship_msg
.import off_smb2_data3_points_added_msg
.import off_smb2_data3_for_each_player_left_msg
.import tbl_smb2_data3_princess_peachs_room
.import off_smb2_data3_fantasy_world9_msg
.import off_smb2_data3_super_player_msg
; from sm2data2
.import off_smb2_data2_castle_area_5_enemies
.import off_smb2_data2_castle_area_6_enemies
.import off_smb2_data2_e_castle_area7
.import off_smb2_data2_e_castle_area8
.import off_smb2_data2_ground_area_12_enemies
.import off_smb2_data2_ground_area_13_enemies
.import off_smb2_data2_ground_area_14_enemies
.import off_smb2_data2_ground_area_15_enemies
.import off_smb2_data2_ground_area_16_enemies
.import off_smb2_data2_ground_area_17_enemies
.import off_smb2_data2_ground_area_18_enemies
.import off_smb2_data2_ground_area_19_enemies
.import off_smb2_data2_ground_area_22_enemies
.import off_smb2_data2_e_ground_area23
.import off_smb2_data2_e_ground_area24
.import off_smb2_data2_e_ground_area29
.import off_smb2_data2_e_underground_area4
.import off_smb2_data2_e_underground_area5
.import off_smb2_data2_water_area_2_enemies
.import off_smb2_data2_e_water_area4
.import off_smb2_data2_e_water_area5
.import off_smb2_data2_castle_area_5_objects
.import off_smb2_data2_castle_area_6_objects
.import off_smb2_data2_l_castle_area7
.import off_smb2_data2_l_castle_area8
.import off_smb2_data2_ground_area_12_objects
.import off_smb2_data2_ground_area_13_objects
.import off_smb2_data2_ground_area_14_objects
.import off_smb2_data2_ground_area_15_objects
.import off_smb2_data2_ground_area_16_objects
.import off_smb2_data2_ground_area_17_objects
.import off_smb2_data2_ground_area_18_objects
.import off_smb2_data2_ground_area_19_objects
.import off_smb2_data2_ground_area_22_objects
.import off_smb2_data2_l_ground_area23
.import off_smb2_data2_l_ground_area24
.import off_smb2_data2_l_ground_area29
.import off_smb2_data2_l_underground_area4
.import off_smb2_data2_l_underground_area5
.import off_smb2_data2_water_area_2_objects
.import off_smb2_data2_l_water_area4
.import off_smb2_data2_l_water_area5
; from sm2data3
.import off_smb2_data3_e_castle_area9
.import off_smb2_data3_e_castle_area10
.import off_smb2_data3_e_ground_area25
.import off_smb2_data3_e_ground_area26
.import off_smb2_data3_e_ground_area27
.import off_smb2_data3_e_water_area6
.import off_smb2_data3_e_water_area7
.import off_smb2_data3_e_water_area8
.import off_smb2_data3_l_castle_area9
.import off_smb2_data3_l_castle_area10
.import off_smb2_data3_l_ground_area25
.import off_smb2_data3_l_ground_area26
.import off_smb2_data3_l_ground_area27
.import off_smb2_data3_l_water_area6
.import off_smb2_data3_l_water_area7
.import off_smb2_data3_l_water_area8

; exports to other files
.export loc_smb2_main_sound_engine_jsr_code
.export sub_smb2_main_move_sprites_offscreen
.export tbl_smb2_main_music_note_periods
.export loc_smb2_main_next_world
.export handler_smb2_main_write_top_status_line
.export handler_smb2_main_write_bottom_status_line
.export handler_smb2_main_select_area_palette
.export handler_smb2_main_prepare_background_and_player_colors
.export loc_smb2_main_award_end_area_points
.export sub_smb2_main_dispatch_inline_handler
.export sub_smb2_main_handle_square_2_sound_effect
.export sub_smb2_main_print_status_bar_numbers
.export tbl_smb2_main_disk_id_string
.export sub_smb2_main_render_enemy_graphics
.export sub_smb2_main_sound_engine
.export handler_smb2_main_disk_screen
.export handler_smb2_main_wait_for_eject
.export handler_smb2_main_wait_for_reinsert
.export handler_smb2_main_reset_disk_vars
.export loc_smb2_main_disk_error_handler
.export handler_smb2_main_attract_mode_subs
.export handler_smb2_main_init_screen_palette
; sm2data4
.export tbl_smb2_main_halfway_page_nibbles
.export sub_smb2_main_get_pipe_height
.export sub_smb2_main_find_empty_enemy_slot
.export sub_smb2_main_setup_piranha_plant
.export off_smb2_main_vertical_pipe_metatiles
.export sub_smb2_main_render_under_part
.export MetatileBuffer
.export sub_smb2_main_get_area_type
.export off_smb2_main_ground_area_21_enemies
.export off_smb2_main_e_ground_area28
.export off_smb2_main_ground_area_10_objects
.export off_smb2_main_l_ground_area28

; -------------------------------------------------------------------------------------
