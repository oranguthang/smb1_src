# Runtime Evidence Scenarios

The runtime workflow replays a deterministic power-on FCEUX movie against the
byte-identical preservation ROM and records compact semantic events from named
source routines. Run the focused scenarios and their validator with:

```bash
make trace-runtime
```

The tracked input fixture is `movies/smb1_any_percent.fm2`, a public TASVideos
user file authored by DJ Incendration. It contains controller input only, not
ROM, CHR, screenshots, audio, or savestates. The scenario manifest pins both the
movie SHA-1 and preservation-ROM SHA-1 before FCEUX starts.
Its original title, source page, CC BY 2.0 license, byte identity, and checksum
are recorded in [`movies/README.md`](../movies/README.md).

## Natural Evidence

The same power-on input deterministically reproduces these World 1-1 events:

| Scenario | Semantic evidence | First frame |
| --- | --- | ---: |
| Title boot | `vec_nmi_handler` | 6 |
| World 1-1 start | `sub_game_core_routine` in game mode | 195 |
| Walking | Grounded horizontal displacement | 202 |
| Jumping | `handler_player_jumping_or_swimming` | 228 |
| Block impact | `sub_bump_block` | 304 |
| Coin collection | `sub_give_one_coin` | 304 |
| Pipe entry and exit | Vertical and side-pipe handlers | 570, 774 |
| Enemy stomp | `loc_enemy_stomped` | 1127 |
| Flagpole completion | Active flagpole state in `sub_flagpole_routine` | 1304 |

The `natural-longplay` scenario retains all 17,862 movie frames and periodic
state checkpoints as a broad mode, position, inventory, and progress regression.

## Controlled Evidence

The source movie does not naturally collect a power-up or lose a life. Those
two scenarios therefore declare controlled RAM patches in
`scenarios/runtime_scenarios.json`; the Lua capture writes every changed address,
old value, new value, and reason as a `controlled_patch` event. The validator
rejects missing, extra, or malformed patches.

`power-up-collection` creates a fully active power-up in enemy slot five at
Mario's current coordinates. The ordinary object/collision pipeline then enters
`loc_handle_power_up_collision` at frame 252 and finishes with Super Mario
status. The patch proves the transaction from collision onward; it is not
evidence for natural block selection, emergence, or movement.

`death-respawn` selects the documented death handler and crosses its vertical
boundary after stable natural play. The ordinary dispatch sequence then enters
`handler_player_death`, `handler_player_lose_life`, and finally
`handler_player_entrance`, decrementing lives from two to one. It proves the
death/respawn transaction after the boundary patch; it is not evidence for a
natural enemy or pit collision.

Generated CSV files remain under `build/runtime/`. Exact event frames and final
state assertions live beside patch declarations in the scenario manifest, so a
contributor can reproduce evidence without relying on prose or a saved emulator
state.
