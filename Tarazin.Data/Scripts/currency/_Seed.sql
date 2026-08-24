-- =============================================
-- Tarazin.Data/Scripts/currency/_Seed.sql
-- Schema: currency
-- Endpoint: execute (startup) — idempotent
-- =============================================
-- داده‌های نمونهٔ tenant-owned برای هر شرکت فعال seed می‌شوند؛ جداول ارزیِ
-- Global (Currencies/PriceRates/...) عمداً CompanyId ندارند و مشترک‌اند.
DECLARE @SeedCompanyId INT = (
    SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);

-- ── ارزهای پایه (PRD §34) + ریال/تومان (PRD §35) ────────────────────────
IF NOT EXISTS (SELECT 1 FROM [currency].[Currencies])
BEGIN
    INSERT INTO [currency].[Currencies] (CurrencyCode, CurrencyName, Symbol, IsBase, UnitFactor, IsActive, CreatedAt)
    VALUES
        (N'IRR',   N'ریال ایران',        N'﷼',    1, 1,        1, SYSUTCDATETIME()),
        (N'TOMAN', N'تومان',             N'تومان', 0, 10,       1, SYSUTCDATETIME()),
        (N'USD',   N'دلار آمریکا',       N'$',    0, 1,        1, SYSUTCDATETIME()),
        (N'EUR',   N'یورو',              N'€',    0, 1,        1, SYSUTCDATETIME()),
        (N'AED',   N'درهم امارات',       N'د.ا',  0, 1,        1, SYSUTCDATETIME()),
        (N'GBP',   N'پوند انگلیس',       N'£',    0, 1,        1, SYSUTCDATETIME()),
        (N'TRY',   N'لیر ترکیه',         N'₺',    0, 1,        1, SYSUTCDATETIME()),
        (N'CNY',   N'یوان چین',          N'¥',    0, 1,        1, SYSUTCDATETIME()),
        (N'IQD',   N'دینار عراق',        N'ع.د',  0, 1,        1, SYSUTCDATETIME()),
        (N'KWD',   N'دینار کویت',        N'د.ك',  0, 1,        1, SYSUTCDATETIME()),
        (N'SAR',   N'ریال عربستان',      N'ر.س',  0, 1,        1, SYSUTCDATETIME()),
        (N'CHF',   N'فرانک سوئیس',       N'CHF',  0, 1,        1, SYSUTCDATETIME()),
        (N'CAD',   N'دلار کانادا',       N'C$',   0, 1,        1, SYSUTCDATETIME()),
        (N'AUD',   N'دلار استرالیا',     N'A$',   0, 1,        1, SYSUTCDATETIME()),
        (N'JPY',   N'ین ژاپن',           N'¥',    0, 1,        1, SYSUTCDATETIME()),
        (N'RUB',   N'روبل روسیه',        N'₽',    0, 1,        1, SYSUTCDATETIME());
END

-- ── کاتالوگ مرکز قیمت (PRD §43) ────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM [currency].[PriceItems])
BEGIN
    INSERT INTO [currency].[PriceItems] (ItemType, ItemKey, Title, Unit, IsActive, CreatedAt)
    VALUES
        -- ارزها
        (N'Currency', N'IRR',   N'ریال ایران',     N'واحد', 1, SYSUTCDATETIME()),
        (N'Currency', N'TOMAN', N'تومان',          N'واحد', 1, SYSUTCDATETIME()),
        (N'Currency', N'USD',   N'دلار آمریکا',    N'دلار', 1, SYSUTCDATETIME()),
        (N'Currency', N'EUR',   N'یورو',           N'یورو', 1, SYSUTCDATETIME()),
        (N'Currency', N'AED',   N'درهم امارات',    N'درهم', 1, SYSUTCDATETIME()),
        (N'Currency', N'GBP',   N'پوند انگلیس',    N'پوند', 1, SYSUTCDATETIME()),
        (N'Currency', N'TRY',   N'لیر ترکیه',      N'لیر',  1, SYSUTCDATETIME()),
        (N'Currency', N'CNY',   N'یوان چین',       N'یوان', 1, SYSUTCDATETIME()),
        (N'Currency', N'IQD',   N'دینار عراق',     N'دینار',1, SYSUTCDATETIME()),
        (N'Currency', N'KWD',   N'دینار کویت',     N'دینار',1, SYSUTCDATETIME()),
        (N'Currency', N'SAR',   N'ریال عربستان',   N'ریال', 1, SYSUTCDATETIME()),
        (N'Currency', N'CHF',   N'فرانک سوئیس',    N'فرانک',1, SYSUTCDATETIME()),
        (N'Currency', N'CAD',   N'دلار کانادا',    N'دلار', 1, SYSUTCDATETIME()),
        (N'Currency', N'AUD',   N'دلار استرالیا',  N'دلار', 1, SYSUTCDATETIME()),
        (N'Currency', N'JPY',   N'ین ژاپن',        N'ین',   1, SYSUTCDATETIME()),
        (N'Currency', N'RUB',   N'روبل روسیه',     N'روبل', 1, SYSUTCDATETIME()),
        -- طلا
        (N'Gold', N'XAU-24',      N'گرم ۲۴ عیار',      N'گرم', 1, SYSUTCDATETIME()),
        (N'Gold', N'XAU-18',      N'گرم ۱۸ عیار',      N'گرم', 1, SYSUTCDATETIME()),
        (N'Gold', N'XAU-18-750',  N'۱۸ عیار ۷۵۰',      N'گرم', 1, SYSUTCDATETIME()),
        (N'Gold', N'XAU-20',      N'۲۰ عیار',          N'گرم', 1, SYSUTCDATETIME()),
        (N'Gold', N'XAU-21',      N'۲۱ عیار',          N'گرم', 1, SYSUTCDATETIME()),
        (N'Gold', N'XAU-22',      N'۲۲ عیار',          N'گرم', 1, SYSUTCDATETIME()),
        (N'Gold', N'MISGHAL',     N'مثقال',            N'مثقال', 1, SYSUTCDATETIME()),
        (N'Gold', N'OUNCE',       N'انس جهانی',        N'انس', 1, SYSUTCDATETIME()),
        (N'Gold', N'XAU-SECOND',  N'طلای دست دوم',     N'گرم', 1, SYSUTCDATETIME()),
        (N'Gold', N'XAU-MELTED',  N'آب‌شده',           N'گرم', 1, SYSUTCDATETIME()),
        -- سکه
        (N'Coin', N'SIKKEH-EMAMI', N'سکه امامی',      N'سکه', 1, SYSUTCDATETIME()),
        (N'Coin', N'SIKKEH-BAHAR', N'سکه بهار آزادی', N'سکه', 1, SYSUTCDATETIME()),
        (N'Coin', N'SIKKEH-NIM',   N'نیم‌سکه',        N'سکه', 1, SYSUTCDATETIME()),
        (N'Coin', N'SIKKEH-ROB',   N'ربع‌سکه',        N'سکه', 1, SYSUTCDATETIME()),
        (N'Coin', N'SIKKEH-GRAMI', N'سکه گرمی',       N'سکه', 1, SYSUTCDATETIME()),
        -- فلزات گران‌بها
        (N'Metal', N'XAG', N'نقره',        N'گرم', 1, SYSUTCDATETIME()),
        (N'Metal', N'XPT', N'پلاتین',      N'گرم', 1, SYSUTCDATETIME()),
        (N'Metal', N'XPD', N'پالادیوم',    N'گرم', 1, SYSUTCDATETIME());
END

-- ── آیتم‌های API رسمی TabloTala ─────────────────────────────────────────
-- type=IR قیمت‌های داخلی را به «تومان» می‌دهد؛ Factor=10 آن‌ها را به واحد
-- پایهٔ برنامه (ریال) تبدیل می‌کند. type=FR برابری ارزها با USD و قیمت‌های
-- جهانی را می‌دهد؛ برای جلوگیری از مخلوط شدن با نرخ ریالی، آیتم مستقل دارد.
INSERT INTO [currency].[PriceItems] (ItemType, ItemKey, Title, Unit, IsActive, CreatedAt, CreatedBy)
SELECT v.ItemType, v.ItemKey, v.Title, v.Unit, 1, SYSUTCDATETIME(), N'seed'
FROM (VALUES
    (N'Global',   N'XAU-OUNCE-USD', N'اونس جهانی طلا',             N'USD/oz'),
    (N'Gold',     N'MAZANEH-17',    N'مظنه ۱۷ عیار',               N'ریال/مثقال'),
    (N'Gold',     N'XAU-740',       N'گرم طلای ۷۴۰',               N'ریال/گرم'),
    (N'Gold',     N'XAU-WORLD-17',  N'طلای جهانی ۱۷ عیار',         N'ریال/مثقال'),
    (N'FxParity', N'EUR-USD',       N'برابری یورو با دلار',        N'USD/EUR'),
    (N'FxParity', N'GBP-USD',       N'برابری پوند با دلار',        N'USD/GBP'),
    (N'FxParity', N'CAD-USD',       N'برابری دلار کانادا با دلار', N'USD/CAD'),
    (N'FxParity', N'JPY100-USD',    N'برابری یکصد ین با دلار',     N'USD/100JPY'),
    (N'FxParity', N'CHF-USD',       N'برابری فرانک با دلار',       N'USD/CHF'),
    (N'FxParity', N'AUD-USD',       N'برابری دلار استرالیا',       N'USD/AUD'),
    (N'FxParity', N'SEK-USD',       N'برابری کرون سوئد با دلار',   N'USD/SEK'),
    (N'FxParity', N'TRY-USD',       N'برابری لیر با دلار',         N'USD/TRY'),
    (N'Global',   N'XAG-OUNCE-USD', N'نقره جهانی',                 N'USD/oz'),
    (N'Global',   N'OIL-BARREL-USD',N'نفت جهانی',                  N'USD/bbl'),
    (N'Global',   N'XPT-OUNCE-USD', N'پلاتینیوم جهانی',            N'USD/oz'),
    (N'Global',   N'XPD-OUNCE-USD', N'پالادیوم جهانی',             N'USD/oz')
) v(ItemType, ItemKey, Title, Unit)
WHERE NOT EXISTS (
    SELECT 1 FROM [currency].[PriceItems] p WHERE p.ItemKey = v.ItemKey);

-- تفکیک روشن آیتم قدیمیِ ریالی از اونس خام دلاری API.
UPDATE [currency].[PriceItems]
SET Title = N'اونس جهانی (نرخ ریالی)', Unit = N'ریال/انس', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = N'seed-migration'
WHERE ItemKey = N'OUNCE' AND Title = N'انس جهانی';

-- ردیف اولیهٔ نرخ برای آیتم‌های تازه تا قبل از اولین fetch نیز روی تابلو دیده شوند.
INSERT INTO [currency].[PriceRates]
    (PriceItemId, SystemRate, SourceKey, IsValid, Status, RateDate, UpdatedAt, UpdatedBy)
SELECT p.PriceItemId, 0, NULL, 0, N'Stale', CAST(SYSUTCDATETIME() AS DATE), SYSUTCDATETIME(), N'seed'
FROM [currency].[PriceItems] p
WHERE p.ItemKey IN (
    N'XAU-OUNCE-USD', N'MAZANEH-17', N'XAU-740', N'XAU-WORLD-17',
    N'EUR-USD', N'GBP-USD', N'CAD-USD', N'JPY100-USD', N'CHF-USD', N'AUD-USD', N'SEK-USD', N'TRY-USD',
    N'XAG-OUNCE-USD', N'OIL-BARREL-USD', N'XPT-OUNCE-USD', N'XPD-OUNCE-USD')
  AND NOT EXISTS (
      SELECT 1 FROM [currency].[PriceRates] r WHERE r.PriceItemId = p.PriceItemId);

-- ── منابع قیمت رسمی (PRD §44/§58/§61) ──────────────────────────────────
DECLARE @TabloIrMappings NVARCHAR(MAX) = N'[
 {"ItemKey":"XAU-OUNCE-USD","Path":"data[type=GOLD].price","Factor":1},
 {"ItemKey":"MAZANEH-17","Path":"data[type=IRG17].price","Factor":10},
 {"ItemKey":"SIKKEH-BAHAR","Path":"data[type=IRCOLD].price","Factor":10},
 {"ItemKey":"SIKKEH-EMAMI","Path":"data[type=IRCNEW].price","Factor":10},
 {"ItemKey":"XAU-18","Path":"data[type=IRG18].price","Factor":10},
 {"ItemKey":"XAU-18-750","Path":"data[type=IRG18].price","Factor":10},
 {"ItemKey":"MISGHAL","Path":"data[type=IRGM18].price","Factor":10},
 {"ItemKey":"SIKKEH-NIM","Path":"data[type=IRC2].price","Factor":10},
 {"ItemKey":"SIKKEH-ROB","Path":"data[type=IRC4].price","Factor":10},
 {"ItemKey":"XAU-740","Path":"data[type=IRG740].price","Factor":10},
 {"ItemKey":"XAU-WORLD-17","Path":"data[type=WORLDG17].price","Factor":10},
 {"ItemKey":"SIKKEH-GRAMI","Path":"data[type=IRCGRAM].price","Factor":10},
 {"ItemKey":"USD","Path":"data[type=USD].price","Factor":10},
 {"ItemKey":"EUR","Path":"data[type=EUR].price","Factor":10},
 {"ItemKey":"AED","Path":"data[type=AED].price","Factor":10},
 {"ItemKey":"GBP","Path":"data[type=GBP].price","Factor":10},
 {"ItemKey":"TRY","Path":"data[type=TRY].price","Factor":10},
 {"ItemKey":"SAR","Path":"data[type=SAR].price","Factor":10},
 {"ItemKey":"CHF","Path":"data[type=CHF].price","Factor":10},
 {"ItemKey":"CAD","Path":"data[type=CAD].price","Factor":10},
 {"ItemKey":"AUD","Path":"data[type=AUD].price","Factor":10},
 {"ItemKey":"JPY","Path":"data[type=JPY].price","Factor":10},
 {"ItemKey":"CNY","Path":"data[type=CNY].price","Factor":10},
 {"ItemKey":"KWD","Path":"data[type=KWD].price","Factor":10},
 {"ItemKey":"IQD","Path":"data[type=IQD].price","Factor":10},
 {"ItemKey":"RUB","Path":"data[type=RUB].price","Factor":10}
]';

DECLARE @TabloFrMappings NVARCHAR(MAX) = N'[
 {"ItemKey":"EUR-USD","Path":"data[type=EUR].price","Factor":1},
 {"ItemKey":"GBP-USD","Path":"data[type=GBP].price","Factor":1},
 {"ItemKey":"CAD-USD","Path":"data[type=CAD].price","Factor":1},
 {"ItemKey":"JPY100-USD","Path":"data[type=JPY].price","Factor":1},
 {"ItemKey":"CHF-USD","Path":"data[type=CHF].price","Factor":1},
 {"ItemKey":"AUD-USD","Path":"data[type=AUD].price","Factor":1},
 {"ItemKey":"SEK-USD","Path":"data[type=SEK].price","Factor":1},
 {"ItemKey":"TRY-USD","Path":"data[type=TRY].price","Factor":1},
 {"ItemKey":"XAG-OUNCE-USD","Path":"data[type=SILVER].price","Factor":1},
 {"ItemKey":"OIL-BARREL-USD","Path":"data[type=OIL].price","Factor":1},
 {"ItemKey":"XPT-OUNCE-USD","Path":"data[type=PLATINUM].price","Factor":1},
 {"ItemKey":"XPD-OUNCE-USD","Path":"data[type=PALLADIUM].price","Factor":1}
]';

IF NOT EXISTS (SELECT 1 FROM [currency].[PriceSources] WHERE SourceKey = N'TABLOTALA')
BEGIN
    INSERT INTO [currency].[PriceSources]
        (SourceKey, Title, BaseUrl, Endpoint, MappingsJson, IsActive, Priority, FetchIntervalSeconds, Status, CreatedAt)
    VALUES
        (N'TABLOTALA', N'تابلو طلا — بازار ایران', N'https://admin.tablotala.app',
         N'https://admin.tablotala.app/api/tv/price?type=IR', @TabloIrMappings,
         1, 1, 300, N'Unknown', SYSUTCDATETIME());
END
ELSE
BEGIN
    -- migration منبع اشتباه قدیمی tv.tablotala.app/api/rates
    UPDATE [currency].[PriceSources]
    SET Title = N'تابلو طلا — بازار ایران',
        BaseUrl = N'https://admin.tablotala.app',
        Endpoint = N'https://admin.tablotala.app/api/tv/price?type=IR',
        MappingsJson = @TabloIrMappings,
        IsActive = 1,
        Priority = 1,
        Status = CASE WHEN Endpoint = N'https://tv.tablotala.app/api/rates' THEN N'Unknown' ELSE Status END,
        LastError = CASE WHEN Endpoint = N'https://tv.tablotala.app/api/rates' THEN NULL ELSE LastError END,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = N'seed-migration'
    WHERE SourceKey = N'TABLOTALA'
      AND (Endpoint IS NULL OR Endpoint = N'https://tv.tablotala.app/api/rates');
END

IF NOT EXISTS (SELECT 1 FROM [currency].[PriceSources] WHERE SourceKey = N'TABLOTALA_FR')
BEGIN
    INSERT INTO [currency].[PriceSources]
        (SourceKey, Title, BaseUrl, Endpoint, MappingsJson, IsActive, Priority, FetchIntervalSeconds, Status, CreatedAt)
    VALUES
        (N'TABLOTALA_FR', N'تابلو طلا — بازار جهانی', N'https://admin.tablotala.app',
         N'https://admin.tablotala.app/api/tv/price?type=FR', @TabloFrMappings,
         1, 2, 300, N'Unknown', SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [currency].[PriceSources]
    SET Title = N'تابلو طلا — بازار جهانی',
        BaseUrl = N'https://admin.tablotala.app',
        Endpoint = N'https://admin.tablotala.app/api/tv/price?type=FR',
        MappingsJson = @TabloFrMappings,
        IsActive = 1,
        Priority = 2,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = N'seed-migration'
    WHERE SourceKey = N'TABLOTALA_FR'
      AND Endpoint IS NULL;
END

-- منبع HTML ماتیسا API رسمی JSON نیست؛ رکورد قدیمی حذف نمی‌شود تا تاریخچه
-- حفظ شود، ولی دیگر توسط Scheduler فراخوانی نخواهد شد.
UPDATE [currency].[PriceSources]
SET IsActive = 0,
    Status = N'Disabled',
    LastError = N'غیرفعال شد: این Endpoint صفحهٔ HTML بود، نه API رسمی JSON.',
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = N'seed-migration'
WHERE SourceKey = N'MATISA'
  AND Endpoint = N'https://matisagoldgallery.com/tablo'
  AND (IsActive = 1 OR Status <> N'Disabled');


-- Migration: currency online mappings for existing DBs
IF EXISTS (SELECT 1 FROM [currency].[PriceSources] WHERE SourceKey = N'TABLOTALA')
BEGIN
    UPDATE [currency].[PriceSources]
    SET MappingsJson = @TabloIrMappings,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = N'seed-migration-currency'
    WHERE SourceKey = N'TABLOTALA'
      AND (MappingsJson IS NULL OR CHARINDEX(N'"ItemKey":"USD"', MappingsJson) = 0);
END
IF NOT EXISTS (SELECT 1 FROM [currency].[PriceSources] WHERE SourceKey = N'MANUAL')
BEGIN
    INSERT INTO [currency].[PriceSources]
        (SourceKey, Title, IsActive, Priority, FetchIntervalSeconds, Status, CreatedAt)
    VALUES
        (N'MANUAL', N'ورود دستی', 1, 99, 0, N'Active', SYSUTCDATETIME());
END

-- ── نرخ‌های اولیه (مرکز قیمت) ──────────────────────────────────────────
-- به‌صورت per-item idempotent است تا افزودن آیتم جدید باعث نشود نرخ‌های پایهٔ
-- دیتابیس تازه ساخته نشوند یا نرخ ویرایش‌شدهٔ مدیر در startup بازنویسی شود.
INSERT INTO [currency].[PriceRates]
    (PriceItemId, OnlineRate, ManualRate, SystemRate, BuyRate, SellRate,
     AccountingRate, MidRate, Spread, SourceKey, Status, RateDate, UpdatedAt, UpdatedBy)
SELECT p.PriceItemId, NULL, NULL,
       CASE p.ItemKey
           WHEN N'IRR'   THEN 1
           WHEN N'TOMAN' THEN 10
           WHEN N'USD'   THEN 615000
           WHEN N'EUR'   THEN 672000
           WHEN N'AED'   THEN 167500
           WHEN N'GBP'   THEN 780000
           WHEN N'TRY'   THEN 18500
           WHEN N'CNY'   THEN 86000
           WHEN N'IQD'   THEN 470
           WHEN N'KWD'   THEN 1990000
           WHEN N'SAR'   THEN 164000
           WHEN N'CHF'   THEN 700000
           WHEN N'CAD'   THEN 450000
           WHEN N'AUD'   THEN 410000
           WHEN N'JPY'   THEN 4150
           WHEN N'RUB'   THEN 7000
           WHEN N'XAU-24' THEN 38000000
           WHEN N'XAU-18' THEN 28000000
           WHEN N'XAU-18-750' THEN 28000000
           WHEN N'XAU-20' THEN 31000000
           WHEN N'XAU-21' THEN 32500000
           WHEN N'XAU-22' THEN 35000000
           WHEN N'MISGHAL' THEN 121000000
           WHEN N'OUNCE'  THEN 115000000
           WHEN N'XAU-SECOND' THEN 27000000
           WHEN N'XAU-MELTED' THEN 27500000
           WHEN N'SIKKEH-EMAMI' THEN 62000000
           WHEN N'SIKKEH-BAHAR' THEN 60000000
           WHEN N'SIKKEH-NIM'   THEN 32000000
           WHEN N'SIKKEH-ROB'   THEN 17000000
           WHEN N'SIKKEH-GRAMI' THEN 9000000
           WHEN N'XAG'   THEN 380000
           WHEN N'XPT'   THEN 32000000
           WHEN N'XPD'   THEN 30000000
           ELSE 0
       END,
       CASE p.ItemKey WHEN N'USD' THEN 614500 WHEN N'EUR' THEN 671500 WHEN N'AED' THEN 167200 ELSE NULL END,
       CASE p.ItemKey WHEN N'USD' THEN 615500 WHEN N'EUR' THEN 672500 WHEN N'AED' THEN 167800 ELSE NULL END,
       NULL,
       CASE p.ItemKey WHEN N'USD' THEN 615000 WHEN N'EUR' THEN 672000 WHEN N'AED' THEN 167500 ELSE NULL END,
       CASE p.ItemKey WHEN N'USD' THEN 1000 WHEN N'EUR' THEN 1000 WHEN N'AED' THEN 600 ELSE NULL END,
       N'MANUAL',
       CASE WHEN p.ItemType IN (N'FxParity', N'Global') THEN N'Stale' ELSE N'Active' END,
       CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME(), N'seed'
FROM [currency].[PriceItems] p
WHERE p.IsDeleted = 0
  AND NOT EXISTS (
      SELECT 1 FROM [currency].[PriceRates] r WHERE r.PriceItemId = p.PriceItemId);

-- ── تنظیمات ارز (PRD §35/§56) ──────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM [currency].[Settings])
BEGIN
    INSERT INTO [currency].[Settings] (SettingKey, SettingValue, Description)
    VALUES
        (N'BaseCurrency',           N'IRR',   N'واحد حسابداری پایه سیستم — همیشه ریال'),
        (N'BaseUnitTitle',          N'ریال',  N'عنوان واحد پایه'),
        (N'TomanFactor',            N'10',    N'هر تومان چند ریال است (تبدیل خودکار ریال↔تومان)'),
        (N'AutoPromoteOnlineToSystem', N'0',  N'در صورت 1، نرخ آنلاین پس از دریافت خودکار به نرخ سیستم تبدیل می‌شود (پیش‌فرض: خیر — فقط با تأیید مدیر §46/§56)'),
        (N'DefaultUpdateIntervalSeconds', N'300', N'فاصلهٔ پیش‌فرض بروزرسانی خودکار نرخ‌ها (ثانیه)'),
        (N'LastValuationDate',      N'',      N'تاریخ آخرین اسنپ‌شات ارزش دارایی');
END

-- ── کیف پول ارز نمونه (PRD §36) ────────────────────────────────────────
-- برای هر شرکت، فقط ارزهای نمونهٔ همان شرکت درج می‌شوند؛ اجرای دوباره
-- موجودی یا نرخ متوسط خرید را بازنویسی نمی‌کند.
INSERT INTO [currency].[Wallets]
    (CurrencyCode, Quantity, AvgBuyRate, OpeningQty, OpeningAvgRate, InQty, OutQty, UpdatedAt, CompanyId)
SELECT v.CurrencyCode, v.Quantity, v.AvgBuyRate, v.Quantity, v.AvgBuyRate, 0, 0, SYSUTCDATETIME(), c.CompanyId
FROM [central].[Companies] c
CROSS JOIN (VALUES
    (N'USD', CONVERT(DECIMAL(18,4), 10000), CONVERT(DECIMAL(18,2), 614000)),
    (N'EUR', CONVERT(DECIMAL(18,4), 5000),  CONVERT(DECIMAL(18,2), 671000)),
    (N'AED', CONVERT(DECIMAL(18,4), 20000), CONVERT(DECIMAL(18,2), 167000))
) v(CurrencyCode, Quantity, AvgBuyRate)
WHERE c.IsDeleted = 0
  AND NOT EXISTS
      (SELECT 1 FROM [currency].[Wallets] w
       WHERE w.CompanyId = c.CompanyId AND w.CurrencyCode = v.CurrencyCode);

-- ── دارایی فیزیکی نمونه (PRD §50/§51) ──────────────────────────────────
INSERT INTO [currency].[AssetHoldings] (ItemKey, Title, Quantity, CostRate, UpdatedAt, CompanyId)
SELECT v.ItemKey, v.Title, v.Quantity, v.CostRate, SYSUTCDATETIME(), c.CompanyId
FROM [central].[Companies] c
CROSS JOIN (VALUES
    (N'XAU-18', N'طلای ۱۸ عیار (گرم)', CONVERT(DECIMAL(18,4), 100), CONVERT(DECIMAL(18,2), 27000000)),
    (N'SIKKEH-EMAMI', N'سکه امامی', CONVERT(DECIMAL(18,4), 10), CONVERT(DECIMAL(18,2), 60000000))
) v(ItemKey, Title, Quantity, CostRate)
WHERE c.IsDeleted = 0
  AND NOT EXISTS
      (SELECT 1 FROM [currency].[AssetHoldings] h
       WHERE h.CompanyId = c.CompanyId AND h.ItemKey = v.ItemKey);
