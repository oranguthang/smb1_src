# Source Layout

The linker contract in `src/nrom256_prg_only.cfg` fixes the `PRG` segment at
`$8000..$FFF9` and the six-byte `VECTORS` segment at `$FFFA..$FFFF`. The output
is a bare 32 KiB PRG image; header and CHR handling remain outside ld65.

This document records the address-ordered modularization of the native SMB1
PRG. Module boundaries preserve the original byte order and are accepted only
after `make verify` succeeds.

## Granularity Policy

The project follows the same middle-grained organization used by the Pac-Man
reconstruction. A module owns a coherent subsystem, its closely related helper
routines, and the data those routines consume. Small routines are not split
into separate files merely to mirror a call graph or satisfy a line limit.

Typical modules should be a few hundred lines. The 200-500 line range is a
useful target when natural boundaries permit it; 700 lines is a soft upper
limit, not a mandate to fragment cohesive code.

## Current Address Map

| File | CPU range | Lines | Responsibility |
| --- | --- | ---: | --- |
| `src/memory/hardware.inc` | no emitted bytes | 23 | NES hardware registers |
| `src/memory/ram.inc` | no emitted bytes | 459 | Zero-page and RAM aliases |
| `src/memory/constants.inc` | no emitted bytes | 157 | Sound, music, object, input, and mode constants |
| `src/main.asm` | no independent range | 72 | Canonical address-ordered include index |
| `src/system/boot_and_frame.asm` | `$8000-$8230` | 282 | Reset, NMI frame driver, timers, pause, sprite shuffling, and mode dispatch |
| `src/game/modes.asm` | `$8231-$8566` | 404 | Title, demo, victory, and floating-score flow |
| `src/rendering/screens.asm` | `$8567-$88AD` | 431 | Screen tasks, palettes, text, and title-screen transfer |
| `src/rendering/background.asm` | `$88AE-$8E03` | 574 | Area rendering, attributes, metatiles, palettes, and messages |
| `src/system/hardware_io.asm` | `$8E04-$8EF3` | 149 | Jump dispatch, controller input, PPU buffers, and nametable initialization |
| `src/rendering/hud/status.asm` | `$8EF4-$8FBB` | 125 | Status digits, score arithmetic, and top-score updates |
| `src/game/setup_and_transitions.asm` | `$8FBC-$92AF` | 395 | Game/area setup, entrances, life loss, and game over |
| `src/game/level/parser.asm` | `$92B0-$96C4` | 498 | Column parser, scenery, terrain, and area-object dispatch |
| `src/game/level/special_objects.asm` | `$96C5-$9956` | 375 | Area attributes, ledges, castles, pipes, and scroll locks |
| `src/game/level/terrain_objects.asm` | `$9957-$9BF7` | 443 | Holes, bridges, blocks, cannons, stairs, springs, and buffer helpers |
| `src/data/levels/index_and_enemies.asm` | `$9BF8-$A1AE` | 422 | Area lookup tables and enemy object streams |
| `src/data/levels/areas.asm` | `$A1AF-$AEDB` | 515 | Encoded area-object streams |
| `src/game/core.asm` | `$AEDC-$B328` | 586 | Game mode, scrolling, player control states, and area transitions |
| `src/game/player/physics.asm` | `$B329-$B623` | 396 | Walking, running, jumping, swimming, climbing, and friction |
| `src/game/objects/projectiles_and_interactions.asm` | `$B624-$B9B9` | 490 | Fireballs, bubbles, timer, warp zones, flagpole, spring, and vine |
| `src/game/objects/dynamic.asm` | `$B9BA-$BCEA` | 451 | Cannons, bullets, hammers, coins, scoring, and power-ups |
| `src/game/objects/blocks.asm` | `$BCEB-$BF01` | 316 | Player/block interaction, brick chunks, and block runtime |
| `src/game/physics/movement.asm` | `$BF02-$C046` | 236 | Shared horizontal, vertical, and gravity movement primitives |
| `src/game/enemies/stream_and_initialization.asm` | `$C047-$C44E` | 606 | Enemy stream parsing, loop commands, and common initialization |
| `src/game/enemies/special_initialization.asm` | `$C44F-$C881` | 636 | Firebars, flying enemies, Bowser, groups, and platforms |
| `src/game/enemies/runtime.asm` | `$C882-$CCC6` | 660 | Enemy dispatcher and common movement behaviors |
| `src/game/enemies/special_behaviors.asm` | `$CCC7-$CFDC` | 401 | Firebars, flying Cheep-Cheeps, and Lakitu/Spiny behavior |
| `src/game/enemies/bowser_and_goals.asm` | `$CFDD-$D431` | 598 | Bowser, bridge collapse, fireworks, star flag, and Piranha Plant |
| `src/game/platforms.asm` | `$D432-$D6D8` | 395 | Balance, moving, falling, and lift platforms |
| `src/game/collisions/projectiles.asm` | `$D6D9-$D852` | 225 | Fireball/enemy, hammer/player, and power-up collisions |
| `src/game/collisions/actors.asm` | `$D853-$DC61` | 612 | Player/enemy, enemy/enemy, and platform collisions |
| `src/game/collisions/player_background.asm` | `$DC62-$DFB8` | 498 | Player metatile collision, climbing, pipes, coins, and movement blocking |
| `src/game/collisions/enemy_background.asm` | `$DFB9-$E1FC` | 367 | Enemy and fireball interactions with background metatiles |
| `src/game/collisions/bounding_boxes.asm` | `$E1FD-$E432` | 338 | Bounding-box construction and generic overlap/block-buffer tests |
| `src/rendering/actors/misc.asm` | `$E433-$E73D` | 442 | Vines, hammers, flags, platforms, coins, and power-ups |
| `src/rendering/actors/enemies.asm` | `$E73E-$EBCC` | 548 | Enemy graphics selection, animation, mirroring, and OAM rows |
| `src/rendering/actors/objects.asm` | `$EBCD-$EE06` | 303 | Blocks, brick chunks, fireballs, explosions, platforms, and bubbles |
| `src/rendering/actors/player.asm` | `$EE07-$F129` | 368 | Player graphics, animation, sizing, attributes, and OAM output |
| `src/rendering/positioning.asm` | `$F12A-$F2CF` | 285 | Relative coordinates, offscreen bits, and generic sprite composition |
| `src/audio/sound_effects.asm` | `$F2D0-$F690` | 562 | Audio dispatcher and square/noise sound effects |
| `src/audio/music_engine.asm` | `$F691-$F90C` | 355 | Music headers, channel sequencing, lengths, and envelopes |
| `src/audio/music_data.asm` | `$F90D-$FFF9` | 387 | Music headers, note streams, frequency tables, and envelopes |
| `src/data/vectors.asm` | `$FFFA-$FFFF` | 6 | NMI, reset, and IRQ vectors |

## Verification Baseline

- PRG size: 32,768 bytes
- PRG SHA-1: `fefa1097449a3a11ebf8c6199e905996c5dc8fbd`
- CHR size: 8,192 bytes
- CHR SHA-1: `394badaf0b0bdd0ea279a1bca89a9d9ddc00b1b5`
- Full ROM SHA-1: `ea343f4e445a9050d4b4fbac2c77d0693b1d0922`
- PRG-only verification command: `make verify-prg`
- Full byte-identity verification command: `make verify`

## Modular Baseline Result

The native PRG now consists of 38 cohesive ASM modules plus a 72-line include
index and three definition includes. Ordinary modules range from 125 to 660
lines; the fixed vector block is intentionally six lines. Tables stay beside
their owning code unless they form a substantial address-ordered data set.
