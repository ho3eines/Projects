# Hermes Dashboard Front-End Build Steps

## Location
The front-end source lives in the Go module cache:
```
%USERPROFILE%\go\pkg\mod\github.com\!nous\!research\hermes-agent@<version>\web
```
where `<version>` is the pseudo-version Go fetched (e.g., `v2026.8.3+incompatible`).

## Build Commands
```bash
cd "%USERPROFILE%\go\pkg\mod\github.com\!nous\!research\hermes-agent@<version>\web"

# Clean install respecting lock-file
npm ci

# Compile TypeScript + bundle with Vite → outputs ./dist
npm run build
```

## Expected Output
```
> web@0.0.0 build
> tsc -b && vite build

vite v8.x.x building for production...
✓ 1234 modules transformed.
✓ built in 2.34s
dist/index.html                    0.45 kB
dist/assets/index-<hash>.css       12.3 kB
dist/assets/index-<hash>.js        245.6 kB
...
```

## Why This Is Required
The `hermes dashboard` command serves the SPA from `web/dist/`. If the folder is missing or stale, the CLI prints:
```
→ Building web UI...
  ✗ Web UI npm install failed
  Run manually:  npm install --workspace web && npm run build -w web
```
Running the build manually once (or in CI) avoids this failure on every start.

## Automation Tip
Add a one-liner to a setup script or scheduled task:
```bat
cmd /c "cd /d %USERPROFILE%\go\pkg\mod\github.com\!nous\!research\hermes-agent@*\web && npm ci && npm run build"
```
The `*` wildcard works because only one version folder exists at a time.