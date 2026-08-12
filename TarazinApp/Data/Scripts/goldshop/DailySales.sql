-- =============================================
-- TarazinApp/Data/Scripts/goldshop/DailySales.sql
-- Schema: goldshop
-- Query. Main page grid (فروش روز).
-- =============================================
SELECT
    s.InvoiceId,
    s.InvoiceNumber,
    s.InvoiceDate,
    s.CustomerName,
    s.ItemCode,
    g.Title AS ItemTitle,
    s.WeightGram,
    s.Workmanship,
    s.Profit,
    s.Tax,
    s.TotalAmount,
    s.Status
FROM [goldshop].[SaleInvoices] s
LEFT JOIN [goldshop].[GoldItems] g ON g.ItemCode = s.ItemCode
WHERE s.InvoiceDate BETWEEN @FromDate AND @ToDate
  AND (@SearchText = N'' OR s.InvoiceNumber LIKE N'%' + @SearchText + N'%'
       OR s.CustomerName LIKE N'%' + @SearchText + N'%')
ORDER BY s.InvoiceDate DESC, s.InvoiceId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
