-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilLinkDelete.sql
-- Schema: accounting | Contract: BaseDetilLink
-- حذف پیوند بین تفصیلی و معین (در صورت امکان؛ در غیر این صورت غیرفعال).
-- ایندکس IX_DocumentLines_AccountCode جستجوی prefix را تسریع می‌کند.
-- =============================================
DECLARE @AccountCode NVARCHAR(20);
SELECT @AccountCode = c.ColCode + m.MoeinCode + d.DetilCode
FROM [accounting].[BaseDetilLink] dl
INNER JOIN [accounting].[BaseMoein] m  ON m.MoeinId  = @MoeinId AND m.IsDeleted = 0
INNER JOIN [accounting].[BaseCol]   c  ON c.ColId    = m.ColId   AND c.IsDeleted = 0
INNER JOIN [accounting].[BaseDetil] d  ON d.DetilId  = @DetilId  AND d.IsDeleted = 0
WHERE dl.LinkId = @LinkId;

IF @AccountCode IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [accounting].[DocumentLines] dl_lines WITH (INDEX(IX_DocumentLines_AccountCode))
        WHERE dl_lines.AccountCode LIKE @AccountCode + N'%'
    )
    BEGIN
        -- فقط غیرفعال می‌کنیم
        UPDATE [accounting].[BaseDetilLink]
        SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
        WHERE LinkId = @LinkId AND IsDeleted = 0;

        IF @@ROWCOUNT = 0
            THROW 50070, N'پیوند تفصیلی پیدا نشد.', 1;
        RETURN;
    END
END

UPDATE [accounting].[BaseDetilLink]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE LinkId = @LinkId AND IsDeleted = 0;

IF @@ROWCOUNT = 0
    THROW 50070, N'پیوند تفصیلی پیدا نشد.', 1;
