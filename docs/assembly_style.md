# Assembly Style

The native source uses one deliberately small, mechanically checked ca65 style.
It follows the visual conventions used by the Pac-Man reconstruction while
remaining explicit about the few rules that editors cannot enforce.

## Layout

- Use only printable ASCII characters (`0x20` through `0x7E`) and LF line
  endings. Unicode text, typographic punctuation, and non-breaking spaces are
  not allowed in ASM or INC source files.
- End every file with exactly one final newline.
- Do not use tabs or trailing whitespace.
- Do not begin a file with a blank or whitespace-only line.
- Keep at most one blank line between source lines.
- Put every label at column zero on a line of its own.
- Indent instructions and data-emitting directives by four spaces.
- Indent the contents of `.if`, `.repeat`, `.macro`, and similar blocks by an
  additional four spaces for each nested block.
- Keep structural directives such as `.include`, `.segment`, and `.org` at the
  current block depth.
- Use exactly one space between an instruction or directive and its operand.

```asm
.if ENABLE_DEMO
handler_demo_entry:
    LDA #$01  ; Select demo mode
    .repeat 2
        NOP
    .endrepeat
.endif
```

## Case

- Write 6502 mnemonics in uppercase: `LDA`, `JSR`, `RTS`.
- Write ca65 directives in lowercase: `.byte`, `.word`, `.include`, `.segment`.
- Write every colon label with its semantic role prefix in lowercase snake_case;
  see `naming.md` for the accepted prefixes.
- Preserve the declared case of constants and operands.

## Comments

- Write comments and documentation in English. Non-ASCII writing systems are
  rejected with an explicit request for a manual rewrite; the formatter never
  translates or deletes their text.
- Put exactly one space after `;`.
- Put exactly two spaces before an inline comment. Do not align inline comments
  to a shared column.
- Do not put a period at the end of a comment. The formatter removes terminal
  periods, while periods separating multiple sentences inside one comment are
  preserved.
- Prefer comments that explain intent, constraints, or side effects over comments
  that merely restate the instruction.
- Use concise `Inputs`, `Outputs`, `Side effects`, and `Clobbers` notes where a
  routine contract is useful.

```asm
; Wait for two VBlank intervals before continuing reset
bra_wait_for_first_vblank:
    LDA PPU_STATUS
    BPL bra_wait_for_first_vblank

bra_initialize_after_boot_check:
    JSR sub_initialize_memory  ; Clear memory using the pointer in Y
```

## Tooling

Run the style gate without modifying files:

```bash
make lint
```

Apply deterministic whitespace, label-layout, mnemonic-case, and directive-case
normalization, then run the gate again:

```bash
make format
make lint
```

The tooling does not use probabilistic language detection. Printable-ASCII and
non-ASCII-letter checks reliably prevent Cyrillic and other non-ASCII writing
systems, while distinguishing English from another language written entirely in
unaccented Latin characters remains a review responsibility.
