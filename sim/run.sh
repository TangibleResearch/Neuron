#!/usr/bin/env bash
# Assembles a .nuasm program with Nemu's real assembler and runs it on the
# actual Neuron32 RTL (via Verilator). This is the "just run some nuasm"
# entry point:
#
#   sim/run.sh path/to/program.nuasm
#
# Requires a local checkout of github.com/TangibleResearch/Nemu (the
# reference software model and NuASM assembler); point NEMU_DIR at it if
# it's not at ~/Nemu.
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 path/to/program.nuasm" >&2
    exit 1
fi

PROGRAM="$1"
NEMU_DIR="${NEMU_DIR:-$HOME/Nemu}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/build/vobj/neuron_sim"
NUASM="$NEMU_DIR/target/release/nuasm"

if [[ ! -x "$NUASM" ]]; then
    echo "Building nuasm from $NEMU_DIR ..." >&2
    (cd "$NEMU_DIR" && cargo build --release --bin nuasm)
fi

if [[ ! -x "$BIN" ]]; then
    echo "Building neuron_sim ..." >&2
    "$SCRIPT_DIR/build.sh"
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

"$NUASM" "$PROGRAM" "$WORKDIR/program.bin"
xxd -p -c1 "$WORKDIR/program.bin" > "$WORKDIR/program.hex"

"$BIN" +HEXFILE="$WORKDIR/program.hex"
