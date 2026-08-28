-- =============================================
-- Cross-schema: central
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


-- BranchCode is a GLOBAL unique key, so guard on the code itself, not just
-- the company. Deleted companies can leave orphan BR-001 rows behind; the
-- global check keeps the seed idempotent across restarts.
IF NOT EXISTS (SELECT 1 FROM [branch].[Branches] WHERE BranchCode = N'BR-001')
   AND NOT EXISTS (SELECT 1 FROM [branch].[Branches] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [branch].[Branches] (BranchCode, Title, Location, IsActive, CreatedAt, CompanyId)
    VALUES (N'BR-001', N'دفتر مرکزی', N'', 1, SYSUTCDATETIME(), @SeedCompanyId);
END