-- =============================================
-- Tarazin.Data/Scripts/store/StoreList.sql
-- Schema: store | Cross-schema: inventory
-- Query. فهرست فروشگاه‌ها با نام انبار متصل.
-- =============================================
SELECT
    s.StoreId,
    s.CompanyId,
    s.StoreCode,
    s.Title,
    s.StoreType,
    s.WarehouseId,
    w.Title AS WarehouseTitle,
    s.ManagerName,
    s.Phone,
    s.Email,
    s.Address,
    s.WorkingHours,
    s.[Description],
    s.OnlineEnabled,
    s.IsActive,
    s.CreatedAt
FROM [store].[Stores] s
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = s.WarehouseId
WHERE s.CompanyId = @CompanyId
  AND s.IsDeleted = 0
  AND (@StoreId IS NULL OR s.StoreId = @StoreId)
  AND (@IsActive IS NULL OR s.IsActive = @IsActive)
ORDER BY s.StoreCode;
