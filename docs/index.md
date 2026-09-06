# Documentation Index

This index is the starting point for the repository's preservation, source,
runtime-evidence, and authoring documentation. Contributors should also read
[`CONTRIBUTING.md`](../CONTRIBUTING.md) before changing emitted bytes or release
contracts.

## Releases and Project Direction

- [`preservation_source_1_0.md`](preservation_source_1_0.md) — stable preservation baseline and acceptance boundary.
- [`source_reconstruction_2_0.md`](source_reconstruction_2_0.md) — 2.0 source-reconstruction contract.
- [`source_reconstruction_3_0.md`](source_reconstruction_3_0.md) — active 3.0 contract, milestones, and aggregate gate.
- [`roadmap.md`](roadmap.md) — completed work, remaining work, and project policy.
- [`smb2_reconstruction.md`](smb2_reconstruction.md) — Super Mario Bros. 2 FDS reconstruction scope.
- [`later_engine_feasibility.md`](later_engine_feasibility.md) and [`later_engine_source_overlap.md`](later_engine_source_overlap.md) — later-engine evidence and source-overlap analysis.

## Source Architecture

- [`source_layout.md`](source_layout.md) — address-ordered module map and linker boundaries.
- [`subsystems.md`](subsystems.md) — runtime ownership and subsystem interactions.
- [`ram_fields.md`](ram_fields.md) — verified RAM symbol registry.
- [`naming.md`](naming.md) — semantic symbol vocabulary and evidence rules.
- [`assembly_style.md`](assembly_style.md) — mechanically checked assembly conventions.
- [`6502_reference.md`](6502_reference.md) — local 6502 instruction reference.
- [`unknowns.md`](unknowns.md) — unresolved and closed evidence records.
- [`provenance/README.md`](provenance/README.md) — provenance manifests and label history.
- [`licensing.md`](licensing.md) — licensing and distribution status for source, tools, and private inputs.

## Builds, Profiles, and Debugging

- [`revision_profiles.md`](revision_profiles.md) — cartridge revision matrix.
- [`platform_profiles.md`](platform_profiles.md) — NES, Vs. System, and FDS profiles.
- [`expanded_rom.md`](expanded_rom.md) — expanded-ROM architecture.
- [`fixed_layout_variants.md`](fixed_layout_variants.md) — fixed-address variant contracts.
- [`relocation_testing.md`](relocation_testing.md) — relocation generation and runtime proof.
- [`debugger_workflow.md`](debugger_workflow.md) — Mesen/FCEUX symbols, watches, and breakpoints.
- [`adr/0001-expanded-rom-architecture.md`](adr/0001-expanded-rom-architecture.md) — expanded-ROM architecture decision.

## Runtime Evidence and Gameplay

- [`runtime_evidence.md`](runtime_evidence.md) — deterministic gameplay and semantic traces.
- [`scoring_runtime.md`](scoring_runtime.md) — score, coin, extra-life, HUD, and top-score transaction contract.
- [`player_movement.md`](player_movement.md) — input, physics, collision, and movement traces.

## Content Authoring

- [`content_authoring.md`](content_authoring.md) — authored-content workflow and profiles.
- [`data_formats.md`](data_formats.md) — typed codecs and byte-identical round trips.
- [`editor_references.md`](editor_references.md) — editor behavior and model references.
- [`modding_examples.md`](modding_examples.md) — practical source modifications.

## Tool Layout

Python tools are grouped under `scripts/build/`, `scripts/validation/`,
`scripts/runtime/`, `scripts/authoring/`, and `scripts/workflow/`. Make targets
are the public interface. For direct tool execution, use the stable launcher:

```text
python scripts/run.py <category.module> [arguments ...]
```
