; SMB2J DISASSEMBLY (SM2DATA4 portion)

; -------------------------------------------------------------------------------------
; DEFINES

AreaData              = $e7
AreaDataLow           = $e7
AreaDataHigh          = $e8
EnemyData             = $e9
EnemyDataLow          = $e9
EnemyDataHigh         = $ea

FrameCounter          = $09
Enemy_State           = $1e
Enemy_Y_Position      = $cf
PiranhaPlantUpYPos    = $0417
PiranhaPlantDownYPos  = $0434
PiranhaPlant_Y_Speed  = $58
PiranhaPlant_MoveFlag = $a0

Player_X_Scroll       = $06ff

Player_PageLoc        = $6d
Player_X_Position     = $86

AreaObjectLength      = $0730
WindFlag              = $07f9

TimerControl          = $0747
EnemyFrameTimer       = $078a

Sprite_Y_Position     = $0200
Sprite_Tilenumber     = $0201
Sprite_Attributes     = $0202
Sprite_X_Position     = $0203

Alt_SprDataOffset     = $06ec

NoiseSoundQueue       = $fd

TerrainControl        = $0727
AreaStyle             = $0733
ForegroundScenery     = $0741
BackgroundScenery     = $0742
CloudTypeOverride     = $0743
BackgroundColorCtrl   = $0744
AreaType              = $074e
AreaAddrsLOffset      = $074f
AreaPointer           = $0750

PlayerEntranceCtrl    = $0710
GameTimerSetting      = $0715
AltEntranceControl    = $0752
EntrancePage          = $0751

WorldNumber           = $075f
AreaNumber            = $0760  ; internal number used to find areas

; imports from other files
.import tbl_smb2_main_halfway_page_nibbles
.import sub_smb2_main_get_pipe_height
.import sub_smb2_main_find_empty_enemy_slot
.import sub_smb2_main_setup_piranha_plant
.import off_smb2_main_vertical_pipe_metatiles
.import sub_smb2_main_render_under_part
.import MetatileBuffer
.import sub_smb2_main_get_area_type
.import off_smb2_main_ground_area_21_enemies
.import off_smb2_main_e_ground_area28
.import off_smb2_main_ground_area_10_objects
.import off_smb2_main_l_ground_area28

; exports to other files
.export handler_late_fds_upside_down_pipe_high
.export handler_late_fds_upside_down_pipe_low
.export handler_smb2_data4_wind_on
.export handler_smb2_data4_wind_off
.export sub_smb2_data4_simulate_wind
.export sub_smb2_data4_blow_player_around
.export handler_late_fds_move_upside_down_piranha_plant
.export sub_late_fds_initialize_hard_course_checkpoints

; -------------------------------------------------------------------------------------------------

.include "shared_interface.inc"
.include "../../../common/game/hard_course_loader.asm"

tbl_smb2_data4_world_area_pointer_offsets:
    .byte tbl_smb2_data4_world_a_areas-tbl_smb2_data4_area_pointers, tbl_smb2_data4_world_b_areas-tbl_smb2_data4_area_pointers
    .byte tbl_smb2_data4_world_c_areas-tbl_smb2_data4_area_pointers, tbl_smb2_data4_world_d_areas-tbl_smb2_data4_area_pointers
    .byte 0,0,0,0,0

tbl_smb2_data4_area_pointers:
tbl_smb2_data4_world_a_areas:
    .byte $20, $2c, $40, $21, $60
tbl_smb2_data4_world_b_areas:
    .byte $22, $2c, $00, $23, $61
tbl_smb2_data4_world_c_areas:
    .byte $24, $25, $26, $62
tbl_smb2_data4_world_d_areas:
    .byte $27, $28, $29, $63

tbl_smb2_data4_enemy_data_offsets_by_area_type:
    .byte $14, $04, $12, $00

off_smb2_data4_enemy_data_addrs:
    .word off_smb2_data4_e_castle_area11, off_smb2_data4_e_castle_area12, off_smb2_data4_e_castle_area13, off_smb2_data4_e_castle_area14, off_smb2_data4_e_ground_area30, off_smb2_data4_e_ground_area31
    .word off_smb2_data4_e_ground_area32, off_smb2_data4_e_ground_area33, off_smb2_data4_e_ground_area34, off_smb2_data4_e_ground_area35, off_smb2_data4_e_ground_area36, off_smb2_data4_e_ground_area37
    .word off_smb2_data4_e_ground_area38, off_smb2_data4_e_ground_area39, off_smb2_data4_e_ground_area40, off_smb2_data4_e_ground_area41, off_smb2_main_ground_area_21_enemies, off_smb2_main_e_ground_area28
    .word off_smb2_data4_e_underground_area6, off_smb2_data4_e_underground_area7, off_smb2_data4_e_water_area9

tbl_smb2_data4_area_object_data_offsets_by_area_type:
    .byte $14, $04, $12, $00

off_smb2_data4_area_data_addrs:
    .word off_smb2_data4_l_castle_area11, off_smb2_data4_l_castle_area12, off_smb2_data4_l_castle_area13, off_smb2_data4_l_castle_area14, off_smb2_data4_l_ground_area30, off_smb2_data4_l_ground_area31
    .word off_smb2_data4_l_ground_area32, off_smb2_data4_l_ground_area33, off_smb2_data4_l_ground_area34, off_smb2_data4_l_ground_area35, off_smb2_data4_l_ground_area36, off_smb2_data4_l_ground_area37
    .word off_smb2_data4_l_ground_area38, off_smb2_data4_l_ground_area39, off_smb2_data4_l_ground_area40, off_smb2_data4_l_ground_area41, off_smb2_main_ground_area_10_objects, off_smb2_main_l_ground_area28
    .word off_smb2_data4_l_underground_area6, off_smb2_data4_l_underground_area7, off_smb2_data4_l_water_area9

tbl_smb2_data4_ato_d_halfway_pages:
    .byte $76, $50
    .byte $65, $50
    .byte $75, $b0
    .byte $00, $00

.include "../../../common/game/hard_course_checkpoints.asm"

; unused space
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff

; -------------------------------------------------------------------------------------------------
; $06 - used to store vertical length of pipe
; $07 - starts with adder from area parser, used to store row offset
