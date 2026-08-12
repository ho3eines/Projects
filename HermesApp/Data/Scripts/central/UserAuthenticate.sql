-- =============================================
-- HermesApp/Data/Scripts/central/UserAuthenticate.sql
-- Schema: central
-- Query. Server-side login lookup (Blazor Server — never shipped to a client).
-- =============================================
SELECT
    u.UserId,
    u.Username,
    u.PasswordHash,
    u.DisplayName,
    u.Role,
    u.IsActive,
    u.CreatedAt
FROM [central].[Users] u
WHERE u.Username = @Username
  AND u.IsDeleted = 0;
