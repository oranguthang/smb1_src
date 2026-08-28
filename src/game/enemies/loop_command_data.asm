; -------------------------------------------------------------------------------------

; Loop-command descriptors and the shared four-page rewind helper

tbl_loop_command_world_numbers:
.if con_revision_profile = con_revision_profile_vs
    .byte $04, $04, $06, $06, $06, $06, $06, $06, $07, $07, $07
.elseif con_revision_profile = con_revision_profile_ann
    .byte $03, $03, $06, $06, $06, $06, $06, $06, $07, $07
.else
    .byte $03, $03, $06, $06, $06, $06, $06, $06, $07, $07, $07
.endif

tbl_loop_command_page_numbers:
.if con_revision_profile = con_revision_profile_ann
    .byte $05, $09, $04, $05, $06, $08, $09, $0a, $05, $0b
.else
    .byte $05, $09, $04, $05, $06, $08, $09, $0a, $06, $0b, $10
.endif

tbl_loop_command_player_y_positions:
.if con_revision_profile = con_revision_profile_vs
    .byte $40, $b0, $b0, $40, $40, $b0, $40, $80, $f0, $f0, $f0
.elseif con_revision_profile = con_revision_profile_ann
    .byte $b0, $40, $40, $40, $40, $40, $80, $80, $f0, $b0
.else
    .byte $40, $b0, $b0, $80, $40, $40, $80, $40, $f0, $f0, $f0
.endif

.if con_revision_profile = con_revision_profile_ann
tbl_ann_loop_command_required_counts:
    .byte $01, $01, $03, $03, $03, $03, $03, $03, $01, $01
.endif

sub_exec_game_loopback:
    LDA ram_player_page_loc  ; send player back four pages
    SEC
    SBC #$04
    STA ram_player_page_loc
    LDA ram_current_page_loc  ; send current page back four pages
    SEC
    SBC #$04
    STA ram_current_page_loc
    LDA ram_screen_left_page_loc  ; subtract four from page location
    SEC  ; of screen's left border
    SBC #$04
    STA ram_screen_left_page_loc
    LDA ram_screen_right_page_loc  ; do the same for the page location
    SEC  ; of screen's right border
    SBC #$04
    STA ram_screen_right_page_loc
    LDA ram_area_object_page_loc  ; subtract four from page control
    SEC  ; for area objects
    SBC #$04
    STA ram_area_object_page_loc
    LDA #$00  ; initialize page select for both
    STA ram_enemy_object_page_sel  ; area and enemy objects
    STA ram_area_object_page_sel
    STA ram_enemy_data_offset  ; initialize enemy object data offset
    STA ram_enemy_object_page_loc  ; and enemy object page control
.if con_revision_profile = con_revision_profile_vs
    LDA #con_vs_request_irq_release
    STA VS_REQUEST
    LDA ram_vs_io_buffer,y  ; read the CHR-resident loop offset copied during course loading
.else
    LDA tbl_area_object_loopback_offsets,y  ; adjust area object offset based on
.endif
    STA ram_area_data_offset  ; which loop command we encountered
    RTS
