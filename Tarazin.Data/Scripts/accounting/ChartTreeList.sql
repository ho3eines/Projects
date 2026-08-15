-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartTreeList.sql
-- Schema: accounting
-- خروجی مسطح درخت چندسطحی (قرارداد قدیمی IdPath/CodePath حفظ شده است).
-- =============================================
;WITH BaseCols AS (
    SELECT
        c.ColId AS NodeId, 1 AS Level,
        CAST(N'C:' + CAST(c.ColId AS NVARCHAR(20)) AS NVARCHAR(1000)) AS IdPath,
        CAST(c.ColCode AS NVARCHAR(4000)) AS CodePath,
        c.ColCode AS Code, c.Title, N'BaseCol' AS NodeType,
        CAST(NULL AS INT) AS ParentId, c.IsActive, c.IsDeleted,
        CAST(NULL AS INT) AS DetilEntityId, CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS MoeinId, CAST(NULL AS INT) AS ParentLinkId,
        CAST(c.Title AS NVARCHAR(4000)) AS FullPathTitle
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0 AND (@IncludeInactive = 1 OR c.IsActive = 1)
),
BaseMoeins (
    NodeId, Level, IdPath, CodePath, Code, Title, NodeType, ParentId,
    IsActive, IsDeleted, DetilEntityId, LinkId, MoeinId, ParentLinkId, FullPathTitle
) AS (
    SELECT
        m.MoeinId, 2,
        CAST(c.IdPath + N'/M:' + CAST(m.MoeinId AS NVARCHAR(20)) AS NVARCHAR(1000)),
        CAST(c.CodePath + m.MoeinCode AS NVARCHAR(4000)),
        m.MoeinCode, m.Title, N'BaseMoein', m.ColId, m.IsActive, m.IsDeleted,
        CAST(NULL AS INT), CAST(NULL AS INT), CAST(NULL AS INT), CAST(NULL AS INT),
        CAST(c.FullPathTitle + N' > ' + m.Title AS NVARCHAR(4000))
    FROM [accounting].[BaseMoein] m
    INNER JOIN BaseCols c ON c.NodeId = m.ColId
    WHERE m.IsDeleted = 0 AND (@IncludeInactive = 1 OR m.IsActive = 1)
),
DetailTree (
    NodeId, Level, IdPath, CodePath, Code, Title, NodeType, ParentId,
    IsActive, IsDeleted, DetilEntityId, LinkId, MoeinId, ParentLinkId, FullPathTitle
) AS (
    SELECT
        d.DetilId, 3,
        CAST(m.IdPath + N'/L:' + CAST(dl.LinkId AS NVARCHAR(20)) AS NVARCHAR(1000)),
        CAST(m.CodePath + d.DetilCode AS NVARCHAR(4000)),
        d.DetilCode, d.Title, N'BaseDetil', dl.MoeinId,
        CAST(CASE WHEN d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT),
        d.IsDeleted, d.DetilId, dl.LinkId, dl.MoeinId, dl.ParentLinkId,
        CAST(m.FullPathTitle + N' > ' + d.Title AS NVARCHAR(4000))
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN BaseMoeins m ON m.NodeId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0 AND d.IsDeleted = 0
      AND (@IncludeInactive = 1 OR (dl.IsActive = 1 AND d.IsActive = 1))

    UNION ALL

    SELECT
        d.DetilId, parent.Level + 1,
        CAST(parent.IdPath + N'/L:' + CAST(dl.LinkId AS NVARCHAR(20)) AS NVARCHAR(1000)),
        CAST(parent.CodePath + d.DetilCode AS NVARCHAR(4000)),
        d.DetilCode, d.Title, N'BaseDetil', dl.ParentLinkId,
        CAST(CASE WHEN parent.IsActive = 1 AND d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT),
        d.IsDeleted, d.DetilId, dl.LinkId, dl.MoeinId, dl.ParentLinkId,
        CAST(parent.FullPathTitle + N' > ' + d.Title AS NVARCHAR(4000))
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN DetailTree parent ON parent.LinkId = dl.ParentLinkId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND d.IsDeleted = 0 AND dl.MoeinId = parent.MoeinId
      AND (@IncludeInactive = 1 OR (dl.IsActive = 1 AND d.IsActive = 1))
),
AllNodes AS (
    SELECT * FROM BaseCols
    UNION ALL SELECT * FROM BaseMoeins
    UNION ALL SELECT * FROM DetailTree
)
SELECT
    NodeId, Level, IdPath, CodePath, Code, Title, NodeType, ParentId,
    IsActive, IsDeleted, CodePath AS AccountCode, FullPathTitle,
    DetilEntityId, LinkId, MoeinId, ParentLinkId
FROM AllNodes
ORDER BY CodePath, Level, LinkId
OPTION (MAXRECURSION 32767, RECOMPILE);
