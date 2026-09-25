# Neuron32 memory bus interface

The core (`rtl/neuron_core.sv`, wrapped by `rtl/neuron_chip.sv` at the
chip level) accesses all program and data memory through one generic
ready/valid bus. The same core, unmodified, drives:

- `rtl/memory.sv` — combinational (zero-wait-state) read, synchronous
  write. Used by `sim/`, `tb/core_tb.sv`, and `tb/alu_tb.sv`'s siblings.
- `rtl/memory_sync.sv` — configurable-latency synchronous read/write
  (`wait_states` input). Used by `tb/core_delay_tb.sv` and `tb/reset_tb.sv`
  to prove the core tolerates real memory latency.
- an external adapter (`renode/`) for full-system co-simulation.

## Signals

| Signal | Width | Direction (from core) | Meaning |
|---|---|---|---|
| `mem_addr` | 32 | out | Byte address of the current request. |
| `mem_word` | 1 | out | `1` = 32-bit little-endian access, `0` = 1-byte access. |
| `mem_read` | 1 | out | Request is a read. |
| `mem_write` | 1 | out | Request is a write. |
| `mem_wdata` | 32 | out | Write data (only the low 8 bits matter when `mem_word=0`). |
| `mem_rdata` | 32 | in | Read data, valid the cycle `mem_ready` is high during a read. |
| `mem_ready` | 1 | in | Pulses high the cycle the current request completes. |

`mem_read` and `mem_write` are mutually exclusive by construction — every
opcode arm in `neuron_core.sv`'s `S_EXECUTE` case sets at most one of
them, and `rtl/neuron_core.sv` asserts this (`!(mem_read && mem_write)`)
under `` `ifndef SYNTHESIS ``.

## Addressing

- 32-bit byte addresses.
- Little-endian: a 32-bit access at address `A` reads/writes bytes
  `A` (LSB) through `A+3` (MSB) — mirrors Nemu's `read_u32`/`write_u32`
  (`u32::from_le_bytes`/`to_le_bytes` in `src/cpu.rs`).
- No alignment is enforced anywhere in the core or the memory models: a
  32-bit access at an odd address is legal and simply touches
  `A..A+3`. See `docs/EXCEPTIONS_AND_UNDEFINED_BEHAVIOR.md` for what
  happens at the top of the address space.

## Request lifecycle

A request **begins** the cycle `mem_read` or `mem_write` is first
asserted (both are pure combinational functions of `(state, opcode_reg,
operand[], sp, pc)` in `neuron_core.sv` — never registered outputs), and
**ends** the cycle `mem_ready` is sampled high on that same request.
There is no separate "acknowledge then data" phase: `mem_ready` and (for
reads) `mem_rdata` are valid together, the same cycle.

**Address/data must remain stable while waiting.** While a request is
outstanding, `neuron_core.sv` stays in the same FSM state
(`S_FETCH_OPCODE`, `S_FETCH_OPERANDS`, or `S_EXECUTE`) and none of
`state`, `opcode_reg`, `operand[]`, `sp`, or `pc` change until
`mem_ready` is observed — so `mem_addr`/`mem_word`/`mem_read`/
`mem_write`/`mem_wdata`, being pure combinational functions of exactly
those signals, are provably stable for the whole wait, not just by
convention. This is enforced with assertions in `rtl/neuron_core.sv`:

```
assert property (@(posedge clk) disable iff (reset)
    (mem_read && !mem_ready) |=> mem_read && $stable(mem_addr));
assert property (@(posedge clk) disable iff (reset)
    (mem_write && !mem_ready) |=> mem_write && $stable(mem_addr) && $stable(mem_wdata));
```

**Single outstanding request only.** The core never issues a second
request before the first completes — there is exactly one request in
flight per FSM state, ever. This is architecturally simple by
construction (there is nothing in the control unit that *could* pipeline
requests) rather than something separately enforced; `docs/
MICROARCHITECTURE.md` has the full FSM. Keep it this way unless changing
it is absolutely required (see the top-level task's own instruction to
that effect) — it is what makes the stability guarantee above provable
from the FSM structure alone.

**Delayed `mem_ready` is fully supported.** The core has no notion of a
timeout or a maximum wait: as long as the memory model eventually pulses
`mem_ready` with the request still asserted, the core proceeds correctly
regardless of how many cycles that takes. `rtl/memory_sync.sv` and
`tb/core_delay_tb.sv`/`tb/run_delay_tests.sh` prove this for 0, 1, 2, and
randomized 0-3 cycle latencies across every memory-touching opcode
(instruction fetch, `LOAD`, `STORE`, `PUSH`, `POP`, `CALL`, `RET`) against
the same self-checking NuASM programs `tb/run_all.sh` uses with
zero-latency memory — the architectural result (the `OUT` byte stream) is
identical in every case; only the cycle count changes.

## What's out of scope here

- Bus arbitration / multiple masters: there is exactly one requester
  (the core). Not applicable.
- Byte-enable strobes narrower than the two supported access widths (1
  byte, 4-byte little-endian word): not implemented; not needed by any
  current opcode.
- Error responses (e.g. a bus abort for an out-of-range address): the
  bus has no error signal. See `docs/EXCEPTIONS_AND_UNDEFINED_BEHAVIOR.md`
  for what currently happens instead.
