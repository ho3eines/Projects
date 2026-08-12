# Hermes Agent — Skill Routing

Project law: `docs/PROJECT.md`.
**Data skill: `.agents/hermes-tsql/` only.**  
`server-client-comm` is **disabled** in this repo. Do not load it.

Generic collection (marketing/design/research) still lives in `.agents/skills/` (ho3eines/Skill). Those never override Hermes data rules.

---

## Always-on (Hermes)

| Skill | When |
|-------|------|
| **`hermes-tsql`** | Any entity, CRUD, report, TSQL, query/execute/scalar, schema, webapi call |
| `convert-prompts-to-blazor` | React/Vue/HTML → Razor — but data calls become `ISystemApi`, not `ICommunicationService` |
| `blazor-motion` | Animations (CSS transform/opacity, Bootstrap 5) |
| `ui-ux-pro-max` | Visual design — `--stack blazor-wasm`, output Bootstrap not Tailwind |

---

## Data path (non-negotiable)

```
ISystemApi.Query/Execute/Scalar
  → POST /api/system/{query|execute|scalar}
  → webapi/Data/Scripts/{schema}/{Name}.sql
  → [schema].[Table]
```

Forbidden: `ICommunicationService`, WebSocket, `{Entity}Controller`, `IRequestService.Request(rawSql)`, `ISqlService` CRUD/DDL.

BDS is UI only: Modal, Alert, Theme, Culture, Storage, PersianDatePicker, SearchableList.

---

## Other skills (unchanged)

Marketing / research / design / decide / company-cfo — same as before.  
Before marketing questions, read `.agents/product-marketing.md` if it exists.

---

## Gaps to remember

- `bootstrap5-ui` folder does not exist; use Bootstrap 5.3 + `blazor-motion`.
- `ui-styling` (shadcn/Tailwind) does not apply to Hermes UI.
- Auth JWT is configured on webapi but login pages are not built yet.
