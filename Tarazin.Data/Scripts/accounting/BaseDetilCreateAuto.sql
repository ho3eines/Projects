-- =============================================
-- ایجاد تفصیلی و اتصال آن به مسیر، با تخصیص خودکار و اتمیک شماره از بازهٔ گروه.
-- شماره‌های حذف‌شده دوباره استفاده نمی‌شوند تا ارجاعات تاریخی مبهم نشوند.
-- =============================================
SET XACT_ABORT ON;

DECLARE @Name NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@Title, N'')));
DECLARE @Nature NVARCHAR(10) = LTRIM(RTRIM(ISNULL(@AccountNature, N'')));
DECLARE @NormalizedParentLinkId INT = NULLIF(@ParentLinkId, 0);
DECLARE @From NVARCHAR(7);
DECLARE @To NVARCHAR(7);
DECLARE @Next NVARCHAR(7) = NULL;
DECLARE @DetilId INT;
DECLARE @ParentMoeinId INT;
DECLARE @LockResult INT;
DECLARE @LockResource NVARCHAR(255) = N'Tarazin:BaseDetilGroup:' + CONVERT(NVARCHAR(20), @AccountGroupId);

IF @Name = N''
    THROW 50140, N'عنوان حساب تفصیلی الزامی است.', 1;
IF @Nature NOT IN (N'Debit', N'Credit', N'Both')
    THROW 50141, N'ماهیت حساب باید بدهکار، بستانکار یا هر دو باشد.', 1;
IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseMoein] m INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId WHERE m.MoeinId = @MoeinId AND m.IsDeleted = 0 AND c.CompanyId = @CompanyId)
    THROW 50142, N'حساب معین انتخاب‌شده معتبر نیست یا متعلق به این شرکت نیست.', 1;

IF @NormalizedParentLinkId IS NOT NULL
BEGIN
    SELECT @ParentMoeinId = MoeinId
    FROM [accounting].[BaseDetilLink]
    WHERE LinkId = @NormalizedParentLinkId AND IsDeleted = 0 AND CompanyId = @CompanyId;

    IF @ParentMoeinId IS NULL
        THROW 50143, N'تفصیلی والد پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت نیست.', 1;
    IF @ParentMoeinId <> @MoeinId
        THROW 50144, N'تفصیلی والد به حساب معین دیگری تعلق دارد.', 1;
END

BEGIN TRY
    BEGIN TRANSACTION;

    -- یک قفل تراکنشی برای هر گروه، دو کاربر همزمان را از گرفتن یک شماره بازمی‌دارد.
    EXEC @LockResult = sys.sp_getapplock
        @LockResource, N'Exclusive', N'Transaction', 15000;

    IF @LockResult < 0
        THROW 50145, N'تخصیص شمارهٔ تفصیلی هم‌اکنون در حال انجام است؛ چند لحظه بعد دوباره تلاش کنید.', 1;

    SELECT @From = FromCode, @To = ToCode
    FROM [accounting].[AccountGroups] WITH (UPDLOCK, HOLDLOCK)
    WHERE AccountGroupId = @AccountGroupId
      AND GroupType = N'Detil'
      AND IsDeleted = 0
      AND IsActive = 1;

    IF @From IS NULL
        THROW 50146, N'گروه تفصیلی فعال و معتبر نیست.', 1;

    -- اولین حفرهٔ آزاد بازه پیدا می‌شود. ایندکس یکتای DetilCode و قفل گروه
    -- تخصیص را قطعی می‌کنند؛ رکورد حذف نرم نیز شماره را رزرو نگه می‌دارد.
    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WITH (UPDLOCK, HOLDLOCK) WHERE DetilCode = @From)
        SET @Next = @From;
    ELSE
    BEGIN
        SELECT TOP (1)
            @Next = RIGHT(N'0000000' + CONVERT(NVARCHAR(7), code.NumericCode + 1), 7)
        FROM [accounting].[BaseDetil] d WITH (UPDLOCK, HOLDLOCK)
        CROSS APPLY (VALUES (TRY_CONVERT(INT, d.DetilCode))) code(NumericCode)
        WHERE code.NumericCode >= CONVERT(INT, @From)
          AND code.NumericCode < CONVERT(INT, @To)
          AND NOT EXISTS (
              SELECT 1 FROM [accounting].[BaseDetil] nextCode WITH (UPDLOCK, HOLDLOCK)
              WHERE nextCode.DetilCode = RIGHT(N'0000000' + CONVERT(NVARCHAR(7), code.NumericCode + 1), 7)
          )
        ORDER BY code.NumericCode;
    END

    IF @Next IS NULL
        THROW 50147, N'ظرفیت بازهٔ این گروه تفصیلی تکمیل شده است.', 1;

    INSERT INTO [accounting].[BaseDetil]
        (DetilCode, Title, [Description], AccountGroupId, AccountNature,
         IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (@Next, @Name, NULLIF(LTRIM(RTRIM(@Description)), N''),
         @AccountGroupId, @Nature, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);

    SET @DetilId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO [accounting].[BaseDetilLink]
        (DetilId, MoeinId, ParentLinkId, [Description], IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (@DetilId, @MoeinId, @NormalizedParentLinkId, NULL,
         ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);

    COMMIT TRANSACTION;

    SELECT @DetilId AS NewId, @Next AS DetilCode;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
