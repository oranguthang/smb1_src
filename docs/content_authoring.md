# Content Authoring

The authoring workflow provides four purpose-built, dependency-free Tkinter
programs. They use the same tested binary codecs as the command-line build and
store local work beneath the ignored `content/workspace/` directory.

Source Reconstruction 3.0 introduces a manifest-owned compatibility matrix at
`config/content_authoring_profiles.json`. Run `make list-content-profiles` to
inspect Studio availability and `make content-profile-audit` to validate the
contract. JU, PC10, PAL, Vs. SMB, FDS SMB1, ANN, and SMB2 support all four Studios
through isolated profile workspaces, labels, stream capacities, program images,
and container builders. ANN has an exact multi-payload FDS composition contract,
and point playtesting is proven for both its normal and extended course banks.
A profile or Studio is not
selectable merely because its program happens to share labels or bytes with JU.
Source 3 formats extend the frozen Source 2 codec manifest through
`config/content_formats_3.json`; the earlier release contract is not rewritten.

Select a supported profile with `CONTENT_PROFILE`:

```bash
make level-studio CONTENT_PROFILE=pal
make sound-studio CONTENT_PROFILE=pc10
make level-studio CONTENT_PROFILE=vs_smb
make graphics-studio CONTENT_PROFILE=fds_smb
make level-studio CONTENT_PROFILE=ann_fds
make level-studio CONTENT_PROFILE=smb2_jp_fds
make build-content CONTENT_PROFILE=ju
```

Each Studio displays the selected profile in its title and forwards it to Build
ROM, Run FCEUX, and Level Studio playtest actions. Workspace documents carry a
protected profile identifier, preventing a PAL document from being applied to a
JU or PC10 build.

| Command | What it edits |
| --- | --- |
| `make world-studio` | All 36 world-to-area routes and nine player physics tables |
| `make level-studio` | Every selected-profile area header, terrain-object stream, enemy stream, entrance, and page control |
| `make graphics-studio` | 512 CHR tiles, 101 metatiles, 26 player frames, eight palette packets, and fixed-length UI text |
| `make sound-studio` | Fourteen main-game compositions, every selected-profile header and active channel view, plus the swim/stomp volume envelope; ANN and SMB2 also expose their FDS ending suites |

ANN Level Studio adds a course-set selector. Its normal set resolves 44 valid
areas through pointer tables spanning `NSMMAIN` and `NSMDATA2`; its extended set
resolves 21 areas from `NSMDATA4` plus the two deliberately reused primary
streams. World Studio exposes the corresponding 36 normal and 18 extended
routes. Shared empty enemy pointers must encode identically, and the service
pointer that targets a lone `$FD` is excluded because it is not an area stream.
ANN Sound Studio adds a bank selector instead of interpreting the ending overlay
as ordinary SMB1 music. The main bank retains the four-channel APU model. The
`NSMDATA3` bank decodes the actual 11-section ending order, six fixed headers,
APU pulse/triangle/noise streams, FDS wave channel, private length table, and
software envelopes. Its synthesis view edits both 32-byte source waves (mirrored
by the game into 64 FDS samples) and typed direct/increase/decrease volume steps.
All note and synthesis edits preserve the original byte capacities.

SMB2 Level Studio exposes Worlds 1-9 and Worlds A-D as separate course banks.
Their 73 editable areas retain explicit stream ownership across `SM2MAIN`,
`SM2DATA2`, `SM2DATA3`, and `SM2DATA4`; shared streams are written back to one
canonical owner. World Studio exposes 58 routes, Graphics Studio exposes 512
CHR tiles, 104 metatiles, and 26 player frames, and Sound Studio keeps the main
APU bank separate from the `SM2DATA3` FDS ending suite. Studio window titles
identify this sibling engine as SMB2 rather than SMB1.

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
and background tiles the second 4 KiB. Its eight editable area-palette packets
retain stable labels over the shared console/FDS or Vs.-specific ignored pack.
The 101 editable 2x2 metatiles use the shared graphics pack; the ANN build
selects its 102-record later-engine counterpart without changing renderer
pointers.
Sound Studio decodes notes, rests,
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
The linked headers remain relocatable ASM; note streams, timing tables, and
envelopes come from checksum-validated profile packs with the same labels that
the Sound Studio and engine consume.

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
FDS playtesting allows a longer boot interval than cartridge profiles because
the BIOS must load the program and CHR records before the normal title task is
ready. Embedded playtests use turbo only for this startup phase and restore
normal speed before control is handed to the player. ANN normal courses use
title task 3 and stabilize in gameplay task 5; these values were measured by
the smoke trace rather than inherited from cartridge SMB. Extended-course
playtests enter disk-loader task 6, load record `$40` (`NSMDATA4`) at `$C296`,
verify its `$C33D=$00` overlay signature, and only then enter the same gameplay
ready state. Run both gates with
`make smoke-level-playtest CONTENT_PROFILE=ann_fds PLAYTEST_THEME=Night` and
`make smoke-level-playtest CONTENT_PROFILE=ann_fds PLAYTEST_BANK=extended PLAYTEST_AREA=castle_1 PLAYTEST_THEME=Night`.
Vs. playtesting uses its distinct arcade mode tree: title readiness is
task 4, operating mode 2 is gameplay, and gameplay readiness is task 4. These
values belong to the profile manifest rather than the shared Lua workflow.

SMB2 point playtesting preserves the engine's disk-overlay boundary. Worlds
1-4 enter directly from `SM2MAIN`; Worlds 5-8 load `SM2DATA2`, World 9 loads
`SM2DATA3`, and Worlds A-D load `SM2DATA4` before the selected world, area, and
entrance are restored. Representative loader paths can be checked with:

```
make smoke-level-playtest CONTENT_PROFILE=smb2_jp_fds PLAYTEST_AREA=ground_12
make smoke-level-playtest CONTENT_PROFILE=smb2_jp_fds PLAYTEST_AREA=ground_25 PLAYTEST_THEME=Night
make smoke-level-playtest CONTENT_PROFILE=smb2_jp_fds PLAYTEST_BANK=hard PLAYTEST_AREA=ground_1 PLAYTEST_THEME=Night
```

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
`make build-content` to create `build/content/<profile>/smb.nes` for cartridge
profiles or `build/content/fds_smb/smb.fds` for FDS SMB1, or
`make run-content` to build it and open it in the configured FCEUX executable.
The source tree and preservation outputs are never modified. A machine-readable
byte-difference report is written beside the content build. PC10 composition
retains its private 8 KiB trailing payload; PAL uses its own 1,522-byte authored
music range and exact regional program data. FDS SMB1 resolves authored ranges
against its `$6000` program load address. Its builder verifies an ignored,
zeroed private disk template, writes the 32 KiB `SMMAIN` program into file IDs 3
and 4, and writes the editable 8 KiB CHR into file ID 2. The template, retained
CHR, and completed 65,500-byte disk side each have independent manifest hashes.
ANN composition writes `NSMMAIN`, `NSMDATA2`, `NSMDATA3`, and `NSMDATA4` back to
their original FDS records. Logical course documents gather streams through the
source-built address tables and scatter edits back to their manifest-owned
payloads; the unmodified build reproduces the complete disk side exactly.
SMB2 composition follows the same container discipline while retaining its
sibling-engine formats. It writes `SM2MAIN`, `SM2DATA2`, `SM2DATA3`, and
`SM2DATA4` to their original records, validates each payload's load address,
size, and SHA-1, and reproduces the 65,500-byte disk side with SHA-1
`20e50128742162ee47561db9e82b2836399c880c` when no edits are present.
Vs. composition retains its exact 16-byte header, 32 KiB source-built PRG, and
16 KiB CHR. Graphics Studio edits only the first 8 KiB pattern-table bank. The
second bank holds the arcade level data: Level Studio derives all 39 area and 39
enemy stream boundaries from the selected PRG's pointer tables, then writes the
encoded streams back into that bank without exposing code as binary content.
World and Sound Studios use the Vs.-specific routing and 27 emitted music
headers. A zero-edit build reproduces the complete 49,168-byte image exactly.

`make check-studios` initializes missing local files and checks all four models
without opening windows. The lower-level init, export, validate, and build
commands accept `STUDIO=world`, `STUDIO=level`, `STUDIO=graphics`, or
`STUDIO=sound`.

`make check-content-profiles` performs an isolated export, constructs every
supported Studio model, and rebuilds JU, PC10, PAL, Vs. SMB, FDS SMB1, ANN, and
SMB2 with zero edits. It rejects any image whose size or SHA-1
differs from the selected profile baseline. Its temporary workspaces live under
`build/content_roundtrip/` and never overwrite local authoring work.

The ignored `references/` directory may contain local research checkouts. The
editors were implemented independently from the documented SMB1 formats. No
third-party editor source is incorporated into the tracked project. The reviewed
projects and reuse boundaries are recorded in `docs/editor_references.md`.

The immutable 1.0 round-trip manifest remains `config/data_formats.json`.
`config/content_formats.json` layers complete level streams, the full vanilla
music bank, all metatiles, complete game text, and area palette packets over it
without changing the accepted 1.0 evidence count.
