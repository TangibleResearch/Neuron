# constraints/neuron.sdc
#
# Synopsys Design Constraints for the neuron_chip synthesis target
# (rtl/neuron_chip.sv, see synth/synth.ys).
#
# ============================================================================
# THE CLOCK PERIOD BELOW IS A PLACEHOLDER, NOT A SPECIFICATION.
#
# 50 MHz / 20 ns was picked as a conservative, "almost certainly achievable
# even on a slow standard-cell library" starting point for getting a
# synthesis+STA flow running end-to-end -- it is NOT the result of any
# static timing analysis against neuron_core's actual critical path, and
# it is NOT a claim about what this design can run at in silicon.
#
# The only source of truth for achievable frequency is: synthesize against
# a real, named standard-cell library and PDK, run STA (see asic/README.md
# for where that fits in the flow), and read the resulting worst negative
# slack. Until that's been done for a specific target process, do not
# quote a frequency number for this design anywhere -- docs, marketing,
# investor material, none of it. Frequency is a measurement, not a
# constant you write into a file.
# ============================================================================

create_clock -name clk -period 20.0 [get_ports clk]

# neuron_core has exactly one clock domain (see docs/MICROARCHITECTURE.md,
# "Clocking"): every state-holding element in rtl/ is clocked off `clk`.
# There is no second clock, no generated/divided clock, and no fabricated
# PLL model here -- if a PLL is ever needed for a real tapeout, it belongs
# in the physical-design stage (asic/), constrained against its own
# datasheet, not invented in this file.

set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]

# Reset (rtl/neuron_core.sv's `reset` port, and every submodule's `reset`
# input) is synchronous, sampled on the same `clk` edge as everything
# else -- see docs/RESET.md. It is deliberately NOT declared as a false
# path or an asynchronous reset tree here: treat it as a normal
# synchronous signal for timing purposes.

# ----------------------------------------------------------------------
# I/O timing: placeholders. Neither the mem_ready-gated memory bus (see
# docs/MEMORY_INTERFACE.md) nor the OUT byte stream has a specified
# external timing budget yet -- these exist so the design has *something*
# to close I/O timing against in an STA run, not because 3 ns / 2 ns are
# real numbers. Replace with whatever the actual memory macro/bus/pad
# timing turns out to require once one is chosen.
# ----------------------------------------------------------------------

set all_inputs  [remove_from_collection [all_inputs] [get_ports clk]]
set all_outputs [all_outputs]

set_input_delay  -clock clk 3.0 $all_inputs
set_output_delay -clock clk 2.0 $all_outputs

# No false paths, no multicycle paths: this is a plain, non-pipelined,
# multi-cycle-per-instruction control unit (see docs/MICROARCHITECTURE.md)
# with a single clock domain and no intentionally-slow paths that would
# warrant one. If a genuine multicycle path is identified during STA
# (e.g. matrix_engine's systolic run is architecturally 4 cycles per
# result, not that any single path spans 4 cycles), add it here with a
# comment explaining why, rather than blanket-relaxing timing.
