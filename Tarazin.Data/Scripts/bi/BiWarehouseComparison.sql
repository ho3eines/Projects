-- =============================================
-- Tarazin.Data/Scripts/bi/BiWarehouseComparison.sql
-- Schema: bi
-- Cross-schema: inventory
-- Query. مقایسه انبارها (§39): ورود/خروج/گردش/تعداد کالا از حرکات واقعی.
-- خروجی: جدول (Col1=انبار, Col2=ورود, Col3=خروج, Col4=تعداد کالا, Amount=گردش کل تعداد)
-- =============================================
DECLARE @From DATE = ISNULL(@FromDate, DATEADD(MONTH, -1, CAST(SYSDATETIME() AS DATE)));
DECLARE @To DATE = ISNULL(@ToDate, CAST(SYSDATETIME() AS DATE));

SELECT w.WarehouseCode AS RowKey,
       w.Title AS Col1,
       FORMAT(ISNULL(SUM(CASE WHEN m.MovementType = N'Receipt' THEN m.Qty ELSE 0 END), 0), 'N0') AS Col2,
       FORMAT(ISNULL(SUM(CASE WHEN m.MovementType = N'Issue' THEN m.Qty ELSE 0 END), 0), 'N0') AS Col3,
       FORMAT(COUNT(DISTINCT m.ItemId), 'N0') AS Col4,
       CAST(ISNULL(SUM(CASE WHEN m.MovementType = N'Receipt' THEN m.Qty ELSE -m.Qty END), 0) AS DECIMAL(18,2)) AS Amount,
       ISNULL(SUM(CASE WHEN m.MovementType = N'Receipt' THEN m.Qty ELSE -m.Qty END), 0) AS SecondaryAmount,
       MAX(m.MovementDate) AS Date1,
       N'/inventory' AS Link
FROM [inventory].[Warehouses] w
LEFT JOIN [inventory].[Movements] m ON m.WarehouseId = w.WarehouseId
   AND m.IsDeleted = 0 AND m.MovementDate BETWEEN @From AND @To
WHERE w.IsDeleted = 0
GROUP BY w.WarehouseCode, w.Title
ORDER BY w.Title;
