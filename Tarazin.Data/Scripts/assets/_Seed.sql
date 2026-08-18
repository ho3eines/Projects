-- Cross-schema: central
-- Multi-Company seed: use first company for default data
DECLARE @SeedCompanyId INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
IF @SeedCompanyId IS NULL
BEGIN
    -- No company yet — central seed will create it; this seed will run again on next startup
    RETURN;
END


-- =============================================
-- Tarazin.Data/Scripts/assets/_Seed.sql
-- Schema: assets
-- Endpoint: execute (startup)
-- عمداً خالی: اموال ثابت توسط مدیر ثبت می‌شود (هیچ دادهٔ نمایشی/ساختگی).
-- =============================================