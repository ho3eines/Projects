-- =============================================
-- webapi/Data/Scripts/treasury/CashMovementInsert.sql
-- Schema: treasury
-- Execute. دریافت / پرداخت / انتقال.
-- =============================================
IF @Direction NOT IN (N'In', N'Out')
    THROW 51010, N'جهت نامعتبر است (In/Out)', 1;

BEGIN TRAN;
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy)
    VALUES
        (N'', @MovementDate, @Direction, @Amount, ISNULL(@CurrencyCode, N'IRR'), @AccountId, @CashBoxId, @Description, @SourceReference, N'Posted', @CreatedBy);

    DECLARE @Mid INT = SCOPE_IDENTITY();
    UPDATE [treasury].[CashMovements]
    SET MovementNumber = N'CSH-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5)
    WHERE MovementId = @Mid;

    -- Keep account/cashbox balances in sync (v1: direct update).
    IF @AccountId IS NOT NULL
        UPDATE [treasury].[BankAccounts]
        SET Balance = Balance + CASE WHEN @Direction = N'In' THEN @Amount ELSE -@Amount END
        WHERE AccountId = @AccountId;

    IF @CashBoxId IS NOT NULL
        UPDATE [treasury].[CashBoxes]
        SET Balance = Balance + CASE WHEN @Direction = N'In' THEN @Amount ELSE -@Amount END
        WHERE CashBoxId = @CashBoxId;
COMMIT;
