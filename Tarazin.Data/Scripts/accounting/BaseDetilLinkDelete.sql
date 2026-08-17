-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilLinkDelete.sql
-- Schema: accounting | Contract: BaseDetilLink
-- حذف یک placement تفصیلی. گره دارای زیرسطح باید از پایین به بالا حذف شود.
-- =============================================
DECLARE @AccountCode NVARCHAR(4000) = NULL;
DECLARE @Exists BIT = 0;
DECLARE @ResolvedMoeinId INT = NULL;
DECLARE @DetailCodePath NVARCHAR(MAX) = NULL;

-- مسیر دقیق همیشه با LinkId تشخیص داده می‌شود (فقط در شرکت جاری).
SELECT
    @Exists = 1,
    @ResolvedMoeinId = dl.MoeinId
FROM [accounting].[BaseDetilLink] dl
WHERE dl.LinkId = @LinkId AND dl.IsDeleted = 0 AND dl.CompanyId = @CompanyId;

-- سازگاری با فراخوان‌های قدیمیِ بدون LinkId؛ ریشهٔ سطح ۳ اولویت دارد.
IF @Exists = 0 AND ISNULL(@DetilId, 0) <> 0 AND ISNULL(@MoeinId, 0) <> 0
BEGIN
    SELECT TOP (1)
        @Exists = 1,
        @LinkId = dl.LinkId,
        @ResolvedMoeinId = dl.MoeinId
    FROM [accounting].[BaseDetilLink] dl
    WHERE dl.DetilId = @DetilId
      AND dl.MoeinId = @MoeinId
      AND dl.IsDeleted = 0
      AND dl.CompanyId = @CompanyId
    ORDER BY CASE WHEN dl.ParentLinkId IS NULL THEN 0 ELSE 1 END, dl.LinkId;
END

IF @Exists = 0
    THROW 50070, N'محل قرارگیری تفصیلی پیدا نشد یا متعلق به این شرکت نیست.', 1;

IF EXISTS (
    SELECT 1
    FROM [accounting].[BaseDetilLink]
    WHERE ParentLinkId = @LinkId AND IsDeleted = 0)
    THROW 50071, N'این تفصیلی دارای زیرسطح است؛ ابتدا فرزندان آن را حذف کنید.', 1;

-- AccountCode کامل همین مسیر را برای کنترل گردش مالی بساز.
;WITH Ancestors AS (
    SELECT dl.LinkId, dl.ParentLinkId, dl.DetilId, 0 AS Depth
    FROM [accounting].[BaseDetilLink] dl
    WHERE dl.LinkId = @LinkId AND dl.IsDeleted = 0

    UNION ALL

    SELECT parent.LinkId, parent.ParentLinkId, parent.DetilId, child.Depth + 1
    FROM [accounting].[BaseDetilLink] parent
    INNER JOIN Ancestors child ON child.ParentLinkId = parent.LinkId
    WHERE parent.IsDeleted = 0
)
SELECT @DetailCodePath = STRING_AGG(CAST(d.DetilCode AS NVARCHAR(MAX)), N'')
           WITHIN GROUP (ORDER BY a.Depth DESC)
FROM Ancestors a
INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = a.DetilId AND d.IsDeleted = 0
OPTION (MAXRECURSION 32767);

SELECT @AccountCode = CAST(c.ColCode + m.MoeinCode + ISNULL(@DetailCodePath, N'') AS NVARCHAR(4000))
FROM [accounting].[BaseMoein] m
INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
WHERE m.MoeinId = @ResolvedMoeinId AND m.IsDeleted = 0;

-- اگر روی خود مسیر یا زیرمسیرهای آن گردش ثبت شده باشد، placement حذف نمی‌شود.
-- گردش فقط روی اسناد همین شرکت معتبر است (کدها بین شرکت‌ها ممکن است مشترک باشند).
IF @AccountCode IS NOT NULL
   AND EXISTS (
        SELECT 1
        FROM [accounting].[DocumentLines] lines
        INNER JOIN [accounting].[Documents] doc
            ON doc.DocumentId = lines.DocumentId AND doc.CompanyId = @CompanyId
        WHERE lines.AccountCode LIKE @AccountCode + N'%'
   )
BEGIN
    UPDATE [accounting].[BaseDetilLink]
    SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE LinkId = @LinkId AND IsDeleted = 0;
    RETURN;
END

UPDATE [accounting].[BaseDetilLink]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE LinkId = @LinkId AND IsDeleted = 0;

IF @@ROWCOUNT = 0
    THROW 50070, N'محل قرارگیری تفصیلی پیدا نشد.', 1;
