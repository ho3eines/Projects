-- =============================================
-- Tarazin.Data/Scripts/bi/BiStockHealth.sql
-- Schema: bi
-- Cross-schema: inventory
-- Query. سلامت موجودی (§38): Healthy / Low / Zero / Dead / Negative — شمارش واقعی.
-- خروجی: ترکیب (Title=وضعیت, Value=تعداد کالا)
-- =============================================
DECLARE @DeadDays INT = ISNULL(@DeadDays, 90);

WITH items AS (
    SELECT i.ItemId, i.StockQty,
           CASE WHEN EXISTS (SELECT 1 FROM [inventory].[Movements] m
                             WHERE m.ItemId = i.ItemId AND m.MovementDate >= DATEADD(DAY, -@DeadDays, CAST(SYSDATETIME() AS DATE)))
                THEN 1 ELSE 0 END AS HasMovement
    FROM [inventory].[Items] i
    WHERE i.IsDeleted = 0
)
SELECT N'Negative' AS GroupKey, N'موجودی منفی' AS Title, ISNULL(SUM(CASE WHEN StockQty < 0 THEN 1 ELSE 0 END), 0) AS Value, 0 AS SecondaryValue
FROM items
UNION ALL
SELECT N'Zero', N'بدون موجودی', ISNULL(SUM(CASE WHEN StockQty = 0 THEN 1 ELSE 0 END), 0), 0 FROM items
UNION ALL
SELECT N'Dead', N'راکد (' + CONVERT(NVARCHAR(10), @DeadDays) + N' روز)', ISNULL(SUM(CASE WHEN HasMovement = 0 AND StockQty > 0 THEN 1 ELSE 0 END), 0), 0 FROM items
UNION ALL
SELECT N'Active', N'فعال', ISNULL(SUM(CASE WHEN HasMovement = 1 AND StockQty > 0 THEN 1 ELSE 0 END), 0), 0 FROM items;
