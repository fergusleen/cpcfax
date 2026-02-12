#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RAW="build/harness_m4.bin"      # your existing raw output
HDR="build/CPCFAX.BIN"                # headered file that AMSDOS can RUN
DSK="build/CPCFAX.dsk"

# Create AMSDOS-headered runnable binary: RUN"H.BIN"
python3 tools/add_amsdos_header.py "$RAW" "$HDR" --name CPCFAX --ext BIN --load "&1000" --exec "&1000"


rm -f "$DSK"

# Create a blank data disk
"$ROOT/iDSK" "$DSK" -n

# Put the binary on it as HARNESS.BIN
"$ROOT/iDSK" "$DSK" -i "$HDR"
echo "Created $DSK with CPCFAX.BIN"
cp build/cpcfax.dsk "$HOME/Library/Application Support/CPCemu/DISC/"
echo "Copied $DSK to CPCemu DISC folder"
