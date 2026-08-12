-- =============================================
-- webapi/Data/Scripts/inventory/StockBalanceReport.sql
-- Schema: inventory
-- Query. موجودی کالاها (با ارزش).
-- =============================================
SELECT
    i.ItemId,
    i.ItemCode,
    i.ItemTitle,
    i.Unit,
    i.StockQty,
    i.UnitPrice,
    (i.StockQty * i.UnitPrice) AS StockValue
FROM [inventory].[Items] i
WHERE i.IsDeleted = 0
ORDER BY i.ItemTitle;
