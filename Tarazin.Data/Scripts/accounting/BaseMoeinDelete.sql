-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseMoeinDelete.sql
-- Schema: accounting | Contract: BaseMoein
-- اگر دارای تفصیلی پیوند یا گردش باشد، حذف ممنوع.
-- =============================================
DECLARE @HasChildren BIT = 0;
DECLARE @HasUsage   BIT = 0;

IF EXISTS (SELECT 1 FROM [accounting].[BaseDetilLink] WHERE MoeinId = @MoeinId AND IsDeleted = 0)
    SET @HasChildren = 1;

-- گردش سند: AccountCode شامل ColCode + MoeinCode در ابتدا
IF EXISTS (
    SELECT 1
    FROM [accounting].[DocumentLines] dl
    JOIN [accounting].[BaseMoein] m ON dl.AccountCode LIKE m.MoeinCode + N'%'
    JOIN [accounting].[BaseCol]   c ON m.ColId = c.ColId
    WHERE m.MoeinId = @MoeinId AND m.IsDeleted = 0 AND c.IsDeleted = 0
      AND dl.AccountCode LIKE c.ColCode + m.MoeinCode + N'%')
    SET @HasUsage = 1;

IF @HasChildren = 1
    THROW 50030, N'این حساب معین دارای تفصیلی است؛ ابتدا پیوندهای تفصیلی را حذف کنید.', 1;

IF @HasUsage = 1
    THROW 50031, N'این حساب به‌دلیل داشتن گردش مالی امکان حذف ندارد. به‌جای آن غیرفعال کنید.', 1;

UPDATE [accounting].[BaseMoein]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE MoeinId = @MoeinId AND IsDeleted = 0;

IF @@ROWCOUNT = 0
    THROW 50032, N'حساب معین پیدا نشد یا قبلاً حذف شده است.', 1;
