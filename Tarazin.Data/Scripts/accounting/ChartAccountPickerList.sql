-- =============================================
-- Account Picker برای درخت چندسطحی، همراه با گروه و ماهیت حساب.
-- LinkId مسیر دقیق هر تفصیلی را مشخص می‌کند.
-- اطلاعات گروه بعد از CTE بازگشتی متصل می‌شود تا بخش بازگشتی فاقد OUTER JOIN باشد.
-- =============================================
DECLARE @Term NVARCHAR(200) = ISNULL(LTRIM(RTRIM(@SearchText)), N'');
DECLARE @Like NVARCHAR(202) = N'%' + @Term + N'%';
DECLARE @Inactive BIT = CASE WHEN ISNULL(@IncludeInactive, 0) = 0 THEN 0 ELSE 1 END;

;WITH BaseCols AS (
    SELECT
        c.ColId AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(4000)) AS AccountCode,
        c.AccountGroupId, c.AccountNature,
        c.IsActive,
        CAST(c.Title AS NVARCHAR(4000)) AS Breadcrumb,
        CAST(NULL AS INT) AS DetilEntityId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS MoeinId,
        CAST(NULL AS INT) AS ParentLinkId
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0 AND c.CompanyId = @CompanyId AND (@Inactive = 1 OR c.IsActive = 1)
),
BaseMoeins (
    NodeId, Level, Code, Title, NodeType, ParentId, AccountCode,
    AccountGroupId, AccountNature,
    IsActive, Breadcrumb, DetilEntityId, LinkId, MoeinId, ParentLinkId
) AS (
    SELECT
        m.MoeinId, 2, m.MoeinCode, m.Title,
        N'BaseMoein', m.ColId,
        CAST(c.AccountCode + m.MoeinCode AS NVARCHAR(4000)),
        m.AccountGroupId, m.AccountNature,
        m.IsActive,
        CAST(c.Breadcrumb + N' > ' + m.Title AS NVARCHAR(4000)),
        CAST(NULL AS INT), CAST(NULL AS INT), CAST(NULL AS INT), CAST(NULL AS INT)
    FROM [accounting].[BaseMoein] m
    INNER JOIN BaseCols c ON c.NodeId = m.ColId
    WHERE m.IsDeleted = 0 AND m.CompanyId = @CompanyId AND (@Inactive = 1 OR m.IsActive = 1)
),
DetailTree (
    NodeId, Level, Code, Title, NodeType, ParentId, AccountCode,
    AccountGroupId, AccountNature,
    IsActive, Breadcrumb, DetilEntityId, LinkId, MoeinId, ParentLinkId
) AS (
    SELECT
        d.DetilId, 3, d.DetilCode, d.Title,
        N'BaseDetil', dl.MoeinId,
        CAST(m.AccountCode + d.DetilCode AS NVARCHAR(4000)),
        d.AccountGroupId, d.AccountNature,
        CAST(CASE WHEN d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT),
        CAST(m.Breadcrumb + N' > ' + d.Title AS NVARCHAR(4000)),
        d.DetilId, dl.LinkId, dl.MoeinId, dl.ParentLinkId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN BaseMoeins m ON m.NodeId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.ParentLinkId IS NULL
      AND dl.IsDeleted = 0 AND dl.CompanyId = @CompanyId AND d.IsDeleted = 0
      AND (@Inactive = 1 OR (dl.IsActive = 1 AND d.IsActive = 1))

    UNION ALL

    SELECT
        d.DetilId, parent.Level + 1, d.DetilCode, d.Title,
        N'BaseDetil', dl.ParentLinkId,
        CAST(parent.AccountCode + d.DetilCode AS NVARCHAR(4000)),
        d.AccountGroupId, d.AccountNature,
        CAST(CASE WHEN parent.IsActive = 1 AND d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT),
        CAST(parent.Breadcrumb + N' > ' + d.Title AS NVARCHAR(4000)),
        d.DetilId, dl.LinkId, dl.MoeinId, dl.ParentLinkId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN DetailTree parent ON parent.LinkId = dl.ParentLinkId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND d.IsDeleted = 0
      AND dl.MoeinId = parent.MoeinId
      AND (@Inactive = 1 OR (dl.IsActive = 1 AND d.IsActive = 1))
),
AllNodes AS (
    SELECT * FROM BaseCols
    UNION ALL SELECT * FROM BaseMoeins
    UNION ALL SELECT * FROM DetailTree
),
Enriched AS (
    SELECT n.*, g.GroupCode, g.Title AS GroupTitle
    FROM AllNodes n
    LEFT JOIN [accounting].[AccountGroups] g
        ON g.AccountGroupId = n.AccountGroupId AND g.IsDeleted = 0
),
Filtered AS (
    SELECT *
    FROM Enriched n
    WHERE (@AccountTypeFilter IS NULL
           OR (@AccountTypeFilter = N'Col' AND n.NodeType = N'BaseCol')
           OR (@AccountTypeFilter = N'Moein' AND n.NodeType = N'BaseMoein')
           OR (@AccountTypeFilter = N'Detil' AND n.NodeType = N'BaseDetil'))
      AND (@Term = N''
           OR n.Title LIKE @Like
           OR n.Code LIKE @Like
           OR n.AccountCode LIKE @Like
           OR n.Breadcrumb LIKE @Like
           OR n.GroupCode LIKE @Like
           OR n.GroupTitle LIKE @Like
           OR n.AccountNature LIKE @Like
           OR (N'بدهکار' LIKE @Like AND n.AccountNature = N'Debit')
           OR (N'بستانکار' LIKE @Like AND n.AccountNature = N'Credit')
           OR ((N'هر دو' LIKE @Like OR N'هردو' LIKE @Like) AND n.AccountNature = N'Both'))
)
SELECT
    n.NodeId, n.Level, n.Code, n.Title, n.NodeType, n.ParentId,
    n.AccountCode,
    n.AccountGroupId, n.GroupCode, n.GroupTitle, n.AccountNature,
    n.IsActive,
    CASE n.NodeType
        WHEN N'BaseCol' THEN (SELECT COUNT(*) FROM BaseMoeins x WHERE x.ParentId = n.NodeId)
        WHEN N'BaseMoein' THEN (SELECT COUNT(*) FROM DetailTree x WHERE x.MoeinId = n.NodeId AND x.ParentLinkId IS NULL)
        WHEN N'BaseDetil' THEN (SELECT COUNT(*) FROM DetailTree x WHERE x.ParentLinkId = n.LinkId)
        ELSE 0
    END AS ChildCount,
    n.Breadcrumb,
    n.DetilEntityId, n.LinkId, n.MoeinId, n.ParentLinkId
FROM Filtered n
-- TransactionalOnly فقط قابلیت انتخاب را در UI محدود می‌کند؛ والدها به‌عنوان
-- context در لیست باقی می‌مانند (رفتار قبلی Picker).
WHERE @AllowTransactionOnly IN (0, 1)
ORDER BY n.AccountCode, n.Level, n.LinkId
OPTION (MAXRECURSION 32767, RECOMPILE);
