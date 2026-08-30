#!/usr/bin/env python
"""Reliable in-app navigation for the Tarazin Edge window (chord hotkeys)."""
import subprocess, sys, time
from windows_mcp_client import McpClient

BASE = "http://127.0.0.1:5050/mcp"
EDGE = "0x2704CE"

def _client_nav(c, url):
    subprocess.run(["powershell", "-NoProfile", "-Command", f"Set-Clipboard -Value '{url}'"],
                   capture_output=True)
    c.call("windows.activate", {"windowId": EDGE})
    time.sleep(1)
    c.call("mouse.click", {"x": 300, "y": 44})      # real input focus in address bar
    time.sleep(0.7)
    c.call("keyboard.hotkey", {"chord": "ctrl+l"})   # focus address bar
    time.sleep(0.7)
    c.call("keyboard.hotkey", {"chord": "ctrl+a"})   # select existing URL
    time.sleep(0.7)
    c.call("keyboard.hotkey", {"chord": "ctrl+v"})   # paste new URL
    time.sleep(0.7)
    c.call("keyboard.hotkey", {"chord": "enter"})    # navigate
    time.sleep(4)


def main_quiet(url):
    c = McpClient(BASE)
    c.initialize()
    _client_nav(c, url)


def main():
    url = sys.argv[1]
    c = McpClient(BASE)
    c.initialize()
    _client_nav(c, url)
    print("navigated:", url)

if __name__ == "__main__":
    main()