#!/usr/bin/env python3
"""
Generate tokenized AMSDOS BASIC launcher files for the AMSNET combined disk.
"""

from __future__ import annotations

import argparse
from pathlib import Path

TOKENS = {
    "BORDER": 0x82,
    "CALL": 0x83,
    "CLS": 0x8A,
    "DRAW": 0x94,
    "END": 0x98,
    "FILL": 0xDD,
    "GRAPHICS": 0xDE,
    "GOTO": 0xA0,
    "IF": 0xA1,
    "INK": 0xA2,
    "LOAD": 0xA8,
    "LOCATE": 0xA9,
    "MEMORY": 0xAA,
    "MODE": 0xAD,
    "MOVE": 0xAE,
    "ORIGIN": 0xB8,
    "PAPER": 0xBA,
    "PEN": 0xBB,
    "PRINT": 0xBF,
    "RUN": 0xCA,
    "THEN": 0xEB,
}

SEP = bytes((0x01,))  # statement separator
OP_EQ = bytes((0xEF,))  # "=" operator (also used for assignment)
FUN_CHR = bytes((0xFF, 0x03))  # CHR$
FUN_INKEY_DOLLAR = bytes((0xFF, 0x43))  # INKEY$


def le16(n: int) -> bytes:
    return bytes((n & 0xFF, (n >> 8) & 0xFF))


def kw(name: str) -> bytes:
    return bytes((TOKENS[name],))


def num16(n: int) -> bytes:
    if n < 0 or n > 0xFFFF:
        raise ValueError(f"constant out of range: {n}")
    if n <= 10:
        return bytes((0x0E + n,))
    if n <= 0xFF:
        return bytes((0x19, n))
    if n <= 0x7FFF:
        return bytes((0x1A, n & 0xFF, (n >> 8) & 0xFF))
    # Values above BASIC's signed decimal range must be represented as hex.
    return bytes((0x1C, n & 0xFF, (n >> 8) & 0xFF))


def line_ref(n: int) -> bytes:
    if n < 0 or n > 0xFFFF:
        raise ValueError(f"line number out of range: {n}")
    return bytes((0x1E, n & 0xFF, (n >> 8) & 0xFF))


def q(s: str) -> bytes:
    return b'"' + s.encode("ascii") + b'"'


def svar(name: str) -> bytes:
    up = name.upper()
    if not up or len(up) > 31:
        raise ValueError("string variable must be 1..31 chars")
    prefix = up[:-1].encode("ascii")
    final = bytes((ord(up[-1]) | 0x80,))
    return bytes((0x03, 0x00, 0x00)) + prefix + final


def rsx(name: str) -> bytes:
    up = name.upper()
    if not up:
        raise ValueError("rsx name cannot be empty")
    prefix = up[:-1].encode("ascii")
    final = bytes((ord(up[-1]) | 0x80,))
    # RSX command token is '|' followed by a zero byte then command name.
    return bytes((0x7C, 0x00)) + prefix + final


def line(line_no: int, body: bytes) -> bytes:
    rec = bytearray(b"\x00\x00")
    rec += le16(line_no)
    rec += body
    rec += b"\x00"
    rec[0:2] = le16(len(rec))
    return bytes(rec)


def amsdos_header(payload: bytes, name: str, ext: str = "BAS", file_type: int = 0) -> bytes:
    name8 = name.upper()[:8].ljust(8).encode("ascii")
    ext3 = ext.upper()[:3].ljust(3).encode("ascii")
    length = len(payload)

    hdr = bytearray(128)
    hdr[0] = 0x00
    hdr[1:9] = name8
    hdr[9:12] = ext3
    hdr[18] = file_type & 0xFF
    hdr[19:21] = le16(length & 0xFFFF)
    hdr[21:23] = le16(0x0170)  # BASIC load address
    hdr[23] = 0xFF
    hdr[24:26] = le16(length & 0xFFFF)
    hdr[26:28] = le16(length & 0xFFFF)
    hdr[64] = length & 0xFF
    hdr[65] = (length >> 8) & 0xFF
    hdr[66] = (length >> 16) & 0xFF
    checksum = sum(hdr[0:67]) & 0xFFFF
    hdr[67:69] = le16(checksum)
    return bytes(hdr) + payload


def menu_program() -> bytes:
    lines: list[str] = []
    next_line = 10

    def add(body: str) -> int:
        nonlocal next_line
        line_no = next_line
        lines.append(f"{line_no} {body}")
        next_line += 10
        return line_no

    def locate_print(x: int, y: int, text: str, pen: int | None = None) -> None:
        if pen is not None:
            add(f"PEN {pen}")
        add(f"LOCATE {x},{y}")
        add(f'PRINT "{text}"')

    # Store the menu as ASCII BASIC and let the CPC ROM perform tokenisation.
    # Keep every statement on its own line so runtime errors remain precise.
    add("MODE 1")
    add("BORDER 0")
    add("INK 0,1")
    add("INK 1,24")
    add("INK 2,20")
    add("PAPER 0")
    add("PEN 1")
    add("CLS")

    locate_print(3, 3, "AMMSTAR   2025 ", pen=2)
    locate_print(3, 4, "------------------------------------", pen=2)
    locate_print(3, 7, "Press:", pen=1)
    locate_print(3, 10, "1")
    locate_print(6, 10, "VIEWDATA", pen=2)
    locate_print(18, 10, "Mode", pen=1)
    locate_print(6, 12, "Prestel, Micronet 800, etc...")
    locate_print(3, 15, "2")
    locate_print(6, 15, "ASCII/ANSI", pen=2)
    locate_print(18, 15, "Mode", pen=1)
    locate_print(6, 17, "BT GOLD, Bulletin Boards, etc...")
    locate_print(8, 21, "github.com/fergusleen/amsnet", pen=2)
    locate_print(3, 22, "------------------------------------", pen=2)
    locate_print(3, 24, "ESC returns to BASIC", pen=1)

    key_loop = next_line
    exit_line = key_loop + 60
    add("a$=INKEY$")
    add('IF a$="" THEN CALL &BD19')
    add('IF a$="1" THEN RUN "CPCFAX.BIN"')
    add('IF a$="2" THEN RUN "M4TERM.BAS"')
    add(f"IF a$=CHR$(27) THEN GOTO {exit_line}")
    add(f"GOTO {key_loop}")
    add("MODE 2")
    add("END")
    return ("\r\n".join(lines) + "\r\n\x1a").encode("ascii")


def m4term_program() -> bytes:
    source = [
        "5 REM M4TERM.BAS - https://github.com/fergusleen/m4ewenterm",
        "10 MEMORY &67FF",
        '20 LOAD "CHARSET.BIN",&6800',
        '30 LOAD "M4TERM.BIN",&7000',
        "40 CALL &7000",
        "50 MODE 2",
        "60 PEN 1",
        "70 PAPER 0:INK 1,19:INK 0,0:BORDER 0",
        "80 CLS",
        '90 PRINT "M4TERM installed."',
        "100 |TERM",
    ]
    return ("\r\n".join(source) + "\r\n\x1a").encode("ascii")


def disc_program() -> bytes:
    return line(10, kw("RUN") + b" " + q("AMSNET")) + b"\x00\x00"


def write_basic(path: Path, name: str, payload: bytes) -> None:
    path.write_bytes(amsdos_header(payload, name=name, ext="BAS", file_type=0))


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate BASIC launcher files for AMSNET disk.")
    parser.add_argument("--outdir", default="build/staging/amsnet", help="Output directory")
    args = parser.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    (outdir / "AMSNET.BAS").write_bytes(menu_program())
    (outdir / "M4TERM.BAS").write_bytes(m4term_program())
    write_basic(outdir / "DISC.BAS", "DISC", disc_program())

    print(f"Wrote BASIC launchers in {outdir}")


if __name__ == "__main__":
    main()
