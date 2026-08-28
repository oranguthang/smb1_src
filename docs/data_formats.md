# Authored Data Formats and Round Trips

`make roundtrip-formats` validates reversible binary codecs over representative
data emitted by the preservation source. The command builds the PRG, resolves
tracked start/end labels, slices exact bytes, decodes them into structured JSON,
encodes that structure again, and requires byte-for-byte equality.

The generated inspection document is `build/data_formats.json`. It is local and
ignored. The command never rewrites ASM, editable source documents, ROM assets,
or the manifest.

## Manifest

`config/data_formats.json` owns each artifact's source file, linker-label
boundaries, codec, and any structural lengths that are not encoded in the data
itself. A missing boundary, invalid source path, malformed stream, unconsumed
byte, or first round-trip difference is a hard failure.

The current manifest covers ten artifacts across every milestone-8 family:

| Artifact | Format contract |
| --- | --- |
| World area pointers | Per-world lists; bits 6-5 select area type, bits 4-0 select the typed area index, and bit 7 is preserved explicitly |
| Ground area 3-3 | Two-byte area header, two-byte object records, `$FD` terminator |
| World 1-1 enemies | Two-byte enemy/page records, three-byte row-14 entrance records, `$FF` terminator |
| Palette-3 metatiles | Four pattern-table tile indexes per 2x2 metatile |
| Top status bar | Address/control/payload PPU packets, repeat and vertical flags, `$FF` block terminator |
| Player animation tiles | Eight tile slots per four-row player frame; `$FC` remains an explicit hidden-tile value |
| Star/cloud music header | Length-table offset, little-endian stream pointer, per-channel offsets |
| Star/cloud music channels | Typed square-2, square-1, triangle, and noise byte events with manifest-owned channel boundaries |
| Swim/stomp envelope | Duty, envelope mode, and volume nibble for every APU step |
| Player physics profiles | Named signed/unsigned gravity, initial velocity, speed-limit, friction, and climbing tables |

## Level Streams

Area headers expose timer, entrance, foreground/color, style, background, and
terrain fields. Each following pair retains the screen column, row, page-advance
bit, and seven-bit object control. Encoding reconstructs the packed bytes and
the `$FD` terminator rather than retaining an opaque copy.

Enemy streams use the first byte's low nibble to distinguish ordinary records,
row-15 page controls, and row-14 three-byte entrances. Entrance records expose
the destination area pointer, world selector, and page. Other records expose
hard-mode and page-advance bits plus the six-bit object/page value.

## Rendering and PPU Data

PPU packet control bit 7 selects vertical increment, bit 6 repeats one payload
byte, and bits 5-0 hold the transfer length. Non-repeat packets carry exactly
that many bytes. Fixed metatile and player-frame record sizes are structural
properties in the manifest, so a shifted table boundary fails instead of
silently producing a partial record.

## Audio and Tuning Data

Music decoding preserves the distinct channel grammars documented in
`src/audio/music_data.asm`: square-2/triangle note versus length bytes and the
split length/note or length/beat fields used by square 1 and noise. Address-
bearing headers remain ASM, while `src/audio/music_streams.asm` retains every
semantic boundary around the ignored profile-specific data packs. Channel
lengths are declared because the original header stores offsets, not a uniform
delimiter for every channel.

Signed physics bytes decode to negative integers and encode through two's
complement. Unsigned fractional forces remain `$00..$FF`. This makes generated
JSON useful for inspection without changing how the preservation build owns or
emits the tuning tables.

## Validation

```bash
make roundtrip-formats  # Build and round-trip all manifest artifacts
make test               # Exercise codec semantics and malformed boundaries
make verify             # Independently require the original complete ROM
```

Adding a format requires a narrow decoder and encoder, an exact source-owned
range, a unit test for its semantic fields, and a successful preservation build.
