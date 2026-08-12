-- =============================================
-- TarazinApp/Data/Scripts/inventory/DailyMovements.sql
-- Schema: inventory
-- Query. Main page grid (اسناد روز انبار).
-- =============================================
SELECT
    m.MovementId,
    m.MovementNumber,
    m.MovementDate,
    m.MovementType,
    i.ItemCode,
    i.ItemTitle,
    ISNULL(w.Title, N'—') AS WarehouseName,
    m.Qty,
    m.UnitPrice,
    (m.Qty * m.UnitPrice) AS TotalValue,
    m.Status,
    m.Description
FROM [inventory].[Movements] m
JOIN [inventory].[Items] i ON i.ItemId = m.ItemId
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = m.WarehouseId
WHERE m.IsDeleted = 0
  AND m.MovementDate BETWEEN @FromDate AND @ToDate
  AND (@SearchText = N'' OR m.MovementNumber LIKE N'%' + @SearchText + N'%'
       OR i.ItemTitle LIKE N'%' + @SearchText + N'%'
       OR i.ItemCode LIKE N'%' + @SearchText + N'%')
  AND (@MovementType IS NULL OR m.MovementType = @MovementType)
ORDER BY m.MovementDate DESC, m.MovementId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
