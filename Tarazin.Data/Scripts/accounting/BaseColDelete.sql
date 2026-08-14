-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseColDelete.sql
-- Schema: accounting | Contract: BaseCol
-- اگر حساب دارای فرزند، گردش یا سند باشد، حذف مستقیم ممنوع است؛
-- در غیر این صورت، حذف نرم (IsDeleted=1) اعمال می‌شود.
-- =============================================
DECLARE @HasChildren BIT = 0;
DECLARE @HasUsage   BIT = 0;

-- فرزند معین
IF EXISTS (SELECT 1 FROM [accounting].[BaseMoein] WHERE ColId = @ColId AND IsDeleted = 0)
    SET @HasChildren = 1;

-- گردش سند: چک بر اساس DocumentLines.AccountCode prefix
IF EXISTS (
    SELECT 1
    FROM [accounting].[DocumentLines] dl
    JOIN [accounting].[BaseCol] c ON dl.AccountCode LIKE c.ColCode + N'%'
    WHERE c.ColId = @ColId AND c.IsDeleted = 0)
    SET @HasUsage = 1;

IF @HasChildren = 1
    THROW 50010, N'این حساب کل دارای حساب معین است؛ ابتدا حساب‌های معین زیرمجموعه را حذف/منتقل کنید.', 1;

IF @HasUsage = 1
    THROW 50011, N'این حساب به‌دلیل داشتن گردش مالی امکان حذف ندارد. به‌جای آن غیرفعال کنید.', 1;

UPDATE [accounting].[BaseCol]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE ColId = @ColId AND IsDeleted = 0;

IF @@ROWCOUNT = 0
    THROW 50012, N'حساب کل پیدا نشد یا قبلاً حذف شده است.', 1;
