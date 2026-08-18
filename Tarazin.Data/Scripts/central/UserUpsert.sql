-- =============================================
-- Tarazin.Data/Scripts/central/UserUpsert.sql
-- Schema: central
-- Execute. ایجاد/ویرایش کاربر. UserId=0 → insert.
-- PasswordHash always comes from server-side PasswordHasher (PBKDF2).
-- RoleId از روی کلید نقش (@Role) حل می‌شود تا RBAC همیشه همگام بماند.
-- =============================================
IF @UserId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [central].[Users] WHERE Username = @Username AND IsDeleted = 0)
        THROW 51050, N'این نام کاربری قبلاً ثبت شده است', 1;

    DECLARE @NewRoleId INT = COALESCE(
        (SELECT RoleId FROM [central].[Roles] WHERE RoleKey = @Role AND IsDeleted = 0),
        (SELECT RoleId FROM [central].[Roles] WHERE RoleKey = N'User' AND IsDeleted = 0),
        (SELECT TOP 1 RoleId FROM [central].[Roles] WHERE IsDeleted = 0 ORDER BY IsSystem DESC, RoleId));

    INSERT INTO [central].[Users] (Username, PasswordHash, DisplayName, Role, RoleId, IsActive, CreatedAt, CreatedBy)
    VALUES (@Username, @PasswordHash, @DisplayName, @Role, @NewRoleId, @IsActive, SYSUTCDATETIME(), @CreatedBy);

    -- A generated mobile administrator is bound to exactly one broker company.
    -- The explicit principal check is intentional: fn_MobileCompanyId also
    -- serves trusted Web/bootstrap table defaults and may return Web context or
    -- the legacy fallback company. Those callers retain their existing explicit
    -- UserCompanies assignment workflow.
    DECLARE @MobileCompanyId INT = [central].[fn_MobileCompanyId]();
    IF LEFT(USER_NAME(), 5) = N'tz_m_' AND @MobileCompanyId IS NOT NULL
        INSERT INTO [central].[UserCompanies] (UserId, CompanyId)
        VALUES (CONVERT(INT, SCOPE_IDENTITY()), @MobileCompanyId);
END
ELSE
BEGIN
    UPDATE [central].[Users]
    SET DisplayName = ISNULL(@DisplayName, DisplayName),
        Role        = ISNULL(@Role, Role),
        RoleId      = ISNULL(
                          (SELECT RoleId FROM [central].[Roles]
                           WHERE RoleKey = ISNULL(@Role, Role) AND IsDeleted = 0),
                          RoleId),
        IsActive    = ISNULL(@IsActive, IsActive),
        PasswordHash = CASE WHEN @PasswordHash = N'' THEN PasswordHash ELSE @PasswordHash END,
        UpdatedAt   = SYSUTCDATETIME(),
        UpdatedBy   = @CreatedBy
    WHERE UserId = @UserId;
END
