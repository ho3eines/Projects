-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemUnitsList.sql
-- Schema: inventory
-- Query. واحدهای چندگانهٔ یک کالا با ضریب تبدیل (Factor) به واحد پایه.
-- =============================================
SELECT iu.ItemUnitId, iu.ItemId, iu.UnitId, iu.Factor, iu.IsDefault,
       u.Title AS UnitTitle, u.UnitCode,
       iu.CreatedAt, iu.UpdatedAt
FROM [inventory].[ItemUnits] iu
JOIN [inventory].[Units] u ON u.UnitId = iu.UnitId AND u.IsDeleted = 0
WHERE iu.ItemId = @ItemId AND iu.IsDeleted = 0
ORDER BY CASE WHEN iu.IsDefault = 1 THEN 0 ELSE 1 END, u.Title;