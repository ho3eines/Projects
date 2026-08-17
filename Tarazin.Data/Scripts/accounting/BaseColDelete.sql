-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseColDelete.sql
-- Schema: accounting | Contract: BaseCol
-- اگر حساب دارای فرزند، گردش یا سند باشد، حذف مستقیم ممنوع است؛
-- در غیر این صورت، حذف نرم (IsDeleted=1) اعمال می‌شود.
-- ایندکس IX_DocumentLines_AccountCode جستجوی گردش را سریع می‌کند.
-- قانون چندشرکتی: حساب و گردش فقط در همان شرکت معتبر است؛ گردش شرکت دیگر
-- با کد مشابه نباید حذف را قفل کند.
-- =============================================
DECLARE @ColCode NVARCHAR(2);
SELECT @ColCode = ColCode FROM [accounting].[BaseCol]
WHERE ColId = @ColId AND IsDeleted = 0 AND CompanyId = @CompanyId;

IF @ColCode IS NULL
    THROW 50012, N'حساب کل پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت نیست.', 1;

IF EXISTS (SELECT 1 FROM [accounting].[BaseMoein] WHERE ColId = @ColId AND IsDeleted = 0)
    THROW 50010, N'این حساب کل دارای حساب معین است؛ ابتدا حساب‌های معین زیرمجموعه را حذف/منتقل کنید.', 1;

-- بررسی گردش: DocumentLines.AccountCode با ColCode شروع می‌شود.
-- ایندکس IX_DocumentLines_AccountCode روی ستون AccountCode جستجوی prefix را تسریع می‌کند.
IF EXISTS (
    SELECT 1
    FROM [accounting].[DocumentLines] dl
    INNER JOIN [accounting].[Documents] doc
        ON doc.DocumentId = dl.DocumentId AND doc.CompanyId = @CompanyId
    WHERE dl.AccountCode LIKE @ColCode + N'%'
)
    THROW 50011, N'این حساب به‌دلیل داشتن گردش مالی امکان حذف ندارد. به‌جای آن غیرفعال کنید.', 1;

UPDATE [accounting].[BaseCol]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE ColId = @ColId AND IsDeleted = 0 AND CompanyId = @CompanyId;

IF @@ROWCOUNT = 0
    THROW 50012, N'حساب کل پیدا نشد یا قبلاً حذف شده است.', 1;
