-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilLinkDelete.sql
-- Schema: accounting | Contract: BaseDetilLink
-- حذف پیوند بین تفصیلی و معین (در صورت امکان؛ در غیر این صورت غیرفعال).
--
-- ⚠ باگ تاریخی (رفع شد): جوین‌ها به‌جای اینکه از خودِ ردیفِ پیوند بیایند، با
--   شرط‌های ثابت روی @MoeinId/@DetilId نوشته شده بودند (m.MoeinId = @MoeinId
--   داخل ON) و به dl وصل نمی‌شدند؛ نتیجه یک CROSS JOIN بود که در صورت
--   ناهماهنگیِ پارامترها AccountCode را NULL می‌کرد و کنترل گردش مالی را
--   کاملاً دور می‌زد. حالا همه‌چیز از روی LinkId استخراج می‌شود.
-- =============================================
DECLARE @AccountCode NVARCHAR(20);
DECLARE @Exists      BIT = 0;

SELECT
    @Exists      = 1,
    @AccountCode = c.ColCode + m.MoeinCode + d.DetilCode
FROM [accounting].[BaseDetilLink] dl
INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
INNER JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
WHERE dl.LinkId = @LinkId AND dl.IsDeleted = 0;

-- سازگاری با فراخوان‌هایی که LinkId ندارند: با جفتِ (DetilId, MoeinId) پیدا کن.
IF @Exists = 0 AND ISNULL(@DetilId, 0) <> 0 AND ISNULL(@MoeinId, 0) <> 0
BEGIN
    SELECT TOP (1)
        @Exists      = 1,
        @LinkId      = dl.LinkId,
        @AccountCode = c.ColCode + m.MoeinCode + d.DetilCode
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
    INNER JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.DetilId = @DetilId AND dl.MoeinId = @MoeinId AND dl.IsDeleted = 0
    ORDER BY dl.LinkId;
END

IF @Exists = 0
    THROW 50070, N'پیوند تفصیلی پیدا نشد.', 1;

-- اگر روی این مسیر گردش مالی ثبت شده، پیوند حذف نمی‌شود؛ فقط غیرفعال می‌گردد.
IF @AccountCode IS NOT NULL
   AND EXISTS (
        SELECT 1
        FROM [accounting].[DocumentLines] dl_lines
        WHERE dl_lines.AccountCode LIKE @AccountCode + N'%'
   )
BEGIN
    UPDATE [accounting].[BaseDetilLink]
    SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE LinkId = @LinkId AND IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 50070, N'پیوند تفصیلی پیدا نشد.', 1;
    RETURN;
END

UPDATE [accounting].[BaseDetilLink]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE LinkId = @LinkId AND IsDeleted = 0;

IF @@ROWCOUNT = 0
    THROW 50070, N'پیوند تفصیلی پیدا نشد.', 1;
