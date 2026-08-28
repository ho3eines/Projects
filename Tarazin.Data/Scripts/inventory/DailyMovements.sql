-- =============================================
-- Tarazin.Data/Scripts/inventory/DailyMovements.sql
-- Schema: inventory
-- Query. Main page grid (اسناد روز انبار) — شرکت فعال + انبارک.
-- =============================================
SELECT
    m.MovementId,
    m.MovementNumber,
    m.MovementDate,
    m.MovementType,
    i.ItemCode,
    i.ItemTitle,
    ISNULL(w.Title, N'—') AS WarehouseName,
    ISNULL(sw.Title, N'') AS SubWarehouseName,
    m.Qty,
    m.UnitPrice,
    m.CostPrice,
    (m.Qty * m.CostPrice) AS TotalValue,
    m.Status,
    m.Description,
    m.CreatedAt,
    m.UpdatedAt
FROM [inventory].[Movements] m
JOIN [inventory].[Items] i ON i.ItemId = m.ItemId
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = m.WarehouseId
LEFT JOIN [inventory].[SubWarehouses] sw ON sw.SubWarehouseId = m.SubWarehouseId
WHERE m.IsDeleted = 0 AND m.CompanyId = @CompanyId
  AND m.MovementDate BETWEEN @FromDate AND @ToDate
  AND (@WarehouseId IS NULL OR m.WarehouseId = @WarehouseId)
  AND (@SubWarehouseId IS NULL OR m.SubWarehouseId = @SubWarehouseId)
  AND (@SearchText = N'' OR m.MovementNumber LIKE N'%' + @SearchText + N'%'
       OR i.ItemTitle LIKE N'%' + @SearchText + N'%'
       OR i.ItemCode LIKE N'%' + @SearchText + N'%')
  AND (@MovementType IS NULL OR m.MovementType = @MovementType)
ORDER BY m.MovementDate DESC, m.MovementId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
