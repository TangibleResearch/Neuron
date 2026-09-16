# Tangible Neuron
Official Repo for the Tangible Neuron Project

**NOTE**: This project is the Actual Verilog HDL based CPU, Not the Emulator. If you are willing to make code for Neuron, Use Nemu as this Repo is where the team will design the actual circut which then will be fabricated for production.

Tangible Neuron is a Open source, ASIC based, AI based processor Designed to run Intense AI based workflows on **1** Chip

## Structure

- `rtl/` — the Neuron32 scalar CPU core in SystemVerilog: register file, ALU, MAC unit, 4x4 INT8 matrix engine, and the fetch/decode/execute control unit (`neuron_core.sv`) that implements Nemu's instruction set (`src/isa.rs` / `src/cpu.rs` there is the spec).
- `tb/` — unit testbenches per module, plus `core_tb.sv`, an instruction-level testbench that runs Nemu's real `.nuasm` test programs against the RTL. Run `tb/run_all.sh` (needs `sim/testvectors/`, see below).
- `sim/` — standalone target: assemble and run a `.nuasm` file directly against the real RTL via Verilator. `sim/run.sh path/to/program.nuasm` (needs a local `Nemu` checkout for the assembler; set `NEMU_DIR` if it's not at `~/Nemu`). `sim/gen_testvectors.sh` regenerates the hex test vectors `tb/run_all.sh` uses.
- `renode/` — wraps the same core as a CPU for [Renode](https://renode.io) via Verilator co-simulation, so Neuron can be the CPU in a simulated platform alongside Renode's peripheral models.
- `CHATGPT.md` — task backlog / spec handoff for AI coding agents working on this repo.

**Build/test requirements**: [Verilator](https://verilator.org) (the reference simulator for this project — see the note in `tb/run_all.sh` about why Icarus Verilog isn't used), and a local clone of [Nemu](https://github.com/TangibleResearch/Nemu) for the NuASM assembler and reference test programs.

## Status

`rtl/` implements the Neuron32 scalar core (fetch/decode/execute, scalar
register file, ALU, MAC, and the 4x4 INT8 matrix engine) in SystemVerilog,
matching the ISA/semantics of the reference software model in
[Nemu](https://github.com/TangibleResearch/Nemu) instruction-for-instruction.
It passes all of Nemu's self-checking `.nuasm` test programs running on the
real RTL via Verilator. Vector (V0-V7) and predicate (P0-P3) registers from
the architecture sketch above aren't implemented yet — Nemu doesn't define
any opcodes for them yet either, so there's nothing to port.

Two ways to run it:

- **`sim/`** — a standalone Verilator-based runner: `sim/run.sh
  path/to/program.nuasm` assembles with Nemu's real `nuasm` tool and runs
  the program on the actual core, streaming `OUT` output and dumping final
  register/status state (the RTL analogue of Nemu's own `neuron` CLI).
- **`renode/`** — wraps the same core as a CPU for
  [Renode](https://renode.io/), for full-system simulation alongside
  Renode's peripheral models. See `renode/README.md` for status.

Run the RTL test suite (regenerates test vectors from a local Nemu
checkout, builds with Verilator, checks output against Nemu's expected
pass/fail programs):

```sh
NEMU_DIR=~/Nemu sim/gen_testvectors.sh
tb/run_all.sh
```

See [CHATGPT.md](CHATGPT.md) for the current task backlog and how this
project is being split between Claude and Codex.