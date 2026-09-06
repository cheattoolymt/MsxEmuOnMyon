# MsxEmuOnMyon

MSX1 emulator written in [Myon](https://github.com/TeamMyonlang/Myon).

## Progress

| Step | Contents | Status |
|---|---|---|
| Step 1 | Memory (64KB) + Z80 register / flag skeleton | **done** |
| Step 2 | Z80 instruction core (LD / arithmetic / jump / call / stack / HALT) | not started |
| Step 3 | CB & ED prefixes, DJNZ, `run()` | not started |
| Step 4 | VDP TMS9918A (VRAM, R0-R7, ports $98/$99) | not started |
| Step 5 | Integration demos | not started |
| Step 6 | SDL2 via FFI + C-BIOS boot | not started |

Steps are implemented strictly in order; nothing beyond Step 1 is written yet.

## Files

```
msx.myon    the emulator (currently Appendix A bit helpers + Memory + Z80 + Step 1 self-test)
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

`msx.myon` ends with 31 assertions covering memory sizing/masking/wrapping,
all four register pairs, every flag bit position, and the reset state.

```
--- Step 1: Memory ---
  ok   memory size: 65536
  ...
--- Step 1: register pairs ---
B=18 C=52
  ...
--- Step 1: flags ---
Z=1
  ...
=== Step 1 result ===
all 31 checks passed
```
