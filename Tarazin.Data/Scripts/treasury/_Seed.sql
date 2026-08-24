-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/treasury/_Seed.sql
-- Schema: treasury
-- Endpoint: execute (startup)
-- =============================================
-- Multi-Company seed: for EVERY active company.
DECLARE trs_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CompanyId FROM [central].[Companies] WHERE IsDeleted=0 AND IsActive=1 ORDER BY CompanyId;
DECLARE @SeedCompanyId INT;
OPEN trs_cursor;
FETCH NEXT FROM trs_cursor INTO @SeedCompanyId;
WHILE @@FETCH_STATUS = 0
BEGIN
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
        SELECT N'حساب جاری ' + b.Title, N'011-0000000-0', b.BankId, 1000000000, 1, SYSUTCDATETIME(), @SeedCompanyId
        FROM [treasury].[Banks] b WHERE b.CompanyId = @SeedCompanyId;
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

    IF NOT EXISTS (SELECT 1 FROM [treasury].[Cheques] WHERE CompanyId = @SeedCompanyId)
    BEGIN
        INSERT INTO [treasury].[Cheques] (ChequeNumber, BankId, Amount, DueDate, Direction, Status, CreatedAt, CompanyId)
        SELECT N'CHQ-' + RIGHT(N'000000' + CAST(ROW_NUMBER() OVER (ORDER BY b.BankId) AS NVARCHAR(10)), 6),
               b.BankId, 75000000, DATEADD(DAY, 30, SYSDATETIME()), N'In', N'Pending', SYSUTCDATETIME(), @SeedCompanyId
        FROM [treasury].[Banks] b WHERE b.CompanyId = @SeedCompanyId;
    END

    FETCH NEXT FROM trs_cursor INTO @SeedCompanyId;
END
CLOSE trs_cursor;
DEALLOCATE trs_cursor;