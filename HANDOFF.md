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
