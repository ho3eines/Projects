#!/usr/bin/env python3
"""Fast, dependency-free Streamable HTTP client for the local screen_windows MCP."""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from typing import Any

DEFAULT_URL = os.getenv("WINDOWS_MCP_URL", "http://127.0.0.1:5050/mcp")


class McpError(RuntimeError):
    pass


class McpClient:
    def __init__(self, url: str, timeout: float = 10.0) -> None:
        self.url = url
        self.timeout = timeout
        self._next_id = 1
        self._session_id: str | None = None

    def _request(self, method: str, params: dict[str, Any] | None = None, expect_response: bool = True) -> Any:
        request_id = self._next_id
        self._next_id += 1
        payload: dict[str, Any] = {"jsonrpc": "2.0", "method": method}
        if expect_response:
            payload["id"] = request_id
        if params is not None:
            payload["params"] = params
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        if self._session_id:
            headers["Mcp-Session-Id"] = self._session_id
        request = urllib.request.Request(
            self.url,
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                self._session_id = response.headers.get("Mcp-Session-Id", self._session_id)
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise McpError(f"MCP HTTP {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise McpError(f"MCP connection failed: {exc}") from exc

        if not expect_response:
            return None
        return self._parse_response(raw)

    @staticmethod
    def _parse_response(raw: str) -> dict[str, Any]:
        raw = raw.strip()
        if not raw:
            raise McpError("MCP returned an empty response")
        if raw.startswith("data:") or "event:" in raw:
            data_lines: list[str] = []
            for line in raw.splitlines():
                if line.startswith("data:"):
                    data_lines.append(line[5:].lstrip())
            data = "\n".join(data_lines).strip()
            if data and data != "[DONE]":
                return json.loads(data)
            raise McpError("MCP returned an empty SSE response")
        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            raise McpError(f"Invalid MCP response: {raw[:300]}") from exc

    def initialize(self) -> dict[str, Any]:
        result = self._request(
            "initialize",
            {
                "protocolVersion": "2025-03-26",
                "capabilities": {},
                "clientInfo": {"name": "tarazin-windows-mcp-client", "version": "1.0"},
            },
        )
        self._request("notifications/initialized", {}, expect_response=False)
        return result

    def call(self, tool: str, arguments: dict[str, Any] | None = None) -> Any:
        response = self._request("tools/call", {"name": tool, "arguments": arguments or {}})
        if "error" in response:
            raise McpError(json.dumps(response["error"], ensure_ascii=False))
        return response.get("result", response)


def main() -> int:
    parser = argparse.ArgumentParser(description="Fast local screen_windows MCP client")
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--timeout", type=float, default=10.0)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("screen", help="Get screen metadata")
    sub.add_parser("list-windows", help="List visible top-level windows")
    call = sub.add_parser("call", help="Call any MCP tool explicitly")
    call.add_argument("tool")
    call.add_argument("arguments", nargs="?", default="{}")
    args = parser.parse_args()

    client = McpClient(args.url, args.timeout)
    try:
        client.initialize()
        if args.command == "screen":
            result = client.call("computer.get_screen")
        elif args.command == "list-windows":
            result = client.call("windows.list")
        else:
            result = client.call(args.tool, json.loads(args.arguments))
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (McpError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
