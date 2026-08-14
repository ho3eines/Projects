-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartAccountPickerList.sql
-- Schema: accounting
-- لیست بهینه‌شده برای Account Picker (هزاران رکورد).
--   1. سه سطح: Col, Moein, Detil. هر کدام مستقیماً از جداول پایه با
--      ایندکس‌های پوششی فیلتر می‌شود.
--   2. DetilEntityId/LinkId/MoeinId در حالت BaseDetil مقداردهی می‌شود.
--   3. اگر Detil منطبق باشد، Moein و Col والد مسیر (path context) نیز
--      نمایش داده می‌شود تا مسیر در Picker قابل‌فهم باشد.
--   4. @AllowTransactionOnly=1: فقط Detil‌ها (انتخاب‌پذیر). کل/معین والد
--      فقط به‌عنوان context نمایش داده می‌شود (غیرانتخاب‌پذیر).
--   5. @AllowTransactionOnly=0: همه نمایش داده می‌شود.
-- =============================================
DECLARE @Like   NVARCHAR(200) = N'%' + ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';
DECLARE @Prefix NVARCHAR(200) = ISNULL(LTRIM(RTRIM(@SearchText)), N'') + N'%';

-- Detil‌های منطبق (شامل path context)
;WITH DetilPath AS (
    SELECT
        d.DetilId, d.DetilCode, d.Title AS DetilTitle, d.IsActive AS DetilIsActive,
        dl.LinkId, dl.MoeinId,
        m.MoeinCode, m.Title AS MoeinTitle, m.IsActive AS MoeinIsActive, m.ColId,
        c.ColCode, c.Title AS ColTitle, c.IsActive AS ColIsActive
    FROM [accounting].[BaseDetil] d
    INNER JOIN [accounting].[BaseDetilLink] dl ON dl.DetilId = d.DetilId
        AND dl.IsDeleted = 0 AND dl.IsActive = 1
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
        AND m.IsDeleted = 0 AND m.IsActive = 1
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId
        AND c.IsDeleted = 0 AND c.IsActive = 1
    WHERE d.IsDeleted = 0 AND d.IsActive = 1
      AND (@SearchText IS NULL OR @SearchText = N''
           OR d.Title LIKE @Like OR d.DetilCode LIKE @Like OR d.DetilCode LIKE @Prefix
           OR (c.ColCode + m.MoeinCode + d.DetilCode) LIKE @Like
           OR (c.ColCode + m.MoeinCode + d.DetilCode) LIKE @Prefix
           OR c.Title LIKE @Like OR c.ColCode LIKE @Like
           OR m.Title LIKE @Like OR m.MoeinCode LIKE @Like)
),
-- Detil: ردیف اصلی برای Picker
DetilOutput AS (
    SELECT
        dp.DetilId AS NodeId, 3 AS Level, dp.DetilCode AS Code, dp.DetilTitle AS Title,
        N'BaseDetil' AS NodeType, dp.LinkId AS ParentId,
        CAST(dp.ColCode + dp.MoeinCode + dp.DetilCode AS NVARCHAR(200)) AS AccountCode,
        CAST(1 AS BIT) AS IsActive,
        CAST(dp.ColTitle + N' > ' + dp.MoeinTitle + N' > ' + dp.DetilTitle AS NVARCHAR(1000)) AS Breadcrumb,
        dp.DetilId AS DetilEntityId, dp.LinkId AS LinkId, dp.MoeinId
    FROM DetilPath dp
    WHERE (@AccountTypeFilter IS NULL OR @AccountTypeFilter = N'Detil')
),
-- Moeins: از طریق Detil path (context) — اگر Moein به Detil وصل باشد
MoeinContext AS (
    SELECT DISTINCT
        dp.MoeinId AS NodeId, 2 AS Level, dp.MoeinCode AS Code, dp.MoeinTitle AS Title,
        N'BaseMoein' AS NodeType, dp.ColId AS ParentId,
        CAST(dp.ColCode + dp.MoeinCode AS NVARCHAR(200)) AS AccountCode,
        CAST(1 AS BIT) AS IsActive,
        CAST(dp.ColTitle + N' > ' + dp.MoeinTitle AS NVARCHAR(1000)) AS Breadcrumb,
        NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM DetilPath dp
    WHERE @AllowTransactionOnly = 1
      AND (@AccountTypeFilter IS NULL OR @AccountTypeFilter = N'Moein')
),
-- Cols: از طریق Detil path (context) — والد Moein
ColContext AS (
    SELECT DISTINCT
        dp.ColId AS NodeId, 1 AS Level, dp.ColCode AS Code, dp.ColTitle AS Title,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(dp.ColCode AS NVARCHAR(200)) AS AccountCode,
        CAST(1 AS BIT) AS IsActive,
        CAST(dp.ColTitle AS NVARCHAR(1000)) AS Breadcrumb,
        NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM DetilPath dp
    WHERE @AllowTransactionOnly = 1
      AND (@AccountTypeFilter IS NULL OR @AccountTypeFilter = N'Col')
),
-- Cols و Moeins: مستقیم (وقتی AllowTransactionOnly=0)
ColMoeinDirect AS (
    SELECT
        c.ColId AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(200)) AS AccountCode,
        c.IsActive,
        CAST(c.Title AS NVARCHAR(1000)) AS Breadcrumb,
        NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0 AND c.IsActive = 1
      AND @AllowTransactionOnly = 0
      AND (@AccountTypeFilter IS NULL OR @AccountTypeFilter = N'Col')
      AND (@SearchText IS NULL OR @SearchText = N''
           OR c.Title LIKE @Like OR c.ColCode LIKE @Like OR c.ColCode LIKE @Prefix)
    UNION ALL
    SELECT
        m.MoeinId AS NodeId, 2 AS Level, m.MoeinCode AS Code, m.Title,
        N'BaseMoein' AS NodeType, m.ColId AS ParentId,
        CAST(c.ColCode + m.MoeinCode AS NVARCHAR(200)) AS AccountCode,
        m.IsActive,
        CAST(c.Title + N' > ' + m.Title AS NVARCHAR(1000)) AS Breadcrumb,
        NULL AS DetilEntityId, NULL AS LinkId, NULL AS MoeinId
    FROM [accounting].[BaseMoein] m
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0 AND c.IsActive = 1
    WHERE m.IsDeleted = 0 AND m.IsActive = 1
      AND @AllowTransactionOnly = 0
      AND (@AccountTypeFilter IS NULL OR @AccountTypeFilter = N'Moein')
      AND (@SearchText IS NULL OR @SearchText = N''
           OR m.Title LIKE @Like OR m.MoeinCode LIKE @Like OR m.MoeinCode LIKE @Prefix)
)
SELECT
    n.NodeId, n.Level, n.Code, n.Title, n.NodeType, n.ParentId, n.AccountCode, n.IsActive,
    0 AS ChildCount, n.Breadcrumb,
    n.DetilEntityId, n.LinkId, n.MoeinId
FROM (
    SELECT * FROM DetilOutput
    UNION ALL
    SELECT * FROM ColMoeinDirect
    UNION ALL
    SELECT * FROM MoeinContext
    UNION ALL
    SELECT * FROM ColContext
) n
ORDER BY n.AccountCode, n.Level
OPTION (RECOMPILE);
