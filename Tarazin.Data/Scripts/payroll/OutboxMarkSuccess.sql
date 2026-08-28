-- =============================================
-- Tarazin.Data/Scripts/payroll/OutboxMarkSuccess.sql
-- Schema: payroll
-- Execute. علامت‌گذاری موفقیت یک ردیف Outbox پس از اجرای موفق مصرف‌کننده‌ها.
-- =============================================
UPDATE [payroll].[Outbox]
SET ProcessedAt   = SYSUTCDATETIME(),
    ClaimedAt     = NULL,
    LastError     = NULL
WHERE OutboxId = @OutboxId
  AND ProcessedAt IS NULL;