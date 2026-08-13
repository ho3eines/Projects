-- =============================================
-- Tarazin.Data/Scripts/bi/BiFundStatus.sql
-- Schema: bi
-- Cross-schema: treasury
-- Query. وضعیت بانک‌ها و صندوق‌ها (§64/§65): موجودی + دریافت/پرداخت دوره.
-- خروجی: جدول (Col1=نوع, Col2=عنوان, Col3=دریافت, Col4=پرداخت, Amount=موجودی)
-- =============================================
DECLARE @From DATE = ISNULL(@FromDate, DATEADD(MONTH, -1, CAST(SYSDATETIME() AS DATE)));
DECLARE @To DATE = ISNULL(@ToDate, CAST(SYSDATETIME() AS DATE));

SELECT N'Bank' AS RowKey,
       N'بانک' AS Col1,
       b.AccountName AS Col2,
       FORMAT(ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] m
                      WHERE m.AccountId = b.AccountId AND m.Direction = N'In' AND m.MovementDate BETWEEN @From AND @To), 0), 'N0') AS Col3,
       FORMAT(ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] m
                      WHERE m.AccountId = b.AccountId AND m.Direction = N'Out' AND m.MovementDate BETWEEN @From AND @To), 0), 'N0') AS Col4,
       CAST(ISNULL(b.Balance, 0) AS DECIMAL(18,2)) AS Amount,
       ISNULL(b.Balance, 0) AS SecondaryAmount,
       NULL AS Date1,
       N'/treasury' AS Link
FROM [treasury].[BankAccounts] b
WHERE b.IsDeleted = 0

UNION ALL

SELECT N'Cash', N'صندوق', c.Title,
       FORMAT(ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] m
                      WHERE m.CashBoxId = c.CashBoxId AND m.Direction = N'In' AND m.MovementDate BETWEEN @From AND @To), 0), 'N0'),
       FORMAT(ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] m
                      WHERE m.CashBoxId = c.CashBoxId AND m.Direction = N'Out' AND m.MovementDate BETWEEN @From AND @To), 0), 'N0'),
       CAST(ISNULL(c.Balance, 0) AS DECIMAL(18,2)),
       ISNULL(c.Balance, 0),
       NULL,
       N'/treasury'
FROM [treasury].[CashBoxes] c
WHERE c.IsDeleted = 0

ORDER BY Col1, Col2;
