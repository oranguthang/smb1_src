; Shared late-FDS hard-course checkpoint initializer

sub_late_fds_initialize_hard_course_checkpoints:
    LDY #$07

bra_late_fds_copy_hard_course_checkpoints:
    LDA off_late_fds_hard_course_checkpoint_starts,y
    STA tbl_late_fds_halfway_page_nibbles,y
    DEY
    BPL bra_late_fds_copy_hard_course_checkpoints
    RTS
