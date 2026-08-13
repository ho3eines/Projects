-- =============================================
-- Tarazin.Data/Scripts/central/RoleList.sql
-- Schema: central
-- Query. فهرست نقش‌ها + تعداد کاربران هر نقش.
-- =============================================
SELECT
    r.RoleId,
    r.RoleKey,
    r.Title,
    r.Description,
    r.IsSystem,
    r.IsDeleted,
    r.CreatedAt,
    r.UpdatedAt,
    r.CreatedBy,
    r.UpdatedBy,
    ISNULL(u.UserCount, 0) AS UserCount
FROM [central].[Roles] r
LEFT JOIN (
    SELECT RoleId, COUNT(*) AS UserCount
    FROM [central].[Users]
    WHERE IsDeleted = 0
    GROUP BY RoleId
) u ON u.RoleId = r.RoleId
WHERE r.IsDeleted = 0
ORDER BY r.IsSystem DESC, r.RoleId;
