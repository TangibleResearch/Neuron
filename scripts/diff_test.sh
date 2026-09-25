#!/usr/bin/env bash
# Differential test: runs one NuASM program through both Nemu (the
# reference software model's real `neuron` CLI) and the actual Neuron RTL
# (via tb/core_tb.sv under Verilator) and compares the resulting
# architectural state: R1-R5, PC, SP, STATUS. (Nemu's own `neuron` CLI
# only ever prints R1-R5, not the full R0-R15 -- see src/Neuron.rs -- so
# that's the common surface both sides can be compared on without
# modifying Nemu, which is out of scope here.)
#
# Two modes:
#   scripts/diff_test.sh path/to/program.nuasm
#       Runs exactly that program once.
#
#   scripts/diff_test.sh --random --seed N [--count C] [--program-size S]
#       Generates C (default 20) random straight-line programs starting
#       at seed N via scripts/gen_random_program.py and runs each one.
#       Seeds are deterministic: a failure reprints the exact seed that
#       reproduces it.
#
# Requires: a local Nemu checkout (NEMU_DIR, default ~/Nemu) with nuasm
# and neuron already built (`cargo build --release --bin nuasm --bin
# neuron`), and tb/build/vobj/core_tb_v already built (tb/run_all.sh
# builds it).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
NEMU_DIR="${NEMU_DIR:-$HOME/Nemu}"
NUASM="$NEMU_DIR/target/release/nuasm"
NEURON_CLI="$NEMU_DIR/target/release/neuron"
CORE_TB="$ROOT_DIR/tb/build/vobj/core_tb_v"

mode="single"
program=""
seed_start=1
count=20
program_size=60

while [[ $# -gt 0 ]]; do
    case "$1" in
        --random) mode="random"; shift ;;
        --seed) seed_start="$2"; shift 2 ;;
        --count) count="$2"; shift 2 ;;
        --program-size) program_size="$2"; shift 2 ;;
        *) program="$1"; shift ;;
    esac
done

if [[ ! -x "$NUASM" ]]; then
    echo "error: nuasm not built at $NUASM (cargo build --release --bin nuasm --manifest-path \"$NEMU_DIR/Cargo.toml\")" >&2
    exit 1
fi
if [[ ! -x "$NEURON_CLI" ]]; then
    echo "error: neuron CLI not built at $NEURON_CLI (cargo build --release --bin neuron --manifest-path \"$NEMU_DIR/Cargo.toml\")" >&2
    exit 1
fi
if [[ ! -x "$CORE_TB" ]]; then
    echo "error: $CORE_TB not built -- run tb/run_all.sh first" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Extracts "PC=<n> SP=<n> STATUS=<n> R1=<n> R2=<n> R3=<n> R4=<n> R5=<n>"
# from either tool's stdout, normalizing hex/decimal so format
# differences (Nemu prints STATUS as 0xXXXXXXXX, RTL prints it as bare
# hex with no leading zeros) don't cause false mismatches.
extract_state() {
    local out="$1"
    local pc sp status
    pc="$(echo "$out" | grep -oE 'PC=[0-9]+' | head -1 | cut -d= -f2)"
    sp="$(echo "$out" | grep -oE 'SP=[0-9]+' | head -1 | cut -d= -f2)"
    status="$(echo "$out" | grep -oE 'STATUS=(0x)?[0-9A-Fa-f]+' | head -1 | cut -d= -f2)"
    status=$((16#${status#0x}))
    echo "PC=$pc SP=$sp STATUS=$status"
    for r in 1 2 3 4 5; do
        echo "R$r=$(echo "$out" | grep -oE "R$r = [-0-9]+" | head -1 | awk '{print $3}')"
    done
}

run_one() {
    local nuasm_path="$1" label="$2"
    local bin="$WORKDIR/prog.bin" hexf="$WORKDIR/prog.hex"

    "$NUASM" "$nuasm_path" "$bin" > "$WORKDIR/asm.log" 2>&1 || {
        echo "SKIP  $label: nuasm assembly failed"; cat "$WORKDIR/asm.log"; return 2;
    }
    xxd -p -c1 "$bin" > "$hexf"

    local nemu_out rtl_out
    nemu_out="$("$NEURON_CLI" "$bin" 2>&1)"
    rtl_out="$("$CORE_TB" +HEXFILE="$hexf" 2>&1)"

    local nemu_state rtl_state
    nemu_state="$(extract_state "$nemu_out")"
    rtl_state="$(extract_state "$rtl_out")"

    if [[ "$nemu_state" == "$rtl_state" ]]; then
        echo "PASS  $label"
        return 0
    else
        echo "FAIL  $label"
        echo "  program: $nuasm_path"
        echo "  Nemu:  $(echo "$nemu_state" | tr '\n' ' ')"
        echo "  RTL:   $(echo "$rtl_state" | tr '\n' ' ')"
        return 1
    fi
}

pass=0
fail=0

if [[ "$mode" == "single" ]]; then
    if [[ -z "$program" ]]; then
        echo "usage: $0 path/to/program.nuasm | --random --seed N [--count C]" >&2
        exit 1
    fi
    if run_one "$program" "$(basename "$program")"; then pass=$((pass+1)); else fail=$((fail+1)); fi
else
    for ((i = 0; i < count; i++)); do
        seed=$((seed_start + i))
        prog="$WORKDIR/random_seed_${seed}.nuasm"
        python3 "$SCRIPT_DIR/gen_random_program.py" --seed "$seed" --count "$program_size" --out "$prog"
        # Keep the failing program around for reproduction instead of
        # letting the trap clean it up.
        if run_one "$prog" "random seed=$seed"; then
            pass=$((pass+1))
        else
            fail=$((fail+1))
            keep="$ROOT_DIR/tb/build/diff_fail_seed_${seed}.nuasm"
            cp "$prog" "$keep"
            echo "  saved: $keep  (reproduce with: scripts/diff_test.sh $keep)"
        fi
    done
fi

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
