# ماژول ارز و معاملات ارزی (Currency) — راهنمای فنی

> PRD بخش دوم §34–§63 · پیاده‌سازی ۲۰۲۶/۰۸/۱۳ · ماژول درجه‌یک محصول (نه ماژول جانبی)
>
> **اصل نهایی:** هر دارایی با واحد اصلی خودش نگهداری می‌شود، اما تمام دارایی‌ها
> در نهایت قابلیت ارزش‌گذاری، گزارش‌گیری و تجمیع بر مبنای **ریال** را دارند.

## ۱. جایگاه در معماری

همان الگوی پنج‌لایه: `Share ← Data ← Ui ← {Web, Maui}`. ماژول جدید `currency`
هشتمین ماژول محصول است (اسکیمهٔ `currency` + مسیر `/currency`). هیچ پروژهٔ
جدیدی ساخته نشده؛ همه‌چیز داخل پروژه‌های موجود است:

| لایه | فایل‌ها |
|------|---------|
| مدل‌ها | `Tarazin.Share/CurrencyModels.cs` |
| دسترسی‌ها | `Tarazin.Share/Permissions.cs` (ماژول `currency` + کلیدهای `rates.*`) |
| داده (اسکریپت‌ها) | `Tarazin.Data/Scripts/currency/*.sql` (۲۹ اسکریپت نامدار در اسکیمهٔ currency + goldshop/GoldRateBoard) |
| سرویس‌های داده | `Tarazin.Data/PriceFeedService.cs`، `PriceFeedScheduler.cs` |
| UI | `Tarazin.Ui/Modules/Currency/Pages/*.razor` (۱۰ صفحه) + `Components/` (۳ دیالوگ) |
| منو/ناوبری | `Tarazin.Ui/Theme/TarazinModules.cs` |

## ۲. اسکیمهٔ دیتابیس (جداول اصلی)

```
currency.Currencies          تعریف ارزها (IRR پایه، TOMAN با ضریب ۱۰، ۱۶ ارز پایه + سفارشی)
currency.PriceItems          کاتالوگ مرکز قیمت: Currency | Gold | Coin | Metal | FxParity | Global
currency.PriceRates          انواع نرخ هر آیتم — مرکز قیمت واحد (§60)
currency.PriceSources        منابع آنلاین: TABLOTALA(IR) / TABLOTALA_FR / MANUAL + Endpoint/نگاشت/اولویت
currency.PriceSourceValues   آخرین مقدار هر منبع (مقایسهٔ منابع §59)
currency.RateHistory         تاریخچهٔ همهٔ تغییرات نرخ (§49)
currency.Wallets             کیف پول هر ارز (§36)
currency.CurrencyMovements   گردش ارز (§36/§37) — نرخ معامله قفل‌شده (§48)
currency.FxTransactions      سربرگ معاملات: Buy | Sell | Conversion | Combined | Transfer
currency.FxTransactionLegs   پاهای معامله (ترکیبی §38) + RealizedPnl (§52)
currency.AssetHoldings       دارایی فیزیکی (طلا/سکه/فلز) با CostRate
currency.AssetValuationHistory  اسنپ‌شات روزانهٔ ارزش دارایی (§51)
currency.Settings            واحد پایه (ریال)، فاصلهٔ بروزرسانی، AutoPromote و …
```

**مرکز قیمت واحد (§60):** همهٔ قیمت‌ها از `PriceRates` می‌آیند
(OnlineRate / ManualRate / SystemRate / BuyRate / SellRate / AccountingRate /
MidRate / Spread). معاملات فقط `SystemRate` (یا نرخ دستیِ دارای مجوز) می‌گیرند
و آن را در `Rate` پای/گردش **قفل** می‌کنند (§48).

## ۳. اسکریپت‌های نامدار

| اسکریپت | کار |
|---------|-----|
| `_Ensure.sql` / `_Seed.sql` | ساخت جداول + seed (ارزها، آیتم‌های قیمت، منابع، نرخ‌های اولیه) |
| `CurrencyList/Upsert` | فهرست/تعریف ارز جدید توسط مدیر (§34) |
| `RateBoard` | تابلوی مرکز نرخ‌ها (همهٔ انواع نرخ + وضعیت + تغییر) |
| `RateComparison` | مقایسهٔ منابع کنار هم (§59) |
| `RateUpsert` | تغییر دستی نرخ (System/Manual/Buy/Sell/Accounting) + تاریخچه (§46/§49) |
| `RateOverride` | تبدیل نرخ آنلاین → نرخ سیستم با تأیید مدیر (§46) |
| `RateHistory` / `RateHistoryChart` | تاریخچه + نقاط نمودار (§49) |
| `FeedApply` | اعمال نرخ‌های دریافتی آنلاین (فقط OnlineRate؛ سیاست AutoPromote؛ هرگز صفر) |
| `PriceSourceList/Upsert/Status` | مدیریت منابع و وضعیت اتصال (§44/§45/§57/§58) |
| `FundList` | صندوق‌ها/بانک‌ها برای تسویه (خواندن خزانه) |
| `WalletList` / `WalletMovements` / `WalletMovementManual` | کیف پول + گردش + گردش دستی ورود/خروج/انتقال/تعدیل (§36) |
| `FxTransactionCreate` | خرید/فروش ارز — یک تراکنش: کیف پول + گردش + سند حسابداری + خزانه + طرف حساب + تاریخچه (§37) + گارد ریال/تومان (§35) |
| `FxCombinedCreate` | معاملات ترکیبی چندپایه (§38) |
| `ConvertPreview` / `ConvertExecute` | موتور تبدیل با کارمزد (§39–§41) — سند کارمزد برای هر سه نوع متوازن است |
| `AssetValuation` / `AssetValuationSnapshot` / `AssetValuationHistoryList` | ارزش لحظه‌ای (§50/§51) |
| `PnlSummary` | تفکیک سود/زیان طلا+ارز (§52/§53) |
| `SettingsList/Upsert` | تنظیمات (ریال/تومان، بروزرسانی خودکار) |

اسکریپت‌هایی که به اسکیمهٔ دیگر دست می‌زنند با هدر `-- Cross-schema:`
اعلام شده‌اند و `tools/cross-schema-scan.sh` پاس است.

## ۴. اثرگذاری خودکار روی بقیهٔ سیستم

معاملهٔ ارز (`FxTransactionCreate`) در **یک تراکنش**:
1. `currency.Wallets`/`CurrencyMovements` — موجودی و گردش ارز.
2. `accounting.Documents`/`DocumentLines` — سند دوبل: خرید = بدهکار «موجودی ارز
   (۱۰۳۰)» / بستانکار «صندوق/بانک (۱۰۰۰/۱۰۱۰)»؛ فروش = بدهکار صندوق / بستانکار
   موجودی ارز (بها) + «سود و زیان تسعیر ارز (۶۰۰۰)».
3. `treasury.CashMovements` + ماندهٔ صندوق/بانک — سمت ریالی.
4. `central.Parties` — ایجاد/به‌روزرسانی طرف حساب.
5. `currency.RateHistory` — قفل نرخ معامله (§48/§49).

حساب‌های ویژه (۱۰۳۰/۱۰۴۰/۶۰۰۰/۶۱۰۰) هم در `accounting._Seed.sql` و هم به‌صورت
دفاعی داخل اسکریپت‌های معامله ساخته می‌شوند.

## ۵. دریافت آنلاین نرخ — بدون HTML Selector (§44/§57/§58/§61)

- `PriceFeedService` (در `Tarazin.Data`) هر منبع را با `Endpoint` (آدرس API/Feed
  رسمی) و `MappingsJson` (نگاشت `ItemKey ← Path` در پاسخ) که **در دیتابیس قابل
  ویرایش توسط مدیر** است، دریافت می‌کند. با تغییر API منبع، فقط Endpoint/نگاشت
  ویرایش می‌شود — بدون تغییر کد و بدون Scrape.
- Endpointهای رسمی فعال:
  - `https://admin.tablotala.app/api/tv/price?type=IR` — قیمت داخلی با واحد تومان؛ هنگام ورود با `Factor=10` به ریال تبدیل می‌شود.
  - `https://admin.tablotala.app/api/tv/price?type=FR` — برابری ارزها با دلار و کالاهای جهانی با واحد USD؛ در آیتم‌های مستقل `FxParity`/`Global` نگهداری می‌شود و با نرخ ریالی ارزها مخلوط نمی‌شود.
- پاسخ هر دو API یک envelope به شکل `status/message/data[]` دارد و هر عضو `data`
  شامل `id/type/ordering/title/last_update/price` است. Path نگاشت از selector
  مقداری مثل `data[type=IRG18].price` پشتیبانی می‌کند؛ بنابراین تغییر ترتیب آرایه
  مشکلی ایجاد نمی‌کند.
- خروجی پشتیبانی‌شده: JSON رسمی یا جاوااسکریپتِ ساختارمند (`var x = {...};`) —
  هرگز HTML Selector. Endpoint قدیمی ماتیسا چون HTML بود غیرفعال شده است.
- ترتیب منابع بر اساس `Priority` (§58)؛ شکست منبع → ثبت خطا، `Status=Offline`
  و بررسی منبع بعدی؛ نرخ‌های معتبر قبلی دست نمی‌خورند (§57).
- نرخ جدید فقط در `OnlineRate` می‌نشیند؛ ورود به `SystemRate` فقط با
  `RateOverride` (تأیید مدیر) یا تنظیم `AutoPromoteOnlineToSystem=1` (§46/§56).
- `PriceFeedScheduler` (singleton) بروزرسانی خودکار server-side را در Web با
  فاصلهٔ قابل‌تنظیم اجرا می‌کند (§56)؛ MAUI database initialization/scheduler
  را اجرا نمی‌کند.

## ۶. دسترسی‌ها (§55)

علاوه بر شش دسترسی استاندارد ماژول (`currency.view/entry/special/reports/
settings/admin`)، دسترسی‌های ویژهٔ نرخ:
`rates.view`، `rates.fetch`، `rates.change`، `rates.override`، `rates.buy`،
`rates.sell`، `rates.gold`، `rates.currency`، `rates.history`، `rates.confirm`.
نقش‌های پیش‌فرض به‌روزرسانی شده‌اند (صندوق‌دار/فروشنده/حسابدار/حسابرس/مشاهده).

## ۷. صفحات

| مسیر | صفحه | بند PRD |
|------|------|---------|
| `/currency` | تابلو قیمت (آنلاین\|سیستم\|خرید\|فروش\|زمان + اصلاح یک‌کلیکی) | 62 |
| `/currency/dashboard` | داشبورد ارز + تفکیک سود | 53 |
| `/currency/wallets` | کیف پول‌ها + گردش ارز + دکمهٔ «ثبت گردش دستی» (ورود/خروج/انتقال/تعدیل) | 36 |
| `/currency/entry` | خرید/فروش ارز با نمایش نرخ جاری (بدون ریال/تومان — §35) | 37، 54 |
| `/currency/combined` | معاملهٔ ترکیبی چندپایه | 38 |
| `/currency/convert` | تبدیل ارز (پیش‌نمایش + اجرا + کارمزد) | 39–41 |
| `/currency/prices` | مرکز نرخ‌ها و قیمت‌ها (شامل نرخ حسابداری §42) + مقایسهٔ منابع | 43، 45–47، 59، 60 |
| `/currency/assets` | ارزش لحظه‌ای دارایی + تاریخچهٔ اسنپ‌شات | 50، 51 |
| `/currency/special` | منابع قیمت، بروزرسانی خودکار، خط مشی نرخ | 44، 56–58، 61 |
| `/currency/settings` | تعریف ارز، ریال/تومان، تنظیمات | 34، 35 |

## ۸. نکات اجرایی/تأیید

- `tools/cross-schema-scan.sh` ✅ پاس.
- صفحهٔ `/diag` نام واقعی SQL Instance، دیتابیس، مسیر فیزیکی MDF/LDF و تعداد
  رکوردهای `BaseDetil`/`PriceRates`/`RateHistory` را از همان connection برنامه
  نشان می‌دهد؛ لاگ startup نیز همین مقصد و شمارنده‌ها را ثبت می‌کند.
- build واقعی نیاز به dotnet SDK + SQL Server دارد (Backlog B1/B3 در `todo.md`).
- `PriceFeedService` از `HttpClient` فقط برای **دادهٔ بازار خارجی** استفاده
  می‌کند؛ دادهٔ کسب‌وکار همچنان فقط از مسیر Dapper/اسکریپت نامدار می‌آید.
- Endpoint و نگاشت رسمی TabloTala در seed به‌صورت idempotent تنظیم می‌شوند و از صفحهٔ `/currency/special` قابل مشاهده‌اند.

---

## ۹. نتیجهٔ بازبینی کامل (§۳۴–§۶۳)

بازبینی بندبه‌بند در برابر فایل‌های پیاده‌سازی‌شده انجام شد. **همهٔ ۳۰ بند پوشش
دارند**؛ سه گپ واقعی شناسایی و در همین نشست بسته شد:

| گپ شناسایی‌شده | اصلاح |
|----------------|-------|
| §۵۴ — فرم فاکتور طلا نرخ مرکز قیمت را نشان نمی‌داد | `goldshop/GoldRateBoard.sql` + چیپ‌های نرخ آنلاین/سیستم و دکمهٔ یک‌کلیکی در `/goldshop/entry` |
| §۳۶ — «انتقال/تعدیل» فقط نوع داده بود، UI ثبت دستی نداشت | `WalletMovementManual.sql` + دیالوگ «ثبت گردش دستی» در `/currency/wallets` |
| §۳۵ — کنترل اشتباه ریال/تومان در معامله نبود | گارد در `FxTransactionCreate` + فیلتر لیست‌ها + نمایش واحد در فرم |
| §۴۲ — نرخ حسابداری در UI نمایش داده نمی‌شد | ستون «حسابداری» به مرکز نرخ‌ها اضافه شد |
| §۴۱ — سند کارمزد برای نوع ریالی با خزانه هماهنگ نبود | بازنویسی سند: کارمزد ریالی = دریافت نقدی (In) + بدهکار صندوق/بانک؛ مبدا/مقصد = هزینهٔ کارمزد (۶۱۰۰) — هر سه حالت متوازن |

**موارد عمدیِ پیگیری‌شده در Backlog (بیرون از این ماژول):** اتصال خودکار
موجودی طلای ماژول طلافروشی (`goldshop.SaleInvoices`) به `AssetHoldings` برای
کسر خودکار هنگام فاکتور فروش — نیازمند تغییر ترتیبات Seed بین‌اسکیمه‌ای است و
برای جلوگیری از شکستن seed موجود، در Backlog ثبت شده است. معاملات طلا از طریق
ماژول ارز (معاملهٔ ترکیبی) همین اثر را دارند.
