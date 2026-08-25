# Source Provenance

`label_renames.json` maps every label in doppelganger's imported `smbdis.asm`
directly to its current semantic name and module. The source side is pinned to
repository commit `052aa23781fe028d8d7d2627638a87326107c015`, which preserves
the imported file independently of the mutable external gist.

Project-internal intermediate names are intentionally omitted. The separate
`project_additions` collection records current labels that have no original
doppelganger label. At present it contains the single name introduced for the
previously unlabeled inline player-state handler table; adding the symbol did
not change emitted bytes.

Current file paths are navigation hints rather than stable identities. Tests
require every mapped target and project addition to exist exactly once across
the active assembly tree, without relying on fragile source line numbers.
