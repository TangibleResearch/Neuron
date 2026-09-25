#!/usr/bin/env bash
# Runs the generic Yosys synthesis flow (synth/synth.ys) against
# rtl/neuron_chip.sv and its real submodule hierarchy, saves the log and
# reports under build/reports/, and fails if Yosys reports an error (a
# multi-driver net, a combinational loop, an undriven signal, or a plain
# synthesis failure -- see synth/synth.ys's comments for exactly which
# `check` passes catch which problem) or if it never produced the
# expected output netlist.
#
# Requires Yosys (https://github.com/YosysHQ/yosys) on PATH. This is a
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

mkdir -p "$REPORT_DIR"

echo "yosys version: $(yosys -V)" | tee "$REPORT_DIR/synth_tool_version.txt"

cd "$ROOT_DIR"
LOG="$REPORT_DIR/synth.log"

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
