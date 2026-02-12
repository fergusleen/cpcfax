#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

#python3 "$ROOT/tools/gen_vectors.py"

mkdir -p "$ROOT/build"

ASM="sjasmplus"
if [[ -x "$ROOT/sjasmplus" ]]; then
  ASM="$ROOT/sjasmplus"
fi

"$ASM" --raw="$ROOT/build/harness_m4.bin" "$ROOT/src/harness_m4.asm"
