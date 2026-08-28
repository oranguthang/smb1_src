.if con_revision_profile = con_revision_profile_pal
    .define con_course_enemy_streams_asset "../../../assets/generated/revisions/pal/source/pal_course_enemy_streams.bin"
.else
    .define con_course_enemy_streams_asset "../../../assets/generated/source/base_course_enemy_streams.bin"
.endif

; -------------------------------------------------------------------------------------

tbl_area_object_loopback_offsets:
    .byte $12, $36, $0e, $0e, $0e, $32, $32, $32, $0a, $26, $40

; -------------------------------------------------------------------------------------

sub_load_area_pointer:
    JSR sub_find_area_pointer  ; find it and store it here
    STA ram_area_pointer
sub_get_area_type:
    AND #%01100000  ; mask out all but d6 and d5
    ASL
    ROL
    ROL
    ROL  ; make %0xx00000 into %000000xx
    STA ram_area_type  ; save 2 MSB as area type
    RTS

sub_find_area_pointer:
    LDY ram_world_number  ; load offset from world variable
    LDA tbl_world_area_pointer_offsets,y
    CLC  ; add area number used to find data
    ADC ram_area_number
    TAY
    LDA tbl_area_pointers,y  ; from there we have our area pointer
    RTS

sub_get_area_data_addresses:
    LDA ram_area_pointer  ; use 2 MSB for Y
    JSR sub_get_area_type
    TAY
    LDA ram_area_pointer  ; mask out all but 5 LSB
    AND #%00011111
    STA ram_area_addrs_l_offset  ; save as low offset
    LDA tbl_enemy_data_offsets_by_area_type,y  ; load base value with 2 altered MSB,
    CLC  ; then add base value to 5 LSB, result
    ADC ram_area_addrs_l_offset  ; becomes offset for level data
    TAY
    LDA tbl_enemy_data_ptr_lo,y  ; use offset to load pointer
    STA ram_enemy_data_low
    LDA tbl_enemy_data_ptr_hi,y
    STA ram_enemy_data_high
    LDY ram_area_type  ; use area type as offset
    LDA tbl_area_object_data_offsets_by_area_type,y  ; do the same thing but with different base value
    CLC
    ADC ram_area_addrs_l_offset
    TAY
    LDA tbl_area_object_data_ptr_lo,y  ; use this offset to load another pointer
    STA ram_area_data_low
    LDA tbl_area_object_data_ptr_hi,y
    STA ram_area_data_high
    LDY #$00  ; load first byte of header
    LDA (ram_area_data),y
    PHA  ; save it to the stack for now
    AND #%00000111  ; save 3 LSB for foreground scenery or bg color control
    CMP #$04
    BCC bra_store_foreground_scenery
    STA ram_background_color_ctrl  ; if 4 or greater, save value here as bg color control
    LDA #$00
bra_store_foreground_scenery:
    STA ram_foreground_scenery  ; if less, save value here as foreground scenery
    PLA  ; pull byte from stack and push it back
    PHA
    AND #%00111000  ; save player entrance control bits
    LSR  ; shift bits over to LSBs
    LSR
    LSR
    STA ram_player_entrance_ctrl  ; save value here as player entrance control
    PLA  ; pull byte again but do not push it back
    AND #%11000000  ; save 2 MSB for game timer setting
    CLC
    ROL  ; rotate bits over to LSBs
    ROL
    ROL
    STA ram_game_timer_setting  ; save value here as game timer setting
    INY
    LDA (ram_area_data),y  ; load second byte of header
    PHA  ; save to stack
    AND #%00001111  ; mask out all but lower nybble
    STA ram_terrain_control
    PLA  ; pull and push byte to copy it to A
    PHA
    AND #%00110000  ; save 2 MSB for background scenery type
    LSR
    LSR  ; shift bits to LSBs
    LSR
    LSR
    STA ram_background_scenery  ; save as background scenery
    PLA
    AND #%11000000
    CLC
    ROL  ; rotate bits over to LSBs
    ROL
    ROL
    CMP #%00000011  ; if set to 3, store here
    BNE bra_store_area_style  ; and nullify other value
    STA ram_cloud_type_override  ; otherwise store value in other place
    LDA #$00
bra_store_area_style:
    STA ram_area_style
    LDA ram_area_data_low  ; increment area data address by 2 bytes
    CLC
    ADC #$02
    STA ram_area_data_low
    LDA ram_area_data_high
    ADC #$00
    STA ram_area_data_high
    RTS

; -------------------------------------------------------------------------------------
; GAME LEVELS DATA

tbl_world_area_pointer_offsets:
    .byte off_world_1_area_pointers-tbl_area_pointers, off_world_2_area_pointers-tbl_area_pointers
    .byte off_world_3_area_pointers-tbl_area_pointers, off_world_4_area_pointers-tbl_area_pointers
    .byte off_world_5_area_pointers-tbl_area_pointers, off_world_6_area_pointers-tbl_area_pointers
    .byte off_world_7_area_pointers-tbl_area_pointers, off_world_8_area_pointers-tbl_area_pointers

tbl_area_pointers:
off_world_1_area_pointers:
    .byte $25, $29, $c0, $26, $60
off_world_2_area_pointers:
    .byte $28, $29, $01, $27, $62
off_world_3_area_pointers:
    .byte $24, $35, $20, $63
off_world_4_area_pointers:
    .byte $22, $29, $41, $2c, $61
off_world_5_area_pointers:
    .byte $2a, $31, $26, $62
off_world_6_area_pointers:
    .byte $2e, $23, $2d, $60
off_world_7_area_pointers:
    .byte $33, $29, $01, $27, $64
off_world_8_area_pointers:
    .byte $30, $32, $21, $65

; bonus area data offsets, included here for comparison purposes
; underground bonus area  - c2
; cloud area 1 (day)      - 2b
; cloud area 2 (night)    - 34
; water area (5-2/6-2)    - 00
; water area (8-4)        - 02
; warp zone area (4-2)    - 2f

tbl_enemy_data_offsets_by_area_type:
    .byte $1f, $06, $1c, $00

tbl_enemy_data_ptr_lo:
    .byte <off_castle_area_1_enemies, <off_castle_area_2_enemies, <off_castle_area_3_enemies, <off_castle_area_4_enemies, <off_castle_area_5_enemies, <off_castle_area_6_enemies
    .byte <off_ground_area_1_enemies, <off_ground_area_2_enemies, <off_ground_area_3_enemies, <off_ground_area_4_enemies, <off_ground_area_5_enemies, <off_ground_area_6_enemies
    .byte <off_ground_area_7_enemies, <off_ground_area_8_enemies, <off_ground_area_9_enemies, <off_ground_area_10_enemies, <off_ground_area_11_enemies, <off_ground_area_12_enemies
    .byte <off_ground_area_13_enemies, <off_ground_area_14_enemies, <off_ground_area_15_enemies, <off_ground_area_16_enemies, <off_ground_area_17_enemies, <off_ground_area_18_enemies
    .byte <off_ground_area_19_enemies, <off_ground_area_20_enemies, <off_ground_area_21_enemies, <off_ground_area_22_enemies, <off_underground_area_1_enemies
    .byte <off_underground_area_2_enemies, <off_underground_area_3_enemies, <off_water_area_1_enemies, <off_water_area_2_enemies, <off_water_area_3_enemies

tbl_enemy_data_ptr_hi:
    .byte >off_castle_area_1_enemies, >off_castle_area_2_enemies, >off_castle_area_3_enemies, >off_castle_area_4_enemies, >off_castle_area_5_enemies, >off_castle_area_6_enemies
    .byte >off_ground_area_1_enemies, >off_ground_area_2_enemies, >off_ground_area_3_enemies, >off_ground_area_4_enemies, >off_ground_area_5_enemies, >off_ground_area_6_enemies
    .byte >off_ground_area_7_enemies, >off_ground_area_8_enemies, >off_ground_area_9_enemies, >off_ground_area_10_enemies, >off_ground_area_11_enemies, >off_ground_area_12_enemies
    .byte >off_ground_area_13_enemies, >off_ground_area_14_enemies, >off_ground_area_15_enemies, >off_ground_area_16_enemies, >off_ground_area_17_enemies, >off_ground_area_18_enemies
    .byte >off_ground_area_19_enemies, >off_ground_area_20_enemies, >off_ground_area_21_enemies, >off_ground_area_22_enemies, >off_underground_area_1_enemies
    .byte >off_underground_area_2_enemies, >off_underground_area_3_enemies, >off_water_area_1_enemies, >off_water_area_2_enemies, >off_water_area_3_enemies

tbl_area_object_data_offsets_by_area_type:
    .byte $00, $03, $19, $1c

tbl_area_object_data_ptr_lo:
    .byte <off_water_area_1_objects, <off_water_area_2_objects, <off_water_area_3_objects, <off_ground_area_1_objects, <off_ground_area_2_objects, <off_ground_area_3_objects
    .byte <off_ground_area_4_objects, <off_ground_area_5_objects, <off_ground_area_6_objects, <off_ground_area_7_objects, <off_ground_area_8_objects, <off_ground_area_9_objects
    .byte <off_ground_area_10_objects, <off_ground_area_11_objects, <off_ground_area_12_objects, <off_ground_area_13_objects, <off_ground_area_14_objects, <off_ground_area_15_objects
    .byte <off_ground_area_16_objects, <off_ground_area_17_objects, <off_ground_area_18_objects, <off_ground_area_19_objects, <off_ground_area_20_objects, <off_ground_area_21_objects
    .byte <off_ground_area_22_objects, <off_underground_area_1_objects, <off_underground_area_2_objects, <off_underground_area_3_objects, <off_castle_area_1_objects
    .byte <off_castle_area_2_objects, <off_castle_area_3_objects, <off_castle_area_4_objects, <off_castle_area_5_objects, <off_castle_area_6_objects

tbl_area_object_data_ptr_hi:
    .byte >off_water_area_1_objects, >off_water_area_2_objects, >off_water_area_3_objects, >off_ground_area_1_objects, >off_ground_area_2_objects, >off_ground_area_3_objects
    .byte >off_ground_area_4_objects, >off_ground_area_5_objects, >off_ground_area_6_objects, >off_ground_area_7_objects, >off_ground_area_8_objects, >off_ground_area_9_objects
    .byte >off_ground_area_10_objects, >off_ground_area_11_objects, >off_ground_area_12_objects, >off_ground_area_13_objects, >off_ground_area_14_objects, >off_ground_area_15_objects
    .byte >off_ground_area_16_objects, >off_ground_area_17_objects, >off_ground_area_18_objects, >off_ground_area_19_objects, >off_ground_area_20_objects, >off_ground_area_21_objects
    .byte >off_ground_area_22_objects, >off_underground_area_1_objects, >off_underground_area_2_objects, >off_underground_area_3_objects, >off_castle_area_1_objects
    .byte >off_castle_area_2_objects, >off_castle_area_3_objects, >off_castle_area_4_objects, >off_castle_area_5_objects, >off_castle_area_6_objects

; ENEMY OBJECT DATA

; level 1-4/6-4
off_castle_area_1_enemies:
    .incbin con_course_enemy_streams_asset, $000, $027

; level 4-4
off_castle_area_2_enemies:
    .incbin con_course_enemy_streams_asset, $027, $019

; level 2-4/5-4
off_castle_area_3_enemies:
    .incbin con_course_enemy_streams_asset, $040, $02f

; level 3-4
off_castle_area_4_enemies:
    .incbin con_course_enemy_streams_asset, $06f, $02b

; level 7-4
off_castle_area_5_enemies:
    .incbin con_course_enemy_streams_asset, $09a, $015

; level 8-4
off_castle_area_6_enemies:
    .incbin con_course_enemy_streams_asset, $0af, $03a

; level 3-3
off_ground_area_1_enemies:
    .incbin con_course_enemy_streams_asset, $0e9, $025

; level 8-3
off_ground_area_2_enemies:
    .incbin con_course_enemy_streams_asset, $10e, $01d

; level 4-1
off_ground_area_3_enemies:
    .incbin con_course_enemy_streams_asset, $12b, $00e

; level 6-2
off_ground_area_4_enemies:
    .incbin con_course_enemy_streams_asset, $139, $027

; level 3-1
off_ground_area_5_enemies:
    .incbin con_course_enemy_streams_asset, $160, $031

; level 1-1
off_ground_area_6_enemies:
    .incbin con_course_enemy_streams_asset, $191, $01e

; level 1-3/5-3
off_ground_area_7_enemies:
    .incbin con_course_enemy_streams_asset, $1af, $01d

; level 2-3/7-3
off_ground_area_8_enemies:
    .incbin con_course_enemy_streams_asset, $1cc, $015

; level 2-1
off_ground_area_9_enemies:
    .incbin con_course_enemy_streams_asset, $1e1, $02a

; end of data terminator here is also used by pipe intro area
off_ground_area_10_enemies:
    .incbin con_course_enemy_streams_asset, $20b, $001

; level 5-1
off_ground_area_11_enemies:
    .incbin con_course_enemy_streams_asset, $20c, $024

; cloud level used in levels 2-1 and 5-2
off_ground_area_12_enemies:
    .incbin con_course_enemy_streams_asset, $230, $009

; level 4-3
off_ground_area_13_enemies:
    .incbin con_course_enemy_streams_asset, $239, $025

; level 6-3
off_ground_area_14_enemies:
    .incbin con_course_enemy_streams_asset, $25e, $023

; level 6-1
off_ground_area_15_enemies:
    .incbin con_course_enemy_streams_asset, $281, $009

; warp zone area used in level 4-2
off_ground_area_16_enemies:
    .incbin con_course_enemy_streams_asset, $28a, $001

; level 8-1
off_ground_area_17_enemies:
    .incbin con_course_enemy_streams_asset, $28b, $03a

; level 5-2
off_ground_area_18_enemies:
    .incbin con_course_enemy_streams_asset, $2c5, $02b

; level 8-2
off_ground_area_19_enemies:
    .incbin con_course_enemy_streams_asset, $2f0, $02e

; level 7-1
off_ground_area_20_enemies:
    .incbin con_course_enemy_streams_asset, $31e, $01c

; cloud level used in levels 3-1 and 6-2
off_ground_area_21_enemies:
    .incbin con_course_enemy_streams_asset, $33a, $009

; level 3-2
off_ground_area_22_enemies:
    .incbin con_course_enemy_streams_asset, $343, $025

; level 1-2
off_underground_area_1_enemies:
    .incbin con_course_enemy_streams_asset, $368, $02d

; level 4-2
off_underground_area_2_enemies:
    .incbin con_course_enemy_streams_asset, $395, $02e

; underground bonus rooms area used in many levels
off_underground_area_3_enemies:
    .incbin con_course_enemy_streams_asset, $3c3, $02d

; water area used in levels 5-2 and 6-2
off_water_area_1_enemies:
    .incbin con_course_enemy_streams_asset, $3f0, $011

; level 2-2/7-2
off_water_area_2_enemies:
    .incbin con_course_enemy_streams_asset, $401, $02a

; water area used in level 8-4
off_water_area_3_enemies:
    .incbin con_course_enemy_streams_asset, $42b, $014
