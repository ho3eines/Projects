-- =============================================
-- لیست تمام حساب‌های کل همراه گروه و ماهیت.
-- =============================================
SELECT
    c.ColId,
    c.ColCode,
    c.Title,
    c.[Description],
    c.AccountGroupId,
    g.GroupCode,
    g.Title AS GroupTitle,
    c.AccountNature,
    c.IsActive,
    c.CreatedAt,
    c.UpdatedAt,
    c.CreatedBy,
    c.UpdatedBy
FROM [accounting].[BaseCol] c
LEFT JOIN [accounting].[AccountGroups] g
    ON g.AccountGroupId = c.AccountGroupId AND g.IsDeleted = 0
WHERE c.IsDeleted = 0 AND c.CompanyId = @CompanyId
ORDER BY c.ColCode;
