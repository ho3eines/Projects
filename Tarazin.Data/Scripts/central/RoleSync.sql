-- =============================================
-- Tarazin.Data/Scripts/central/RoleSync.sql
-- Schema: central
-- Execute. همگام‌سازی نقش‌های پیش‌فرض از C# (idempotent).
-- @RolesJson = [ { "key":"Admin", "title":"...", "description":"...", "isSystem":true }, ... ]
--
-- نقش‌هایی که وجود ندارند ساخته می‌شوند؛ فقط مشخصات نقش‌های سیستمی (Admin)
-- از کاتالوگ به‌روز می‌شوند تا سفارشی‌سازی مدیر روی نقش‌های عادی حفظ شود.
-- =============================================
INSERT INTO [central].[Roles] (RoleKey, Title, Description, IsSystem, CreatedAt, CreatedBy)
SELECT j.[key], j.title, j.description, j.isSystem, SYSUTCDATETIME(), N'seed'
FROM OPENJSON(@RolesJson)
WITH (
    [key]        NVARCHAR(40)  '$.key',
    title        NVARCHAR(120) '$.title',
    description  NVARCHAR(300) '$.description',
    isSystem     BIT           '$.isSystem'
) j
WHERE NOT EXISTS (SELECT 1 FROM [central].[Roles] r WHERE r.RoleKey = j.[key]);

UPDATE r
SET r.Title        = j.title,
    r.Description  = j.description,
    r.IsSystem     = j.isSystem,
    r.IsDeleted    = 0,
    r.UpdatedAt    = SYSUTCDATETIME()
FROM [central].[Roles] r
JOIN OPENJSON(@RolesJson)
WITH (
    [key]        NVARCHAR(40)  '$.key',
    title        NVARCHAR(120) '$.title',
    description  NVARCHAR(300) '$.description',
    isSystem     BIT           '$.isSystem'
) j ON j.[key] = r.RoleKey
WHERE r.IsSystem = 1;
