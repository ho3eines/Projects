-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilLinkUpsert.sql
-- Schema: accounting | Contract: BaseDetilLink
-- یک تفصیلی به یک معین پیوند می‌خورد.
-- اگر از قبل پیوند وجود داشت، دوباره فعال می‌شود (idempotent).
-- =============================================
DECLARE @MoeinExists BIT = 0;
DECLARE @DetilExists BIT = 0;
DECLARE @ExistingId  INT  = 0;

SELECT @MoeinExists = 1 FROM [accounting].[BaseMoein] WHERE MoeinId = @MoeinId AND IsDeleted = 0;
SELECT @DetilExists = 1 FROM [accounting].[BaseDetil] WHERE DetilId = @DetilId AND IsDeleted = 0;

IF @MoeinExists = 0
    THROW 50060, N'حساب معین انتخاب‌شده معتبر نیست.', 1;
IF @DetilExists = 0
    THROW 50061, N'حساب تفصیلی انتخاب‌شده معتبر نیست.', 1;

-- بررسی پیوند تکراری (فقط غیرحذف‌شده)
SELECT @ExistingId = LinkId
FROM [accounting].[BaseDetilLink]
WHERE DetilId = @DetilId AND MoeinId = @MoeinId AND IsDeleted = 0;

IF @ExistingId IS NOT NULL
BEGIN
    UPDATE [accounting].[BaseDetilLink]
    SET IsActive   = ISNULL(@IsActive, IsActive),
        [Description] = NULLIF(LTRIM(RTRIM(@Description)), N''),
        UpdatedAt  = SYSUTCDATETIME(),
        UpdatedBy  = @UpdatedBy
    WHERE LinkId = @ExistingId;

    SELECT @ExistingId AS NewId;
    RETURN;
END

-- اگر پیوند حذف‌شده قبلی وجود داشت، revive کنیم
SELECT @ExistingId = LinkId
FROM [accounting].[BaseDetilLink]
WHERE DetilId = @DetilId AND MoeinId = @MoeinId AND IsDeleted = 1;

IF @ExistingId IS NOT NULL
BEGIN
    UPDATE [accounting].[BaseDetilLink]
    SET IsDeleted = 0,
        IsActive  = ISNULL(@IsActive, 1),
        [Description] = NULLIF(LTRIM(RTRIM(@Description)), N''),
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @UpdatedBy
    WHERE LinkId = @ExistingId;

    SELECT @ExistingId AS NewId;
    RETURN;
END

INSERT INTO [accounting].[BaseDetilLink]
    (DetilId, MoeinId, [Description], IsActive, CreatedAt, CreatedBy)
VALUES
    (@DetilId, @MoeinId, NULLIF(LTRIM(RTRIM(@Description)), N''),
     ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);

SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
