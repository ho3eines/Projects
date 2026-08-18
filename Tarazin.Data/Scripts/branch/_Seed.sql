-- =============================================
-- Tarazin.Data/Scripts/branch/_Seed.sql
-- Schema: branch
-- Endpoint: execute (startup)
-- فقط یک شعبهٔ پیش‌فرض «دفتر مرکزی» — مدیر شعب دیگر را اضافه می‌کند.
-- =============================================
-- Multi-Company seed: use first company for default data
DECLARE @SeedCompanyId INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
IF @SeedCompanyId IS NULL
BEGIN
    -- No company yet — central seed will create it; this seed will run again on next startup
    RETURN;
END


IF NOT EXISTS (SELECT 1 FROM [branch].[Branches] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [branch].[Branches] (BranchCode, Title, Location, IsActive, CreatedAt, CompanyId)
    VALUES (N'BR-001', N'دفتر مرکزی', N'', 1, SYSUTCDATETIME(), @SeedCompanyId);
END