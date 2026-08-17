-- =============================================
-- Tarazin.Data/Scripts/central/EnsureAdminAccess.sql
-- Schema: central
-- Execute. Ensure admin user has access to seeded company and fiscal year.
-- =============================================
DECLARE @AdminId INT = (SELECT TOP 1 UserId FROM [central].[Users] WHERE Username = @Username AND IsDeleted = 0);
DECLARE @CompanyId INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
DECLARE @FiscalYearId INT = (SELECT TOP 1 FiscalYearId FROM [central].[FiscalYears] WHERE IsDeleted = 0 ORDER BY FiscalYearId);

IF @AdminId IS NOT NULL AND @CompanyId IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [central].[UserCompanies] WHERE UserId = @AdminId AND CompanyId = @CompanyId)
    BEGIN
        INSERT INTO [central].[UserCompanies] (UserId, CompanyId) VALUES (@AdminId, @CompanyId);
    END

    IF @FiscalYearId IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [central].[UserFiscalYears] WHERE UserId = @AdminId AND FiscalYearId = @FiscalYearId)
        BEGIN
            INSERT INTO [central].[UserFiscalYears] (UserId, FiscalYearId) VALUES (@AdminId, @FiscalYearId);
        END

        IF NOT EXISTS (SELECT 1 FROM [central].[UserActiveContext] WHERE UserId = @AdminId)
        BEGIN
            INSERT INTO [central].[UserActiveContext] (UserId, ActiveCompanyId, ActiveFiscalYearId)
            VALUES (@AdminId, @CompanyId, @FiscalYearId);
        END
    END
END
