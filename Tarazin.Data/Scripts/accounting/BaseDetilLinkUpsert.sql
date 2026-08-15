-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilLinkUpsert.sql
-- Schema: accounting | Contract: BaseDetilLink
-- یک تفصیلی به یک معین پیوند می‌خورد.
-- اگر از قبل پیوند وجود داشت، دوباره فعال می‌شود (idempotent).
--
-- ⚠ باگ تاریخی (رفع شد): @ExistingId با مقدار 0 مقداردهی اولیه شده بود و
--   شرط «IF @ExistingId IS NOT NULL» همیشه true می‌شد (چون 0 مخالف NULL است).
--   نتیجه: مسیرِ UPDATE روی LinkId=0 اجرا و سپس RETURN می‌شد، و دستور INSERT
--   انتهای اسکریپت هرگز اجرا نمی‌شد — یعنی «افزودن گره تفصیلی» بی‌صدا شکست
--   می‌خورد (۰ ردیف، بدون خطا). حالا با NULL مقداردهی می‌شود.
-- =============================================
DECLARE @MoeinExists BIT = 0;
DECLARE @DetilExists BIT = 0;
DECLARE @ExistingId  INT = NULL;   -- NULL یعنی «پیوندی پیدا نشد» (نه 0)

SELECT @MoeinExists = 1 FROM [accounting].[BaseMoein] WHERE MoeinId = @MoeinId AND IsDeleted = 0;
SELECT @DetilExists = 1 FROM [accounting].[BaseDetil] WHERE DetilId = @DetilId AND IsDeleted = 0;

IF @MoeinExists = 0
    THROW 50060, N'حساب معین انتخاب‌شده معتبر نیست.', 1;
IF @DetilExists = 0
    THROW 50061, N'حساب تفصیلی انتخاب‌شده معتبر نیست.', 1;

-- ۱) پیوند فعال (غیرحذف‌شده) از قبل هست؟ → فقط به‌روزرسانی.
SELECT TOP (1) @ExistingId = LinkId
FROM [accounting].[BaseDetilLink]
WHERE DetilId = @DetilId AND MoeinId = @MoeinId AND IsDeleted = 0
ORDER BY LinkId;

IF @ExistingId IS NOT NULL
BEGIN
    UPDATE [accounting].[BaseDetilLink]
    SET IsActive      = ISNULL(@IsActive, IsActive),
        [Description] = NULLIF(LTRIM(RTRIM(@Description)), N''),
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @UpdatedBy
    WHERE LinkId = @ExistingId;

    SELECT @ExistingId AS NewId;
    RETURN;
END

-- ۲) پیوند حذف‌شدهٔ قبلی هست؟ → احیا (revive) به‌جای INSERT تکراری.
SELECT TOP (1) @ExistingId = LinkId
FROM [accounting].[BaseDetilLink]
WHERE DetilId = @DetilId AND MoeinId = @MoeinId AND IsDeleted = 1
ORDER BY LinkId;

IF @ExistingId IS NOT NULL
BEGIN
    UPDATE [accounting].[BaseDetilLink]
    SET IsDeleted     = 0,
        IsActive      = ISNULL(@IsActive, 1),
        [Description] = NULLIF(LTRIM(RTRIM(@Description)), N''),
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @UpdatedBy
    WHERE LinkId = @ExistingId;

    SELECT @ExistingId AS NewId;
    RETURN;
END

-- ۳) پیوند تازه.
INSERT INTO [accounting].[BaseDetilLink]
    (DetilId, MoeinId, [Description], IsActive, CreatedAt, CreatedBy)
VALUES
    (@DetilId, @MoeinId, NULLIF(LTRIM(RTRIM(@Description)), N''),
     ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);

SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
