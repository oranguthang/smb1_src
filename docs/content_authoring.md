# Content Authoring

The authoring workflow provides four purpose-built, dependency-free Tkinter
programs. They use the same tested binary codecs as the command-line build and
store local work beneath the ignored `content/workspace/` directory.

| Command | What it edits |
| --- | --- |
| `make world-studio` | All 36 world-to-area routes and nine player physics tables |
| `make level-studio` | All 34 area headers, terrain-object streams, enemies, entrances, and page controls |
| `make graphics-studio` | 512 CHR tiles, 101 metatiles, 26 player frames, eight palette packets, and fixed-length UI text |
| `make sound-studio` | Fourteen logical compositions, all 22 vanilla headers and 75 active channel views plus the swim/stomp volume envelope |

The programs are semantic editors rather than generic JSON inspectors. Level
Studio reconstructs every area from the authored headers and object streams,
using the actual CHR, palettes, metatile groups, scenery patterns, terrain
masks, and actor frames. Its horizontally scrolling map therefore shows the
game's terrain, clouds, bushes, mountains, blocks, pipes, common structures,
Mario, the complete normal-state enemy table, Bowser, Toad, grouped enemies,
firebars, and moving platforms instead of abstract record boxes. Intro pipes,
balance ropes, and castle structures use the same metatile layouts as the
engine. Records that only start an invisible generator remain visible as dashed
editor markers. Record badges and the side tables retain direct access to the
underlying bytes. World Studio
presents course routing and documented physics profiles. Graphics Studio uses
the actual SMB1 pattern-table convention: sprite tiles occupy the first 4 KiB
and background tiles the second 4 KiB. Sound Studio decodes notes, rests,
duration changes, and noise beats, draws a piano roll, and renders either one
pattern or a complete logical composition. The complete overworld preview
follows the original 33-pattern schedule instead of treating its internal parts
as separate songs.
Preview synthesis uses the APU's four-bit channel levels, 15-bit noise shift
register and hardware length-counter gates, nonlinear pulse/TND transfer curves,
and the console's two high-pass and one low-pass output filters rather than
generic oscillator mixing. Pulse previews follow the short area, long
water/event, and castle-clear software envelopes; Triangle sustain follows the
engine's `$0F`, `$1F`, and `$FF` linear-counter control modes.
Four independent preview checkboxes enable or mute Square 2, Square 1,
Triangle, and Noise without changing the authored music data.

Level Studio also provides an in-place point playtest on Windows. Right-click
the map, or press **Place Mario** and left-click, to select a starting cell.
The Lighting selector previews and playtests the area with either the daytime
blue universal background or the nighttime black background; each area opens
with its vanilla choice, so World 1-1 starts in Day mode. The placement marker
uses the small standing-Mario frame and the playtest starts with the matching
small-player state. Area, Lighting, World, Course, and area-header arrow controls
apply immediately, so browsing visual variants does not require pressing Enter.
Switching areas resets Mario to the entrance height encoded by the new area
header; changing Entrance Y updates the marker by the same rule.
**Play** saves and validates the level workspace, creates the isolated content
ROM, opens the selected area and page with the original game engine, and embeds
the native FCEUX window in the Playtest tab. The World and Course controls
supply the correct route context for shared and bonus areas. Click the game
screen before using the keyboard; configured gamepads continue to work through
FCEUX. The embedded frame scales to the complete Playtest tab while preserving
the NES aspect ratio; only the unavoidable side or letterbox bars remain. A
generated per-run FCEUX configuration keeps these video settings isolated from
the user's emulator configuration. **Stop** closes only the editor-owned
emulator process and returns to the map. Set `FCEUX_EXE` when the executable is
not available at the default sibling path
`../fceux_automation/vc/x64/Release/fceux64.exe`.

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
