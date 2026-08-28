.if con_revision_profile = con_revision_profile_pal
    .define con_course_area_streams_asset "../../../assets/generated/revisions/pal/source/pal_course_area_streams.bin"
.else
    .define con_course_area_streams_asset "../../../assets/generated/source/base_course_area_streams.bin"
.endif

; AREA OBJECT DATA

; level 1-4/6-4
off_castle_area_1_objects:
    .incbin con_course_area_streams_asset, $000, $061

; level 4-4
off_castle_area_2_objects:
    .incbin con_course_area_streams_asset, $061, $07f

; level 2-4/5-4
off_castle_area_3_objects:
    .incbin con_course_area_streams_asset, $0e0, $073

; level 3-4
off_castle_area_4_objects:
    .incbin con_course_area_streams_asset, $153, $06d

; level 7-4
off_castle_area_5_objects:
    .incbin con_course_area_streams_asset, $1c0, $08b

; level 8-4
off_castle_area_6_objects:
    .incbin con_course_area_streams_asset, $24b, $071

; level 3-3
off_ground_area_1_objects:
    .incbin con_course_area_streams_asset, $2bc, $063

; level 8-3
off_ground_area_2_objects:
    .incbin con_course_area_streams_asset, $31f, $069

; level 4-1
off_ground_area_3_objects:
    .incbin con_course_area_streams_asset, $388, $053

; level 6-2
off_ground_area_4_objects:
    .incbin con_course_area_streams_asset, $3db, $08f

; level 3-1
off_ground_area_5_objects:
    .incbin con_course_area_streams_asset, $46a, $075

; level 1-1
off_ground_area_6_objects:
    .incbin con_course_area_streams_asset, $4df, $065

; level 1-3/5-3
off_ground_area_7_objects:
    .incbin con_course_area_streams_asset, $544, $055

; level 2-3/7-3
off_ground_area_8_objects:
    .incbin con_course_area_streams_asset, $599, $085

; level 2-1
off_ground_area_9_objects:
    .incbin con_course_area_streams_asset, $61e, $065

; pipe intro area
off_ground_area_10_objects:
    .incbin con_course_area_streams_asset, $683, $009

; level 5-1
off_ground_area_11_objects:
    .incbin con_course_area_streams_asset, $68c, $03f

; cloud level used in levels 2-1 and 5-2
off_ground_area_12_objects:
    .incbin con_course_area_streams_asset, $6cb, $015

; level 4-3
off_ground_area_13_objects:
    .incbin con_course_area_streams_asset, $6e0, $067

; level 6-3
off_ground_area_14_objects:
    .incbin con_course_area_streams_asset, $747, $065

; level 6-1
off_ground_area_15_objects:
    .incbin con_course_area_streams_asset, $7ac, $073

; warp zone area used in level 4-2
off_ground_area_16_objects:
    .incbin con_course_area_streams_asset, $81f, $031

; level 8-1
off_ground_area_17_objects:
    .incbin con_course_area_streams_asset, $850, $093

; level 5-2
off_ground_area_18_objects:
    .incbin con_course_area_streams_asset, $8e3, $073

; level 8-2
off_ground_area_19_objects:
    .incbin con_course_area_streams_asset, $956, $079

; level 7-1
off_ground_area_20_objects:
    .incbin con_course_area_streams_asset, $9cf, $059

; cloud level used in levels 3-1 and 6-2
off_ground_area_21_objects:
    .incbin con_course_area_streams_asset, $a28, $02b

; level 3-2
off_ground_area_22_objects:
    .incbin con_course_area_streams_asset, $a53, $033

; level 1-2
off_underground_area_1_objects:
    .incbin con_course_area_streams_asset, $a86, $0a3

; level 4-2
off_underground_area_2_objects:
    .incbin con_course_area_streams_asset, $b29, $0a1

; underground bonus rooms area used in many levels
off_underground_area_3_objects:
    .incbin con_course_area_streams_asset, $bca, $08d

; water area used in levels 5-2 and 6-2
off_water_area_1_objects:
    .incbin con_course_area_streams_asset, $c57, $03f

; level 2-2/7-2
off_water_area_2_objects:
    .incbin con_course_area_streams_asset, $c96, $07b

; water area used in level 8-4
off_water_area_3_objects:
    .incbin con_course_area_streams_asset, $d11, $01c
