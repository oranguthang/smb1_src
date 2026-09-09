# Source and Symbol Provenance

Technical provenance records where imported source and names came from; it does
not grant permission to distribute the original game or its data. Distribution
status and third-party licensing are documented separately in
[`licensing.md`](licensing.md).

`config/reconstruction/label_renames.json` is the sole canonical symbol rename
registry. Its `smb1` section maps every label in doppelganger's imported
`smbdis.asm` to its current semantic name and module. The source is pinned to
repository commit `052aa23781fe028d8d7d2627638a87326107c015`, preserving the
imported file independently of the mutable external gist. The registry includes
colon labels that share a physical line with their first instruction, and tests
compare its ordered roots with that pinned Git object when history is available.

The `smb2` section maps pinned sibling-engine listings to reviewed current
symbols. Project-internal intermediate names are intentionally omitted;
`project_additions` records current labels with no imported predecessor. Its
single current entry names a formerly unlabeled inline player-state handler
table without changing emitted bytes.

File paths are navigation hints, not stable symbol identities. Validation
requires every mapped target and project addition to occur exactly once across
active ASM and INC modules without relying on fragile source line numbers.
