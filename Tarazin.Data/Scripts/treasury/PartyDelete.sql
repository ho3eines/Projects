-- =============================================
-- Tarazin.Data/Scripts/treasury/PartyDelete.sql
-- Schema: treasury | Cross-schema: central
-- Execute. حذف نرم طرف حساب یکپارچه + حذف لینک حسابداری.
-- =============================================
DELETE FROM [treasury].[PartyLinks] WHERE CompanyId = @CompanyId AND PartyId = @PartyId;
UPDATE [central].[Parties]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
WHERE PartyId = @PartyId AND CompanyId = @CompanyId AND IsDeleted = 0;
