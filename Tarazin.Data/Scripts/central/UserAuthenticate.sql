-- =============================================
-- Tarazin.Data/Scripts/central/UserAuthenticate.sql
-- Schema: central
-- Query. Server-side login lookup (Blazor Server — never shipped to a client).
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
WHERE u.Username = @Username
  AND u.IsDeleted = 0;
