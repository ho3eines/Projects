-- =============================================
-- Tarazin.Data/Scripts/branch/_Seed.sql
-- Schema: branch
-- Endpoint: execute (startup)
-- فقط یک شعبهٔ پیش‌فرض «دفتر مرکزی» — مدیر شعب دیگر را اضافه می‌کند.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [branch].[Branches])
BEGIN
    INSERT INTO [branch].[Branches] (BranchCode, Title, Location, IsActive, CreatedAt)
    VALUES (N'BR-001', N'دفتر مرکزی', N'', 1, SYSUTCDATETIME());
END
