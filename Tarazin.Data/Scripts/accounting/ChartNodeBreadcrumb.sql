-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartNodeBreadcrumb.sql
-- Schema: accounting
-- مسیر کامل (Breadcrumb) یک Node خاص.
-- ایندکس‌های IX_BaseDetilLink_Detil_Active/IX_BaseDetilLink_Moein_Active
-- جستجوی Link با covering index را تسریع می‌کنند.
-- =============================================
;WITH ColStep AS (
    SELECT
        c.ColId AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title, c.IsActive,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(200)) AS AccountCode
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
),
MoeinStep AS (
    SELECT
        m.MoeinId, 2 AS Level, m.MoeinCode, m.Title, m.IsActive, m.ColId,
        CAST(c.AccountCode + m.MoeinCode AS NVARCHAR(200)) AS AccountCode
    FROM [accounting].[BaseMoein] m
    INNER JOIN ColStep c ON c.NodeId = m.ColId
    WHERE m.IsDeleted = 0
),
DetilStep AS (
    SELECT
        d.DetilId, 3 AS Level, d.DetilCode, d.Title, d.IsActive, dl.MoeinId,
        CAST(m.AccountCode + d.DetilCode AS NVARCHAR(200)) AS AccountCode
    FROM [accounting].[BaseDetilLink] dl WITH (INDEX(IX_BaseDetilLink_Detil_Active))
    INNER JOIN MoeinStep m ON m.MoeinId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND d.IsDeleted = 0
)
SELECT
    cs.NodeId, cs.Level, cs.Code, cs.Title, cs.IsActive, cs.NodeType, cs.ParentId, cs.AccountCode
FROM ColStep cs
WHERE cs.NodeId = @ColId OR (@NodeType = N'BaseCol' AND cs.NodeId = @NodeId)

UNION ALL

SELECT
    ms.MoeinId, ms.Level, ms.MoeinCode, ms.Title, ms.IsActive,
    N'BaseMoein', ms.ColId, ms.AccountCode
FROM MoeinStep ms
INNER JOIN ColStep cs ON cs.NodeId = ms.ColId
WHERE ms.MoeinId = @MoeinId

UNION ALL

SELECT
    ds.DetilId, ds.Level, ds.DetilCode, ds.Title, ds.IsActive,
    N'BaseDetil', ds.MoeinId, ds.AccountCode
FROM DetilStep ds
WHERE ds.DetilId = @DetilId
ORDER BY Level
OPTION (RECOMPILE);
