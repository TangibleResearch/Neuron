#!/usr/bin/env bash
# Builds the Renode CPU-cosimulation shared library (libVtop.dylib/.so) and
# a standalone socket-based executable (Vtop) for Neuron32, using Renode's
# IntegrationLibrary + Verilator.
#
# Requires a local clone of github.com/renode/renode (for
# src/Plugins/CoSimulationPlugin/IntegrationLibrary) — NOT the Renode.app
# bundle, the actual source tree. Point RENODE_SRC_DIR at it:
#
#   git clone --depth 1 https://github.com/renode/renode.git /path/to/renode-src
#   RENODE_SRC_DIR=/path/to/renode-src renode/build.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${RENODE_SRC_DIR:-}" ]]; then
    echo "error: set RENODE_SRC_DIR to a local clone of github.com/renode/renode" >&2
    echo "  git clone --depth 1 https://github.com/renode/renode.git /path/to/renode-src" >&2
    exit 1
fi

mkdir -p "$SCRIPT_DIR/build"
cd "$SCRIPT_DIR/build"

cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
    -DUSER_RENODE_DIR="$RENODE_SRC_DIR" \
    ..

cmake --build . --config Release

echo
echo "built: $SCRIPT_DIR/build/libVtop.dylib (or .so on Linux)"
echo "built: $SCRIPT_DIR/build/Vtop (standalone socket executable)"
