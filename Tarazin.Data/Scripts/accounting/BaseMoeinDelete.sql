-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseMoeinDelete.sql
-- Schema: accounting | Contract: BaseMoein
-- اگر دارای تفصیلی پیوند یا گردش باشد، حذف ممنوع.
-- ایندکس IX_DocumentLines_AccountCode روی ستون AccountCode جستجوی prefix را تسریع می‌کند.
-- قانون چندشرکتی: حساب و گردش فقط در همان شرکت معتبر است؛ گردش شرکت دیگر
-- با کد مشابه نباید حذف را قفل کند.
-- =============================================
DECLARE @AccountCode NVARCHAR(10);
SELECT @AccountCode = bc.ColCode + m.MoeinCode
FROM [accounting].[BaseMoein] m
INNER JOIN [accounting].[BaseCol] bc ON bc.ColId = m.ColId
WHERE m.MoeinId = @MoeinId AND m.IsDeleted = 0 AND bc.IsDeleted = 0 AND m.CompanyId = @CompanyId;

IF @AccountCode IS NULL
    THROW 50032, N'حساب معین پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت نیست.', 1;

IF EXISTS (SELECT 1 FROM [accounting].[BaseDetilLink] WHERE MoeinId = @MoeinId AND IsDeleted = 0)
    THROW 50030, N'این حساب معین دارای تفصیلی است؛ ابتدا پیوندهای تفصیلی را حذف کنید.', 1;

-- بررسی گردش: DocumentLines.AccountCode شامل ColCode + MoeinCode در ابتدا (5 رقم)
-- فقط برای اسناد همین شرکت.
IF EXISTS (
    SELECT 1
    FROM [accounting].[DocumentLines] dl
    INNER JOIN [accounting].[Documents] doc
        ON doc.DocumentId = dl.DocumentId AND doc.CompanyId = @CompanyId
    WHERE dl.AccountCode LIKE @AccountCode + N'%'
)
    THROW 50031, N'این حساب به‌دلیل داشتن گردش مالی امکان حذف ندارد. به‌جای آن غیرفعال کنید.', 1;

UPDATE [accounting].[BaseMoein]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE MoeinId = @MoeinId AND IsDeleted = 0 AND CompanyId = @CompanyId;

IF @@ROWCOUNT = 0
    THROW 50032, N'حساب معین پیدا نشد یا قبلاً حذف شده است.', 1;
