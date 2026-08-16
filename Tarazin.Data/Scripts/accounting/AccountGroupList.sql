-- =============================================
-- گروه‌های حساب کل، معین و تفصیلی.
-- @GroupType: NULL/'' = همه | Col | Moein | Detil
-- @IncludeInactive: 1 = فعال و غیرفعال
-- =============================================
DECLARE @Type NVARCHAR(10) = NULLIF(LTRIM(RTRIM(@GroupType)), N'');

SELECT
    g.AccountGroupId,
    g.GroupType,
    g.GroupCode,
    g.Title,
    g.FromCode,
    g.ToCode,
    g.DefaultNature,
    g.[Description],
    g.IsActive,
    CASE g.GroupType
        WHEN N'Col' THEN (SELECT COUNT(*) FROM [accounting].[BaseCol] c WHERE c.AccountGroupId = g.AccountGroupId AND c.IsDeleted = 0)
        WHEN N'Moein' THEN (SELECT COUNT(*) FROM [accounting].[BaseMoein] m WHERE m.AccountGroupId = g.AccountGroupId AND m.IsDeleted = 0)
        WHEN N'Detil' THEN (SELECT COUNT(*) FROM [accounting].[BaseDetil] d WHERE d.AccountGroupId = g.AccountGroupId AND d.IsDeleted = 0)
        ELSE 0
    END AS AssignedAccountCount,
    g.CreatedAt,
    g.UpdatedAt,
    g.CreatedBy,
    g.UpdatedBy
FROM [accounting].[AccountGroups] g
WHERE g.IsDeleted = 0
  AND (@Type IS NULL OR g.GroupType = @Type)
  AND (@IncludeInactive = 1 OR g.IsActive = 1)
ORDER BY
    CASE g.GroupType WHEN N'Col' THEN 1 WHEN N'Moein' THEN 2 WHEN N'Detil' THEN 3 ELSE 4 END,
    g.GroupCode,
    g.Title;
