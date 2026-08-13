-- =============================================
-- Tarazin.Data/Scripts/bi/BiSalesTrend.sql
-- Schema: bi
-- Cross-schema: goldshop, store, currency
-- Query. روند فروش (§5): روزانه/هفتگی/ماهانه/فصلی/سالانه با قابلیت Granularity.
-- فروش = طلافروشی + فروشگاه (Invoiced) + فروش ارز (Sell).
-- خروجی: (Bucket, Label, Value1=فروش, Value2=فاکتور, Value3=مشتری, Value4=میانگین فاکتور)
--
-- نکتهٔ فنی: برای هر Granularity، تاریخ هر ردیف داده ابتدا به bucket تبدیل و سپس
-- join می‌شود (Bucket(data.D) = bucket) — در غیر این صورت برای هفته/ماه/فصل/سال
-- join روی تاریخ خام با bucket برابر نمی‌شد و نمودار صفر می‌ماند.
-- =============================================
DECLARE @Gran NVARCHAR(10) = ISNULL(@Granularity, N'Day');

WITH data AS (
    SELECT InvoiceDate AS D, TotalAmount AS Amt, CustomerName AS Cust
    FROM [goldshop].[SaleInvoices]
    WHERE (@From IS NULL OR InvoiceDate >= @From) AND (@To IS NULL OR InvoiceDate <= @To)
    UNION ALL
    SELECT OrderDate, TotalAmount, CustomerName
    FROM [store].[Orders]
    WHERE Status = N'Invoiced'
      AND (@From IS NULL OR OrderDate >= @From) AND (@To IS NULL OR OrderDate <= @To)
    UNION ALL
    SELECT TransactionDate, TotalRial, PartyName
    FROM [currency].[FxTransactions]
    WHERE TransactionType = N'Sell'
      AND (@From IS NULL OR TransactionDate >= @From) AND (@To IS NULL OR TransactionDate <= @To)
),
bucketed AS (
    SELECT d.D, d.Amt, d.Cust,
        CASE @Gran
            WHEN N'Week'    THEN DATEADD(WEEK, DATEDIFF(WEEK, 0, d.D), 0)
            WHEN N'Month'   THEN DATEFROMPARTS(YEAR(d.D), MONTH(d.D), 1)
            WHEN N'Quarter' THEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.D), 0)
            WHEN N'Year'    THEN DATEFROMPARTS(YEAR(d.D), 1, 1)
            ELSE d.D
        END AS Bucket
    FROM data d
)
SELECT
    b.Bucket,
    FORMAT(b.Bucket, 'yyyy/MM/dd') AS Label,
    ISNULL(SUM(x.Amt), 0) AS Value1,
    COUNT(x.D) AS Value2,
    COUNT(DISTINCT x.Cust) AS Value3,
    CASE WHEN COUNT(x.D) = 0 THEN 0 ELSE ROUND(ISNULL(SUM(x.Amt), 0) / COUNT(x.D), 0) END AS Value4
FROM (SELECT DISTINCT Bucket FROM bucketed) b
LEFT JOIN bucketed x ON x.Bucket = b.Bucket
GROUP BY b.Bucket
ORDER BY b.Bucket;
