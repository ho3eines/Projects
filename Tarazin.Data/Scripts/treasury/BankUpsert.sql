-- =============================================
-- Tarazin.Data/Scripts/treasury/BankUpsert.sql
-- Schema: treasury
-- Execute. ثبت/ویرایش بانک. BankId=0 یعنی رکورد جدید.
-- =============================================
IF @BankId = 0
BEGIN
    INSERT INTO [treasury].[Banks] (BankCode, Title, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES (@BankCode, @Title, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [treasury].[Banks]
    SET BankCode = @BankCode,
        Title    = @Title,
        IsActive = ISNULL(@IsActive, IsActive),
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE BankId = @BankId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51020, N'بانک یافت نشد.', 1;
END
