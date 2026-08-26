# NES 6502 Instruction Reference

This is a compact reference for the Ricoh 2A03/2A07 CPU used by the NES. It
covers the documented NMOS 6502 instruction set and the ca65 operand syntax used
by this reconstruction.

The original `6502jsm.txt` imported with the project is preserved in Git commit
`052aa23781fe028d8d7d2627638a87326107c015`. It was replaced because its opcode
coverage was incomplete and several flag descriptions were inaccurate.

## NES CPU Notes

- The 2A03/2A07 implements the NMOS 6502 instruction set without decimal
  arithmetic. `SED` and `CLD` change the decimal flag, but `ADC` and `SBC`
  always perform binary arithmetic on the NES.
- The stack occupies `$0100..$01FF`. The eight-bit stack pointer grows downward
  on pushes and upward on pulls.
- Zero-page indexed addressing wraps within `$0000..$00FF`.
- NMOS `JMP ($xxFF)` reads the high destination byte from `$xx00`, not from the
  next page. Avoid indirect vectors that cross this boundary.
- A taken branch costs an extra cycle; crossing a page costs one more. Indexed
  reads may also pay a page-crossing cycle, while stores use their fixed timing.
- Read-modify-write instructions perform memory bus writes as part of their
  operation. Treat their use on PPU/APU/I/O registers with care.
- This reference lists official opcodes only. Undocumented opcodes are outside
  the preservation source convention.

## Status Register

```text
bit  7 6 5 4 3 2 1 0
     N V 1 B D I Z C
```

| Flag | Meaning |
| --- | --- |
| `N` | Negative; copies bit 7 of the result |
| `V` | Signed overflow |
| `B` | Break marker in a pushed status byte; not a persistent CPU latch |
| `D` | Decimal-mode request; arithmetic ignores it on the NES |
| `I` | Maskable interrupt disable |
| `Z` | Zero result |
| `C` | Carry, no-borrow, or shifted-out bit |

The flags column below lists flags written by an instruction. A dash means that
the instruction does not change status flags.

## Addressing Syntax

| Mode | ca65 example | Meaning |
| --- | --- | --- |
| Implied | `CLC` | Operand is implied by the instruction |
| Accumulator | `ASL A` | Operate directly on `A` |
| Immediate | `LDA #$20` | Use the following byte as a value |
| Zero page | `LDA $20` | Read or write `$0020` |
| Zero page,X | `LDA $20,x` | Add `X`, wrapping within zero page |
| Zero page,Y | `LDX $20,y` | Add `Y`, wrapping within zero page |
| Absolute | `LDA $8123` | Use a 16-bit address |
| Absolute,X | `LDA $8123,x` | Add `X` to a 16-bit base address |
| Absolute,Y | `LDA $8123,y` | Add `Y` to a 16-bit base address |
| Indexed indirect | `LDA ($20,x)` | Add `X` before reading a zero-page pointer |
| Indirect indexed | `LDA ($20),y` | Read a zero-page pointer, then add `Y` |
| Indirect | `JMP ($8123)` | Read the destination address from memory |
| Relative | `BNE bra_loop` | Signed branch displacement from the next PC |

## Instruction Semantics

| Instruction | Operation | Flags |
| --- | --- | --- |
| `ADC` | `A = A + M + C` | `N Z C V` |
| `AND` | `A = A AND M` | `N Z` |
| `ASL` | Shift left; bit 7 enters `C`, zero enters bit 0 | `N Z C` |
| `BCC` | Branch if `C = 0` | - |
| `BCS` | Branch if `C = 1` | - |
| `BEQ` | Branch if `Z = 1` | - |
| `BIT` | Test `A AND M`; copy memory bits 7 and 6 to `N` and `V` | `N V Z` |
| `BMI` | Branch if `N = 1` | - |
| `BNE` | Branch if `Z = 0` | - |
| `BPL` | Branch if `N = 0` | - |
| `BRK` | Push return state and enter the IRQ/BRK vector | `I` |
| `BVC` | Branch if `V = 0` | - |
| `BVS` | Branch if `V = 1` | - |
| `CLC` | Clear carry | `C` |
| `CLD` | Clear decimal request | `D` |
| `CLI` | Clear interrupt disable | `I` |
| `CLV` | Clear overflow | `V` |
| `CMP` | Compare `A - M` without storing the result | `N Z C` |
| `CPX` | Compare `X - M` without storing the result | `N Z C` |
| `CPY` | Compare `Y - M` without storing the result | `N Z C` |
| `DEC` | `M = M - 1` | `N Z` |
| `DEX` | `X = X - 1` | `N Z` |
| `DEY` | `Y = Y - 1` | `N Z` |
| `EOR` | `A = A XOR M` | `N Z` |
| `INC` | `M = M + 1` | `N Z` |
| `INX` | `X = X + 1` | `N Z` |
| `INY` | `Y = Y + 1` | `N Z` |
| `JMP` | Replace `PC` with the destination | - |
| `JSR` | Push the return address and jump to a subroutine | - |
| `LDA` | `A = M` | `N Z` |
| `LDX` | `X = M` | `N Z` |
| `LDY` | `Y = M` | `N Z` |
| `LSR` | Shift right; bit 0 enters `C`, zero enters bit 7 | `N Z C` |
| `NOP` | No operation | - |
| `ORA` | `A = A OR M` | `N Z` |
| `PHA` | Push `A` | - |
| `PHP` | Push status with the break marker set | - |
| `PLA` | Pull `A` | `N Z` |
| `PLP` | Pull status | `N V D I Z C` |
| `ROL` | Rotate left through `C` | `N Z C` |
| `ROR` | Rotate right through `C` | `N Z C` |
| `RTI` | Pull status and `PC` after an interrupt | `N V D I Z C` |
| `RTS` | Pull a subroutine return address and advance it | - |
| `SBC` | `A = A - M - (1 - C)` | `N Z C V` |
| `SEC` | Set carry | `C` |
| `SED` | Set decimal request; arithmetic remains binary on NES | `D` |
| `SEI` | Set interrupt disable | `I` |
| `STA` | `M = A` | - |
| `STX` | `M = X` | - |
| `STY` | `M = Y` | - |
| `TAX` | `X = A` | `N Z` |
| `TAY` | `Y = A` | `N Z` |
| `TSX` | `X = SP` | `N Z` |
| `TXA` | `A = X` | `N Z` |
| `TXS` | `SP = X` | - |
| `TYA` | `A = Y` | `N Z` |

## Opcode Tables

All opcode values are hexadecimal. A dash means that the addressing mode is not
available for that instruction.

### ALU, Load, Store, and Compare

| Instruction | `#imm` | `zp` | `zp,X` | `zp,Y` | `abs` | `abs,X` | `abs,Y` | `(zp,X)` | `(zp),Y` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ADC` | `69` | `65` | `75` | - | `6D` | `7D` | `79` | `61` | `71` |
| `AND` | `29` | `25` | `35` | - | `2D` | `3D` | `39` | `21` | `31` |
| `BIT` | - | `24` | - | - | `2C` | - | - | - | - |
| `CMP` | `C9` | `C5` | `D5` | - | `CD` | `DD` | `D9` | `C1` | `D1` |
| `CPX` | `E0` | `E4` | - | - | `EC` | - | - | - | - |
| `CPY` | `C0` | `C4` | - | - | `CC` | - | - | - | - |
| `EOR` | `49` | `45` | `55` | - | `4D` | `5D` | `59` | `41` | `51` |
| `LDA` | `A9` | `A5` | `B5` | - | `AD` | `BD` | `B9` | `A1` | `B1` |
| `LDX` | `A2` | `A6` | - | `B6` | `AE` | - | `BE` | - | - |
| `LDY` | `A0` | `A4` | `B4` | - | `AC` | `BC` | - | - | - |
| `ORA` | `09` | `05` | `15` | - | `0D` | `1D` | `19` | `01` | `11` |
| `SBC` | `E9` | `E5` | `F5` | - | `ED` | `FD` | `F9` | `E1` | `F1` |
| `STA` | - | `85` | `95` | - | `8D` | `9D` | `99` | `81` | `91` |
| `STX` | - | `86` | - | `96` | `8E` | - | - | - | - |
| `STY` | - | `84` | `94` | - | `8C` | - | - | - | - |

### Shift and Memory Update

| Instruction | `A` | `zp` | `zp,X` | `abs` | `abs,X` |
| --- | ---: | ---: | ---: | ---: | ---: |
| `ASL` | `0A` | `06` | `16` | `0E` | `1E` |
| `DEC` | - | `C6` | `D6` | `CE` | `DE` |
| `INC` | - | `E6` | `F6` | `EE` | `FE` |
| `LSR` | `4A` | `46` | `56` | `4E` | `5E` |
| `ROL` | `2A` | `26` | `36` | `2E` | `3E` |
| `ROR` | `6A` | `66` | `76` | `6E` | `7E` |

### Branch

| Instruction | Condition | Relative opcode |
| --- | --- | ---: |
| `BCC` | `C = 0` | `90` |
| `BCS` | `C = 1` | `B0` |
| `BEQ` | `Z = 1` | `F0` |
| `BMI` | `N = 1` | `30` |
| `BNE` | `Z = 0` | `D0` |
| `BPL` | `N = 0` | `10` |
| `BVC` | `V = 0` | `50` |
| `BVS` | `V = 1` | `70` |

### Jump, Interrupt, and Return

| Instruction | Mode | Opcode |
| --- | --- | ---: |
| `BRK` | Implied | `00` |
| `JMP` | Absolute | `4C` |
| `JMP` | Indirect | `6C` |
| `JSR` | Absolute | `20` |
| `RTI` | Implied | `40` |
| `RTS` | Implied | `60` |

### Implied and Stack

| Instruction | Opcode | Instruction | Opcode | Instruction | Opcode |
| --- | ---: | --- | ---: | --- | ---: |
| `CLC` | `18` | `CLD` | `D8` | `CLI` | `58` |
| `CLV` | `B8` | `SEC` | `38` | `SED` | `F8` |
| `SEI` | `78` | `DEX` | `CA` | `DEY` | `88` |
| `INX` | `E8` | `INY` | `C8` | `NOP` | `EA` |
| `PHA` | `48` | `PHP` | `08` | `PLA` | `68` |
| `PLP` | `28` | `TAX` | `AA` | `TAY` | `A8` |
| `TSX` | `BA` | `TXA` | `8A` | `TXS` | `9A` |
| `TYA` | `98` | | | | |

## Common Flag Patterns

- Clear `C` before addition when there is no incoming carry.
- Set `C` before subtraction when there is no incoming borrow.
- `CMP`, `CPX`, and `CPY` set `C` when the register is greater than or equal to
  the operand in an unsigned comparison.
- Signed comparisons require reasoning about `N` and `V`; `N` alone is not a
  complete signed less-than result after arbitrary arithmetic.
- Loads and transfers that write a register usually update `N` and `Z`; stores
  and `TXS` do not.
- `BIT` is useful for testing memory without changing `A`, but its `N` and `V`
  outputs come directly from memory bits 7 and 6.
