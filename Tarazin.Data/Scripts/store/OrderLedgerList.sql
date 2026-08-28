-- =============================================
-- Tarazin.Data/Scripts/store/OrderLedgerList.sql
-- Schema: store
-- Query. دفتر مشتری (کیف پول ریالی) — ردیف‌های بدهکار/بستانکار + ماندهٔ تجمعی.
-- =============================================
SELECT
    l.LedgerId,
    l.CustomerId,
    l.OrderId,
    l.EntryDate,
    l.EntryType,
    l.DebitRial,
    l.CreditRial,
    l.Description,
    l.CreatedBy,
    l.CreatedAt,
    o.OrderNumber
FROM [store].[OrderLedger] l
LEFT JOIN [store].[Orders] o ON o.OrderId = l.OrderId
WHERE l.CompanyId = @CompanyId
  AND (@CustomerId IS NULL OR l.CustomerId = @CustomerId)
  AND (@OrderId IS NULL OR l.OrderId = @OrderId)
ORDER BY l.EntryDate, l.LedgerId;
