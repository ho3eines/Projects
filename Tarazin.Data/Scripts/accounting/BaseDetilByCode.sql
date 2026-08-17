-- =============================================
-- یافتن تفصیلی بر اساس کد 7 رقمی، همراه گروه و ماهیت.
-- =============================================
DECLARE @NormCode NVARCHAR(7) = RIGHT('0000000' + ISNULL(NULLIF(LTRIM(RTRIM(@DetilCode)), ''), '0000000'), 7);

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
WHERE d.IsDeleted = 0 AND d.DetilCode = @NormCode AND d.CompanyId = @CompanyId;
