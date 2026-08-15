-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseMoeinUpsert.sql
-- Schema: accounting | Contract: BaseMoein (حساب معین)
-- قانون: MoeinCode دقیقاً 3 رقم، تکراری در ColId ممنوع.
-- AccountCode = ColCode + MoeinCode (5 رقم) به‌صورت خودکار.
-- توجه به قرارداد @Description: مقدار NULL یعنی «تغییرش نده» و رشتهٔ خالی
-- یعنی «پاکش کن». قبلاً هر دو حالت به NULL تبدیل می‌شد، برای همین ویرایش یا
-- غیرفعال‌سازی از روی درخت (که شرح را نمی‌داند) شرح موجود را پاک می‌کرد.
-- =============================================
DECLARE @NormCode NVARCHAR(3) = RIGHT('000' + ISNULL(NULLIF(LTRIM(RTRIM(@MoeinCode)), ''), '000'), 3);
DECLARE @ColCode  NVARCHAR(2);

-- اعتبارسنجی کد
IF @NormCode NOT LIKE '[0-9][0-9][0-9]'
    THROW 50020, N'کد حساب معین باید دقیقاً ۳ رقم باشد.', 1;

IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = N''
    THROW 50021, N'عنوان حساب معین الزامی است.', 1;

-- والد باید وجود داشته باشد و فعال باشد
SELECT @ColCode = ColCode
FROM [accounting].[BaseCol]
WHERE ColId = @ColId AND IsDeleted = 0;

IF @ColCode IS NULL
    THROW 50022, N'حساب کل والد معتبر نیست یا حذف شده است.', 1;

-- تکراری نبودن کد در همان ColId
IF @MoeinId = 0 AND EXISTS (
    SELECT 1 FROM [accounting].[BaseMoein]
    WHERE ColId = @ColId AND MoeinCode = @NormCode AND IsDeleted = 0)
    THROW 50023, N'این کد معین قبلاً در همین حساب کل استفاده شده است.', 1;

IF @MoeinId <> 0
BEGIN
    -- اگر در حال ویرایش، ColId یا MoeinCode تغییر کرده، تکراری نباشد.
    IF EXISTS (
        SELECT 1 FROM [accounting].[BaseMoein]
        WHERE ColId = @ColId AND MoeinCode = @NormCode AND IsDeleted = 0 AND MoeinId <> @MoeinId)
        THROW 50024, N'این کد معین قبلاً در همین حساب کل استفاده شده است.', 1;
END

IF @MoeinId = 0
BEGIN
    INSERT INTO [accounting].[BaseMoein]
        (ColId, MoeinCode, Title, [Description], IsActive, CreatedAt, CreatedBy)
    VALUES
        (@ColId, @NormCode, LTRIM(RTRIM(@Title)), NULLIF(LTRIM(RTRIM(@Description)), N''),
         ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
END
ELSE
BEGIN
    -- بررسی تغییر ColId: والد جدید نباید دارای فرزند تکراری باشد.
    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseMoein] WHERE MoeinId = @MoeinId AND IsDeleted = 0)
        THROW 50025, N'حساب معین پیدا نشد یا قبلاً حذف شده است.', 1;

    UPDATE [accounting].[BaseMoein]
    SET ColId        = @ColId,
        MoeinCode    = @NormCode,
        Title        = LTRIM(RTRIM(@Title)),
        [Description]= CASE WHEN @Description IS NULL THEN [Description]
                            ELSE NULLIF(LTRIM(RTRIM(@Description)), N'') END,
        IsActive     = ISNULL(@IsActive, IsActive),
        UpdatedAt    = SYSUTCDATETIME(),
        UpdatedBy    = @UpdatedBy
    WHERE MoeinId = @MoeinId AND IsDeleted = 0;

    SELECT @MoeinId AS NewId;
END
