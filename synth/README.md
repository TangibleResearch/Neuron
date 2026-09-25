# synth/

Generic (technology-agnostic) synthesis check for the Neuron32 core, using
[Yosys](https://github.com/YosysHQ/yosys).

## What this proves

- `rtl/neuron_chip.sv` (the ASIC-oriented chip top; see its header comment
  for why it isn't named `neuron_top`) and its real submodule hierarchy
  (`neuron_core`, `register_file`, `alu`, `mac`, `matrix_regfile`,
  `matrix_engine`, `status_reg`, `decode`) parse as synthesizable
  SystemVerilog.
- The design elaborates with no unresolved module references.
- The design synthesizes to generic gates/flops with no multi-driver
  nets, no combinational loops, and no undriven signals (Yosys's `check`
  pass, run both pre- and post-synthesis -- see `synth.ys`'s comments).
- Cell, register, and memory-inference statistics against Yosys's
  built-in generic gate library.

## What this does NOT prove

- **Not a timing signoff.** No standard-cell library or PDK is targeted
  (see `asic/README.md` for why none is committed to this repo), so there
  is no real gate delay information and no static timing analysis here.
  `constraints/neuron.sdc` exists to make the *next* stage (STA against a
  real library) possible, not to claim a frequency.
- **Not an area signoff.** The cell counts in `stat`'s output are against
  generic logic, not any real standard-cell library's actual gates --
  useful for spotting something absurd (a module that's 100x bigger than
  expected) but not a die-area estimate.
- **Not tapeout-ready.** See `asic/README.md` for the full list of stages
  between "synthesizes cleanly" and a fabricatable GDSII, including SRAM
  macro integration for any real-capacity on-chip memory (`rtl/memory.sv`
  / `rtl/memory_sync.sv` synthesize fine as flip-flop-based storage for
  this design's small 1KB default, which is adequate for proving the
  logic but is not what a real memory macro looks like).

## Running it

```sh
scripts/synth_check.sh
```

Requires Yosys on `PATH` (`brew install yosys` on macOS, `apt-get install
yosys` on Debian/Ubuntu -- also available in GitHub Actions' Ubuntu
runners via apt, see `.github/workflows/ci.yml`) and
[sv2v](https://github.com/zachjs/sv2v) (download a release binary; set
`SV2V=/path/to/sv2v` if it isn't on `PATH`). Yosys's built-in frontend
can't parse this design's unpacked-array ports, so `synth_check.sh` first
converts the RTL to plain Verilog with sv2v and synthesizes that. Writes a log and the
synthesized netlist/statistics to `build/reports/` (gitignored; see
`docs/FABRICATION_READINESS.md` for how to read the results).

## Why `neuron_chip.sv`, not `neuron_core.sv`, is the synthesis target

`neuron_core.sv` exposes a 512-bit `regs_dbg` array and several other
debug-only ports directly, because that's convenient for testbenches.
`neuron_chip.sv` wraps it with a realistic chip pinout (clock, reset, the
generic memory bus, the OUT byte stream, and `halted`/`illegal_opcode`)
and gates the debug ports behind `` `ifdef NEURON_DEBUG `` (undefined
here, so this synthesis run gets the production pinout). See
`rtl/neuron_chip.sv`'s own header comment for the full reasoning,
including why it isn't simply called `neuron_top` (that name is already
used by `sim/neuron_top.sv`, an unrelated simulation-only driver).
