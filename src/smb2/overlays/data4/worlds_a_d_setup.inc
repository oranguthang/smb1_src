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
.export handler_smb2_data4_upside_down_pipe_high
.export handler_smb2_data4_upside_down_pipe_low
.export handler_smb2_data4_wind_on
.export handler_smb2_data4_wind_off
.export sub_smb2_data4_simulate_wind
.export sub_smb2_data4_blow_player_around
.export handler_smb2_data4_move_upside_down_piranha_plant
.export sub_smb2_data4_change_halfway_pages

; -------------------------------------------------------------------------------------------------

loc_smb2_data4_find_area_pointer:
    LDY WorldNumber  ; load offset from world variable
    LDA tbl_smb2_data4_world_area_pointer_offsets,y
    CLC  ; add area number used to find data
    ADC AreaNumber
    TAY
    LDA tbl_smb2_data4_area_pointers,y  ; from there we have our area pointer
    RTS

loc_smb2_data4_get_area_data_addresses:
    LDA AreaPointer  ; use 2 MSB for Y
    JSR sub_smb2_main_get_area_type
    TAY
    LDA AreaPointer  ; mask out all but 5 LSB
    AND #%00011111
    STA AreaAddrsLOffset  ; save as low offset
    LDA tbl_smb2_data4_enemy_data_offsets_by_area_type,y  ; load base value with 2 altered MSB,
    CLC  ; then add base value to 5 LSB, result
    ADC AreaAddrsLOffset  ; becomes offset for level data
    ASL
    TAY
    LDA off_smb2_data4_enemy_data_addrs+1,y  ; use offset to load pointer
    STA EnemyDataHigh
    LDA off_smb2_data4_enemy_data_addrs,y
    STA EnemyDataLow
    LDY AreaType  ; use area type as offset
    LDA tbl_smb2_data4_area_object_data_offsets_by_area_type,y  ; do the same thing but with different base value
    CLC
    ADC AreaAddrsLOffset
    ASL
    TAY
    LDA off_smb2_data4_area_data_addrs+1,y  ; use this offset to load another pointer
    STA AreaDataHigh
    LDA off_smb2_data4_area_data_addrs,y
    STA AreaDataLow
    LDY #$00  ; load first byte of header
    LDA (AreaData),y
    PHA  ; save it to the stack for now
    AND #%00000111  ; save 3 LSB for foreground scenery or bg color control
    CMP #$04
    BCC bra_smb2_data4_store_foreground_scenery
    STA BackgroundColorCtrl  ; if 4 or greater, save value here as bg color control
    LDA #$00
bra_smb2_data4_store_foreground_scenery:
    STA ForegroundScenery  ; if less, save value here as foreground scenery
    PLA  ; pull byte from stack and push it back
    PHA
    AND #%00111000  ; save player entrance control bits
    LSR  ; shift bits over to LSBs
    LSR
    LSR
    STA PlayerEntranceCtrl  ; save value here as player entrance control
    PLA  ; pull byte again but do not push it back
    AND #%11000000  ; save 2 MSB for game timer setting
    CLC
    ROL  ; rotate bits over to LSBs
    ROL
    ROL
    STA GameTimerSetting  ; save value here as game timer setting
    INY
    LDA (AreaData),y  ; load second byte of header
    PHA  ; save to stack
    AND #%00001111  ; mask out all but lower nybble
    STA TerrainControl
    PLA  ; pull and push byte to copy it to A
    PHA
    AND #%00110000  ; save 2 MSB for background scenery type
    LSR
    LSR  ; shift bits to LSBs
    LSR
    LSR
    STA BackgroundScenery  ; save as background scenery
    PLA
    AND #%11000000
    CLC
    ROL  ; rotate bits over to LSBs
    ROL
    ROL
    CMP #%00000011  ; if set to 3, store here
    BNE bra_smb2_data4_store_area_style  ; and nullify other value
    STA CloudTypeOverride  ; otherwise store value in other place
    LDA #$00
bra_smb2_data4_store_area_style:
    STA AreaStyle
    LDA AreaDataLow  ; increment area data address by 2 bytes
    CLC
    ADC #$02
    STA AreaDataLow
    LDA AreaDataHigh
    ADC #$00
    STA AreaDataHigh
    RTS

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

sub_smb2_data4_change_halfway_pages:
    LDY #$07
bra_smb2_data4_c_half_l:
    LDA tbl_smb2_data4_ato_d_halfway_pages,y  ; load new halfway nybbles over the old ones
    STA tbl_smb2_main_halfway_page_nibbles,y
    DEY
    BPL bra_smb2_data4_c_half_l
    RTS

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
