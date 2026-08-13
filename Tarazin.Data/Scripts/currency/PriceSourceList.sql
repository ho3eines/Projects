-- =============================================
-- Tarazin.Data/Scripts/currency/PriceSourceList.sql
-- Schema: currency
-- Query. فهرست منابع قیمت (PRD §44/§45/§57/§58/§61).
-- =============================================
SELECT s.SourceId, s.SourceKey, s.Title, s.BaseUrl, s.Endpoint, s.MappingsJson,
       s.IsActive, s.Priority, s.FetchIntervalSeconds, s.Status,
       s.LastFetchAt, s.LastSuccessAt, s.LastValidAt, s.LastError, s.ErrorCount,
       s.CreatedAt, s.UpdatedAt, s.CreatedBy, s.UpdatedBy
FROM [currency].[PriceSources] s
WHERE (@OnlyActive = 0 OR s.IsActive = 1)
ORDER BY s.Priority, s.SourceKey;
