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
    c.CompanyName,
    fy.YearName,
    fy.StartDate,
    fy.EndDate,
    fy.IsActive,
    ISNULL(fy.[Status], N'Open') AS [Status]
FROM [central].[FiscalYears] fy
INNER JOIN [central].[Companies] c ON c.CompanyId = fy.CompanyId
WHERE fy.IsDeleted = 0
  AND fy.CompanyId = @CompanyId
  AND c.IsDeleted = 0
  AND (@IsAdmin = 1 OR fy.FiscalYearId IN (SELECT FiscalYearId FROM [central].[UserFiscalYears] WHERE UserId = @UserId))
ORDER BY fy.YearName DESC;
