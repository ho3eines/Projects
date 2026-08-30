-- =============================================
-- tools/fix-hossein-company-access.sql
-- Fix: hossein (UserId 2) only had access to deleted companies 1 & 2
--      and a mismatched active context (Company 3 + FY 1).
-- Grant active company 3 + its fiscal year 1405 (FY 4), fix active
-- context, and clean up stale rows pointing at deleted companies.
-- Run with: sqlcmd -I (QUOTED_IDENTIFIER ON required)
-- =============================================
SET NOCOUNT ON;

DECLARE @UserId INT = 2;              -- hossein
DECLARE @CompanyId INT = 3;           -- active company
DECLARE @FiscalYearId INT = 4;        -- 1405 of company 3 (active)
DECLARE @ActiveCompanyId INT = 3;     -- for UserActiveContextSet
DECLARE @ActiveFiscalYearId INT = 4;  -- for UserActiveContextSet
DECLARE @CreatedBy NVARCHAR(100) = N'seed-admin';

-- 1) Grant company access (idempotent) — uses the project's own script.
:r D:/Hermes/projects/Tarazin.Data/Scripts/central/CompanyAssignToUser.sql

-- 2) Grant fiscal year access (idempotent) — same grant logic as FiscalYearEnsure step 4.
IF NOT EXISTS (SELECT 1 FROM [central].[UserFiscalYears] WHERE UserId = @UserId AND FiscalYearId = @FiscalYearId)
    INSERT INTO [central].[UserFiscalYears] (UserId, FiscalYearId) VALUES (@UserId, @FiscalYearId);

-- 3) Fix active context to (Company 3, FY 4) — uses the project's own script.
:r D:/Hermes/projects/Tarazin.Data/Scripts/central/UserActiveContextSet.sql

-- 4) Clean up stale access rows for deleted companies / their fiscal years.
DELETE uc
FROM [central].[UserCompanies] uc
JOIN [central].[Companies] c ON c.CompanyId = uc.CompanyId
WHERE uc.UserId = @UserId AND c.IsDeleted = 1;

DELETE uf
FROM [central].[UserFiscalYears] uf
JOIN [central].[FiscalYears] fy ON fy.FiscalYearId = uf.FiscalYearId
JOIN [central].[Companies] c ON c.CompanyId = fy.CompanyId
WHERE uf.UserId = @UserId AND c.IsDeleted = 1;

-- 5) Report final state.
SELECT 'UserCompanies' AS What, UserId, CompanyId FROM [central].[UserCompanies] WHERE UserId = @UserId;
SELECT 'UserFiscalYears' AS What, UserId, FiscalYearId FROM [central].[UserFiscalYears] WHERE UserId = @UserId;
SELECT 'UserActiveContext' AS What, UserId, ActiveCompanyId, ActiveFiscalYearId FROM [central].[UserActiveContext] WHERE UserId = @UserId;
