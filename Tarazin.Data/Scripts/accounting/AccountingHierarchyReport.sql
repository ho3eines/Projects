-- =============================================
-- Tarazin.Data/Scripts/accounting/AccountingHierarchyReport.sql
-- Schema: accounting
-- Query. گزارش سلسله‌مراتبی واقعی؛ هر فراخوان فقط یک سطح را برمی‌گرداند.
-- @Level: 1=کل، 2=معینِ یک کل، 3=تفصیلی‌های یک معین.
-- مبنای اتصال گردش، AccountCode ذخیره‌شده روی ردیف سند است تا placementهای
-- مشترک یک تفصیلی با یکدیگر ترکیب نشوند.
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
        CAST(c.ColCode AS NVARCHAR(4000)) AS AccountCode,
        CAST(NULL AS NVARCHAR(30)) AS AccountNature,
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
    GROUP BY c.ColId, c.ColCode, c.Title
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
        CAST(c.ColCode + m.MoeinCode AS NVARCHAR(4000)) AS AccountCode,
        CAST(NULL AS NVARCHAR(30)) AS AccountNature,
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
    GROUP BY m.MoeinId, m.ColId, m.MoeinCode, m.Title, c.ColCode
    HAVING ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) <> 0
        OR ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) <> 0
    ORDER BY m.MoeinCode;
    RETURN;
END

IF @Level = 3
BEGIN
    ;WITH DetailPaths AS (
        SELECT
            dl.LinkId, dl.ParentLinkId, dl.MoeinId, dl.DetilId, 3 AS TreeLevel,
            CAST(c.ColCode + m.MoeinCode + bd.DetilCode AS NVARCHAR(4000)) AS AccountCode,
            bd.DetilCode, bd.Title
        FROM [accounting].[BaseDetilLink] dl
        INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId AND m.IsDeleted = 0
        INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
        INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
        WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0 AND dl.MoeinId = @MoeinId

        UNION ALL

        SELECT
            dl.LinkId, dl.ParentLinkId, dl.MoeinId, dl.DetilId, p.TreeLevel + 1,
            CAST(p.AccountCode + bd.DetilCode AS NVARCHAR(4000)),
            bd.DetilCode, bd.Title
        FROM [accounting].[BaseDetilLink] dl
        INNER JOIN DetailPaths p ON p.LinkId = dl.ParentLinkId AND p.MoeinId = dl.MoeinId
        INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
        WHERE dl.IsDeleted = 0
    ),
    CanonicalPaths AS (
        SELECT p.*,
               ROW_NUMBER() OVER (PARTITION BY p.AccountCode ORDER BY p.LinkId) AS PathRank
        FROM DetailPaths p
    )
    SELECT
        p.LinkId AS NodeId,
        p.TreeLevel AS [Level],
        p.DetilCode AS Code,
        p.Title,
        N'BaseDetil' AS NodeType,
        m.ColId,
        p.MoeinId,
        p.DetilId,
        p.LinkId,
        p.AccountCode,
        CAST(NULL AS NVARCHAR(30)) AS AccountNature,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) AS Debit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) AS Credit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit - l.Credit ELSE 0 END), 0) AS Balance
    FROM CanonicalPaths p
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = p.MoeinId
    LEFT JOIN [accounting].[DocumentLines] l ON l.AccountCode = p.AccountCode
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0
        AND d.DocumentDate BETWEEN @From AND @To
        AND (@Status IS NULL OR d.Status = @Status)
        AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
    WHERE p.PathRank = 1
    GROUP BY p.LinkId, p.TreeLevel, p.DetilCode, p.Title, m.ColId, p.MoeinId, p.DetilId, p.AccountCode
    HAVING ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) <> 0
        OR ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) <> 0
    ORDER BY p.AccountCode, p.LinkId
    OPTION (MAXRECURSION 32767);
END
