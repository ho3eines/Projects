---
project: Tarazin
type: Handoff
date: 2026-08-31
author: Hermes Agent
status: completed

## ⚠️ قوانین دائمی (برای هر نشست آینده — قانون ۱ و ۲ اجباری است)

1. **پیشنهادها همیشه به تلگرام بروند** — در پایان هر کار/تسک، پیشنهادهای ادامه
   (۲–۴ مورد) را با `telegram_send.py --buttons` به‌صورت دکمه به تلگرام بفرست، نه فقط
   اینجا. کلیک‌های کاربر در صف می‌آیند و باید همان نشست اجرا شوند. تحویل را با
   `~/.telegram-bridge/agent/status.json` تأیید کن.
2. **سؤال/تأیید/دسترسی فقط از طریق تلگرام** — هیچ سؤالی در پنجرهٔ Freebuff نپرس؛
   همه با دکمه به تلگرام بروند و پاسخ از صف خوانده شود.
3. **گزارش نهایی هر تسک** با `--priority high` به تلگرام فرستاده شود.
4. **reseed خودکار بعد از هر تسک** — `complete` در `tools/telegram_queue.py`
   خودکار `seed-demo-data.sh --reseed` را بعد از هر تسک اجرا می‌کند (دادهٔ نمونه
   همیشه تازه؛ غیر-کشنده؛ log در `~/.telegram-bridge/agent/reseed.log`؛
   خاموش‌کردن با `--no-reseed`). **اگر reseed شکست بخورد، هشدار priority=high
   به تلگرام می‌رود** (rc + tail خروجی) تا خطا دیده و رفع شود.
   (نسخهٔ کامل‌تر: `~/.telegram-bridge/agent/rules.md`)

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

### Telegram → Freebuff local task queue (به‌روزرسانی 2026-09-01)

- `tools/telegram_agent.py` مصرف‌کنندهٔ واحد Telegram است؛ پیام مجاز کاربر و کلیک روی دکمه‌های inline را به Task با Todoهای استاندارد در `~/.telegram-bridge/agent/queue.jsonl` تبدیل می‌کند.
- **Auto-mode روشن است** (فایل `~/.telegram-bridge/agent/auto-mode` = 1؛ از تلگرام با `/auto on|off` تغییر می‌کند): پیام جدید مستقیماً `ready` می‌شود، نیازی به `/approve` دستی نیست.
- Agent وقتی Task جدید `ready` می‌شود فایل notify می‌سازد؛ Freebuff چک می‌کند: `python tools/telegram_queue.py has-notify` (خروجی `yes/no`).
- نشست فعال Freebuff تنها executor است: `python tools/telegram_queue.py list`، سپس `claim-next` (اتمیک، اولین `ready` را `in_progress` می‌کند) یا `claim TASK-ID`؛ پایان با `complete TASK-ID` یا `fail`.
- دکمه‌های پیشنهاد فاز بعدی: `python tools/telegram_send.py --buttons "متن" "دکمه۱" "دکمه۲" ...` — callback دکمه توسط agent به Task تبدیل می‌شود.
- `tools/telegram_send.py` گزارش یا سؤال Freebuff را در outbox می‌گذارد؛ `telegram_agent.py` با retry ارسال می‌کند.
- token در `.telegram-agent.env` محلی و ignored است؛ webhook خالی است؛ lock مشترک `~/.telegram-bridge/bridge.lock` مانع چند poller و خطای `409` می‌شود. `tools/telegram_bridge.py` هم‌زمان با agent نباید اجرا شود (فعلاً اصلاح و بدون token پیش‌فرض).
- وضعیت شناخته‌شده: agent با `Telegram network error ... retry` روی خطاهای شبکه پایدار می‌ماند؛ `answer_callback failed` (HTTP 400) در لاگ دیده می‌شود — زیانبار نیست اما دکمه‌های قدیمیِ قبلاً پاسخ‌داده‌شده را نشان می‌دهد.
- صفِ `queue.jsonl` ممکن است Taskهای تکراری/قدیمی‌ای از کلیک‌های تکراری دکمه جمع کند — با اسکریپت one-off status قدیمی‌ها را `completed` کردیم؛ `has-notify` فقط Taskهای `ready` جدید را نشان می‌دهد.
- کشف خودکار نشست: `next` قدیمی‌ترین Task قابل مشاهده را چاپ می‌کند و `claim-next` آن را اتمیک به `in_progress` می‌برد؛ خروجی با UTF-8 تنظیم شده تا درخواست‌های فارسی روی Windows خطا ندهند. این ابزار جایگزین فراخوانی مستقیم نشست Freebuff نیست؛ Python API برای تزریق Task به مدل فعال Freebuff ندارد.

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

### فازهای بعدی (باقی‌مانده — واقعی)
1. **فاز ۴**: بازبینی کنتراست mod تیره (StatCard/جدول/دیالوگ) + dialog/backdrop/pagination — بخشی از فاز ۴ قبلاً انجام شد (توکن‌های kebab-case MudBlazor 9 در app.css درست شد).
2. **فاز ۵**: پاک‌سازی app.css (کامنت‌های روسی، قوانین تکراری) + به‌روزرسانی skill doc `tarazin-development` با فهرست اجباری کامپوننت‌ها (PageHeader, PageToolbar, StatCard, EmptyState, TzDataTable, EntityPickerField, StatusChip, EntityActions).
3. **Rollout picker**: `GoldShopEntry` (جنس طلا)، `ChequeCollectDialog` (بانک)، `TreasurySettings`/`StoreSettings` به `EntityPickerField`.
4. **تست دستی**: دیالوگ‌های جدید (SelectorDialog در حالت picker) در مرورگر: جستجو، پیجینگ، Enter/Esc، پاک کردن فیلد.

### نکته برای دست‌گیرندهٔ بعدی
- `EntityPickerService` باید قبل از استفاده در صفحه جدید ثبت شده باشد (در `ServiceCollectionExtensions.cs` ثبت شده — سراسری).
- برای افزودن picker جدید فقط ~۱۵ خط Options تعریف کنید (ستون‌ها + DisplayText)؛ دیالوگ/فیلد عمومی است.
- `TzDataTable<T>` برای جدول‌های جدید ترجیح داده شود (chrome/skeleton/empty/pager یک‌جا)؛ صفحات باقی‌مانده به‌تدریج مهاجرت شوند.

---

## ۱۴۰۵/۰۶/۱۰ (2026-09-01) — ماژول انبار: فازهای ۱–۵ + یکپارچه‌سازی جداول فاکتور + تعمیر دیتابیس زنده

### کاری که انجام شد
- **فاز ۱ — Database:** در `inventory/_Ensure.sql` جدول‌های یکپارچه `Invoices` (OperationType ن-discriminator: Purchase|Sales) + `InvoiceLines` جایگزین ۴ جدول قدیمی split (PurchaseInvoices/PurchaseInvoiceLines/SalesInvoices/SalesInvoiceLines) شد + migration یک‌بارهٔ داده. ستون‌های غنی‌سازی Items (SKU, Barcode, Brand, Model, MinStock, MaxStock, ReorderPoint, HasBatch/Serial/Expiry, LatinTitle, PurchasePrice, SalePrice, Description, ImageUrl) + جداول Returns/Transfers/Barcodes.
- **فاز ۲ — SQL scripts:** `PurchaseInvoiceInsert/Search`, `SalesInvoiceInsert/Search`, `TransferInsert`, `ReturnInsert`, بهبود `StockCardReport`, `ItemUpsert`, `ItemList`.
- **فاز ۳ — UI:** `PurchaseInvoiceEntry/List`, `SalesInvoiceEntry/List` (جدا), `TransferEntry`, `PurchaseReturnEntry`/`SalesReturnEntry` (جدا), حذف صفحات ترکیبی قدیمی `ReturnEntry`/`InvoiceList`.
- **فاز ۴ — Permissions:** دسترسی‌های جدید inventory (Purchase*, Sales*, Transfer, Return) در `Tarazin.Share/Permissions.cs`.
- **فاز ۵ — Tests:** `Tarazin.Tests/InventoryPhase5Tests.cs` (۶ سناریو) — کل suite ۱۲۳/۱۲۳ پاس.

### تعمیر دیتابیس زنده (مهم — برای دست‌گیرندهٔ بعدی)
- دیتابیس زنده (TarazinMaster) هنوز schema قدیمی داشت (Returns با `PurchaseInvoiceId`/`SalesInvoiceId`، FK به جدول‌های split). `_Ensure.sql` با `IF NOT EXISTS` جدول موجود را به‌روز نمی‌کرد.
- **باگ پیدا و رفع شد:** در `_Ensure.sql` الگوی `EXEC (N'...' + QUOTENAME(...) + N';')` را این SQL Server قبول نمی‌کند («Incorrect syntax near 'QUOTENAME'») — به `DECLARE @sql ...; EXEC sys.sp_executesql @sql;` (الگوی `_MobileSecurity.sql`) تغییر کرد.
- نصب مجدد schema روی دیتابیس زنده: جدول‌های قدیمی split + Returns قدیمی drop و با schema جدید ساخته شدند؛ Returns حالا با `InvoiceId`/`InvoiceLineId` FK به `Invoices`/`InvoiceLines` متصل‌اند. `accounting.SalesInvoices` و `goldshop.InvoiceLines` دست‌نخورده ماندند (ماژول‌های دیگر).
- نکته برای اجرای دستی یک اسکریپت فارسی با sqlcmd در Windows: `` python -c "open('tmp.sql','w',encoding='utf-16').write(open(src,encoding='utf-8').read())" `` سپس `sqlcmd -S localhost -U sa -P 123456 -d TarazinMaster -b -I -i tmp.sql` (کدپید 1252 پیش‌فرض sqlcmd متن فارسی را می‌شکند).
- Startup برنامه (`dotnet run` روی 65220/65221) بعد از اصلاح: `EnsureSchema` همهٔ schemaها OK، `_Seed` همه OK، سرور بالا آمد، صفحه `/inventory/purchase-invoices` فقط redirect 308 (لاگین عادی) می‌دهد. ریشهٔ «صفحه باز نمی‌شود» همان باگ QUOTENAME بود که startup را می‌شکست.

### نکتهٔ حسابداران
- Invoice settings (`InventorySettings`) برای ثبت سند حسابداری نیاز به InventoryAccountId + ContraAccountId دارد؛ اگر NULL باشد، insert سند را با THROW 51038 متوقف می‌کند (بخش حسابداری فقط اگر `IsEnabled=1`).

### پاک‌سازی منوی انبار (۱۴۰۵/۰۶/۱۰)
- **صفحه `InventoryEntry.razor` («حرکت جدید» /inventory/entry) حذف شد** — رسید/حواله/تعدیل دستی که فاکتور خرید (رسید خودکار)، فاکتور فروش (حواله خودکار)، انتقال و برگشت‌ها جای آن را گرفته‌اند. آیتم منو هم از `TarazinModules.cs` حذف شد.
- هیچ ارجاع دیگری به `InventoryEntry` یا `/inventory/entry` در سورس نماند. اسکریپت `MovementInsert` دست‌نخورده است (هنوز در تست‌ها و نمونه‌های demo استفاده می‌شود؛ TreasuryEntry از `CashMovementInsert` استفاده می‌کند نه `MovementInsert`).
- بررسی بیشتر صفحات انبار (۱۴۰۵/۰۶/۱۰): همهٔ ۱۴ صفحهٔ باقی‌مانده واقعی، مسیردار و متصل به اسکریپت‌اند — صفحهٔ مرده‌ای نماند. فقط `InventoryMovementSearch.sql` بی‌مصرف بود (جای آن را `DailyMovements` گرفته) و حذف شد؛ تعداد اسکریپت‌های انبار: ۳۱.
- منوی انبار پس از پاک‌سازی: داشبورد، اسناد روز، انبارها، کالاها، فاکتور خرید (+لیست)، فاکتور فروش (+لیست)، انتقال، برگشت خرید، برگشت فروش، عملیات ویژه، گزارشات، امکانات.
- Build: 0 خطا، تست 125/125 پاس.

### ربات تلگرام: دکمه‌های پویا (۱۴۰۵/۰۶/۱۰)
- `tools/telegram_send.py --buttons "متن" "گزینه۱" "گزینه۲" ...` حالا **دکمه‌های inline کاملاً پویا** می‌سازد (هر آرگومان بعد از متن یک دکمه) — به‌جای دکمه‌های ثابت فاز ۳/۴/۵ قدیمی.
- `tools/telegram_agent.py` دکمه‌های پویا را هم پردازش می‌کند: هر callback (به‌جز status/queue:run/queue:clean) به Task `ready` تبدیل می‌شود؛ `dynamic_buttons()` پیشنهادهای پویا از وضعیت صف می‌سازد و بعد از هر Task/پیام می‌فرستد.
- مشکل تکرار agent (خطای 409) با تک‌نمونه‌سازی حل شد؛ lock قدیمی `~/.telegram-bridge/bridge.lock` باید بعد از kill باگ‌دار پاک شود.

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

## ۱۴۰۵/۰۶/۱۰ — اجرای خودکار ربات تلگرام با Task Scheduler

ربات تلگرام حالا بهصورت خودکار بالا میآید و خود-ترمیم میشود — دیگر لازم نیست بعد از ریاستارت ویندوز دستی اجرا شود.

### Task ثبتشده
- **نام:** `Tarazin\TelegramAgent`
- **اکشن:** `C:\Users\Ho3ein\AppData\Local\Programs\Python\Python312\python.exe D:\Hermes\projects\tools\telegram_agent.py` (اجرای مستقیم daemon — نه استارتر واسطه)
- **Triggers:** (۱) Logon کاربر `HO3EIN\Ho3ein` (۲) تکرار هر ۵ دقیقه برای auto-heal بعد از crash
- **تنظیمات:** `MultipleInstancesPolicy=IgnoreNew`، `ExecutionTimeLimit=PT0S`، `StartWhenAvailable`
- **تغییر یا حذف:** `schtasks /Change /TN "Tarazin\TelegramAgent" /DISABLE` یا `schtasks /Delete /TN "Tarazin\TelegramAgent" /F`
- **XML منبع:** `tools/telegram_agent_task.xml` (بازسازی: `schtasks /Create /TN "Tarazin\TelegramAgent" /XML tools\telegram_agent_task.xml /F`)

### دو باگ واقعی که همینجا پیدا و رفع شد
1. **`pid_exists` روی ویندوز:** `os.kill(pid, 0)` برای پروسههای زندهٔ spawn شده از طریق launcher shim (uv re-exec) خطای `OSError 22` میداد → agent زنده «مرده» تشخیص داده میشد، نمونهٔ دوم lock را میدزدید و دو poller با هم خطای 409 میگرفتند. حالا `ctypes OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` استفاده میشود (خطای 87 فقط برای PID واقعاً مرده).
2. **`log()` با stdout غیر UTF-8:** print به خروجی redirect شده با codepage ویندوز (charmap) خطای encode میداد و در poll loop تکرار میشد — حالا wrap شده و crash نمیکند.

### نکتهٔ طراحی (درس گرفتهشده)
استارتر spawn-و-exit (`start_telegram_agent.py`) داخل job آبجکت Task Scheduler جواب نمیدهد (CREATE_BREAKAWAY_FROM_JOB شکست میخورد و فرزند با پایان اکشن کشته میشود). **راهحل درست: اکشن خود daemon باشد** — agent خودش single-instance lock دارد و `IgnoreNew` هم از همپوشانی جلوگیری میکند. `tools/start_telegram_agent.py` فقط بهعنوان ابزار دستی (از ترمینال) باقی میماند.

### وضعیت نهایی
- یک نمونهٔ تمیز: `python.exe tools/telegram_agent.py` (PID متغیر، Python312 مستقیم — بدون جفت shim)
- تست ارسال/دریافت: ✅ (outbox خالی شد)
- خطای 409 جدید: صفر (۹ مورد قبلی مربوط به poller دوگانهٔ قدیمی در لاگ باقی است)

## ۱۴۰۵/۰۶/۱۰ — گزارش کامل وضعیت ماژول انبار

### صفحات (۱۴ — همه در منو، همه متصل به اسکریپت)
| مسیر | صفحه | اسکریپت(ها) |
|---|---|---|
| `/inventory/dashboard` | داشبورد (کارتهای آماری) | `DashboardSummary` |
| `/inventory` | اسناد روز (ژورنال حرکت با فیلتر) | `DailyMovements` |
| `/inventory/warehouses` | انبارها + زیرانبارها | `WarehouseList/Upsert/Delete`, `SubWarehouse*` |
| `/inventory/items` | کالاها (+ گروه/واحد) | `ItemList/Upsert/Delete`, `ItemGroup*`, `Unit*` |
| `/inventory/purchase-invoice` | فاکتور خرید | `PurchaseInvoiceInsert` |
| `/inventory/purchase-invoices` | لیست فاکتور خرید | `PurchaseInvoiceSearch` |
| `/inventory/sales-invoice` | فاکتور فروش | `SalesInvoiceInsert` |
| `/inventory/sales-invoices` | لیست فاکتور فروش | `SalesInvoiceSearch` |
| `/inventory/transfer` | انتقال بین انبارها | `TransferInsert` |
| `/inventory/purchase-return` | برگشت خرید | `ReturnInsert` (Purchase) |
| `/inventory/sales-return` | برگشت فروش | `ReturnInsert` (Sales) |
| `/inventory/special` | عملیات ویژه (انبارگردانی) | `StocktakeRun` |
| `/inventory/reports` | گزارشات (موجودی + کارتکس + PDF) | `StockBalanceReport`, `StockCardReport` |
| `/inventory/settings` | امکانات | `InventorySettingsGet/Upsert` |

### اسکریپتها (۳۱)
- **Schema/Seed:** `_Ensure.sql` (جدولهای یکپارچه `Invoices`/`InvoiceLines` + RLS + migration)، `_Seed.sql`
- **عملیات:** `PurchaseInvoiceInsert`, `SalesInvoiceInsert`, `ReturnInsert`, `TransferInsert`, `StocktakeRun`, `MovementInsert` (قدیمی — فقط تست/demo)
- **پایهها:** `Item*`, `ItemGroup*`, `Unit*`, `Warehouse*`, `SubWarehouse*` (۱۵ اسکریپت)
- **گزارش/جستجو:** `StockBalanceReport`, `StockCardReport`, `DailyMovements`, `DashboardSummary`, `PurchaseInvoiceSearch`, `SalesInvoiceSearch`
- **تنظیمات:** `InventorySettingsGet/Upsert`

### یکپارچگیها
- **حسابداری ✅**: فاکتور خرید/فروش سند دوبل میسازند (خرید: بدهکار موجودی کالا / بستانکار تأمینکننده؛ فروش: بدهکار مشتری / بستانکار فروش + بهای تمامشده COGS) و `DocumentId` روی فاکتور ذخیره میشود.
- **طلافروشی ✅**: `goldshop.GoldItems.InventoryItemCode` ← `inventory.ItemList` (پل کدی؛ دیالوگ اتصال با EntityPickerService ساخته شد).
- **خزانه/مشتری**: `central.Parties` مشترک (PartyList) — طرفحسابها یکساناند.

### تستها
- ۱۱ تست Inventory (`InventoryPhase5Tests` + `InventoryMovementInsertTests`).
- در اجرای **مجزا: همه پاس**؛ در اجرای موازی یک تست flaky (`Receipt_posts_updates_stock_layer_outbox`) بهخاطر state مشترک دیتابیس زنده — در ایزوله پاس میشود.
- Full suite قبلاً: **۱۲۵/۱۲۵ پاس**.

### تصمیمهای مهم اخیر
- جدولهای split قدیمی (`PurchaseInvoices`/`SalesInvoices`/`Returns` قدیم) **حذف شدند**؛ Returns با `InvoiceId` به `Invoices` یکپارچه متصل شد.
- `InventoryEntry` (حرکت جدید دستی) حذف شد — فاکتور خرید/فروش جای رسید/حواله دستی را گرفت.
- `InventoryMovementSearch.sql` حذف شد (بیاستفاده؛ `DailyMovements` جای آن است).
- باگ `EXEC(...+QUOTENAME(...))` در `_Ensure.sql` → الگوی `sp_executesql` اصلاح شد (startup سالم).

### ۳ کار مهم بعدی (پیشنهاد شده به تلگرام)
1. **گزارشات تکمیلی موجودی**: موجودی به تفکیک انبار/زیرانبار + ارزش ریالی + هشدار کمبود (MinStock/ReorderPoint از فاز ۱ موجودند ولی مصرف نشدهاند).
2. **تعدیل و انبارگردانی کامل**: StocktakeRun فعلی + ثبت مغایرت بهصورت سند حسابداری (تعدیل موجودی) — بدون سند، تراز انبار/حسابداری جابهجا میشود.
3. **Batch/Serial/Expiry**: ستونهای `HasBatch/HasSerial/HasExpiry` در Items از قبل هست ولی عملیات ثبت/صدور سریال و بچ هنوز پیاده نشده — اولین قدم: ورود سریال در فاکتور خرید و صدور در فروش.

### ۱۴۰۵/۰۶/۱۰ — تست اتصال طلا↔انبار + باگ CreatedBy
- **جدید:** `Tarazin.Tests/GoldItemLinkTests.cs` — ۲ تست SkippableFact: (۱) لینک → ذخیرهٔ `InventoryItemCode` + دیدهشدن عنوان در `GoldItemList` + قطع اتصال (null)؛ (۲) تعویض اتصال بین دو کالا. **۲/۲ پاس** (مجموع انبار+طلا: ۱۳/۱۳).
- **باگ واقعی پیدا و رفع شد:** `GoldItemUpsert.sql` در بلوک اتصال حسابداری به `@CreatedBy` ارجاع دارد و هیچ فراخوانی آن را پاس نمیداد → «Must declare the scalar variable @CreatedBy». یعنی ذخیرهٔ جنس طلا از `EntityEditorDialog` هم شکسته بود. حالا `CreatedBy = Session.UserName` به `EntityEditorDialog` (کیس GoldItem) و `GoldItemLinkDialog` اضافه شد.

### ۱۴۰۵/۰۶/۱۰ — پروکسی تلگرام (رفع ناپایداری شبکه)
- **مشکل:** ۶۱۰ خطای SSL/handshake به api.telegram.org (شبکهٔ کاربر ناپایدار) → تأخیر/از دست رفتن موقت پیامها.
- **راهحل:** `telegram_agent.py` حالا از `TELEGRAM_PROXY` پشتیبانی میکند (فایل `.telegram-agent.env` — مقدار نمونه `http://127.0.0.1:3067`).
  - غیرفعال: مقدار خالی/حذف → اتصال مستقیم (رفتار قبلی).
  - تغییر پورت: فقط مقدار را عوض کنید.
  - `urllib` opener با `ProxyHandler` برای http/https؛ بعد از تغییر config، agent باید ریاستارت شود (لاگ `telegram transport: proxy ... | direct`).
- **تأیید:** بعد از فعالسازی، خطاهای شبکه از ۶۱۰ → **۰** و ارسال/دریافت از طریق پروکسی کار میکند.
- `/status` تلگرام هم وضعیت پروکسی را نشان میدهد.

### ۱۴۰۵/۰۶/۱۰ — ماندهٔ ابتدای دوره (Opening Balance) + تأیید یکپارچگی
- صفحهٔ جدید `/accounting/opening` («ماندهٔ ابتدای دوره») — منوی حسابداری + آیتم جدید
  - `DocumentOpeningEnsure` را صدا می‌زند (اتمیک/idempotent → سند افتتاحیهٔ 00000001 را می‌سازد یا همان را برمی‌گرداند)
  - ویرایشگر مشترک `AccountingDocument` را با `IsModal=1` تعبیه می‌کند (همان الگوی DetailAccountHistoryDialog)
  - StatCard: جمع مانده، تعداد ردیف، وضعیت سند + راهنمای کاربر
- `AccountingDocument.razor`: برای اسناد Opening/Closing به‌جای MudSelect نوع، فیلد فقط‌خواندنی نشان می‌دهد (چون نوع توسط مسیر سیستمی تعیین می‌شود)
- تست جدید `OpeningBalanceTests.cs` (1/1 پاس): Ensure idempotent + شماره 00000001 + ذخیرهٔ ردیف‌های مانده با DocumentUpdate (نوع Opening حفظ می‌شود، TotalAmount به‌روز می‌شود)
- تأیید یکپارچگی سه‌جانبه (پاسخ تسک «یکپارچه کن»): انبار↔حسابداری (سند دوبل در Purchase/SalesInvoiceInsert با DocumentId)، طلافروشی↔انبار (GoldInvoiceCreate: چک موجودی + مصرف FIFO از StockLayers + درج inventory.Movements + آپدیت StockQty + لایهٔ جدید برای تسویهٔ طلا)، طلافروشی↔حسابداری (GoldInvoiceCreate سند دریافت با خطوط صندوق/بانک/طلا می‌سازد)

### ۱۴۰۵/۰۶/۱۰ — Batch/Serial/Expiry + سند حسابداری انبارگردانی + تنظیمات جدید (تسک‌های تلگرام T-26A0775D و T-F7A00260)
این دو مورد در «۳ کار مهم بعدی» (خطوط ۲۵۸–۲۵۹) به‌عنوان شکاف ذکر شده بودند؛ حالا پیاده و تست شدند.

**🏷 پشتیبانی Batch/Serial/Expiry (T-26A0775D):**
- جدول جدید `inventory.LotSerials`: `LotSerialId, ItemId, WarehouseId, SubWarehouseId, LotNo, SerialNo, ExpiryDate, Qty, Status (In|Out), SourceReference (PINV:id | SINV:id), ReceiptMovementId, IssueMovementId, CompanyId, CreatedBy` + ایندکس `IX_LotSerials_Item_Status`
- `PurchaseInvoiceInsert`: پارامتر اختیاری `@SerialsJson` = `[{ ItemId, LotNo, SerialNo, ExpiryDate, Qty }]` → ثبت سریال/بچ با `Status=In` داخل cursor ردیف‌ها (بعد از ثبت موجودی/لایه)
- `SalesInvoiceInsert`: `@SerialsJson` → صدور سریال/بچ (`Status=Out`) با اعتبارسنجی در برابر `LotSerials`؛ سریالِ قبلاً صادرشده دوباره فروخته نمی‌شود → خطای **51055**
- UI: فیلد «سریال/بچ» در هر قلم فاکتور خرید و فروش (`PurchaseInvoiceEntry` / `SalesInvoiceEntry`)؛ همهٔ فراخوان‌ها (۸ سایت تست + صفحات) پارامتر جدید را پاس می‌کنند
- تست: `LotSerialTests.cs` — **۳/۳ پاس** (ثبت در خرید، صدور در فروش، فروش مجدد سریال صادرشده رد می‌شود)

**⚖️ سند حسابداری مغایرت انبارگردانی (T-F7A00260):**
- `StocktakeRun`: اگر `InventorySettings.IsEnabled = 1` و مغایرت ≠ ۰ → سند `StocktakeAdjustment` با شمارهٔ ترتیبی ۸رقمی و `SourceReference = Stocktake:<StocktakeId>`:
  - مغایرت مثبت (افزایش موجودی): بدهکار حساب موجودی کالا / بستانکار حساب مقابل تعدیل
  - مغایرت منفی (کاهش): بدهکار حساب مقابل تعدیل / بستانکار حساب موجودی کالا
  - مبلغ = `ABS(ΔQty) × (UnitCost در افزایش | CostPrice در کاهش)`؛ وضعیت سند `Note`
  - نیازمندی‌ها: `@FiscalYearId` (خطای **51027** اگر null) و حساب‌های تنظیم‌شده (خطای **51038**)
- تنظیمات انبار: ستون‌های جدید `AdjustmentAccountId/Code/Title` + `IsEnabled` در `_Ensure` / `InventorySettingsGet` / `InventorySettingsUpsert`؛ خواص `AdjustmentAccount*` در `InventorySettingsRow`
- UI: انتخاب «حساب مقابل تعدیل» در صفحهٔ تنظیمات انبار + ارسال `FiscalYearId` فعال از صفحهٔ عملیات ویژه (`InventorySpecial`)
- تست: `InventoryAdjustmentTests.cs` — **۲/۲ پاس** (مغایرت مثبت و منفی → سند و خطوط درست)

**تأیید نهایی:** Build UI **۰ خطا**؛ تست‌ها: LotSerial 3/3، Adjustment 2/2، Phase5 6/6، GoldLink 2/2، OpeningBalance 1/1.

### ۱۴۰۵/۰۶/۱۰ — دکمهٔ واقعی «غیرفعال/فعال کردن پروکسی» در ربات تلگرام
- دکمهٔ پویا «⛔ غیرفعال کردن پروکسی» (و برعکس «🔄 فعال کردن پروکسی (3067)» وقتی غیرفعال است) در `dynamic_buttons()` — callbackهای `proxy:off`/`proxy:on`
- `set_proxy_config(enabled)`: فقط خط `TELEGRAM_PROXY=` در `.telegram-agent.env` را عوض می‌کند؛ بقیهٔ خطوط (توکن و…) دست‌نخورده می‌مانند
- `restart_agent(reason)`: offset فعلی را قبل از خروج ذخیره می‌کند (جلوگیری از بازپردازش update → حلقهٔ بی‌نهایت ری‌استارت)، نمونهٔ جداگانه spawn (DETACHED_PROCESS + CREATE_NO_WINDOW) و `os._exit(0)` می‌کند
- `main()` حالا تا ۳۰ ثانیه برای قفل صبر می‌کند (۱۵ تلاش × ۲s) تا ری‌استارت بدون رقابت باشد
- تست زنده: شبیه‌سازی کلیک `proxy:off` → config خالی شد + agent جدید با `transport: direct` بالا آمد؛ سپس `proxy:on` → config برگشت + agent جدید با `transport: proxy` بالا آمد؛ تک‌نمونه (PID واحد)، بدون 409

### ۱۴۰۵/۰۶/۱۰ — Healthcheck ربات تلگرام (هشدار ناپایداری خودکار)
- آستانه: `HEALTH_ALERT_THRESHOLD = 5` خطای پشتسرهم → یک‌بار هشدار «⚠️ هشدار سلامت ربات تلگرام» (شمار خطاها + مسیر پروکسی + اطمینان از امن‌بودن پیام‌ها در صف محلی) به outbox رفته و با backoff تحویل می‌شود (نه برای هر خطا — فقط در لحظهٔ گذر از آستانه)
- بعد از بهبود (`_consecutive_failures == 0`): هشدارِ تحویل‌نشده از outbox حذف و «✅ به حالت عادی برگشت» جایگزین می‌شود (هشدار قدیمی بعد از بهبود نمی‌رسد)
- پیام‌ها از `enqueue_outbox` می‌روند (فایل outbox — تحویل مطمئن در حلقهٔ اصلی، بدون block کردن poll)
- دستور `/health`: وضعیت اتصال، شمار خطاهای پشتسرهم، آستانه، مسیر (پروکسی/مستقیم) و آپ‌تایم؛ `/status` هم شمار خطاها را نشان می‌دهد
- تست: واحد (گذر از آستانه → ۱ هشدار؛ بهبود → حذف هشدار کهنه + پیام عادی؛ idempotent) + **زنده** — با قطعی واقعی شبکه، بعد از ۵ خطای پشتسرهم هشدار واقعی در outbox ثبت شد (لاگ `health: degraded (5 consecutive failures)` در 17:11:41)

### ۱۴۰۵/۰۶/۱۰ — ری‌استارت خودکار بعد از تغییر TELEGRAM_PROXY (حذف گام دستی)
- Watcher در حلقهٔ اصلی: `_config_proxy_value()` (همان قواعد parse ریدconfig) با `PROXY` در حال اجرا مقایسه می‌شود؛ اگر فرق داشت → `restart_agent("TELEGRAM_PROXY changed in config -> ...")` بدون هیچ گام دستی
- بعد از ری‌استارت، حافظه == فایل می‌شود → پایدار (هیچ حلقهٔ بی‌پایانی)؛ `_config_proxy_value` دقیقاً مثل `read_local_config` پارس می‌کند تا مقایسه همیشه درست باشد
- واکنش در ابتدای هر سیکل (قبل از send_pending) — با شبکهٔ سالم ~۳۰-۶۰ ثانیه، با قطعی چند دقیقه
- تست زنده (هر دو جهت، بدون هیچ گام دستی): ویرایش دستی به خالی → خودکار `transport: direct` (17:16:57→17:16:59)؛ ویرایش به پروکسی → خودکار `transport: proxy` (17:20:11→17:20:12)؛ تکنمونه، بدون حلقه/409

### ۱۴۰۵/۰۶/۱۰ — دکمهٔ مشاهدهٔ سند انبارگردانی در عملیات ویژه
- `StocktakeRun.sql`: خروجی `SELECT @AdjDocumentId AS DocumentId;` (شناسهٔ سند حسابداری مغایرت اگر ساخته شده باشد، وگرنه NULL) — بدون تغییر در منطق ثبت
- مدل جدید `StocktakeResultRow` (DocumentId؟) در InventoryModels.cs
- `InventorySpecial.razor`: بعد از اجرای موفق، اگر سند ساخته شده باشد → پیام موفقیت با شماره/مبلغ سند + دکمهٔ «مشاهدهٔ سند انبارگردانی» که `AccountingDocument` را با `IsModal=1` در دیالوگ باز می‌کند (همان الگوی DetailAccountHistoryDialog)
- سند از `accounting.DocumentById` و با `@using Tarazin.Modules.Accounting.Pages` (RootNamespace=Tarazin)
- تأیید: Build ۰ خطا؛ InventoryAdjustmentTests 2/2 پاس
- یادداشت: `StockCardReport.sql` از قبل برای ستون‌های Lot/Serial/Expiry + EarliestExpiry غنی شد (بدون UI) — تکمیل UI (ستون‌ها + هشدار انقضا) در صف بعدی

### ۱۴۰۵/۰۶/۱۰ — عیب‌یابی مسیر تلگرام (Karing fake-IP + بهترین مسیر)
- **کشف**: DNS این سیستم توسط **Karing** (پورت 3067، `karingService.exe`) در حالت fake-IP ربوده می‌شود — `api.telegram.org` → `127.146.0.2` و `fd00:696e:6974:6578::3a:32` (آدرس‌های جعلی). «اتصال مستقیم» عملاً از تونل Karing می‌رود.
- **علت قطعی ~۱۷:۰۰-۱۷:۵۰**: هم تونل Karing و هم مسیر واقعی در TLS handshake timeout بودند → agent با backoff مقاومت کرد + هشدار سلامت واقعی ثبت شد.
- **وضعیت فعلی (بازیابی‌شده)**: getMe مستقیم ۱٫۴s و از طریق پروکسی 3067 **۰٫۷s**؛ تحویل هر ۳ پیام صف + پیام تست تأیید شد (outbox خالی).
- **تست IPهای جایگزین**: از ۸ IP واقعی تلگرام فقط **`149.154.167.220`** مستقیم کار می‌کند (TLS ۰٫۴s)؛ بقیه WRONG_VERSION_NUMBER/Timeout (فیلتر/تصرف‌شده).
- **بهترین مسیر**: پروکسی `http://127.0.0.1:3067` (Karing) — سریع‌ترین و پایدار؛ همین الان در config agent است. پورت پروکسی محلی دیگری (clash/v2ray/privoxy) در سیستم نیست.
- **سلامت**: تکنمونه (PID واحد)، 409 جدید صفر، offset به‌روز.

### ۱۴۰۵/۰۶/۱۰ — ارسال قابل‌اعتماد: outbox-first به‌جای send همزمان
- `send()` حالا **اول رکورد را در outbox می‌نویسد** (پایدار) و بعد با **تایم‌اوت کوتاه ۱۰s** (`SEND_ATTEMPT_TIMEOUT`) تلاش فوری می‌کند؛ در موفقیت رکورد حذف می‌شود، در قطعی در صف می‌ماند
- `_deliver(record)`: تلاش همزمانِ کوتاه برای یک رکورد؛ `send_pending()` فقط از آن استفاده می‌کند (نه از send) و ناموفق‌ها را حفظ می‌کند — ریتم تحویل با backoff حلقهٔ اصلی تنظیم می‌شود
- `answer_callback` هم با تایم‌اوت کوتاه — حلقه حتی هنگام قطعی پاسخ‌گو می‌ماند
- **نتیجه**: پیام‌های تأیید (مثل تأیید ری‌استارت پروکسی) دیگر با ری‌استارت از بین نمی‌روند؛ کرش/ری‌استارت agent هم پیام صف را تحویل می‌دهد
- تست‌ها: شبیه‌سازی قطعی (deliver=False) → پیام در صف می‌ماند ✅؛ مسیر فوری با شبکهٔ سالم → تحویل فوری و صف خالی ✅؛ **کرش زنده**: پیام در صف → kill agent → ری‌استارت → تحویل (outbox 1→0) ✅؛ تکنمونه

### ۱۴۰۵/۰۶/۱۰ — اولویت‌بندی outbox: پاسخ کلیک‌ها قبل از گزارش‌ها
- `send(..., priority="high")` — پیش‌فرض high برای همهٔ فراخوان‌های داخلی (تأییدها/پاسخ دکمه و دستور — چون همه پاسخِ کاربر‌اند)
- رکوردهای بدون priority (گزارش‌های `telegram_send.py` و هشدارهای سلامت که `priority:"normal"` می‌گیرند) عادی‌اند
- `send_pending()`: مرتب‌سازی `(high اول، سپس normal) + created_at` — پاسخ کلیک‌ها همیشه قبل از گزارش‌های معوق تحویل می‌شوند
- تست واحد: [نرمال۱، نرمال۲] در صف + [high۱، high۲] → ترتیب تحویل دقیقاً high۱، high۲، نرمال۱، نرمال۲ ✅ — تکنمونه زنده، تحویل تأیید شد

### ۱۴۰۵/۰۶/۱۰ — سقف و هشدار رشد outbox
- `OUTBOX_WARN_THRESHOLD = 10`: وقتی رکوردهای معوق از ۱۰ بیشتر شود → هشدار جداگانه «⚠️ هشدار صف ارسال تلگرام» (شمار رکوردها + علت محتمل + اطمینان از امن‌بودن) — فقط یک‌بار در گذر از آستانه، بعد از بهبود flag ریست می‌شود
- `OUTBOX_HARD_CAP = 50`: بالای سقف، `send()` رکورد جدید نمی‌پذیرد (log + return False) — صف هیچ‌وقت بی‌نهایت رشد نمی‌کند؛ رکوردهای موجود حفظ و با backoff تحویل می‌شوند
- باگِ پیدا و رفع‌شده: هشدار ابتدا قبل از بازنویسی فایل صف می‌شد و پاک می‌شد → `outbox_health_check(len(remaining))` به انتهای `send_pending` منتقل شد
- تست‌ها: ۱۱ معوق → ۱ هشدار در فایل (زنده می‌ماند)، سیکل دوم تکراری ندارد، بهبود → ریست؛ سقف ۵۰: ارسال ۵۱ام رد می‌شود ✅

### ۱۴۰۵/۰۶/۱۰ — فلگ --priority high در telegram_send.py
- `tools/telegram_send.py --priority high "متن"` → رکورد با `priority:"high"` در outbox → agent آن را قبل از گزارش‌های عادی تحویل می‌دهد (هماهنگ با اولویت‌بندی send_pending)
- مقادیر مجاز: `high | normal` (پیش‌فرض normal)؛ مقدار نامعتبر → خطا و خروج 2
- تست: رکورد با priority=high در صف ثبت و تحویل شد؛ مقدار نامعتبر رد شد ✅

### ۱۴۰۵/۰۶/۱۰ — فایل وضعیت واحد (status.json) برای /status
- `~/.telegram-bridge/agent/status.json` — نمای کامل سلامت: transport/پروکسی، خطاهای پشتسرهم، وضعیت health، رکوردهای معوق outbox + فلگ هشدار، آخرین خطا/زمان، آخرین موفقیت/زمان، آپتایم، pid و updated_at
- نوشته میشود: هنگام شروع، پایان هر سیکل حلقه، و در گذرهای health (degraded/recovered)
- poll(): خطاها `_last_error/_last_error_ts` و موفقیت `_last_success_ts` را ثبت میکنند
- `/status` حالا علاوه بر وضعیت صف: آپتایم + رکوردهای معوق outbox (+⚠️ اگر بالای آستانه) + آخرین خطا را نشان میدهد
- تست: فایل با ۱۲ فیلد درست ساخته شد؛ زنده — agent بعد از deploy فایل را نوشت و بعد از poll موفق بهروز شد ✅
- رفع باگ: `_last_success_ts/_last_error/_last_error_ts` در `poll()` بدون `global` سایه می‌شدند (فایل آپدیت می‌شد ولی مقادیر صفر می‌ماند) → به `global` poll اضافه شد؛ تأیید زنده: last_success_at بعد از poll موفق > 0 ✅

---

## 📖 مرجع کامل ربات تلگرام (۱۴۰۵/۰۶/۱۰)

> 📄 **مرجع به‌روز‌تر ابزارهای tools در `tools/README.md` است** — بخش «🤖 ربات تلگرام»
> (فایل‌ها، Task Scheduler، وضعیت/سلامت، نکته‌ها) و بخش «🖥 سرور dev» (start-dev-server.sh /
> dev-server-watch.sh / Task Scheduler). اگر بین این بخش و README اختلاف یافتید، README ملاک است;
> جدول بالا برای دسترسی سریع همین‌جا نگه داشته می‌شود.

### فرمان‌های تلگرام (ارسال مستقیم به ربات)

| فرمان | کار |
|---|---|
| `/help` | فهرست فرمان‌ها |
| `/status` | وضعیت صف + مسیر (پروکسی/مستقیم) + وضعیت اتصال و شمار خطاهای پشت‌سرهم + آپ‌تایم + رکوردهای معوق outbox (+⚠️ بالای آستانه) + آخرین خطا |
| `/health` | وضعیت اتصال، خطاهای پشت‌سرهم، آستانهٔ هشدار، مسیر، آپ‌تایم |
| `/queue` | ۱۰ تسک آخر |
| `/auto on` / `/auto off` | حالت تأیید خودکار پیام‌های جدید (فایل auto-mode) |
| `/approve TASK-ID` | انتقال تسک به ready برای اجرای Freebuff |
| `/reject TASK-ID [دلیل]` | رد تسک |
| `/done TASK-ID [گزارش]` | کامل‌کردن تسک با گزارش |
| `/report TASK-ID [گزارش]` | ثبت گزارش روی تسک |

### دکمه‌های پویا (callback_data)

| دکمه | کار |
|---|---|
| `▶️ اجرای صف (N آماده)` → `queue:run` | اطلاع‌رسانی به Freebuff برای اجرا |
| `📊 وضعیت صف` → `status` | خلاصهٔ صف |
| `🧹 پاک‌سازی صف` → `queue:clean` | انتقال تسک‌های باز به completed |
| `⛔ غیرفعال کردن پروکسی` → `proxy:off` | خالی‌کردن `TELEGRAM_PROXY` + ری‌استارت خودکار agent |
| `🔄 فعال کردن پروکسی (3067)` → `proxy:on` | ست‌کردن `TELEGRAM_PROXY=http://127.0.0.1:3067` + ری‌استارت خودکار |
| هر برچسب دیگر | تبدیل به تسک جدید در صف |

### اسکریپت‌های tools

| اسکریپت | کاربرد |
|---|---|
| `python tools/telegram_send.py "متن"` | قرار دادن گزارش در outbox (تحویل توسط agent) |
| `--chat-id 76937621` | تغییر گیرنده |
| `--buttons "متن" "دکمه ۱" ...` | پیام با دکمه (اولین آرگومان = متن) |
| `--priority high\|normal` | اولویت (پیش‌فرض normal؛ high قبل از عادی تحویل می‌شود) |
| `python tools/telegram_queue.py list\|next\|claim-next\|claim T\|complete T S\|fail T R` | مدیریت صف |
| `python tools/telegram_agent.py` | دیمون اصلی (Task Scheduler: `Tarazin\TelegramAgent`) |
| `python tools/start_telegram_agent.py` | استارتر idempotent (قدیمی — دیمون مستقیم جایگزین شد) |

### اولویت‌بندی outbox

| مقدار | منبع |
|---|---|
| `high` | پیش‌فرض `send()` داخلی (پاسخ کلیک/دستور، تأییدها) + `telegram_send.py --priority high` |
| `normal` | گزارش‌های `telegram_send.py` (پیش‌فرض) + هشدارهای سلامت/صف (enqueue_outbox) |

ترتیب تحویل: `high` (به‌ترتیب زمان) ← سپس `normal` (به‌ترتیب زمان).

### آستانه‌ها و تنظیمات (telegram_agent.py)

| ثابت | مقدار | معنا |
|---|---|---|
| `POLL_TIMEOUT` | ۲۵s | long-poll تلگرام |
| `REQUEST_TIMEOUT` | ۴۰s | تایم‌اوت سوکت poll |
| `SEND_ATTEMPT_TIMEOUT` | ۱۰s | تایم‌اوت هر تلاش ارسال |
| `BACKOFF_BASE` / `BACKOFF_CAP` | ۲s / ۶۰s | backoff نمایی با جیتر ۳۰٪ |
| `HEALTH_ALERT_THRESHOLD` | ۵ | خطاهای پشت‌سرهم → هشدار سلامت (یک‌بار) |
| `OUTBOX_WARN_THRESHOLD` | ۱۰ | رکوردهای معوق → هشدار صف (یک‌بار) |
| `OUTBOX_HARD_CAP` | ۵۰ | بالای این، رکورد جدید پذیرفته نمی‌شود |
| محدودیت callback_data | ۶۴ بایت | truncate امن (`callback_data_safe`) |
| کوتاه‌کردن پیام | ۳۹۰۰ کاراکتر | در `send()` |

### فایل‌های وضعیت (~/.telegram-bridge/agent/)

| فایل | محتوا |
|---|---|
| `status.json` | نمای کامل سلامت (۱۲ فیلد: transport، خطاها، outbox، آخرین خطا/موفقیت، آپ‌تایم…) — به‌روز در هر سیکل |
| `queue.jsonl` | صف تسک‌ها |
| `outbox.jsonl` | رکوردهای ارسال‌نشده (پایدار؛ با backoff تحویل می‌شوند) |
| `agent-offset` | آخرین offset پردازش‌شده |
| `bridge.lock` | قفل تک‌نمونه‌ای (PID) |
| `agent.log` | لاگ کامل |
| `auto-mode` | حالت `/auto` |
| `agent.stop` | فایل توقف دستی |

### config (`.telegram-agent.env` در ریشهٔ پروژه)

| کلید | توضیح |
|---|---|
| `TELEGRAM_BOT_TOKEN` | توکن ربات |
| `TELEGRAM_CHAT_ID` | چت مجاز (پیش‌فرض 76937621) |
| `TELEGRAM_AGENT_ROOT` | ریشهٔ پروژه |
| `TELEGRAM_PROXY` | خالی/حذف = مستقیم؛ مثال `http://127.0.0.1:3067` (Karing) — **تغییرش → ری‌استارت خودکار agent** |

### رفتارهای خودکار
- تک‌نمونه (قفل + Task Scheduler با `MultipleInstancesPolicy=IgnoreNew`) — بدون 409
- ری‌استارت خودکار بعد از تغییر `TELEGRAM_PROXY` (watcher در هر سیکل)
- خروجی‌ها اول در outbox (پایدار) — کرش/ری‌استارت پیام را از دست نمی‌دهد
- هشدار سلامت (۵ خطای پشت‌سرهم) و هشدار صف (۱۰ رکورد معوق) — هر کدام یک‌بار، با پیام بهبود

### ۱۴۰۵/۰۶/۱۰ — صفحهٔ سلامت ربات تلگرام در برنامه (Blazor)
- صفحهٔ جدید `/central/telegram-bot` + آیتم منوی «سلامت ربات تلگرام» (مرکزی، زیر مدیریت قالب‌ها)
- `status.json` (~/.telegram-bridge/agent/) را هر ۳۰ ثانیه می‌خواند (Timer + InvokeAsync) + دکمهٔ بازخوانی دستی
- StatCardها: وضعیت اتصال (عادی/ناپایدار با رنگ Moss/Crimson)، خطاهای پشت‌سرهم (آستانه ۵)، پیام‌های معوق outbox (هشدار ≥۱۰)، آپ‌تایم
- جدول جزئیات: مسیر (چیپ پروکسی/مستقیم)، وضعیت health، فلگ هشدار صف، آخرین خطا + زمان، آخرین poll موفق، PID، مسیر فایل
- اگر فایل نباشد → هشدار «agent در حال اجرا نیست (Task Scheduler: Tarazin\TelegramAgent)»
- مدل `TelegramBotStatus` (۱۲ فیلد متناظر status.json) داخل صفحه؛ Build UI ۰ خطا؛ مسیر/JSON با دیتابیس زنده تطبیق داده شد
- نکته: سرور dev با `--no-build` در حال اجراست → صفحه بعد از ری‌استارت/rebuild سرور در دسترس است (فعلاً DLL قفل است)

### ۱۴۰۵/۰۶/۱۰ — تست خودکار ربات (tools/test_telegram_agent.py)
- اجرا: `PYTHONIOENCODING=utf-8 python tools/test_telegram_agent.py` — بدون شبکهٔ واقعی، بدون دست‌زدن به فایل‌های واقعی (همه به پوشهٔ موقت)
- پوشش ۵ گروه / ۲۰ تست: (۱) ارسال→صف→تحویل (قطعی/بهبود/فوری)، (۲) هشدار سلامت (یک‌بار، idempotent، بهبود)، (۳) هشدار و سقف outbox (۱۰/۵۰)، (۴) watcher تغییر TELEGRAM_PROXY + حفظ توکن، (۵) اولویت‌بندی high/normal
- `restart_agent` واقعی (spawn+os._exit) عمداً اجرا نمی‌شود — فقط شرایطش (watcher) تست می‌شود؛ ری‌استارت واقعی در تست‌های زندهٔ قبلی تأیید شده
- نتیجه: ۲۰/۲۰ پاس، خروج 0

### ۱۴۰۵/۰۶/۱۰ — نمودار خطی روند ۲۴ ساعته در صفحهٔ سلامت ربات

**سمت agent (`tools/telegram_agent.py`):**
- `history.jsonl` — نمونهٔ روند هر ۶۰ ثانیه (failures/outbox/degraded)، max ۱۵۰۰ خط (prune)
- بعد از هر موفقیت/خطا + در پایان هر سیکل حلقه ثبت میشود

**سمت UI (`TelegramBotHealth.razor`):**
- SVG خطی بدون وابستگی (بهدلیل تداخل `<text>` با Razor، بهصورت MarkupString ساخته میشود)
- دو خط: خطاهای پشتسرهم (Crimson) + معوق outbox (Petrol)؛ محورهای X/Y با ۴ برچسب زمانی و ۳ برچسب مقدار
- نمونهگیری ۱۵ دقیقهای (بدترین مقدار هر بازه، max ۹۶ نقطه) — ویو ۲۴ ساعته
- StatCard های اوج خطا / اوج outbox / دقیقههای ناپایدار (مجموع فاصلههای زمانی ناپایدار — مستقل از نرخ نمونهگیری)
- بازخوانی خودکار ۳۰ ثانیهای همان data را رندر میکند

**backfill:** پنجرهٔ قطعی واقعی امروز (۱۷:۰۰–۱۷:۵۰) با اوج ۸ خطا + ۳ پیام معوق seed شد تا روند از همان ابتدا معنی داشته باشد؛ agent از این پس نمونههای واقعی را کنار آن مینویسد.

**تأیید:** Build UI ۰ خطا. ⚠️ سرور dev با `--no-build` اجراست — صفحه بعد از ریاستارت سرور دیده میشود.

### ۱۴۰۵/۰۶/۱۰ — رفع بلاک ثبت فاکتورها + انتخاب انبار فعال (مثل سال مالی) + ایزولاسیون شرکت

**۱. ریشهٔ «امکان ثبت فاکتور/کالا وجود ندارد» پیدا و رفع شد:**
- `inventory.InventorySettings` برای همهٔ شرکت‌ها `IsEnabled=1` ولی حساب‌های انبار/مقابل (InventoryAccountId/ReceiptContra/IssueContra) همگی NULL بود → هر فاکتور خرید/فروش با خطای 51038/51039 «حساب‌ها تنظیم نشده» رد می‌شد و ثبت غیرممکن بود.
- رفع: `_Seed.sql` → `IsEnabled=0` برای شرکت‌های جدید؛ `_Ensure.sql` → درمان خودکار ردیف‌های ناسازگار (UPDATE IsEnabled=0 وقتی حساب‌ها NULL)؛ روی دیتابیس زنده ۳۴۳ ردیف درمان شد (۰ ردیف شکسته باقی ماند).
- رفتار مقاوم: `PurchaseInvoiceInsert` / `SalesInvoiceInsert` / `StocktakeRun` دیگر به‌خاطر نبود تنظیمات حسابداری فاکتور را رد نمی‌کنند — سند حسابداری فقط در صورت کامل‌بودن تنظیمات (حساب‌ها + سال مالی) ساخته می‌شود و ستون `AccountingNote` دلیل را برمی‌گرداند.
- تأیید زنده: فاکتور خرید شرکت ۳ (که قبلاً 51038 می‌داد) الان با موفقیت ثبت می‌شود (تست با ROLLBACK).

**۲. انتخاب «انبار فعال» (مثل سال مالی) — عملیات فقط روی انبار انتخابی:**
- `UserSession` + `SessionStore`: فیلدهای `ActiveWarehouseId/ActiveWarehouseName` + متد `UpdateActiveWarehouseAsync` (پایدار بعد از رفرش).
- سرویس جدید `InventoryContextService` (ثبت در DI): فهرست انبارها، Set/Clear، و `EnsureActiveWarehouseAsync` (بازنشانی به انبار پیش‌فرض تنظیمات یا اولین انبار؛ اگر انبار فعال به شرکت قبلی تعلق داشت پاک می‌شود).
- `MainLayout`: چیپ انبار کنار چیپ سال مالی (آیکون Warehouse) با منوی انبارهای همان شرکت؛ `@key` صفحه به انبار فعال هم وصل شد تا صفحات با تغییر انبار دوباره مونت شوند.
- صفحات: ورود فاکتور خرید/فروش/مرجوعی‌ها (پیش‌فرض انبار فعال)، انتقال (انبار مبدأ=انبار فعال)، گزارش‌ها (فیلترها روی انبار فعال)، خانهٔ انبار و عملیات ویژه (انبارگردانی) — همه با `Session.ActiveWarehouseId`.

**۳. ایزولاسیون شرکت انبارها (تأیید شده):**
- `Warehouses/SubWarehouses/Items/ItemGroups/Units/Movements/StockLayers/Invoices/LotSerials` همگی `CompanyId` دارند و همهٔ لیست/آپسرت/دلیت با `@CompanyId` اسکوپ می‌شوند (WarehouseList/SubWarehouseList/WarehouseUpsert/WarehouseDelete بررسی شد). ایندکس یکتا `UX_Warehouses_Company_Code` روی (CompanyId, WarehouseCode).

**تأیید:** Build UI و Web ۰ خطا؛ تست‌ها: InventoryPhase5 6/6، Adjustment 2/2، LotSerial 3/3 (در ایزوله؛ شکست‌های اجرای موازی مربوط به رقابت روی دیتابیس مشترک است). سرور dev با build جدید ریاستارت شد: https://localhost:65220 / http://localhost:65221 ✅

### ۱۴۰۵/۰۶/۱۰ — سرور dev با ریاستارت خودکار (dotnet watch + supervisor)

**معماری نهایی:** سرور dev حالا با `dotnet watch run --project Tarazin.Web --launch-profile Tarazin.Web` اجرا میشود — خودش سورس را رصد میکند:
- تغییر `.razor` → **هاتریلود فوری بدون ریاستارت** (صفحهها همان لحظه عوض میشوند؛ تأیید زنده: تغییر در ۳ ثانیه اعمال شد و uptime/server دستنخورده ماند)
- تغییر `.cs` → هاتریلود یا در صورت لزوم rebuild + ریاستارت خودکار (حتی افزودن کلاس جدید با هاتریلود اعمال شد)
- تغییر صرفاً کامنت → no-op (بدون ریاستارت بیفایده)

**چرا نه «watchdog رصد build»؟** در ویندوز فرایند در حال اجرا، `Tarazin.Web.exe`/dll ها را قفل میکند؛ `dotnet build` در حالی که سرور بالاست با MSB3021 FAIL میشود. پس فقط خودِ `dotnet watch` میتواند (بعد از توقف) rebuild کند.

**فایلها:**
- `tools/dev-server-watch.sh` — supervisor: اجرای dotnet watch + crash-heal (اگر watch بمیرد دوباره بالا میآورد). توقف: `bash tools/dev-server-watch.sh --stop`
- `tools/start-dev-server.sh` — راهاندازی تمیز: کشتن supervisor های قدیمی (تطبیق دقیق command line)، کشتن سرور قبلی، گارد stale-build، سپس اجرای supervisor

**نکات عملی:**
- در حالی که این سرور بالاست `dotnet build Tarazin.Web` نزنید (قفل exe → خطا)؛ برای بررسی کامپایل، `dotnet build Tarazin.Ui` کافی است و watch خودش Web را rebuild میکند.
- لاگها: `/tmp/tarazin-watch.log` (سرور) و `/tmp/dev-server-watch.log` (supervisor)
- سرور الان: https://localhost:65220 (تأیید: 200، تک supervisor، dotnet watch زنده)

### ۱۴۰۵/۰۶/۱۰ — بازههای ۷ و ۳۰ روزه در نمودار سلامت ربات + نگهداشت ۳۰ روزهٔ داده

**سمت agent (`tools/telegram_agent.py`):**
- نگهداشت دو سطحی: ۲۴ ساعتِ آخر با رزولوشن ۶۰ ثانیه + قدیمیترها فشرده به باکت ۱۰ دقیقهای (بدترین failures/outbox/degraded هر باکت) → پوشش ~۳۰ روز با سقف ۶۰۰۰ خط (قبلاً ۱۵۰۰ ≈ ۲۵ ساعت)
- `_prune_history_file()` جایگزین truncate ساده شد (بازنویسی هوشمند بهجای بریدن ته)

**سمت UI (`TelegramBotHealth.razor`):**
- دکمهٔ انتخاب بازه (MudButtonGroup): ۲۴ ساعت / ۷ روز / ۳۰ روز
- باکت تجمیع بر اساس بازه: ۲۴h → ۱۵ دقیقه (۹۷ نقطه)، ۷d → ۱ ساعت (۱۶۹)، ۳۰d → ۳ ساعت (۲۴۱) — بدترین مقدار هر باکت
- محور X: ۲۴h → HH:mm؛ ۷/۳۰ روز → MM/dd؛ عنوان و StatCard های اوج/ناپایدار هم با بازه تطبیق مییابند
- `SetRangeAsync` بدون رفرش، همان داده را با بازهٔ جدید بازتجمیع میکند

**تأییدها:** Build UI ۰ خطا (watch هاتریلود کرد)؛ منطق تجمیع با دادهٔ واقعی (۱۴۳۹/۲۳۱۱/۵۶۸۹ نمونه خام) بررسی شد؛ backfill واقعی ۳۰ روزه (۵۶۸۹ خط، ۳ رخداد پراکنده + قطعی امروز) seed شد؛ agent با کد جدید ریاستارت شد (PID 20140)؛ سرور 200.
⚠️ نکتهٔ عملی: dotnet watch گاهی watcher فایل را از دست میدهد (در این جلسه بعد از چند هاتریلود) — supervisor بعد از کشتن watch خودکار دوباره بالا آوردش (crash-heal مؤثر بود). اگر تغییری hot reload نشد، watch را بکشید تا supervisor ریاستارت کند.

### ۱۴۰۵/۰۶/۱۰ — تست خودکار history.jsonl و SVG نمودار (۴۱ تست)

**`tools/test_telegram_agent.py` → ۴۱/۴۱ پاس** (قبلاً ۲۰). گروه‌های جدید:
- **[۶] ثبت history:** `_append_history_sample` فیلدها را درست می‌نویسد، throttle ۶۰ ثانیه‌ای، افزودن بعد از گذشت پنجره
- **[۶ب] prune/نگهداشت:** زیر سقف دست‌نخورده؛ بالای سقف → ۲۴ ساعت آخر با ۶۰s + قدیمی‌ترها با ۶۰۰s؛ حفظ بدترین مقدار هر باکت؛ خط خراب بدون خطا حذف می‌شود
- **[۷] قرارداد SVG نمودار:** آینهٔ دقیق LoadHistoryAndChartAsync + BuildChart صفحهٔ TelegramBotHealth.razor (فیلتر پنجره، باکت ۹۰۰/۳۶۰۰/۱۰۸۰۰، بدترین مقدار، فرمول نقاط با PadL/ChartW و رنگ‌های #C62828/#2B6B7A) — برای هر سه بازه اوج‌ها، تعداد نقاط و ساختار SVG بررسی می‌شود

**دو باگ واقعی که تست‌ها در `_prune_history_file` پیدا و رفع کردند:**
1. cutoff از `rows[-1]` گرفته می‌شد (فرض: آخرین خط جدیدترین است) → با `max(ts)` مستقل از ترتیب فایل شد
2. ردیف‌های downsampled شده ts نمونهٔ اصلی (نامیزان با باکت) را نگه می‌داشتند → حالا ts به ابتدای باکت نرمال می‌شود (dict(r, ts=b))

agent با نسخهٔ اصلاح‌شده ریاستارت شد (تک‌نمونه، transport پروکسی).

### ۱۴۰۵/۰۶/۱۰ — Task Scheduler برای سرور dev (بالا آمدن خودکار بعد از ریاستارت)

**وظیفهٔ `Tarazin\DevServer`** (الگوی TelegramAgent؛ InteractiveToken — نشست کاربر):
- **LogonTrigger**: بعد از ورود ویندوز، `tools/start-dev-server.sh` را اجرا میکند → dotnet watch + supervisor بالا میآید (~۴۵ ثانیه)
- **TimeTrigger هر ۵ دقیقه** (re-heal): اگر سرور پایین افتاد دوباره بالا میآورد
- `MultipleInstancesPolicy: IgnoreNew`، `ExecutionTimeLimit: PT0S`

**Idempotent شدن `tools/start-dev-server.sh`:** اگر سرور سالم (۲۰۰) و supervisor زنده باشد → «nothing to do» و خروج (بدون ریاستارت). — اجرای ۵ دقیقهای بیخطر شد.
(باگ هنگام ساخت: تطبیق `dev-server-watch\.sh *$` در خروجی wmic شکست میخورد چون ستون PID هم در خط هست؛ با تطبیق بدون anchor + فیلتر `name='bash.exe'` حل شد.)

**تستها (زنده):**
- مسیر «پایین»: کشتن supervisor+سرور → اجرای task → build + supervisor + سرور UP در ۴۴ ثانیه ✅
- مسیر «سالم»: اجرای task → «already healthy — nothing to do»، health 200، تکنمونه supervisor ✅

**فایل قالب:** `tools/tarazin-devserver-task.xml` (UTF-16 — import مجدد: `schtasks //create //tn "Tarazin\DevServer" //xml tools/tarazin-devserver-task.xml //f`)
**لاگ task:** `/tmp/tarazin-task.log`

### ۱۴۰۵/۰۶/۱۰ — Health endpoint + رفع باگ ItemList

**۱. Health endpoint (`GET /api/health`)** — عمومی، بدون auth (فقط وضعیت فرایند):
- JSON: `status:"ok"`، `uptimeSeconds` (آپتایم واقعی فرایند — نه ماشین)، `buildVersion`، `buildTime` (زمان آخرین build از mtime DLL)، `environment`، `timestamp`
- supervisor (`dev-server-watch.sh`) و `start-dev-server.sh` حالا سلامت را از همین endpoint میسنجند (نه هر 200 دلخواه) — `grep '"status":"ok"'`
- ⚠️ نکته: هاتریلود route جدید در Program.cs را فعال نمیکند — برای اعمال endpoint جدید باید سرور کامل ریاستارت شود (اینبار انجام شد)
- `Environment.TickCount64` آپتایم ماشین است (۳۶ روز بود!) — با `Process.StartTime` جایگزین شد (بعد از هاتریلود ۶۴ ثانیه درست شد)

**۲. رفع باگ «لیست کالا خطا میداد» (SqlError 137):**
- `inventory/ItemList.sql` پارامتر `@Search` دارد (جستجوی کد/عنوان/SKU/بارکد/برند) ولی صفحه فقط `CompanyId` میفرستاد → «Must declare the scalar variable @Search»
- فیکس: `InventoryItems.razor` حالا `Search = _search` هم میفرستد (هماهنگ با جستجوی سمت کلاینت)
- تأیید زنده: کوئری با `@Search=''` و `@Search=N'قند'` هر دو RC 0
- build: ۰ خطا؛ سرور با build تازه ریاستارت شد؛ supervisor تکنمونه سالم؛ idempotent check: «already healthy»

### نکته برای نوبت بعد
- route جدید به Program.cs اضافه شد → حتماً سرور کامل ریاستارت شود (هاتریلود کافی نیست)

### ۱۴۰۵/۰۶/۱۰ — تطبیق README با رفتار واقعی + رفع باگ گمشدن پیام

**تطبیق tools/README.md با --help و اجرای واقعی (همه گزینهها بررسی شد):**
- ✅ صحیح بودند: seed-demo-data.sh (همه گزینهها + TARAZIN_TEST_CONN)، run-checks.sh (۷ گام)، check-stale-build.sh، cross-schema-scan.sh، start-dev-server.sh (--force/idempotent)، dev-server-watch.sh (--stop)
- 🔧 `telegram_send.py`: گزینهٔ `--help` نداشت — `python tools/telegram_send.py --help` واقعاً پیامِ «--help» را به تلگرام میفرستاد! راهنمای کامل (usage + شرح گزینهها) اضافه شد
- 🔧 `telegram_queue.py`: رشتهٔ usage فاقد `has-notify` بود → اضافه شد
- 📝 README: ردیفهای telegram_queue.py (list/next/has-notify/claim-next/claim/complete/fail) و refresh-test-report.sh (نیاز به $1 = خلاصهٔ dotnet test) اصلاح شد

**🐛 باگ واقعی و جدی پیدا و رفع شد (در تست ۵):**
- `time.time_ns()` در ویندوز برای فراخوانیهای پشتسرهم مقدار یکسان برمیگرداند (مشاهده: دو رکورد با ID یکسان `M-...1114200`) → `_drop_outbox_record` رکوردِ تحویلنشده را هم حذف میکرد → **گمشدن تصادفی پیام از outbox** (دقیقاً همان ناپایداری «پیام نرسید» که قبلاً نامرتبط به شبکه تصور میشد)
- فیکس: تابع `_new_message_id()` = `M-{time_ns}-{seq}` (شمارندهٔ سراسری) — در `send()` و `enqueue_outbox()`
- تأیید: ۵۰۰/۵۰۰ تکرار بدون خطا (قبلاً ~۲۵٪ شکست)؛ تست کامل ۲× ۴۱/۴۱ پاس
- agent با نسخهٔ اصلاحشده ریاستارت شد (تکنمونه، پروکسی 3067)

### ۱۴۰۵/۰۶/۱۰ — اسکریپت tools/check-server.sh

**بررسی سلامت سرور از GET /api/health:**
- خروجی روی صفحه: [سالم]/[پایین] + uptime واقعی (d/h/m) + نسخهٔ build + زمان build + تاریخ
- به‌صورت پیش‌فرض نتیجه را از telegram_send.py به تلگرام می‌فرستد؛ `--no-telegram` فقط صفحه (برای cron/supervisor)
- Exit code: 0 = سالم، 1 = پایین/بدون پاسخ/JSON نامعتبر، 2 = خطای گزینه
- گزینه‌ها: `--no-telegram`، `--url <url>`/`--url=<url>`، `--help`؛ env `HEALTH_URL`
- تأیید زنده: سالم rc=0 + پایین rc=1 + JSON نامعتبر rc=1 + تحویل واقعی به تلگرام (outbox 0)
- README به‌روز شد (ردیف check-server.sh)

### ۱۴۰۵/۰۶/۱۰ — تطبیق جدول tools/README.md با همهٔ فایل‌های پوشه (۳۱ اسکریپت)

- ۱۳ فایل مستندنشده پیدا و به جدول اضافه شد: check-rtl-headers.sh، check-stale-build.ps1، preview-publish.sh، compare-designer-downloads.sh، fix-double-utf8.ps1، telegram_bridge.py (قدیمی — جایگزین telegram_agent.py)، test_modules.py، windows_mcp_client.py و ۶ کمکی تست UI (nav/capture_to_file/ocr_text/fill_step/png_boxes/png_teal_scan — در یک ردیف گروهی)
- هر ۳۱ فایل `.sh/.py/.ps1/.sql` پوشهٔ tools حالا در README ذکر شده‌اند (قبلاً ۱۸)

### ۱۴۰۵/۰۶/۱۰ — تست امنِ دستور re-register وظیفهٔ TelegramAgent

- ساختار وظیفهٔ زنده `Tarazin\TelegramAgent` با قالب `tools/telegram_agent_task.xml` مقایسه شد: **معادل کامل** — همان triggerها (Logon + هر ۵ دقیقه)، همان Command/Arguments/WorkingDirectory (python.exe ← tools/telegram_agent.py ← ریشه). تفاوت فقط ترتیب عناصر و فیلدهای پیشفرض است که Task Scheduler هنگام import خودش اضافه میکند
- دستور `schtasks //create //tn ... //xml <template> //f` با نام موقت `Tarazin\TelegramAgentDryRun` تست شد: SUCCESS rc=0، سپس حذف شد (SUCCESS rc=0) — وظیفهٔ واقعی دستنخورده ماند
- تأیید نهایی: وظیفهٔ زنده Enabled/Ready با همان دستور؛ Last Result=2 از اجرای ۵ دقیقهای = خروج تمیز گارد تکنمونه (agent از قبل بالاست — pid 30472 زنده، transport پروکسی، last_success)

### ۱۴۰۵/۰۶/۱۰ — تسک T-DC272185 (انتخاب کالا دیالوگی + واحدهای چندگانه) — بخش‌های عمده انجام شد

**✅ انتخاب کالا دیالوگی (جستجو + صفحه‌بندی + موجودی + قیمت):**
- کامپوننت مشترک جدید `Tarazin.Ui/Components/ItemPickerCell.razor` ساخته شد — به‌جای MudSelect دستی، دیالوگ `SelectorDialog<ItemRow>` را از طریق `EntityPickerService` باز می‌کند
- ستون‌ها: کد / عنوان / واحد / **موجودی** / **قیمت واحد** / گروه + جستجو روی کد/عنوان/SKU/بارکد/برند + صفحه‌بندی ۱۰تایی
- قیمت واحد قلم به‌صورت خودکار از قیمت کالا پیش‌فرض می‌شود (اگر صفر باشد)
- در ۴ صفحه اعمال شد: PurchaseInvoiceEntry، SalesInvoiceEntry، PurchaseReturnEntry، SalesReturnEntry (ReturnLine دو صفحه UnitPrice گرفت)
- StoreEntry/TreasuryEntry قبلاً EntityPickerField داشتند؛ حالا انبار هم الگوی یکپارچه دارد

**✅ واحدهای چندگانهٔ کالا با ضریب تبدیل (زیرساخت کامل + UI):**
- جدول جدید `inventory.ItemUnits` (ItemId+UnitId یکتا، Factor، IsDefault، IsDeleted) در `_Ensure.sql`
- اسکریپت‌های جدید: `ItemUnitsList.sql` (واحدهای یک کالا) و `ItemUnitsUpsert.sql` (جایگزینی اتمی با JSON؛ الزام یک واحد پیش‌فرض)
- مدل `ItemUnitRow` در InventoryModels.cs
- تب «واحدهای چندگانه کالا» در ItemDialog: افزودن/حذف واحد، ضریب تبدیل، پیش‌فرض؛ ذخیره بعد از ItemUpsert (برای کالای جدید شناسه با ItemList بازیابی می‌شود)
- تست زنده روی DB: upsert Success=1 + list هر دو واحد با Factor درست (پیش‌فرض=۱، دومی=۱۰۰۰)

**✅ از قبل موجود (تأیید شد):** کالاها/گروه‌ها/واحدها per-company؛ گزارشات per-warehouse؛ PriceFeedService آنلاین (TABLOTALA طلا/سکه/فلز)

**تأیید:** build ۰ خطا، تست انبار ۱۴/۱۴، هات‌ریلود اعمال شد، صفحه 200

**نکته:** اجرای `_Ensure.sql` در دیتابیس زنده با `-I` الزامی است (QUOTED_IDENTIFIER برای ایندکس‌های فیلترشده) — بدون آن Msg 1934 می‌گیرد

### ۱۴۰۵/۰۶/۱۰ — چهار تسک دکمه‌ای تلگرام: ضریب تبدیل + چندقلمی + قیمت زنده + تست DB

**T-BF9A7353 (اعمال ضریب تبدیل واحدها در فاکتور):**
- خطوط Purchase/Sales: UnitId+Factor+Units؛ پس از انتخاب کالا واحدهای ItemUnitsList بارگذاری و واحد پایه پیش‌گزیده می‌شود
- MudSelect واحد کنار تعداد؛ `Qty × Factor` (BaseQty) در CalcLineTotal و JSON ارسالی
- برگشت‌ها چون به InvoiceLineId ارجاع دارند، واحد خط مبدأ را می‌گیرند (درست — تغییری لازم نبود)

**T-FE1FCDB4 (افزودن چند قلم از یک دیالوگ):**
- SelectorDialog حالت MultiSelect گرفت (چک‌باکس + select-all + برگرداندن لیست via SelectorResult.Items)
- EntityPickerService.PickManyAsync اضافه شد
- دکمهٔ «افزودن چند قلم از دیالوگ…» در فاکتور خرید و فروش (تکرارها نادیده گرفته می‌شوند؛ واحدها/قیمت پیش‌فرض اعمال می‌شود)

**T-023663E6 (قیمت زنده TABLOTALA در انتخاب کالا):**
- اسکریپت جدید `inventory/ItemListLive.sql` — ItemList + LivePrice/LiveSource/LiveItemKey از currency.PriceItems/PriceRates (تطبیق ItemCode↔ItemKey + از طریق goldshop.InventoryItemCode)
- ستون «قیمت زنده» (⚡ وقتی منبع TABLOTALA) در ItemPickerCell؛ ۴ صفحهٔ فاکتور از ItemListLive
- تست زنده: XAU-18 → OnlineRate 221,847,730 از TABLOTALA

**T-36D6DD97 (تست دیتابیس انتخاب کالا):**
- `Tarazin.Tests/ItemPickerDbTests.cs` — ۲ تست SkippableFact: (۱) ItemListLive قیمت زنده را الحاق می‌کند، (۲) ItemUnitsUpsert/List واحد پیش‌فرض (Factor=1) و ضریب ۱۰۰۰ را ذخیره/بازمی‌گرداند — 2/2 پاس
- نکته: کلیدهای تست یکتا (Guid) برای جلوگیری از تداخل بین تست‌ها؛ PriceRates ستون CreatedBy ندارد (کشف در تست)

**تأیید:** build ۰ خطا؛ همهٔ کلاس‌های انبار در ایزوله پاس (15/15 + picker 2/2)؛ شکست‌های اجرای ترکیبی همان contention شناخته‌شدهٔ دیتابیس مشترک است (نه رگرسیون)

### ۱۴۰۵/۰۶/۱۰ — تسک T-2BBE8E60: «seed بعد از هر مرحله» → `--reseed` idempotent

- **مشکل**: `seed-demo-data.sh` گارد «قبلاً seed شده» داشت؛ اجرای مجدد فقط با `--force` ممکن بود که ردیفها را تکرار میکرد (movements/چک/فاکتور duplicate) — کار «سید بعد از هر مرحله» را عملاً غیرممکن میکرد.
- **راهحل**: فلگ جدید `--reseed` = پاکسازی نمونههای قبلی + سید نو. فایل جدید `tools/seed-cleanup.sql`.
  - پاکسازی فقط نشانگرهای خودِ sampleها: توضیحات «نمونه»، حرکت «حواله بابت GINV-»، چک `CHQ-SAMPLE%`، فاکتور طلا با قلم `XAU-24`، صندوق/بانک `SourceReference=GoldInvoice:%`. سید اصلی (`_Seed.sql` با GINV-00001/XAU-18) هرگز لمس نمیشود.
  - ترتیب امن FK: خطوط/دفتر طرفحساب/سرفاکتور طلا ← لایههای FIFO + حرکات (soft-delete) ← ارز ← اسناد حسابداری ← صندوق/بانک (برگرداندن تراز) ← چک → بازمحاسبه `Items.StockQty` از StockLayers.
- **تست زنده روی دیتابیس**: سه بار `--reseed` پیاپی → حرکات نمونه = ۳ ثابت، فاکتور sample XAU-24 = ۱ ثابت، GINV-00001 سید اصلی = ۳۶۴ دستنخورده، موجودی صحیح (GOLD-18=90، GOLD-24=48). ✅
- ابزار قبلی `--force` باقی ماند (با هشدار «نمیتواند تکرار کند»).
- README (tools) بهروز شد.

### ۱۴۰۵/۰۶/۱۰ — قانون ۴: reseed خودکار بعد از هر تسک صف تلگرام

- `tools/telegram_queue.py` دستور `complete` را تغییر داد: بعد از ثبت تسک،
  خودکار `bash tools/seed-demo-data.sh --reseed` را اجرا میکند (subprocess با
  timeout 240s، خروجی در `~/.telegram-bridge/agent/reseed.log`).
- غیر-کشنده: هر خطا در reseed فقط در log ثبت میشود و تسک همچنان completed میماند.
- خاموشکردن موردی: `complete TASK-ID "..." --no-reseed`.
- تست زنده: تسک آزمایشی T-TESTRESEED → rc=0، «Demo data seeded» در log ✅
- README tools + rules.md + بخش قوانین دائمی HANDOFF بهروز شدند.

### ۱۴۰۵/۰۶/۱۰ — تست خودکار seed-cleanup (Tarazin.Tests/SeedCleanupTests.cs)

- دو تست SkippableFact جدید روی دیتابیس زنده:
  1. `SeedCleanup_RemovesSampleArtifacts_KeepsCoreSeed` — seed کامل نمونهها
     (حرکت «نمونه» + لایه FIFO + حرکت GINV + فاکتور XAU-24 با خط/دفتر +
     چک CHQ-SAMPLE + صندوق «نمونه» + سند با GINV) + کنترلهای سید اصلی
     (حرکت عادی، فاکتور XAU-18/GINV-00001، چک عادی، سند عادی) →
     نمونهها حذف/باطل/soft-delete شدند و کنترلها دستنخورده ماندند.
  2. `SeedCleanup_RecomputesStock_FromRemainingLayers` — بعد از حذف لایهٔ
     sample، StockQty از لایهٔ باقیمانده بازمحاسبه میشود (25 گرم).
- نکتهٔ پیادهسازی: اسکریپت از پارامتر sqlcmd `$(CompanyId)` استفاده میکند؛
  تست آن را با مقدار واقعی جایگزین و `GO` را حذف میکند (Dapper نمیتواند GO).
- اجرا: 2/2 سبز روی دیتابیس زنده + کل سوئیت انبار 16/16 (بدون regression).

### ۱۴۰۵/۰۶/۱۰ — هشدار تلگرام هنگام شکست reseed خودکار

- `run_auto_reseed` در `tools/telegram_queue.py` حالا وقتی `ok=False` باشد
  (rc≠0 یا «Demo data seeded» در خروجی نباشد) یا exception بگیرد، یک پیام
  هشدار با `priority=high` از طریق `telegram_send.py` به تلگرام میفرستد
  (شامل rc + آخرین خطوط خروجی + مسیر reseed.log). تابع کمکی `_notify_telegram`
  best-effort است و هرگز تسک را fail نمیکند.
- تست: (۱) مسیر ارسال با پیام تست → تحویل شد (outbox 0)؛ (۲) شبیهسازی شکست
  با subprocess موک (rc=3) → هشدار ثبت و تحویل شد.
- rules.md + بخش قوانین دائمی HANDOFF بهروز شدند.

### ۱۴۰۵/۰۶/۱۱ — پنج تسک صف تلگرام (report/auto-tests/reseed button/link dialog)

- **باگ `claim` در `telegram_queue.py` رفع شد**: این دستور `save()` را صدا نمی‌زد؛
  تسک‌ها claimed می‌شدند ولی هرگز در فایل ذخیره نمی‌شدند (پس از هر claim، دوباره ready).
  تست: `claim T-4404496B` → `in_progress` در دیسک.
- **گزارش کامل وضعیت انبار** → تلگرام: ۱۴ صفحه، ۳۴ اسکریپت، ۲۲ تست/۷ کلاس، یکپارچگی‌ها.
- **تست خودکار انبار بعد از هر تسک** (قانون دائمی): `run_auto_inventory_tests` در
  `complete` — هر کلاس جداگانه اجرا می‌شود (contention DB مشترک شناخته‌شده) + retry-یک‌بار
  + هشدار تلگرام روی شکست؛ log در `~/.telegram-bridge/agent/tests.log`؛ خاموش‌کردن با `--no-tests`.
- **باگ واقعی LotSerial یافت/رفع شد**: `DECLARE @SerialsJson` هم‌نام پارامتر ارسالی در
  Purchase/SalesInvoiceInsert → «already declared». حذف DECLARE و هم‌اهنگ‌سازی
  InvoiceLegacyParamGuardTests با الگوی پروژه (همیشه NULL بفرست) → هر ۳ تست گارد + LotSerial سبز.
- **دکمه «بازسازی دادهٔ نمونه»** در تب «داده نمونه» تنظیمات انبار + `DemoDataSeedingService`
  + endpoint `POST /api/tools/reseed` در Tarazin.Web.
- **دیالوگ اتصال طلا↔انبار**: `ItemStockInfo.sql` جدید + ستون‌های LastPurchasePrice/
  LastSalePrice در `ItemListLive` — نمایش موجودی لحظه‌ای، قیمت آخرین خرید و قیمت زنده در دیالوگ.

### ۱۴۰۵/۰۶/۱۱ — صف تلگرام: ۶ تسک دکمهای اجرا/بررسی شد + رفع تداخل

- **علت «صف اجرا نمیشود»**: ۶ تسک از کلیک دکمهها (۳:۵۸ و ۴:۴۱) در صف مانده بودند و
  هیچ نمونه اجرا نکرده بود — نه تداخل اسکریپت. اکنون هر ۶ claimed/completed:
  - T-AF8B6020/T-4E2CEDC7: تکرار تسکهای قبلی (اتصال طلا↔انبار، تست خودکار) ✅
  - T-E920A4D6: تست لینک/قطع/ذخیره از قبل در GoldItemLinkTests هست ✅
  - T-FB598C7C: **کامپوننت مشترک جدید `ReseedButton`** + دکمه در تنظیمات طلا و خزانه ✅
  - T-57FAF691/T-CFE1019E: **فیلتر انبار فعال نشست در لیست فاکتورها** — Searchها
    `@WarehouseId` گرفتند و هر دو صفحه آن را از `Session.ActiveWarehouseId` میفرستند ✅
- **تداخل consumer در agent.log** (pid 30472) مربوط به نمونهٔ قبل از ریاستارت بود —
  اکنون فقط pid 28252 در حال poll است (uptime ۹۵ دقیقه، خطا ۰).
- ۲۲ تست انبار سبز بعد از تغییرات SQL؛ صف `active=0`.

### ۱۴۰۵/۰۶/۱۱ — بازبینی کامل ربات تلگرام (رفع باگ --text)

**مشکل اصلی (علت «پیام نامربوط»):** `tools/telegram_send.py` فلگ `--text` را نمیپذیرفت. چون parser ناشناختهها را بهعنوان آرگومان موقعیونی میگرفت، فراخوانیِ `--text "پیام"` در عمل خودِ رشتهٔ `--text` را بهجای پیام میفرستاد. هم `_notify_telegram` (telegram_queue.py) و هم ارسالهای دستی از این مسیر آسیب میدیدند.
- **رفع:** کاهشِ `--text MESSAGE` در telegram_send.py بههمراه حفظ حالت موقعیونی (backward compatible).
- **تست:** ۳ کیس پالسر (--text / موقعیونی / --text + --buttons) با outbox موقت سبز شدند + ارسال زندهٔ E2E از طریق agent تحویل شد (outbox 0).
- نکته: `_notify_telegram` حالا درست کار میکند و نیازی به تغییر نداشت.

**علت «تعامل ناقص»:** دکمهها/پیامها task میسازند ولی اجرا فقط با claim-next نشست Freebuff انجام میشود؛ ۴ تسک ready از کلیکهای قبلی بیاجرا مانده بودند. اینجا همگی اجرا و بسته شدند.

**۴ تسک صف (انجامشده):**
- `T-0280B7B4` + `T-F1530259` — پسورد admin به `admin` ریست شد (PBKDF2 100k/SHA256 مستقیم روی DB، Verified MATCH=True).
- `T-7DCEF876` — `Tarazin.Tests/WarehouseFilterTests.cs` (۲ تست فیلتر @WarehouseId در Purchase/SalesInvoiceSearch؛ 2/2 سبز).
- `T-24033C77` — انتخاب دستی انبار از Purchase/SalesInvoiceEntry حذف؛ انبار فقط از نوار بالا (نشست) و نمایش فقطخواندنی `_warehouseTitle`.
- بهعلاوه: `_Ensure.sql` بیلاین `inventory.Warehouses` به حالت زندهٔ DB اصلاح شد (CompanyId + UpdatedAt/CreatedBy/UpdatedBy + یونیک شرکت-محور UX_Warehouses_Company_Code + ایندکس IX_Warehouses_Company) — بیلاین قبلی فاقد CompanyId بود و ساخت DB تازه را میشکست.

**پس از تسکها:** reseed خودکار ✅ و ۷ کلاس تست انبار ✅ (بدون regression؛ build UI 0 error/0 warning).


### ۱۴۰۵/۰۶/۱۱ — ترنسپورت دوگانه ربات تلگرام: webhook یا long-poll

- `tools/telegram_agent.py` حالا دو ترنسپورت دارد (`TELEGRAM_TRANSPORT` در `.telegram-agent.env`):
  - `auto` (پیش‌فرض): اگر `TELEGRAM_WEBHOOK_URL` ست شده باشد webhook، وگرنه long-poll.
  - `poll`: getUpdates با offset (fallback پایدار؛ پروکسی حفظ می‌شود).
  - `webhook`: setWebhook + گیرنده‌ی محلی `TELEGRAM_WEBHOOK_LISTEN` (پیش‌فرض 127.0.0.1:8443)؛ آپدیت‌ها فوری و بدون 409 می‌رسند.
- کلیدهای جدید: `TELEGRAM_WEBHOOK_URL`, `TELEGRAM_WEBHOOK_SECRET` (اگر خالی باشد خودکار ساخته و در config ذخیره می‌شود), `TELEGRAM_WEBHOOK_LISTEN`.
- وب‌هوک فقط با URL عمومی HTTPS معنا دارد (مثلاً تونل)؛ بدون آن `auto` همان long-poll است — فعلاً روی poll فعال است.
- شروع `poll` → webhook کهنه خودکار حذف می‌شود (رفع 409)؛ شروع `webhook` → خودکار setWebhook می‌زند؛ تغییر config → ری‌استارت خودکار.
- status.json فیلدهای `mode` و `webhook_url` و `webhook_registered` اضافه شد (نمودار سلامت Blazor بدون تغییر می‌خواند).
- تست‌های `test_telegram_agent.py` به ۵۶ مورد رسید (ترنسپورت، پارامترهای setWebhook، گیرنده با secret، پاک‌سازی کهنه).


### ۱۴۰۵/۰۶/۱۱ — خودکارسازی اجرای صف تلگرام (TelegramAutopilot، هر ۱ دقیقه)

**مشکل:** دکمههای تلگرام Task `ready` در `queue.jsonl` میسازند ولی Freebuff فقط صف
خودش (`queue_items` در `desktop-v2.db`) را اجرا میکند — صف تلگرام تا وقتی نشست
دستی claim-next نمیزد بیاجرا میماند.

**راهحل (اثباتشده روی مکانیزم خودِ اپ):** اپ Freebuff هر `queue_items` با
`delivery=queue, state=queued` را بهصورت تِرن خودکار در تردِ باز اجرا میکند
(خودِ همین درخواست از queue item 73d6d44c آمده بود). پس:

1. `tools/telegram_autopilot.py` — یکشات: اگر Task `ready` هست و دستور auto-run
   مشابهی هنوز در صف ترد executor نیست (dedupe با `skill_name=telegram-autopilot`)،
   یک `queue_items` با دستور «claim-next → اجرا → complete → گزارش تلگرام» تزریق
   میکند. هرگز خودش اجرا نمیکند و تلگرام/LLM صدا نمیزند.
2. وظیفهٔ `Tarazin\TelegramAutopilot` (Task Scheduler، هر ۱ دقیقه، XML در
   `tools/telegram_autopilot_task.xml`) — ثبت و تأیید شد (PT1M، Last Run OK).
3. ترد هدف: `TELEGRAM_AUTOPILOT_THREAD_ID` یا خودکار؛ state در
   `~/.telegram-bridge/agent/autopilot-thread` ذخیره میشود. پیشفرض ترد executor
   زیرساخت تلگرام (9374d03d…) است؛ ترد کمپین store (a2f7f98d…) تزریق نمیشود.
4. `claim`/`complete` همچنان اتمیک و توسط نشست Freebuff انجام میشود → reseed و
   تستهای خودکار همانجا میمانند.

**تأیید زنده:** ۲ Task آماده (T-499ED10D, T-60C56D73) → autopilot یک آیتم
`b37d48a2` در ترد 9374d03d تزریق کرد (state=queued)؛ اجرای دوم dedupe شد
(«already pending — skipped»). بعد از پایان این تِرن، اپ آن را خودکار اجرا و صف
را خالی میکند.

### ۱۴۰۵/۰۶/۱۱ — بررسی webhook/تانل: مسدودیت DNS کارینگ؛ بازگشت به long-poll

**وضعیت:** ربات در حالت **long-poll از طریق پروکسی (سالم)** است — agent pid 1964،
outbox_pending 0، failures 0. تست ارسال واقعی: ✅.

**یافتهٔ کلیدی:** تونل‌های cloudflared روی این شبکه **شدنی نیستند**:
- `cloudflared` نصب شد (scoop, 2026.8.3) و URL موقت trycloudflare می‌گیرد، اما
  هر ۱۲ تا ۳۵ ثانیه با خطای `Couldn't resolve SRV record region1/region2.v2.argotunnel.com`
  می‌میرد. `--protocol http2` هم همین خطا (SRV فراتر از پروتکل است).
- علت: DNS کارینگ (VPN) رکوردهای SRV دامنهٔ argotunnel.com را مسدود/بی‌پاسخ می‌کند
  (تست nslookup/پرس‌وجوی مستقیم 8.8.8.8/1.1.1.1/OpenDNS همگی timeout).
- راه‌حل hosts هم جواب نمی‌دهد: Go فقط A-record را از hosts می‌خواند، SRV همیشه
  از DNS سیستم پرسیده می‌شود.
- localhost.run: اتصال SSH بلافاصله بسته شد (احتمالاً مسدودیت کارینگ).
- localtunnel (loca.lt): برای webhook مناسب نیست (صفحهٔ رمز عبور به Telegram می‌رسد).

**اقدامات:**
- T-A27BB5E1 (cloudflared سریع): `failed` با دلیل کامل.
- T-60C56D73 (webhook با تونل): همچنان `in_progress` — منتظر انتخاب کاربر.
- گزینه‌ها با ۴ دکمه به تلگرام ارسال شد: بازگشت long-poll (پیشنهاد) /
  تانل با اکانت Cloudflare / تانل روی VPS شخصی / بعداً.
- حالت webhook کدش سر جایش است و فقط با یک `TELEGRAM_WEBHOOK_URL` معتبر و پایدار
  (خارج از این شبکه) فعال می‌شود؛ agent به‌صورت خودکار webhook کهنه را قبل از
  poll پاک می‌کند (امشب در عمل تست شد ✅).

### ۱۴۰۵/۰۶/۱۱ — گزارش شکافها: جریان سفارشهای فروشگاه در گزارشات انبار (T-F046C927)

**خلاصه:** موتور موجودی یکپارچه است (فروشگاه و انبار هر دو inventory.Movements/StockLayers را مصرف میکنند)
و تراز حسابداری/موجودی درست است؛ شکاف فقط در **لایهٔ دید/گزارش** است.

**شکاف G1 — لیست فاکتور فروش انبار، فروش POS را نمیبیند:**
`SalesInvoiceSearch.sql` فقط از `inventory.Invoices` (OperationType=Sales) میخواند؛ سفارشهای فروشگاه در
`store.Orders` هستند → فروش POS هیچوقت در لیست/گزارش فروش انبار ظاهر نمیشود (فقط از گزارشات خود فروشگاه دیده میشود).
حسابداری هر دو را میبیند (سند با SourceReference=StoreOrder:).

**شکاف G2 — حرکات بدون نشانگر مبدأ:** `inventory.Movements` ستون SourceReference ندارد؛ حرکات فروشگاه
(«حواله بابت ORD-...») از حرکات فاکتور فروش انبار فقط با متن آزاد Description قابل تشخیصاند، نه با فیلتر ساختاری.
پس تفکیک «فروش کانال فروشگاه» از «فاکتور فروش انبار» در DailyMovements/StockCardReport ممکن نیست.

**چه چیزهایی درست/شامل است (بدون شکاف):** DailyMovements (حرکات را میبیند — هر دو کانال ✅)،
StockBalanceReport و StockValue (از Items/StockLayers — ریاضی موجودی درست ✅)، DashboardSummary
(TodayMovements از Movements ✅)، BI (از Movements ✅). جایی دوبارهشمارش (double count) وجود ندارد.

**گزینههای بستن شکاف (به تلگرام ارسال شد):**
- A) ستون SourceReference به inventory.Movements + مقداردهی از OrderPlace/فاکتورها/انبارگردانی + فیلتر مبدأ در گزارشات
- B) نمایش فقطخواندنی سفارشهای فروشگاه در لیست فروش انبار (UNION در SalesInvoiceSearch)
- C) فقط مستندسازی وضعیت فعلی (منطق سالم است؛ تفاوت صرفاً در دید لیستها)

### ۱۴۰۵/۰۶/۱۱ — بستن شکافهای A+B (T-468AF117 / T-2D51A952 / T-514367BD)

**شکاف A — SourceReference روی inventory.Movements (انجام شد):**
- ستون `SourceReference NVARCHAR(120)` به Movements اضافه شد (زنده + `_Ensure` idempotent).
- مقداردهی همهٔ نویسندهها: PINV:id (خرید)، SINV:id (فروش)، RET:id (برگشت دو شاخه)،
  Transfer:id (دو حرکت)، StoreOrder:id (فروشگاه OrderPlace)، N'Stocktake'، N'Manual'.
- DailyMovements ستون SourceReference را نمایش میدهد.
- قدیمیها NULL ماندند (بدون backfill؛ از این پس همهٔ حرکات جدید مبدأ دارند).

**شکاف B — فروش POS در لیست فروش انبار (انجام شد):**
- `SalesInvoiceSearch.sql` حالا UNION دارد: فاکتورهای inventory.Invoices + سفارشهای store.Orders.
- ردیف فروشگاه: SalesInvoiceId منفی (synthetic)، Status=N'Store' (نمایش «فروشگاه (POS)»)،
  انبار و COGS از حرکات خروج همان سفارش (SourceReference=StoreOrder:id؛ عقبماندهها با Description).
- فیلترهای تاریخ/جستجو/وضعیت/مشتری/انبار برای هر دو کانال اعمال میشود؛ صفحه فقط نمایشی است.

**تأیید:** WarehouseFilterTests 2/2، StoreOrderE2ETests 2/2، InventoryPhase5Tests 6/6،
InventoryMovementInsertTests 5/5، LotSerialTests 3/3 (همه در ایزوله سبز؛ timeoutهای دستهجمعی
رقابت شناختهشده روی DB زنده است). لاگ ربات: یک خط آرام برای watchdog هر ۵ دقیقه (رفع طوفان «another consumer»).


### ۱۴۰۵/۰۶/۱۲ — شمارهٔ مشترک بین ۴ ماژول + گزارش DocumentTrace (T-B7364145)

**درخواست:** بررسی کامل ارتباط فروشگاه، انبار، خزانه و حسابداری؛ یک «شمارهٔ مشترک» برای
ردیابی زنجیره در SQL و ساخت گزارش.

**یافتهٔ معماری — شمارهٔ مشترک از قبل وجود دارد (`SourceReference`):**
- قرارداد کلید مشترک `'{Prefix}:{LocalId}'` است که همهٔ ماژولها هنگام ثبت مینویسند:
  - `StoreOrder:{id}` → فروشگاه (سند + نقد/چک خزانه + حرکت انبار)
  - `SalesInvoice:{id}` / `PurchaseInvoice:{id}` → انبار (سند حسابداری + حرکت)
  - `Cheque:{id}` → چک + حرکت نقدی + سند وصول
  - `Invoice:{id}` → دریافت نقدی بابت فاکتور (کلید idempotency قدیمی)
  - `Payroll:{RunId}`، `Stocktake`، `Manual`
- لنگر حسابداری: `accounting.Documents.DocumentId` که انبار/فروشگاه روی فاکتور/سفارش ذخیره میکنند.

**شکاف بستهشده — لنگر مستقیم خزانه ↔ حسابداری (انجام شد):**
- ستون `DocumentId INT NULL` به `treasury.CashMovements` و `treasury.Cheques` اضافه شد
  (زنده + `treasury/_Ensure.sql` idempotent + ایندکس فیلترشدهٔ IX_*_DocumentId).
- مقداردهی نویسندهها:
  - `OrderPlace.sql`: بعد از ساخت سند، نقد/چکِ همان سفارش DocumentId سند را میگیرند.
  - `ChequeStatusChange.sql`: چک و حرکت نقدیِ وصول، DocumentId سند وصول را میگیرند.
  - `CashEntryFromInvoice.sql`: DocumentId از فاکتور مبدأ (Inventory/Store) resolve میشود.

**گزارش جدید — `accounting/DocumentTrace.sql` (Query، خودکار embed میشود):**
- ورودی `@DocumentId` یا `@SourceReference` (هر دو nullable؛ حداقل یکی مقدار).
- خروجی: یک ردیف برای هر «پای» زنجیره — حسابداری، انبار (فاکتور)، فروشگاه (سفارش)،
  خزانه (نقد)، خزانه (چک)، حرکت انبار — با DocumentId/DocumentNumber مشترک.
- نمونهٔ استفاده (Dapper):
  `QueryAsync(Script("DocumentTrace.sql"), new { DocumentId = docId, SourceReference = (string?)null })`

**تأیید:** StoreOrderE2ETests 3/3 (تست جدید Document_trace_links_store_inventory_treasury_accounting
لنگر DocumentId روی خزانه و هر دو حالت ورودی گزارش را میسنجد)؛ TreasuryCashMovementInsertTests 3/3،
TreasurySourceLabelsTests 30/30، SourceDetailSqlGuardTests 5/5، OrderStateMachineTests 6/6.


### ۱۴۰۵/۰۶/۱۲ — دکمهٔ «ردیابی زنجیره» در صفحهٔ سند حسابداری

- کامپوننت جدید `Tarazin.Ui/Modules/Accounting/Components/DocumentTraceDialog.razor`:
  گزارش `accounting/DocumentTrace` را اجرا و همهٔ پاهای زنجیره (حسابداری، انبار، فروشگاه،
  خزانه نقد/چک، حرکت انبار) را با تراشهٔ رنگی ماژول + شمارهٔ مشترک SourceReference نمایش می‌دهد.
  ورودی `DocumentId` یا `SourceReference` (nullable).
- مدل `DocumentTraceRow` به `Tarazin.Share/AccountingModels.cs` اضافه شد.
- دکمهٔ «ردیابی زنجیره» (AccountTree) در نوار ابزار `AccountingDocument.razor` کنار چاپ سند.
- Build: 0 خطا. تأیید: StoreOrderE2ETests 3/3 سبز (گزارش DocumentTrace همان مسیر Dapper را می‌سنجد).


### ۱۴۰۵/۰۶/۱۲ — فیلتر مبدأ حرکت در اسناد روز انبار (DailyMovements)

- `DailyMovements.sql`: با CROSS APPLY، مبدأ هر حرکت از SourceReference استخراج می‌شود
  (SourceType = پیشوند قبل از ':' و SourceId = شناسه) و فیلتر `@SourceType` اضافه شد
  (NULL/خالی = همه).
- پیشوندها: StoreOrder (فروشگاه)، PINV (فاکتور خرید)، SINV (فاکتور فروش)، RET (برگشت)،
  Transfer (انتقال)، Stocktake (انبارگردانی)، Manual (دستی). ردیف‌های قدیمی بدون
  SourceReference → مبدأ «—» (بدون backfill، طبق تصمیم قبلی).
- `InventoryHome.razor`: فیلتر «مبدأ حرکت» (Dropdown) + ستون «مبدأ» با تراشهٔ رنگی.
- `DailyMovementRow` (Tarazin.Share): + SourceReference/SourceType/SourceId.
- تأیید: کوئری با هر فیلتر روی DB زنده rc=0 و فیلتر دقیق؛ build 0 خطا؛
  InventoryMovementInsertTests 5/5 و InventoryPhase5Tests 6/6 ایزوله سبز.


### ۱۴۰۵/۰۶/۱۲ — ردیابی زنجیره از سمت خزانه (چک/نقد) — T-C72EDBD8

- `TreasuryCheques.razor`: کنار دکمهٔ «جزئیات منبع»، دکمهٔ «ردیابی زنجیره» (AccountTree)
  اضافه شد که DocumentTraceDialog را با SourceReference چک باز می‌کند.
- `TreasuryHome.razor` (گردش روز صندوق/بانک): ستون «ردیابی» + دکمهٔ AccountTree روی هر
  حرکت نقدی دارای SourceReference؛ `IDialogService Dialog` تزریق شد.
- `DailyCashMovements.sql` + `DailyCashMovementRow` (Tarazin.Share): ستون SourceReference.
- تأیید: build 0 خطا؛ TreasuryCashMovementInsertTests 3/3، TreasurySourceLabelsTests 30/30،
  SourceDetailSqlGuardTests 5/5 ایزوله سبز.


### ۱۴۰۵/۰۶/۱۲ — فیلتر مبدأ در کاردکس کالا (StockCardReport) — T-49B98C1D

- `StockCardReport.sql`: CROSS APPLY برای استخراج SourceType/SourceId از SourceReference
  (در #Card و SELECT نهایی) + فیلتر @SourceType (NULL/خالی = همه).
- `StockCardRow` (Tarazin.Share): + SourceReference/SourceType/SourceId.
- `InventoryReports.razor` (تب کاردکس کالا): dropdown «مبدأ حرکت» + ستون «مبدأ» با تراشهٔ رنگی.
- کلاس مشترک جدید `Tarazin.Share/InventorySourceLabels.cs` (Options + For) تا InventoryHome
  و InventoryReports یک منبع واحد داشته باشند (حذف کپی محلی از InventoryHome).
- تأیید: کوئری روی DB زنده rc=0 با/بدون فیلتر؛ build 0 خطا.

### 🔧 رفع ریشه‌ای — ۳ سپتامبر ۲۰۲۶ (از Task T-D6221C47)
- **Reseed موژیبیک**: `tools/seed-demo-data.sh` → `run_sql` حالا `-f 65001` دارد (sqlcmd ورودی را UTF-8 می‌خواند). قبلاً هر reseed فارسی را دوبار-انکود می‌کرد و `DoubleUtf8GuardTests` را می‌شکست (۱→۵ ردیف). بعد از این رفع، reseed تازه دادهٔ تمیز می‌سازد (گارد ۹/۹).
- **باگ تست MultiInvoiceGate** (`Tarazin.Tests/MultiInvoiceGateTests.cs`): گارد `IF NOT EXISTS` بانک BK-GATE به `CompanyId` مقید نبود → ردیف بانک شرکتِ دیگر، `bankId=0` و نقض FK می‌داد؛ و Seed خارج از `try/finally` بود → خطا ردیف‌ها را نشت می‌کرد. هر دو رفع شد + ردیف‌های نشتی (CompanyId 5402) از DB زنده پاک شد. کلاس ۳/۳.
- وضعیت کل سوئیت: ۱۷۹/۱۷۹ سبز در اجرای ایزوله (شکست‌های دسته‌ای = تداخل دیتابیس مشترک موازی، مستند).
