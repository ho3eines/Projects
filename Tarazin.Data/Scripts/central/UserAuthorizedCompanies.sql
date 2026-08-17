-- =============================================
-- Tarazin.Data/Scripts/central/UserAuthorizedCompanies.sql
-- Schema: central
-- Query. Get authorized companies for a user.
-- =============================================
DECLARE @IsAdmin BIT = 0;
IF EXISTS (SELECT 1 FROM [central].[Users] WHERE UserId = @UserId AND [Role] = N'Admin' AND IsDeleted = 0)
    SET @IsAdmin = 1;

SELECT DISTINCT
    c.CompanyId,
    c.CompanyName,
    c.IsActive
FROM [central].[Companies] c
WHERE c.IsDeleted = 0
  AND (@IsAdmin = 1 OR c.CompanyId IN (SELECT CompanyId FROM [central].[UserCompanies] WHERE UserId = @UserId))
ORDER BY c.CompanyName;
