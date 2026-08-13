-- =============================================
-- Tarazin.Data/Scripts/currency/WalletMovements.sql
-- Schema: currency
-- Cross-schema: treasury (عنوان صندوق/بانک)
-- Query. گردش ارز — ورود/خروج/انتقال/خرید/فروش/تبدیل (PRD §36/§37).
-- =============================================
SELECT m.MovementId, m.MovementNumber, m.MovementDate, CONVERT(NVARCHAR(8), m.MovementTime, 108) AS MovementTime,
       m.MovementType, m.Direction, m.CurrencyCode, c.CurrencyName,
       m.Quantity, m.Rate, m.AmountRial, m.CounterPartyName, m.FundType, m.FundId,
       CASE m.FundType
           WHEN N'Cash' THEN (SELECT Title FROM [treasury].[CashBoxes] WHERE CashBoxId = m.FundId)
           WHEN N'Bank' THEN (SELECT AccountName FROM [treasury].[BankAccounts] WHERE AccountId = m.FundId)
           ELSE NULL
       END AS FundTitle,
       m.FxTransactionId, m.DocumentId, m.Description, m.CreatedBy, m.CreatedAt
FROM [currency].[CurrencyMovements] m
LEFT JOIN [currency].[Currencies] c ON c.CurrencyCode = m.CurrencyCode
WHERE (@CurrencyCode IS NULL OR m.CurrencyCode = @CurrencyCode)
  AND (@FromDate IS NULL OR m.MovementDate >= @FromDate)
  AND (@ToDate IS NULL OR m.MovementDate <= @ToDate)
  AND (@Direction IS NULL OR m.Direction = @Direction)
ORDER BY m.MovementDate DESC, m.MovementId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
