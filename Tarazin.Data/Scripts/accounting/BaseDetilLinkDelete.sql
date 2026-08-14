-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilLinkDelete.sql
-- Schema: accounting | Contract: BaseDetilLink
-- حذف پیوند بین تفصیلی و معین (در صورت امکان؛ در غیر این صورت غیرفعال).
-- =============================================
DECLARE @HasUsage BIT = 0;

-- گردش مالی: DocumentLines.AccountCode ترکیب Col+Moein+Detil را دارد.
IF EXISTS (
    SELECT 1
    FROM [accounting].[DocumentLines] dl
    JOIN [accounting].[BaseMoein] m  ON m.MoeinId = @MoeinId AND m.IsDeleted = 0
    JOIN [accounting].[BaseCol]   c  ON c.ColId   = m.ColId   AND c.IsDeleted = 0
    JOIN [accounting].[BaseDetil] d  ON d.DetilId = @DetilId  AND d.IsDeleted = 0
    WHERE dl.AccountCode LIKE c.ColCode + m.MoeinCode + d.DetilCode + N'%')
    SET @HasUsage = 1;

IF @HasUsage = 1
BEGIN
    -- فقط غیرفعال می‌کنیم
    UPDATE [accounting].[BaseDetilLink]
    SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE LinkId = @LinkId AND IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 50070, N'پیوند تفصیلی پیدا نشد.', 1;
END
ELSE
BEGIN
    UPDATE [accounting].[BaseDetilLink]
    SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE LinkId = @LinkId AND IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 50070, N'پیوند تفصیلی پیدا نشد.', 1;
END
