-- =============================================
-- Tarazin.Data/Scripts/inventory/DailyMovements.sql
-- Schema: inventory
-- Query. Main page grid (اسناد روز انبار) — شرکت فعال + انبارک.
-- مبدأ هر حرکت از SourceReference استخراج می‌شود (شمارهٔ مشترک بین ماژول‌ها):
--   StoreOrder:{id} → فروشگاه | PINV:{id} → فاکتور خرید | SINV:{id} → فاکتور فروش
--   RET:{id} → برگشت | Transfer:{id} → انتقال | Stocktake/Manual → بدون شناسه
-- فیلتر @SourceType با همان پیشوند (یا مقدار خام برای Stocktake/Manual) کار می‌کند.
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
    m.SourceReference,
    src.SourceType,
    src.SourceId,
    m.CreatedAt,
    m.UpdatedAt
FROM [inventory].[Movements] m
JOIN [inventory].[Items] i ON i.ItemId = m.ItemId
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = m.WarehouseId
LEFT JOIN [inventory].[SubWarehouses] sw ON sw.SubWarehouseId = m.SubWarehouseId
CROSS APPLY (
    SELECT CASE WHEN CHARINDEX(N':', m.SourceReference) > 0
                THEN LEFT(m.SourceReference, CHARINDEX(N':', m.SourceReference) - 1)
                ELSE m.SourceReference END AS SourceType,
           CASE WHEN CHARINDEX(N':', m.SourceReference) > 0
                THEN TRY_CONVERT(BIGINT, SUBSTRING(m.SourceReference, CHARINDEX(N':', m.SourceReference) + 1, 400))
                ELSE NULL END AS SourceId
) src
WHERE m.IsDeleted = 0 AND m.CompanyId = @CompanyId
  AND m.MovementDate BETWEEN @FromDate AND @ToDate
  AND (@WarehouseId IS NULL OR m.WarehouseId = @WarehouseId)
  AND (@SubWarehouseId IS NULL OR m.SubWarehouseId = @SubWarehouseId)
  AND (@SearchText = N'' OR m.MovementNumber LIKE N'%' + @SearchText + N'%'
       OR i.ItemTitle LIKE N'%' + @SearchText + N'%'
       OR i.ItemCode LIKE N'%' + @SearchText + N'%')
  AND (@MovementType IS NULL OR m.MovementType = @MovementType)
  AND (@SourceType IS NULL OR @SourceType = N'' OR src.SourceType = @SourceType)
ORDER BY m.MovementDate DESC, m.MovementId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;