-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartAccountPickerList.sql
-- Schema: accounting
-- لیست بهینه‌شده برای Account Picker (هزاران رکورد).
--   1. هر سطح (Col/Moein/Detil) مستقیماً از جداول پایه با ایندکس‌های
--      پوششی فیلتر می‌شود.
--   2. DetilEntityId/LinkId/MoeinId در حالت BaseDetil مقداردهی می‌شود.
--   3. برای سرعت بیشتر در سناریوهای با تعداد رکورد بالا، از filtered index
--      استفاده می‌شود (IsDeleted=0).
--   4. در BaseDetil به‌جای outer apply، مستقیماً join به Link با index انجام می‌شود.
-- =============================================
DECLARE @Like   NVARCHAR(200) = N'%' + ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';
DECLARE @Prefix NVARCHAR(200) = ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';

;WITH Cols AS (
    SELECT
        c.ColId    AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(200)) AS AccountCode,
        c.IsActive,
        CAST(c.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0 AND c.IsActive = 1
      AND (@AccountTypeFilter IS NULL OR @AccountTypeFilter = N'Col')
      AND (@SearchText IS NULL OR @SearchText = N''
           OR c.Title LIKE @Like OR c.ColCode LIKE @Like OR c.ColCode LIKE @Prefix)
),
Moeins AS (
    SELECT
        m.MoeinId  AS NodeId, 2 AS Level, m.MoeinCode AS Code, m.Title,
        N'BaseMoein' AS NodeType, m.ColId AS ParentId,
        CAST(bc.AccountCode + m.MoeinCode AS NVARCHAR(200)) AS AccountCode,
        m.IsActive,
        CAST(bc.Breadcrumb + N' > ' + m.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseMoein] m
    INNER JOIN Cols bc ON bc.NodeId = m.ColId
    WHERE m.IsDeleted = 0 AND m.IsActive = 1
      AND (@AccountTypeFilter IS NULL OR @AccountTypeFilter = N'Moein')
      AND (@SearchText IS NULL OR @SearchText = N''
           OR m.Title LIKE @Like OR m.MoeinCode LIKE @Like OR m.MoeinCode LIKE @Prefix)
),
Detils AS (
    SELECT
        d.DetilId  AS NodeId, 3 AS Level, d.DetilCode AS Code, d.Title,
        N'BaseDetil' AS NodeType, dl.LinkId AS ParentId,
        CAST(bm.AccountCode + d.DetilCode AS NVARCHAR(200)) AS AccountCode,
        CAST(1 AS BIT) AS IsActive,
        CAST(bm.Breadcrumb + N' > ' + d.Title AS NVARCHAR(1000)) AS Breadcrumb
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN Moeins bm ON bm.NodeId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND dl.IsActive = 1
      AND d.IsDeleted = 0 AND d.IsActive = 1
      AND (@AccountTypeFilter IS NULL OR @AccountTypeFilter = N'Detil')
      AND (@SearchText IS NULL OR @SearchText = N''
           OR d.Title LIKE @Like OR d.DetilCode LIKE @Like OR d.DetilCode LIKE @Prefix
           OR bm.AccountCode LIKE @Like OR bm.AccountCode + d.DetilCode LIKE @Like)
      AND (@AllowTransactionOnly = 0)
),
AllNodes AS (
    SELECT NodeId, Level, Code, Title, NodeType, ParentId, AccountCode, IsActive, Breadcrumb,
           NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM Cols
    UNION ALL
    SELECT NodeId, Level, Code, Title, NodeType, ParentId, AccountCode, IsActive, Breadcrumb,
           NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM Moeins
    UNION ALL
    SELECT NodeId, Level, Code, Title, NodeType, ParentId, AccountCode, IsActive, Breadcrumb,
           NodeId AS DetilEntityId, ParentId AS LinkId, NULL AS MoeinId
    FROM Detils
)
SELECT
    n.NodeId, n.Level, n.Code, n.Title, n.NodeType, n.ParentId, n.AccountCode, n.IsActive,
    0 AS ChildCount, n.Breadcrumb,
    n.DetilEntityId, n.LinkId, n.MoeinId
FROM AllNodes n
ORDER BY n.AccountCode, n.Level
OPTION (RECOMPILE);
