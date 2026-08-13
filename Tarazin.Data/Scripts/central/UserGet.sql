-- =============================================
-- Tarazin.Data/Scripts/central/UserGet.sql
-- Schema: central
-- Query. یک کاربر با مشخصات نقش.
-- =============================================
SELECT
    u.UserId,
    u.Username,
    u.PasswordHash,
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
WHERE u.UserId = @UserId AND u.IsDeleted = 0;
