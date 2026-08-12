-- =============================================
-- webapi/Data/Scripts/central/_Seed.sql
-- Schema: central
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [central].[Parties])
BEGIN
    INSERT INTO [central].[Parties] (PartyCode, PartyType, FullName, NationalId, Phone, Email, IsActive, CreatedBy)
    VALUES
        (N'CUS-001', N'Customer', N'شرکت بازرگانی آمل', N'10100456789', N'011-32123456', N'info@amol-trade.ir', 1, N'seed'),
        (N'VEN-001', N'Vendor',   N'تأمین‌کننده طلا و جواهر تهران', N'10200765432', N'021-88776655', NULL, 1, N'seed'),
        (N'EMP-001', N'Employee', N'علی محمدی', N'10300987654', N'09121112233', N'ali@hermes.local', 1, N'seed');
END
