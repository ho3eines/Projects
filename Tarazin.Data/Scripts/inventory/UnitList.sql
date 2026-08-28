-- =============================================
-- Tarazin.Data/Scripts/inventory/UnitList.sql
-- Schema: inventory
-- Query. فهرست واحدهای کالا (شرکت فعال).
-- =============================================
SELECT u.UnitId, u.UnitCode, u.Title, u.IsActive,
       u.CreatedAt, u.UpdatedAt, u.CreatedBy, u.UpdatedBy
FROM [inventory].[Units] u
WHERE u.IsDeleted = 0 AND u.CompanyId = @CompanyId
ORDER BY u.Title;
