-- =============================================
-- Tarazin.Data/Scripts/inventory/UnitUpsert.sql
-- Schema: inventory
-- Execute. ثبت/ویرایش واحد کالا. UnitId=0 یعنی رکورد جدید.
-- =============================================
DECLARE @EffectiveCode NVARCHAR(30) = ISNULL(NULLIF(@UnitCode, N''),
    N'UNT-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(UnitId) FROM [inventory].[Units] WHERE CompanyId = @CompanyId), 0) + 1 AS NVARCHAR(10)), 5));

IF @UnitId = 0
BEGIN
    INSERT INTO [inventory].[Units] (UnitCode, Title, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES (@EffectiveCode, @Title, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [inventory].[Units]
    SET UnitCode  = ISNULL(@UnitCode, UnitCode),
        Title     = ISNULL(@Title, Title),
        IsActive  = ISNULL(@IsActive, IsActive),
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE UnitId = @UnitId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51032, N'واحد کالا یافت نشد.', 1;
END
