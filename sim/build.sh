#!/usr/bin/env bash
# Builds the standalone Verilator-based Neuron32 runner (neuron_top.sv)
# into sim/build/vobj/neuron_sim.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build"

mkdir -p "$BUILD_DIR"

verilator --binary --top-module neuron_top -Wno-fatal --timing \
    -Mdir "$BUILD_DIR/vobj" -o neuron_sim \
    "$ROOT_DIR"/rtl/isa_pkg.sv \
    "$ROOT_DIR"/rtl/register.sv \
    "$ROOT_DIR"/rtl/alu.sv \
    "$ROOT_DIR"/rtl/clock.sv \
    "$ROOT_DIR"/rtl/status_reg.sv \
    "$ROOT_DIR"/rtl/mac.sv \
    "$ROOT_DIR"/rtl/matrix_regfile.sv \
    "$ROOT_DIR"/rtl/matrix_engine.sv \
    "$ROOT_DIR"/rtl/memory.sv \
    "$ROOT_DIR"/rtl/decode.sv \
    "$ROOT_DIR"/rtl/neuron_core.sv \
    "$SCRIPT_DIR"/neuron_top.sv

echo "built $BUILD_DIR/vobj/neuron_sim"
