-- =============================================
-- جستجو در همهٔ سطح‌های درخت، شامل گروه، ماهیت، AccountCode و Breadcrumb.
-- اطلاعات گروه بعد از CTE بازگشتی متصل می‌شود تا بخش بازگشتی فاقد OUTER JOIN باشد.
-- =============================================
DECLARE @Term NVARCHAR(200) = ISNULL(LTRIM(RTRIM(@SearchText)), N'');
DECLARE @Like NVARCHAR(202) = N'%' + @Term + N'%';

;WITH BaseCols AS (
    SELECT
        c.ColId AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(4000)) AS AccountCode,
        c.AccountGroupId, c.AccountNature,
        c.IsActive, c.IsDeleted,
        CAST(c.Title AS NVARCHAR(4000)) AS Breadcrumb,
        CAST(NULL AS INT) AS DetilEntityId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS MoeinId,
        CAST(NULL AS INT) AS ParentLinkId
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0 AND c.CompanyId = @CompanyId
),
BaseMoeins (
    NodeId, Level, Code, Title, NodeType, ParentId, AccountCode,
    AccountGroupId, AccountNature,
    IsActive, IsDeleted, Breadcrumb, DetilEntityId, LinkId, MoeinId, ParentLinkId
) AS (
    SELECT
        m.MoeinId, 2, m.MoeinCode, m.Title,
        N'BaseMoein', m.ColId,
        CAST(c.AccountCode + m.MoeinCode AS NVARCHAR(4000)),
        m.AccountGroupId, m.AccountNature,
        m.IsActive, m.IsDeleted,
        CAST(c.Breadcrumb + N' > ' + m.Title AS NVARCHAR(4000)),
        CAST(NULL AS INT), CAST(NULL AS INT), CAST(NULL AS INT), CAST(NULL AS INT)
    FROM [accounting].[BaseMoein] m
    INNER JOIN BaseCols c ON c.NodeId = m.ColId
    WHERE m.IsDeleted = 0 AND m.CompanyId = @CompanyId
),
DetailTree (
    NodeId, Level, Code, Title, NodeType, ParentId, AccountCode,
    AccountGroupId, AccountNature,
    IsActive, IsDeleted, Breadcrumb, DetilEntityId, LinkId, MoeinId, ParentLinkId
) AS (
    SELECT
        d.DetilId, 3, d.DetilCode, d.Title,
        N'BaseDetil', dl.MoeinId,
        CAST(m.AccountCode + d.DetilCode AS NVARCHAR(4000)),
        d.AccountGroupId, d.AccountNature,
        CAST(CASE WHEN d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT),
        d.IsDeleted,
        CAST(m.Breadcrumb + N' > ' + d.Title AS NVARCHAR(4000)),
        d.DetilId, dl.LinkId, dl.MoeinId, dl.ParentLinkId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN BaseMoeins m ON m.NodeId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0 AND dl.CompanyId = @CompanyId
      AND d.IsDeleted = 0

    UNION ALL

    SELECT
        d.DetilId, parent.Level + 1, d.DetilCode, d.Title,
        N'BaseDetil', dl.ParentLinkId,
        CAST(parent.AccountCode + d.DetilCode AS NVARCHAR(4000)),
        d.AccountGroupId, d.AccountNature,
        CAST(CASE WHEN parent.IsActive = 1 AND d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT),
        d.IsDeleted,
        CAST(parent.Breadcrumb + N' > ' + d.Title AS NVARCHAR(4000)),
        d.DetilId, dl.LinkId, dl.MoeinId, dl.ParentLinkId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN DetailTree parent ON parent.LinkId = dl.ParentLinkId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND d.IsDeleted = 0 AND dl.MoeinId = parent.MoeinId
),
AllNodes AS (
    SELECT * FROM BaseCols
    UNION ALL SELECT * FROM BaseMoeins
    UNION ALL SELECT * FROM DetailTree
)
SELECT
    n.NodeId, n.Level, n.AccountCode, n.Code, n.Title, n.NodeType, n.ParentId,
    n.AccountGroupId, g.GroupCode, g.Title AS GroupTitle, n.AccountNature,
    n.IsActive, n.IsDeleted, n.Breadcrumb,
    0 AS ChildCount,
    n.DetilEntityId, n.LinkId, n.MoeinId, n.ParentLinkId
FROM AllNodes n
LEFT JOIN [accounting].[AccountGroups] g
    ON g.AccountGroupId = n.AccountGroupId AND g.IsDeleted = 0
WHERE @Term <> N''
  AND (n.Title LIKE @Like OR n.Code LIKE @Like OR n.AccountCode LIKE @Like OR n.Breadcrumb LIKE @Like
       OR g.Title LIKE @Like OR g.GroupCode LIKE @Like OR n.AccountNature LIKE @Like
       OR (N'بدهکار' LIKE @Like AND n.AccountNature = N'Debit')
       OR (N'بستانکار' LIKE @Like AND n.AccountNature = N'Credit')
       OR ((N'هر دو' LIKE @Like OR N'هردو' LIKE @Like) AND n.AccountNature = N'Both'))
ORDER BY n.AccountCode, n.Level, n.LinkId
OPTION (MAXRECURSION 32767, RECOMPILE);
