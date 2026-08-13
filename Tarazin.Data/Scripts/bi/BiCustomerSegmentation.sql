-- =============================================
-- Tarazin.Data/Scripts/bi/BiCustomerSegmentation.sql
-- Schema: bi
-- Cross-schema: central, goldshop, store
-- Query. تقسیم‌بندی مشتریان (§84): VIP/Gold/Regular/New/Inactive بر اساس خرید واقعی.
-- خروجی: ترکیب (GroupKey=بخش, Title, Value=تعداد مشتری, SecondaryValue=درصد)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

WITH purchases AS (
    SELECT s.CustomerName AS Cust, COUNT(*) AS Cnt, MAX(s.InvoiceDate) AS LastBuy, MIN(s.InvoiceDate) AS FirstBuy
    FROM [goldshop].[SaleInvoices] s
    WHERE s.CustomerName IS NOT NULL AND s.CustomerName <> N''
    GROUP BY s.CustomerName
    UNION ALL
    SELECT o.CustomerName, COUNT(*), MAX(o.OrderDate), MIN(o.OrderDate)
    FROM [store].[Orders] o
    WHERE o.Status = N'Invoiced' AND o.CustomerName IS NOT NULL AND o.CustomerName <> N''
    GROUP BY o.CustomerName
),
agg AS (
    SELECT Cust, SUM(Cnt) AS Cnt, MAX(LastBuy) AS LastBuy, MIN(FirstBuy) AS FirstBuy
    FROM purchases GROUP BY Cust
),
seg AS (
    SELECT Cust, Cnt, LastBuy,
        CASE
            WHEN Cnt >= 6 THEN N'VIP'
            WHEN Cnt >= 3 THEN N'Gold'
            WHEN Cnt >= 1 THEN N'Regular'
            ELSE N'Inactive'
        END AS Segment
    FROM agg
    UNION ALL
    -- مشتریان تعریف‌شدهٔ اخیر (بدون خرید یا جدید)
    SELECT p.FullName, 0, NULL,
           CASE WHEN p.CreatedAt >= DATEADD(DAY, -30, @Today) THEN N'New' ELSE N'Inactive' END
    FROM [central].[Parties] p
    WHERE p.PartyType = N'Customer' AND p.IsDeleted = 0
      AND NOT EXISTS (SELECT 1 FROM purchases x WHERE x.Cust = p.FullName)
)
SELECT Segment AS GroupKey,
       CASE Segment WHEN N'VIP' THEN N'VIP (۶+ خرید)' WHEN N'Gold' THEN N'Gold (۳–۵)'
                    WHEN N'Regular' THEN N'Regular (۱–۲)' WHEN N'New' THEN N'جدید (۳۰ روز)'
                    ELSE N'غیرفعال' END AS Title,
       COUNT(*) AS Value,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM seg), 1) AS SecondaryValue
FROM seg
GROUP BY Segment
ORDER BY Value DESC;
