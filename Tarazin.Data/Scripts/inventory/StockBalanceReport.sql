-- =============================================
-- Tarazin.Data/Scripts/inventory/StockBalanceReport.sql
-- Schema: inventory
-- Query. موجودی کالاها به تفکیک انبار/انبارک با ارزش (از لایه‌های موجودی).
-- =============================================
SELECT
    i.ItemId,
    i.ItemCode,
    i.ItemTitle,
    ISNULL(u.Title, i.Unit) AS Unit,
    w.WarehouseId,
    w.Title AS WarehouseName,
    sw.SubWarehouseId,
    sw.Title AS SubWarehouseName,
    ISNULL(l.QtyRemaining, 0) AS StockQty,
    CASE WHEN ISNULL(l.QtyRemaining, 0) <> 0
         THEN ROUND(ISNULL(l.StockValue, 0) / l.QtyRemaining, 2)
         ELSE 0 END AS UnitPrice,
    ISNULL(l.StockValue, 0) AS StockValue
FROM [inventory].[Items] i
LEFT JOIN [inventory].[Units] u ON u.UnitId = i.UnitId
LEFT JOIN (
    SELECT ItemId, WarehouseId, SubWarehouseId,
           SUM(QtyRemaining) AS QtyRemaining,
           SUM(QtyRemaining * UnitCost) AS StockValue
    FROM [inventory].[StockLayers]
    WHERE CompanyId = @CompanyId
    GROUP BY ItemId, WarehouseId, SubWarehouseId
) l ON l.ItemId = i.ItemId
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = l.WarehouseId
LEFT JOIN [inventory].[SubWarehouses] sw ON sw.SubWarehouseId = l.SubWarehouseId
WHERE i.IsDeleted = 0 AND i.CompanyId = @CompanyId
  AND (@WarehouseId IS NULL OR l.WarehouseId = @WarehouseId)
  AND (@SubWarehouseId IS NULL OR l.SubWarehouseId = @SubWarehouseId)
  AND (@OnlyNonZero = 0 OR ISNULL(l.QtyRemaining, 0) <> 0)
ORDER BY i.ItemTitle, w.Title, sw.Title;
