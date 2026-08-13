-- =============================================
-- Tarazin.Data/Scripts/central/PermissionSync.sql
-- Schema: central
-- Execute. همگام‌سازی کاتالوگ دسترسی‌ها از C# (idempotent).
-- @PermissionsJson = [ { "key":"accounting.view", "title":"...", "module":"accounting" }, ... ]
-- =============================================
MERGE [central].[Permissions] AS t
USING (
    SELECT j.[key] AS PermissionKey, j.title AS Title, j.module AS ModuleKey
    FROM OPENJSON(@PermissionsJson)
    WITH (
        [key]   NVARCHAR(80)  '$.key',
        title   NVARCHAR(160) '$.title',
        module  NVARCHAR(50)  '$.module'
    ) j
) AS s ON t.PermissionKey = s.PermissionKey
WHEN MATCHED THEN
    UPDATE SET Title = s.Title, ModuleKey = s.ModuleKey,
               IsDeleted = 0, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (PermissionKey, Title, ModuleKey, CreatedAt)
    VALUES (s.PermissionKey, s.Title, s.ModuleKey, SYSUTCDATETIME());
