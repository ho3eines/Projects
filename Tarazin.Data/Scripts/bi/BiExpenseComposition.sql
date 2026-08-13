-- =============================================
-- Tarazin.Data/Scripts/bi/BiExpenseComposition.sql
-- Schema: bi
-- Cross-schema: accounting
-- Query. ترکیب هزینه (§70): هزینه به تفکیک حساب (دسته) از دفتر کل در بازهٔ انتخابی.
-- خروجی: ترکیب (GroupKey=کد حساب, Title=عنوان حساب, Value=هزینه, SecondaryValue=درصد)
-- =============================================
DECLARE @From DATE = ISNULL(@FromDate, DATEFROMPARTS(YEAR(CAST(SYSDATETIME() AS DATE)), MONTH(CAST(SYSDATETIME() AS DATE)), 1));
DECLARE @To DATE = ISNULL(@ToDate, CAST(SYSDATETIME() AS DATE));

WITH exp AS (
    SELECT a.AccountCode AS Code, a.Title,
           SUM(l.Debit) AS Value
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0
      AND d.DocumentDate BETWEEN @From AND @To
      AND a.AccountType = N'Expense'
    GROUP BY a.AccountCode, a.Title
)
SELECT Code AS GroupKey, Title,
       ISNULL(Value, 0) AS Value,
       CASE WHEN (SELECT SUM(Value) FROM exp) = 0 THEN 0
            ELSE ROUND(ISNULL(Value, 0) * 100.0 / (SELECT SUM(Value) FROM exp), 1) END AS SecondaryValue
FROM exp
WHERE ISNULL(Value, 0) <> 0
ORDER BY Value DESC;
