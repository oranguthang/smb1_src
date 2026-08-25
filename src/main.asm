;SMBDIS.ASM - A COMPREHENSIVE SUPER MARIO BROS. DISASSEMBLY
;by doppelganger (doppelheathen@gmail.com)

;This file is provided for your own use as-is.  It will require the character rom data
;and an iNES file header to get it to work.

;There are so many people I have to thank for this, that taking all the credit for
;myself would be an unforgivable act of arrogance. Without their help this would
;probably not be possible.  So I thank all the peeps in the nesdev scene whose insight into
;the 6502 and the NES helped me learn how it works (you guys know who you are, there's no
;way I could have done this without your help), as well as the authors of x816 and SMB
;Utility, and the reverse-engineers who did the original Super Mario Bros. Hacking Project,
;which I compared notes with but did not copy from.  Last but certainly not least, I thank
;Nintendo for creating this game and the NES, without which this disassembly would
;only be theory.

;The original source assembled with x816; this reconstruction assembles with ca65.

;-------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------
;DEFINITIONS

       .include "memory/hardware.inc"
       .include "memory/ram.inc"
       .include "memory/constants.inc"

;-------------------------------------------------------------------------------------
;DIRECTIVES

       .p02

       .org $8000

       .include "system/boot_and_frame.asm"

       .include "game/modes.asm"
       .include "rendering/screens.asm"
       .include "rendering/background.asm"
       .include "system/hardware_io.asm"
       .include "rendering/hud/status.asm"
       .include "game/setup_and_transitions.asm"
       .include "game/level/parser.asm"
       .include "game/level/special_objects.asm"
       .include "game/level/terrain_objects.asm"
       .include "data/levels/index_and_enemies.asm"
       .include "data/levels/areas.asm"
       .include "game/core.asm"
       .include "game/player/physics.asm"
       .include "game/objects/projectiles_and_interactions.asm"
       .include "game/objects/dynamic.asm"
       .include "game/objects/blocks.asm"
       .include "game/physics/movement.asm"
       .include "game/enemies/stream_and_initialization.asm"
       .include "game/enemies/special_initialization.asm"
       .include "game/enemies/runtime.asm"
       .include "game/enemies/special_behaviors.asm"
       .include "game/enemies/bowser_and_goals.asm"
       .include "game/platforms.asm"
       .include "game/collisions/projectiles.asm"
       .include "game/collisions/actors.asm"
       .include "game/collisions/player_background.asm"
       .include "game/collisions/enemy_background.asm"
       .include "game/collisions/bounding_boxes.asm"
       .include "rendering/actors/misc.asm"
       .include "rendering/actors/enemies.asm"
       .include "rendering/actors/objects.asm"
       .include "rendering/actors/player.asm"
       .include "rendering/positioning.asm"
       .include "audio/sound_effects.asm"
       .include "audio/music_engine.asm"
       .include "audio/music_data.asm"
       .include "data/vectors.asm"
