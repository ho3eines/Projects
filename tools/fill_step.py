#!/usr/bin/env python
"""Self-locating fill for the accounting entry table.

Re-captures the screen each step so scroll/reflow drift is handled:
  locate <- capture -> tesseract TSV -> localize cells
  fill   <- click + type
  verify <- fresh capture + read totals/debit line
Usage:
  python fill_step.py debit <amount>      # fill بدهکار of row N (default row 1)
  python fill_step.py credit <amount>
  python fill_step.py desc <text>
  python fill_step.py totals             # just report sums + balance chip
"""
import json, os, subprocess, sys, time, csv
from windows_mcp_client import McpClient

BASE = "http://127.0.0.1:5050/mcp"
EDGE = "0x2704CE"
PNG = "C:/Users/Ho3ein/AppData/Local/Temp/fl.png"
TSV = "C:/Users/Ho3ein/AppData/Local/Temp/fl.tsv"
TESS = "C:/Program Files/Tesseract-OCR/tesseract.exe"

def cap():
    subprocess.run(["python", "capture_to_file.py", "/tmp/fl.png"], capture_output=True)
    subprocess.run(["cp", "C:/Users/Ho3ein/AppData/Local/Temp/fl.png", PNG], capture_output=True)
    subprocess.run([TESS, PNG, "C:/Users/Ho3ein/AppData/Local/Temp/fl", "-l", "fas+eng", "--psm", "11", "tsv"],
                   capture_output=True)

def tsv_words(y0=0, y1=10000, x0=0, x1=1500, conf_min=22):
    out = []
    if not os.path.exists(TSV):
        return out
    with open(TSV, newline='', encoding='utf-8') as f:
        for r in csv.DictReader(f, delimiter='\t'):
            t = (r.get('text') or '').strip()
            if not t:
                continue
            try:
                conf = float(r.get('conf', '-1'))
            except Exception:
                conf = -1
            if conf < conf_min:
                continue
            y = int(r['top']); x = int(r['left'])
            if y0 <= y <= y1 and x0 <= x <= x1:
                out.append((y, x, t, conf))
    out.sort()
    return out

def locate_header():
    """Return {x_debit, x_credit, x_desc, header_y, row_y} for the lines table."""
    cap()
    words = tsv_words(0, 10000, 0, 1500)
    # header row: find 'بدهکار' and 'شرح' and 'حساب' in same y band
    debit = [w for w in words if w[2] == 'بدهکار']
    desc = [w for w in words if w[2] == 'شرح']
    if not debit or not desc:
        return None
    hy = max(w[0] for w in debit)          # header baseline
    xdeb = min(w[1] for w in debit)
    xdesc = min(w[1] for w in desc)
    xcre = None
    for w in words:
        if w[2] == 'بستانکار' and abs(w[0] - hy) < 12:
            xcre = w[1]; break
    # row1: search for the selected account text below header (بانک...) -> account row y
    row_y = None
    for w in words:
        if (w[2] == 'بانک' or w[2] == 'ملی') and w[0] > hy + 8 and w[0] < hy + 70 and w[1] > 900:
            row_y = w[0]; break
    if row_y is None:
        row_y = hy + 32  # dense row ~ (fallback)
    return dict(xdeb=xdeb, xcre=xcre, xdesc=xdesc, hy=hy, row=row_y)

def read_totals():
    cap()
    words = tsv_words(0, 10000, 0, 1500)
    deb = cred = chip = None
    for w in words:
        t = w[2]
        if 'جمع' in t and 'بدهکار' in t:
            deb = t
        if 'جمع' in t and 'بستانکار' in t:
            cred = t
        if 'متوازن' in t or 'نامتوازن' in t:
            chip = t
    return deb, cred, chip

def main():
    action = sys.argv[1]
    c = McpClient(BASE); c.initialize()
    loc = locate_header()
    print("loc:", loc)
    row_dy = max(0, (loc['row'] or 0) - (loc['hy'] or 0))
    # input vertical center for the row (a bit below account text)
    yin = loc['row'] + 6 if loc['row'] else loc['hy'] + 36
    if action in ('debit', 'credit'):
        val = sys.argv[2]
        x = loc['xdeb'] if action == 'debit' else loc['xcre']
        c.call("windows.activate", {"windowId": EDGE}); time.sleep(0.4)
        c.call("mouse.click", {"x": x, "y": yin}); time.sleep(0.6)
        c.call("keyboard.hotkey", {"chord": "ctrl+a"}); time.sleep(0.3)
        c.call("keyboard.type", {"text": val}); time.sleep(0.8)
        print(f"typed {val} into {action} at ({x},{yin})")
    elif action == 'desc':
        text = sys.argv[2]
        x = loc['xdesc']
        c.call("windows.activate", {"windowId": EDGE}); time.sleep(0.4)
        c.call("mouse.click", {"x": x, "y": yin}); time.sleep(0.6)
        c.call("keyboard.type", {"text": text}); time.sleep(0.6)
        print(f"typed desc at ({x},{yin})")
    time.sleep(1)
    deb, cred, chip = read_totals()
    print("TOTALS:", deb, "|", cred, "|", chip)

if __name__ == "__main__":
    main()