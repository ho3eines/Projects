-- =============================================
-- Tarazin.Data/Scripts/treasury/BankAccountUpsert.sql
-- Schema: treasury
-- Execute. ثبت/ویرایش حساب بانکی. AccountId=0 یعنی رکورد جدید.
-- =============================================
IF @AccountId = 0
BEGIN
    INSERT INTO [treasury].[BankAccounts] (AccountName, AccountNo, BankId, Balance, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES (@AccountName, @AccountNo, @BankId, ISNULL(@Balance, 0), ISNULL(@IsActive, 1),
            SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [treasury].[BankAccounts]
    SET AccountName = @AccountName,
        AccountNo   = @AccountNo,
        BankId      = @BankId,
        IsActive    = ISNULL(@IsActive, IsActive),
        UpdatedAt   = SYSUTCDATETIME(),
        UpdatedBy   = @CreatedBy
    WHERE AccountId = @AccountId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51021, N'حساب بانکی یافت نشد.', 1;
END
