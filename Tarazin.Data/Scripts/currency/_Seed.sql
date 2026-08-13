-- =============================================
-- Tarazin.Data/Scripts/currency/_Seed.sql
-- Schema: currency
-- Endpoint: execute (startup) — idempotent
-- =============================================

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

-- ── منابع قیمت (PRD §44/§58/§61) ───────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM [currency].[PriceSources])
BEGIN
    INSERT INTO [currency].[PriceSources]
        (SourceKey, Title, BaseUrl, Endpoint, MappingsJson, IsActive, Priority, FetchIntervalSeconds, Status, CreatedAt)
    VALUES
        (N'TABLOTALA', N'تابلو طلا',
         N'https://tv.tablotala.app', N'https://tv.tablotala.app/api/rates',
         N'[{"ItemKey":"USD","Path":"rates.usd.price","Factor":1},{"ItemKey":"EUR","Path":"rates.eur.price","Factor":1},{"ItemKey":"AED","Path":"rates.aed.price","Factor":1},{"ItemKey":"XAU-18","Path":"rates.gold18.price","Factor":1},{"ItemKey":"XAU-24","Path":"rates.gold24.price","Factor":1},{"ItemKey":"MISGHAL","Path":"rates.mesghal.price","Factor":1},{"ItemKey":"SIKKEH-EMAMI","Path":"rates.emami.price","Factor":1}]',
         1, 1, 300, N'Unknown', SYSUTCDATETIME()),
        (N'MATISA', N'گالری ماتیسا',
         N'https://matisagoldgallery.com', N'https://matisagoldgallery.com/tablo',
         N'[{"ItemKey":"USD","Path":"usd.price","Factor":1},{"ItemKey":"EUR","Path":"eur.price","Factor":1},{"ItemKey":"AED","Path":"aed.price","Factor":1},{"ItemKey":"XAU-18","Path":"gold18.price","Factor":1},{"ItemKey":"SIKKEH-EMAMI","Path":"emami.price","Factor":1}]',
         1, 2, 600, N'Unknown', SYSUTCDATETIME()),
        (N'MANUAL', N'ورود دستی',
         NULL, NULL, NULL,
         1, 99, 0, N'Active', SYSUTCDATETIME());
END

-- ── نرخ‌های اولیه (مرکز قیمت) ──────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM [currency].[PriceRates])
BEGIN
    INSERT INTO [currency].[PriceRates]
        (PriceItemId, OnlineRate, ManualRate, SystemRate, BuyRate, SellRate, AccountingRate, MidRate, Spread, SourceKey, Status, RateDate, UpdatedAt, UpdatedBy)
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
           NULL, NULL,
           NULL,
           NULL, NULL,
           N'MANUAL', N'Active', CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME(), N'seed'
    FROM [currency].[PriceItems] p
    WHERE p.IsDeleted = 0;

    -- نرخ خرید/فروش نمونه برای ارزهای اصلی (اسپرد ۵۰۰ ریالی).
    UPDATE r SET
        BuyRate    = CASE i.ItemKey WHEN N'USD' THEN 614500 WHEN N'EUR' THEN 671500 WHEN N'AED' THEN 167200 ELSE NULL END,
        SellRate   = CASE i.ItemKey WHEN N'USD' THEN 615500 WHEN N'EUR' THEN 672500 WHEN N'AED' THEN 167800 ELSE NULL END,
        MidRate    = CASE i.ItemKey WHEN N'USD' THEN 615000 WHEN N'EUR' THEN 672000 WHEN N'AED' THEN 167500 ELSE NULL END,
        Spread     = CASE i.ItemKey WHEN N'USD' THEN 1000 WHEN N'EUR' THEN 1000 WHEN N'AED' THEN 600 ELSE NULL END,
        UpdatedAt  = SYSUTCDATETIME()
    FROM [currency].[PriceRates] r
    JOIN [currency].[PriceItems] i ON i.PriceItemId = r.PriceItemId
    WHERE i.ItemKey IN (N'USD', N'EUR', N'AED');
END

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
IF NOT EXISTS (SELECT 1 FROM [currency].[Wallets])
BEGIN
    INSERT INTO [currency].[Wallets] (CurrencyCode, Quantity, AvgBuyRate, OpeningQty, OpeningAvgRate, InQty, OutQty, UpdatedAt)
    VALUES
        (N'USD', 10000, 614000, 10000, 614000, 0, 0, SYSUTCDATETIME()),
        (N'EUR', 5000,  671000, 5000,  671000, 0, 0, SYSUTCDATETIME()),
        (N'AED', 20000, 167000, 20000, 167000, 0, 0, SYSUTCDATETIME());
END

-- ── دارایی فیزیکی نمونه (PRD §50/§51) ──────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM [currency].[AssetHoldings])
BEGIN
    INSERT INTO [currency].[AssetHoldings] (ItemKey, Title, Quantity, CostRate, UpdatedAt)
    VALUES
        (N'XAU-18',       N'طلای ۱۸ عیار (گرم)',  100.000, 27000000, SYSUTCDATETIME()),
        (N'SIKKEH-EMAMI', N'سکه امامی',           10.000,  60000000, SYSUTCDATETIME());
END
