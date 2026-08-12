-- =============================================
-- webapi/Data/Scripts/treasury/_Seed.sql
-- Schema: treasury
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [treasury].[Banks])
BEGIN
    INSERT INTO [treasury].[Banks] (BankCode, Title, IsActive, CreatedAt)
    VALUES
        (N'BK-MELI', N'بانک ملی ایران', 1, SYSUTCDATETIME()),
        (N'BK-SADERAT', N'بانک صادرات ایران', 1, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[BankAccounts])
BEGIN
    INSERT INTO [treasury].[BankAccounts] (AccountName, AccountNo, BankId, Balance, IsActive, CreatedAt)
    VALUES
        (N'حساب جاری اصلی', N'011-1234567-8', 1, 1500000000, 1, SYSUTCDATETIME()),
        (N'حساب فروشگاه',   N'011-7654321-9', 2, 800000000, 1, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[CashBoxes])
BEGIN
    INSERT INTO [treasury].[CashBoxes] (CashBoxCode, Title, Balance, IsActive, CreatedAt)
    VALUES
        (N'BOX-01', N'صندوق فروشگاه', 250000000, 1, SYSUTCDATETIME()),
        (N'BOX-02', N'صندوق دفتر مرکزی', 120000000, 1, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[CurrencyRates])
BEGIN
    INSERT INTO [treasury].[CurrencyRates] (CurrencyCode, CurrencyName, RateToIRR, RateDate, UpdatedAt)
    VALUES
        (N'IRR', N'ریال ایران', 1, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME()),
        (N'USD', N'دلار آمریکا', 615000, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME()),
        (N'EUR', N'یورو', 672000, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME()),
        (N'XAU', N'طلای ۲۴ عیار (گرم)', 38000000, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[CashMovements])
BEGIN
    INSERT INTO [treasury].[CashMovements] (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy)
    VALUES
        (N'CSH-00001', CAST(SYSDATETIME() AS DATE), N'In',  50000000, N'IRR', 1, NULL, N'دریافت از فروش نقدی', NULL, N'Posted', N'seed'),
        (N'CSH-00002', CAST(SYSDATETIME() AS DATE), N'Out', 18000000, N'IRR', 1, NULL, N'پرداخت هزینه جاری',   NULL, N'Posted', N'seed');
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[Cheques])
BEGIN
    INSERT INTO [treasury].[Cheques] (ChequeNumber, BankId, Amount, DueDate, Direction, Status, CreatedAt)
    VALUES
        (N'CHQ-881231', 1, 75000000, DATEADD(DAY, 30, SYSDATETIME()), N'In', N'Pending', SYSUTDATETIME());
END
