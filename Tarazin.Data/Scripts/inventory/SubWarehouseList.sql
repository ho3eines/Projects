-- =============================================
-- Tarazin.Data/Scripts/inventory/SubWarehouseList.sql
-- Schema: inventory
-- Query. فهرست انبارک‌ها (شرکت فعال؛ اختیاراً برای یک انبار).
-- =============================================
SELECT s.SubWarehouseId, s.WarehouseId, w.Title AS WarehouseTitle,
       s.SubWarehouseCode, s.Title, s.Location, s.IsActive,
       s.CreatedAt, s.UpdatedAt, s.CreatedBy, s.UpdatedBy
FROM [inventory].[SubWarehouses] s
JOIN [inventory].[Warehouses] w ON w.WarehouseId = s.WarehouseId
WHERE s.IsDeleted = 0 AND s.CompanyId = @CompanyId
  AND (@WarehouseId IS NULL OR s.WarehouseId = @WarehouseId)
ORDER BY w.Title, s.Title;
