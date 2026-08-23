#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
STAGE_DIR="$BUILD_DIR/staging/amsnet"
DIST_DIR="$ROOT/dist"
DSK_PATH="$DIST_DIR/AMSNET.DSK"

RAW_CPCFAX="$BUILD_DIR/harness_m4.bin"
HDR_CPCFAX="$BUILD_DIR/CPCFAX.BIN"

M4_ROOT="${M4EWENTERM_ROOT:-$ROOT/../m4ewenterm}"
M4_BIN_DIR="$M4_ROOT/bin"
M4_RAW_BIN="$M4_BIN_DIR/EWENM4.BIN"
M4_CHARSET_BIN="$M4_BIN_DIR/CHARSET.BIN"

echo "==> Building CPCFAX core"
bash "$ROOT/tools/build.sh"
python3 "$ROOT/tools/add_amsdos_header.py" \
  "$RAW_CPCFAX" "$HDR_CPCFAX" \
  --name CPCFAX --ext BIN --load "&1000" --exec "&1000"

if [[ ! -d "$M4_ROOT" ]]; then
  echo "m4ewenterm repository not found at: $M4_ROOT" >&2
  echo "Set M4EWENTERM_ROOT or clone it beside cpcfax." >&2
  exit 1
fi

if [[ ! -f "$M4_RAW_BIN" || ! -f "$M4_CHARSET_BIN" ]]; then
  echo "==> Building m4ewenterm artifacts"
  mkdir -p "$M4_BIN_DIR"
  if [[ ! -x "$M4_ROOT/rasm" ]]; then
    if [[ -n "${RASM_BIN:-}" && -x "${RASM_BIN}" ]]; then
      cp "${RASM_BIN}" "$M4_ROOT/rasm"
      chmod +x "$M4_ROOT/rasm"
    elif [[ -x "$ROOT/../rasm/rasm" ]]; then
      cp "$ROOT/../rasm/rasm" "$M4_ROOT/rasm"
      chmod +x "$M4_ROOT/rasm"
    elif command -v rasm >/dev/null 2>&1; then
      cp "$(command -v rasm)" "$M4_ROOT/rasm"
      chmod +x "$M4_ROOT/rasm"
    else
      echo "RASM not found. Build it and pass RASM_BIN=/path/to/rasm." >&2
      exit 1
    fi
  fi
  (cd "$M4_ROOT" && ./build.sh)
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

echo "==> Generating BASIC launchers"
python3 "$ROOT/tools/build_amsnet_basic.py" --outdir "$STAGE_DIR"

echo "==> Staging AMSNET files"
cp "$HDR_CPCFAX" "$STAGE_DIR/CPCFAX.BIN"
cp "$M4_RAW_BIN" "$STAGE_DIR/M4TERM.BIN"
cp "$M4_CHARSET_BIN" "$STAGE_DIR/CHARSET.BIN"

# Safe brand touch-up in terminal banner string.
python3 -c 'from pathlib import Path; p=Path("'"$STAGE_DIR"'/M4TERM.BIN"); d=p.read_bytes(); p.write_bytes(d.replace(b"EwenM4", b"M4TERM"))'

cat > "$STAGE_DIR/README.TXT" <<'EOF'
AMSNET Combined Disk
====================

If autoboot does not trigger, run:
RUN"AMSNET"

Menu keys:
1 = CPCFAX (Viewdata)
2 = M4TERM (Terminal)
ESC = Exit to BASIC
EOF

mkdir -p "$DIST_DIR"
rm -f "$DSK_PATH"

echo "==> Building dist/AMSNET.DSK via iDSK"
"$ROOT/iDSK" "$DSK_PATH" -n
"$ROOT/iDSK" "$DSK_PATH" -i "$STAGE_DIR/DISC.BAS"
"$ROOT/iDSK" "$DSK_PATH" -i "$STAGE_DIR/AMSNET.BAS" -t 0
"$ROOT/iDSK" "$DSK_PATH" -i "$STAGE_DIR/CPCFAX.BIN"
"$ROOT/iDSK" "$DSK_PATH" -i "$STAGE_DIR/M4TERM.BAS" -t 0
"$ROOT/iDSK" "$DSK_PATH" -i "$STAGE_DIR/M4TERM.BIN"
"$ROOT/iDSK" "$DSK_PATH" -i "$STAGE_DIR/CHARSET.BIN"
"$ROOT/iDSK" "$DSK_PATH" -i "$STAGE_DIR/README.TXT" -t 0

echo "==> AMSNET disk directory"
"$ROOT/iDSK" "$DSK_PATH" -l

echo "Created $DSK_PATH"

echo "==> Copying AMSNET disk to CPCemu"
cp "$DSK_PATH" "/Users/fergus/Library/Application Support/CPCemu/DISC/AMSNET.DSK"
