-- =============================================
-- Tarazin.Data/Scripts/payroll/OutboxClaim.sql
-- Schema: payroll
-- Execute. برداشتن (Claim) ردیف‌های آمادهٔ Outbox به‌صورت اتمیک برای دیسپچر.
--
-- ردیف‌هایی Claim می‌شوند که:
--   * ProcessedAt IS NULL (هنوز موفق نشده‌اند) و
--   * ClaimedAt خالی باشد یا Lease آن منقضی شده باشد (< @LeaseSeconds قبل)
--     تا اگر یک worker وسط کار از بین رفت، ردیف دوباره برداشته شود.
--
-- معیار Claim اتمیک است: همزمانی چند worker با UPDATE ... OUTPUT و قفل ردیف
-- حل می‌شود (ردیفِ Claim‌شده بلافاصله ClaimedAt تازه می‌گیرد و توسط worker
-- بعدی دیده نمی‌شود).
-- =============================================
DECLARE @LeaseExpiry DATETIME2 = DATEADD(SECOND, -ISNULL(@LeaseSeconds, 60), SYSUTCDATETIME());

;WITH Ready AS
(
    SELECT TOP (ISNULL(@MaxRows, 50)) *
    FROM [payroll].[Outbox]
    WHERE ProcessedAt IS NULL
      AND (ClaimedAt IS NULL OR ClaimedAt < @LeaseExpiry)
    ORDER BY OutboxId ASC
)
UPDATE Ready
SET ClaimedAt      = SYSUTCDATETIME(),
    LastAttemptAt  = SYSUTCDATETIME(),
    Attempts       = Attempts + 1
OUTPUT inserted.OutboxId,
       inserted.EventType,
       inserted.EventKey,
       inserted.Payload,
       inserted.PayloadVersion,
       inserted.CreatedAt,
       inserted.ProcessedAt,
       inserted.Attempts,
       inserted.LastError,
       inserted.ClaimedAt;