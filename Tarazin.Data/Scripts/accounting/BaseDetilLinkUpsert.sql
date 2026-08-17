-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilLinkUpsert.sql
-- Schema: accounting | Contract: BaseDetilLink
--
-- هر ردیف BaseDetilLink یک «محل قرارگیری» در درخت است:
--   ParentLinkId = NULL  → تفصیلی سطح ۳، مستقیماً زیر Moein
--   ParentLinkId <> NULL → تفصیلی سطح ۴ به بعد، زیر یک تفصیلی دیگر
--
-- یک BaseDetil همچنان موجودیتی مشترک است و می‌تواند در چند مسیر/والد قرار
-- بگیرد. یکتایی idempotent بر اساس (DetilId, MoeinId, ParentLinkId) است؛ پس
-- افزودن زیر یک تفصیلی دیگر دیگر به ریشهٔ Moein برنمی‌گردد.
-- قانون چندشرکتی: هر سه طرف پیوند (معین، تفصیلی، والد سطح ۴+) باید متعلق به
-- همان شرکت باشند و CompanyId روی پیوند ثبت می‌شود (هم‌راستا با BaseDetilCreateAuto).
-- =============================================
DECLARE @NormalizedParentLinkId INT = NULLIF(@ParentLinkId, 0);
DECLARE @MoeinExists BIT = 0;
DECLARE @DetilExists BIT = 0;
DECLARE @ExistingId INT = NULL;
DECLARE @ParentMoeinId INT = NULL;

SELECT @MoeinExists = 1
FROM [accounting].[BaseMoein]
WHERE MoeinId = @MoeinId AND IsDeleted = 0 AND CompanyId = @CompanyId;

SELECT @DetilExists = 1
FROM [accounting].[BaseDetil]
WHERE DetilId = @DetilId AND IsDeleted = 0 AND CompanyId = @CompanyId;

IF @MoeinExists = 0
    THROW 50060, N'حساب معین انتخاب‌شده معتبر نیست یا متعلق به این شرکت نیست.', 1;
IF @DetilExists = 0
    THROW 50061, N'حساب تفصیلی انتخاب‌شده معتبر نیست یا متعلق به این شرکت نیست.', 1;

-- والدِ سطح ۴+ باید یک placement فعال در همان مسیر Moein و همان شرکت باشد.
IF @NormalizedParentLinkId IS NOT NULL
BEGIN
    SELECT @ParentMoeinId = MoeinId
    FROM [accounting].[BaseDetilLink]
    WHERE LinkId = @NormalizedParentLinkId AND IsDeleted = 0 AND CompanyId = @CompanyId;

    IF @ParentMoeinId IS NULL
        THROW 50062, N'تفصیلی والد پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت نیست.', 1;

    IF @ParentMoeinId <> @MoeinId
        THROW 50063, N'تفصیلی والد به حساب معین دیگری تعلق دارد.', 1;

    -- تکرار همان موجودیت در زنجیرهٔ خودش مجاز نیست. این کنترل علاوه بر جلوگیری
    -- از مسیرهای بی‌معنا، بازگشت recursive CTE را هم قطعی نگه می‌دارد.
    DECLARE @AncestorHasSameDetil BIT = 0;
    ;WITH Ancestors AS (
        SELECT LinkId, ParentLinkId, DetilId
        FROM [accounting].[BaseDetilLink]
        WHERE LinkId = @NormalizedParentLinkId AND IsDeleted = 0
        UNION ALL
        SELECT p.LinkId, p.ParentLinkId, p.DetilId
        FROM [accounting].[BaseDetilLink] p
        INNER JOIN Ancestors a ON a.ParentLinkId = p.LinkId
        WHERE p.IsDeleted = 0
    )
    SELECT TOP (1) @AncestorHasSameDetil = 1
    FROM Ancestors
    WHERE DetilId = @DetilId
    OPTION (MAXRECURSION 32767);

    IF @AncestorHasSameDetil = 1
        THROW 50064, N'یک تفصیلی نمی‌تواند زیرمجموعهٔ خودش یا یکی از والدهای همان مسیر باشد.', 1;
END

-- ۱) placement غیرحذف‌شدهٔ همین موجودیت زیر همین والد وجود دارد؟
SELECT TOP (1) @ExistingId = LinkId
FROM [accounting].[BaseDetilLink]
WHERE DetilId = @DetilId
  AND MoeinId = @MoeinId
  AND ((ParentLinkId = @NormalizedParentLinkId)
       OR (ParentLinkId IS NULL AND @NormalizedParentLinkId IS NULL))
  AND IsDeleted = 0
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

-- ۲) placement حذف‌شدهٔ همین مسیر وجود دارد؟ احیا کن.
SELECT TOP (1) @ExistingId = LinkId
FROM [accounting].[BaseDetilLink]
WHERE DetilId = @DetilId
  AND MoeinId = @MoeinId
  AND ((ParentLinkId = @NormalizedParentLinkId)
       OR (ParentLinkId IS NULL AND @NormalizedParentLinkId IS NULL))
  AND IsDeleted = 1
ORDER BY LinkId;

IF @ExistingId IS NOT NULL
BEGIN
    UPDATE [accounting].[BaseDetilLink]
    SET IsDeleted     = 0,
        IsActive      = ISNULL(@IsActive, 1),
        ParentLinkId  = @NormalizedParentLinkId,
        [Description] = NULLIF(LTRIM(RTRIM(@Description)), N''),
        CompanyId     = @CompanyId,
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @UpdatedBy
    WHERE LinkId = @ExistingId;

    SELECT @ExistingId AS NewId;
    RETURN;
END

-- ۳) placement تازه.
INSERT INTO [accounting].[BaseDetilLink]
    (DetilId, MoeinId, ParentLinkId, [Description], IsActive, CreatedAt, CreatedBy, CompanyId)
VALUES
    (@DetilId, @MoeinId, @NormalizedParentLinkId,
     NULLIF(LTRIM(RTRIM(@Description)), N''),
     ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);

SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
