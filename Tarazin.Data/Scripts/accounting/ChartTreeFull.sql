-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartTreeFull.sql
-- Schema: accounting
-- درخت کامل با تعداد فرزند (ChildCount) و Breadcrumb برای هر Node.
-- @IncludeInactive: 0=فقط فعال، 1=همه.
-- خروجی: همهٔ سطوح با NodeId, ParentId, Level, Code, Title, AccountCode, ChildCount, IsActive, Breadcrumb (با جداکنندهٔ «>»).
-- =============================================
;WITH BaseCols AS (
    SELECT
        c.ColId    AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, NULL AS ParentId,
        CAST(c.ColCode AS NVARCHAR(200)) AS AccountCode,
        c.IsActive, c.IsDeleted,
        CAST(c.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
      AND (@IncludeInactive = 1 OR c.IsActive = 1)
),
BaseMoeins AS (
    SELECT
        m.MoeinId  AS NodeId, 2 AS Level, m.MoeinCode AS Code, m.Title,
        N'BaseMoein' AS NodeType, m.ColId AS ParentId,
        CAST(bc.AccountCode + m.MoeinCode AS NVARCHAR(200)) AS AccountCode,
        m.IsActive, m.IsDeleted,
        CAST(bc.Breadcrumb + N' > ' + m.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseMoein] m
    JOIN BaseCols bc ON bc.NodeId = m.ColId
    WHERE m.IsDeleted = 0
      AND (@IncludeInactive = 1 OR m.IsActive = 1)
),
BaseDetils AS (
    SELECT
        d.DetilId  AS NodeId, 3 AS Level, d.DetilCode AS Code, d.Title,
        N'BaseDetil' AS NodeType, dl.LinkId AS ParentId,
        CAST(bm.AccountCode + d.DetilCode AS NVARCHAR(200)) AS AccountCode,
        CASE WHEN d.IsActive = 1 AND dl.IsActive = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsActive,
        d.IsDeleted,
        CAST(bm.Breadcrumb + N' > ' + d.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseDetilLink] dl
    JOIN BaseMoeins bm ON bm.NodeId = dl.MoeinId
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND d.IsDeleted = 0
      AND (@IncludeInactive = 1 OR (d.IsActive = 1 AND dl.IsActive = 1))
),
AllNodes AS (
    SELECT * FROM BaseCols
    UNION ALL
    SELECT * FROM BaseMoeins
    UNION ALL
    SELECT * FROM BaseDetils
)
SELECT
    n.NodeId, n.Level, n.Code, n.Title, n.NodeType, n.ParentId,
    n.AccountCode, n.IsActive, n.IsDeleted, n.Breadcrumb,
    ISNULL(c.ChildCount, 0) AS ChildCount
FROM AllNodes n
OUTER APPLY (
    SELECT COUNT(*) AS ChildCount
    FROM AllNodes ch
    WHERE ch.ParentId = n.NodeId AND ch.Level = n.Level + 1
) c
ORDER BY n.AccountCode, n.Level, n.Code;
