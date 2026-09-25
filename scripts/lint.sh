#!/usr/bin/env bash
# Verilator-based static lint of the production RTL (rtl/*.sv). This is the
# synthesizability gate: CI must fail if this script fails.
#
# Two warning categories are waived project-wide, below, because they've
# been individually reviewed and are not real RTL problems:
#
#   -Wno-DECLFILENAME  Several modules live in a file named after the
#                       module's function rather than its literal SV module
#                       name (register.sv -> register_file, clock.sv ->
#                       neuron_clock). This is a deliberate, established
#                       project file-naming convention (see README.md's
#                       directory description), not an accidental mismatch.
#
#   -Wno-IMPORTSTAR     Every module that needs the shared opcode/flag
#                       constants does `import isa_pkg::*;`. isa_pkg is the
#                       single, intentional source of truth for those
#                       constants (see isa_pkg.sv's own header comment) and
#                       is the only package in the project, so there is no
#                       real namespace-collision risk from the wildcard
#                       import.
#
# Every other warning category is left enabled and fatal: a new latch,
# multi-driver net, combinational loop, width mismatch, unused signal,
# etc. must be fixed (or, if it's a legitimate false positive, waived
# individually inline with a documented `/* verilator lint_off ... */
# ... /* verilator lint_on ... */` pair, the way rtl/neuron_core.sv does
# for alu_zero/alu_negative) rather than added here.
#
# Do NOT add `-Wno-fatal` to this script. The whole point of a lint gate is
# that real warnings fail the build.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RTL_DIR="$ROOT_DIR/rtl"

COMMON_FLAGS=(--lint-only -Wall -Wno-DECLFILENAME -Wno-IMPORTSTAR --timing)

status=0

echo "== Per-module lint (each leaf module elaborated standalone) =="
# Composite modules (matrix_engine instantiates mac; neuron_core
# instantiates nearly everything; neuron_chip instantiates neuron_core)
# are intentionally NOT re-elaborated standalone here -- they're already
# covered, with their real submodules, by the full-hierarchy passes below.
# Elaborating e.g. neuron_core.sv alone against only isa_pkg.sv would just
# produce MODMISSING errors for every submodule it instantiates, which
# isn't a real RTL problem.
LEAF_MODULES=(register alu clock status_reg mac matrix_regfile decode memory memory_sync)
for base in "${LEAF_MODULES[@]}"; do
    echo "-- $base --"
    # -Wno-UNUSEDPARAM here only: isa_pkg is a wide shared package (every
    # opcode, every ALU op, the matrix geometry, ...) and any single leaf
    # module only needs a handful of its constants. Elaborated standalone,
    # Verilator (correctly, for this narrow elaboration) reports the rest
    # as unused -- but they're not unused in the real design, only in this
    # one-module-at-a-time view. The full-hierarchy elaborations below
    # (neuron_core, neuron_chip) use every constant somewhere and are NOT
    # given this waiver, so a genuinely unused isa_pkg constant would
    # still be caught there.
    if ! verilator "${COMMON_FLAGS[@]}" -Wno-UNUSEDPARAM "$RTL_DIR/isa_pkg.sv" "$RTL_DIR/$base.sv" 2>&1; then
        status=1
    fi
done

echo "-- matrix_engine (with its mac submodule) --"
if ! verilator "${COMMON_FLAGS[@]}" -Wno-UNUSEDPARAM --top-module matrix_engine \
    "$RTL_DIR/isa_pkg.sv" "$RTL_DIR/mac.sv" "$RTL_DIR/matrix_engine.sv" 2>&1; then
    status=1
fi

# isa_pkg.sv must come first: every other file that imports it depends on
# compilation order for a package.
CORE_FILES=(
    "$RTL_DIR/isa_pkg.sv"
    "$RTL_DIR/register.sv"
    "$RTL_DIR/alu.sv"
    "$RTL_DIR/clock.sv"
    "$RTL_DIR/status_reg.sv"
    "$RTL_DIR/mac.sv"
    "$RTL_DIR/matrix_regfile.sv"
    "$RTL_DIR/matrix_engine.sv"
    "$RTL_DIR/memory.sv"
    "$RTL_DIR/decode.sv"
    "$RTL_DIR/neuron_core.sv"
)

# neuron_chip doesn't instantiate a memory model itself (the memory bus is
# a chip pin -- see rtl/neuron_chip.sv's header), so it only needs
# neuron_core's own submodule tree, not memory.sv/memory_sync.sv.
CHIP_FILES=(
    "$RTL_DIR/isa_pkg.sv"
    "$RTL_DIR/register.sv"
    "$RTL_DIR/alu.sv"
    "$RTL_DIR/clock.sv"
    "$RTL_DIR/status_reg.sv"
    "$RTL_DIR/mac.sv"
    "$RTL_DIR/matrix_regfile.sv"
    "$RTL_DIR/matrix_engine.sv"
    "$RTL_DIR/decode.sv"
    "$RTL_DIR/neuron_core.sv"
    "$RTL_DIR/neuron_chip.sv"
)

echo
echo "== Full-hierarchy lint: neuron_core as top (memory.sv, async-read variant) =="
if ! verilator "${COMMON_FLAGS[@]}" --top-module neuron_core "${CORE_FILES[@]}"; then
    status=1
fi

echo
echo "== Full-hierarchy lint: neuron_chip as top, production pinout (no debug ports) =="
if ! verilator "${COMMON_FLAGS[@]}" --top-module neuron_chip "${CHIP_FILES[@]}"; then
    status=1
fi

echo
echo "== Full-hierarchy lint: neuron_chip as top, debug/bring-up pinout (+define+NEURON_DEBUG) =="
if ! verilator "${COMMON_FLAGS[@]}" +define+NEURON_DEBUG --top-module neuron_chip "${CHIP_FILES[@]}"; then
    status=1
fi

if [[ $status -eq 0 ]]; then
    echo
    echo "lint: PASS (no unreviewed warnings)"
else
    echo
    echo "lint: FAIL (unreviewed warnings above)"
fi

exit $status
