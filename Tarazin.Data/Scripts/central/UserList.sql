-- =============================================
-- Tarazin.Data/Scripts/central/UserList.sql
-- Schema: central
-- Endpoint: query
-- =============================================
SELECT
    u.UserId,
    u.Username,
    u.DisplayName,
    u.Role,
    u.RoleId,
    r.Title AS RoleTitle,
    u.IsActive,
    u.CreatedAt,
    u.UpdatedAt,
    u.CreatedBy,
    u.UpdatedBy
FROM [central].[Users] u
LEFT JOIN [central].[Roles] r ON r.RoleId = u.RoleId AND r.IsDeleted = 0
WHERE u.IsDeleted = 0
ORDER BY u.UserId;
