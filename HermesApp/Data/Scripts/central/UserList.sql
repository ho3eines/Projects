-- =============================================
-- HermesApp/Data/Scripts/central/UserList.sql
-- Schema: central
-- Endpoint: query
-- =============================================
SELECT
    u.UserId,
    u.Username,
    u.DisplayName,
    u.Role,
    u.IsActive,
    u.CreatedAt
FROM [central].[Users] u
WHERE u.IsDeleted = 0
ORDER BY u.UserId;
