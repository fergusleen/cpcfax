#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RAW="$ROOT/build/harness_m4.bin"
HDR="$ROOT/build/CPCFAX.BIN"
DSK="$ROOT/build/CPCFAX.dsk"

# Create AMSDOS-headered runnable binary: RUN"H.BIN"
python3 "$ROOT/tools/add_amsdos_header.py" "$RAW" "$HDR" --name CPCFAX --ext BIN --load "&1000" --exec "&1000"


rm -f "$DSK"

# Create a blank data disk
"$ROOT/iDSK" "$DSK" -n

# Put the binary on it as HARNESS.BIN
"$ROOT/iDSK" "$DSK" -i "$HDR"
echo "Created $DSK with CPCFAX.BIN"
if [[ -d "$HOME/Library/Application Support/CPCemu/DISC/" ]]; then
  if cp "$DSK" "$HOME/Library/Application Support/CPCemu/DISC/cpcfax.dsk"; then
    echo "Copied $DSK to CPCemu DISC folder"
  else
    echo "Warning: could not copy to CPCemu DISC folder (continuing)." >&2
  fi
fi
