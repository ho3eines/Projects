-- =============================================
-- Tarazin.Data/Scripts/accounting/AccountingHierarchyReport.sql
-- Schema: accounting
-- یک مرحله از مرور حساب را برمی‌گرداند:
--   1 = کل، 2 = معینِ کل، 3 = فرزندان مستقیم تفصیلی.
-- برای تفصیلی‌های سطح 4 به بعد، @ParentLinkId placement والد را مشخص می‌کند.
-- جمع هر والد تفصیلی شامل گردش تمام فرزندان آن است؛ فقط برگ نهایی به گردش سند می‌رود.
-- =============================================
DECLARE @From DATE = CAST(@FromDate AS DATE);
DECLARE @To DATE = CAST(@ToDate AS DATE);
DECLARE @Status NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@StatusFilter)), N'');
DECLARE @Number NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@DocumentNumber)), N'');

IF @Level = 1
BEGIN
    SELECT
        c.ColId AS NodeId,
        1 AS [Level],
        c.ColCode AS Code,
        c.Title,
        N'BaseCol' AS NodeType,
        CAST(NULL AS INT) AS ColId,
        CAST(NULL AS INT) AS MoeinId,
        CAST(NULL AS INT) AS DetilId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS ParentLinkId,
        (
            SELECT COUNT(*)
            FROM [accounting].[BaseMoein] child
            WHERE child.ColId = c.ColId AND child.IsDeleted = 0
        ) AS ChildCount,
        CAST(c.ColCode AS NVARCHAR(4000)) AS AccountCode,
        c.AccountNature,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) AS Debit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) AS Credit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit - l.Credit ELSE 0 END), 0) AS Balance
    FROM [accounting].[BaseCol] c
    LEFT JOIN [accounting].[DocumentLines] l ON l.AccountCode LIKE c.ColCode + N'%'
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0
        AND d.DocumentDate BETWEEN @From AND @To
        AND (@Status IS NULL OR d.Status = @Status)
        AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
    WHERE c.IsDeleted = 0
    GROUP BY c.ColId, c.ColCode, c.Title, c.AccountNature
    HAVING ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) <> 0
        OR ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) <> 0
    ORDER BY c.ColCode;
    RETURN;
END

IF @Level = 2
BEGIN
    SELECT
        m.MoeinId AS NodeId,
        2 AS [Level],
        m.MoeinCode AS Code,
        m.Title,
        N'BaseMoein' AS NodeType,
        m.ColId,
        m.MoeinId,
        CAST(NULL AS INT) AS DetilId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS ParentLinkId,
        (
            SELECT COUNT(*)
            FROM [accounting].[BaseDetilLink] child
            INNER JOIN [accounting].[BaseDetil] childDetail
                ON childDetail.DetilId = child.DetilId AND childDetail.IsDeleted = 0
            WHERE child.MoeinId = m.MoeinId
              AND child.ParentLinkId IS NULL
              AND child.IsDeleted = 0
        ) AS ChildCount,
        CAST(c.ColCode + m.MoeinCode AS NVARCHAR(4000)) AS AccountCode,
        m.AccountNature,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) AS Debit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) AS Credit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit - l.Credit ELSE 0 END), 0) AS Balance
    FROM [accounting].[BaseMoein] m
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
    LEFT JOIN [accounting].[DocumentLines] l ON l.AccountCode LIKE c.ColCode + m.MoeinCode + N'%'
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0
        AND d.DocumentDate BETWEEN @From AND @To
        AND (@Status IS NULL OR d.Status = @Status)
        AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
    WHERE m.IsDeleted = 0 AND m.ColId = @ColId
    GROUP BY m.MoeinId, m.ColId, m.MoeinCode, m.Title, m.AccountNature, c.ColCode
    HAVING ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) <> 0
        OR ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) <> 0
    ORDER BY m.MoeinCode;
    RETURN;
END

IF @Level = 3
BEGIN
    ;WITH DetailPaths AS (
        SELECT
            dl.LinkId,
            dl.ParentLinkId,
            dl.MoeinId,
            dl.DetilId,
            3 AS TreeLevel,
            CAST(c.ColCode + m.MoeinCode + bd.DetilCode AS NVARCHAR(4000)) AS AccountCode,
            bd.DetilCode,
            bd.Title,
            bd.AccountNature
        FROM [accounting].[BaseDetilLink] dl
        INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId AND m.IsDeleted = 0
        INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
        INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
        WHERE dl.ParentLinkId IS NULL
          AND dl.IsDeleted = 0
          AND dl.MoeinId = @MoeinId

        UNION ALL

        SELECT
            dl.LinkId,
            dl.ParentLinkId,
            dl.MoeinId,
            dl.DetilId,
            parent.TreeLevel + 1,
            CAST(parent.AccountCode + bd.DetilCode AS NVARCHAR(4000)),
            bd.DetilCode,
            bd.Title,
            bd.AccountNature
        FROM [accounting].[BaseDetilLink] dl
        INNER JOIN DetailPaths parent
            ON parent.LinkId = dl.ParentLinkId
           AND parent.MoeinId = dl.MoeinId
        INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
        WHERE dl.IsDeleted = 0
    ),
    CanonicalPaths AS (
        SELECT path.*,
               ROW_NUMBER() OVER (PARTITION BY path.AccountCode ORDER BY path.LinkId) AS PathRank
        FROM DetailPaths path
    )
    SELECT
        path.LinkId AS NodeId,
        path.TreeLevel AS [Level],
        path.DetilCode AS Code,
        path.Title,
        N'BaseDetil' AS NodeType,
        m.ColId,
        path.MoeinId,
        path.DetilId,
        path.LinkId,
        path.ParentLinkId,
        (
            SELECT COUNT(*)
            FROM DetailPaths child
            WHERE child.ParentLinkId = path.LinkId
        ) AS ChildCount,
        path.AccountCode,
        path.AccountNature,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) AS Debit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) AS Credit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit - l.Credit ELSE 0 END), 0) AS Balance
    FROM CanonicalPaths path
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = path.MoeinId
    LEFT JOIN [accounting].[DocumentLines] l ON l.AccountCode LIKE path.AccountCode + N'%'
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0
        AND d.DocumentDate BETWEEN @From AND @To
        AND (@Status IS NULL OR d.Status = @Status)
        AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
    WHERE path.PathRank = 1
      AND (
          (@ParentLinkId IS NULL AND path.ParentLinkId IS NULL)
          OR path.ParentLinkId = @ParentLinkId
      )
    GROUP BY
        path.LinkId,
        path.TreeLevel,
        path.DetilCode,
        path.Title,
        m.ColId,
        path.MoeinId,
        path.DetilId,
        path.ParentLinkId,
        path.AccountCode,
        path.AccountNature
    HAVING ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) <> 0
        OR ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) <> 0
    ORDER BY path.AccountCode, path.LinkId
    OPTION (MAXRECURSION 32767);
END
