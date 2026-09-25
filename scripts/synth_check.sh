#!/usr/bin/env bash
# Runs the generic Yosys synthesis flow (synth/synth.ys) against
# rtl/neuron_chip.sv and its real submodule hierarchy, saves the log and
# reports under build/reports/, and fails if Yosys reports an error (a
# multi-driver net, a combinational loop, an undriven signal, or a plain
# synthesis failure -- see synth/synth.ys's comments for exactly which
# `check` passes catch which problem) or if it never produced the
# expected output netlist.
#
# Requires Yosys (https://github.com/YosysHQ/yosys) and sv2v
# (https://github.com/zachjs/sv2v) on PATH -- sv2v converts the
# SystemVerilog RTL into plain Verilog Yosys's built-in frontend can
# parse (see synth/synth.ys). Set SV2V to override its path. This is a
# synthesizability + generic-logic area-estimate check, not a tapeout
# flow -- see asic/README.md for what's still missing between this and a
# real chip (a target standard-cell library/PDK, SRAM macro integration,
# STA, physical design, DRC/LVS).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_DIR="$ROOT_DIR/build/reports"

if ! command -v yosys >/dev/null 2>&1; then
    echo "error: yosys not found on PATH." >&2
    echo "Install it (e.g. 'brew install yosys' on macOS, 'apt-get install yosys' on Debian/Ubuntu)" >&2
    echo "and re-run this script. See synth/README.md." >&2
    exit 1
fi

SV2V="${SV2V:-sv2v}"
if ! command -v "$SV2V" >/dev/null 2>&1; then
    echo "error: sv2v not found (looked for '$SV2V')." >&2
    echo "Download a release binary from https://github.com/zachjs/sv2v/releases" >&2
    echo "and put it on PATH (or set SV2V=/path/to/sv2v). See synth/README.md." >&2
    exit 1
fi

mkdir -p "$REPORT_DIR"

echo "yosys version: $(yosys -V)" | tee "$REPORT_DIR/synth_tool_version.txt"

cd "$ROOT_DIR"
LOG="$REPORT_DIR/synth.log"

# Same file list and order synth/synth.ys used to read directly.
"$SV2V" -DSYNTHESIS --top=neuron_chip \
    rtl/isa_pkg.sv \
    rtl/register.sv \
    rtl/alu.sv \
    rtl/clock.sv \
    rtl/status_reg.sv \
    rtl/mac.sv \
    rtl/matrix_regfile.sv \
    rtl/matrix_engine.sv \
    rtl/decode.sv \
    rtl/neuron_core.sv \
    rtl/neuron_chip.sv \
    > "$REPORT_DIR/neuron_chip.sv2v.v"

if yosys -l "$LOG" synth/synth.ys; then
    :
else
    status=$?
    echo "synth_check: FAIL (yosys exited $status) -- see $LOG" >&2
    exit "$status"
fi

# Belt-and-suspenders: yosys can exit 0 while having printed an ERROR to
# the log in some flows (e.g. inside a nested script), and the whole
# point of this gate is that a synthesis warning about multiple drivers/
# undriven nets/combinational loops must fail CI, not just be logged.
if grep -qiE '^ERROR|combinational loop|multiple driv|has no driver' "$LOG"; then
    echo "synth_check: FAIL (see $LOG for the reported error)" >&2
    grep -inE '^ERROR|combinational loop|multiple driv|has no driver' "$LOG" >&2
    exit 1
fi

if [[ ! -f "$REPORT_DIR/neuron_chip.synth.v" ]]; then
    echo "synth_check: FAIL (expected output netlist $REPORT_DIR/neuron_chip.synth.v was not produced)" >&2
    exit 1
fi

echo "synth_check: PASS"
echo "reports written to $REPORT_DIR"
