#!/usr/bin/env bash
# Regenerates sim/testvectors/*.hex from Nemu's .nuasm programs.
#
# Nemu (github.com/TangibleResearch/Nemu) is the reference software model
# and NuASM assembler for Neuron; this script assembles its example/test
# programs with the real `nuasm` tool and converts the resulting binaries
# into $readmemh-compatible hex (one byte per line) for use by
# sim/core_tb.sv and sim/neuron_sim.cpp.
#
# Usage: NEMU_DIR=/path/to/Nemu ./gen_testvectors.sh
set -euo pipefail

NEMU_DIR="${NEMU_DIR:-$HOME/Nemu}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/testvectors"

NUASM="$NEMU_DIR/target/release/nuasm"
if [[ ! -x "$NUASM" ]]; then
    echo "Building nuasm from $NEMU_DIR ..." >&2
    (cd "$NEMU_DIR" && cargo build --release --bin nuasm)
fi

mkdir -p "$OUT_DIR"

assemble_one() {
    local src="$1"
    local name
    name="$(basename "${src%.nuasm}")"
    "$NUASM" "$src" "$OUT_DIR/$name.bin"
    xxd -p -c1 "$OUT_DIR/$name.bin" > "$OUT_DIR/$name.hex"
    echo "assembled $name ($(wc -c < "$OUT_DIR/$name.bin") bytes)"
}

assemble_one "$NEMU_DIR/programs/hello.nuasm"
for f in "$NEMU_DIR"/programs/tests/*.nuasm; do
    assemble_one "$f"
done
