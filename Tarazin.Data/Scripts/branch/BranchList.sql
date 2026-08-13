-- =============================================
-- Tarazin.Data/Scripts/branch/BranchList.sql
-- Schema: branch
-- Query. فهرست شعب.
-- =============================================
SELECT b.BranchId, b.BranchCode, b.Title, b.Location, b.Manager, b.IsActive, b.IsDeleted,
       b.CreatedAt, b.UpdatedAt, b.CreatedBy, b.UpdatedBy
FROM [branch].[Branches] b
WHERE b.IsDeleted = 0
  AND (@OnlyActive = 0 OR b.IsActive = 1)
ORDER BY b.BranchCode;
