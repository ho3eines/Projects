#!/usr/bin/env python3
"""Find uniform filled rectangles in a PNG region that contrast with the background.

Usage: png_boxes.py <png> x0 y0 x1 y1
Scans for runs of pixels whose color differs from the local dominant background and
prints bounding boxes of the resulting connected components (approx. by horizontal runs).
"""
import os
import sys
import tempfile
from png_teal_scan import load_png


def dominant_color(pix, x0, y0, x1, y1):
    from collections import Counter
    c = Counter()
    for yy in range(y0, min(y1, len(pix)), 3):
        for xx in range(x0, min(x1, len(pix[0])), 3):
            c[(pix[yy][xx][0] >> 4 << 4, pix[yy][xx][1] >> 4 << 4, pix[yy][xx][2] >> 4 << 4)] += 1
    return c.most_common(1)[0][0]


def main():
    path = sys.argv[1]
    x0, y0, x1, y1 = (int(a) for a in sys.argv[2:6])
    if not os.path.exists(path):
        path = os.path.join(tempfile.gettempdir(), path)
    w, h, pix = load_png(path)
    bg = dominant_color(pix, x0, y0, min(x1, w), min(y1, h))
    print("bg(quantized):", bg)
    R, G, B = bg

    def diff(p):
        r, g, b = p[:3]
        return abs(r - R) + abs(g - G) + abs(b - B)

    TH = 26
    # horizontal runs per row
    runs = []  # (x0,x1)
    for yy in range(y0, y1):
        row = []
        inrun = False
        start = None
        for xx in range(x0, x1):
            on = diff(pix[yy][xx]) > TH
            if on and not inrun:
                inrun = True; start = xx
            elif on and inrun:
                pass
            elif not on and inrun:
                if xx - start >= 3:
                    row.append((start, xx - 1))
                inrun = False
        if inrun and x1 - start >= 3:
            row.append((start, x1 - 1))
        runs.append(row)
    # group rows that overlap horizontally into boxes
    boxes = []
    for yy, row in enumerate(runs):
        yabs = y0 + yy
        if not row:
            continue
        for (s, e) in row:
            placed = False
            for bi, b in enumerate(boxes):
                if s <= b[2] + 2 and e >= b[0] - 2 and yabs <= b[3] + 3 and yabs >= b[1] - 3:
                    b[0] = min(b[0], s); b[1] = min(b[1], yabs)
                    b[2] = max(b[2], e); b[3] = max(b[3], yabs)
                    placed = True
                    break
            if not placed:
                boxes.append([s, yabs, e, yabs])
    # merge nearby boxes in same column band
    merged = boxes
    merged.sort(key=lambda b: (b[1], b[0]))
    result = []
    for b in merged:
        if b[2] - b[0] >= 30 and b[3] - b[1] >= 8:
            result.append(tuple(b))
    result.sort(key=lambda b: b[1])
    for b in result:
        cx = (b[0] + b[2]) // 2
        cy = (b[1] + b[3]) // 2
        print(f"BOX x{b[0]}-{b[2]} y{b[1]}-{b[3]}  center=({cx},{cy})  w={b[2]-b[0]+1} h={b[3]-b[1]+1}")


if __name__ == "__main__":
    main()