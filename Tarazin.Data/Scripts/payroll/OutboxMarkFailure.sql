-- =============================================
-- Tarazin.Data/Scripts/payroll/OutboxMarkFailure.sql
-- Schema: payroll
-- Execute. ثبت شکست روی یک ردیف Outbox؛ ClaimedAt پاک می‌شود تا ردیف پس از
-- انقضای Lease دوباره Claim شود (retry با Attempts و LastError برای پایش).
-- =============================================
UPDATE [payroll].[Outbox]
SET ClaimedAt = NULL,
    LastError = @LastError
WHERE OutboxId = @OutboxId
  AND ProcessedAt IS NULL;