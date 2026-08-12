-- =============================================
-- Tarazin.Shared/Data/Scripts/inventory/StockCardReport.sql
-- Schema: inventory
-- Query. کارتکس کالا (per item).
-- =============================================
SELECT
    m.MovementId,
    m.MovementDate,
    m.MovementNumber,
    m.MovementType,
    m.Qty,
    m.UnitPrice,
    (m.Qty * m.UnitPrice) AS TotalValue,
    m.Description
FROM [inventory].[Movements] m
WHERE m.ItemId = @ItemId
  AND m.IsDeleted = 0
  AND m.MovementDate BETWEEN @FromDate AND @ToDate
ORDER BY m.MovementDate, m.MovementId;
