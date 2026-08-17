-- =============================================
-- Tarazin.Data/Scripts/central/UserAuthorizedFiscalYears.sql
-- Schema: central
-- Query. Get authorized fiscal years for a user and a company.
-- =============================================
DECLARE @IsAdmin BIT = 0;
IF EXISTS (SELECT 1 FROM [central].[Users] WHERE UserId = @UserId AND [Role] = N'Admin' AND IsDeleted = 0)
    SET @IsAdmin = 1;

SELECT DISTINCT
    fy.FiscalYearId,
    fy.CompanyId,
    fy.YearName,
    fy.StartDate,
    fy.EndDate,
    fy.IsActive
FROM [central].[FiscalYears] fy
WHERE fy.IsDeleted = 0
  AND fy.CompanyId = @CompanyId
  AND (@IsAdmin = 1 OR fy.FiscalYearId IN (SELECT FiscalYearId FROM [central].[UserFiscalYears] WHERE UserId = @UserId))
ORDER BY fy.YearName DESC;
