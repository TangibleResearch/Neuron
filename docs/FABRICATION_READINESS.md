# Fabrication readiness

Status snapshot from the pre-fabrication RTL hardening pass. Statuses:
**PASS** (evidence below), **FAIL**, **NOT TESTED** (written but not yet
run — see "Local verification blocker"), **REQUIRES FOUNDRY/PDK**,
**ARCHITECTURAL DECISION REQUIRED**.

## Local verification blocker

This pass was done on a macOS machine where the Xcode license has not
been accepted (`sudo xcodebuild -license accept` was started but did not
complete during this session). That blocks **any** C++ compilation —
Verilator's `--binary` mode (needed to actually *run* a testbench, not
just lint it) and even `cargo build`'s linker step for Nemu's own `nuasm`/
`neuron` binaries. It does **not** block Verilator's `--lint-only` mode
(no C++ compiler needed), which is why lint is the one thing with real,
run evidence below. Everything else added in this pass (new testbenches,
`scripts/diff_test.sh`, `scripts/synth_check.sh`) is written, reviewed,
and wired into CI, but **not yet executed locally**. `.github/workflows/
ci.yml`'s `rtl`/`synthesis` jobs run on `ubuntu-latest`, which is
unaffected by this — the next CI run on this branch is the actual first
execution of most of what's below. Do not treat "NOT TESTED" here as
"probably fine" — it means exactly what it says.

## RTL correctness

| Item | Status | Evidence |
|---|---|---|
| `scripts/lint.sh` (Verilator `-Wall`, two documented waivers) | **PASS** | Ran locally: 0 unreviewed warnings across every leaf module standalone, `matrix_engine`+`mac`, full `neuron_core` hierarchy (both memory variants), full `neuron_chip` hierarchy (both pinout configs). |
| Real bugs found and fixed during lint | see below | |
| `tb/run_all.sh` (13 Nemu `.nuasm` programs, zero-latency memory) | **NOT TESTED** locally (blocked); unchanged from pre-pass baseline otherwise | Will run in CI. |
| `tb/run_module_tests.sh` (`alu_tb`, `register_tb`, `clock_tb`, new `matrix_tb`, new `reset_tb`) | **NOT TESTED** locally (blocked) | Will run in CI. |
| `tb/run_delay_tests.sh` (new: 13 programs x 4 memory-timing modes) | **NOT TESTED** locally (blocked) | Will run in CI. |

### Bugs found and fixed this pass

- **`rtl/alu.sv` redeclared `ALU_*` opcode constants locally** instead of
  importing them from `isa_pkg` (the documented single source of truth).
  Values happened to match today, but nothing enforced that — a future
  edit to one copy and not the other would have silently desynced ALU
  operand decoding from `isa_pkg`'s canonical opcodes. Fixed: `alu.sv`
  now imports `isa_pkg::*` and uses the shared constants directly.
- **`rtl/matrix_engine.sv`** compared a 2-bit counter against a 32-bit
  `int` localparam (`k == MATRIX_SIZE - 1`) — functionally correct (both
  sides implicitly widen to compare, and the values in range never
  differ), but a real width mismatch Verilator correctly flagged.
  Fixed with an explicit `2'(MATRIX_SIZE - 1)` cast.
- **`rtl/neuron_core.sv`** declared `state_n` (a next-state signal) that
  was never driven or read — dead code left over from an earlier
  two-process FSM style that was never finished switching over. Removed.
- **`rtl/memory.sv`'s `load_bytes` task** ($readmemh, simulation-only)
  had no synthesis guard — nothing stopped it from being pulled into a
  synthesis run alongside the rest of the file. Now wrapped in
  `` `ifndef SYNTHESIS ``; `rtl/memory_sync.sv` (new) has the same guard
  from the start.
- **Operand-field truncation vs. Nemu's panics** (out-of-range register/
  matrix-register/row/column encodings, stack underflow/overflow) were
  previously undocumented divergences from Nemu, found by reading
  `src/cpu.rs` line-by-line against the RTL's decode paths during this
  pass. See `docs/EXCEPTIONS_AND_UNDEFINED_BEHAVIOR.md` — not fixed
  (most require an architectural decision, not a code change), but now
  explicit instead of silently relied upon.

No other functional bugs were found in the existing scalar ALU, MAC,
matrix engine, or control FSM logic during this audit — the existing
carry/overflow/flag-mode semantics were cross-checked opcode-by-opcode
against `src/scalar_alu.rs`/`src/issuer.rs`/`src/cpu.rs` and match
exactly (see `docs/ISA.md`).

## ISA parity

**PASS** (static cross-check; **NOT TESTED** at runtime — see blocker
above). Every instruction's encoded length was cross-checked between
Nemu's assembler (`src/assembler.rs::OperandLayout::instruction_size`)
and `rtl/decode.sv`'s length table — they agree exactly, opcode for
opcode. Every opcode's flag-update behavior was cross-checked between
`src/cpu.rs`/`src/scalar_alu.rs`/`src/issuer.rs` and
`rtl/neuron_core.sv`'s `flag_mode` selection — they agree exactly. See
`docs/ISA.md`. This is a source-level review, not yet confirmed by
actually running `scripts/diff_test.sh`.

## Verification

| Item | Status |
|---|---|
| `scripts/diff_test.sh` (Nemu vs. RTL, R1-R5/PC/SP/STATUS) | **NOT TESTED** locally (blocked); written, wired into CI against all 13 hand-written programs plus 40 deterministically-seeded random programs |
| `scripts/gen_random_program.py` | Generator itself verified: 200 seeds all assembled successfully via the real `nuasm` (no C++ compilation needed for that). Whether the *programs it generates* produce matching Nemu/RTL results is NOT TESTED locally. |
| `tb/matrix_tb.sv` (MAC/matrix-engine/matrix-regfile hardening: zero/identity/±128/±127 tiles, 32-bit accumulator wraparound, back-to-back MMUL, MMUL-immediately-after-MMUL, `start` held high across a run, reset mid-MMUL, dest==src write-back ordering) | **NOT TESTED** locally (blocked); self-checking, fails the build via `$fatal` on any mismatch |
| `tb/reset_tb.sv` (reset at startup/mid-fetch/mid-execute/mid-memory-wait/mid-MMUL/post-HALT) | **NOT TESTED** locally (blocked); self-checking |
| Assertions (`rtl/neuron_core.sv`, `rtl/matrix_engine.sv`) | **NOT TESTED** at runtime (needs `--assert`, wired into all `tb/*.sh` scripts); confirmed lint-clean |

## Synthesis

| Item | Status |
|---|---|
| `scripts/synth_check.sh` / `synth/synth.ys` | **NOT TESTED** — Yosys is not installed locally (blocked by the same Homebrew/Xcode-license issue) and was not available in this session. Will run in CI's `synthesis` job (installs Yosys via `apt-get` on `ubuntu-latest`). |
| Multi-driver / combinational-loop / undriven-signal detection | Covered structurally by `synth.ys`'s two `check` passes (pre- and post-synthesis) — **NOT TESTED** end-to-end. |
| Cell/register/memory statistics | **NOT TESTED** — no report generated yet. |

## Timing

**ARCHITECTURAL DECISION REQUIRED / REQUIRES FOUNDRY-OR-PDK.**
`constraints/neuron.sdc` exists with a placeholder 50MHz clock
constraint, explicitly labeled as not a frequency claim (see that file).
No STA has been run against any real standard-cell library — none is
available in this environment or committed to this repo (see
`asic/README.md`). **Do not quote a clock frequency for this design
anywhere.**

## Memory

**PASS** (design/lint-level; **NOT TESTED** at runtime — see blocker).
`rtl/memory_sync.sv` (new) implements a configurable per-transaction
`wait_states` input on top of the same generic bus, reproducing
`memory.sv`'s exact zero-latency timing at `wait_states=0` and modeling
real registered-SRAM latency otherwise. `tb/core_delay_tb.sv`/
`tb/run_delay_tests.sh` (new) are written to prove all 13 existing
programs produce identical `OUT` output under fixed 0/1/2-cycle and
randomized 0-3-cycle latency — not yet run. See
`docs/MEMORY_INTERFACE.md` for the full bus contract and the assertions
now enforcing it.

## Reset

**PASS** (design/lint-level; **NOT TESTED** at runtime — see blocker).
Full per-module audit in `docs/RESET.md`; every state-holding element has
an explicit, `reset`-driven value, with no reliance on simulation-only
initial-value inference. `tb/reset_tb.sv` (new) is written to check six
specific reset points (startup, mid-fetch, mid-execute, mid-memory-wait,
mid-MMUL, post-HALT) — not yet run.

## Clocking

**PASS.** One clock domain (`clk`), confirmed by inspection of every
`always_ff` in `rtl/` — no generated/divided clocks, no fabricated PLL
model. `constraints/neuron.sdc` documents this and is ready for a real
library's STA once one is available.

## ASIC flow

**REQUIRES FOUNDRY/PDK for anything past synthesis.** `asic/README.md`
documents the intended RTL -> lint -> synthesis -> STA -> floorplan ->
placement -> CTS -> routing -> DRC -> LVS -> GDSII flow and exactly which
stages this repo currently reaches (lint, generic synthesis) versus which
need a target PDK (everything from STA onward). `asic/openlane/
config.json` is an unvalidated, PDK-agnostic OpenLane skeleton — not a
working flow.

## Physical-design dependencies

**REQUIRES FOUNDRY/PDK.** None committed (deliberately — see
`asic/README.md`): no standard-cell library, no LEF, no liberty timing
views, no DRC/LVS decks, no voltage/process corner data. **No SRAM
macro**: `rtl/memory.sv`/`rtl/memory_sync.sv` are flip-flop-array models,
fine for this design's default 1KB for logic verification and generic
synthesis, but not what a real chip would use for any non-trivial memory
capacity — real SRAM integration is a physical-design-stage task against
a chosen macro, not something addressed by this pass. `rtl/neuron_chip.sv`
deliberately keeps the memory bus as chip pins specifically so this can
be added later without touching the core.

## Outstanding architectural decisions

From `docs/EXCEPTIONS_AND_UNDEFINED_BEHAVIOR.md` — not decided here,
listed as open questions for whoever owns the ISA:

1. **Divide/modulo by zero** — currently returns 0 silently (both Nemu
   and RTL agree it doesn't trap, for different reasons: Nemu panics the
   whole process, which isn't a hardware-realizable behavior). Does
   Neuron32 ever get a trap/exception mechanism, and if so, does this
   opcode class use it?
2. **Stack underflow/overflow** — `SP` wraps silently on both sides
   today (Nemu via `panic!` on `checked_sub`/`checked_add` overflow,
   which again isn't hardware-realizable; RTL via plain wraparound with
   zero detection). Should real hardware detect this at all, and if so,
   what should happen?
3. **Memory address outside implemented RAM** — currently tool-dependent
   (simulation and synthesis are not guaranteed to agree on what an
   out-of-range fixed-array index does). Wrap? An error response on a bus
   that currently has none? A fixed larger `MEM_SIZE` that makes typical
   programs never reach this?

## Known deliberate deviations from Nemu

All documented in detail in `docs/EXCEPTIONS_AND_UNDEFINED_BEHAVIOR.md`
and (originally) `CHATGPT.md`:

1. Illegal opcode halts the core; Nemu panics the process.
2. Divide/modulo by zero returns 0; Nemu panics.
3. MMUL truncates matrix cells to INT8; Nemu panics if a cell doesn't
   fit.
4. Operand fields (register/matrix-register/row/column selectors) wrap
   silently on an out-of-range encoded value; Nemu panics. (Not reachable
   through `nuasm`-assembled programs — the assembler already rejects
   out-of-range register names — found and documented this pass.)
5. `memory.sv` is combinational-read/synchronous-write (a convenience
   simplification); `memory_sync.sv` (new this pass) is the
   fabrication-realistic synchronous-read alternative with configurable
   latency, on the same generic bus, with no core changes required.

## Blockers before tapeout

### 1. RTL/architecture blockers
- The three "outstanding architectural decisions" above are unresolved.
- No trap/exception architecture exists at all; every error condition
  above either silently continues or halts the whole core (no
  fine-grained recovery).

### 2. Verification blockers
- **Nothing added in this pass has actually been executed yet** — see
  "Local verification blocker" above. This is the single biggest gap:
  until CI (or a working local toolchain) actually runs `scripts/
  lint.sh`, `tb/run_all.sh`, `tb/run_module_tests.sh`, `tb/
  run_delay_tests.sh`, `scripts/diff_test.sh`, and `scripts/
  synth_check.sh`, none of the new coverage in this pass is confirmed
  passing — it's reviewed and internally consistent, not proven.
- No gate-level simulation has been attempted (needs a working Yosys
  synthesis run first).

### 3. Physical-design blockers
- No target standard-cell library/PDK selected.
- No SRAM macro integrated (or a decision to keep memory fully external).
- No floorplan, placement, CTS, routing, DRC, or LVS has been attempted.

### 4. PDK/foundry-specific blockers
- No STA against a real library — current clock constraint is an
  explicitly-labeled placeholder.
- No voltage/process corner analysis.
- No power analysis.
- No foundry design-rule signoff.

## Tapeout status

**Neuron32 RTL is lint-clean and has a synthesis flow, an SDC scaffold,
and an ASIC-flow document ready to receive a target PDK, but has not yet
had that flow (or most of the new verification added in this pass)
actually executed end-to-end in this environment, and is not tapeout-
ready until: the new testbenches and differential/synthesis checks are
confirmed passing in CI; the three outstanding architectural decisions
above are resolved; STA, physical design, DRC/LVS, SRAM integration,
clock-tree analysis, and power analysis are completed against a real,
chosen PDK; and foundry signoff is obtained.**
