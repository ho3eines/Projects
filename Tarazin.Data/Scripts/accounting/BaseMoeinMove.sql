-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseMoeinMove.sql
-- Schema: accounting | Contract: BaseMoein
-- انتقال یک حساب معین به یک حساب کل دیگر.
-- اگر MoeinCode در مقصد تکراری باشد، خطا.
-- ID و Code معین تغییر نمی‌کند؛ فقط Parent تغییر می‌کند.
-- =============================================
DECLARE @CurrentColId INT;
SELECT @CurrentColId = ColId
FROM [accounting].[BaseMoein]
WHERE MoeinId = @MoeinId AND IsDeleted = 0;

IF @CurrentColId IS NULL
    THROW 50080, N'حساب معین پیدا نشد.', 1;

IF @CurrentColId = @NewColId
BEGIN
    -- تغییری نکرده
    SELECT @MoeinId AS NewId;
    RETURN;
END

-- والد مقصد باید معتبر و فعال باشد
IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColId = @NewColId AND IsDeleted = 0)
    THROW 50081, N'حساب کل مقصد معتبر نیست.', 1;

-- کد در مقصد نباید تکراری باشد
IF EXISTS (
    SELECT 1 FROM [accounting].[BaseMoein]
    WHERE ColId = @NewColId AND IsDeleted = 0
      AND MoeinCode = (SELECT MoeinCode FROM [accounting].[BaseMoein] WHERE MoeinId = @MoeinId)
      AND MoeinId <> @MoeinId)
    THROW 50082, N'در حساب کل مقصد، حساب معین دیگری با همین کد وجود دارد.', 1;

UPDATE [accounting].[BaseMoein]
SET ColId = @NewColId, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
WHERE MoeinId = @MoeinId AND IsDeleted = 0;

SELECT @MoeinId AS NewId;
