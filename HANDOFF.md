---
project: Tarazin
type: Handoff
date: 2026-08-31
author: Hermes Agent
status: completed

## ۱۴۰۵/۰۶/۰۹ — نصب ECC (Everything Claude Code) برای هارنس

### کار انجام‌شده در این نوبت

**نصب ECC 2.2.0 (affaan-m/ECC) روی Claude Code**

- Claude Code `2.1.229` + Node v24 موجود بود؛ `ecc-universal@2.2.0` از npm نصب شد.
- Marketplace به‌صورت declarative در `~/.claude/settings.json` ثبت شد (`extraKnownMarketplaces.ecc` → `affaan-m/ECC`، `enabledPlugins: {"ecc@ecc": true}`) — مسیر توصیه‌شدهٔ خود ECC برای پرهیز از تداخل `/plugin`.
- `npx ecc-universal setup --mode claude-plugin --scope user --hooks standard --yes` → `ecc@ecc` در user scope نصب شد (`restartRequired: true`).
- وابستگی‌های اسکریپت ECC (`npm ci`، ۲۱۰ بسته) در `~/.claude/plugins/cache/ecc/ecc/2.2.0` نصب شد — بدون آن `plan/doctor` با `Cannot find module 'ajv'` می‌شکست.
- پروفایل **developer** نصب شد (`node scripts/ecc.js --profile developer --enable-hooks`): ماژول‌های rules-core, agents-core, commands-core, hooks-runtime, platform-configs, framework-language, database, skill-unified-memory, workflow-quality, orchestration.
- نتیجه: ۱۲۵ skill، ۶۸ agent، ۹۴ command در `~/.claude/{skills,agents,commands}`؛ قواعد مدیریت‌شده در `~/.claude/rules/ecc` (common + پشته‌های زبانی)؛ install-state در `~/.claude/ecc/install-state.json`.
- `doctor --target claude` → `Status: OK, Issues: none` ✅
- توجه: `doctor` بدون install-state خطای گمراه‌کنندهٔ «No ECC install-state files found» می‌دهد — این *نرمال* است قبل از اولین `install`؛ بعد از نصب OK می‌شود.
- دسترسی: `/reload-plugins` یا restart؛ skill راهنما `ecc-guide`، دستورات `/ecc:*`.

### یادداشت‌ها برای نوبت بعد
- اسکیل‌های سفارشی پروژه (tarazin-development, tarazin-reporting, windows-computer-control) دست‌نخورده ماندند — ECC آن‌ها را به‌عنوان user-owned skip می‌کند.
- اگر `plan` یا `doctor` خطای `Cannot find module 'ajv'` داد: `npm ci` داخل `~/.claude/plugins/cache/ecc/ecc/<ver>` اجرا شود.

### تصمیم نهایی (به‌روزرسانی): پلاگین مالک شد، نصب تخت حذف شد

**۱. تعارض install تخت با پلاگین (یافتهٔ کلیدی).** `ecc setup` (مسیر پلاگین) بعد از نصب تخت با خطای `MANAGED_INSTALL_OVERLAP` رد می‌شود: از ۸۱۰ عملیات ثبت‌شده در `~/.claude/ecc/install-state.json`، **۳۹۴ عملیات** روی همان مسیرهای `~/.claude/{agents,commands,hooks,skills}` می‌نویسند که پلاگین `ecc@ecc` هم آن‌ها را مدیریت می‌کند (بررسی: `/tmp/check_overlap.py` — شمارش عملیات بر اساس `destinationPath`: agents ۶۸، commands ۹۴، hooks ۵، skills ۲۲۷). ECC اجازهٔ استک‌کردن این دو مسیر نصب را نمی‌دهد و خودش هم توصیه می‌کند فقط یکی را انتخاب کنید.

**۲. تصمیم نهایی (بازنگری‌شده): پلاگین مالک شد، نصب تخت حذف شد.** در بازنگری نهایی **پلاگین مالک محتوا شد و نصب تخت حذف شد**: `ecc uninstall --target claude` هر ۸۱۱ فایل مدیریت‌شدهٔ تخت را پاک کرد (`~/.claude/{agents,commands,hooks,rules}` خالی شدند؛ `~/.claude/skills` فقط `learned/` دارد؛ اسکیل‌های سفارشی پروژه در `.claude/skills/` *پروژه* دست‌نخورده ماندند). دلایل بازنگری: (الف) پلاگین مسیر رسمی و پایدار ECC است و به‌روزرسانی/تعمیر/uninstall را خودکار می‌کند؛ (ب) نصب تخت با پروفایل developer محتوای یکسان را در همان مسیرهای پلاگین می‌نویسد و `MANAGED_INSTALL_OVERLAP` اجازهٔ استک‌کردن نمی‌دهد؛ (ج) پلاگین skills/agents/commands/rules را مستقیم از cache پلاگین (`~/.claude/plugins/cache/ecc/ecc/2.2.0` — ۲۸۶ skill، ۶۸ agent، ۹۴ command) سرو می‌کند و `hooks/hooks.json` خودش hooks را لود می‌کند.

**۳. سیم‌کشی دستی hooks حذف شد.** سه hook `PreToolUse` دستی که در `settings.json` نوشته شده بود (Bash → `pre-bash-dispatcher.js`، Write → `doc-file-warning.js`، Edit|Write → `suggest-compact.js`، با `cwd` ثابت `~/.claude/plugins/cache/ecc/ecc/2.2.0`) از `settings.json` حذف شدند — پلاگین `ecc@ecc` خودش hooks را از `hooks/hooks.json` لود می‌کند و نسخهٔ دستی فقط تکرار بود. هر سه hook دستی قبل از حذف با payload واقعی `PreToolUse` از cwd خنثی (`/tmp`) dry-run شدند و همه exit 0 دادند.

**۴. تأیید نشست زنده ✅.** در نشست تازهٔ Claude Code (`claude --print`) تأیید شد:
- `claude plugin list` → `ecc@ecc` نسخه 2.2.0، scope user، status enabled.
- `claude plugin marketplace list` → marketplace `ecc` (GitHub affaan-m/ECC) ثبت است.
- skill `ecc:ecc-guide` در دسترس است (invocable به‌صورت `/ecc:ecc-guide`).
- ~۹۴ دستور `/ecc:*` در دسترس‌اند (build-fix، code-review، quality-gate و ...).
- `claude --print` خودش نشست تازه می‌سازد و معادل verify بعد از restart است.

### یادداشت‌ها برای نوبت بعد (به‌روزرسانی نهایی)
- اسکیل‌های سفارشی پروژه (tarazin-development, tarazin-reporting, tarazin-ui-ux, windows-computer-control) در `.claude/skills/` *پروژه* دست‌نخورده ماندند — پلاگین به `.claude/skills/` پروژه دست نمی‌زند.
- اگر `plan` یا `doctor` خطای `Cannot find module 'ajv'` داد: `npm ci` داخل `~/.claude/plugins/cache/ecc/ecc/<ver>` اجرا شود.
- `doctor` با نصب فقط-پلاگین خطای «No ECC install-state files found» می‌دهد — نرمال است: پلاگین install-state تخت نمی‌سازد؛ فقط حالت نصب تخت را چک می‌کند.
- `setup` دوباره بعد از حذف install-state تخت با موفقیت اجرا شد (`ECC updated ecc@ecc at user scope`) — دیگر خطای overlap نمی‌دهد.
- دستی hooks از `settings.json` حذف شدند — پلاگین خودش hooks را از `hooks/hooks.json` لود می‌کند (`hooks: none` در settings.json درست است).
- **تأیید نشست زنده ✅:** نشست تازه (`claude --print`) skill `ecc:ecc-guide` و ~۹۴ دستور `/ecc:*` را دید؛ `claude plugin list` → `ecc@ecc` 2.2.0، scope user، enabled.
- **تپولوژی نهایی (تأیید شده در نشست زنده ✅):** فقط پلاگین `ecc@ecc` — نصب تخت کاملاً حذف شد (`ecc uninstall`، ۸۱۱ مسیر) و دستی hooks هم از `settings.json` حذف شد (پلاگین خودش hooks را سرو می‌کند). `~/.claude/{skills,agents,commands,rules}` خالی هستند (فقط `skills/learned`)؛ همهٔ محتوا از cache پلاگین سرو می‌شود. اسکیل‌های پروژه در `.claude/skills/` پروژه سالم ماندند.
- تأیید زنده: `claude --print` → ۶۸+ agent با پیشوند `ecc:`، `ecc:ecc-guide` skill، و فهرست کامل `/ecc:*` commands (build-fix، checkpoint، quality-gate و ...) همگی در دسترس‌اند.

### ⚠️ قانون مهم ارتباطی (کاربر فقط از تلگرام می‌بیند)
- **هیچ سؤال/تأیید/درخواست تصمیمی را در Freebuff نپرس** — کاربر دیگر این صفحه را نمی‌بیند.
- **حتی پیشنهادهای مرحلهٔ بعد هم نباید با ابزار suggest_prompts در Freebuff نمایش داده شوند** — کاربر آن‌ها را نمی‌بیند. هر پیشنهاد باید به‌صورت دکمهٔ inline در تلگرام فرستاده شود.
- تمام سؤال‌ها، درخواست تأیید، گزینه‌ها و پیشنهادهای مرحلهٔ بعد باید فقط از طریق ربات تلگرام ارسال شوند: `python tools/telegram_send.py --buttons "متن سؤال"` (یا بدون `--buttons` اگر دکمه لازم نیست).
- پاسخ کاربر از تلگرام می‌آید → agent آن را Task `ready` می‌سازد → Freebuff با `claim-next` می‌گیرد.
- Freebuff فقط گزارش/اطلاع‌رسانی می‌تواند در صفحهٔ خود بنویسد؛ سؤال نپرسد و پیشنهاد ندهد.

### Telegram → Freebuff local task queue (2026-08-31)

- `tools/telegram_agent.py` مصرف‌کنندهٔ واحد Telegram است؛ پیام مجاز کاربر را به Task با Todoهای استاندارد در `~/.telegram-bridge/agent/queue.jsonl` تبدیل می‌کند.
- این agent عمداً هیچ Claude/API مدل، shell، repository executor یا اجرای خودکاری ندارد. وضعیت‌ها: `awaiting_approval` → `/approve TASK-ID` → `ready`.
- نشست فعال Freebuff تنها executor است: `python tools/telegram_queue.py list`، سپس پس از بررسی `python tools/telegram_queue.py claim TASK-ID` و اجرای واقعی در همین نشست؛ پایان با `complete` یا `fail` ثبت می‌شود.
- `/status` و `/queue` وضعیت صف را می‌فرستند؛ `/approve`، `/reject`، `/done` و `/report` کنترل چرخه را انجام می‌دهند. سؤال/دسترسی باید در همین نشست Freebuff پاسخ داده شود و با `/report` به Telegram ارسال شود.
- `tools/telegram_send.py` گزارش یا سؤال Freebuff را در outbox می‌گذارد؛ `telegram_agent.py` با retry آن را ارسال می‌کند.
- token در `.telegram-agent.env` محلی و ignored است؛ webhook خالی است؛ lock مشترک `~/.telegram-bridge/bridge.lock` مانع چند poller و خطای `409` می‌شود. `tools/telegram_bridge.py` هم‌زمان با agent نباید اجرا شود.
- تست انجام‌شده: `py_compile` برای هر چهار ابزار، `getMe` و `getWebhookInfo` موفق، ارسال outbox موفق و outbox خالی پس از تحویل. اجرای واقعی Task عمداً فقط با approval و توسط Freebuff انجام می‌شود.
- کشف خودکار نشست: `python tools/telegram_queue.py next` قدیمی‌ترین Task قابل مشاهده را چاپ می‌کند و `claim-next` آن را اتمیک به `in_progress` می‌برد؛ خروجی با UTF-8 تنظیم شده تا درخواست‌های فارسی روی Windows خطا ندهند. این ابزار جایگزین فراخوانی مستقیم نشست Freebuff نیست؛ Python API برای تزریق Task به مدل فعال Freebuff ندارد.

### فاز ۳ (پیاده‌سازی شد): skeleton داشبوردها و صفحات حسابداری
- کامپوننت مشترک جدید `Tarazin.Ui/Components/StatCardSkeleton.razor` — گرید اسکلتون با همان کلاس‌های `tz-stat` (Count، Md/Xs/Sm مطابق StatCard).
- داشبوردها (همهٔ `MudProgressLinear Indeterminate` داشبوردی حذف شد): `AccountingDashboard` (۴ کارت)، `TreasuryDashboard` (۵)، `StoreDashboard` (۴)، `InventoryDashboard` (۴)، `PayrollDashboard` (۴)، `GoldShopDashboard` (۵) → `StatCardSkeleton`.
- صفحات/دیالوگ‌های حسابداری → `TableSkeleton` (ستون‌ها مطابق جدول واقعی): `AccountingDocument` (۵ ستون)، `AccountingReports` (۸ ستون)، `AccountingChart` (۳ ستون درخت)، `DocumentDetailDialog` (۴ ستون)، `DetailAccountHistoryDialog` (StatCardSkeleton ۲×۲ + TableSkeleton ۸ ستون).
- باقی‌مانده عمداً: فقط `MudProgressLinear` با `Value=` در `BiDashboard` (نوار درصد تحقق هدف — داده‌نما نیست، اسکلتون نیست).
- بیلد: `dotnet build Tarazin.Web` → 0 error ✅؛ `bash tools/check-stale-build.sh` → 0 ✅؛ `dotnet test` → 63/63 ✅. dev server با کد تازه روی 65220/65221 بالا آمد (HTTP 200).

## ۱۴۰۵/۰۶/۰۹ — کامپوننت‌محورسازی UI (فازهای ۱–۲)

### کار انجام‌شده در این نوبت

**۱. پالت اکسنت نام‌دار (commit `0a8bda1`)**
- `Tarazin.Ui/Theme/TarazinAccents.cs` — ۱۳ رنگ اکسنت نام‌دار (Ink, Steel, Gold, Brass, Wine, Petrol, Moss, Emerald, Jade, Crimson, Violet, Slate, Amber).
- ۴۳ hex literal در ۱۶ فایل razor به `TarazinAccents.*` تبدیل شد (ماژول‌ها، داشبوردها، CentralHome، BiKpiGrid، CurrencyDashboard، TreasuryChequeReport).
- `StatCard`/`ModuleCard` پیش‌فرض از پالت؛ پالت تیره در `TarazinTheme.cs` توکن‌های کنتراست (Gray/Overlay/*ContrastText) گرفت.

**۲. سه‌گانهٔ EntityPicker (commit `9916a5b`)**
- `Tarazin.Ui/Services/EntityPickerService.cs` — `EntityPickerOptions<T>` (Items/LoadAsync، Columns، SearchFields، RowsPerPage، EnableVirtualization) + `EntityPickerService.PickAsync<T>()` روی `SelectorDialog<T>` موجود (جستجوی debounce، پیجینگ، مرتب‌سازی، پیمایش کلید).
- `Tarazin.Ui/Components/EntityPickerField.razor` — فیلد فرم عمومی (دکمهٔ انتخاب + نمایش انتخاب + پاک کردن)، الگوی `AccountPickerField`.
- DI: `services.AddScoped<EntityPickerService>()` در `ServiceCollectionExtensions.cs`.
- مهاجرت‌شده: `TreasuryEntry` (صندوق/حساب بانکی + طرف حساب با record محلی `TreasuryAccountOption`)، `StoreEntry` (مشتری + محصول)، `ChequeDialog` (بانک).

**۳. EmptyState یکپارچه (همان commit)**
- همهٔ `NoRecordsContent><MudText` (۶۲ مورد در ۳۸ فایل) به `<EmptyState Title=... />` تبدیل شد؛ صفر مورد باقی مانده. `TzDataTable.razor` هم اضافه شد (chrome + skeleton + EmptyState + pager در یک کامپوننت) و در `TreasuryCheques`، `CentralRoles`، `StoreSettings` استفاده شده.

### وضعیت Build
- `dotnet build Tarazin.Ui` → 0 error, 0 warning ✅ (پس از هر فاز)

### فازهای بعدی (باقی‌مانده)
1. **فاز ۳**: skeleton داشبوردها — ۸ داشبورد هنوز `MudProgressLinear` تنها دارند؛ با `TableSkeleton` + StatCard skeleton جایگزین شود.
2. **فاز ۴**: polesan dialog/backdrop/pagination + بازبینی کنتراست mod تیره (StatCard/جدول/دیالوگ).
3. **فاز ۵**: پاک‌سازی app.css (کامنت‌های روسی، قوانین تکراری) + به‌روزرسانی skill doc `tarazin-development` با فهرست اجباری کامپوننت‌ها (PageHeader, PageToolbar, StatCard, EmptyState, TzDataTable, EntityPickerField, StatusChip, EntityActions).
4. **Rollout picker**: `GoldShopEntry` (جنس طلا)، `ChequeCollectDialog` (بانک)، `TreasurySettings`/`StoreSettings` به `EntityPickerField`.
5. **تست دستی**: دیالوگ‌های جدید (SelectorDialog در حالت picker) در مرورگر: جستجو، پیجینگ، Enter/Esc، پاک کردن فیلد.

### نکته برای دست‌گیرندهٔ بعدی
- `EntityPickerService` باید قبل از استفاده در صفحه جدید ثبت شده باشد (در `ServiceCollectionExtensions.cs` ثبت شده — سراسری).
- برای افزودن picker جدید فقط ~۱۵ خط Options تعریف کنید (ستون‌ها + DisplayText)؛ دیالوگ/فیلد عمومی است.
- `TzDataTable<T>` برای جدول‌های جدید ترجیح داده شود (chrome/skeleton/empty/pager یک‌جا)؛ صفحات باقی‌مانده به‌تدریج مهاجرت شوند.
- commit‌های مرجع: `0a8bda1` (accent tokens)، `9916a5b` (EntityPicker + EmptyState). working tree هنوز ~۴۷ فایل تغییر یافتهٔ فازهای ۳–۵ دارد که commit نشده‌اند.

---

## نوبت قبلی (2026-08-22)

## خلاصه تغییرات

### مشکل اصلی
در ماژول حسابداری، بخش گزارشات (AccountingReports.razor) وقتی کاربر روی آخرین سطر جدول گردش (DetailAccountTransactionRow) کلیک میکرد، به جای باز کردن دیالوگ، با `Nav.NavigateTo` به صفحهٔ `/accounting/document/{id}` هدایت میشد.

### راهحل
تغییر `OpenDocument` در AccountingReports.razor از ناوبری به DialogService.ShowAsync.

### فایل‌های تغییر یافته
1. `Tarazin.Ui/Modules/Accounting/Components/DocumentDetailDialog.razor` (ایجاد شده)
   - دیالوگ MudBlazor برای نمایش جزئیات سند
   - شامل: تاریخ، نوع، طرف حساب، وضعیت، مبلغ کل، ردیفهای سند
   - استفاده از DocumentById و DocumentLines scripts
   - استفاده از IMudDialogInstance برای بستن دیالوگ

2. `Tarazin.Ui/Modules/Accounting/Pages/AccountingReports.razor` (تغییر)
   - افزودن `@using Tarazin.Modules.Accounting.Components`
   - افزودن `[Inject] private IDialogService DialogService`
   - تغییر `OpenDocument` از `Nav.NavigateTo` به `DialogService.ShowAsync<DocumentDetailDialog>`

### الگوی استفاده از Dialog در پروژه
دیالوگ‌های موجود در پروژه (مثل AccountPickerDialog, EntityEditorDialog) از این الگو پیروی میکنند:
- `@inject IDialogService DialogService`
- `[CascadingParameter] private IMudDialogInstance MudDialog`
- `<MudDialog>` در Rooter
- `MudDialog.Cancel()` برای بستن
- `DialogService.ShowAsync<T>(title, parameters, options)` برای باز کردن

### تست
- Build موفق: `dotnet build Tarazin.Web/Tarazin.Web.csproj` ✅
- Build UI: `dotnet build Tarazin.Ui/Tarazin.Ui.csproj` ✅
- 0 error, فقط warnings وجود دارد

### نحوه تست
1. `cd /d/hermes/projects/webapi && dotnet run`
2. به `/accounting/reports` بروید
3. گزارش «گردش تفصیلی» را انتخاب کنید
4. روی آخرین سطر جدول گردش کلیک کنید
5. دیالوگ «جزئیات سند» باید باز شود (نه ناوبری)
