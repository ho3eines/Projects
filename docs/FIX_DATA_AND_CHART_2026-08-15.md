# رفع اشکال — لایهٔ داده (Tarazin.Data) و درخت جداول پایه (حسابداری)

**تاریخ:** ۱۴۰۵/۰۵/۲۴ (2026-08-15)
**دامنه:** ساخته‌نشدن جداول، کار نکردن seed، و «اضافه نشدن گره» در جداول پایه.

> خلاصه: منطق کلی درست بود — همان‌طور که حدس زده شده بود. مشکل چند باگ ریز
> ولی **کشنده** بود که همگی «بی‌صدا» شکست می‌خوردند: یا خطا داخل `try/catch`
> بلعیده می‌شد، یا SQL بدون خطا صفر ردیف برمی‌گرداند. برای همین ظاهر UI درست
> بود ولی عمل نمی‌کرد.

---

## ۱. چرا «افزودن گره» کار نمی‌کرد؟ (باگ اصلی)

`accounting/BaseDetilLinkUpsert.sql` — اسکریپتی که تفصیلی را به معین وصل می‌کند:

```sql
DECLARE @ExistingId INT = 0;      -- ❌ مقدار اولیه صفر

SELECT @ExistingId = LinkId
FROM [accounting].[BaseDetilLink]
WHERE DetilId = @DetilId AND MoeinId = @MoeinId AND IsDeleted = 0;

IF @ExistingId IS NOT NULL        -- ❌ همیشه TRUE است! (0 ≠ NULL)
BEGIN
    UPDATE ... WHERE LinkId = @ExistingId;   -- روی LinkId = 0 → صفر ردیف
    RETURN;                                   -- ❌ خروج
END

INSERT INTO [accounting].[BaseDetilLink] ...  -- ❌ هرگز اجرا نمی‌شد
```

نکتهٔ کلیدی: وقتی `SELECT @x = col` هیچ ردیفی پیدا نکند، **مقدار متغیر را دست
نمی‌زند** — یعنی `@ExistingId` روی `0` می‌ماند، نه `NULL`. پس شرط
`IS NOT NULL` همیشه برقرار بود، `UPDATE` روی `LinkId = 0` هیچ ردیفی را عوض
نمی‌کرد، `RETURN` اجرا می‌شد و `INSERT` انتهای فایل **کد مرده** بود.

نتیجه: `ExecuteAsync` بدون خطا برمی‌گشت، Snackbar سبز «ثبت شد» نشان می‌داد،
ولی هیچ گره‌ای ساخته نمی‌شد.

**رفع:** مقداردهی اولیه به `NULL` + انتخاب `TOP (1) … ORDER BY LinkId`.

---

## ۲. جداول ساخته نمی‌شدند (`EnsureSchema` شکست می‌خورد)

`central/_Ensure.sql` هیچ `GO` نداشت، پس **کل فایل یک batch** بود:

```sql
ALTER TABLE [central].[Users] ADD RoleId INT NULL;   -- ستون در همین batch
...
ALTER TABLE [central].[Users]
    ADD CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) ...;  -- ❌
```

SQL Server کل batch را **قبل از اجرا** کامپایل می‌کند؛ ستونی که در همان batch
اضافه می‌شود هنوز وجود ندارد → `Msg 1911: Column name 'RoleId' does not exist`.
چون `EnsureSchemaAsync` تک‌تک اسکیمه‌ها را اجرا می‌کند، این خطا کل راه‌اندازی
دیتابیس را می‌شکست.

**رفع:** افزودن مرز `GO` + پاک‌سازی `RoleId`های یتیم قبل از افزودن FK
(وگرنه `Msg 547`).

---

## ۳. `seed` کار نمی‌کرد (ردیف‌های سند خالی می‌ماندند)

در `accounting/_Seed.sql` ترتیب اشتباه بود:

1. `Documents` درج می‌شد،
2. `DocumentLines` با `CROSS JOIN [accounting].[ChartOfAccounts]` ساخته می‌شد،
3. و **تازه بعد از آن** `ChartOfAccounts` seed می‌شد.

چون در گام ۲ جدول حساب‌ها هنوز خالی بود، `CROSS JOIN` صفر ردیف می‌داد. سند
نمونه بدون هیچ ردیفی ثبت می‌شد و دفتر روزنامه/کل و تراز آزمایشی خالی بودند.

**رفع:** انتقال بلوک `ChartOfAccounts` به ابتدای فایل.

---

## ۴. تداخل نام پارامتر با `DECLARE` (خطای قطعی SQL)

اگر پارامتری که از C# فرستاده می‌شود هم‌نامِ متغیری باشد که داخل اسکریپت
`DECLARE` شده، SQL Server خطای
`Msg 134: The variable name '@X' has already been declared` می‌دهد و **کل
عملیات شکست می‌خورد**. چهار مورد پیدا شد:

| صفحه | اسکریپت | پارامتر متداخل |
|---|---|---|
| `InventoryEntry.razor` | `inventory/MovementInsert` | `@ItemCode` |
| `StoreEntry.razor` | `store/OrderPlace` | `@CustomerName` |
| `TreasurySpecial.razor` | `treasury/DayClose` | `@Today` |
| `CurrencyEditDialog.razor` | `currency/CurrencyUpsert` | `@IsBase` |

**رفع:** حذف پارامتر اضافی از فراخوان‌ها؛ و در `CurrencyUpsert` تغییر نام
متغیر داخلی به `@BaseFlag` (که ضمناً باعث می‌شد مقدار ارسالی کاربر هم واقعاً
اعمال شود — قبلاً متغیر مقدار خودش را می‌خواند و ورودی نادیده گرفته می‌شد).

---

## ۵. پارامترهای جاافتاده (`Must declare the scalar variable`)

| فراخوان | اسکریپت | پارامترهای غایب |
|---|---|---|
| `AccountingChart` و `AccountPickerDialog` | `ChartNodeBreadcrumb` | `@ColId, @MoeinId, @DetilId` |
| `WalletMovementDialog` | `WalletMovementManual` | `@PartyName, @FundType, @FundId` |

`ChartNodeBreadcrumb` بازنویسی شد تا دقیقاً همان قراردادی را بپذیرد که UI
می‌فرستد (`@NodeId`, `@NodeType`, `@LinkId`) و مسیر را خودش استخراج کند.
چون فراخوانی داخل `catch {}` بی‌صدا بود، Breadcrumb همیشه خالی می‌ماند.

---

## ۶. ایندکس‌هایی که ممکن بود وجود نداشته باشند

هفت اسکریپت با `WITH (INDEX(...))` به ایندکس‌هایی hint می‌دادند که فقط **داخل
بلوک `CREATE TABLE`** ساخته می‌شدند. روی دیتابیسی که جدولش از قبل وجود داشت،
آن ایندکس‌ها هرگز ساخته نمی‌شدند و کوئری با
`Msg 308: index does not exist` شکست می‌خورد — یعنی حذف/انتقال/جستجو کار
نمی‌کرد.

**رفع:** (الف) بلوک migration idempotent در `accounting/_Ensure.sql` که همهٔ
این ایندکس‌ها را تضمین می‌کند، و (ب) حذف خودِ hintها — بهینه‌ساز SQL Server
با وجود ایندکس درست، خودش مسیر بهینه را انتخاب می‌کند و hint فقط شکنندگی
می‌آورد.

---

## ۷. باگ‌های سمت UI در درخت جداول پایه

| مشکل | توضیح |
|---|---|
| **گره جدید دیده نمی‌شد** | بعد از ساخت فرزند، والد باز نمی‌شد؛ کاربر فکر می‌کرد ثبت نشده. حالا والد خودکار expand می‌شود. |
| **تداخل شناسه‌ها** | `_expanded` فقط با `NodeId` کلید می‌خورد، ولی `ColId=1` و `MoeinId=1` هر دو وجود دارند → باز کردن یک گره، گره‌های بی‌ربط را هم باز می‌کرد. کلید به `(NodeType, NodeId)` تغییر کرد. |
| **فیلتر «نوع» بی‌اثر** | به `_typeFilter` بایند شده بود ولی در `ApplyFilter` اصلاً استفاده نمی‌شد. |
| **دکمهٔ ذخیرهٔ تفصیلی بی‌اثر** | در حالت «استفاده از تفصیلی موجود»، `MudForm.Validate()` فیلدهای رندرنشدهٔ Required را نامعتبر می‌دید و تابع بی‌صدا `return` می‌کرد. |
| **`_busy` هرگز `true` نمی‌شد** | فقط در `finally` صفر می‌شد؛ دکمه قفل نمی‌شد و دابل‌کلیک دو رکورد می‌ساخت. |
| **حذف تفصیلی همیشه خطا می‌داد** | مستقیم `BaseDetilDelete` صدا زده می‌شد که اگر پیوندی باشد خطا می‌دهد — و هر تفصیلیِ داخل درخت طبق تعریف پیوند دارد. حالا اول پیوند برداشته می‌شود. |
| **پاک شدن شرح** | ویرایش/غیرفعال‌سازی از درخت `Description = ""` می‌فرستاد و شرح موجود را پاک می‌کرد. حالا `NULL` یعنی «دست نزن». |
| **مسیر جستجو باز نمی‌شد** | والد با `AccountCode.StartsWith(moein.Code)` پیدا می‌شد که هرگز match نمی‌کرد (کد معین ۳ رقم است). حالا از `ParentId`/`MoeinId` واقعی استفاده می‌شود. |
| **سوییچ «نمایش غیرفعال‌ها»** | UI پارامتر `@IncludeInactive` می‌فرستاد ولی `ChartAccountPickerList` آن را تعریف نکرده بود (Dapper بی‌صدا نادیده می‌گیرد) → سوییچ هیچ اثری نداشت. |

---

## ۸. جلوگیری از تکرار — `tools/sql-contract-scan.py`

هیچ کامپایلری قرارداد «اسکریپت نامدار ↔ فراخوان Dapper» را چک نمی‌کند؛ برای
همین این کلاس باگ تا زمان اجرا پنهان می‌ماند. یک اسکنر ایستا اضافه شد که در CI
اجرا می‌شود و این موارد را می‌گیرد:

| بررسی | چه چیزی را می‌گیرد |
|---|---|
| `MISSING_SCRIPT` | اسکریپت فراخوانی‌شده وجود ندارد |
| `MISSING_PARAM` | پارامتر لازم فرستاده نشده |
| `COLLISION` | پارامتر هم‌نام با `DECLARE` (خطای Msg 134) |
| `ALWAYS_TRUE_NULL` | `DECLARE @x INT = 0` + `IF @x IS NOT NULL` (باگ شمارهٔ ۱) |
| `BATCH_HAZARD` | ستون اضافه‌شده و استفاده در همان batch بدون `GO` (باگ شمارهٔ ۲) |
| `SEED_ORDER` | `INSERT` که از جدولی می‌خواند که بعداً seed می‌شود (باگ شمارهٔ ۳) |
| `STALE_INDEX_HINT` | hint به ایندکسی که تضمین‌شده ساخته نمی‌شود (باگ شمارهٔ ۶) |

اجرا:

```bash
python3 tools/sql-contract-scan.py     # خروجی ۰ = سالم، ۱ = خطا
```

هر هفت بررسی با برگرداندن موقت باگ اصلی **تست منفی** شدند و همگی خطا را
گرفتند.

---

## وضعیت فعلی

```
$ python3 tools/sql-contract-scan.py
اسکریپت‌ها: 239
نتیجه: قرارداد سالم است (0 هشدار)

$ bash tools/cross-schema-scan.sh
Cross-schema scan OK — no undocumented cross-schema references
```

**تأیید نشده (نیازمند محیط واقعی):** در این sandbox نه .NET SDK هست و نه
SQL Server (دسترسی به NuGet/`packages.microsoft.com` بسته است)، بنابراین
`dotnet build` و اجرای واقعی روی دیتابیس انجام نشد. تحلیل‌ها ایستا هستند
(۲۳۹ اسکریپت + ۱۹۲ فراخوان). پیشنهاد تست دستی پس از بالا آمدن محیط:

1. `docker compose up -d` سپس اجرای وب → دیتابیس و جداول باید ساخته شوند.
2. `/accounting/chart` → «حساب کل جدید» → «+ معین» → «+ تفصیلی»
   (گره باید بلافاصله زیر والدِ بازشده ظاهر شود).
3. «استفاده در مسیر جدید» روی یک تفصیلی → باید در معین دوم هم دیده شود.
4. حذف یک تفصیلی از درخت → فقط همان مسیر برداشته شود.

---

## ۹. اصلاح تکمیلی: سطح ۴ به بعد واقعاً سلسله‌مراتبی است

رفع قبلی فقط دکمهٔ «+ تفصیلی» را روی یک تفصیلی هم نمایش می‌داد، اما در دیتابیس
هر رکورد `BaseDetilLink` هنوز فقط `MoeinId` داشت. بنابراین گره جدید دوباره
مستقیماً زیر معین ذخیره و همیشه **Level 3** می‌شد؛ یعنی sibling جدید بود، نه
child سطح ۴. این محدودیت با UI قابل‌حل نبود و به تغییر مدل داده نیاز داشت.

اکنون ستون nullable زیر به‌صورت migration idempotent اضافه می‌شود:

```sql
[accounting].[BaseDetilLink].ParentLinkId
```

- `ParentLinkId IS NULL`: تفصیلی سطح ۳ زیر معین؛
- `ParentLinkId = LinkId والد`: تفصیلی سطح ۴ به بعد؛
- `Level` و `AccountCode` با recursive CTE از زنجیره محاسبه می‌شوند؛
- داده‌های قبلی بدون تغییر و با `ParentLinkId=NULL` در سطح ۳ باقی می‌مانند؛
- حذف والد تا وقتی زیرسطح دارد ممنوع است؛
- expand/search/breadcrumb/picker همگی از `LinkId` مسیر و `ParentLinkId` استفاده می‌کنند.

### محل واقعی ذخیره در SQL Server

داده‌ها in-memory یا فایل محلی نیستند. مقصد فعال را صفحهٔ `/diag` نشان می‌دهد؛
مقدار پیش‌فرض وب `Server=.;Database=TarazinMaster` است، مگر اینکه
`TARAZIN_SQL_CONNECTION` آن را override کرده باشد. جداول هم زیر schema
`accounting` هستند، نه `dbo`:

```sql
USE [TarazinMaster];
SELECT * FROM [accounting].[BaseCol];
SELECT * FROM [accounting].[BaseMoein];
SELECT * FROM [accounting].[BaseDetil];
SELECT LinkId, DetilId, MoeinId, ParentLinkId, IsDeleted
FROM [accounting].[BaseDetilLink]
ORDER BY LinkId;
```

برای اعمال migration باید برنامه یک‌بار restart شود تا `accounting/_Ensure.sql`
در startup اجرا شود.
