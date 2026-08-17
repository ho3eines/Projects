-- =============================================
-- Tarazin.Data/Scripts/central/FiscalYearList.sql
-- Schema: central
-- Query. Get all fiscal years for a company.
-- =============================================
SELECT 
    fy.FiscalYearId,
    fy.CompanyId,
    c.CompanyName,
    fy.YearName,
    fy.StartDate,
    fy.EndDate,
    fy.IsActive,
    fy.CreatedAt,
    fy.UpdatedAt,
    fy.CreatedBy,
    fy.UpdatedBy
FROM [central].[FiscalYears] fy
INNER JOIN [central].[Companies] c ON c.CompanyId = fy.CompanyId AND c.IsDeleted = 0
WHERE fy.IsDeleted = 0 AND fy.CompanyId = @CompanyId
ORDER BY fy.YearName DESC;
