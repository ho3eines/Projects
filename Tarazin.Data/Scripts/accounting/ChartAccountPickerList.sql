-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartAccountPickerList.sql
-- Schema: accounting
-- لیست کامل حساب‌ها برای Account Picker.
-- فیلتر نوع حساب (کل/معین/تفصیلی) و قابلیت ثبت تراکنش.
-- @AccountTypeFilter: NULL = همه؛ 'Col' | 'Moein' | 'Detil'.
-- @AllowTransactionOnly=1: فقط حساب‌های نهایی قابل ثبت سند (= BaseDetil).
-- @SearchText: جستجو روی Code/Title/AccountCode.
-- خروجی: شامل ChildCount و DetilEntityId/LinkId/MoeinId برای Picker.
-- =============================================
DECLARE @Like   NVARCHAR(200) = N'%' + ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';
DECLARE @Prefix NVARCHAR(200) = ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';

;WITH BaseCols AS (
    SELECT
        c.ColId    AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, NULL AS ParentId,
        CAST(c.ColCode AS NVARCHAR(200)) AS AccountCode,
        c.IsActive,
        CAST(c.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
),
BaseMoeins AS (
    SELECT
        m.MoeinId  AS NodeId, 2 AS Level, m.MoeinCode AS Code, m.Title,
        N'BaseMoein' AS NodeType, m.ColId AS ParentId,
        CAST(bc.AccountCode + m.MoeinCode AS NVARCHAR(200)) AS AccountCode,
        m.IsActive,
        CAST(bc.Breadcrumb + N' > ' + m.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseMoein] m
    JOIN BaseCols bc ON bc.NodeId = m.ColId
    WHERE m.IsDeleted = 0
),
BaseDetils AS (
    SELECT
        d.DetilId  AS NodeId, 3 AS Level, d.DetilCode AS Code, d.Title,
        N'BaseDetil' AS NodeType, dl.LinkId AS ParentId,
        CAST(bm.AccountCode + d.DetilCode AS NVARCHAR(200)) AS AccountCode,
        CASE WHEN d.IsActive = 1 AND dl.IsActive = 1 THEN 1 ELSE 0 END AS IsActive,
        CAST(bm.Breadcrumb + N' > ' + d.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseDetilLink] dl
    JOIN BaseMoeins bm ON bm.NodeId = dl.MoeinId
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND d.IsDeleted = 0
),
AllNodes AS (
    SELECT * FROM BaseCols
    UNION ALL
    SELECT * FROM BaseMoeins
    UNION ALL
    SELECT * FROM BaseDetils
)
SELECT
    t.NodeId, t.Level, t.Code, t.Title, t.NodeType, t.ParentId, t.AccountCode,
    CASE WHEN t.IsActive = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsActive,
    0 AS ChildCount,
    t.Breadcrumb,
    CASE WHEN t.NodeType = N'BaseDetil' THEN t.NodeId ELSE NULL END AS DetilEntityId,
    CASE WHEN t.NodeType = N'BaseDetil' THEN t.ParentId ELSE NULL END AS LinkId,
    CASE WHEN t.NodeType = N'BaseDetil'
         THEN (SELECT TOP 1 dl.MoeinId FROM [accounting].[BaseDetilLink] dl
               WHERE dl.DetilId = t.NodeId AND dl.LinkId = t.ParentId AND dl.IsDeleted = 0)
         ELSE NULL END AS MoeinId
FROM AllNodes t
WHERE t.IsActive = 1
  AND (
       @SearchText IS NULL OR LTRIM(RTRIM(@SearchText)) = N''
    OR t.Title       LIKE @Like
    OR t.Code        LIKE @Like
    OR t.Code        LIKE @Prefix
    OR t.AccountCode LIKE @Like
    OR t.AccountCode LIKE @Prefix
  )
  AND (
       @AccountTypeFilter IS NULL
    OR (@AccountTypeFilter = N'Col'   AND t.NodeType = N'BaseCol')
    OR (@AccountTypeFilter = N'Moein' AND t.NodeType = N'BaseMoein')
    OR (@AccountTypeFilter = N'Detil' AND t.NodeType = N'BaseDetil')
  )
  AND (
       @AllowTransactionOnly = 0
    OR t.NodeType = N'BaseDetil'
  )
ORDER BY t.AccountCode, t.Level;
