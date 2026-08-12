-- =============================================
-- Tarazin.Shared/Data/Scripts/treasury/CashEntryFromInvoice.sql
-- Schema: treasury | Consumer of InvoiceCreated (accounting → treasury)
-- Execute. Idempotent on SourceReference = 'Invoice:{InvoiceId}' (ADR-002).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [treasury].[CashMovements] WHERE SourceReference = CONCAT(N'Invoice:', @InvoiceId))
BEGIN
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy)
    VALUES
        (N'', CAST(SYSDATETIME() AS DATE), N'In', @TotalAmount, ISNULL(@CurrencyCode, N'IRR'),
         (SELECT TOP 1 AccountId FROM [treasury].[BankAccounts] WHERE IsDeleted = 0 ORDER BY AccountId),
         NULL,
         CONCAT(N'دریافت بابت فاکتور ', @InvoiceId, N' — سفارش ', @OrderId),
         CONCAT(N'Invoice:', @InvoiceId), N'Posted', N'outbox');

    UPDATE [treasury].[CashMovements]
    SET MovementNumber = N'CSH-' + RIGHT(N'00000' + CAST(MovementId AS NVARCHAR(10)), 5)
    WHERE SourceReference = CONCAT(N'Invoice:', @InvoiceId);
END
