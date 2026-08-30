#!/usr/bin/env python
"""Navigate each Tarazin module, OCR-read its content, save a screenshot per module."""
import json, subprocess, sys, time
from windows_mcp_client import McpClient
import nav

BASE = "http://127.0.0.1:5050/mcp"

MODULES = [
    ("bi", "https://localhost:65220/bi"),
    ("accounting", "https://localhost:65220/accounting"),
    ("inventory", "https://localhost:65220/inventory"),
    ("treasury", "https://localhost:65220/treasury"),
    ("store", "https://localhost:65220/store"),
    ("central", "https://localhost:65220/central"),
    ("goldshop", "https://localhost:65220/goldshop"),
    ("currency", "https://localhost:65220/currency"),
    ("payroll", "https://localhost:65220/payroll"),
    ("log", "https://localhost:65220/log"),
]

def ocr(x, y, w, h, lang="fa"):
    c = McpClient(BASE); c.initialize()
    r = c.call("vision.ocr", {"x": x, "y": y, "width": w, "height": h, "language": lang})
    data = json.loads(r["content"][0]["text"])
    return [l["text"] for l in data.get("lines", [])]

def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots-test"
    report = {}
    for name, url in MODULES:
        nav.main_quiet(url)
        time.sleep(2)
        lines = ocr(60, 150, 1240, 560)
        clean = [l for l in lines if l.strip()]
        report[name] = clean
        # screenshot
        cap = subprocess.run(["python", "windows_mcp_client.py", "call",
                              "computer.capture_window", json.dumps({"format": "png"})],
                             capture_output=True, text=True)
        png = outdir + f"/mod-{name}.png"
        print("=" * 60)
        print(f"[{name}] -> {png}")
        for l in clean[:28]:
            print("  ", l)
    # also save a combined text report
    with open(outdir + "/modules-report.txt", "w", encoding="utf-8") as f:
        for name, lines in report.items():
            f.write(f"===== {name} =====\n")
            f.write("\n".join(lines))
            f.write("\n\n")
    print("report written to", outdir + "/modules-report.txt")

if __name__ == "__main__":
    main()