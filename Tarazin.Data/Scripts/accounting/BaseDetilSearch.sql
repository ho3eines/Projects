-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilSearch.sql
-- Schema: accounting
-- جستجوی تفصیلی برای Autocomplete.
-- ایندکس IX_BaseDetil_Title جستجوی روی Title را سریع می‌کند.
-- ایندکس IX_BaseDetil_Deleted_Active فیلتر IsDeleted/IsActive را بهینه می‌کند.
-- =============================================
SELECT
    d.DetilId, d.DetilCode, d.Title, d.[Description], d.IsActive,
    d.CreatedAt, d.UpdatedAt, d.CreatedBy, d.UpdatedBy
FROM [accounting].[BaseDetil] d
WHERE d.IsDeleted = 0
  AND (@SearchText = N'' OR d.Title LIKE N'%' + @SearchText + N'%'
       OR d.DetilCode LIKE N'%' + @SearchText + N'%')
ORDER BY CASE WHEN @SearchText <> N'' AND d.DetilCode = @SearchText THEN 0
              WHEN @SearchText <> N'' AND d.DetilCode LIKE @SearchText + N'%' THEN 1
              WHEN @SearchText <> N'' AND d.Title LIKE @SearchText + N'%' THEN 2
              ELSE 3 END,
         d.DetilCode
OFFSET 0 ROWS FETCH NEXT 50 ROWS ONLY;
