-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartTreeFull.sql
-- Schema: accounting
-- درخت کامل حساب‌ها با تفصیلی چندسطحی واقعی:
--   Level 1 = BaseCol
--   Level 2 = BaseMoein
--   Level 3 = BaseDetilLink با ParentLinkId=NULL
--   Level 4+ = BaseDetilLink با ParentLinkId به placement والد
--
-- BaseDetil موجودیت مشترک است؛ LinkId هویت گره در یک مسیر مشخص است.
-- @IncludeInactive: 0=فقط زنجیره‌های فعال، 1=همهٔ رکوردهای حذف‌نشده.
-- =============================================
;WITH BaseCols AS (
    SELECT
        c.ColId AS NodeId,
        1 AS Level,
        c.ColCode AS Code,
        c.Title,
        N'BaseCol' AS NodeType,
        CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(4000)) AS AccountCode,
        c.IsActive,
        c.IsDeleted,
        CAST(c.Title AS NVARCHAR(4000)) AS Breadcrumb,
        CAST(NULL AS INT) AS DetilEntityId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS MoeinId,
        CAST(NULL AS INT) AS ParentLinkId
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
      AND (@IncludeInactive = 1 OR c.IsActive = 1)
),
BaseMoeins AS (
    SELECT
        m.MoeinId AS NodeId,
        2 AS Level,
        m.MoeinCode AS Code,
        m.Title,
        N'BaseMoein' AS NodeType,
        m.ColId AS ParentId,
        CAST(bc.AccountCode + m.MoeinCode AS NVARCHAR(4000)) AS AccountCode,
        m.IsActive,
        m.IsDeleted,
        CAST(bc.Breadcrumb + N' > ' + m.Title AS NVARCHAR(4000)) AS Breadcrumb,
        CAST(NULL AS INT) AS DetilEntityId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS MoeinId,
        CAST(NULL AS INT) AS ParentLinkId
    FROM [accounting].[BaseMoein] m
    INNER JOIN BaseCols bc ON bc.NodeId = m.ColId
    WHERE m.IsDeleted = 0
      AND (@IncludeInactive = 1 OR m.IsActive = 1)
),
DetailTree AS (
    -- سطح ۳: placement ریشه زیر معین.
    SELECT
        d.DetilId AS NodeId,
        3 AS Level,
        d.DetilCode AS Code,
        d.Title,
        N'BaseDetil' AS NodeType,
        dl.MoeinId AS ParentId,
        CAST(bm.AccountCode + d.DetilCode AS NVARCHAR(4000)) AS AccountCode,
        CAST(CASE WHEN d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT) AS IsActive,
        d.IsDeleted,
        CAST(bm.Breadcrumb + N' > ' + d.Title AS NVARCHAR(4000)) AS Breadcrumb,
        d.DetilId AS DetilEntityId,
        dl.LinkId,
        dl.MoeinId,
        dl.ParentLinkId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN BaseMoeins bm ON bm.NodeId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.ParentLinkId IS NULL
      AND dl.IsDeleted = 0
      AND d.IsDeleted = 0
      AND (@IncludeInactive = 1 OR (dl.IsActive = 1 AND d.IsActive = 1))

    UNION ALL

    -- سطح ۴ به بعد: placement فرزند دقیقاً به LinkId والد متصل است.
    SELECT
        d.DetilId AS NodeId,
        parent.Level + 1 AS Level,
        d.DetilCode AS Code,
        d.Title,
        N'BaseDetil' AS NodeType,
        dl.ParentLinkId AS ParentId,
        CAST(parent.AccountCode + d.DetilCode AS NVARCHAR(4000)) AS AccountCode,
        CAST(CASE WHEN parent.IsActive = 1 AND d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS BIT) AS IsActive,
        d.IsDeleted,
        CAST(parent.Breadcrumb + N' > ' + d.Title AS NVARCHAR(4000)) AS Breadcrumb,
        d.DetilId AS DetilEntityId,
        dl.LinkId,
        dl.MoeinId,
        dl.ParentLinkId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN DetailTree parent ON parent.LinkId = dl.ParentLinkId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0
      AND d.IsDeleted = 0
      AND dl.MoeinId = parent.MoeinId
      AND (@IncludeInactive = 1 OR (dl.IsActive = 1 AND d.IsActive = 1))
),
AllNodes AS (
    SELECT * FROM BaseCols
    UNION ALL
    SELECT * FROM BaseMoeins
    UNION ALL
    SELECT * FROM DetailTree
)
SELECT
    n.NodeId,
    n.Level,
    n.Code,
    n.Title,
    n.NodeType,
    n.ParentId,
    n.AccountCode,
    n.IsActive,
    n.IsDeleted,
    n.Breadcrumb,
    CASE n.NodeType
        WHEN N'BaseCol' THEN (
            SELECT COUNT(*) FROM BaseMoeins ch WHERE ch.ParentId = n.NodeId)
        WHEN N'BaseMoein' THEN (
            SELECT COUNT(*) FROM DetailTree ch
            WHERE ch.MoeinId = n.NodeId AND ch.ParentLinkId IS NULL)
        WHEN N'BaseDetil' THEN (
            SELECT COUNT(*) FROM DetailTree ch WHERE ch.ParentLinkId = n.LinkId)
        ELSE 0
    END AS ChildCount,
    n.DetilEntityId,
    n.LinkId,
    n.MoeinId,
    n.ParentLinkId
FROM AllNodes n
ORDER BY n.AccountCode, n.Level, n.LinkId
OPTION (MAXRECURSION 32767, RECOMPILE);
