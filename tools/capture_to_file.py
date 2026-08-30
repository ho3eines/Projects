#!/usr/bin/env python3
"""Capture a window/screen via MCP and save the base64 image to a file."""
import base64
import json
import os
import sys

from windows_mcp_client import McpClient

DEFAULT_URL = os.getenv("WINDOWS_MCP_URL", "http://127.0.0.1:5050/mcp")


def main() -> int:
    args = sys.argv[1:]
    tool = "computer.capture_screen"
    params: dict = {"format": "png", "width": 1400}
    if args and args[0].endswith((".png", ".jpg", ".jpeg")):
        out = args[0]
        rest = args[1:]
    else:
        out = "tmp_screen.png"
        rest = args
    for a in rest:
        if "=" in a:
            k, v = a.split("=", 1)
            params[k] = int(v) if v.lstrip("-").isdigit() else v
        elif a == "screen":
            tool = "computer.capture_screen"
        else:
            tool = "computer.capture_region"
            parts = a.split(",")
            if len(parts) == 4:
                x, y, w, h = (int(p) for p in parts)
                params = {"x": x, "y": y, "width": w, "height": h, "format": "png"}
            elif len(parts) == 2:
                params = {"x": 0, "y": 0, "width": int(parts[0]), "height": int(parts[1]), "format": "png"}

    client = McpClient(DEFAULT_URL)
    client.initialize()
    result = client.call(tool, params)
    data = None
    for c in result.get("content", []):
        if c.get("type") == "image":
            data = c.get("data")
            break
    if not data:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 1
    with open(out, "wb") as f:
        f.write(base64.b64decode(data))
    print(f"saved {out} ({len(base64.b64decode(data))} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())