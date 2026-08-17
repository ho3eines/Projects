-- =============================================
-- حساب‌های معین یک حساب کل همراه با گروه و ماهیت
-- =============================================
SELECT
    m.MoeinId,
    m.ColId,
    m.MoeinCode,
    m.Title,
    m.[Description],
    m.AccountGroupId,
    g.GroupCode,
    g.Title AS GroupTitle,
    m.AccountNature,
    m.IsActive,
    m.CreatedAt,
    m.UpdatedAt,
    m.CreatedBy,
    m.UpdatedBy
FROM [accounting].[BaseMoein] m
INNER JOIN [accounting].[BaseCol] bc ON bc.ColId = m.ColId AND bc.CompanyId = @CompanyId
LEFT JOIN [accounting].[AccountGroups] g
    ON g.AccountGroupId = m.AccountGroupId
   AND g.IsDeleted = 0
WHERE m.ColId = @ColId
  AND m.IsDeleted = 0
ORDER BY m.MoeinCode;
