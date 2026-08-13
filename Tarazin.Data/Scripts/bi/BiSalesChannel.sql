-- =============================================
-- Tarazin.Data/Scripts/bi/BiSalesChannel.sql
-- Schema: bi
-- Cross-schema: goldshop, store, currency
-- Query. مقایسهٔ کانال‌های فروش (§30): طلافروشی / فروشگاه / فروش ارز.
-- خروجی: ترکیب (Title=کانال, Value=مبلغ, SecondaryValue=درصد)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

WITH parts AS (
    SELECT N'GoldShop' AS GroupKey, N'طلافروشی' AS Title,
           ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0) AS Value
    UNION ALL SELECT N'Store', N'فروشگاه اینترنتی',
           ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate >= @MonthStart AND Status = N'Invoiced'), 0)
    UNION ALL SELECT N'FxSell', N'فروش ارز',
           ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate >= @MonthStart AND TransactionType = N'Sell'), 0)
)
SELECT GroupKey, Title, Value,
       CASE WHEN (SELECT SUM(Value) FROM parts) = 0 THEN 0
            ELSE ROUND(Value * 100.0 / (SELECT SUM(Value) FROM parts), 1) END AS SecondaryValue
FROM parts
WHERE Value <> 0
ORDER BY Value DESC;
