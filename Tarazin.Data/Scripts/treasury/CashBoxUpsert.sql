-- =============================================
-- Tarazin.Data/Scripts/treasury/CashBoxUpsert.sql
-- Schema: treasury
-- Execute. ثبت/ویرایش صندوق. CashBoxId=0 یعنی رکورد جدید.
-- =============================================
IF @CashBoxId = 0
BEGIN
    INSERT INTO [treasury].[CashBoxes] (CashBoxCode, Title, Balance, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES (@CashBoxCode, @Title, ISNULL(@Balance, 0), ISNULL(@IsActive, 1),
            SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [treasury].[CashBoxes]
    SET CashBoxCode = @CashBoxCode,
        Title       = @Title,
        IsActive    = ISNULL(@IsActive, IsActive),
        UpdatedAt   = SYSUTCDATETIME(),
        UpdatedBy   = @CreatedBy
    WHERE CashBoxId = @CashBoxId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51022, N'صندوق یافت نشد.', 1;
END
