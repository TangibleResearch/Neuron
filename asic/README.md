# asic/ — physical-design flow scaffolding

This directory documents (and, where practical, scaffolds) the path from
synthesizable RTL to a fabricatable chip. **Generic synthesis
(`synth/`) is not tapeout.** Nothing in this repository is tapeout-ready;
see `docs/FABRICATION_READINESS.md` for the current, honest status.

## The intended flow

```
RTL (rtl/)
  -> lint            scripts/lint.sh            (Verilator, this repo)
  -> synthesis       scripts/synth_check.sh      (Yosys, generic cells, this repo)
  -> gate-level netlist                          (output of the above, target-PDK
                                                   cells once one is selected)
  -> STA             static timing analysis      (needs: liberty timing files for
                                                   the target library + constraints/neuron.sdc)
  -> floorplan                                   (needs: target PDK, die/core area budget)
  -> placement                                   (needs: target PDK, LEF)
  -> clock-tree synthesis (CTS)                  (needs: target PDK, clock tree
                                                   requirements from STA)
  -> routing                                     (needs: target PDK, LEF, routing rules)
  -> DRC              design rule check           (needs: target PDK's DRC deck)
  -> LVS              layout-vs-schematic          (needs: target PDK's LVS deck)
  -> GDSII                                        (the fabricable artifact)
```

Every stage from floorplan onward is **PDK-specific**: it needs real
files (a standard-cell library, LEF/liberty timing views, DRC/LVS rule
decks) that don't exist in this repository and are not committed here
(see "What is deliberately not committed" below).

## What this repo currently has

- `scripts/lint.sh` — Verilator RTL lint (synthesizability audit).
- `synth/` — generic Yosys synthesis (parses, elaborates, synthesizes to
  generic gates; reports statistics; catches multi-driver/combinational-
  loop/undriven-signal problems). See `synth/README.md` for exactly what
  it does and does not prove.
- `constraints/neuron.sdc` — a placeholder clock constraint, ready to be
  pointed at a real library once one exists. The clock period in it is
  explicitly *not* a frequency claim (see that file's own comments).
- `asic/openlane/config.json` — a PDK-agnostic
  [OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) /
  [OpenLane2](https://github.com/efabless/openlane2) configuration
  skeleton for `neuron_chip` (the same top used by `synth/synth.ys`),
  with every PDK-specific field either left to OpenLane's own default
  resolution (via `PDK`/`STD_CELL_LIBRARY` environment selection) or
  explicitly marked as needing a real value.

## What this repo deliberately does NOT have

- **No PDK.** No standard-cell library, no LEF, no liberty (`.lib`)
  timing files, no DRC/LVS decks. These are typically NDA'd or
  license-restricted (e.g. a foundry PDK, or even an open PDK like
  SkyWater's sky130 requires an explicit install step) and are never
  appropriate to commit into a source repository like this one, open or
  otherwise. Whoever runs the physical-design stage supplies these via
  environment/tool configuration (e.g. `PDK_ROOT` and `PDK` for
  OpenLane), not via files added to this repo.
- **No SRAM macro.** `rtl/memory.sv` and `rtl/memory_sync.sv` are
  flip-flop/latch-array models of memory, adequate for this design's
  default 1KB size to prove logic correctness and to synthesize cleanly
  as generic gates, but **not** what a real chip would use for any
  non-trivial memory capacity. A real implementation needs either a
  foundry SRAM compiler's hard macro or an open memory compiler's
  output, integrated at the physical-design stage with its own LEF/
  liberty views -- this is a physical-design dependency, not something
  `synth/synth.ys` or a bigger `MEM_SIZE` parameter solves. `rtl/
  neuron_chip.sv` deliberately does not instantiate a memory model at
  all (the memory bus is chip pins; see `docs/MEMORY_INTERFACE.md`),
  specifically so a real SRAM macro (or macro-backed memory controller)
  can be integrated at this stage without touching the core's RTL.
- **No STA results, no floorplan, no GDSII.** All require the PDK above.

## Voltage corners / process corners

Not addressed at all yet -- multi-corner STA (setup at slow/low-voltage/
high-temperature, hold at fast/high-voltage/low-temperature, etc.) is a
target-PDK-specific concern that only becomes meaningful once a real
library with corner-specific liberty views is selected. Tracked here as
an explicit open item, not silently assumed away.

## Using `asic/openlane/config.json`

This is a starting skeleton, not a validated OpenLane run. To actually
use it:

1. Choose a target PDK (e.g. `sky130A` for an open flow) and install it
   per OpenLane's own instructions (`PDK_ROOT`/`PDK` environment
   variables -- OpenLane resolves the standard-cell library from these,
   nothing in this repo names one).
2. Fill in the placeholder fields marked `REPLACE_ME` below with real
   values for that PDK/target (clock period from real STA, not
   `constraints/neuron.sdc`'s placeholder; die area sized for the actual
   cell count from `synth/`'s `stat` output against that PDK's cells,
   not generic logic).
3. Provide the SRAM macro integration mentioned above if `MEM_SIZE` is
   raised beyond a trivial flip-flop-array size, or keep memory fully
   external (matching `rtl/neuron_chip.sv`'s current chip-pin bus) and
   integrate memory at the board/package level instead.
