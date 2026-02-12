#!/usr/bin/env python3
import argparse
import os
from pathlib import Path

def pad8(s: str) -> bytes:
    s = s.upper()
    if len(s) > 8:
        s = s[:8]
    return s.encode("ascii") + b" " * (8 - len(s))

def pad3(s: str) -> bytes:
    s = s.upper()
    if len(s) > 3:
        s = s[:3]
    return s.encode("ascii") + b" " * (3 - len(s))

def u16le(n: int) -> bytes:
    return bytes((n & 0xFF, (n >> 8) & 0xFF))

def main():
    ap = argparse.ArgumentParser(description="Add AMSDOS header to a CPC binary.")
    ap.add_argument("infile", help="Input raw binary (no header).")
    ap.add_argument("outfile", help="Output file with AMSDOS header.")
    ap.add_argument("--name", default="H", help="8.3 filename (name part). Default: H")
    ap.add_argument("--ext", default="BIN", help="8.3 extension. Default: BIN")
    ap.add_argument("--load", default="0x8000", help="Load address (hex like 0x8000 or &8000).")
    ap.add_argument("--exec", default="0x8000", help="Exec address (hex).")
    args = ap.parse_args()

    def parse_addr(s: str) -> int:
        s = s.strip()
        if s.startswith("&"):
            return int(s[1:], 16)
        return int(s, 0)

    load_addr = parse_addr(args.load)
    exec_addr = parse_addr(args.exec)

    raw = Path(args.infile).read_bytes()
    length = len(raw)

    if length > 0xFFFFFF:
        raise SystemExit("File too large for AMSDOS 24-bit length field.")

    hdr = bytearray(128)
    # 0: user number
    hdr[0] = 0x00
    # 1..8: name
    hdr[1:9] = pad8(args.name)
    # 9..11: ext
    hdr[9:12] = pad3(args.ext)
    # 12..15: zeros already
    # 16..17: block number/last block (not used) -> 0
    hdr[16] = 0
    hdr[17] = 0
    # 18: file type: 2 = unprotected binary :contentReference[oaicite:2]{index=2}
    hdr[18] = 0x02
    # 19..20: "data length" (not really used for disc); set to length low 16 bits
    hdr[19:21] = u16le(length & 0xFFFF)
    # 21..22: load address :contentReference[oaicite:3]{index=3}
    hdr[21:23] = u16le(load_addr)
    # 23: first block (for output files); set to FF as common convention :contentReference[oaicite:4]{index=4}
    hdr[23] = 0xFF
    # 24..25: logical length (bytes) :contentReference[oaicite:5]{index=5}
    hdr[24:26] = u16le(length & 0xFFFF)
    # 26..27: entry address (exec) :contentReference[oaicite:6]{index=6}
    hdr[26:28] = u16le(exec_addr)
    # 64..66: 24-bit length (excluding header) :contentReference[oaicite:7]{index=7}
    hdr[64] = length & 0xFF
    hdr[65] = (length >> 8) & 0xFF
    hdr[66] = (length >> 16) & 0xFF

    # 67..68: checksum = sum of bytes 0..66 inclusive, little-endian :contentReference[oaicite:8]{index=8}
    csum = sum(hdr[0:67]) & 0xFFFF
    hdr[67] = csum & 0xFF
    hdr[68] = (csum >> 8) & 0xFF

    out = bytes(hdr) + raw
    Path(args.outfile).write_bytes(out)
    print(f"Wrote {args.outfile}: header(128)+data({length}) = {len(out)} bytes, load={hex(load_addr)}, exec={hex(exec_addr)}")

if __name__ == "__main__":
    main()
