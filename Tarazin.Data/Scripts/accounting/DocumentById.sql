-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentById.sql
-- Schema: accounting
-- سربرگ یک سند حسابداری بر اساس شناسه (برای نمایش/ویرایش سند).
-- اسناد حذف‌شده (IsDeleted=1) برنمی‌گردند.
-- =============================================
SELECT
    d.DocumentId,
    d.DocumentNumber,
    d.DocumentDate,
    d.DocumentType,
    d.CounterPartyName,
    d.TotalAmount,
    d.CurrencyCode,
    d.Status,
    d.CreatedAt,
    d.UpdatedAt,
    d.CreatedBy,
    d.UpdatedBy
FROM [accounting].[Documents] d
WHERE d.DocumentId = @DocumentId AND d.IsDeleted = 0;
