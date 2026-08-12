-- =============================================
-- TarazinApp/Data/Scripts/treasury/CashMoveFromPayroll.sql
-- Schema: treasury | Consumer of PayrollFinalized (payroll → treasury)
-- Execute. Idempotent on SourceReference = 'Payroll:{RunId}' (ADR-002 dual-write).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [treasury].[CashMovements] WHERE SourceReference = CONCAT(N'Payroll:', @RunId))
BEGIN
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy)
    VALUES
        (N'', CAST(SYSDATETIME() AS DATE), N'Out', @NetTotal, N'IRR',
         (SELECT TOP 1 AccountId FROM [treasury].[BankAccounts] WHERE IsDeleted = 0 ORDER BY AccountId),
         NULL,
         CONCAT(N'پرداخت حقوق دوره ', @Period),
         CONCAT(N'Payroll:', @RunId), N'Posted', N'outbox');

    UPDATE [treasury].[CashMovements]
    SET MovementNumber = N'CSH-' + RIGHT(N'00000' + CAST(MovementId AS NVARCHAR(10)), 5)
    WHERE SourceReference = CONCAT(N'Payroll:', @RunId);
END
