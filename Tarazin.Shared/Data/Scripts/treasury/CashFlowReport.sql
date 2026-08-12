-- =============================================
-- Tarazin.Shared/Data/Scripts/treasury/CashFlowReport.sql
-- Schema: treasury
-- Query. جریان نقد در بازه.
-- =============================================
SELECT
    m.MovementDate,
    m.MovementNumber,
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
ORDER BY m.MovementDate, m.MovementId;
