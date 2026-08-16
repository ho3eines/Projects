-- =============================================
-- ایجاد / ویرایش گروه حساب
-- GroupType: Col | Moein | Detil
-- بازه فقط برای گروه تفصیلی مجاز و الزامی است.
-- =============================================
SET XACT_ABORT ON;

DECLARE @Type NVARCHAR(10) = LTRIM(RTRIM(ISNULL(@GroupType, N'')));
DECLARE @Code NVARCHAR(20) = LTRIM(RTRIM(ISNULL(@GroupCode, N'')));
DECLARE @Name NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@Title, N'')));
DECLARE @Nature NVARCHAR(10) = LTRIM(RTRIM(ISNULL(@DefaultNature, N'')));
DECLARE @From NVARCHAR(7) = NULLIF(LTRIM(RTRIM(@FromCode)), N'');
DECLARE @To NVARCHAR(7) = NULLIF(LTRIM(RTRIM(@ToCode)), N'');
DECLARE @CurrentType NVARCHAR(10);
DECLARE @LockResult INT;
DECLARE @LockResource NVARCHAR(255) = N'Tarazin:AccountGroups';
DECLARE @LockMode NVARCHAR(32) = N'Exclusive';
DECLARE @LockOwner NVARCHAR(32) = N'Transaction';
DECLARE @LockTimeout INT = 15000;

IF @Type NOT IN (N'Col', N'Moein', N'Detil')
    THROW 50070, N'نوع گروه حساب معتبر نیست.', 1;
IF @Code = N'' OR LEN(@Code) > 20
    THROW 50071, N'کد گروه الزامی و حداکثر ۲۰ نویسه است.', 1;
IF @Name = N'' OR LEN(@Name) > 200
    THROW 50072, N'عنوان گروه الزامی و حداکثر ۲۰۰ نویسه است.', 1;
IF @Nature NOT IN (N'Debit', N'Credit', N'Both')
    THROW 50073, N'ماهیت پیش‌فرض باید بدهکار، بستانکار یا هر دو باشد.', 1;

IF @Type = N'Detil'
BEGIN
    IF @From IS NULL OR @To IS NULL
        THROW 50074, N'شمارهٔ شروع و پایان گروه تفصیلی الزامی است.', 1;
    IF LEN(@From) <> 7 OR @From LIKE N'%[^0-9]%'
        THROW 50075, N'شمارهٔ شروع باید دقیقاً ۷ رقم باشد.', 1;
    IF LEN(@To) <> 7 OR @To LIKE N'%[^0-9]%'
        THROW 50076, N'شمارهٔ پایان باید دقیقاً ۷ رقم باشد.', 1;
    IF CONVERT(INT, @From) > CONVERT(INT, @To)
        THROW 50077, N'شمارهٔ شروع نمی‌تواند از شمارهٔ پایان بزرگ‌تر باشد.', 1;
END
ELSE
BEGIN
    SET @From = NULL;
    SET @To = NULL;
END

BEGIN TRY
    BEGIN TRANSACTION;

    -- همهٔ تغییرات گروه‌ها سریالی می‌شوند تا دو کاربر نتوانند همزمان
    -- کد تکراری یا بازه‌های تفصیلی هم‌پوشان ثبت کنند.
    EXEC @LockResult = sys.sp_getapplock
        @LockResource, @LockMode, @LockOwner, @LockTimeout;

    IF @LockResult < 0
        THROW 50084, N'ویرایش گروه‌ها هم‌اکنون توسط کاربر دیگری انجام می‌شود؛ چند لحظه بعد دوباره تلاش کنید.', 1;

    IF @AccountGroupId <> 0
    BEGIN
        SELECT @CurrentType = GroupType
        FROM [accounting].[AccountGroups] WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountGroupId = @AccountGroupId AND IsDeleted = 0;

        IF @CurrentType IS NULL
            THROW 50080, N'گروه حساب پیدا نشد یا حذف شده است.', 1;
        IF @CurrentType <> @Type
            THROW 50081, N'نوع گروه پس از ایجاد قابل تغییر نیست.', 1;
    END

    IF EXISTS (
        SELECT 1 FROM [accounting].[AccountGroups]
        WHERE GroupType = @Type AND GroupCode = @Code
          AND IsDeleted = 0 AND AccountGroupId <> @AccountGroupId)
        THROW 50078, N'کد گروه در این نوع حساب تکراری است.', 1;

    IF @Type = N'Detil' AND EXISTS (
        SELECT 1 FROM [accounting].[AccountGroups]
        WHERE GroupType = N'Detil' AND IsDeleted = 0
          AND AccountGroupId <> @AccountGroupId
          AND CONVERT(INT, FromCode) <= CONVERT(INT, @To)
          AND CONVERT(INT, ToCode) >= CONVERT(INT, @From))
        THROW 50079, N'بازهٔ این گروه با یک گروه تفصیلی دیگر هم‌پوشانی دارد.', 1;

    IF @AccountGroupId = 0
    BEGIN
        INSERT INTO [accounting].[AccountGroups]
            (GroupType, GroupCode, Title, [Description], FromCode, ToCode,
             DefaultNature, IsActive, CreatedAt, CreatedBy)
        VALUES
            (@Type, @Code, @Name, NULLIF(LTRIM(RTRIM(@Description)), N''), @From, @To,
             @Nature, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);

        SET @AccountGroupId = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        IF @Type = N'Detil' AND EXISTS (
            SELECT 1 FROM [accounting].[BaseDetil]
            WHERE AccountGroupId = @AccountGroupId AND IsDeleted = 0
              AND (CONVERT(INT, DetilCode) < CONVERT(INT, @From)
                   OR CONVERT(INT, DetilCode) > CONVERT(INT, @To)))
            THROW 50083, N'بازهٔ جدید شامل همهٔ حساب‌های تفصیلی تخصیص‌یافته به این گروه نیست.', 1;

        UPDATE [accounting].[AccountGroups]
        SET GroupCode = @Code,
            Title = @Name,
            [Description] = NULLIF(LTRIM(RTRIM(@Description)), N''),
            FromCode = @From,
            ToCode = @To,
            DefaultNature = @Nature,
            IsActive = ISNULL(@IsActive, IsActive),
            UpdatedAt = SYSUTCDATETIME(),
            UpdatedBy = @UpdatedBy
        WHERE AccountGroupId = @AccountGroupId AND IsDeleted = 0;
    END

    COMMIT TRANSACTION;

    SELECT @AccountGroupId AS NewId;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
