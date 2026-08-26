# Content Authoring

The authoring workflow provides four purpose-built, dependency-free Tkinter
programs. They use the same tested binary codecs as the command-line build and
store local work beneath the ignored `content/workspace/` directory.

| Command | What it edits |
| --- | --- |
| `make world-studio` | All 36 world-to-area routes and nine player physics tables |
| `make level-studio` | All 34 area headers, terrain-object streams, enemies, entrances, and page controls |
| `make graphics-studio` | 512 CHR tiles, 101 metatiles, 26 player frames, eight palette packets, and fixed-length UI text |
| `make sound-studio` | All 22 vanilla music headers and 76 channel views plus the swim/stomp volume envelope |

The programs are semantic editors rather than generic JSON inspectors. Level
Studio draws every area as a horizontally scrolling page grid and distinguishes
terrain objects from enemies and entrances. World Studio presents course
routing and documented physics profiles. Graphics Studio uses the actual SMB1
pattern-table convention: sprite tiles occupy the first 4 KiB and background
tiles the second 4 KiB. Sound Studio decodes notes, rests, duration changes, and
noise beats, draws a piano roll, and renders a local WAV preview.

Run `make init-content` before editing. It creates only missing workspace files,
so opening a studio never overwrites earlier local work. Run
`make export-content` only when intentionally restoring every supported artifact
from the preservation build. Writes use a temporary sibling and atomic
replacement.

Every variable stream retains its original fixed allocation. Level records may
be inserted or removed while the encoded stream fits its displayed byte budget;
a stream sharing its terminator with the following stream must retain its exact
payload length. Music event bytes are edited in place because channel offsets
are part of the original engine format. These restrictions keep pointers valid
and make malformed edits fail before a ROM is written.

Run `make validate-content` to validate protected metadata, canonical codec
values, fixed capacities, CHR size, and every edited artifact. Run
`make build-content` to create `build/content/smb.nes`, or `make run-content` to
build it and open it in the configured FCEUX executable. The source tree and
preservation outputs are never modified. A machine-readable byte-difference
report is written beside the content build.

`make check-studios` initializes missing local files and checks all four models
without opening windows. The lower-level init, export, validate, and build
commands accept `STUDIO=world`, `STUDIO=level`, `STUDIO=graphics`, or
`STUDIO=sound`.

The ignored `references/` directory may contain local research checkouts. The
editors were implemented independently from the documented SMB1 formats. No
third-party editor source is incorporated into the tracked project. The reviewed
projects and reuse boundaries are recorded in `docs/editor_references.md`.

The immutable 1.0 round-trip manifest remains `config/data_formats.json`.
`config/content_formats.json` layers complete level streams, the full vanilla
music bank, all metatiles, complete game text, and area palette packets over it
without changing the accepted 1.0 evidence count.
