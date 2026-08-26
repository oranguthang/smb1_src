# Fixed-Layout Variants

Fixed-layout variants are explicit, reviewable modifications of the canonical
32 KiB PRG. They retain the NROM-256 layout, original header, and original CHR,
but they are never accepted by the preservation `make verify` contract.

The first demonstrator is `five_lives`. Its separate entrypoint defines
`con_initial_lives` as `$04`; the stored value counts spare lives, so the game
starts with five total lives. The preservation entrypoint defines no variant
flag and retains the original `$02` default.

Use the three independent acceptance layers:

```text
make build-hack
make verify-hack
make validate-hack
```

`build-hack` writes only beneath `build/variants/five_lives`. `verify-hack`
compares both PRG and complete ROM against the preservation build and accepts
only the byte declared in `config/fixed_layout_variants.json`. It therefore also
proves that header and CHR data are unchanged. `validate-hack` plays the tracked
FM2 in FCEUX and observes `ram_numberof_lives` immediately after primary game
setup, proving that the declared operand has the intended runtime effect.

Future fixed-layout variants must use their own source entrypoint and output
directory, declare every changed byte with its original value and reason, and
add a focused runtime observation. They may change constants or tables, or use
space separately proven unused; they must not add feature flags to `src/main.asm`.
