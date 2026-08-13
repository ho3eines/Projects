-- =============================================
-- Tarazin.Data/Scripts/central/RoleUpsert.sql
-- Schema: central
-- Execute. ایجاد/ویرایش نقش + جایگزینی دسترسی‌های آن.
--   RoleId=0 → ایجاد | RoleId>0 → ویرایش.
--   @PermissionsJson = [ "accounting.view", ... ]
-- نقش‌های سیستمی (IsSystem=1) قابل ویرایش/تغییر دسترسی نیستند.
-- =============================================
DECLARE @Rid INT;
DECLARE @IsSys BIT = 0;

IF @RoleId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [central].[Roles] WHERE RoleKey = @RoleKey AND IsDeleted = 0)
        THROW 51061, N'این کلید نقش قبلاً ثبت شده است', 1;

    INSERT INTO [central].[Roles] (RoleKey, Title, Description, IsSystem, CreatedAt, CreatedBy)
    VALUES (@RoleKey, @Title, NULLIF(@Description, N''), 0, SYSUTCDATETIME(), @CreatedBy);

    SET @Rid = SCOPE_IDENTITY();
END
ELSE
BEGIN
    UPDATE [central].[Roles]
    SET Title       = @Title,
        Description = NULLIF(@Description, N''),
        UpdatedAt   = SYSUTCDATETIME(),
        UpdatedBy   = @CreatedBy
    WHERE RoleId = @RoleId AND IsSystem = 0 AND IsDeleted = 0;

    SET @Rid = @RoleId;
    SET @IsSys = ISNULL((SELECT TOP 1 CAST(IsSystem AS BIT) FROM [central].[Roles] WHERE RoleId = @Rid), 0);
END

-- دسترسی‌ها فقط برای نقش‌های غیرسیستمی (یا نقش تازه‌ساز) جایگزین می‌شوند.
IF @Rid IS NOT NULL AND @IsSys = 0 AND @PermissionsJson IS NOT NULL
BEGIN
    DELETE FROM [central].[RolePermissions] WHERE RoleId = @Rid;

    INSERT INTO [central].[RolePermissions] (RoleId, PermissionId)
    SELECT @Rid, p.PermissionId
    FROM OPENJSON(@PermissionsJson) j
    JOIN [central].[Permissions] p ON p.PermissionKey = j.[value] AND p.IsDeleted = 0;
END
