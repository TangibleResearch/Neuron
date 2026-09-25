# Exceptions and undefined behavior

Neuron32 has no trap/exception architecture yet — no trap vector, no
saved-PC-on-fault mechanism, no privilege levels. This document is not
proposing one. Its job is to say, for every condition where real hardware
and Nemu's software reference model could disagree, exactly what Neuron32
RTL currently does and why, classified as one of:

- **Architecturally defined** — both Nemu and the RTL agree, and it's
  intentional.
- **Deliberate hardware deviation** — Nemu does something a real chip
  cannot (usually: panic and stop the whole process), so the RTL
  necessarily does something else. Documented here and in `CHATGPT.md`;
  not a bug.
- **Currently undefined** — behavior exists but nothing has decided it
  should be one specific thing; flagged so it isn't silently relied upon.
- **Future trap/exception work** — needs an ISA-level decision (a trap
  vector, a status bit, something) before it can be implemented at all.

Nothing below invents new ISA behavior. Where a real decision is needed,
it's listed as a blocker in `docs/FABRICATION_READINESS.md`, not decided
here.

## Illegal opcode

**Classification: deliberate hardware deviation (already documented in
CHATGPT.md).**

Nemu: `cpu.rs::step()`'s catch-all match arm `panic!("Unknown Neuron
opcode: {:#04X}", opcode)` — crashes the whole process.

RTL: `rtl/decode.sv` sets `valid=0` for any opcode not in its table;
`rtl/neuron_core.sv` samples that the same cycle it latches the opcode
byte and, if invalid, sets `illegal_opcode <= 1` and moves straight to
`S_HALTED` without ever reaching `S_EXECUTE`. This is the only
architecturally deterministic choice available to real hardware — it
cannot unwind a process. `illegal_opcode` is a chip-level pin
(`rtl/neuron_chip.sv`) specifically so a system integrator can observe
this happened.

## Divide by zero / modulo by zero

**Classification: deliberate hardware deviation (already documented in
CHATGPT.md); no trap mechanism exists to do better.**

Nemu: `src/scalar_alu.rs`'s `div`/`modulo` both `panic!("Neuron
divide-by-zero exception")` / `panic!("Neuron modulo-by-zero exception")`
when the divisor is `0`.

RTL: `rtl/alu.sv`'s `ALU_DIV`/`ALU_MOD` cases return `0` when `b == 0`
(the `result` default before the `case` even runs), with `carry`/
`overflow` both `0` — a plain, deterministic result, not a trap.

**Future trap/exception work.** A real division-by-zero fault needs an
architectural decision this document does not make: does Neuron32 gain a
trap vector at all, and if so, what does it look like for *any* fault,
not just this one? Until that's decided, "returns 0" is the only
implementable behavior. Tracked as a blocker in
`docs/FABRICATION_READINESS.md`.

## Operand fields wider than the value they select

**Classification: deliberate hardware deviation (not previously
documented — found during this hardening pass).**

Every register/matrix-register/row/column selector in the NuASM encoding
occupies a full byte in the instruction stream, but the *valid* range is
much narrower (4 bits for a scalar register 0-15, 2 bits for a matrix
register/row/column 0-3). Nemu validates the full byte and panics on an
out-of-range value:

- `NeuronCpu::read_scalar`/`write_scalar`: `panic!("Invalid Neuron scalar
  register: R{register}")` for `register > 15`.
- `cpu.rs`'s `OP_MSET` arm: explicit `panic!` for `register > 3`, `row >=
  4`, or `column >= 4`.

RTL never sees the full byte at these positions as a range to validate —
it only ever *wires* the bit width it needs (e.g.
`reg_write_sel = operand[0][3:0]` for a scalar register,
`mreg_cell_sel = operand[0][1:0]` for a matrix register). An
out-of-range encoded value (e.g. a corrupted instruction stream encoding
"register 20") silently wraps to the value those low bits happen to
represent (20 = `0b0001_0100` -> low 4 bits `0100` = R4) instead of
trapping. This is the same category of deviation as illegal-opcode and
divide-by-zero above: real combinational decode logic cannot panic.

**Not reachable through normal use.** Nemu's assembler
(`src/assembler.rs::parse_register`) already rejects any out-of-range
register name at assembly time (`.filter(|value| *value <= maximum)`),
so no program `nuasm` can produce ever exercises this path. It only
matters for a hand-crafted or corrupted instruction stream — which is
exactly the class of input `scripts/diff_test.sh`'s random generator
deliberately does *not* produce (see that script's own comments).

## Stack underflow / overflow

**Classification: currently undefined (found during this hardening
pass) — needs an architectural decision, not invented here.**

Nemu: `push_u32`/`pop_u32` (`src/cpu.rs`) use `checked_sub`/`checked_add`
on `sp` and `panic!("Neuron stack underflow")` /
`panic!("Neuron stack pointer overflow")` if `sp` would wrap past `0` or
past `u32::MAX`.

RTL: `sp` is a plain `logic [31:0]` register updated with `sp <= sp -
32'd4` (`PUSH`/`CALL`) or `sp <= sp + 32'd4` (`POP`/`RET`) — ordinary
fixed-width arithmetic that wraps silently on underflow/overflow, with no
detection at all. A `POP`/`RET` past the top of a program's legitimate
stack usage, or enough nested `PUSH`/`CALL` to walk `sp` below `0`
(wrapping to near `0xFFFFFFFF`), does not fault; it just reads/writes
whatever `mem_addr` that wrapped value happens to produce.

This is *not* classified as a deliberate hardware deviation, because
unlike illegal-opcode/divide-by-zero there is no fundamental reason real
hardware couldn't detect this (e.g. compare `sp` against `MEM_SIZE`
before a `PUSH`, or against a lower bound before a `POP`) — nobody has
decided whether it should, or what should happen if it did (halt like an
illegal opcode? a status flag? nothing, because software is expected to
manage its own stack discipline, the same way Nemu's own architecture
sketch has no memory-protection unit?). Flagged as an open architectural
question in `docs/FABRICATION_READINESS.md`, not decided here.

## Memory address outside implemented RAM

**Classification: currently undefined (tool-dependent) — needs an
architectural decision.**

Both `rtl/memory.sv` and `rtl/memory_sync.sv` declare `logic [7:0] bytes
[0:SIZE-1]` and index it with the full 32-bit `addr` the core presents,
with no bounds check anywhere. `SIZE` (`MEM_SIZE` at the core level) is
1024 by convention in every testbench/sim target today, but nothing
architecturally prevents a program from presenting an address `>= 1024`
(the same stack-overflow scenario above can produce one, and so can a bad
`LOAD`/`STORE` address).

In simulation, Verilator's behavior for an out-of-range fixed-size array
index is implementation-defined (reads typically return `0`/X-adjacent,
writes are dropped) and is **not** the same thing as what a synthesis
tool will produce for the same RTL: a synthesized address decoder for a
1024-entry array driven by a wider address signal will very likely (but
is not *guaranteed* by the SystemVerilog written here to) truncate to the
low 10 bits, silently wrapping instead of aliasing to nothing the way
simulation does. This mismatch — simulation vs. synthesis disagreeing on
out-of-range behavior — is exactly the class of problem `scripts/
lint.sh`/`scripts/synth_check.sh` exist to catch structurally, but *this
specific case* isn't a lint/synthesis bug to fix; it's an open question
about what SHOULD happen (wrap? an error response on the bus, which
doesn't exist today per `docs/MEMORY_INTERFACE.md`? a fixed, larger
`MEM_SIZE` that makes the question moot for realistic programs?) that
needs a decision before it can be made deterministic. Tracked in
`docs/FABRICATION_READINESS.md`.

## Misaligned word access

**Classification: architecturally defined (no restriction).**

Neither Nemu (`read_u32`/`write_u32` just slice `memory[addr..addr+4]`)
nor the RTL (`bytes[addr]` through `bytes[addr+3]`, no alignment check
anywhere) restrict word accesses to 4-byte-aligned addresses. A 32-bit
`LOAD`/`STORE` at an odd address is legal on both sides and produces
identical results (same little-endian byte layout). This is a real,
intentional simplicity choice matching Nemu, not an oversight — no
change needed.

## Invalid matrix values fed to MMUL

**Classification: deliberate hardware deviation (already documented in
CHATGPT.md, "MMUL truncates ... Nemu's Rust model instead panics").**

A matrix register cell is a 32-bit signed value; `MSET` can only ever
write an INT8-range value into one (the assembler-checked `parse_i8`
immediate), but `MMUL`'s bulk write-back from a *previous* `MMUL`'s
32-bit accumulated result can leave a cell holding a value outside
INT8 range. Nemu panics (`i8::try_from(...).unwrap_or_else(|_| panic!(...))`)
if a subsequent `MMUL` tries to read such a cell as an operand. RTL
(`neuron_core.sv`'s `mmul_a_tile`/`mmul_b_tile` assignment) instead
truncates to the low 8 bits unconditionally — the only option available
to a fixed combinational systolic array feeding real hardware. `scripts/
diff_test.sh`'s random generator deliberately never chains an MMUL result
register into a later MMUL as a source, for exactly this reason (see that
script's comments) — it's not testing around a bug, it's avoiding the one
input class Nemu cannot execute without crashing.

## HALT / illegal-opcode termination

**Classification: architecturally defined.** See `docs/RESET.md`'s "HALT
is not sticky across reset" and the `halted_r` protocol assertion in
`rtl/neuron_core.sv`. Both HALT and illegal-opcode are terminal
(`S_HALTED`) until `reset`, on both Nemu (`self.halted = true`, checked
at the top of every `step()`) and the RTL.
