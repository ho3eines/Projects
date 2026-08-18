-- =============================================
-- Tarazin.Data/Scripts/central/AuditLastRowHash.sql
-- Schema: central
-- Query. Last hash in the tenant-local audit chain; NULL is the server-global chain.
-- Mobile callers cannot select another tenant's predecessor chain.
-- =============================================
DECLARE @ResolvedCompanyId INT = CASE
    WHEN ORIGINAL_LOGIN() LIKE N'tz_m[_]%'
        THEN [central].[fn_MobileCompanyId]()
    ELSE @CompanyId
END;

SELECT TOP 1 RowHash
FROM [central].[AuditLog]
WHERE (CompanyId = @ResolvedCompanyId)
   OR (CompanyId IS NULL AND @ResolvedCompanyId IS NULL)
ORDER BY AuditId DESC;
