-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartTreeSearch.sql
-- Schema: accounting
-- جستجوی حرفه‌ای روی درخت:
--   - جستجوی روی Title هر سطح → هم مسیرهایی که شامل آن عنوان در هر سطح است.
--   - جستجوی روی Code یا AccountCode (prefix یا contains).
--   - اگر جستجو روی BaseDetil منطبق شود، تمام مسیرهای آن Detil نمایش داده می‌شود.
-- پارامتر @SearchText توسط کلاینت به‌صورت wildcarded استفاده می‌شود.
-- خروجی: تمام مسیرهای منطبق (ممکن است چند مسیر برای یک تفصیلی).
-- =============================================
DECLARE @Like NVARCHAR(200) = N'%' + ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';
DECLARE @Prefix NVARCHAR(200) = ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';

;WITH BaseCols AS (
    SELECT
        c.ColId        AS NodeId,
        1              AS Level,
        CAST(c.ColCode AS NVARCHAR(200)) AS CodePath,
        c.ColCode      AS Code,
        c.Title        AS Title,
        N'BaseCol'     AS NodeType,
        NULL           AS ParentId,
        c.IsActive     AS IsActive,
        c.IsDeleted    AS IsDeleted
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
),
BaseMoeins AS (
    SELECT
        m.MoeinId      AS NodeId,
        2              AS Level,
        CAST(bc.CodePath + m.MoeinCode AS NVARCHAR(200)) AS CodePath,
        m.MoeinCode    AS Code,
        m.Title        AS Title,
        N'BaseMoein'   AS NodeType,
        m.ColId        AS ParentId,
        m.IsActive     AS IsActive,
        m.IsDeleted    AS IsDeleted
    FROM [accounting].[BaseMoein] m
    JOIN BaseCols bc ON bc.NodeId = m.ColId
    WHERE m.IsDeleted = 0
),
BaseDetils AS (
    SELECT
        d.DetilId      AS DetilEntityId,
        3              AS Level,
        CAST(bm.CodePath + d.DetilCode AS NVARCHAR(200)) AS CodePath,
        d.DetilCode    AS Code,
        d.Title        AS Title,
        N'BaseDetil'   AS NodeType,
        dl.LinkId      AS ParentId,
        d.IsActive     AS IsActive,
        d.IsDeleted    AS IsDeleted,
        dl.LinkId      AS LinkId,
        dl.MoeinId     AS MoeinId
    FROM [accounting].[BaseDetilLink] dl
    JOIN BaseMoeins bm ON bm.NodeId = dl.MoeinId
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0
      AND d.IsDeleted = 0
),
-- ابتدا تشخیص می‌دهیم آیا SearchText روی DetilTitle منطبق است یا نه.
MatchedDetilIds AS (
    SELECT DISTINCT d.DetilId
    FROM [accounting].[BaseDetil] d
    WHERE d.IsDeleted = 0
      AND (
        d.Title LIKE @Like
        OR d.DetilCode LIKE @Like
        OR d.DetilCode LIKE @Prefix
      )
),
MatchedMoeinIds AS (
    SELECT DISTINCT m.MoeinId
    FROM [accounting].[BaseMoein] m
    WHERE m.IsDeleted = 0
      AND (
        m.Title LIKE @Like
        OR m.MoeinCode LIKE @Like
        OR m.MoeinCode LIKE @Prefix
      )
),
MatchedColIds AS (
    SELECT DISTINCT c.ColId
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
      AND (
        c.Title LIKE @Like
        OR c.ColCode LIKE @Like
        OR c.ColCode LIKE @Prefix
      )
)
SELECT
    t.NodeId, t.Level, t.CodePath AS AccountCode, t.Code, t.Title, t.NodeType, t.ParentId, t.IsActive, t.IsDeleted,
    t.DetilEntityId, t.LinkId, t.MoeinId
FROM (
    -- Cols
    SELECT
        bc.ColId AS NodeId, bc.Level, bc.CodePath, bc.Code, bc.Title, bc.NodeType, bc.ParentId,
        bc.IsActive, bc.IsDeleted, NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM BaseCols bc
    WHERE bc.ColId IN (SELECT ColId FROM MatchedColIds)

    UNION ALL

    -- Moeins
    SELECT
        bm.MoeinId AS NodeId, bm.Level, bm.CodePath, bm.Code, bm.Title, bm.NodeType, bm.ParentId,
        bm.IsActive, bm.IsDeleted, NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM BaseMoeins bm
    WHERE bm.MoeinId IN (SELECT MoeinId FROM MatchedMoeinIds)

    UNION ALL

    -- Detils: هر مسیری که شامل Detil منطبق باشد
    SELECT
        bd.DetilEntityId AS NodeId, bd.Level, bd.CodePath, bd.Code, bd.Title, bd.NodeType, bd.ParentId,
        bd.IsActive, bd.IsDeleted, bd.DetilEntityId, bd.LinkId, bd.MoeinId
    FROM BaseDetils bd
    WHERE bd.DetilEntityId IN (SELECT DetilId FROM MatchedDetilIds)

    UNION ALL

    -- Detils: مسیرهای منطبق مستقیم روی کد/عنوان خود Detil (روی همان ردیف Detil)
    SELECT
        bd.DetilEntityId AS NodeId, bd.Level, bd.CodePath, bd.Code, bd.Title, bd.NodeType, bd.ParentId,
        bd.IsActive, bd.IsDeleted, bd.DetilEntityId, bd.LinkId, bd.MoeinId
    FROM BaseDetils bd
    WHERE bd.Title LIKE @Like
       OR bd.Code  LIKE @Like
       OR bd.Code  LIKE @Prefix
       OR bd.CodePath LIKE @Like
       OR bd.CodePath LIKE @Prefix
) t
ORDER BY t.CodePath, t.Level;
