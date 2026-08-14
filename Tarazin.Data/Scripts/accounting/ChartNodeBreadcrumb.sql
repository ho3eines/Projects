-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartNodeBreadcrumb.sql
-- Schema: accounting
-- مسیر کامل (Breadcrumb) یک Node خاص.
-- سه case: BaseCol (@NodeType=BaseCol), BaseMoein (@NodeType=BaseMoein), BaseDetil (@NodeType=BaseDetil).
-- ایندکس‌های PK و IX_*_Active استفاده می‌شوند.
-- =============================================

-- حالت BaseCol: فقط کافی است ردیف Col + تمام Moein/Detil والدش را برگردانیم.
-- حالت BaseMoein: Col + Moein + Detil والدش.
-- حالت BaseDetil: Col + Moein + Detil (از طریق Link).

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
    FROM [accounting].[BaseDetilLink] dl WITH (INDEX(IX_BaseDetilLink_Moein_Active))
    INNER JOIN MoeinStep m ON m.MoeinId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND d.IsDeleted = 0
)
SELECT
    cs.NodeId, cs.Level, cs.Code, cs.Title, cs.IsActive, cs.NodeType, cs.ParentId, cs.AccountCode
FROM ColStep cs
WHERE (cs.NodeId = @ColId AND @ColId <> 0)
   OR (@NodeType = N'BaseCol' AND cs.NodeId = @NodeId)

UNION ALL

SELECT
    ms.MoeinId AS NodeId, ms.Level, ms.MoeinCode AS Code, ms.Title, ms.IsActive,
    N'BaseMoein' AS NodeType, ms.ColId AS ParentId, ms.AccountCode
FROM MoeinStep ms
INNER JOIN ColStep cs ON cs.NodeId = ms.ColId
WHERE ms.MoeinId = @MoeinId AND @MoeinId <> 0

UNION ALL

SELECT
    ds.DetilId AS NodeId, ds.Level, ds.DetilCode AS Code, ds.Title, ds.IsActive,
    N'BaseDetil' AS NodeType, ds.MoeinId AS ParentId, ds.AccountCode
FROM DetilStep ds
WHERE ds.DetilId = @DetilId AND @DetilId <> 0
ORDER BY Level
OPTION (RECOMPILE);
