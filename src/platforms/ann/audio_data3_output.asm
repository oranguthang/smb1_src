; All Night Nippon APU and FDS channel register writers

sub_ann_write_fds_pulse_1_base:
    STY SND_SQUARE1_SWEEP
    STX SND_REGISTER
    RTS

handler_ann_write_fds_pulse_1:
    JSR sub_ann_write_fds_pulse_1_base

sub_ann_write_fds_pulse_1_note:
    LDX #$00
    TAY
    LDA $df01, Y
    BEQ $d2bc
    STA SND_SQUARE1_TIMER_LO, X
    LDA $df00, Y
    ORA #$08
    STA SND_SQUARE1_TIMER_HI, X
    RTS

sub_ann_write_fds_pulse_2_base:
    STX SND_SQUARE2_REG
    STY SND_SQUARE2_SWEEP
    RTS

handler_ann_write_fds_pulse_2:
    JSR sub_ann_write_fds_pulse_2_base

sub_ann_write_fds_pulse_2_note:
    LDX #$04
    BNE $d2ab

sub_ann_write_fds_triangle_note:
    LDX #$08
    BNE $d2ab

sub_ann_write_fds_wave_note:
    LDX #$80
    STX FDS_SND_FREQUENCY + 1
    TAY
    LDA tbl_ann_fds_wave_notes, Y
    STA FDS_SND_FREQUENCY + 1
    LDA $d201, Y
    STA FDS_SND_FREQUENCY
    RTS
