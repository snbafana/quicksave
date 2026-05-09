#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${QUICKSAVE_INSTALL_DIR:-$HOME/.local/bin}"

cd "$ROOT"
swift build -c release --product quicksave >/dev/null

mkdir -p "$INSTALL_DIR"
cp "$ROOT/.build/release/quicksave" "$INSTALL_DIR/quicksave"

echo "$INSTALL_DIR/quicksave"
