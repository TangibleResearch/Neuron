#!/usr/bin/env bash
# Compiles core_tb.sv against the rtl/ sources with Verilator, runs it
# against every generated test vector in sim/testvectors/, and checks the
# captured OUT byte stream: "hello" must print "Hello, World!", every other
# vector is one of Nemu's self-checking programs that must print "PASS"
# (and must not print "FAIL").
#
# NOTE: this project uses Verilator, not Icarus Verilog, as the reference
# simulator. An earlier version of this script used `iverilog`/`vvp` and
# hit a genuine Icarus interpreter limitation: combinational logic reading
# back an array-typed submodule output (register_file's read ports,
# matrix_regfile's read ports) that the same always_comb block also drives
# the address/select inputs for caused Icarus to livelock re-evaluating the
# process forever at a single simulated time, even though every signal
# value involved was already stable and correct. Verilator (and, per the
# reference model's own semantics, real hardware) has no such issue. If
# you're extending this design and Icarus is your only simulator, expect
# to hit the same wall — see CHATGPT.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VECTORS_DIR="$ROOT_DIR/sim/testvectors"
BUILD_DIR="$ROOT_DIR/tb/build"

mkdir -p "$BUILD_DIR"

verilator --binary --top-module core_tb -Wno-fatal --timing \
    -Mdir "$BUILD_DIR/vobj" -o core_tb_v \
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
    "$ROOT_DIR"/tb/core_tb.sv \
    > "$BUILD_DIR/verilate.log" 2>&1 || { cat "$BUILD_DIR/verilate.log"; exit 1; }

BIN="$BUILD_DIR/vobj/core_tb_v"

pass=0
fail=0

for hex in "$VECTORS_DIR"/*.hex; do
    name="$(basename "${hex%.hex}")"
    out="$("$BIN" +HEXFILE="$hex")"

    output_line="$(echo "$out" | grep '^OUTPUT: ')"

    if [[ "$name" == "hello" ]]; then
        if echo "$output_line" | grep -q "Hello, World!"; then
            echo "PASS  $name"
            pass=$((pass+1))
        else
            echo "FAIL  $name"
            echo "$out" | sed 's/^/      /'
            fail=$((fail+1))
        fi
    else
        if echo "$output_line" | grep -q "PASS" && ! echo "$output_line" | grep -q "FAIL"; then
            echo "PASS  $name"
            pass=$((pass+1))
        else
            echo "FAIL  $name"
            echo "$out" | sed 's/^/      /'
            fail=$((fail+1))
        fi
    fi
done

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
