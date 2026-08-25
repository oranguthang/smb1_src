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
    .byte $76, $dd, $bb, $4c, $ea, $1d, $1b, $cc, $56, $5d
    .byte $16, $9d, $c6, $1d, $36, $9d, $c9, $1d, $04, $db
    .byte $49, $1d, $84, $1b, $c9, $5d, $88, $95, $0f, $08
    .byte $30, $4c, $78, $2d, $a6, $28, $90, $b5
    .byte $ff

; level 4-4
off_castle_area_2_enemies:
    .byte $0f, $03, $56, $1b, $c9, $1b, $0f, $07, $36, $1b
    .byte $aa, $1b, $48, $95, $0f, $0a, $2a, $1b, $5b, $0c
    .byte $78, $2d, $90, $b5
    .byte $ff

; level 2-4/5-4
off_castle_area_3_enemies:
    .byte $0b, $8c, $4b, $4c, $77, $5f, $eb, $0c, $bd, $db
    .byte $19, $9d, $75, $1d, $7d, $5b, $d9, $1d, $3d, $dd
    .byte $99, $1d, $26, $9d, $5a, $2b, $8a, $2c, $ca, $1b
    .byte $20, $95, $7b, $5c, $db, $4c, $1b, $cc, $3b, $cc
    .byte $78, $2d, $a6, $28, $90, $b5
    .byte $ff

; level 3-4
off_castle_area_4_enemies:
    .byte $0b, $8c, $3b, $1d, $8b, $1d, $ab, $0c, $db, $1d
    .byte $0f, $03, $65, $1d, $6b, $1b, $05, $9d, $0b, $1b
    .byte $05, $9b, $0b, $1d, $8b, $0c, $1b, $8c, $70, $15
    .byte $7b, $0c, $db, $0c, $0f, $08, $78, $2d, $a6, $28
    .byte $90, $b5
    .byte $ff

; level 7-4
off_castle_area_5_enemies:
    .byte $27, $a9, $4b, $0c, $68, $29, $0f, $06, $77, $1b
    .byte $0f, $0b, $60, $15, $4b, $8c, $78, $2d, $90, $b5
    .byte $ff

; level 8-4
off_castle_area_6_enemies:
    .byte $0f, $03, $8e, $65, $e1, $bb, $38, $6d, $a8, $3e, $e5, $e7
    .byte $0f, $08, $0b, $02, $2b, $02, $5e, $65, $e1, $bb, $0e
    .byte $db, $0e, $bb, $8e, $db, $0e, $fe, $65, $ec, $0f, $0d
    .byte $4e, $65, $e1, $0f, $0e, $4e, $02, $e0, $0f, $10, $fe, $e5, $e1
    .byte $1b, $85, $7b, $0c, $5b, $95, $78, $2d, $90, $b5
    .byte $ff

; level 3-3
off_ground_area_1_enemies:
    .byte $a5, $86, $e4, $28, $18, $a8, $45, $83, $69, $03
    .byte $c6, $29, $9b, $83, $16, $a4, $88, $24, $e9, $28
    .byte $05, $a8, $7b, $28, $24, $8f, $c8, $03, $e8, $03
    .byte $46, $a8, $85, $24, $c8, $24
    .byte $ff

; level 8-3
off_ground_area_2_enemies:
    .byte $eb, $8e, $0f, $03, $fb, $05, $17, $85, $db, $8e
    .byte $0f, $07, $57, $05, $7b, $05, $9b, $80, $2b, $85
    .byte $fb, $05, $0f, $0b, $1b, $05, $9b, $05
    .byte $ff

; level 4-1
off_ground_area_3_enemies:
    .byte $2e, $c2, $66, $e2, $11, $0f, $07, $02, $11, $0f, $0c
    .byte $12, $11
    .byte $ff

; level 6-2
off_ground_area_4_enemies:
    .byte $0e, $c2, $a8, $ab, $00, $bb, $8e, $6b, $82, $de, $00, $a0
    .byte $33, $86, $43, $06, $3e, $b4, $a0, $cb, $02, $0f, $07
    .byte $7e, $42, $a6, $83, $02, $0f, $0a, $3b, $02, $cb, $37
    .byte $0f, $0c, $e3, $0e
    .byte $ff

; level 3-1
off_ground_area_5_enemies:
    .byte $9b, $8e, $ca, $0e, $ee, $42, $44, $5b, $86, $80, $b8
    .byte $1b, $80, $50, $ba, $10, $b7, $5b, $00, $17, $85
    .byte $4b, $05, $fe, $34, $40, $b7, $86, $c6, $06, $5b, $80
    .byte $83, $00, $d0, $38, $5b, $8e, $8a, $0e, $a6, $00
    .byte $bb, $0e, $c5, $80, $f3, $00
    .byte $ff

; level 1-1
off_ground_area_6_enemies:
    .byte $1e, $c2, $00, $6b, $06, $8b, $86, $63, $b7, $0f, $05
    .byte $03, $06, $23, $06, $4b, $b7, $bb, $00, $5b, $b7
    .byte $fb, $37, $3b, $b7, $0f, $0b, $1b, $37
    .byte $ff

; level 1-3/5-3
off_ground_area_7_enemies:
    .byte $2b, $d7, $e3, $03, $c2, $86, $e2, $06, $76, $a5
    .byte $a3, $8f, $03, $86, $2b, $57, $68, $28, $e9, $28
    .byte $e5, $83, $24, $8f, $36, $a8, $5b, $03
    .byte $ff

; level 2-3/7-3
off_ground_area_8_enemies:
    .byte $0f, $02, $78, $40, $48, $ce, $f8, $c3, $f8, $c3
    .byte $0f, $07, $7b, $43, $c6, $d0, $0f, $8a, $c8, $50
    .byte $ff

; level 2-1
off_ground_area_9_enemies:
    .byte $85, $86, $0b, $80, $1b, $00, $db, $37, $77, $80
    .byte $eb, $37, $fe, $2b, $20, $2b, $80, $7b, $38, $ab, $b8
    .byte $77, $86, $fe, $42, $20, $49, $86, $8b, $06, $9b, $80
    .byte $7b, $8e, $5b, $b7, $9b, $0e, $bb, $0e, $9b, $80
; end of data terminator here is also used by pipe intro area
off_ground_area_10_enemies:
    .byte $ff

; level 5-1
off_ground_area_11_enemies:
    .byte $0b, $80, $60, $38, $10, $b8, $c0, $3b, $db, $8e
    .byte $40, $b8, $f0, $38, $7b, $8e, $a0, $b8, $c0, $b8
    .byte $fb, $00, $a0, $b8, $30, $bb, $ee, $42, $88, $0f, $0b
    .byte $2b, $0e, $67, $0e
    .byte $ff

; cloud level used in levels 2-1 and 5-2
off_ground_area_12_enemies:
    .byte $0a, $aa, $0e, $28, $2a, $0e, $31, $88
    .byte $ff

; level 4-3
off_ground_area_13_enemies:
    .byte $c7, $83, $d7, $03, $42, $8f, $7a, $03, $05, $a4
    .byte $78, $24, $a6, $25, $e4, $25, $4b, $83, $e3, $03
    .byte $05, $a4, $89, $24, $b5, $24, $09, $a4, $65, $24
    .byte $c9, $24, $0f, $08, $85, $25
    .byte $ff

; level 6-3
off_ground_area_14_enemies:
    .byte $cd, $a5, $b5, $a8, $07, $a8, $76, $28, $cc, $25
    .byte $65, $a4, $a9, $24, $e5, $24, $19, $a4, $0f, $07
    .byte $95, $28, $e6, $24, $19, $a4, $d7, $29, $16, $a9
    .byte $58, $29, $97, $29
    .byte $ff

; level 6-1
off_ground_area_15_enemies:
    .byte $0f, $02, $02, $11, $0f, $07, $02, $11
    .byte $ff

; warp zone area used in level 4-2
off_ground_area_16_enemies:
    .byte $ff

; level 8-1
off_ground_area_17_enemies:
    .byte $2b, $82, $ab, $38, $de, $42, $e2, $1b, $b8, $eb
    .byte $3b, $db, $80, $8b, $b8, $1b, $82, $fb, $b8, $7b
    .byte $80, $fb, $3c, $5b, $bc, $7b, $b8, $1b, $8e, $cb
    .byte $0e, $1b, $8e, $0f, $0d, $2b, $3b, $bb, $b8, $eb, $82
    .byte $4b, $b8, $bb, $38, $3b, $b7, $bb, $02, $0f, $13
    .byte $1b, $00, $cb, $80, $6b, $bc
    .byte $ff

; level 5-2
off_ground_area_18_enemies:
    .byte $7b, $80, $ae, $00, $80, $8b, $8e, $e8, $05, $f9, $86
    .byte $17, $86, $16, $85, $4e, $2b, $80, $ab, $8e, $87, $85
    .byte $c3, $05, $8b, $82, $9b, $02, $ab, $02, $bb, $86
    .byte $cb, $06, $d3, $03, $3b, $8e, $6b, $0e, $a7, $8e
    .byte $ff

; level 8-2
off_ground_area_19_enemies:
    .byte $29, $8e, $52, $11, $83, $0e, $0f, $03, $9b, $0e
    .byte $2b, $8e, $5b, $0e, $cb, $8e, $fb, $0e, $fb, $82
    .byte $9b, $82, $bb, $02, $fe, $42, $e8, $bb, $8e, $0f, $0a
    .byte $ab, $0e, $cb, $0e, $f9, $0e, $88, $86, $a6, $06
    .byte $db, $02, $b6, $8e
    .byte $ff

; level 7-1
off_ground_area_20_enemies:
    .byte $ab, $ce, $de, $42, $c0, $cb, $ce, $5b, $8e, $1b, $ce
    .byte $4b, $85, $67, $45, $0f, $07, $2b, $00, $7b, $85
    .byte $97, $05, $0f, $0a, $92, $02
    .byte $ff

; cloud level used in levels 3-1 and 6-2
off_ground_area_21_enemies:
    .byte $0a, $aa, $0e, $24, $4a, $1e, $23, $aa
    .byte $ff

; level 3-2
off_ground_area_22_enemies:
    .byte $1b, $80, $bb, $38, $4b, $bc, $eb, $3b, $0f, $04
    .byte $2b, $00, $ab, $38, $eb, $00, $cb, $8e, $fb, $80
    .byte $ab, $b8, $6b, $80, $fb, $3c, $9b, $bb, $5b, $bc
    .byte $fb, $00, $6b, $b8, $fb, $38
    .byte $ff

; level 1-2
off_underground_area_1_enemies:
    .byte $0b, $86, $1a, $06, $db, $06, $de, $c2, $02, $f0, $3b
    .byte $bb, $80, $eb, $06, $0b, $86, $93, $06, $f0, $39
    .byte $0f, $06, $60, $b8, $1b, $86, $a0, $b9, $b7, $27
    .byte $bd, $27, $2b, $83, $a1, $26, $a9, $26, $ee, $25, $0b
    .byte $27, $b4
    .byte $ff

; level 4-2
off_underground_area_2_enemies:
    .byte $0f, $02, $1e, $2f, $60, $e0, $3a, $a5, $a7, $db, $80
    .byte $3b, $82, $8b, $02, $fe, $42, $68, $70, $bb, $25, $a7
    .byte $2c, $27, $b2, $26, $b9, $26, $9b, $80, $a8, $82
    .byte $b5, $27, $bc, $27, $b0, $bb, $3b, $82, $87, $34
    .byte $ee, $25, $6b
    .byte $ff

; underground bonus rooms area used in many levels
off_underground_area_3_enemies:
    .byte $1e, $a5, $0a, $2e, $28, $27, $2e, $33, $c7, $0f, $03, $1e, $40, $07
    .byte $2e, $30, $e7, $0f, $05, $1e, $24, $44, $0f, $07, $1e, $22, $6a
    .byte $2e, $23, $ab, $0f, $09, $1e, $41, $68, $1e, $2a, $8a, $2e, $23, $a2
    .byte $2e, $32, $ea
    .byte $ff

; water area used in levels 5-2 and 6-2
off_water_area_1_enemies:
    .byte $3b, $87, $66, $27, $cc, $27, $ee, $31, $87, $ee, $23, $a7
    .byte $3b, $87, $db, $07
    .byte $ff

; level 2-2/7-2
off_water_area_2_enemies:
    .byte $0f, $01, $2e, $25, $2b, $2e, $25, $4b, $4e, $25, $cb, $6b, $07
    .byte $97, $47, $e9, $87, $47, $c7, $7a, $07, $d6, $c7
    .byte $78, $07, $38, $87, $ab, $47, $e3, $07, $9b, $87
    .byte $0f, $09, $68, $47, $db, $c7, $3b, $c7
    .byte $ff

; water area used in level 8-4
off_water_area_3_enemies:
    .byte $47, $9b, $cb, $07, $fa, $1d, $86, $9b, $3a, $87
    .byte $56, $07, $88, $1b, $07, $9d, $2e, $65, $f0
    .byte $ff
