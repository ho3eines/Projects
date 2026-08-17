-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseColUpsert.sql
-- Schema: accounting | Contract: BaseCol (حساب کل)
-- Execute.
-- قانون: ColCode دقیقاً 2 رقم، صفرهای ابتدایی حفظ می‌شود، تکراری ممنوع.
-- توجه به قرارداد @Description: مقدار NULL یعنی «تغییرش نده» و رشتهٔ خالی
-- یعنی «پاکش کن». قبلاً هر دو حالت به NULL تبدیل می‌شد، برای همین ویرایش یا
-- غیرفعال‌سازی از روی درخت (که شرح را نمی‌داند) شرح موجود را پاک می‌کرد.
-- =============================================
DECLARE @NormCode NVARCHAR(2) = RIGHT('00' + ISNULL(NULLIF(LTRIM(RTRIM(@ColCode)), ''), '00'), 2);
DECLARE @Nature NVARCHAR(10) = LTRIM(RTRIM(ISNULL(@AccountNature, N'')));
DECLARE @GroupId INT = NULLIF(@AccountGroupId, 0);

-- اعتبارسنجی: دقیقاً 2 رقم و فقط عدد.
IF @NormCode NOT LIKE '[0-9][0-9]'
    THROW 50001, N'کد حساب کل باید دقیقاً ۲ رقم باشد.', 1;

IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = N''
    THROW 50002, N'عنوان حساب کل الزامی است.', 1;

IF @Nature NOT IN (N'Debit', N'Credit', N'Both')
    THROW 50006, N'ماهیت حساب باید بدهکار، بستانکار یا هر دو باشد.', 1;

IF @GroupId IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM [accounting].[AccountGroups]
    WHERE AccountGroupId = @GroupId AND GroupType = N'Col' AND IsDeleted = 0)
    THROW 50007, N'گروه انتخاب‌شده برای حساب کل معتبر نیست.', 1;

-- بررسی تکراری نبودن کد (فقط برای رکوردهای غیرحذف‌شده در همان شرکت).
IF @ColId = 0 AND EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = @NormCode AND IsDeleted = 0 AND CompanyId = @CompanyId)
    THROW 50003, N'این کد قبلاً برای حساب کل دیگری استفاده شده است.', 1;

IF @ColId <> 0
BEGIN
    -- اگر کد تغییر کرده، تکراری نباشد در همان شرکت.
    IF EXISTS (
        SELECT 1 FROM [accounting].[BaseCol]
        WHERE ColCode = @NormCode AND IsDeleted = 0 AND ColId <> @ColId AND CompanyId = @CompanyId)
        THROW 50004, N'این کد قبلاً برای حساب کل دیگری استفاده شده است.', 1;
END

IF @ColId = 0
BEGIN
    INSERT INTO [accounting].[BaseCol]
        (ColCode, Title, [Description], AccountGroupId, AccountNature,
         IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (@NormCode, LTRIM(RTRIM(@Title)), NULLIF(LTRIM(RTRIM(@Description)), N''),
         @GroupId, @Nature, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
END
ELSE
BEGIN
    UPDATE [accounting].[BaseCol]
    SET ColCode       = @NormCode,
        Title         = LTRIM(RTRIM(@Title)),
        [Description] = CASE WHEN @Description IS NULL THEN [Description]
                             ELSE NULLIF(LTRIM(RTRIM(@Description)), N'') END,
        AccountGroupId= @GroupId,
        AccountNature = @Nature,
        IsActive      = ISNULL(@IsActive, IsActive),
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @UpdatedBy
    WHERE ColId = @ColId AND IsDeleted = 0 AND CompanyId = @CompanyId;

    IF @@ROWCOUNT = 0
        THROW 50005, N'حساب کل پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت نیست.', 1;

    SELECT @ColId AS NewId;
END
