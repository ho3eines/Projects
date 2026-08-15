-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseColList.sql
-- Schema: accounting
-- لیست تمام حساب‌های کل.
-- ایندکس IX_BaseCol_Deleted_Active این query را سریع می‌کند.
-- =============================================
SELECT
    c.ColId, c.ColCode, c.Title, c.[Description], c.IsActive,
    c.CreatedAt, c.UpdatedAt, c.CreatedBy, c.UpdatedBy
FROM [accounting].[BaseCol] c
WHERE c.IsDeleted = 0
ORDER BY c.ColCode;
