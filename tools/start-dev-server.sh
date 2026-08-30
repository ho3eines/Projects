#!/usr/bin/env bash
# Start the Tarazin dev server in the background, log to a file.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
nohup dotnet run --project Tarazin.Web --no-build > /tmp/tarazin-dev.log 2>&1 &
echo "PID $!"
sleep 1
echo "started"
