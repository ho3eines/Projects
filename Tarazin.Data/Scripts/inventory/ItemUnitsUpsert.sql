-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemUnitsUpsert.sql
-- Schema: inventory
-- Procedure. جایگزینی کامل واحدهای یک کالا (حذف + درج در تراکنش).
-- پارامترها: @ItemId, @Json (آرایهٔ [{"UnitId":..,"Factor":..,"IsDefault":..}]), @CreatedBy
-- نکته: دقیقاً یک IsDefault=1 باید وجود داشته باشد و Factor آن باید ۱ باشد.
-- =============================================
SET NOCOUNT ON;
DECLARE @Items TABLE (UnitId INT, Factor DECIMAL(18,4), IsDefault BIT);
INSERT INTO @Items (UnitId, Factor, IsDefault)
SELECT UnitId, Factor, IsDefault
FROM OPENJSON(@Json)
WITH (
    UnitId   INT             '$.UnitId',
    Factor   DECIMAL(18,4)   '$.Factor',
    IsDefault BIT            '$.IsDefault'
);

BEGIN TRY
    BEGIN TRANSACTION;

    -- هشدار: بدون واحد پیش‌فرض نیستیم
    IF NOT EXISTS (SELECT 1 FROM @Items WHERE IsDefault = 1)
    BEGIN
        RAISERROR(N'یک واحد باید به‌عنوان پیش‌فرض انتخاب شود.', 16, 1);
    END

    UPDATE [inventory].[ItemUnits]
    SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
    WHERE ItemId = @ItemId;

    INSERT INTO [inventory].[ItemUnits] (ItemId, UnitId, Factor, IsDefault, CreatedBy)
    SELECT @ItemId, t.UnitId,
           CASE WHEN t.IsDefault = 1 THEN 1 ELSE t.Factor END,
           t.IsDefault, @CreatedBy
    FROM @Items t
    WHERE t.UnitId > 0;

    COMMIT TRANSACTION;
    SELECT CAST(1 AS BIT) AS Success;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;