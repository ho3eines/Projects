-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseColDelete.sql
-- Schema: accounting | Contract: BaseCol
-- اگر حساب دارای فرزند، گردش یا سند باشد، حذف مستقیم ممنوع است؛
-- در غیر این صورت، حذف نرم (IsDeleted=1) اعمال می‌شود.
-- ایندکس IX_DocumentLines_AccountCode جستجوی گردش را سریع می‌کند.
-- =============================================
IF EXISTS (SELECT 1 FROM [accounting].[BaseMoein] WHERE ColId = @ColId AND IsDeleted = 0)
    THROW 50010, N'این حساب کل دارای حساب معین است؛ ابتدا حساب‌های معین زیرمجموعه را حذف/منتقل کنید.', 1;

-- بررسی گردش: DocumentLines.AccountCode با ColCode شروع می‌شود.
-- ایندکس IX_DocumentLines_AccountCode روی ستون AccountCode جستجوی prefix را تسریع می‌کند.
DECLARE @ColCode NVARCHAR(2);
SELECT @ColCode = ColCode FROM [accounting].[BaseCol] WHERE ColId = @ColId AND IsDeleted = 0;

IF @ColCode IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [accounting].[DocumentLines] dl WITH (INDEX(IX_DocumentLines_AccountCode))
        WHERE dl.AccountCode LIKE @ColCode + N'%'
    )
        THROW 50011, N'این حساب به‌دلیل داشتن گردش مالی امکان حذف ندارد. به‌جای آن غیرفعال کنید.', 1;
END

UPDATE [accounting].[BaseCol]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE ColId = @ColId AND IsDeleted = 0;

IF @@ROWCOUNT = 0
    THROW 50012, N'حساب کل پیدا نشد یا قبلاً حذف شده است.', 1;
