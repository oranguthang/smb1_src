# Symbol Naming

Symbols describe program roles rather than binary locations. CPU addresses
belong in linker configuration, maps, comments, and provenance records; they
must not be the identity of an active semantic symbol.

## Code Symbols

6502 assembly has no function declaration, so the prefix records how an entry
is reached:

| Prefix | Meaning |
| --- | --- |
| `sub_` | Callable subroutine entered with `JSR` and returned from with `RTS` |
| `handler_` | Entry selected by a jump table or another indirect dispatcher |
| `loc_` | Shared code entry reached with `JMP` |
| `bra_` | Internal conditional branch target |
| `vec_` | CPU interrupt or reset vector entry |

A `sub_` label must have a direct `JSR` caller. Every direct `JSR` target will
converge on the `sub_` prefix as milestone 3 proceeds. A label reached both by
fall-through and a conditional branch remains a `bra_`; a shared entry reached
with `JMP` uses `loc_`.

## Data Symbols

| Prefix | Meaning |
| --- | --- |
| `tbl_` | Indexed table or lookup data |
| `off_` | Addressable data block referenced through a pointer table |
| `ram_` | Persistent or domain-specific RAM field |
| `zp_` | Neutral zero-page workspace |
| `con_` | Assembly-time constant |
| `unused_` | Code or data proven unreachable for the reference ROM |

Shared zero-page workspace may keep a neutral scratch alias until each use has
a proven contextual role. Unknown persistent state must remain explicitly
unknown until static or runtime evidence supports a semantic name.

## Naming Rules

1. Prefer a role such as `sub_update_player_movement` over a ROM address.
2. Include subsystem context when a short local description would collide.
3. Keep state or opcode values only when they are part of a decoded format.
4. Preserve useful original names or addresses in review history and generated
   maps rather than embedding them in active identifiers.
5. Treat a plausible interpretation as insufficient evidence for a rename.
6. Run `make verify` after every rename batch; symbol cleanup must not alter a
   single emitted byte.

The vocabulary is being adopted incrementally. Existing descriptive symbols
remain valid until their replacements are supported by control-flow, data-flow,
or runtime evidence.
