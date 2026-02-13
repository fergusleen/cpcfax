# CPCFAX

Z80 Viewdata client for Amstrad CPC + M4 Board.

This project connects a CPC to telnet-style Viewdata services over wifi on the M4 board, with a UI and renderer designed for a classic CPC experience.

- Optimised Viewdata/teletext style rendering
- Profile presets (including `amshole` and `telstar`)
- Disk image output for CPCemu

## Building

```bash
bash tools/build.sh
```

Build output:

- `build/harness_m4.bin` (raw binary at `0x1000`)

Create an AMSDOS-ready binary and `.dsk`:

```bash
bash tools/make_dsk.sh
```

Expected outputs:

- `build/CPCFAX.BIN`
- `build/CPCFAX.dsk`

`make_dsk.sh` also copies the disk to:

- `~/Library/Application Support/CPCemu/DISC/`

## What You Need

- `sjasmplus` (local copy included at repo root)
- Python 3 (for AMSDOS header generation)
- `iDSK` (local copy included at repo root)
- CPC with M4 ROM (or CPCemu setup that matches your workflow)

## Run It

Boot your disk in CPCemu or on real hardware, then:

```basic
RUN"CPCFAX.BIN"
```

Pick a profile, enter or accept a host, and connect.

## Repo Layout

- `src/harness_m4.asm` main program and UI flow
- `src/vd_engine.asm` Viewdata parsing/render core
- `tools/build.sh` assemble raw binary
- `tools/make_dsk.sh` wrap binary + build `.dsk`
- `tools/add_amsdos_header.py` add AMSDOS header
