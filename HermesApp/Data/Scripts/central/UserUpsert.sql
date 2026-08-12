-- =============================================
-- HermesApp/Data/Scripts/central/UserUpsert.sql
-- Schema: central
-- Execute. ایجاد/ویرایش کاربر. UserId=0 → insert.
-- PasswordHash always comes from server-side PasswordHasher (PBKDF2).
-- =============================================
IF @UserId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [central].[Users] WHERE Username = @Username AND IsDeleted = 0)
        THROW 51050, N'این نام کاربری قبلاً ثبت شده است', 1;

    INSERT INTO [central].[Users] (Username, PasswordHash, DisplayName, Role, IsActive, CreatedAt, CreatedBy)
    VALUES (@Username, @PasswordHash, @DisplayName, @Role, @IsActive, SYSUTCDATETIME(), @CreatedBy);
END
ELSE
BEGIN
    UPDATE [central].[Users]
    SET DisplayName = ISNULL(@DisplayName, DisplayName),
        Role        = ISNULL(@Role, Role),
        IsActive    = ISNULL(@IsActive, IsActive),
        PasswordHash = CASE WHEN @PasswordHash = N'' THEN PasswordHash ELSE @PasswordHash END,
        UpdatedAt   = SYSUTCDATETIME(),
        UpdatedBy   = @CreatedBy
    WHERE UserId = @UserId;
END
