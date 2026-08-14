-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilSearch.sql
-- Schema: accounting
-- جستجوی تفصیلی بر اساس کد/عنوان (برای Autocomplete).
-- =============================================
SELECT
    d.DetilId, d.DetilCode, d.Title, d.[Description], d.IsActive,
    d.CreatedAt, d.UpdatedAt, d.CreatedBy, d.UpdatedBy
FROM [accounting].[BaseDetil] d
WHERE d.IsDeleted = 0
  AND (@SearchText = N'' OR d.Title LIKE N'%' + @SearchText + N'%'
       OR d.DetilCode LIKE N'%' + @SearchText + N'%')
ORDER BY d.DetilCode
OFFSET 0 ROWS FETCH NEXT 50 ROWS ONLY;
