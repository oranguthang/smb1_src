; ANN NSMDATA4 HARD-COURSE LOADER

.include "shared_interface.inc"
.include "../../../common/game/hard_course_loader.asm"

.assert * - handler_late_fds_get_hard_course_descriptor = $a3, error, "ANN DATA4 course loader must be 163 bytes"
