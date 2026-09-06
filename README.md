# MsxEmuOnMyon

MSX1 emulator written in [Myon](https://github.com/TeamMyonlang/Myon).

## Progress

| Step | Contents | Status |
|---|---|---|
| Step 1 | Memory (64KB) + Z80 register / flag skeleton | **done** |
| Step 2 | Z80 instruction core (LD / arithmetic / jump / call / stack / HALT) | **done** |
| Step 3 | CB & ED prefixes, DJNZ, `run()` | not started |
| Step 4 | VDP TMS9918A (VRAM, R0-R7, ports $98/$99) | not started |
| Step 5 | Integration demos | not started |
| Step 6 | SDL2 via FFI + C-BIOS boot | not started |

Steps are implemented strictly in order; nothing beyond Step 2 is written yet.
Opcodes that belong to a later Step (`CB`/`ED`/`DD`/`FD` prefixes, `DJNZ`,
`RST`, `EX`/`EXX`, `DI`/`EI`, the accumulator ops `RLCA`/`DAA`/`SCF`/…)
are reported as `[UNIMPL] 0x.. at PC=0x....` and consume 4 cycles, so it
stays obvious what is still missing instead of failing silently.

## Files

```
msx.myon    the emulator (Appendix A bit helpers + Memory + Z80 + instruction core + self-tests)
run.sh      clones & builds Myon if needed, then runs msx.myon
```

## Build & run

The Myon interpreter is not vendored here. `run.sh` fetches and builds it
on demand (requires a C compiler and OpenSSL headers, e.g.
`sudo apt-get install build-essential libssl-dev`).

```sh
./run.sh
```

Or manually:

```sh
git clone https://github.com/TeamMyonlang/Myon
cd Myon && make && cd ..
./Myon/myon msx.myon
```

## Step 1 details

### Memory

* flat `myon.array(int)` of 65536 elements, all zero (MSX slot/mapper
  mechanics are intentionally simplified away for now)
* `read(addr)` / `write(addr, val)` mask the address with `mask16` and the
  value with `mask8`, so out-of-range accesses wrap like the real bus

### Z80

Register set as documented in the Zilog Z80 CPU User Manual (UM0080):

* 8-bit main registers `a f b c d e h l`
* 16-bit registers `ix iy sp pc`
* interrupt control `iff1 iff2 im`
* emulator bookkeeping `halted cycles`

The alternate register set (`AF' BC' DE' HL'`) and the `I` / `R` registers
exist on real hardware but are not needed until `EX` / `EXX` and the
interrupt modes are implemented, so they are left for a later Step.

Register pairs are accessed with top-level functions
(`get_bc`/`set_bc`, `get_de`/`set_de`, `get_hl`/`set_hl`, `get_af`/`set_af`)
rather than methods, because Myon struct methods form a scope boundary
while a struct passed as an argument stays mutable.

### Flag register F

Bit layout confirmed against the Z80 flag documentation
(z80.info "Z80 Flag Affection" / UM0080):

| bit | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|---|---|---|
| flag | S | Z | F5 | H | F3 | P/V | N | C |

* `S` sign — copy of the result MSB
* `Z` zero — result is zero
* `F5` undocumented — copy of result bit 5
* `H` half carry — carry from bit 3 into bit 4
* `F3` undocumented — copy of result bit 3
* `P/V` parity (even number of set bits) or two's-complement overflow
* `N` add/subtract — set when the last operation was a subtraction
* `C` carry — result did not fit in the register

Accessors: `get_flag_x(cpu)` / `set_flag_x(cpu, v)` for
`c n pv f3 h f5 z s`.

### Bit operation helpers

Myon has no bit operators (`& | ^ ~ << >>`), so Appendix A of the
specification is pasted verbatim at the top of `msx.myon`:
`bit_and` `bit_or` `bit_xor` `shl` `shr` `mask8` `mask16` `hi8` `lo8`
`bit_not8` `bit_not16` `get_bit` `set_bit`.

### Self-test output

Step 1 contributes 31 assertions covering memory sizing/masking/wrapping,
all four register pairs, every flag bit position, and the reset state.

## Step 2 details

### Decoding

Instructions are decoded from the opcode's octal structure, which is how
the real Z80 decodes them (per [Decoding Z80 Opcodes](http://www.z80.info/decoding.htm)),
rather than as a flat 256-way `if` chain:

```
bit :  7  6 | 5  4  3 | 2  1  0
       x    |    y    |    z        p = y >> 1 (bits 5-4)
                                    q = y  & 1 (bit 3)
```

| `x` | meaning |
|---|---|
| 0 | relative jumps, 16-bit load/add, INC/DEC, 8-bit load immediate |
| 1 | `LD r[y], r[z]` — with `HALT` carved out of `LD (HL),(HL)` |
| 2 | `alu[y] r[z]` |
| 3 | conditional flow, stack, immediate ALU, prefixes |

The lookup tables are implemented as `get_r`/`set_r` (`B C D E H L (HL) A`),
`get_rp`/`set_rp` (`BC DE HL SP`), `get_rp2`/`set_rp2` (`BC DE HL AF`),
`test_cc` (`NZ Z NC C PO PE P M`) and `alu_apply`
(`ADD ADC SUB SBC AND XOR OR CP`). Because one table entry is `(HL)`,
every register-operand instruction gets its memory form for free.

### Implemented in this Step

`NOP` · `LD r,n` · `LD r,r'` · `LD r,(HL)` / `LD (HL),r` / `LD (HL),n` ·
`LD A,(BC)` / `LD A,(DE)` / `LD (BC),A` / `LD (DE),A` ·
`LD A,(nn)` / `LD (nn),A` · `LD HL,(nn)` / `LD (nn),HL` ·
`LD rp,nn` · `ADD/ADC/SUB/SBC/AND/XOR/OR/CP` (register, `(HL)` and
immediate forms) · `INC/DEC r` · `INC/DEC rp` · `ADD HL,rp` ·
`JP nn` / `JP cc,nn` · `JR e` / `JR cc,e` · `CALL nn` / `CALL cc,nn` ·
`RET` / `RET cc` · `PUSH`/`POP` `BC DE HL AF` · `OUT (n),A` / `IN A,(n)` ·
`HALT`.

### Flags

Flag effects follow [Z80 Flag Affection](http://www.z80.info/z80sflag.htm),
including the two undocumented flags F5/F3:

| operation | flags |
|---|---|
| `ADD` / `ADC` / `SUB` / `SBC` | `SZ5H3VNC` |
| `CP r` | `SZ*H*VNC` — F5/F3 come from the **operand**, not the result |
| `INC` / `DEC r` | `SZ5H3VN-` — carry deliberately untouched |
| `AND r` | `SZ513P00` — H is always set |
| `OR` / `XOR r` | `SZ503P00` |
| `ADD HL,ss` | `--***-0C` — F5/H/F3 from the high-byte addition |

`P/V` is parity for the logical ops and signed overflow for the
arithmetic ops, so `overflow_add8` / `overflow_sub8` / `parity8` are
separate helpers.

### Notes on the Myon implementation

* **`wrap8` / `wrap16`** — Appendix A's `bit_and` loops while `a > 0`, so
  `mask8(-1)` returns 0 rather than 0xFF. Subtraction, `DEC` and a
  backwards `JR` all produce negative intermediates, so these wrappers
  bring a value into range before masking. Appendix A itself is left
  unmodified as instructed.
* **`signed8`** — `JR`/`JR cc` displacements are two's complement, so
  a byte above 127 becomes `byte - 256`.
* **`hex8` / `hex16`** — the specification's `[UNIMPL] 0x{str(op)}`
  template prints decimal after a `0x` prefix, which would label opcode
  `0x10` as "0x16". Since opcodes are only ever read as hex, that label
  would actively mislead debugging, so the message is formatted properly.
* **`myon.elif` placement** — the parser only accepts `myon.elif` on the
  same line as the preceding `}`. Where a chain would need its own lines,
  short-circuiting `myon.if ... { ...  ret }` blocks are used instead.
* **`str` has no methods** — string assertions compare values directly
  rather than calling `.length()`.
* **Cycle counts** are the plain Z80 timings from the
  [MSX Assembly Page instruction table](https://map.grauw.nl/resources/z80instr.php);
  the MSX M1 wait states are not added yet.

### Verification

The specified acceptance program is checked first:

```
0x3E 0x05   LD A, 5
0x06 0x03   LD B, 3
0x80        ADD A, B
0x76        HALT
```

```
--- Step 2: the specified test program ---
A=8 Z=0 C=0
  ok   A after ADD A,B: 8
  ok   flag Z: 0
  ok   flag C: 0
```

On top of that, Step 2 adds coverage for every instruction group above —
loads, memory loads, 16-bit loads, INC/DEC, `ADD HL`, all eight ALU ops
(carry, half carry, signed overflow, borrow), taken and not-taken
`JP cc` / `CALL cc` / `RET cc`, a backwards `JR NZ` loop, `PUSH AF` /
`POP` round trips with the flag byte, `OUT`/`IN`, and `HALT`. Six
assertions compare the **entire F byte** against hand-computed values
(e.g. `0x00 - 0x01` must leave `F = 0xBB`) so a single wrong flag bit
cannot hide behind a test that only inspects one flag.

```
=== Step 1 + Step 2 result ===
all 133 checks passed
```
