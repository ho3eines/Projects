SELECT s.CompanyId, s.InventoryWarehouseId, w.Title AS InventoryWarehouseTitle,
       s.CustomerAccountGroupId, cg.Title AS CustomerAccountGroupTitle,
       s.SupplierAccountGroupId, sg.Title AS SupplierAccountGroupTitle,
       s.InventoryAccountGroupId, ig.Title AS InventoryAccountGroupTitle,
       s.SalesAccountId, ISNULL(s.SalesAccountTitle, sa.Title) AS SalesAccountTitle, s.SalesAccountCode,
       s.InventoryAccountId, ISNULL(s.InventoryAccountTitle, ia.Title) AS InventoryAccountTitle, s.InventoryAccountCode,
       s.TaxPayableAccountId, ISNULL(s.TaxPayableAccountTitle, ta.Title) AS TaxPayableAccountTitle, s.TaxPayableAccountCode,
       s.CashAccountId, ISNULL(s.CashAccountTitle, ca.Title) AS CashAccountTitle, s.CashAccountCode,
       s.BankAccountId, ba.AccountName AS BankAccountTitle,
       s.CashBoxId, cb.Title AS CashBoxTitle,
       s.BankChartAccountId, ISNULL(s.BankChartAccountTitle, bca.Title) AS BankChartAccountTitle, s.BankChartAccountCode,
       s.DefaultTaxPercent, s.LaborTaxPercent,
       s.IsEnabled, s.UpdatedAt
FROM [goldshop].[GoldShopSettings] s
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId=s.InventoryWarehouseId
LEFT JOIN [accounting].[AccountGroups] cg ON cg.AccountGroupId=s.CustomerAccountGroupId
LEFT JOIN [accounting].[AccountGroups] sg ON sg.AccountGroupId=s.SupplierAccountGroupId
LEFT JOIN [accounting].[AccountGroups] ig ON ig.AccountGroupId=s.InventoryAccountGroupId
LEFT JOIN [accounting].[ChartOfAccounts] sa ON sa.AccountId=s.SalesAccountId
LEFT JOIN [accounting].[ChartOfAccounts] ia ON ia.AccountId=s.InventoryAccountId
LEFT JOIN [accounting].[ChartOfAccounts] ta ON ta.AccountId=s.TaxPayableAccountId
LEFT JOIN [accounting].[ChartOfAccounts] ca ON ca.AccountId=s.CashAccountId
LEFT JOIN [treasury].[BankAccounts] ba ON ba.AccountId=s.BankAccountId
LEFT JOIN [treasury].[CashBoxes] cb ON cb.CashBoxId=s.CashBoxId
LEFT JOIN [accounting].[ChartOfAccounts] bca ON bca.AccountId=s.BankChartAccountId
WHERE s.CompanyId=@CompanyId;
