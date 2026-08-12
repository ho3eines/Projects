# Windows Node.js Version for Hermes Dashboard

## Why Node LTS (v24) is Required
The Hermes dashboard's `web/` workspace depends on `nanoid@6`, which declares:
```json
"engines": { "node": "^22 || ^24 || >=26" }
```
Node 25.x (the `nodejs` Scoop bucket) does **not** satisfy this range, causing `npm ci` to fail with:
```
npm error code EBADENGINE
npm error engine Unsupported engine
npm error engine Not compatible with your version of node/npm: nanoid@6.0.0
npm error notsup Required: {"node":"^22 || ^24 || >=26"}
npm error notsup Actual:   {"node":"v25.2.1","npm":"11.19.0"}
```

## Fix: Switch to Node LTS via Scoop
```bash
# Install LTS (v24.x)
scoop install nodejs-lts

# Make it the active `node`/`npm` on PATH
scoop reset nodejs-lts

# Kill any stray node.exe processes from the newer install
taskkill /F /IM node.exe
```

## Verify
```bash
node --version   # → v24.x.x
npm  --version   # → 11.x
which node       # → ...\scoop\apps\nodejs-lts\current\node
which npm        # → ...\scoop\apps\nodejs-lts\current\bin\npm
```

After this, `npm ci && npm run build` in the dashboard `web/` folder will succeed.