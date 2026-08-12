# Hermes Agent — Skill Routing (76 skills loaded)

Source: [ho3eines/Skill](https://github.com/ho3eines/Skill) → local `.agents/skills/` (v1.0.0, 2026-07-22).
Project law: `docs/PROJECT.md` **overrides** any skill that conflicts with Hermes architecture.

Auto-trigger: match user keywords → load that skill’s `SKILL.md` + needed `references/` before acting.

---

## 0. Hermes overrides (always win)

| Topic | Hermes (`docs/PROJECT.md`) | Skill that would otherwise apply |
|-------|----------------------------|----------------------------------|
| UI library | HTML + **Bootstrap 5.3** + CSS/JS only. **No MudBlazor / Radzen / shadcn / Tailwind** | `ui-styling` (shadcn+Tailwind) — skip stack, keep a11y/token ideas |
| Data access | Single `webapi` + **named TSQL** in `webapi/Data/Scripts/{schema}/{name}.sql` | `server-client-comm` 13-step per-entity Controller/Dapper — **do not** add per-project APIs |
| Project shape | Each product = **client-only** Blazor WASM | `server-client-comm` `{Project}.Server` / `{Project}.Business` — not this repo |
| Auth | Login in `central-client`; token via **URL param** to other clients | WS handshake / AES session from Pdd.ir — only if Hermes already has it |
| Dates | Prefer `long` Unix timestamps + Shamsi display (`DateHelper`) | same as `server-client-comm` |
| Loading | Skeleton, not `spinner-border` for page load | same |
| i18n | `T.Text()` / `TranslateService` when present | same |
| Reports-first | Research reports **before** designing models | `deep-research` + `company-cfo` |

Hermes services that **do** exist in `blazordeployservice` and should be used:

`RequestService`, `ModalService`, `AlertService`, `ClientStorageService`, `EncryptionService`, `ThemeService`, `CultureService`, `SqlService`.

Prefer `RequestService` (this repo) over inventing `ICommunicationService` unless that interface is already wired.

---

## 1. Blazor / Hermes (load first on product work)

| Skill | Trigger | What I do |
|-------|---------|-----------|
| `server-client-comm` | entity جدید، CRUD، API، WebSocket، encrypt، DTO، SQL | Modal-first CRUD, DTO + `long` dates, parameterized SQL, skeleton, `T.Text()`. **Adapt** to named TSQL + `SystemController`, not new controllers |
| `convert-prompts-to-blazor` | تبدیل به بلیزور، React/Vue/Angular → Razor | Map hooks→`@code`, v-if→`@if`, fetch→`RequestService` |
| `blazor-motion` | انیمیشن، transition، hover، modal enter, scroll | CSS transform/opacity, `prefers-reduced-motion`, assets in `wwwroot/css` + `wwwroot/js` |
| `ui-ux-pro-max` | صفحه/کامپوننت/رنگ/فونت/UX review | Run `scripts/search.py` with `--design-system` + `--stack blazor-wasm`. Bootstrap, not Tailwind |
| `smart-image` | mockup، hero، icon، تصویر UI | AI generate for UI/abstract; web search for real photos |

---

## 2. Design system (marketing site / brand / decks)

| Skill | Trigger |
|-------|---------|
| `design` | لوگو، CIP، بنر، اسلاید، آیکون — router to sub-skills |
| `design-system` | design tokens (primitive→semantic→component), no raw hex |
| `brand` | voice, identity, `docs/brand-guidelines.md` |
| `banner-design` | کاور، بنر تبلیغ، hero |
| `ui-styling` | **only** a11y + token thinking; do **not** install shadcn/Tailwind in Hermes |
| `slides` / `slide-deck` | پرزنتیشن HTML / React deck |
| `image` / `video` / `watch-video` | ساخت یا استخراج تصویر/ویدیو |

---

## 3. Research, decisions, knowledge

| Skill | Trigger |
|-------|---------|
| `deep-research` | تحقیق عمیق، due diligence — multi-source, cite, archive |
| `decide` | کمک در تصمیم — 6–8 سوال 37signals، آرشیو با revisit |
| `business-brainstorm` | تست ایده کسب‌وکار — 9 بُعد، Build/Sleep/Pass |
| `customer-research` | صدای مشتری، JTBD، verbatim quotes |
| `competitor-profiling` | پروفایل رقبا از URL |
| `competitors` | صفحات alternative / vs |
| `read-book` | نت‌برداری از کتاب/PDF |
| `company-brain` / `second-brain` | دانش تیمی / شخصی |
| `company-cfo` / `personal-cfo` | گزارش نقدینگی ماهانه / سناریوی خانوار |
| `pm` | کانبان + Eisenhower |
| `skillify` / `toolify` / `loopify` | ساخت مهارت / اینتگریشن / حلقه زمان‌بندی |

---

## 4. Marketing (check `.agents/product-marketing.md` first)

`product-marketing` · `marketing-plan` · `marketing-ideas` · `marketing-council` · `marketing-psychology` · `marketing-loops` · `copywriting` · `copy-editing` · `content-strategy` · `seo-audit` · `ai-seo` · `programmatic-seo` · `schema` · `site-architecture` · `analytics` · `ads` · `ad-creative` · `ab-testing` · `cro` · `signup` · `onboarding` · `popups` · `paywalls` · `pricing` · `offers` · `emails` · `cold-email` · `sms` · `social` · `social-fetch` · `jab-hook` · `launch` · `lead-magnets` · `free-tools` · `directory-submissions` · `public-relations` · `referrals` · `churn-prevention` · `co-marketing` · `community-marketing` · `prospecting` · `sales-enablement` · `revops` · `aso` · `domain`

---

## 5. Hard rules I will apply

**Blazor / Hermes**
1. No per-project API. Data = named TSQL via shared `webapi`.
2. No MudBlazor / Radzen / shadcn / Tailwind in this repo.
3. Dates as `long` Unix; display Shamsi via helper.
4. Parameterized SQL only.
5. Modal-first CRUD; Page+Modal for reports/big grids.
6. Skeleton loaders for pages; button spinner only while saving.
7. `T.Text()` for UI strings; `RequestService` / existing BDS services.
8. Animate `transform`/`opacity` only; honor `prefers-reduced-motion`.
9. Research reports before inventing accounting models (`company-cfo` + `deep-research`).
10. Do not ask the user to re-explain project structure.

**Marketing**
- Read `.agents/product-marketing.md` before asking context questions.
- No invented stats/testimonials. Ground ad creative in real inputs.
- One hypothesis / one variable per A/B test. Pre-size the sample.
- Clarity > cleverness. Benefits > features. Customer language > company language.

**Research / decisions**
- Cite every claim. Surface contradictions; don’t average them.
- `decide`: capture first instinct **before** analysis. Archive every call.
- Never invent CFO methodology; transaction-sum EOM only; never commit `data/`.

**Security**
- Auth on every data request. Encrypt bodies when EncryptionService is in play.
- Never `git add -A` in finance vaults.

---

## 6. Gaps in the collection

- README lists `bootstrap5-ui` — **folder missing**. Hermes uses Bootstrap 5.3 via PROJECT.md + `blazor-motion`.
- `server-client-comm` is Pdd.ir-shaped (WS auto-CRUD). Hermes is TSQL-script-shaped. Adapt, don’t copy the 13-step controller path.
- `ui-styling` / `design` assume React+Tailwind. Convert through `convert-prompts-to-blazor` + Bootstrap.

Full texts live in `.agents/skills/<name>/SKILL.md`.
