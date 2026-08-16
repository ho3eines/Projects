-- =============================================
-- جستجوی تفصیلی برای Autocomplete همراه گروه و ماهیت.
-- =============================================
SELECT
    d.DetilId,
    d.DetilCode,
    d.Title,
    d.[Description],
    d.AccountGroupId,
    g.GroupCode,
    g.Title AS GroupTitle,
    d.AccountNature,
    d.IsActive,
    d.CreatedAt,
    d.UpdatedAt,
    d.CreatedBy,
    d.UpdatedBy
FROM [accounting].[BaseDetil] d
LEFT JOIN [accounting].[AccountGroups] g
    ON g.AccountGroupId = d.AccountGroupId AND g.IsDeleted = 0
WHERE d.IsDeleted = 0
  AND (@SearchText = N'' OR d.Title LIKE N'%' + @SearchText + N'%'
       OR d.DetilCode LIKE N'%' + @SearchText + N'%'
       OR g.Title LIKE N'%' + @SearchText + N'%'
       OR g.GroupCode LIKE N'%' + @SearchText + N'%')
ORDER BY CASE WHEN @SearchText <> N'' AND d.DetilCode = @SearchText THEN 0
              WHEN @SearchText <> N'' AND d.DetilCode LIKE @SearchText + N'%' THEN 1
              WHEN @SearchText <> N'' AND d.Title LIKE @SearchText + N'%' THEN 2
              ELSE 3 END,
         d.DetilCode
OFFSET 0 ROWS FETCH NEXT 50 ROWS ONLY;
