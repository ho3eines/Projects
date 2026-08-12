-- =============================================
-- TarazinApp/Data/Scripts/accounting/ChartOfAccountUpsert.sql
-- Schema: accounting | Contract: ChartOfAccount (producer)
-- Execute.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountId = @AccountId)
BEGIN
    INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, ParentAccountId, IsActive, CreatedAt)
    VALUES (@AccountCode, @Title, @AccountType, @ParentAccountId, ISNULL(@IsActive, 1), SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [accounting].[ChartOfAccounts]
    SET AccountCode     = ISNULL(@AccountCode, AccountCode),
        Title           = ISNULL(@Title, Title),
        AccountType     = @AccountType,
        ParentAccountId = @ParentAccountId,
        IsActive        = ISNULL(@IsActive, IsActive),
        UpdatedAt       = SYSUTCDATETIME()
    WHERE AccountId = @AccountId;
END
