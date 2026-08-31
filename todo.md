# TODO — ترازین (مدیریت هوشمند کسب‌وکار) — Blazor Hybrid

> 🧑‍💻 **راهنمای کدنویسی الزامی:** قبل از هر تغییر/دریافت پارامتر، `.claude/skills/tarazin-development/SKILL.md` را کامل بخوان — معماری، لایهٔ داده، قواعد MudBlazor 9.8.0، دسترسی‌ها و الگوهای کپی‌پذیر (جدول/فرم/منو/دیالوگ) همه در آن است.
>
> **وضعیت کلی (۱۴۰۵/۰۶/۰۲):** Web با SQL Server واقعی لایو بررسی شد؛ مسیرهای CRUD ماژول‌های حسابداری، انبار، خزانه، حقوق، طلافروشی، فروشگاه و ارز، داشبورد BI، Viewer گزارش و ممیزی Central سالم هستند. اصلاح tenant ارز، seed چندشرکتی کیف‌پول/دارایی، و زنجیرهٔ `Ensure → Seed → Backfill → MobileSecurity` در startup تأیید شد. اتصال MAUI همچنان نیازمند build و تست دستگاهی در محیط دارای workload است؛ هیچ چیزی Deploy نشده است.

| فاز | وضعیت (0 تا 4) | شرح کار | مسئول |
|-----|-----------------|---------|--------|
| 0 | 3 | حذف پروژه‌های قدیمی (webapi، WASMها، share، blazordeployservice، tests) و ساخت پنج‌تایی `Share / Data / Ui / Web / Maui` | @arch |
| 0 | 3 | **`Tarazin.Share`** (مدل‌ها/قراردادها) + **`Tarazin.Data`** (لایهٔ داده) به‌عنوان پروژه‌های مستقل با وابستگی یک‌طرفه | @arch |
| 0 | 3 | هستهٔ UI مشترک (`Tarazin.Ui`): MudBlazor + چیدمان (MudLayout/MudDrawer/NavMenu) + شعار «مدیریت هوشمند کسب‌وکار» | @front |
| 0 | 3 | لایهٔ داده (در `Tarazin.Data`): ScriptCatalog (Embedded) + DbService (Dapper + اسکریپت نامدار) + ممیزی خودکار + ICurrentUser | @backend |
| 0 | 3 | هاست وب (`Tarazin.Web`): Blazor Server + `AddTarazinUiServices` + init | @backend |
| 0 | 3 | **هاست MAUI (`Tarazin.Maui`)**: BlazorWebView → `Tarazin.App` + Platforms/Resources کامل | @maui |
| 0 | 3 | ماژول پلتفرم مشترک: ورود، کاربران، اخبار/بلاگ/گالری، ممیزی | @backend |
| 1 | 3 | ماژول حسابداری: اسناد روز، ثبت سند، دفتر روزنامه/کل، تراز، بستن دوره، حساب‌ها | @dev_a |
| 2 | 3 | ماژول انبار آمل: رسید/حواله، کارتکس، موجودی، انبارگردانی، کالاها | @dev_b |
| 3 | 3 | ماژول خزانه‌داری: دریافت/پرداخت، گردش نقدی، نرخ ارز، بستن روز | @dev_c |
| 4 | 3 | ماژول حقوق و دستمزد: کارمندان، فیش، نهایی‌کردن دوره، گزارشات | @dev_d |
| 5 | 3 | ماژول طلافروشی: فاکتور فروش، قیمت طلا، اجناس، گزارشات | @dev_e |
| 6 | 3 | ماژول فروشگاه: سبد خرید، سفارش، محصولات، مشتریان + **یکپارچه‌سازی (۱۴۰۵/۰۶/۰۶)**: سفارش → سند حسابداری یاداشت + دفتر مشتری (OrderLedger) + خزانه (نقد/بانک/چک) + حوالهٔ انبار؛ تب اتصال حسابداری در تنظیمات؛ مشتریان لینک‌شده به central.Parties با تفصیلی خودکار | @dev_f |
| 7 | 3 | بازبینی ایستا + تست لایو Web با SQL Server واقعی انجام شد؛ تست دستگاهی MAUI و E2E موبایل هنوز مانده | @qa_lead |
| 8 | 1 | `ci/ci.yml` (build وب + build MAUI با workload) نوشته شده؛ **فعال‌سازی: انتقال به `.github/workflows/ci.yml` و پوش با اکانت دارای دسترسی workflows و سبز شدن مانده** | @devops |
| 9 | 3 | مستندسازی نهایی (PRD، PLATFORM_PRD، PROJECT، ADRها، skills، .agents) **کامل**؛ انتقال به تولید مانده | @arch |
| 11 | 2 | **یکپارچه‌سازی طلافروشی + ارز + انبار + حسابداری + خزانه**: مشتری/تأمین‌کننده، دفتر بدهکار/بستانکار ریالی/طلا/ارز، فاکتور مالیاتی و اجرت، پرداخت خزانه، کاهش موجودی و تنظیمات لینک حسابداری؛ مسیرهای `/goldshop/parties` و `/goldshop/settings/integration` اضافه شد. picker تفصیلی گرافیکی و برگشت فاکتور هنوز مانده | @dev_e |
| 10 | 3 | **ماژول ارز و معاملات ارزی (PRD §34–§63)**: اسکیمهٔ `currency` + مرکز نرخ‌ها، کیف پول، خرید/فروش ارز، معاملات ترکیبی، موتور تبدیل، دریافت آنلاین (TabloTala/Matisa)، ارزش لحظه‌ای دارایی، سود/زیان ارزی، دسترسی‌های `rates.*`؛ ایزولاسیون چندشرکتی و seed مستقل برای شرکت‌ها نیز تأیید شد — شرح کامل در `docs/CURRENCY_MODULE.md` | @dev_c |
| 11 | 3 | **ماژول داشبورد و BI (PRD BI §1–§121)**: اسکیمهٔ `bi` (۲۸ اسکریپت) + مرکز فرماندهی `/bi` با ۱۴ تب (اجرایی/مالی/فروش/خزانه/طلا/ارز/انبار/مشتریان/بدهی‌ها/حقوق/فروشگاه/اهداف/هشدار/تحلیل هوشمند) + `BiAlerts` + **چاپ گزارش با موتور عمومی (QuestPDF)** (`/bi/reports` + `TemplatePrintDialog`) — شرح کامل در `docs/BI_MODULE.md` | @dev_a |

## کارهای باز (Backlog)

| # | کار | پیش‌نیاز |
|---|-----|----------|
| B1 | `dotnet build Tarazin.Web/Tarazin.Web.csproj` — تأیید build پنج‌پروژه (MudBlazor 9.8.0 روی net8.0) | محیط با SDK |
| B2 | `dotnet workload install maui` + build MAUI (ویندوز) | build `net8.0-windows10.0.19041.0/win10-x64` موفق با ۰ خطا؛ publish/device test مانده |
| B3 | `docker compose up -d` با secretهای خارجی + تست E2E وب/MAUI با bootstrap password تزریق‌شده، ورود MAUI (رمز درست/غلط، API/SQL unavailable)، ثبت داده، گزارش و ممیزی. عیب‌یابی: `bash tools/test-connection.sh` و `/diag` امن | SQL Server + SDK |
| B4 | تأیید build/runtime مسیر مستقیم SqlClient و endpoint ورود برای Android/iOS؛ بدون credential دائمی یا TLS bypassدر بسته | build Android موفق؛ runtime دستگاهی Android/iOS و بررسی endpoint در CI/device lab مانده |
| B5 | انتقال `.github/workflows/ci.yml` به `.github/workflows/ci.yml` و سبز شدن | دسترسی workflows |
| B6 | پیکربندی secret store تولید برای اتصال Web و bootstrap password؛ repository و artifact باید بدون مقدار secret باقی بمانند | تولید |
| B7 | پاک‌سازی جدول‌های Outbox خواب (ADR-002) | اختیاری |

## فاز ۱۰ — دسترسی (RBAC) + سرویس کاربر + CreatedAt/UpdatedAt (۱۴۰۵/۰۵/۲۲)

> افزوده‌شده روی معماری موجود (بدون پروژهٔ جدید). شرح کامل در `docs/GAP_ANALYSIS_ERP.md`.

| کار | وضعیت | شرح |
|-----|:---:|-----|
| RBAC — کاتالوگ دسترسی (`Tarazin.Share/Permissions.cs`): ۴۶ دسترسی `{module}.{action}` + ۸ نقش پیش‌فرض | 3 | منبع واحد برای seed و UI |
| جداول `[central].[Permissions/Roles/RolePermissions]` + `Users.RoleId` + اسکریپت‌های Sync/Backfill | 3 | Migration idempotent در `_Ensure.sql`؛ همگام‌سازی در `TarazinDbInitializer` |
| `UserSession` با `HasPermission/CanView/HasAny` + بارگذاری دسترسی‌ها هنگام ورود | 3 | `Login.razor` |
| اعمال دسترسی در UI: فیلتر NavMenu/Home/ModuleSubNav + گارد مرکزی مسیر در `MainLayout` | 3 | نمایش «دسترسی ندارید» |
| `UserService` (`Tarazin.Ui/Services/UserService.cs`) برای ایجاد/ویرایش/حذف کاربر + نقش‌ها | 3 | هش PBKDF2 داخل سرویس |
| صفحهٔ «نقش‌ها و دسترسی‌ها» (`/central/roles`) + `RoleEditorDialog` | 3 | چک‌باکس گروه‌بندی‌شده |
| CreatedAt/UpdatedAt/CreatedBy/UpdatedBy در همهٔ جداول موجودیت + مدل‌ها + اسکریپت‌ها | 3 | Migration + Upsert + List/Search |

## کارهای باز — ویژگی‌های ERP (از لیست ۳۳ بخشی)

| # | کار | وضعیت فعلی |
|---|-----|:---:|
| B8 | ماژول خرید (درخواست→سفارش→فاکتور→برگشت) + تسویه | ❌ |
| B9 | اموال و دارایی ثابت (استهلاک، انتقال، اسقاط) | 🟡 | اسکیمهٔ `assets` + CRUD + استهلاک خط مستقیم + BI ساخته شد؛ انتقال/اسقاط کامل و نمودارهای بیشتر مانده |
| B10 | تکمیل طلا: آب‌شده/انگ/سکه، تبدیل عیار، تهاتر، تسویهٔ طلایی، نرخ خرید/فروش | 🟡 | تهاتر/آب‌شده/سکه/نرخ خرید-فروش در ماژول ارز انجام شد — ماژول طلا جداگانه می‌ماند |
| B11 | POS/صندوق فروش (شیفت، شمارش، مغایرت) | ❌ |
| B12 | اقساط و بدهی‌ها (برنامه پرداخت، دیرکرد) | ❌ |
| B13 | صورتحساب الکترونیکی مالیاتی (وضعیت ارسال/خطا) | 🟡 |
| B14 | شعب/چندشرکتی + گزارش مقایسه | 🟡 | ماژول `branch` (CRUD + BranchId روی فاکتورها) + BI ساخته شد؛ انتخاب شعبه در فرم‌های فاکتور و چندشرکتی کامل مانده |
| B15 | جستجوی سراسری + داشبورد مدیریتی جامع + BI | ❌ |
| B16 | اعلان‌ها/هشدارها + چاپ و خروجی Excel/PDF | 🟡 | هشدارها و چاپ گزارش در ماژول BI انجام شد (موتور عمومی QuestPDF)؛ اعلان‌های Push/Email و خروجی‌های بیشتر مانده |

## Status Legend
- 0 = برنامه‌ریزی نشده
- 1 = در حال پیاده‌سازی
- 2 = دارای مشکل / در حال رفع
- 3 = تکمیل شده
- 4 = کامل شده و Deploy شده
