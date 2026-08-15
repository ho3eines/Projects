-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartTreeSearch.sql
-- Schema: accounting
-- جستجو در همهٔ سطح‌های درخت، شامل AccountCode و Breadcrumb سطح ۴ به بعد.
-- =============================================
DECLARE @Term NVARCHAR(200) = ISNULL(LTRIM(RTRIM(@SearchText)), N'');
DECLARE @Like NVARCHAR(202) = N'%' + @Term + N'%';

;WITH BaseCols AS (
    SELECT
        c.ColId AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(4000)) AS AccountCode,
        c.IsActive, c.IsDeleted,
        CAST(c.Title AS NVARCHAR(4000)) AS Breadcrumb,
        CAST(NULL AS INT) AS DetilEntityId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS MoeinId,
        CAST(NULL AS INT) AS ParentLinkId
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
),
BaseMoeins (
    NodeId, Level, Code, Title, NodeType, ParentId, AccountCode,
    IsActive, IsDeleted, Breadcrumb, DetilEntityId, LinkId, MoeinId, ParentLinkId
) AS (
    SELECT
        m.MoeinId, 2, m.MoeinCode, m.Title,
        N'BaseMoein', m.ColId,
        CAST(c.AccountCode + m.MoeinCode AS NVARCHAR(4000)),
        m.IsActive, m.IsDeleted,
        CAST(c.Breadcrumb + N' > ' + m.Title AS NVARCHAR(4000)),
        CAST(NULL AS INT), CAST(NULL AS INT), CAST(NULL AS INT), CAST(NULL AS INT)
    FROM [accounting].[BaseMoein] m
    INNER JOIN BaseCols c ON c.NodeId = m.ColId
    WHERE m.IsDeleted = 0
),
DetailTree (
    NodeId, Level, Code, Title, NodeType, ParentId, AccountCode,
    IsActive, IsDeleted, Breadcrumb, DetilEntityId, LinkId, MoeinId, ParentLinkId
) AS (
    SELECT
        d.DetilId, 3, d.DetilCode, d.Title,
        N'BaseDetil', dl.MoeinId,
        CAST(m.AccountCode + d.DetilCode AS NVARCHAR(4000)),
        CAST(CASE WHEN d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT),
        d.IsDeleted,
        CAST(m.Breadcrumb + N' > ' + d.Title AS NVARCHAR(4000)),
        d.DetilId, dl.LinkId, dl.MoeinId, dl.ParentLinkId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN BaseMoeins m ON m.NodeId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0 AND d.IsDeleted = 0

    UNION ALL

    SELECT
        d.DetilId, parent.Level + 1, d.DetilCode, d.Title,
        N'BaseDetil', dl.ParentLinkId,
        CAST(parent.AccountCode + d.DetilCode AS NVARCHAR(4000)),
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
    NodeId, Level, AccountCode, Code, Title, NodeType, ParentId,
    IsActive, IsDeleted, Breadcrumb,
    0 AS ChildCount,
    DetilEntityId, LinkId, MoeinId, ParentLinkId
FROM AllNodes
WHERE @Term <> N''
  AND (Title LIKE @Like OR Code LIKE @Like OR AccountCode LIKE @Like OR Breadcrumb LIKE @Like)
ORDER BY AccountCode, Level, LinkId
OPTION (MAXRECURSION 32767, RECOMPILE);
