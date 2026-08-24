-- =============================================
-- Tarazin.Data/Scripts/currency/WalletMovementManual.sql
-- Schema: currency
-- Execute. ثبت گردش دستی کیف پول (PRD §36): ورود / خروج / انتقال / تعدیل.
--   In  → موجودی افزایش + بازمحاسبهٔ نرخ متوسط خرید (با نرخ ورودی)
--   Out → موجودی کاهش (با کنترل موجودی کافی)
-- نوع حرکت (MovementType) می‌تواند In/Out/Transfer/Adjustment باشد.
-- =============================================
IF @Direction NOT IN (N'In', N'Out')
    THROW 51180, N'جهت گردش باید In یا Out باشد', 1;
IF @Quantity <= 0 OR @Rate <= 0
    THROW 51181, N'مقدار و نرخ باید بزرگ‌تر از صفر باشد', 1;
IF @CurrencyCode IN (N'IRR', N'TOMAN')
    THROW 51182, N'کیف پول معاملاتی فقط برای ارزهای خارجی است (§35)', 1;

DECLARE @WQty DECIMAL(18,4) = 0, @WAvg DECIMAL(18,2) = NULL;
SELECT @WQty = ISNULL(Quantity, 0), @WAvg = AvgBuyRate
FROM [currency].[Wallets]
WHERE CurrencyCode = @CurrencyCode
  AND CompanyId = [central].[fn_MobileCompanyId]();

IF @Direction = N'Out' AND @WQty < @Quantity
BEGIN
    DECLARE @InsufficientMsg NVARCHAR(2048) = N'موجودی ' + @CurrencyCode + N' برای خروج کافی نیست';
    THROW 51183, @InsufficientMsg, 1;
END

DECLARE @Type NVARCHAR(30) = ISNULL(NULLIF(@MovementType, N''),
    CASE WHEN @Direction = N'In' THEN N'In' ELSE N'Out' END);
DECLARE @AmountRial DECIMAL(18,2) = ROUND(@Quantity * @Rate, 0);

BEGIN TRAN;
    INSERT INTO [currency].[CurrencyMovements]
        (MovementNumber, MovementDate, MovementTime, MovementType, Direction, CurrencyCode, Quantity, Rate, AmountRial,
         CounterPartyName, FundType, FundId, SourceReference, Description, CreatedBy, CompanyId)
    VALUES
        (N'', @MovementDate, @MovementTime, @Type, @Direction, @CurrencyCode, @Quantity, @Rate, @AmountRial,
         NULLIF(LTRIM(RTRIM(@PartyName)), N''), NULLIF(@FundType, N''), @FundId,
         N'MANUAL:' + CONVERT(NVARCHAR(40), SYSUTCDATETIME(), 126), @Description, @CreatedBy, [central].[fn_MobileCompanyId]());

    DECLARE @Mid BIGINT = SCOPE_IDENTITY();
    UPDATE [currency].[CurrencyMovements]
    SET MovementNumber = N'CM-' + RIGHT(N'0000000' + CAST(@Mid AS NVARCHAR(20)), 7)
    WHERE MovementId = @Mid;

    IF @Direction = N'In'
    BEGIN
        DECLARE @NewAvg DECIMAL(18,2);
        IF @WAvg IS NULL OR @WAvg = 0
            SET @NewAvg = @Rate;
        ELSE
            SET @NewAvg = ROUND((@WQty * @WAvg + @Quantity * @Rate) / (@WQty + @Quantity), 0);

        IF EXISTS (SELECT 1 FROM [currency].[Wallets]
               WHERE CurrencyCode = @CurrencyCode
                 AND CompanyId = [central].[fn_MobileCompanyId]())
            UPDATE [currency].[Wallets]
            SET Quantity = Quantity + @Quantity, AvgBuyRate = @NewAvg,
                InQty = InQty + @Quantity, LastMovementAt = SYSUTCDATETIME(),
                UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
            WHERE CurrencyCode = @CurrencyCode
              AND CompanyId = [central].[fn_MobileCompanyId]();
        ELSE
            INSERT INTO [currency].[Wallets] (CurrencyCode, Quantity, AvgBuyRate, OpeningQty, InQty, OutQty, UpdatedAt, UpdatedBy, CompanyId)
            VALUES (@CurrencyCode, @Quantity, @NewAvg, 0, @Quantity, 0, SYSUTCDATETIME(), @CreatedBy, [central].[fn_MobileCompanyId]());
    END
    ELSE
    BEGIN
        UPDATE [currency].[Wallets]
        SET Quantity = Quantity - @Quantity,
            OutQty = OutQty + @Quantity, LastMovementAt = SYSUTCDATETIME(),
            UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
        WHERE CurrencyCode = @CurrencyCode
          AND CompanyId = [central].[fn_MobileCompanyId]();
    END
COMMIT;
