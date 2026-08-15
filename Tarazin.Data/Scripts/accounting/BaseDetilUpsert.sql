-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilUpsert.sql
-- Schema: accounting | Contract: BaseDetil (تفصیلی یکپارچه)
-- DetilCode دقیقاً 7 رقم، یکتا در کل سیستم.
-- توجه به قرارداد @Description: مقدار NULL یعنی «تغییرش نده» و رشتهٔ خالی
-- یعنی «پاکش کن». قبلاً هر دو حالت به NULL تبدیل می‌شد، برای همین ویرایش یا
-- غیرفعال‌سازی از روی درخت (که شرح را نمی‌داند) شرح موجود را پاک می‌کرد.
-- =============================================
DECLARE @NormCode NVARCHAR(7) = RIGHT('0000000' + ISNULL(NULLIF(LTRIM(RTRIM(@DetilCode)), ''), '0000000'), 7);

IF @NormCode NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
    THROW 50040, N'کد حساب تفصیلی باید دقیقاً ۷ رقم باشد.', 1;

IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = N''
    THROW 50041, N'عنوان حساب تفصیلی الزامی است.', 1;

IF @DetilId = 0 AND EXISTS (
    SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = @NormCode AND IsDeleted = 0)
    THROW 50042, N'این کد تفصیلی قبلاً ایجاد شده است. به‌جای آن از حساب موجود استفاده کنید.', 1;

-- ⚠ باگ تاریخی (رفع شد): اگر تفصیلی با همین کد قبلاً «حذف نرم» شده بود، شرط
--   بالا آن را نمی‌دید و INSERT به UNIQUE constraint روی DetilCode می‌خورد
--   (خطای 2627). نتیجه: بعد از حذف یک تفصیلی، ساختن دوبارهٔ همان کد ناممکن
--   می‌شد و کاربر آن را «سقف تعداد تفصیلی» می‌دید. حالا ردیف حذف‌شده احیا
--   می‌شود (همان رفتار BaseDetilLinkUpsert).
IF @DetilId = 0
BEGIN
    DECLARE @RevivedId INT = NULL;

    SELECT TOP (1) @RevivedId = DetilId
    FROM [accounting].[BaseDetil]
    WHERE DetilCode = @NormCode AND IsDeleted = 1
    ORDER BY DetilId;

    IF @RevivedId IS NOT NULL
    BEGIN
        UPDATE [accounting].[BaseDetil]
        SET IsDeleted     = 0,
            Title         = LTRIM(RTRIM(@Title)),
            [Description] = CASE WHEN @Description IS NULL THEN [Description]
                                 ELSE NULLIF(LTRIM(RTRIM(@Description)), N'') END,
            IsActive      = ISNULL(@IsActive, 1),
            UpdatedAt     = SYSUTCDATETIME(),
            UpdatedBy     = @CreatedBy
        WHERE DetilId = @RevivedId;

        SELECT @RevivedId AS NewId;
        RETURN;
    END
END

IF @DetilId <> 0 AND EXISTS (
    SELECT 1 FROM [accounting].[BaseDetil]
    WHERE DetilCode = @NormCode AND IsDeleted = 0 AND DetilId <> @DetilId)
    THROW 50043, N'این کد تفصیلی قبلاً ایجاد شده است.', 1;

IF @DetilId = 0
BEGIN
    INSERT INTO [accounting].[BaseDetil]
        (DetilCode, Title, [Description], IsActive, CreatedAt, CreatedBy)
    VALUES
        (@NormCode, LTRIM(RTRIM(@Title)), NULLIF(LTRIM(RTRIM(@Description)), N''),
         ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
END
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilId = @DetilId AND IsDeleted = 0)
        THROW 50044, N'حساب تفصیلی پیدا نشد یا قبلاً حذف شده است.', 1;

    UPDATE [accounting].[BaseDetil]
    SET DetilCode     = @NormCode,
        Title         = LTRIM(RTRIM(@Title)),
        [Description] = CASE WHEN @Description IS NULL THEN [Description]
                             ELSE NULLIF(LTRIM(RTRIM(@Description)), N'') END,
        IsActive      = ISNULL(@IsActive, IsActive),
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @UpdatedBy
    WHERE DetilId = @DetilId AND IsDeleted = 0;

    SELECT @DetilId AS NewId;
END
