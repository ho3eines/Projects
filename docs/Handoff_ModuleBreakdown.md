# Module-by-Module Breakdown – Tarazin ERP

## 1. Tarazin.Share
- **Purpose**: Domain‑models and shared contracts.
- **Key files**:
  - `Models/AccountingModels.cs` – POCOs for accounting entities.
  - `Models/InventoryModels.cs` – POCOs for inventory management.
  - `Models/SalaryModels.cs` – payroll and employee remuneration models.
  - `Models/Permissions.cs` – constant definitions for module‑action permissions.
  - `Models/CurrencyModels.cs` – currency‑exchange and monetary‑handling types.
  - (Other POCOs such as `CustomerModels.cs`, `SupplierModels.cs`, etc.)

- **No external dependencies** – pure C# POCOs, used by all other projects.

## 2. Tarazin.Data
- **Purpose**: Data‑access layer built on Dapper; hosts embedded T‑SQL scripts.
- **Directory layout**:
  - `Scripts/{schema}/` – each business domain (accounting, inventory, etc.) gets its own schema folder containing `.sql` files.
- **Key files**:
  - `DbService.cs` – generic Dapper wrapper handling connection, transaction, and query execution.
  - `ScriptCatalog.cs` – statically registers every script under a logical name for runtime discovery.
  - `AuditLog.cs` – entity representing an audit‑log record; inserted automatically by `DbService`.
  - `CurrentUser.cs` – abstraction for the logged‑in user, used by audit & permission checks.
- **Important scripts (examples)**:
  - `accounting/Invoice.sql` – CRUD for invoices.
  - `inventory/StockAdjustment.sql` – adjustments and reconciliations.
  - `salary/Payroll.sql` – batch payroll calculation.
  - `core/Setup.sql` – database schema creation and seed data.
- **Schema‑scan enforcement**: `tools/cross-schema-scan.sh` validates that no module accesses a script outside its declared schema; CI fails on violation.

## یکپارچه‌سازی طلافروشی با ارز، انبار، حسابداری و خزانه‌داری

- مسیر `/goldshop/parties` مشتری و تأمین‌کننده را جداگانه نشان می‌دهد (Employee ها از لیست طلافروشی حذف‌اند) و ماندهٔ ریالی، طلا، ارز و لینک تفصیلی را نمایش می‌دهد؛ `GoldPartyDelete` ابتدا لینک `GoldPartyLinks` را پاک می‌کند تا ردیف یتیم نماند و سپس soft-delete می‌کند.
- مسیر `/goldshop/settings/integration` تنظیم انبار اختصاصی، گروه تفصیلی مشتری/تأمین‌کننده (از `AccountGroupList` نوع Detil)، حساب فروش/موجودی/مالیات/صندوق/بانک (از درخت حساب‌ها با `AccountPickerField` و `TransactionalOnly=true`)، صندوق/بانک پیش‌فرض خزانه و درصد مالیات را نگهداری می‌کند.
- **معماری حساب‌ها**: حساب‌های طلافروشی از **درخت `BaseCol/BaseMoein/BaseDetil`** انتخاب می‌شوند (`AccountId = NodeId`، `AccountCode = مسیر کامل`، مثلاً `2000000` تفصیلی مشتری) — نه جدول تخت `ChartOfAccounts` — تا با `DocumentInsert` و سندهای دستی حسابداری هم‌سو باشند. `GoldShopSettings` ستون‌های `AccountCode/Title` (و `InventoryWarehouseId`/`InventoryAccountGroupId`) را ذخیره می‌کند؛ `GoldShopSettingsUpsert/Get` و `GoldShopModels` به‌روز شده‌اند.
- **اتصال حسابداری خودکار (۱۴۰۵/۰۶/۰۲)**: دیگر انتخاب دستی تفصیلی وجود ندارد. `AccountGroups.DefaultMoeinId` تعیین می‌کند هر گروه تفصیلی به کدام معین می‌رود (seed: مشتریان ← دارایی جاری 10/001، تأمین‌کنندگان ← بدهی‌های جاری 20/001، موجودی کالا ← دارایی جاری). `GoldPartyUpsert` هنگام ساخت مشتری/تأمین‌کننده، تفصیلی را با **کد ۷رقمی داخل بازهٔ گروه** (FromCode + شمارهٔ طرف‌حساب؛ مثلاً CUS-001 → `2000000`، CUS-00010 → `2000009`) می‌سازد یا بازیابی می‌کند و لینک می‌کند. `GoldItemUpsert` همین کار را برای کالاها در گروه موجودی انجام می‌دهد. صندوق/بانک سند هم به تفصیلی‌های استاندارد seed (صندوق اصلی `0000002` / بانک‌ها `0000001`) وصل می‌شوند.
- **تنظیمات شرکت مالی (منبع واحد گروه‌ها)**: گروه‌های تفصیلی مشتری/تأمین‌کننده/موجودی دیگر در صفحهٔ طلافروشی تعریف نمی‌شوند؛ صفحهٔ جدید «تنظیمات شرکت» در ماژول حسابداری (`/accounting/settings`، جدول `accounting.CompanyAccountSettings` + اسکریپت‌های Get/Upsert) منبع واحد است و همهٔ ماژول‌ها (GoldPartyUpsert، GoldItemUpsert، seed طلافروشی) از آن می‌خوانند (با fallback به تنظیمات قدیمی). صفحهٔ اتصال طلافروشی فقط انبار، حساب‌های سند و تسویهٔ خزانه را نگه می‌دارد و به تنظیمات شرکت لینک می‌دهد؛ آیتم تکراری «مشتریان و تأمین‌کنندگان» از منوی طلافروشی حذف شد.
- **یکپارچه‌سازی (۱۴۰۵/۰۶/۰۲)**: برنامه دیگر «انتخاب شرکت» ندارد — یک محیط واحد است. `AccountingContextService.ResolveAsync` بدون دیالوگ، اولین شرکت فعال را خودکار فعال می‌کند (و اگر هیچ شرکتی نباشد، فرم ایجاد شرکت نمایش داده می‌شود)؛ دیالوگ «انتخاب شرکت مالی» و `SelectCompanyAsync` از MainLayout حذف شد و چیپ بالای صفحه فقط سال مالی را نشان می‌دهد. در دیتابیس زنده فقط شرکت «تست» (CompanyId=3) فعال است و همهٔ داده‌ها (حسابداری، انبار/انبار طلا، خزانه، طلافروشی) در همان محیط یکپارچه با یک انبار کار می‌کنند.
- `GoldInvoiceCreate`/`GoldPurchaseCreate` **چندردیفه** (JSON array) با مالیات ردیفی (تیک ۱۰٪)، نرخ ارز (٪ یا مبلغ)، تسویهٔ ترکیبی (نقدی/بانک/چک/ارز/طلا/نسیه)، دفتر طرف‌حساب، انبار، کیف پول ارز، خزانه و **سند حسابداری یاداشت متوازن**. چک در `treasury.Cheques` ثبت می‌شود (Direction=In/Out, Status=Pending) و در سند حسابداری بدهکار/بستانکار بانک منعکس می‌شود. جدول `goldshop.InvoiceLines` ردیف‌ها را ذخیره می‌کند.
- جدول‌های `GoldShopSettings`، `GoldPartyLinks` و `GoldPartyLedger` و ستون‌های PartyId/PaymentStatus/CompanyId و ستون‌های AccountCode/Title/InventoryWarehouseId در startup به‌صورت idempotent ساخته می‌شوند.
- **چندشرکتی‌سازی seedها**: `central._Seed` (طرف‌حساب‌ها و سال مالی ۱۴۰۵)، `accounting._Seed` (ترازنامه/گروه‌ها/TaxRules)، `inventory._Seed` (انبار/کالا) و `treasury._Seed` (بانک/صندوق/نرخ) همه با cursor روی **همهٔ شرکت‌های فعال** اجرا می‌شوند؛ یکتایی‌های سراسری `BaseDetil.DetilCode`، `AccountGroups (Type+Code)`، `Warehouses.WarehouseCode`، `Items.ItemCode`، `Banks/CashBoxes/CurrencyRates/DayCloses` به ایندکس‌های درون‌شرکتی (`UX_*` با CompanyId) تبدیل شده‌اند و `BaseDetilCreateAuto/NextCode` نیز CompanyId-aware هستند.
- **تأیید زنده (۱۴۰۵/۰۶/۰۲)**: مشتری جدید «مشتری اتولینک تست» از UI ساخته شد → کد `CUS-00010` + **تفصیلی خودکار `2000009`** در گروه مشتریان (گروه 3) با لینک به دارایی جاری. فاکتور ۲ گرمی برای همان مشتری → سند `DocumentId=72` متوازن با `AccountCode=2000009` + ردیف دفتر مشتری + حرکت انبار Issue — بدون هیچ انتخاب دستی حساب. فاکتورهای قبلی (GINV-00007 با ۱۰ گرم و GINV-00008 ترکیبی طلا+USD) همچنان با تفصیلی `2000000` کار می‌کنند.

## یکپارچه‌سازی فروشگاه با حسابداری، خزانه و انبار (۱۴۰۵/۰۶/۰۶)

- **قبل از این تغییر** فروشگاه فقط سفارش می‌ساخت و رویداد `OrderPlaced` را در `store.Outbox` می‌نوشت؛ هیچ دیسپچری آن را مصرف نمی‌کرد و پرداخت/سند/دفتر وجود نداشت — «سفارش → انبار» هم ناتمام بود.
- `OrderPlace.sql` بازنویسی شد و دقیقاً الگوی `GoldInvoiceCreate` را اجرا می‌کند (همه در یک تراکنش): کنترل موجودی → سفارش (`Status='Invoiced'` + `PaymentStatus` Paid/Partial/Unpaid + `BalanceRial` + ستون‌های تسویه) → خروج FIFO انبار (لایه‌ها + `Movements` Issue + کاهش `StockQty` + آزادسازی رزروها) → **دفتر مشتری** (`store.OrderLedger`: بدهکار کل، بستانکار تسویه) → **خزانه** (نقد/بانک در `CashMovements` + چک در `Cheques` با `SourceReference='StoreOrder:{id}'`) → **سند حسابداری یاداشت** (`Status='Note'`، `DocumentType='Sale'`، بدهکار: نسیه/صندوق/بانک/چک، بستانکار: فروش، `SourceReference='StoreOrder:{id}'`). خروجی: `OrderId/OrderNumber/TotalAmount/BalanceRial/DocumentId`.
- **تنظیمات فروشگاه** (`store.StoreSettings` + Get/Upsert): انبار، حساب فروش/صندوق/بانک (از درخت حساب‌ها با `AccountPickerField`)، صندوق/حساب بانکی پیش‌فرض خزانه — تب «اتصال حسابداری» در `/store/settings`.
- **مشتریان فروشگاه → طرف حساب یکپارچه**: `store.Customers.PartyId` به `central.Parties` لینک شد؛ `CustomerUpsert` هنگام ساخت/ویرایش مشتری، `central.Parties` (کد `CUS-xxxxx`) + لینک حسابداری خودکار (`treasury.PartyLinks` با تفصیلی از گروه `CompanyAccountSettings.CustomerAccountGroupId` — کد ۷رقمی داخل بازهٔ گروه) می‌سازد. `_Ensure` مشتریان قدیمی بدون لینک را backfill می‌کند. `CustomerList` ماندهٔ دفتر (بدهکار/بستانکار) را هم برمی‌گرداند.
- **UI**: `StoreEntry` بخش تسویه (نقدی/بانک/چک/نسیه با تراز صفر) گرفت؛ `StoreHome` ستون‌های نسیه/تسویه/سند + دیالوگ «جزئیات سفارش» (اقلام + دفتر مشتری + مانده)؛ اسکریپت‌های `OrderItemsByOrder`، `OrderLedgerList`، `OrderLedgerBalance` و مدل‌های `OrderResultRow`، `OrderLedgerRow`، `StoreSettingsRow`، `OrderItemRow` اضافه شدند.
- **تأیید زنده (۱۴۰۵/۰۶/۰۶)**: از UI سفارش ORD-00004 (سارا رضایی، سکه طلا ۶۲٬۰۰۰٬۰۰۰ با تسویهٔ نقد ۴۲٬۰۰۰٬۰۰۰ + چک CHQ-UI-0002 به مبلغ ۲۰٬۰۰۰٬۰۰۰) ثبت شد → سند ۸۹ **متوازن** (صندوق ۴۲M + بانک ۲۰M ← فروش ۶۲M)، ردیف دفتر مشتری ۶۲M/۶۲M، حرکت خزانه CSH-00027، چک Pending و حوالهٔ انبار SIKKEH ۸۵→۸۴. دیالوگ جزئیات و تب اتصال حسابداری از UI تأیید شد.
- نکته: دادهٔ فروشگاه seed قدیمی روی شرکت حذف‌شدهٔ ۱ بود و به شرکت فعال ۳ منتقل شد (مشتریان/محصولات/لینک‌ها).

## چاپ اسناد حسابداری (۱۴۰۵/۰۶/۰۸)

- **دیالوگ `DocumentPrintDialog`** (در `Tarazin.Ui/Modules/Accounting/Components/`) چاپ سند حسابداری را با **دو حالت** انجام می‌دهد:
  - **چاپ ساده**: فقط ردیف‌های سند (کد/عنوان/شرح/بدهکار/بستانکار) + جمع — کم‌پدینگ و ستون‌ها کنار هم.
  - **چاپ پیشرفته**: یک جدول تودرتوی **کل (۲ رقم) ← معین (۵ رقم) ← تفصیل (ریز ردیف‌ها)** — هر کل زیر خودش معین‌ها و هر معین زیر خودش ریز ردیف‌های از کدِ همان معین را نشان می‌دهد و جمع هر سطح از ردیف‌ها محاسبه می‌شود. ردیف‌های کل/معین با بک‌گراند و نشانِ «کل»/«معین» مشخص می‌شوند.
  - عناوین کل/معین از اسکریپت `accounting/DocumentPrintRollup.sql` می‌آیند؛ جمع‌ها در UI از `Model.Lines` باز‌محاسبه می‌شوند.
- **دکمهٔ چاپ با منوی دو حالته** هم در صفحهٔ سند (`AccountingDocument.razor`) هم در صفحهٔ ثبت سند (`AccountingEntry.razor`) اضافه شده تا از «ثبت و ویرایش سند» هم قابل دسترس باشد.
- **دکمهٔ «دانلود PDF»** در دیالوگ، از مسیر سرور (QuestPDF) PDF می‌سازد: `PdfReportService.BuildDocumentPdf(model, paperSize)` (A4/A5 پرتره، RTL، کدی/عنوان/شرح/بدهکار/بستانکار + جمع و وضعیت متوازن) و نام فایل استاندارد فارسی از `PdfFileNames.Document(...)` (سند-{شماره}-{ساده/پیشرفته}-{تاریخ شمسی}-{اندازه}.pdf) ساخته و با `IPdfSaver` دانلود می‌شود.
- **سربرگ رسمی + QRCode**: همهٔ چاپ‌ها از `PrintBrandHeader` استفاده می‌کنند (بخشی از تنظیمات شرکت مالی؛ لوگو/نام/آدرس + QRCode پیگیری سند). `_Host.cshtml` اسکریپت‌های `qrcode.js` و `brand.js` را بار می‌کند.
- **CSS چاپ/پیش‌نمایش**: جدول‌های MudBlazor در حالت چاپ و پیش‌نمایش با `display:table` به چیدمان ستونی بازگردانده می‌شوند (جلوی «هر ردیف = کارت» در چاپ گرفته می‌شود) و هدر/فوتر رسمی با `position:fixed` روی همهٔ صفحات تکرار می‌شود.
- **پیمایش بین اسناد**: دکمه‌های «سند قبل/بعد» در صفحهٔ سند از اسکریپت `accounting/DocumentNeighbors.sql` (کوچک‌تر/بزرگ‌تر در همان سال مالی و شرکت) استفاده می‌کنند.
- **تأیید زنده**: روی سند ۸۸ (۰۰۰۰۰۰۱۸، فروش، ۳ ردیف صندوق/بانک/فروش) — منوی چاپ بعد از ریاستارت سرور (قانون طلایی بیلد) باز شد؛ چاپ پیشرفته کل ۱۰ دارایی‌ها (۸M بدهکار / ۲۸M بستانکار) با معین‌های ۱۰۱۰/۱۰۲۰ + ریز «فروش»/«بانک»، کل ۲۰ بدهی‌ها با معین ۲۰۰۰ + ریز «صندوق»، و مجموع متوازن ۲۸٬۰۰۰٬۰۰۰ را نشان داد؛ دکمهٔ دانلود PDF بدون خطا کار کرد.

## موتور چاپ عمومی (Print Engine — ۱۴۰۵/۰۶/۰۸)

- **هدف**: یک موتور چاپ واحد و قابل‌توسعه برای کل نرم‌افزار — برای هر گزارش قالب مجزا تعریف می‌شود (نه دیالوگ اختصاصی به‌ازای هر صفحه) و در حالت دیزاین قابل تنظیم است.
- **مدل قالب** (`Tarazin.Share/PrintingModels.cs`): `PrintTemplateDef` شامل `TemplateId` (کلید یکتا مثل `accounting.documents`)، `Title/Subtitle`، `PaperSize` (A4/A5)، `Orientation` (عمودی/افقی)، `MarginMm`، `FontSizePt`، پرچم‌های نمایش (هدر شرکت/فوتر صفحه/فوتر گزارش/QRCode)، باندها: `MetaFields` (هدر داده: برچسب+کلید داده) و `Columns` (ستون‌های دیتیل: Key/عنوان/عرض/تراز/فرمت N0/بولد/جمع).
- **ذخیره‌سازی**: اسکیمای `printing` با جدول `PrintTemplates` (JSON در `DefinitionJson`) + اسکریپت‌های `_Ensure/PrintTemplateList/Get/Upsert/Delete`. قالب‌ها با `IsSystem=1` به‌صورت پیش‌فرض داخلی در کد تعریف می‌شوند (فعلاً: `treasury.cheques`، `accounting.documents`، `accounting.document`) و کاربر می‌تواند با همان ID ذخیره کند تا نسخهٔ سفارشی روی آن بنشیند (سرویس، قالب ذخیره‌شده را بر پیش‌فرض ترجیح می‌دهد).
- **دو رندرر از یک قالب**:
  - `PrintSheetRenderer` (HTML خالص RTL — چاپ مرورگر/پیش‌نمایش): باندهای هدر شرکت (از `PrintBrandHeader`/تنظیمات شرکت) ← عنوان/زیرعنوان ← هدر داده (برچسب‌ها) ← جدول واقعی ← فوتر گزارش (جمع‌ها) ← فوتر صفحه (شماره صفحه). CSS در `app.css` با `@media print` + `@page` اندازه را A4/A5 و جدول را ستونی نگه می‌دارد.
  - `PdfReportService.BuildTemplatePdf` (QuestPDF سمت سرور): همان قالب را به PDF تبدیل می‌کند (ستون‌ها با عرض/تراز/فرمت از قالب؛ جمع ستون‌های دارای پرچم `Sum`).
- **هم‌راستایی چاپ/PDF (۱۴۰۵/۰۶/۰۹)**: باگ‌های تراز RTL رندرر QuestPDF رفع شد تا خروجی PDF دقیقاً مثل پیش‌نمایش/چاپ HTML باشد: (۱) تراز ستون‌ها معکوس نبود — `Start`→راست، `End`→چپ، `Center`→وسط (قبلاً `End→AlignRight` بود یعنی آینه‌ای)؛ (۲) هدر جدول با ترازِ همان ستون رندر می‌شود (`ColHeaderCell`) نه همیشه راست؛ (۳) ترتیب فیلدهای هدر داده در PDF معکوس شد تا اولین فیلد راست‌ترین بنشیند (همانند گرید RTL)؛ (۴) عنوان/زیرعنوان/بازه راست‌چین شدند؛ (۵) ردیف‌های فوتر گزارش معکوس شد (لیبل راست، مقدار چپ)؛ (۶) ردیف‌های زبرا (هر دو ردیف) به PDF اضافه شد؛ (۷) اندازهٔ فونت جدول HTML از قالب پیروی می‌کند (`font-size:inherit` به‌جای ۸.۵pt ثابت).
- **رفع «هدرِ بدون متن» در PDF قالب‌محور (۱۴۰۵/۰۶/۰۸)**: در `BuildTemplateTable` سلول‌های هدر فقط استایل می‌گرفتند و `Text(col.Title)` هرگز صدا زده نمی‌شد → همهٔ PDFهای موتور چاپ عمومی (چک‌ها، موجودی کالا، فروش روز، دوره‌های حقوق، سفارش‌ها و…) هدر ستون نداشتند (فقط نوار خاکستری خالی). با افزودن `.Text(col.Title)` بعد از `ColHeaderCell` هدرها در هر ۱۰ قالب ظاهر شدند؛ ترتیب RTL (اولین ستون راست‌ترین) و تراز هر ستون با HTML یکسان است. هم‌زمان عنوان گزارش که در هدر شرکت دوباره چاپ می‌شد (تکراری) حذف شد تا PDF دقیقاً مثل HTML یک‌بار عنوان را نشان دهد. تأیید: برون‌ریزی هر ۱۰ قالب با `pymupdf` — باند هدر بالای دیتا با ستون‌های قالب (مثل موجودی: کد→ارزش از راست به چپ)؛ تست `All_default_templates_generate_pdf_without_errors` در `Tarazin.Tests/TemplateDumpHarness.cs` هر ۱۰ قالب را در هر بیلد می‌سازد (نگهبان استثنای ساخت) و فایل‌ها را در `%TEMP%/tarazin-pdf/all` برون‌ریزی می‌کند.
- **دیالوگ عمومی `TemplatePrintDialog`**: عنوان «چاپ — {نام قالب}» + اندازه برگه + پیش‌نمایش زنده + دکمه‌های «ویرایش قالب» (می‌رود به `/central/printing?tpl={id}`)، «چاپ» (window.print) و «دانلود PDF» (QuestPDF از همان قالب، نام فایل از `PdfFileNames`).
- **صفحهٔ دیزاینر `PrintDesigner`** (`/central/printing`، منوی «پلتفرم مشترک ← مدیریت قالب‌های چاپ»): لیست قالب‌ها (ذخیره‌شده + سیستمی) + ویرایشگر (ID/نام/توضیح/عنوان/زیرعنوان/کاغذ/جهت/حاشیه/قلم/سوییچ‌ها) + ویرایش باند هدر داده (افزودن/حذف فیلد با کلید داده) + ویرایش ستون‌های دیتیل (افزودن/حذف، کلید/عنوان/عرض/تراز/فرمت/بولد/جمع) + **پیش‌نمایش زنده با نمونه داده** + ذخیره/چاپ/دانلود PDF/حذف.
- **دیزاینر آسان‌شده (۱۴۰۵/۰۶/۰۹)**: (۱) دکمهٔ «افزودن ستون» حالا منوی **الگوهای آماده** است (شماره/تاریخ/شرح/مبلغ/بدهکار/بستانکار/تعداد/طرف حساب/وضعیت/کد حساب — با کلید، تراز، فرمت و جمعِ از پیش تنظیم‌شده) + گزینهٔ «ستون خالی»؛ (۲) فیلد «کلید داده» با `MudAutocomplete` و فهرست کلیدهای شناخته‌شدهٔ پروژه پر می‌شود (دیگر حدس زدن نام فیلد لازم نیست)؛ (۳) «فرمت عدد» با منوی آماده (بدون/N0/N2/N3/N4)؛ (۴) دکمه‌های **جابه‌جایی بالا/پایین** برای ستون‌ها و فیلدهای هدر داده؛ (۵) توضیح راهنمای فارسی زیر هر بخش.
- **تنظیم به‌عنوان پیش‌فرض (۱۴۰۵/۰۶/۰۹)**: ستون `DefaultFor` به `printing.PrintTemplates` اضافه شد — یک قالب سفارشی کاربر می‌تواند «پیش‌فرض»ِ یک گزارش سیستمی شود **بدون تغییر کد**: (۱) در فهرست دیزاینر دکمهٔ ⭐ «تنظیم به‌عنوان پیش‌فرض» روی هر قالب (منوی گزارش‌های شناخته‌شده + «بدون پیش‌فرض»)؛ (۲) در ویرایشگر، فیلد «پیش‌فرض برای گزارش» (`MudSelect` از شناسه‌های شناخته‌شده) که هنگام ذخیره اعمال می‌شود؛ (۳) چیپ «پیش‌فرض: {report}» روی قالب‌هایی که پیش‌فرض‌اند. ترتیب وضوح در `PrintTemplateService.GetOrCreateDefaultAsync`: قالب با همان شناسه → قالبِ `DefaultFor` همان گزارش → قالب داخلی. اسکریپت‌های جدید: `PrintTemplateGetByDefaultFor.sql`، `PrintTemplateSetDefaultFor.sql`، `PrintTemplateClearDefaultFor.sql`.
- **تست گاردِ ترتیب وضوح (۱۴۰۵/۰۶/۰۹)**: `Tarazin.Tests/PrintTemplateResolutionTests.cs` — `GetOrCreateDefaultAsync` را با اسکریپت‌های REAL و سرویس واقعی (نه mirror) تست می‌کند: شناسهٔ مستقیم → پیش‌فرضِ شرکتِ جاری → پیش‌فرضِ سراسری → قالب داخلی؛ به‌همراه ایزولاسیون شرکت (پیش‌فرضِ شرکتِ A به B نشت نمی‌کند) و این‌که تنظیمِ پیش‌فرضِ یک شرکت، پیش‌فرضِ سراسریِ همان گزارش را آزاد می‌کند. شناسه‌های یک‌بارمصرف + پاک‌سازی در finally؛ وقتی SQL Server در دسترس نباشد Skip می‌شود.
- **تستِ بازنشانی (۱۴۰۵/۰۶/۰۹)**: `Reset_falls_back_to_global_then_builtin` در `PrintTemplateResolutionTests` — `ResetToDefaultAsync` روی قالبِ پیش‌فرضِ شرکت → وضوح پله‌به‌پله پایین می‌آید نه یک‌راست به داخلی: بازنشانیِ پیش‌فرضِ شرکت (با سراسریِ فعال) → سراسری؛ بازنشانیِ سراسری → قالب داخلی؛ بازنشانیِ قالبِ مستقیم (شناسه = گزارش) → پیش‌فرضِ شرکت؛ بازنشانیِ آخر → قالب داخلی. هر مرحله ردیف را واقعاً از DB حذف کرده (`GetAsync` → null) و با شناسه‌های یک‌بارمصرف + پاک‌سازی در finally انجام می‌شود.
- **Helper مشترک تست‌های DBدار (۱۴۰۵/۰۶/۰۹)**: `Tarazin.Tests/TestDb.cs` — `TestDb.ConnectionString` (قابل بازنویسی با env var «TARAZIN_TEST_CONN» برای CI)، `TestDb.OpenOrSkipAsync()` (بازکردن اتصال یا Skip وقتی SQL Server در دسترس نیست)، `TestDb.SplitBatches(sql)` (تقسیم بچ‌های `GO` چون SqlCommand/Dapper آن را نمی‌فهمد) و `TestDb.EnsurePrintingAsync(cn)` (اجرای idempotentِ `printing._Ensure`). هر سه فایل DBدار (`AccountingCloseYearTests`، `PrintTemplateResolutionTests`، `PrintTemplateSqlGuardTests`) از آن استفاده می‌کنند.
- **Skip پویای واقعی (۱۴۰۵/۰۶/۰۹)**: پکیج `xunit.skippablefact 1.4.13` اضافه شد — `SkipTestException` سفارشی (که فقط Fail می‌شد، نه Skip!) با `Xunit.SkipException` جایگزین شد و هر ۹ تست DBدار از `[Fact]` به `[SkippableFact]` تبدیل شدند. تأیید: بدون SQL Server نتیجه «Skipped! - Passed: 0, Skipped: 9» است نه «Failed».
- **تست گاردِ SQL خالص (۱۴۰۵/۰۶/۰۹)**: `Tarazin.Tests/PrintTemplateSqlGuardTests.cs` — بدون سرویس، مستقیم روی اسکریپت‌های واقعی: (۱) Upsert — دامنه‌گذاری CompanyId، آزادسازیِ پیش‌فرض قبلیِ همان شرکت، آزاد شدنِ سراسری با تنظیمِ پیش‌فرضِ شرکت (اما نه برعکس)، و DefaultFor خالی → CompanyId=NULL؛ (۲) SetDefaultFor — ایزولاسیون شرکت (تنظیمِ B پیش‌فرضِ A را نمی‌زند)، آزادسازیِ همان شرکت، و ClearDefaultFor → مشترک‌شدن دوباره؛ (۳) GetByDefaultFor — شرکت → سراسری → null؛ (۴) بازنشانی در سطح SQL — اجرای `PrintTemplateReset` (DELETE ردیفِ پیش‌فرضِ شرکت) → وضوح به سراسری می‌افتد، و DELETE سراسری → null؛ (۵) هم‌زمانیِ SetDefaultFor — بازسازیِ بازهٔ ازدست‌رفته (هر دو گامِ آزادسازی قبل از هر دو گامِ تنظیم) از گام‌های استخراج‌شدهٔ اسکریپتِ واقعی → فقط یک برنده و ایندکسِ یکتا بازنده را رد می‌کند (برای دامنهٔ شرکت و سراسری)؛ (۶) ایندکس‌های یکتا — درجِ تکراری (CompanyId, DefaultFor) با `UQ_PrintTemplates_DefaultFor_Company` و تکراریِ سراسری با `UQ_PrintTemplates_DefaultFor_Global` رد می‌شود، و شرکتِ متفاوت برای همان گزارش مجاز است. نکتهٔ پیاده‌سازی: جداسازی گام‌های اسکریپت با `IndexOf("UPDATE")` باید **case-sensitive** باشد چون «UPDATE» پیشوندِ «UPDATEDAT» است و جستجوی بدون حساسیت، داخلِ `[UpdatedAt]` را پیدا می‌کند و fragment را می‌شکند.
- **بازنشانی به قالب پیش‌فرض داخلی (۱۴۰۵/۰۶/۰۹)**: در ویرایشگر دیزاینر دکمهٔ «بازنشانی به قالب پیش‌فرض داخلی» (فقط وقتی قالبِ انتخاب‌شده ردیفِ ذخیره‌شده در دیتابیس دارد) با تأیید `MudDialog` اجرا می‌شود: `PrintTemplateReset.sql` ردیف را حذف می‌کند (با آن `DefaultFor` هم پاک می‌شود) تا وضوحِ قالب به تعریف داخلیِ کد برگردد. اگر شناسه قالبِ شناخته‌شده (مثل `treasury.cheques`) باشد همان گزارش دوباره با قالب داخلی انتخاب می‌شود؛ وگرنه ویرایشگر خالی می‌شود. تأیید لایو: قالب سفارشی ۲-ستونه با `DefaultFor=treasury.cheques` ذخیره شد → دکمهٔ بازنشانی ظاهر شد → بعد از تأیید ردیف از DB حذف شد (۰ ردیف) → فهرست فقط قالب‌های سیستمی ماند → گزارش چک‌ها دوباره قالب داخلی ۸-ستونه را نشان داد.
- **پیش‌فرض per-company (۱۴۰۵/۰۶/۰۸)**: ستون `CompanyId` به `printing.PrintTemplates` اضافه شد تا هر شرکت «پیش‌فرضِ چاپ» جداگانه داشته باشد — **کلید یکتای `(CompanyId, DefaultFor)`** با دو ایندکس فیلترشده: `UQ_PrintTemplates_DefaultFor_Company` (برای هر شرکت) و `UQ_PrintTemplates_DefaultFor_Global` (برای پیش‌فرضِ سراسری CompanyId NULL — قالب‌های قدیمی/مشترک). وضوح در `GetOrCreateDefaultAsync`/`GetByDefaultForAsync` برای نشستِ جاری: قالبِ همان شرکت → قالبِ سراسری → قالب داخلی؛ `SetDefaultForAsync`/`SaveAsync` همیشه دامنهٔ شرکتِ جاری (`_session.ActiveCompanyId`) را می‌نویسند و `ClearDefaultForAsync` قالب را دوباره مشترک می‌کند. دیزاینر: چیپ «پیش‌فرض» فقط وقتی برای شرکتِ جاری است طلایی است؛ پیش‌فرضِ شرکتِ دیگر با برچسب «(شرکت N)» نمایش داده می‌شود. تأیید: دو شرکت برای یک گزارشِ واحد پیش‌فرض‌های متفاوت ذخیره کردند (ایندکس یکتا هر دو را مجاز کرد)، وضوحِ هر شرکت قالبِ خودش را برگرداند، درجِ تکراری (همان شرکت+گزارش) با خطای ایندکس رد شد، و لایو — شرکت ۳ قالب ۲-ستونهٔ خودش را در گزارش چک‌ها نشان داد و بعد از پاکسازی به قالب داخلی ۸-ستونه برگشت.
- **اتصال مصرف‌کنندگان**: یک متد عمومی `PrintAsync<T>(id, title, meta, rows, totals, pageSize)` در `TemplatePrintDialog`. همهٔ ماژول‌ها به موتور وصل شدند (۱۴۰۵/۰۶/۰۹):
  - خزانه‌داری — `TreasuryChequeReport` (قالب `treasury.cheques`، ۸ ستون + جمع ۱٬۸۹۸٬۰۰۰٬۰۰۰)
  - حسابداری — `AccountingHome` (قالب `accounting.documents`، دکمهٔ «چاپ فهرست»)
  - فروشگاه — `StoreReports` (قالب `store.orders`) + **رفع باگ گزارش**: `OrderListReport.sql` دیگر به ازای هر آیتم ردیف برنمی‌گرداند — یک ردیف به ازای هر سفارش با `ItemCount` واقعی از جدول `Orders` (قبلاً سطرهای تکراری سفارشِ چندقلمی و «تعداد اقلام ۰» می‌داد)
  - حقوق — `PayrollReports` (قالب `payroll.runs`، ۵ ستون دوره/تعداد کارمند/خالص کل/وضعیت/تاریخ)
  - طلافروشی — `GoldShopReports` (قالب‌های `goldshop.sales` با ۱۰ ستون + `goldshop.prices`) + **رفع اسکیمای قدیمی**: ستون‌های `GoldItems.CompanyId`/`InventoryItemCode` توسط ALTER های `_Ensure` در ریاستارت بعدی اضافه شدند (کوئری `DailySales` با JOIN روی `g.CompanyId` خطا می‌داد و گزارش خالی می‌ماند)
  - BI — `BiReports` (دکمهٔ «چاپ موتور عمومی»؛ قالب پویا از `ColumnTitles` گزارش — برای «کیف پول و موجودی ارز» با ۷ ستون تأیید شد)
- **تست**: `Tarazin.Tests/PrintEngineTests.cs` (سابقاً `DebugTemplatePdf`) با `BuildTemplatePdf` MediaBox/ابعاد و ساخت PDF بدون خطا را نگهبان می‌کند؛ `dotnet test` باید سبز بماند.
- **تأیید زنده (۱۴۰۵/۰۶/۰۹)**: گزارش چک‌ها → ۸ ستون + PDF بدون کرش؛ فهرست اسناد → ۱۸ سند + PDF + «ویرایش قالب»؛ فروشگاه → ۴ سفارش یکتا (بدون تکرار) با `ItemCount` درست (۱/۱/۲/۱) + جمع ۲۵۳٬۰۰۰٬۰۰۰ در صفحه و چاپ و PDF؛ حقوق → دورهٔ ۱۴۰۵-۰۴ (۳ کارمند، ۲۸۱٬۴۰۰٬۰۰۰) در صفحه و چاپ و PDF؛ طلافروشی → فروش روز با ۱۶ فاکتور (۱۰ ستون) + قیمت طلا (۳ قلم) + PDF؛ BI → «کیف پول و موجودی ارز» با ۷ ستون و ۳ ارز (USD/EUR/AED) + PDF؛ انبار → موجودی کالا با ۵ قلم (۸ ستون) + PDF. همهٔ دیالوگ‌ها بعد از دانلود PDF زنده می‌مانند (بدون خطای circuit).

## 3. Tarazin.Ui
- **Purpose**: Blazor‑based UI library (RCL) shared by Web and MAUI hosts.

### UI/UX component catalog (updated ۱۴۰۵/۰۶/۰۹)
- **Mobile-first interaction layer**: the responsive drawer supports horizontal swipe gestures with a safe threshold; shared CSS handles touch scrolling, bounded horizontal data tables, compact dialogs/actions, readable long-text columns, and prevents page-level overflow on narrow screens. Browser/device smoke testing depends on an available interactive browser environment.
- **Compact visual scale**: responsive typography and compact MudBlazor controls are centralized in `app.css`; headings, buttons, inputs, table headers, stat cards, and module cards use a restrained scale while mobile actions remain usable. `.mud-nav-link` has an explicit Vazirmatn/400-weight/2px-padding/1.5-line-height override with subtle 250ms transitions.
- **Shared visual primitives** (`Tarazin.Ui/Components/`):
  - `PageHeader` — عنوان، زیرعنوان، eyebrow و محتوای عملیاتی سربرگ صفحات.
  - `PageToolbar` — نوار ابزار استاندارد افزودن/فیلتر/عملیات؛ از تکرار flex toolbar جلوگیری می‌کند.
  - `StatusChip` — نمایش یکدست وضعیت فعال/غیرفعال با آیکون و رنگ MudBlazor.
  - `EntityActions` — دکمه‌های استاندارد ویرایش/حذف با `MudTooltip` و callbackهای مستقل.
  - `EmptyState` — وضعیت خالی قابل استفادهٔ مجدد با آیکون، عنوان، توضیح و action اختیاری.
  - `FormSection` — قاب استاندارد فرم با عنوان، توضیح، آیکون، header slot و content slot.
  - `StatCard` — کارت آماری responsive با حالت loading و لینک اختیاری.
  - `ModuleCard` — کارت ورود به ماژول با پشتیبانی keyboard و navigation.
  - `ModuleSubNav` — زیرمنوی ماژول مبتنی بر `MudNavLink` و permission catalog.
  - `TableSkeleton` — اسکلتون ردیف/ستون برای جلوگیری از پرش layout.
  - **UI completion pass**: Central Users/News/Gallery/Blog and BI Branches/Assets now reuse `StatusChip`, `EntityActions`, and `EmptyState`; action cells have consistent accessible labels/tooltips and shared responsive surface spacing.
  - `AccountPickerField` / `AccountPickerDialog` — انتخاب حساب درختی و transaction-safe.
  - `PrintBrandHeader`, `ReportPrintDialog`, `TemplatePrintDialog` — پوسته‌های مشترک چاپ و PDF.
- **Shared dialog/form primitives**: `EntityEditorDialog`, `CompanyFormDialog`, `RoleEditorDialog`, `SelectorDialog` و فرم‌های Chart (`BaseColForm`, `BaseMoeinForm`, `BaseDetilForm`, `AccountGroupForm`).
- **Module component conventions**: دیالوگ‌های اختصاصی هر ماژول داخل `Modules/{Module}/Components/` قرار می‌گیرند و صفحات فقط orchestration، permission و data loading را انجام می‌دهند.
- **MudBlazor rules**: layoutهای معنایی چاپ/درخت با HTML/CSS سفارشی باقی می‌مانند؛ کنترل‌های تعاملی با MudBlazor هستند. از پارامترهای غیرمجاز مانند `CloseOnItemClick` روی `MudMenu`، `AlignItems` روی `MudGrid` و `ToolTip` روی کنترل‌ها استفاده نشود؛ برای tooltip همیشه `MudTooltip` و برای فرم `ValidateAsync()` استفاده شود.
- **Current reuse**: `PageToolbar` در تنظیمات Inventory/Payroll/Currency/Store و گزارش‌های منتخب، `StatusChip`/`EntityActions` در CRUDهای Central و BI و گزارش حقوق، و `EmptyState` در صفحات CRUD و گزارش‌های اصلی استفاده شده‌اند؛ focus keyboard و touch targetهای موبایل نیز در CSS مشترک استاندارد شده‌اند. قبل از ساخت component جدید این فهرست بررسی شود.
- **Motion/typography UX**: `app.css` دارای توکن‌های responsive با `clamp()` برای اندازهٔ متن، فاصله، line-height و مدت انیمیشن است. ورود صفحه و surfaceها، hover کارت‌ها، focus فیلدها، دکمه‌ها و ردیف‌های جدول با transition نرم و transform سه‌بعدی سبک اجرا می‌شوند. در `prefers-reduced-motion` انیمیشن‌های غیرضروری خاموش می‌شوند؛ breakpointهای 600/800/1400 برای موبایل، تبلت و نمایشگر بزرگ تعریف شده‌اند.
- **Coding rules**: development, MudBlazor 9.8.0 conventions, permissions, and copy‑paste UI patterns are documented in `.claude/skills/tarazin-development/SKILL.md` — read it before touching UI code.
- **Windows visual QA**: `.claude/skills/windows-computer-control/SKILL.md` defines the `screen_windows` MCP workflow for screenshot/UI-tree/OCR inspection, UI Automation-first interaction, safe fresh-coordinate rules, responsive viewport and drawer-drag checks, post-action verification, and high-risk action restrictions. `tools/windows_mcp_client.py` is the dependency-free direct HTTP client for fast inspection without Hermes process startup overhead.
- **Important subfolders**:
  - `App.razor` – root component; sets up `MudThemeProvider`, global route table, and service collection.
  - `Layout/`  
    - `MainLayout.razor` – master page with sidebar navigation placeholder.  
    - `NavMenu.razor` – collapsible menu that auto‑generates links from registered modules.
  - `Modules/` – one folder per functional module; each contains:
    - `Pages/` – Razor pages for that module (e.g., `Accounting/Pages/Invoices.razor`).
    - `Components/` – shared Blazor components (tables, dialogs, charts).
    - `Services/` – module‑specific services (e.g., `IInvoiceService`).
- **Service layer**:
  - `UserSession.cs` – holds the current user context, permission checks (`CanView`, `CanEdit`).
  - `AuthService.cs` – PBKDF2 password verification, token issuance.
  - `ServiceCollectionExtensions.cs` – extension methods to register all UI services (DI container).
- **UI primitives**:
  - Reuse of MudBlazor components (cards, tables, dialogs).
  - Custom components for dashboards and data‑grids.
- **Styling**:
  - `wwwroot/css/app.css` – global stylesheet, theme variables, responsive utilities.

## 4. Tarazin.Web
- **Purpose**: Blazor Server host that runs the UI library.
- **Core files**:
  - `Program.cs` – boots Blazor Server, adds MVC, configures authentication, injects UI services from `Tarazin.Ui`.
  - `_Host.cshtml` – Razor page that renders the Blazor root component.
  - `appsettings.json` – holds non‑secret configuration (e.g., feature flags). Sensitive values (SQL connection string) are injected via environment variables or secret store at runtime.
- **Dependency injection**: Calls `AddTarazinUiServices()` (defined in UI project) to register all UI services, ensuring a single source of truth for service registration.

## 5. Tarazin.Maui
- **Purpose**: MAUI host that embeds the Blazor UI as a hybrid mobile/desktop application.
- **Core files**:
  - `MauiProgram.cs` – configures MAUI services, adds BlazorWebView, registers UI services, and sets up platform‑specific configuration.
  - `MainPage.xaml` – defines a single screen that hosts the `BlazorWebView` pointing to `App.razor`.
  - `Resources/`, `Platforms/` – platform‑specific assets (icons, native projects).
  - `appsettings.json` – contains only `ServerEndpoint` (HTTPS base URL) used for bootstrap; all other config is supplied via environment variables.
- **Build variations**:
  - **Windows**: `dotnet publish ... -f net8.0-windows10.0.19041.0 -p:RuntimeIdentifier=win10-x64`
  - **Android**: similar command with keystore parameters for signing.
  - **iOS**: analogous command for Apple platforms.

## 6. Cross‑Project Dependency Flow
```
Tarazin.Share → Tarazin.Data → Tarazin.Ui → (Tarazin.Web, Tarazin.Maui)
```
- **One‑way dependency rule**: no project may reference a higher‑level project directly.
- Enforced by compile‑time warnings; static analysis (`cross-schema-scan.sh`) also prevents accidental script cross‑access.
- Guarantees clear module boundaries and simplifies testing.

## 7. Configuration & Secrets
- `settings.json` (runtime‑generated) controls:
  - `allowNpm`: enables/disables npm command execution in CI.
  - `env:DEBUG`: toggles verbose logging for local debugging.
  - `permissions:move`: moves permission definitions from admin to user‑scoped storage.
  - `rates:maxCallsPerMinute`: enforces external API rate limiting.
- **SQL connection string**: never stored in source; fetched from environment variable `TARAZIN_SQL_CONNECTION` or a secret manager at runtime.
- **Password handling**: PBKDF2 hashing performed by `AuthService`; hashes stored in `Users` table; no plain‑text passwords anywhere.

## 8. Deployment & Build Summary
| Target | Command (run from repo root) |
|--------|------------------------------|
| **Web (Release)** | `dotnet publish Tarazin.Web/Tarazin.Web.csproj -c Release -o ./publish` |
| **MAUI Windows** | `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-windows10.0.19041.0 -p:RuntimeIdentifier=win10-x64` |
| **MAUI Android** | `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-android -p:AndroidKeyStore=... -p:AndroidSigningKeyAlias=... -p:AndroidSigningKeyPass=... -p:AndroidSigningStorePass=...` |
| **MAUI iOS** | `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-ios` |

- Deploy **Web** output to IIS or any HTTP‑capable server.  
- Deploy **MAUI** binaries directly to the target device; sign Android/iOS builds with the provided keystore.

> **⚠️ Golden build rule:** after **any change in `Tarazin.Ui`** (any `.razor` page/component, service, or the shared `PdfReportService`), always run `dotnet build Tarazin.Web/Tarazin.Web.csproj`. `dotnet test` or a solo `Tarazin.Ui` build only refreshes `Tarazin.Ui/bin` — it does **not** refresh the `Tarazin.Web/bin` copy, and a dev server started with `--no-build` will keep serving the stale code (the recurring “columns RTL but header not” bug). Confirmed by `tools/check-stale-build.sh` before any dev-server restart. The one-shot gate `bash tools/run-checks.sh` runs this whole chain in sequence: cross-schema scan → **گاردهای قالب چاپ (فیلتر `PrintTemplate`)** → کل سویت تست → بیلد وب → گارد stale.

> **🤖 CI (GitHub Actions — `.github/workflows/ci.yml`)**: یک job واحد به نام `checks` که کل گیت را در خود دارد — (۱) گام اصلی همان `bash tools/run-checks.sh` را اجرا می‌کند؛ (۲) با سرویس `mcr.microsoft.com/mssql/server:2022-latest` و env `TARAZIN_TEST_CONN`، تست‌های DBدار همین‌جا واقعاً اجرا می‌شوند (و اگر SQL در دسترس نباشد Skip می‌شوند نه Fail)؛ (۳) دو step شرطی (`if: steps.wait-sql.outputs.ready == 'true'`) — اسکیمای واقعی از روی `Tarazin.Data/Scripts/*/_Ensure.sql` (با `docker cp` + `sqlcmd -i`، idempotent، پرچم `-I`) ساخته می‌شود و گاردهای DBدار (`FullyQualifiedName~PrintTemplate|AccountingCloseYearTests`) مقابل همان اسکیمای تازه دوباره اجرا می‌شوند. وقتی SQL بالا نیاید این دو گام Skip می‌شوند و گیت همچنان سبز است (مثل رفتار محلی). راه‌اندازی محلی معادل: `bash tools/run-checks.sh` + اسکریپت‌های `_Ensure` روی یک SQL Server زنده. ⚠ تجربهٔ واقعی: اولین run CI در گام init شکست خورد چون (۱) `sqlcmd` پیش‌فرض QUOTED_IDENTIFIER OFF دارد و ایندکس‌های فیلترشده ساخته نمی‌شوند — پرچم `-I` لازم است؛ (۲) `accounting/_Ensure` و `currency/_Ensure` در حالت دیتابیسِ کاملاً تازه، قبل از ADD ستون از ستون استفاده می‌کردند و ارجاع literal به `goldshop.GoldShopSettings` در بچ‌کامپایل خطا می‌داد — همگی در commit `c30d98d` رفع شدند (جابه‌جایی بلاک‌ها + dynamic SQL) و run بعدی (#33264144264) با هر دو job سبز شد.

## 9. Testing & Validation Process
1. **Schema validation** – Execute `tools/cross-schema-scan.sh`; CI fails if exit code ≠ 0.  
2. **Unit testing** – Place xUnit test projects under each main project’s `Tests/` folder; run `dotnet test`. `Tarazin.Tests` (xUnit, references `Tarazin.Ui`) guards the shared PDF engine (`PdfReportService`) with regression checks on page size/orientation (`MediaBox`: invoice portrait, cheque report landscape for A4/A5), pagination of long invoices, and RTL right-alignment of cells — `dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo` must stay green on every build (fails if the portrait/landscape or right-alignment bug returns).  
3. **Smoke testing** – The mandatory post-change order is: (1) `dotnet test Tarazin.Tests` → (2) `dotnet build Tarazin.Web` → (3) `tools/check-stale-build.sh` (must be exit 0) → (4) restart the dev server. Run `tools/check-stale-build.sh` **before restarting the dev server** — it verifies the `Tarazin.Ui.dll` copy in `Tarazin.Web/bin` is not older than `Tarazin.Ui/bin` (and that `Tarazin.Ui` itself is not older than its sources), preventing the recurring “server serves old code” bug when the server is started with `--no-build`. Then run the Web app (`dotnet run --project Tarazin.Web`) and manually navigate each module page to verify data loading and permission checks.  
4. **MAUI verification** – Launch the published executable; confirm login flow, navigation, and that UI renders correctly on each target platform.  
5. **Audit‑log check** – Insert a test operation and verify an entry appears in the `AuditLog` table with correct user & script metadata.

## 10. Documentation References
- `docs/PROJECT.md` – overall project overview.  
- `docs/adr/` – Architecture Decision Records (e.g., ADR‑001 “One‑Way Dependency”, ADR‑004 “AuditLog NULL CompanyId = system‑level, never backfill”).
- `docs/CURRENCY_MODULE.md` – details on price‑feed integration and rate handling.  
- `docs/BI_MODULE.md` – BI/reporting module internals (Stimulsoft render engine, license, fonts).
- `.claude/skills/tarazin-development/SKILL.md` – **mandatory coding guide** (architecture, Data layer, MudBlazor 9.8.0 pitfalls, RBAC, copy‑paste patterns for tables/forms/menus/dialogs). Read before any change.
- `skills/twg‑engineering‑work/SKILL.md` – CLI tooling for deeper code‑base exploration.

---  

## 11. Live Verification — ۱۴۰۵/۰۶/۰۲

آخرین بررسی زنده روی Web با SQL Server واقعی و حساب `admin` در شرکت «تست» و سال مالی `1405` انجام شد. نتیجهٔ عملیات واقعی:

| حوزه | مسیر/عملیات | نتیجه |
|---|---|---|
| حسابداری | اسناد روز، ثبت سند، گزارش‌ها، **چاپ سند (ساده/پیشرفته + دانلود PDF) و پیمایش قبل/بعد سند** | سالم؛ چاپ پیشرفته تودرتوی کل→معین→تفصیل + PDF روی سند ۸۸ لایو تأیید شد |
| موتور چاپ عمومی | **مدیریت قالب‌های چاپ (`/central/printing`) + دیالوگ چاپ عمومی در همهٔ گزارشات (چک‌ها، فهرست اسناد، انبار، حقوق، طلا، فروشگاه، BI)** | سالم؛ قالب‌ها (سیستمی+ذخیره‌شده) با پیش‌نمایش زنده، چاپ HTML و دانلود PDF از همان قالب، «ویرایش قالب» با `?tpl=` — همهٔ ۷ ماژول لایو تأیید شد |
| انبار | ثبت حرکت، کالا، ویرایش/حذف نرم | سالم؛ رکورد شرکت صحیح و حذف با `IsDeleted` تأیید شد |
| خزانه | ثبت گردش نقدی، تنظیمات بانک/صندوق | سالم؛ ثبت با `CompanyId` صحیح تأیید شد |
| حقوق | فهرست/CRUD کارمند، دوره و نهایی‌سازی | صفحات و CRUD سالم؛ نهایی‌سازی به‌صورت مخرب اجرا نشد |
| طلافروشی | فهرست اجناس، CRUD کامل مشتری (ایجاد/ویرایش/حذف)، فرم فاکتور، صفحهٔ اتصال | سالم؛ CRUD مشتری لایو تأیید شد (حذف = soft-delete + پاک‌سازی لینک)، فاکتور فروش → سند حسابداری متوازن + دفتر مشتری + حرکت انبار، تنظیمات اتصال از درخت حساب‌ها ذخیره شد |
| فروشگاه | تنظیمات، دسته‌ها و CRUD مشتری + **یکپارچه‌سازی کامل (۱۴۰۵/۰۶/۰۶)** | سالم؛ ساخت مشتری و تب‌های تنظیمات تأیید شد؛ سفارش → سند حسابداری (یاداشت) + دفتر مشتری + خزانه (نقد/بانک/چک) + حوالهٔ انبار به‌صورت لایو تأیید شد (ORD-00004: سند ۸۹ متوازن، چک CHQ-UI-0002، حوالهٔ SIKKEH) |
| ارز | کیف پول، تبدیل، ثبت حرکت دستی | صفحات سالم؛ خطای واقعی `THROW` با الحاق رشته و نقص tenant در مسیرهای نوشتن اصلاح شد |
| BI | `/bi`، همهٔ تب‌ها، `/bi/reports` و Viewer | سالم؛ Viewer رندر شد، هشدار trial Stimulsoft مورد انتظار است |
| Central | `/central/audit`، فیلتر سیستمی و صفحه‌بندی | سالم؛ ردیف‌های `CompanyId = NULL` جدا و صفحه‌بندی ۵۰تایی تأیید شد |

### چندشرکتی‌سازی سراسری (۱۴۰۵/۰۶/۰۲)
- قبلاً seedهای central/accounting/inventory/treasury فقط **اولین شرکت** را پر می‌کردند و شرکت‌های بعدی ترازنامه/گروه/انبار/بانک نداشتند؛ اکنون همه با cursor روی هر شرکت فعال seed می‌شوند.
- یکتایی‌های سراسری جدول‌های حسابداری/انبار/خزانه به ایندکس‌های درون‌شرکتی تبدیل شدند تا seed چندشرکتی بدون خطا اجرا شود (مهاجرت‌ها در `_Ensure` مربوطه با `DROP ... UQ` + ساخت `UX_*` است).
- روی دیتابیس زنده اجرا و تأیید شد: شرکت ۳ (تست) اکنون ۱۱ حساب، ۴ کل، ۵ معین، ۵ تفصیلی، ۲ گروه (مشتریان/تأمین‌کنندگان)، ۴ قانون مالیات، ۲ انبار، ۵ کالای طلا، بانک/صندوق/نرخ ارز و ۳ طرف‌حساب لینک‌شده به تفصیلی‌های حسابداری دارد.

### کنترل چندشرکتی ارز
- در دیتابیس `TarazinMaster` برای شرکت‌های ۱ و ۳ کیف‌پول‌های `USD/EUR/AED` و دارایی‌های `XAU-18/SIKKEH-EMAMI` مستقل وجود دارد.
- یکتایی قدیمی سراسری با ایندکس‌های `UX_Wallets_Company_Currency` و `UX_AssetHoldings_Company_Item` جایگزین شده است.
- تمام مسیرهای `WalletMovementManual`، `FxTransactionCreate`، `FxCombinedCreate` و `ConvertExecute` در خواندن/نوشتن موجودی به `central.fn_MobileCompanyId()` محدود هستند.
- هیچ رکورد موقت تست ارزی یا خزانه‌ای در دیتابیس باقی نمانده است.

### وضعیت محیط
- startup زنجیرهٔ `Ensure → Seed → Backfill → MobileSecurity` بدون خطای SQL بالا آمد.
- فید `TABLOTALA_FR` در محیط محلی timeout می‌شود؛ scheduler آن را به‌عنوان خطای منبع ثبت می‌کند و startup/سایر فیدها ادامه می‌یابند.
- بیلد Web و Data با ۰ هشدار و ۰ خطا پاس شد. بیلد MAUI Android با ۰ هشدار و ۰ خطا پاس شد. بیلد MAUI Windows با ۰ خطا پاس شد؛ دو هشدار `MSB3277` ناشی از conflict وابستگی `Microsoft.AspNetCore.WebUtilities` در Stimulsoft 2024.3.2 باقی است و باید با ارتقای سازگار Stimulsoft یا تثبیت binding در CI بررسی شود. هشدار `TZN0001` مربوط به layout فیزیکی Build بود و assetها در `filtered.layout.resfiles` ثبت شده‌اند؛ publish/pack و تست دستگاهی Windows/Android هنوز باید در device lab تکرار شود.

*This modular breakdown is saved as **Handoff_ModuleBreakdown.md** for quick reference and to avoid repeated deep‑dive reviews.*