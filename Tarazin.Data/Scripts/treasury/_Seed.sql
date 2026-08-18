-- =============================================
-- Tarazin.Data/Scripts/treasury/_Seed.sql
-- Schema: treasury
-- Endpoint: execute (startup)
-- =============================================
-- Multi-Company seed: use first company for default data
DECLARE @SeedCompanyId INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
IF @SeedCompanyId IS NULL
BEGIN
    -- No company yet — central seed will create it; this seed will run again on next startup
    RETURN;
END


IF NOT EXISTS (SELECT 1 FROM [treasury].[Banks] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [treasury].[Banks] (BankCode, Title, IsActive, CreatedAt, CompanyId)
    VALUES
        (N'BK-MELI', N'بانک ملی ایران', 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'BK-SADERAT', N'بانک صادرات ایران', 1, SYSUTCDATETIME(), @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[BankAccounts] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [treasury].[BankAccounts] (AccountName, AccountNo, BankId, Balance, IsActive, CreatedAt, CompanyId)
    VALUES
        (N'حساب جاری اصلی', N'011-1234567-8', 1, 1500000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'حساب فروشگاه',   N'011-7654321-9', 2, 800000000, 1, SYSUTCDATETIME(), @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[CashBoxes] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [treasury].[CashBoxes] (CashBoxCode, Title, Balance, IsActive, CreatedAt, CompanyId)
    VALUES
        (N'BOX-01', N'صندوق فروشگاه', 250000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'BOX-02', N'صندوق دفتر مرکزی', 120000000, 1, SYSUTCDATETIME(), @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[CurrencyRates] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [treasury].[CurrencyRates] (CurrencyCode, CurrencyName, RateToIRR, RateDate, UpdatedAt, CompanyId)
    VALUES
        (N'IRR', N'ریال ایران', 1, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME(), @SeedCompanyId),
        (N'USD', N'دلار آمریکا', 615000, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME(), @SeedCompanyId),
        (N'EUR', N'یورو', 672000, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME(), @SeedCompanyId),
        (N'XAU', N'طلای ۲۴ عیار (گرم)', 38000000, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME(), @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[CashMovements] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [treasury].[CashMovements] (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy, CompanyId)
    VALUES
        (N'CSH-00001', CAST(SYSDATETIME() AS DATE), N'In',  50000000, N'IRR', 1, NULL, N'دریافت از فروش نقدی', N'SEED:CSH-00001', N'Posted', N'seed', @SeedCompanyId),
        (N'CSH-00002', CAST(SYSDATETIME() AS DATE), N'Out', 18000000, N'IRR', 1, NULL, N'پرداخت هزینه جاری',   N'SEED:CSH-00002', N'Posted', N'seed', @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [treasury].[Cheques] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [treasury].[Cheques] (ChequeNumber, BankId, Amount, DueDate, Direction, Status, CreatedAt, CompanyId)
    VALUES
        (N'CHQ-881231', 1, 75000000, DATEADD(DAY, 30, SYSDATETIME()), N'In', N'Pending', SYSUTCDATETIME(), @SeedCompanyId);
END