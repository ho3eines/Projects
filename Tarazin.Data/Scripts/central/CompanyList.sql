-- =============================================
-- Tarazin.Data/Scripts/central/CompanyList.sql
-- Schema: central
-- Query. Get all companies.
-- =============================================
SELECT 
    CompanyId,
    CompanyName,
    IsActive,
    CreatedAt,
    UpdatedAt,
    CreatedBy,
    UpdatedBy
FROM [central].[Companies]
WHERE IsDeleted = 0
ORDER BY CompanyId;
