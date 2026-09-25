# Reset behavior

`reset` is a single, synchronous, active-high signal distributed to every
state-holding module in `rtl/`. There is no asynchronous reset tree and
no separate power-on-reset model: every register that needs a defined
value after reset gets it from an explicit `if (reset) ... <= ...;`
branch inside its own `always_ff`, sampled on the same `clk` edge as
everything else. This is deliberate — ASIC-visible state must not depend
on FPGA-style initial-value inference (`initial` blocks, `= 0` at
declaration), which has no equivalent in real silicon. None of the
modules below use one for anything architecturally visible.

## Per-module audit

| Module | Reset value | Notes |
|---|---|---|
| `neuron_core` (FSM) | `state = S_FETCH_OPCODE` | Always restarts at fetch, regardless of where it was. |
| `neuron_core` (PC) | `pc = 0` | Matches Nemu's `NeuronCpu::new` (`pc: 0`). |
| `neuron_core` (SP) | `sp = MEM_SIZE` | Matches Nemu (`sp: memory_size`). |
| `neuron_core` (FP) | `fp = 0` | Matches Nemu (`fp: 0`). FP is otherwise unused — see `docs/ISA.md`. |
| `neuron_core` (halted/illegal) | `halted_r = 0`, `illegal_opcode = 0` | Not sticky across reset — see "HALT is not sticky across reset" below. |
| `neuron_core` (opcode_reg/operand/byte_idx) | all `0` | Fetch-in-progress state; irrelevant once `state` is back at `S_FETCH_OPCODE`, zeroed anyway for determinism. |
| `register_file` (R0-R15) | all `0` | Matches Nemu (`r0..r15: 0`). |
| `status_reg` (STATUS) | `0` | Matches Nemu (`status: 0`). |
| `mac` (standalone MAC accumulator) | `0` | `reset` and `clear` share the same effect on this module. Matches Nemu (`Mac::new` / `Mac::reset`). |
| `matrix_regfile` (M0-M3) | all 16 cells of all 4 registers `0` | Matches Nemu (`m0..m3: [[0;4];4]`). |
| `matrix_engine` (busy/done/k) | `busy=0`, `done=0`, `k=0` | See "Reset during MMUL" below — this is what makes reset-mid-run safe. |
| `matrix_engine`'s 16 internal `mac` instances | all `0` | `reset` is fanned out to every parallel MAC (`matrix_engine.sv`'s `generate` block), so the accumulated partial products of an interrupted MMUL are wiped, not just the busy/done control state. |
| `neuron_clock` (tick counter) | `0` | Debug/perf visibility only; architecturally inert (see `docs/MICROARCHITECTURE.md`). |
| `memory` / `memory_sync` (RAM contents) | **not reset** | Deliberate — see "Memory contents are not reset" below. |
| `memory_sync` (internal wait-state FSM) | `mstate = M_IDLE`, `count = 0` | So a reset mid-wait doesn't leave the memory model stuck mid-transaction; the core's own request re-presents cleanly after reset (see `docs/MEMORY_INTERFACE.md`). |

## Memory contents are not reset

Real SRAM has no defined power-on content, and Nemu's own `reset()`
explicitly documents this: *"Program and system RAM are owned by the
caller and are intentionally unaffected by a CPU reset."* Both
`rtl/memory.sv` and `rtl/memory_sync.sv` follow the same rule: neither
module's `bytes[]` array is touched by `reset`. Simulation callers that
need deterministic memory contents (`tb/core_tb.sv`, `tb/core_delay_tb.sv`,
`tb/reset_tb.sv`) explicitly zero-fill `bytes[]` themselves before
loading a program, exactly like Nemu's own CLI zero-fills a fresh `Vec<u8>`
before copying a program in.

## HALT is not sticky across reset

`halted_r` is sticky **until reset** (see the assertion in
`rtl/neuron_core.sv`: `$past(halted_r) |-> halted_r`, disabled while
`reset` is active) — but reset itself always clears it, by design. A
halted core that receives `reset` is fully live again at
`S_FETCH_OPCODE`/`pc=0`, not stuck. `tb/reset_tb.sv`'s "reset after HALT"
case checks exactly this: reset after HALT, then confirms the core
executes a fresh program correctly afterward.

## Reset during MMUL

The matrix engine's `busy`/`done`/`k` and its 16 internal MAC
accumulators are all reset the same way as everything else — a reset
asserted mid-run drops `busy` back to `0` immediately (not "when the
current run finishes"), clears the partial accumulation, and leaves the
destination matrix register whatever it was before the run (the
destination is only written on the `done` cycle, which reset prevents
from ever being reached — see `rtl/matrix_engine.sv`'s protocol
assertions). `tb/reset_tb.sv`'s "reset during MMUL" case interrupts a run
mid-systolic-sweep, confirms `busy`/`done` are both `0` immediately after,
and then confirms the core can issue and complete a fresh instruction
sequence afterward (not just that state looks clean, but that it's
actually usable).

## What's tested (`tb/reset_tb.sv`)

Self-checking; asserts the full architectural state (PC, SP, FP, STATUS,
R0-R15, halted, illegal_opcode, matrix-engine busy/done, MAC accumulator)
is back to the table above after reset asserted:

1. At startup, before anything has run.
2. While fetching (mid-instruction-byte-stream).
3. While executing a normal ALU instruction (`ADD`).
4. During a memory wait (`STORE` stalled on a non-zero-latency
   `memory_sync` `wait_states`).
5. During MMUL (mid-systolic-run), followed by a check that the core
   executes correctly afterward.
6. After HALT, followed by a check that the core executes correctly
   afterward.
