---
name: hermes-dashboard-windows
description: "Run Hermes dashboard on Windows via Go and Node LTS."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [hermes, dashboard, windows, go, nodejs, setup]
    homepage: https://github.com/NousResearch/hermes-agent
    related_skills: [hermes-agent]
---

# Hermes Dashboard on Windows

**When to Use:** You need to install, build, and run the Hermes Agent web dashboard (`hermes dashboard`) on a Windows machine, binding to a specific host/port (e.g., `0.0.0.0:12000`).

End‑to‑end workflow to get `hermes dashboard` running on Windows, binding to a custom host/port (e.g. `0.0.0.0:12000`).

## Prerequisites
- **Go** ≥ 1.22 (Scoop: `scoop install go`)
- **Node.js LTS** v24.x (Scoop: `scoop install nodejs-lts && scoop reset nodejs-lts`)

## Steps
1. `scoop install go` → verify `go version`.
2. `scoop install nodejs-lts && scoop reset nodejs-lts` → verify `node --version` shows v24.x.
3. `go install github.com/NousResearch/hermes-agent/cmd/hermes@latest` (adds `hermes.exe` to `%USERPROFILE%\go\bin`).
4. Build front‑end:
   ```bash
   cd "%USERPROFILE%\go\pkg\mod\github.com\!nous\!research\hermes-agent@<version>\web"
   npm ci && npm run build
   ```
5. Run dashboard:
   ```bash
   hermes dashboard --host 0.0.0.0 --port 12000 --no-open
   ```

## Common Pitfalls
| Symptom | Fix |
|---|---|
| `go install …/cmd/dashboard` missing package | Dashboard is part of `hermes` CLI; install `hermes` instead. |
| `npm ci` engine error for `nanoid@6` | Use Node LTS v24, not newer `nodejs`. |
| “Web UI npm install failed” | Run the build steps in the `web/` folder. |

## References
- `references/windows-node-version.md`
- `references/dashboard-build-steps.md`