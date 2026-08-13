-- =============================================
-- Tarazin.Data/Scripts/currency/RateHistory.sql
-- Schema: currency
-- Query. تاریخچهٔ تغییرات نرخ‌ها (PRD §49) — با فیلتر و صفحه‌بندی.
-- =============================================
SELECT h.HistoryId, h.ItemType, h.ItemKey, p.Title, h.RateKind,
       h.PrevValue, h.NewValue, h.SourceKey, h.ChangeType, h.Reason,
       h.ChangedBy, h.ChangedAt, h.IsOnline
FROM [currency].[RateHistory] h
LEFT JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
WHERE (@ItemType IS NULL OR h.ItemType = @ItemType)
  AND (@ItemKey IS NULL OR h.ItemKey = @ItemKey)
  AND (@RateKind IS NULL OR h.RateKind = @RateKind)
  AND (@FromDate IS NULL OR CAST(h.ChangedAt AS DATE) >= @FromDate)
  AND (@ToDate IS NULL OR CAST(h.ChangedAt AS DATE) <= @ToDate)
ORDER BY h.ChangedAt DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
