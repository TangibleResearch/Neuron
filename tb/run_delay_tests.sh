#!/usr/bin/env bash
# Runs every generated test vector in sim/testvectors/ through
# core_delay_tb.sv (neuron_core + memory_sync.sv) under four memory-timing
# configurations -- fixed 0/1/2 wait states and randomized 0-3 -- and
# checks the OUT byte stream against the same PASS/FAIL/"Hello, World!"
# convention tb/run_all.sh uses. Architectural correctness (what gets
# printed) must not depend on memory latency; only the cycle count should
# change. See tb/core_delay_tb.sv's header for what each +WAITMODE= means.
#
# A failure prints the exact +SEED= used for WAITMODE=3 so it can be
# reproduced: tb/build/vobj_delay/core_delay_tb_v +HEXFILE=... +WAITMODE=3 +SEED=<n>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VECTORS_DIR="$ROOT_DIR/sim/testvectors"
BUILD_DIR="$ROOT_DIR/tb/build"

mkdir -p "$BUILD_DIR"

verilator --binary --top-module core_delay_tb -Wno-fatal --timing --assert \
    -Mdir "$BUILD_DIR/vobj_delay" -o core_delay_tb_v \
    "$ROOT_DIR"/rtl/isa_pkg.sv \
    "$ROOT_DIR"/rtl/register.sv \
    "$ROOT_DIR"/rtl/alu.sv \
    "$ROOT_DIR"/rtl/clock.sv \
    "$ROOT_DIR"/rtl/status_reg.sv \
    "$ROOT_DIR"/rtl/mac.sv \
    "$ROOT_DIR"/rtl/matrix_regfile.sv \
    "$ROOT_DIR"/rtl/matrix_engine.sv \
    "$ROOT_DIR"/rtl/memory_sync.sv \
    "$ROOT_DIR"/rtl/decode.sv \
    "$ROOT_DIR"/rtl/neuron_core.sv \
    "$ROOT_DIR"/tb/core_delay_tb.sv \
    > "$BUILD_DIR/verilate_delay.log" 2>&1 || { cat "$BUILD_DIR/verilate_delay.log"; exit 1; }

BIN="$BUILD_DIR/vobj_delay/core_delay_tb_v"
SEED="${SEED:-1}"

pass=0
fail=0

check_output() {
    local name="$1" out="$2" waitmode="$3"
    local output_line
    output_line="$(echo "$out" | grep '^OUTPUT: ')"

    if [[ "$name" == "hello" ]]; then
        if echo "$output_line" | grep -q "Hello, World!"; then
            echo "PASS  $name  waitmode=$waitmode"
            pass=$((pass+1))
        else
            echo "FAIL  $name  waitmode=$waitmode  (seed=$SEED)"
            echo "$out" | sed 's/^/      /'
            fail=$((fail+1))
        fi
    else
        if echo "$output_line" | grep -q "PASS" && ! echo "$output_line" | grep -q "FAIL"; then
            echo "PASS  $name  waitmode=$waitmode"
            pass=$((pass+1))
        else
            echo "FAIL  $name  waitmode=$waitmode  (seed=$SEED)"
            echo "$out" | sed 's/^/      /'
            fail=$((fail+1))
        fi
    fi
}

for hex in "$VECTORS_DIR"/*.hex; do
    name="$(basename "${hex%.hex}")"
    for waitmode in 0 1 2 3; do
        out="$("$BIN" +HEXFILE="$hex" +WAITMODE="$waitmode" +SEED="$SEED")"
        check_output "$name" "$out" "$waitmode"
    done
done

echo
echo "$pass passed, $fail failed (seed=$SEED)"
[[ $fail -eq 0 ]]
