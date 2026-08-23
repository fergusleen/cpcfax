#!/usr/bin/env python3
"""
Build a bitmap-backed CPC Mode 0 menu background for AMSNET.

Output is raw screen RAM bytes for loading at &C000.
"""

from __future__ import annotations

import argparse
from pathlib import Path

WIDTH = 160
HEIGHT = 200
SCREEN_BYTES = 0x4000


def clamp(v: int, lo: int, hi: int) -> int:
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v


class Canvas:
    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.pix = [bytearray(w) for _ in range(h)]

    def pset(self, x: int, y: int, c: int) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.pix[y][x] = c & 0x0F

    def fill(self, c: int) -> None:
        v = c & 0x0F
        for y in range(self.h):
            self.pix[y][:] = bytes((v,)) * self.w

    def rect(self, x1: int, y1: int, x2: int, y2: int, c: int, fill: bool = False) -> None:
        xa = clamp(min(x1, x2), 0, self.w - 1)
        xb = clamp(max(x1, x2), 0, self.w - 1)
        ya = clamp(min(y1, y2), 0, self.h - 1)
        yb = clamp(max(y1, y2), 0, self.h - 1)
        if fill:
            for y in range(ya, yb + 1):
                row = self.pix[y]
                row[xa : xb + 1] = bytes((c & 0x0F,)) * (xb - xa + 1)
            return
        for x in range(xa, xb + 1):
            self.pset(x, ya, c)
            self.pset(x, yb, c)
        for y in range(ya, yb + 1):
            self.pset(xa, y, c)
            self.pset(xb, y, c)

    def hline(self, x1: int, x2: int, y: int, c: int) -> None:
        if y < 0 or y >= self.h:
            return
        xa = clamp(min(x1, x2), 0, self.w - 1)
        xb = clamp(max(x1, x2), 0, self.w - 1)
        self.pix[y][xa : xb + 1] = bytes((c & 0x0F,)) * (xb - xa + 1)


FONT_5X7 = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
}


def draw_char(c: Canvas, ch: str, x: int, y: int, pen: int, scale: int) -> int:
    glyph = FONT_5X7.get(ch)
    if glyph is None:
        return x + (6 * scale)
    for gy, row in enumerate(glyph):
        for gx, bit in enumerate(row):
            if bit != "1":
                continue
            px = x + gx * scale
            py = y + gy * scale
            c.rect(px, py, px + scale - 1, py + scale - 1, pen, fill=True)
    return x + (6 * scale)


def draw_text(c: Canvas, text: str, x: int, y: int, pen: int, scale: int) -> None:
    cx = x
    for ch in text:
        if ch == " ":
            cx += 4 * scale
            continue
        cx = draw_char(c, ch, cx, y, pen, scale)


def build_bitmap() -> bytes:
    c = Canvas(WIDTH, HEIGHT)

    # Base background with subtle dither for a bitmap feel.
    c.fill(1)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if ((x * 3 + y * 5) & 0x1F) == 0:
                c.pset(x, y, 0)

    # Outer double frame.
    c.rect(2, 2, WIDTH - 3, HEIGHT - 3, 3, fill=False)
    c.rect(6, 6, WIDTH - 7, HEIGHT - 7, 2, fill=False)

    # Title plate.
    c.rect(12, 12, WIDTH - 13, 48, 2, fill=True)
    c.rect(12, 12, WIDTH - 13, 48, 3, fill=False)
    draw_text(c, "AMSNET", 36, 18, 3, 3)

    # Loading bar frame + prefilled blocks.
    c.rect(20, 56, WIDTH - 21, 72, 3, fill=False)
    for i in range(10):
        x1 = 23 + i * 13
        x2 = x1 + 10
        pen = 3 if (i & 1) == 0 else 2
        c.rect(x1, 59, x2, 69, pen, fill=True)

    # Main options panel.
    c.rect(14, 82, WIDTH - 15, HEIGHT - 18, 0, fill=True)
    c.rect(14, 82, WIDTH - 15, HEIGHT - 18, 3, fill=False)
    c.hline(18, WIDTH - 19, 110, 2)
    c.hline(18, WIDTH - 19, 134, 2)
    c.hline(18, WIDTH - 19, 158, 2)

    # Corner accents.
    c.rect(10, 78, 20, 88, 2, fill=True)
    c.rect(WIDTH - 21, 78, WIDTH - 11, 88, 2, fill=True)
    c.rect(10, HEIGHT - 24, 20, HEIGHT - 14, 2, fill=True)
    c.rect(WIDTH - 21, HEIGHT - 24, WIDTH - 11, HEIGHT - 14, 2, fill=True)

    def pack_mode0_pair(left_pen: int, right_pen: int) -> int:
        b = 0
        if left_pen & 0x1:
            b |= 0x80
        if left_pen & 0x2:
            b |= 0x08
        if left_pen & 0x4:
            b |= 0x20
        if left_pen & 0x8:
            b |= 0x02
        if right_pen & 0x1:
            b |= 0x40
        if right_pen & 0x2:
            b |= 0x04
        if right_pen & 0x4:
            b |= 0x10
        if right_pen & 0x8:
            b |= 0x01
        return b

    screen = bytearray(SCREEN_BYTES)
    for y in range(HEIGHT):
        row = c.pix[y]
        base = (y & 0x07) * 0x800 + (y >> 3) * 80
        for xb in range(80):
            p0 = row[xb * 2]
            p1 = row[xb * 2 + 1]
            screen[base + xb] = pack_mode0_pair(p0, p1)
    return bytes(screen)


def main() -> None:
    ap = argparse.ArgumentParser(description="Build AMSNET Mode 0 bitmap background")
    ap.add_argument("--out-raw", required=True, help="Output raw screen file")
    args = ap.parse_args()

    out = Path(args.out_raw)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(build_bitmap())
    print(f"Wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
