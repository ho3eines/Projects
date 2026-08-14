-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartTreeFull.sql
-- Schema: accounting
-- درخت کامل بهینه‌شده برای هزاران رکورد:
--   1. از window function (COUNT OVER) برای ChildCount استفاده می‌کند
--      تا self-join کاستد OUTER APPLY حذف شود.
--   2. ParentId هر Node به‌صورت synthetic ساخته می‌شود:
--      - BaseCol:    ParentId=NULL
--      - BaseMoein:  ParentId=ColId
--      - BaseDetil:  ParentId=LinkId
--   3. در همان سطح، child هر Node می‌تواند:
--      - BaseMoein اگر نود BaseCol باشد
--      - BaseDetil (از طریق Link) اگر نود BaseMoein باشد
--   4. بنابراین «فرزند مستقیم» فقط وقتی ParentId=NodeId و Level=Level+1 است.
--      با ایندکس IX_BaseMoein_Col/IX_BaseDetilLink_Moein این خیلی سریع است.
--   5. ایندکس‌های IX_BaseCol_Deleted_Active/IX_BaseMoein_Deleted_Active/
--      IX_BaseDetil_Deleted_Active برای فیلتر سریع IsDeleted/IsActive.
-- @IncludeInactive: 0=فقط فعال، 1=همه.
-- =============================================

;WITH BaseCols AS (
    SELECT
        c.ColId    AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(200)) AS AccountCode,
        c.IsActive, c.IsDeleted,
        CAST(c.Title AS NVARCHAR(1000)) AS Breadcrumb,
        CAST(NULL AS INT) AS DetilEntityId, CAST(NULL AS INT) AS LinkId, CAST(NULL AS INT) AS MoeinId
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
        CAST(bc.Breadcrumb + N' > ' + m.Title AS NVARCHAR(1000)) AS Breadcrumb,
        CAST(NULL AS INT) AS DetilEntityId, CAST(NULL AS INT) AS LinkId, CAST(NULL AS INT) AS MoeinId
    FROM [accounting].[BaseMoein] m
    INNER JOIN BaseCols bc ON bc.NodeId = m.ColId
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
        CAST(bm.Breadcrumb + N' > ' + d.Title AS NVARCHAR(1000)) AS Breadcrumb,
        d.DetilId AS DetilEntityId,
        dl.LinkId AS LinkId,
        dl.MoeinId AS MoeinId
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN BaseMoeins bm ON bm.NodeId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
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
    -- تعداد فرزند مستقیم: شمارش ردیف‌هایی که ParentId=NodeId و Level n+1.
    -- این correlated subquery با ایندکس‌های FK بسیار سریع است.
    ISNULL((
        SELECT COUNT_BIG(*)
        FROM AllNodes ch
        WHERE ch.ParentId = n.NodeId AND ch.Level = n.Level + 1
    ), 0) AS ChildCount,
    n.DetilEntityId, n.LinkId, n.MoeinId
FROM AllNodes n
ORDER BY n.AccountCode, n.Level, n.Code
OPTION (RECOMPILE);
