#!/usr/bin/env bash
# Builds and runs every per-module testbench (alu_tb, register_tb,
# clock_tb, matrix_tb). alu_tb/register_tb/clock_tb are print-only (a
# human reads the log); matrix_tb.sv is self-checking (see its header)
# and fails the build on the first mismatch via $display + a non-zero
# exit, so this script's exit status is meaningful for matrix_tb even
# though the older three are informational.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build"
RTL_DIR="$ROOT_DIR/rtl"

mkdir -p "$BUILD_DIR"

echo "== alu_tb =="
verilator --binary --top-module alu_tb -Wno-fatal --timing --assert \
    -Mdir "$BUILD_DIR/alu" -o alu_tb_v \
    "$RTL_DIR/isa_pkg.sv" "$RTL_DIR/alu.sv" "$SCRIPT_DIR/alu_tb.sv"
"$BUILD_DIR/alu/alu_tb_v"

echo
echo "== register_tb =="
verilator --binary --top-module register_tb -Wno-fatal --timing --assert \
    -Mdir "$BUILD_DIR/register" -o register_tb_v \
    "$RTL_DIR/register.sv" "$SCRIPT_DIR/register_tb.sv"
"$BUILD_DIR/register/register_tb_v"

echo
echo "== clock_tb =="
verilator --binary --top-module clock_tb -Wno-fatal --timing --assert \
    -Mdir "$BUILD_DIR/clock" -o clock_tb_v \
    "$RTL_DIR/clock.sv" "$SCRIPT_DIR/clock_tb.sv"
"$BUILD_DIR/clock/clock_tb_v"

echo
echo "== matrix_tb (self-checking MAC/matrix-engine/matrix-regfile hardening) =="
verilator --binary --top-module matrix_tb -Wno-fatal --timing --assert \
    -Mdir "$BUILD_DIR/matrix" -o matrix_tb_v \
    "$RTL_DIR/isa_pkg.sv" "$RTL_DIR/mac.sv" "$RTL_DIR/matrix_engine.sv" \
    "$RTL_DIR/matrix_regfile.sv" "$SCRIPT_DIR/matrix_tb.sv"
"$BUILD_DIR/matrix/matrix_tb_v"

echo
echo "== reset_tb (self-checking reset hardening: startup/fetch/execute/memory-wait/MMUL/post-HALT) =="
verilator --binary --top-module reset_tb -Wno-fatal --timing --assert \
    -Mdir "$BUILD_DIR/reset" -o reset_tb_v \
    "$RTL_DIR/isa_pkg.sv" \
    "$RTL_DIR/register.sv" \
    "$RTL_DIR/alu.sv" \
    "$RTL_DIR/clock.sv" \
    "$RTL_DIR/status_reg.sv" \
    "$RTL_DIR/mac.sv" \
    "$RTL_DIR/matrix_regfile.sv" \
    "$RTL_DIR/matrix_engine.sv" \
    "$RTL_DIR/memory_sync.sv" \
    "$RTL_DIR/decode.sv" \
    "$RTL_DIR/neuron_core.sv" \
    "$SCRIPT_DIR/reset_tb.sv"
"$BUILD_DIR/reset/reset_tb_v"
