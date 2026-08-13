-- =============================================
-- Tarazin.Data/Scripts/assets/FixedAssetDelete.sql
-- Schema: assets
-- Execute. حذف منطقی دارایی ثابت.
-- =============================================
UPDATE [assets].[FixedAssets]
SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
WHERE AssetId = @AssetId;
