-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartTreeSearch.sql
-- Schema: accounting
-- جستجوی حرفه‌ای بهینه‌شده برای هزاران رکورد:
--   1. ابتدا matched IDs در هر سطح را با ایندکس‌های پوششی
--      (IX_BaseCol_Deleted_Active, IX_BaseMoein_Deleted_Active, IX_BaseDetil_Deleted_Active)
--      پیدا می‌کنیم.
--   2. سپس با join به جداول پایه، مسیر کامل هر matched node را می‌سازیم.
--   3. برای BaseDetil: تمام مسیرهای استفاده از آن Detil از طریق BaseDetilLink
--      (با ایندکس IX_BaseDetilLink_Detil_Active) در یک query بازگردانده می‌شود.
--   4. خروجی شامل ChildCount نیست (فقط id/level/code) تا حجم داده کم شود.
-- پارامتر @SearchText: جستجو روی Title/Code/AccountCode.
-- =============================================

DECLARE @Like   NVARCHAR(200) = N'%' + ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';
DECLARE @Prefix NVARCHAR(200) = ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';

;WITH MatchedCol AS (
    SELECT c.ColId
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
      AND (c.Title LIKE @Like OR c.ColCode LIKE @Like OR c.ColCode LIKE @Prefix)
),
MatchedMoein AS (
    SELECT m.MoeinId
    FROM [accounting].[BaseMoein] m
    WHERE m.IsDeleted = 0
      AND (m.Title LIKE @Like OR m.MoeinCode LIKE @Like OR m.MoeinCode LIKE @Prefix)
),
MatchedDetil AS (
    SELECT d.DetilId
    FROM [accounting].[BaseDetil] d
    WHERE d.IsDeleted = 0
      AND (d.Title LIKE @Like OR d.DetilCode LIKE @Like OR d.DetilCode LIKE @Prefix)
),
-- برای Detil: همهٔ مسیرهایی که DetilId در آن‌ها هست (با ایندکس Detil_Active)
MatchedDetilLink AS (
    SELECT dl.LinkId, dl.DetilId, dl.MoeinId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN MatchedDetil md ON md.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND dl.IsActive = 1
)
SELECT
    t.NodeId, t.Level, t.AccountCode, t.Code, t.Title, t.NodeType, t.ParentId,
    t.IsActive, t.IsDeleted,
    t.DetilEntityId, t.LinkId, t.MoeinId
FROM (
    -- 1. Col های منطبق (مسیر ریشه)
    SELECT
        c.ColId AS NodeId, 1 AS Level, c.ColCode AS AccountCode, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, NULL AS ParentId, c.IsActive, c.IsDeleted,
        NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM [accounting].[BaseCol] c
    INNER JOIN MatchedCol mc ON mc.ColId = c.ColId
    WHERE c.IsDeleted = 0

    UNION ALL

    -- 2. Moein های منطبق (مسیر ریشه تا Moein)
    SELECT
        m.MoeinId AS NodeId, 2 AS Level,
        bc.ColCode + m.MoeinCode AS AccountCode,
        m.MoeinCode AS Code, m.Title,
        N'BaseMoein' AS NodeType, m.ColId AS ParentId, m.IsActive, m.IsDeleted,
        NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM [accounting].[BaseMoein] m
    INNER JOIN MatchedMoein mm ON mm.MoeinId = m.MoeinId
    INNER JOIN [accounting].[BaseCol] bc ON bc.ColId = m.ColId AND bc.IsDeleted = 0
    WHERE m.IsDeleted = 0

    UNION ALL

    -- 3. Detil های منطبق — هر Detil در هر مسیر (ممکن است چند ردیف باشد)
    SELECT
        d.DetilId AS NodeId, 3 AS Level,
        bc.ColCode + m.MoeinCode + d.DetilCode AS AccountCode,
        d.DetilCode AS Code, d.Title,
        N'BaseDetil' AS NodeType, dl.LinkId AS ParentId,
        CASE WHEN d.IsActive = 1 AND dl.IsActive = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsActive,
        d.IsDeleted,
        d.DetilId AS DetilEntityId, dl.LinkId AS LinkId, dl.MoeinId
    FROM MatchedDetilLink dl
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId AND m.IsDeleted = 0
    INNER JOIN [accounting].[BaseCol] bc ON bc.ColId = m.ColId AND bc.IsDeleted = 0
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId AND d.IsDeleted = 0
) t
ORDER BY t.AccountCode, t.Level
OPTION (RECOMPILE);
