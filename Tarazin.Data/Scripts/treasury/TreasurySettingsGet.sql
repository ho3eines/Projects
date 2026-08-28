-- =============================================
-- Tarazin.Data/Scripts/treasury/TreasurySettingsGet.sql
-- Schema: treasury
-- Query. تنظیمات اتصال خزانه به حسابداری برای شرکت فعال.
-- =============================================
SELECT s.CompanyId,
       s.CashAccountId, ISNULL(s.CashAccountTitle, ca.Title) AS CashAccountTitle, s.CashAccountCode,
       s.BankChartAccountId, ISNULL(s.BankChartAccountTitle, bca.Title) AS BankChartAccountTitle, s.BankChartAccountCode,
       s.ReceiveContraAccountId, ISNULL(s.ReceiveContraAccountTitle, rca.Title) AS ReceiveContraAccountTitle, s.ReceiveContraAccountCode,
       s.PayContraAccountId, ISNULL(s.PayContraAccountTitle, pca.Title) AS PayContraAccountTitle, s.PayContraAccountCode,
       s.CustomerAccountGroupId, cg.Title AS CustomerAccountGroupTitle,
       s.SupplierAccountGroupId, sg.Title AS SupplierAccountGroupTitle,
       s.DefaultCashBoxId, cb.Title AS DefaultCashBoxTitle,
       s.DefaultBankAccountId, ba.AccountName AS DefaultBankAccountTitle,
       s.IsEnabled, s.UpdatedAt
FROM [treasury].[TreasurySettings] s
LEFT JOIN [accounting].[ChartOfAccounts] ca ON ca.AccountId = s.CashAccountId
LEFT JOIN [accounting].[ChartOfAccounts] bca ON bca.AccountId = s.BankChartAccountId
LEFT JOIN [accounting].[ChartOfAccounts] rca ON rca.AccountId = s.ReceiveContraAccountId
LEFT JOIN [accounting].[ChartOfAccounts] pca ON pca.AccountId = s.PayContraAccountId
LEFT JOIN [accounting].[AccountGroups] cg ON cg.AccountGroupId = s.CustomerAccountGroupId
LEFT JOIN [accounting].[AccountGroups] sg ON sg.AccountGroupId = s.SupplierAccountGroupId
LEFT JOIN [treasury].[CashBoxes] cb ON cb.CashBoxId = s.DefaultCashBoxId
LEFT JOIN [treasury].[BankAccounts] ba ON ba.AccountId = s.DefaultBankAccountId
WHERE s.CompanyId = @CompanyId;
