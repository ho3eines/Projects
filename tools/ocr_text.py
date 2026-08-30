#!/usr/bin/env python
"""Call vision.ocr and print only the recognized text lines."""
import json, subprocess, sys

def call_ocr(region):
    cmd = ["python", "windows_mcp_client.py", "call", "vision.ocr",
           json.dumps(region)]
    out = subprocess.run(cmd, capture_output=True, text=True,
                         encoding="utf-8", errors="replace").stdout
    try:
        obj = json.loads(out)
        text = obj["content"][0]["text"]
        data = json.loads(text)
        return data
    except Exception:
        return {"raw": out[-2000:]}

def main():
    x, y, w, h = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
    lang = sys.argv[5] if len(sys.argv) > 5 else "fa"
    data = call_ocr({"x": x, "y": y, "width": w, "height": h, "language": lang})
    if "lines" in data:
        for line in data["lines"]:
            print(line["text"])
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2)[:2000])

if __name__ == "__main__":
    main()