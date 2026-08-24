-- =============================================
-- Tarazin.Data/Scripts/currency/FxTransactionList.sql
-- Schema: currency
-- Cross-schema: accounting (شمارهٔ سند)
-- Query. گزارش معاملات ارز (PRD §37/§38) — خرید/فروش/تبدیل/ترکیبی.
-- =============================================
SELECT t.FxTransactionId, t.TransactionNumber, t.TransactionDate,
       CONVERT(NVARCHAR(8), t.TransactionTime, 108) AS TransactionTime,
       t.TransactionType, t.PartyName, t.Status, t.TotalRial,
       t.DocumentId, d.DocumentNumber, t.Description,
       (SELECT COUNT(*) FROM [currency].[FxTransactionLegs] l WHERE l.FxTransactionId = t.FxTransactionId AND l.CompanyId = [central].[fn_MobileCompanyId]()) AS LegCount,
       t.CreatedBy, t.CreatedAt
FROM [currency].[FxTransactions] t
LEFT JOIN [accounting].[Documents] d ON d.DocumentId = t.DocumentId AND d.CompanyId = [central].[fn_MobileCompanyId]()
WHERE t.CompanyId = [central].[fn_MobileCompanyId]()
  AND (@FromDate IS NULL OR t.TransactionDate >= @FromDate)
  AND (@ToDate IS NULL OR t.TransactionDate <= @ToDate)
  AND (@TransactionType IS NULL OR t.TransactionType = @TransactionType)
  AND (@SearchText IS NULL OR @SearchText = N''
       OR t.TransactionNumber LIKE N'%' + @SearchText + N'%'
       OR ISNULL(t.PartyName, N'') LIKE N'%' + @SearchText + N'%')
ORDER BY t.TransactionDate DESC, t.FxTransactionId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
