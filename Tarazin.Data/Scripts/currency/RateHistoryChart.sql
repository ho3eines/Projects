-- =============================================
-- Tarazin.Data/Scripts/currency/RateHistoryChart.sql
-- Schema: currency
-- Query. نقاط نمودار تغییرات نرخ یک آیتم (PRD §49) — برای MudChart.
-- =============================================
SELECT TOP (@Limit) h.ChangedAt, h.NewValue
FROM [currency].[RateHistory] h
WHERE h.ItemKey = @ItemKey
  AND (@RateKind IS NULL OR h.RateKind = @RateKind)
ORDER BY h.ChangedAt DESC;
