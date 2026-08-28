; Standalone ANN audio-tail verification entrypoint

.include "profile_ids.inc"

con_revision_profile = con_revision_profile_ann

.include "../memory/hardware.inc"
.include "../memory/ram.inc"

con_sfx_extra_life = %01000000
con_time_running_out_music = %01000000
con_end_of_castle_music = %00001000
con_victory_music = %00000100
con_death_music = %00000001
con_music_header_offset_table_base = tbl_music_header_offsets - 1
con_music_header_data_base = tbl_music_header_offsets

.p02

.segment "PRG"
.org $d2e4

.include "../audio/sound_effects.asm"
.include "../audio/music_engine.asm"
.include "../audio/music_data.asm"
