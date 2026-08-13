-- =============================================
-- Tarazin.Data/Scripts/bi/BiIncomeComposition.sql
-- Schema: bi
-- Cross-schema: goldshop, store, currency, accounting
-- Query. ترکیب درآمد (§10): طلا / اینترنتی / ارز / سایر درآمدهای دفتر کل.
-- خروجی: ترکیب (GroupKey, Title, Value, SecondaryValue=درصد)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

WITH parts AS (
    SELECT N'GoldShop' AS GroupKey, N'فروش طلا' AS Title,
           ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0) AS Value
    UNION ALL SELECT N'Store', N'فروش اینترنتی',
           ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate >= @MonthStart AND Status = N'Invoiced'), 0)
    UNION ALL SELECT N'FxSell', N'فروش ارز',
           ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate >= @MonthStart AND TransactionType = N'Sell'), 0)
    UNION ALL SELECT N'FxConvert', N'سود تبدیل ارز',
           ISNULL((SELECT SUM(ISNULL(l.RealizedPnl, 0)) FROM [currency].[FxTransactionLegs] l
                   JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
                   WHERE t.TransactionDate >= @MonthStart AND t.TransactionType = N'Conversion'), 0)
    UNION ALL SELECT N'Ledger', N'سایر درآمدها (دفتر کل)',
           ISNULL((SELECT SUM(l.Credit) FROM [accounting].[DocumentLines] l
                   JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
                   JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
                   WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate >= @MonthStart
                     AND a.AccountType = N'Income'), 0)
)
SELECT GroupKey, Title, Value,
       CASE WHEN (SELECT SUM(Value) FROM parts) = 0 THEN 0
            ELSE ROUND(Value * 100.0 / (SELECT SUM(Value) FROM parts), 1) END AS SecondaryValue
FROM parts
WHERE Value <> 0
ORDER BY Value DESC;
