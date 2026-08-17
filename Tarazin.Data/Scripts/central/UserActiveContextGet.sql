-- =============================================
-- Tarazin.Data/Scripts/central/UserActiveContextGet.sql
-- Schema: central
-- Query. Get active company and fiscal year for a user.
-- =============================================
SELECT
    uac.ActiveCompanyId,
    c.CompanyName AS ActiveCompanyName,
    uac.ActiveFiscalYearId,
    fy.YearName AS ActiveFiscalYearName,
    ISNULL(fy.[Status], N'Open') AS ActiveFiscalYearStatus
FROM [central].[UserActiveContext] uac
LEFT JOIN [central].[Companies] c ON c.CompanyId = uac.ActiveCompanyId AND c.IsDeleted = 0
LEFT JOIN [central].[FiscalYears] fy ON fy.FiscalYearId = uac.ActiveFiscalYearId AND fy.IsDeleted = 0
WHERE uac.UserId = @UserId;
