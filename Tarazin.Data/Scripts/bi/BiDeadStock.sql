-- =============================================
-- Tarazin.Data/Scripts/bi/BiDeadStock.sql
-- Schema: bi
-- Cross-schema: inventory
-- Query. کالاهای راکد (§37): بدون فروش/حرکت در ۳۰/۶۰/۹۰/۱۸۰/۳۶۵ روز.
-- خروجی: جدول (Col1=کد, Col2=عنوان, Col3=موجودی, Col4=آخرین حرکت, Amount=ارزش)
-- =============================================
SELECT i.ItemCode AS RowKey,
       i.ItemCode AS Col1,
       i.ItemTitle AS Col2,
       FORMAT(ISNULL(i.StockQty, 0), 'N2') AS Col3,
       ISNULL((SELECT TOP 1 CONVERT(NVARCHAR(10), MovementDate, 111) FROM [inventory].[Movements] m
               WHERE m.ItemId = i.ItemId ORDER BY MovementDate DESC), N'—') AS Col4,
       CAST(ROUND(ISNULL(i.StockQty, 0) * ISNULL(i.UnitPrice, 0), 0) AS DECIMAL(18,2)) AS Amount,
       ISNULL(i.StockQty, 0) AS SecondaryAmount,
       NULL AS Date1,
       N'/inventory/reports' AS Link
FROM [inventory].[Items] i
WHERE i.IsDeleted = 0
  AND NOT EXISTS (
        SELECT 1 FROM [inventory].[Movements] m
        WHERE m.ItemId = i.ItemId AND m.MovementDate >= DATEADD(DAY, -@DeadDays, CAST(SYSDATETIME() AS DATE)))
ORDER BY Amount DESC;
