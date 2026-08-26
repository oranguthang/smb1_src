# Content Authoring

The content authoring workflow presents five focused views over the tested
binary codecs:

| Studio | Editable artifacts |
| --- | --- |
| World/Area | World pointers, one area-object stream, and one enemy stream |
| Physics | Player movement and gravity profiles |
| Graphics | Metatile records and player animation tile mappings |
| Screen | Status-bar PPU packets |
| Sound | Music header, channel events, and an APU envelope |

Run make export-content after a native build. It writes formatted JSON beneath
content/workspace, which Git ignores. Each file records its codec, exact byte
capacity, CPU range, source owner, original hash, and decoded semantic data.
Writes use a temporary sibling plus atomic replacement, so an interrupted
export cannot leave a partial document.

Run make validate-content after editing. Protected metadata must remain intact;
the shared encoder from scripts/data_formats.py must produce exactly the
original fixed capacity; decoding that output must reproduce the edited JSON;
and the command reports the number and first address of changed bytes. Invalid
ranges, truncated streams, noncanonical masked values, and over- or under-sized
content are rejected.

Run make build-content to apply validated artifacts to a copy of the canonical
PRG and create build/content/smb.nes with the validated local header and CHR.
The source tree and preservation outputs are never modified. A machine-readable
diff report is written beside the content build.

Pass STUDIO=physics, STUDIO=graphics, STUDIO=screen, STUDIO=sound, or
STUDIO=world_area to operate on one view. Without STUDIO, all five views and all
ten codec-backed artifacts are processed. Raw planar CHR editing is deliberately
outside this milestone until a dedicated tested tile codec exists; Graphics
Studio currently owns the stable PRG-side graphics mappings.
