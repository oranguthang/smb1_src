# Contributing to the SMB1 Preservation Source

This repository treats the original Super Mario Bros. PRG instruction stream,
layout, data, and timing as a preservation reference. Read
`docs/preservation_source_1_0.md` before changing emitted bytes.

## Local Inputs

Use a legally obtained ROM matching SHA-1
`ea343f4e445a9050d4b4fbac2c77d0693b1d0922`. Run `make split` once to create
the ignored header and CHR files. Never add ROM, CHR, header, object, PRG, or
files under `assets/generated/` to Git. The tracked FM2 is controller input and
contains no game payload.

## Source Changes

Start with `docs/source_layout.md` to find the owning module and
`docs/subsystems.md` to understand its callers and state. Preserve address order
in `src/main.asm`. Keep procedures and their owned small tables together; do not
split files merely to reduce line counts.

Use the vocabulary in `docs/naming.md` and the mechanically checked formatting
in `docs/assembly_style.md`. Source comments and documentation are English.
Uncertain interpretations must use an evidence tag and a stable entry in
`docs/unknowns.md`; do not turn a plausible guess into an unqualified fact.
`make lint` also requires exactly one final newline and rejects trailing
whitespace across every tracked text file, including this guide.

For each coherent source change:

```bash
make format
make test
make verify
```

`make format` performs only safe mechanical normalization and then runs lint.
Review semantic names, comments, contracts, and data changes manually.

## Data Changes

Before editing a packed format, read `docs/data_formats.md`. Add or extend one
decoder/encoder and its focused tests when a format is not yet represented.
Run `make roundtrip-formats`; generated JSON under `build/` is inspection output
and must not become a second source of truth.

## Runtime Evidence

Use `make symbols` for Mesen/FCEUX navigation and `make trace-runtime` for
gameplay transactions. Natural input evidence and controlled patches are not
interchangeable. Every controlled RAM mutation belongs in the scenario manifest
and must appear in the captured trace with its old value, new value, and reason.

Run `make trace` after changing control flow, state machines, timing-sensitive
logic, debugger symbols, or scenario-owned RAM. Update exact event frames only
when the preservation ROM is still byte-identical and the evidence change is
understood.

## Preservation Gate

Before proposing a preservation-source change, run:

```bash
make release-check
```

This runs lint, all unit tests, data round trips, complete-ROM verification,
live debugger/runtime evidence, and the 1.0 release-contract audit. A future ROM
hack must use a separate entrypoint and output; weakening `make verify` or
silently changing the preservation profile is not an acceptable shortcut.

## Commits and Draft History

Commit messages are written in English. Use a concise, descriptive title and
two or three body paragraphs that explain the change, its evidence, and any
important boundary; a title alone is not sufficient. When Codex participated,
finish with the exact trailer:

```text
Co-Authored-By: Codex <noreply@openai.com>
```

Draft commits may be combined, split, reordered, or renamed before publication,
but history is never rewritten directly on checked-out `main`. Create a
`rewrite/<topic>` branch from an immutable base, preserve the old refs, and show
the human owner the proposed old-to-new commit map before rewriting. Moving
`main`, replacing a tag, and pushing with `--force-with-lease` require a second,
explicit owner approval after review and all gates pass.

Dates in rewritten history must remain truthful. A combined commit receives an
AuthorDate and CommitDate within the inclusive interval covered by the commits
it replaces. After the rewrite, verify separately that author and committer
dates increase in parent order, compare old and new trees when only metadata was
intended to change, and rerun every applicable aggregate gate.
