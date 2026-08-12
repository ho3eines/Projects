-- =============================================
-- HermesApp/Data/Scripts/treasury/DailyCashMovements.sql
-- Schema: treasury
-- Query. Main page grid (گردش روز صندوق/بانک).
-- =============================================
SELECT
    m.MovementId,
    m.MovementNumber,
    m.MovementDate,
    m.Direction,
    m.Amount,
    m.CurrencyCode,
    ISNULL(a.AccountName, c.Title) AS AccountName,
    m.Description,
    m.Status
FROM [treasury].[CashMovements] m
LEFT JOIN [treasury].[BankAccounts] a ON a.AccountId = m.AccountId
LEFT JOIN [treasury].[CashBoxes] c ON c.CashBoxId = m.CashBoxId
WHERE m.MovementDate BETWEEN @FromDate AND @ToDate
  AND (@SearchText = N'' OR m.MovementNumber LIKE N'%' + @SearchText + N'%'
       OR m.Description LIKE N'%' + @SearchText + N'%')
  AND (@Direction IS NULL OR m.Direction = @Direction)
ORDER BY m.MovementDate DESC, m.MovementId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
