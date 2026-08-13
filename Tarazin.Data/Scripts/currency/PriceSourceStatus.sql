-- =============================================
-- Tarazin.Data/Scripts/currency/PriceSourceStatus.sql
-- Schema: currency
-- Execute. به‌روزرسانی وضعیت اتصال منبع (PRD §45/§57).
-- در صورت قطعی، نرخ‌های معتبر قبلی دست نمی‌خورند.
-- =============================================
UPDATE [currency].[PriceSources]
SET Status     = @Status,                 -- Online | Offline | Disabled
    LastFetchAt = ISNULL(@LastFetchAt, LastFetchAt),
    LastError   = @Error,
    ErrorCount  = CASE WHEN @Status = N'Online' THEN 0 ELSE ErrorCount + 1 END,
    LastSuccessAt = CASE WHEN @Status = N'Online' THEN SYSUTCDATETIME() ELSE LastSuccessAt END,
    LastValidAt   = CASE WHEN @Status = N'Online' THEN SYSUTCDATETIME() ELSE LastValidAt END,
    UpdatedAt     = SYSUTCDATETIME()
WHERE SourceKey = @SourceKey;
