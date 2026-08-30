#!/usr/bin/env python3
"""Decode a PNG capture (stdlib only) and report rows/columns that contain a target color.

Usage: png_teal_scan.py <png> [x0,y0,x1,y1]
Scans the region and prints the horizontal bands where target-teal-ish pixels are dense,
so you can locate buttons/fields by color on screen.
"""
import struct
import sys
import zlib


def load_png(path):
    """Return (width, height, pixels) where pixels is a list of rows of (r,g,b,a)."""
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a png"
    pos = 8
    width = height = None
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        ctype = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        if ctype == b"IHDR":
            width, height, bitdepth, colortype = struct.unpack(">IIBB", chunk[:10])
            assert bitdepth == 8
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break
        pos += 12 + length
    raw = zlib.decompress(idat)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[colortype]
    stride = width * channels
    pixels = []
    prev = bytearray(stride)
    i = 0
    for _ in range(height):
        ft = raw[i]; i += 1
        line = bytearray(raw[i : i + stride]); i += stride
        if ft == 1:
            for c in range(channels, len(line)):
                line[c] = (line[c] + line[c - channels]) & 255
        elif ft == 2:
            for c in range(len(line)):
                line[c] = (line[c] + prev[c]) & 255
        elif ft == 3:
            for c in range(len(line)):
                a = line[c - channels] if c >= channels else 0
                line[c] = (line[c] + ((a + prev[c]) >> 1)) & 255
        elif ft == 4:
            for c in range(len(line)):
                a = line[c - channels] if c >= channels else 0
                b = prev[c]
                cc = prev[c - channels] if c >= channels else 0
                d = prev[c + channels] if c + channels < len(line) else 0
                line[c] = (line[c] + (a + b - cc + d)) & 255
        px = []
        for cx in range(width):
            off = cx * channels
            if colortype == 6:
                px.append((line[off], line[off + 1], line[off + 2], line[off + 3]))
            elif colortype == 2:
                px.append((line[off], line[off + 1], line[off + 2], 255))
            elif colortype == 0:
                px.append((line[off], line[off], line[off], 255))
            else:
                px.append((line[off], line[off], line[off], 255))
        pixels.append(px)
        prev = line
    return width, height, pixels


def is_tealish(rgb, tol=22):
    r, g, b = rgb[:3]
    # teal families seen: #0B3A38, #0E4D4A, #163A4A, #2C625D, #21534D, #255348, #3A6A54
    return (g > 36 and g > r and (g - r) > 10 and abs(g - b) <= 50)


def main():
    path = sys.argv[1]
    w, h, px = load_png(path)
    x0, y0, x1, y1 = 0, 0, w, h
    if len(sys.argv) >= 6:
        x0, y0, x1, y1 = (int(a) for a in sys.argv[2:6])
    # row density
    rows = []
    for y in range(y0, min(y1, h)):
        cnt = sum(1 for x in range(x0, min(x1, w)) if is_tealish(px[y][x]))
        rows.append((y, cnt))
    # group contiguous rows with enough teal
    bands = []
    cur = None
    for y, cnt in rows:
        on = cnt >= 8
        if on and cur is None:
            cur = [y, y]
        elif on:
            cur[1] = y
        elif cur is not None:
            bands.append(tuple(cur)); cur = None
    if cur: bands.append(tuple(cur))
    print(f"size={w}x{h} scan=({x0},{y0})-({min(x1,w)},{min(y1,h)}) teal-bands:")
    for band in bands:
        yA, yB = band
        yc = (yA + yB) // 2
        # width of teal in middle row
        mid = flagcnt = 0
        xs = [x for x in range(x0, min(x1, w)) if is_tealish(px[yc][x])]
        if xs:
            xs.sort()
            start = prevx = xs[0]
            best = (0, 0, 0)
            cur = (start, start)
            for x in xs[1:]:
                if x > prevx + 2:
                    if cur[1] - cur[0] > best[1] - best[0]:
                        best = cur
                    cur = (x, x)
                else:
                    cur = (cur[0], x)
                prevx = x
            if cur[1] - cur[0] > best[1] - best[0]:
                best = cur
            print(f"  band y={yA}-{yB} h={yB-yA+1} midrow={yc} teal x-run: {best[0]}-{best[1]} (wid={best[1]-best[0]+1})")
        else:
            print(f"  band y={yA}-{yB}")


if __name__ == "__main__":
    main()