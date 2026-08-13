-- =============================================
-- Tarazin.Data/Scripts/bi/BiAlerts.sql
-- Schema: bi
-- Cross-schema: treasury, currency, inventory, accounting
-- Query. مرکز هشدار (§100/§102) — همه از دادهٔ واقعی:
--   چک‌های نزدیک سررسید | منابع قیمت Offline | نرخ‌های قدیمی | موجودی منفی | کالای راکد | بدهکار بزرگ
-- خروجی: (AlertKey, Severity, Title, Detail, Amount, OccurredAt, Source, Action, Link)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

-- چک‌های ۷ روز آینده
SELECT N'cheque7' AS AlertKey,
       N'Warning' AS Severity,
       N'چک نزدیک سررسید' AS Title,
       N'چک ' + c.ChequeNumber + N' (' + CASE c.Direction WHEN N'In' THEN N'دریافتی' ELSE N'پرداختی' END + N') در ' + CONVERT(NVARCHAR(10), c.DueDate, 111) + N' سررسید می‌شود.' AS Detail,
       CAST(c.Amount AS DECIMAL(18,2)) AS Amount,
       c.DueDate AS OccurredAt,
       N'treasury' AS Source,
       N'در صفحهٔ خزانه بررسی و تسویه شود.' AS Action,
       N'/treasury' AS Link
FROM [treasury].[Cheques] c
WHERE c.Status = N'Pending' AND c.DueDate BETWEEN @Today AND DATEADD(DAY, 7, @Today)

UNION ALL

-- منابع قیمت قطع
SELECT N'src_offline', N'Critical', N'منبع قیمت قطع است',
       s.Title + N' در دسترس نیست — آخرین نرخ معتبر حفظ شده است (§57).',
       NULL, s.LastFetchAt, N'currency', N'وضعیت منبع را در عملیات ویژه بررسی کنید.',
       N'/currency/special'
FROM [currency].[PriceSources] s
WHERE s.Status = N'Offline'

UNION ALL

-- نرخ‌های قدیمی (بدون دریافت آنلاین به‌مدت ۲ برابر فاصلهٔ تعریف‌شده)
SELECT N'stale_rate', N'Warning', N'نرخ قدیمی شده است',
       p.Title + N' آخرین دریافت آنلاین: ' + ISNULL(CONVERT(NVARCHAR(20), r.LastFetchAt, 120), N'—'),
       NULL, r.LastFetchAt, N'currency', N'دریافت دستی نرخ انجام شود.',
       N'/currency/prices'
FROM [currency].[PriceRates] r
JOIN [currency].[PriceItems] p ON p.PriceItemId = r.PriceItemId
WHERE p.ItemType = N'Currency' AND p.IsDeleted = 0
  AND r.LastFetchAt IS NOT NULL
  AND DATEDIFF(MINUTE, r.LastFetchAt, SYSUTCDATETIME()) > 1440

UNION ALL

-- موجودی منفی کالا
SELECT N'neg_stock', N'Critical', N'موجودی منفی کالا',
       i.ItemCode + N' — ' + i.ItemTitle + N' با موجودی ' + CONVERT(NVARCHAR(20), i.StockQty),
       CAST(ROUND(ISNULL(i.StockQty, 0) * ISNULL(i.UnitPrice, 0), 0) AS DECIMAL(18,2)),
       NULL, N'inventory', N'با رسید انبار اصلاح شود.', N'/inventory'
FROM [inventory].[Items] i
WHERE i.IsDeleted = 0 AND ISNULL(i.StockQty, 0) < 0

UNION ALL

-- کالاهای راکد (بدون حرکت ۱۸۰ روز)
SELECT N'dead180', N'Warning', N'کالای راکد (۱۸۰ روز)',
       i.ItemCode + N' — ' + i.ItemTitle,
       CAST(ROUND(ISNULL(i.StockQty, 0) * ISNULL(i.UnitPrice, 0), 0) AS DECIMAL(18,2)),
       NULL, N'inventory', N'حرکت/تخفیف/بررسی موجودی راکد.', N'/inventory/reports'
FROM [inventory].[Items] i
WHERE i.IsDeleted = 0 AND NOT EXISTS (
    SELECT 1 FROM [inventory].[Movements] m
    WHERE m.ItemId = i.ItemId AND m.MovementDate >= DATEADD(DAY, -180, @Today))

UNION ALL

-- بدهکاران بزرگ (اسناد فروش معوق بالای ۱ میلیارد)
SELECT N'big_debtor', N'Warning', N'بدهکار بزرگ',
       d.CounterPartyName + N' با ' + CONVERT(NVARCHAR(20), COUNT(*)) + N' سند فروش معوق.',
       CAST(SUM(d.TotalAmount) AS DECIMAL(18,2)),
       MAX(d.DocumentDate), N'accounting', N'وصول مطالبات و تماس با مشتری.', N'/bi?tab=customers'
FROM [accounting].[Documents] d
WHERE d.IsDeleted = 0 AND d.DocumentType IN (N'Sale', N'FxSell', N'FxCombined')
  AND d.CounterPartyName IS NOT NULL
GROUP BY d.CounterPartyName
HAVING SUM(d.TotalAmount) > 1000000000

UNION ALL

-- چک بزرگ (بالای ۱ میلیارد)
SELECT N'big_cheque', N'Warning', N'چک بزرگ',
       N'چک ' + c.ChequeNumber + N' (' + CASE c.Direction WHEN N'In' THEN N'دریافتی' ELSE N'پرداختی' END
       + N') به مبلغ قابل توجه در راه است.',
       CAST(c.Amount AS DECIMAL(18,2)), c.DueDate, N'treasury', N'تسویهٔ به‌موقع چک پیگیری شود.', N'/treasury'
FROM [treasury].[Cheques] c
WHERE c.Status = N'Pending' AND c.Amount > 1000000000

UNION ALL

-- تغییر غیرعادی نرخ (بیش از ۵٪ در ۲۴ ساعت) — §62
SELECT N'rate_spike', N'Warning', N'تغییر غیرعادی نرخ',
       p.Title + N' در ۲۴ ساعت گذشته ' + FORMAT(ABS(ISNULL(r.ChangePercent, 0)), '0.0') + N'٪ تغییر کرده است.',
       NULL, r.LastChangeAt, N'currency', N'نرخ را بررسی و در صورت نیاز Override کنید (§46).', N'/currency/prices'
FROM [currency].[PriceRates] r
JOIN [currency].[PriceItems] p ON p.PriceItemId = r.PriceItemId
WHERE p.IsDeleted = 0
  AND r.LastChangeAt >= DATEADD(HOUR, -24, SYSUTCDATETIME())
  AND ABS(ISNULL(r.ChangePercent, 0)) >= 5

ORDER BY CASE Severity WHEN N'Critical' THEN 0 WHEN N'Warning' THEN 1 ELSE 2 END, OccurredAt;
