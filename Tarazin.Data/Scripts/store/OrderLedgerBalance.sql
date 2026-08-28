-- =============================================
-- Tarazin.Data/Scripts/store/OrderLedgerBalance.sql
-- Schema: store
-- Query. ماندهٔ دفتر مشتری (بدهکار مثبت / بستانکار منفی).
-- =============================================
SELECT ISNULL(SUM(DebitRial - CreditRial), 0) AS Balance
FROM [store].[OrderLedger]
WHERE CompanyId = @CompanyId AND CustomerId = @CustomerId;
