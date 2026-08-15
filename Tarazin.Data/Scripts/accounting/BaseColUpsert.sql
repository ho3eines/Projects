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

-- اعتبارسنجی: دقیقاً 2 رقم و فقط عدد.
IF @NormCode NOT LIKE '[0-9][0-9]'
    THROW 50001, N'کد حساب کل باید دقیقاً ۲ رقم باشد.', 1;

IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = N''
    THROW 50002, N'عنوان حساب کل الزامی است.', 1;

-- بررسی تکراری نبودن کد (فقط برای رکوردهای غیرحذف‌شده).
IF @ColId = 0 AND EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = @NormCode AND IsDeleted = 0)
    THROW 50003, N'این کد قبلاً برای حساب کل دیگری استفاده شده است.', 1;

IF @ColId <> 0
BEGIN
    -- اگر کد تغییر کرده، تکراری نباشد.
    IF EXISTS (
        SELECT 1 FROM [accounting].[BaseCol]
        WHERE ColCode = @NormCode AND IsDeleted = 0 AND ColId <> @ColId)
        THROW 50004, N'این کد قبلاً برای حساب کل دیگری استفاده شده است.', 1;
END

IF @ColId = 0
BEGIN
    INSERT INTO [accounting].[BaseCol]
        (ColCode, Title, [Description], IsActive, CreatedAt, CreatedBy)
    VALUES
        (@NormCode, LTRIM(RTRIM(@Title)), NULLIF(LTRIM(RTRIM(@Description)), N''),
         ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
END
ELSE
BEGIN
    UPDATE [accounting].[BaseCol]
    SET ColCode       = @NormCode,
        Title         = LTRIM(RTRIM(@Title)),
        [Description] = CASE WHEN @Description IS NULL THEN [Description]
                             ELSE NULLIF(LTRIM(RTRIM(@Description)), N'') END,
        IsActive      = ISNULL(@IsActive, IsActive),
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @UpdatedBy
    WHERE ColId = @ColId AND IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 50005, N'حساب کل پیدا نشد یا قبلاً حذف شده است.', 1;

    SELECT @ColId AS NewId;
END
