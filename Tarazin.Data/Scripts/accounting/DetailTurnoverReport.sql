-- =============================================
-- Tarazin.Data/Scripts/accounting/DetailTurnoverReport.sql
-- Schema: accounting
-- گزارش «گردش تفصیلی» — بر پایهٔ خودِ موجودیت تفصیلی (@DetilId)، نه یک مسیر حساب.
--
-- مسیر مرور (طبق نیاز کاربر):
--   @Level = 1 → حساب‌های کل که این تفصیلی در آن‌ها بدهکار/بستانکار شده است.
--   @Level = 2 → حساب‌های معینِ آن کل (@ColId) که این تفصیلی در آن‌ها گردش دارد.
--   @Level = 3 → محل‌های قرارگیری (placement) همین تفصیلی زیر آن معین (@MoeinId).
--   @Level = 4 → فرزندان مستقیم یک placement (@ParentLinkId) — تا آخرین برگ.
--
-- جمع هر ردیف = گردش کل زیردرختِ آن مسیر (AccountCode LIKE prefix)، پس والدها
-- همیشه جمع فرزندان را نشان می‌دهند و فقط برگ نهایی به گردش/سند می‌رود.
-- خروجی هم‌شکل AccountingHierarchyRow است تا UI یک جدول مشترک داشته باشد.
-- =============================================
DECLARE @From DATE = CAST(@FromDate AS DATE);
DECLARE @To DATE = CAST(@ToDate AS DATE);
DECLARE @Status NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@StatusFilter)), N'');
DECLARE @Number NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@DocumentNumber)), N'');

CREATE TABLE #DetilTree (
    LinkId        INT NOT NULL,
    ParentLinkId  INT NULL,
    MoeinId       INT NOT NULL,
    DetilId       INT NOT NULL,
    TreeLevel     INT NOT NULL,
    ColId         INT NOT NULL,
    ColCode       NVARCHAR(10) NOT NULL,
    ColTitle      NVARCHAR(200) NOT NULL,
    ColNature     NVARCHAR(10) NOT NULL,
    MoeinCode     NVARCHAR(10) NOT NULL,
    MoeinTitle    NVARCHAR(200) NOT NULL,
    MoeinNature   NVARCHAR(10) NOT NULL,
    DetilCode     NVARCHAR(20) NOT NULL,
    DetilTitle    NVARCHAR(200) NOT NULL,
    DetilNature   NVARCHAR(10) NOT NULL,
    AccountCode   NVARCHAR(400) NOT NULL,
    PathRank      INT NOT NULL
);

;WITH DetailTree AS (
    SELECT
        dl.LinkId,
        dl.ParentLinkId,
        dl.MoeinId,
        dl.DetilId,
        3 AS TreeLevel,
        c.ColId,
        c.ColCode,
        c.Title AS ColTitle,
        c.AccountNature AS ColNature,
        m.MoeinCode,
        m.Title AS MoeinTitle,
        m.AccountNature AS MoeinNature,
        bd.DetilCode,
        bd.Title AS DetilTitle,
        bd.AccountNature AS DetilNature,
        CAST(c.ColCode + m.MoeinCode + bd.DetilCode AS NVARCHAR(400)) AS AccountCode
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId AND m.IsDeleted = 0
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0 AND c.CompanyId = @CompanyId
    INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
    WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0

    UNION ALL

    SELECT
        dl.LinkId,
        dl.ParentLinkId,
        dl.MoeinId,
        dl.DetilId,
        p.TreeLevel + 1,
        p.ColId,
        p.ColCode,
        p.ColTitle,
        p.ColNature,
        p.MoeinCode,
        p.MoeinTitle,
        p.MoeinNature,
        bd.DetilCode,
        bd.Title,
        bd.AccountNature,
        CAST(p.AccountCode + bd.DetilCode AS NVARCHAR(400))
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN DetailTree p ON p.LinkId = dl.ParentLinkId AND p.MoeinId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
    WHERE dl.IsDeleted = 0
)
INSERT INTO #DetilTree (LinkId, ParentLinkId, MoeinId, DetilId, TreeLevel, ColId, ColCode,
                        ColTitle, ColNature, MoeinCode, MoeinTitle, MoeinNature,
                        DetilCode, DetilTitle, DetilNature, AccountCode, PathRank)
SELECT LinkId, ParentLinkId, MoeinId, DetilId, TreeLevel, ColId, ColCode,
       ColTitle, ColNature, MoeinCode, MoeinTitle, MoeinNature,
       DetilCode, DetilTitle, DetilNature, AccountCode,
       -- مسیرهای تکراری (یک AccountCode از چند Link) فقط یک‌بار جمع می‌شوند تا
       -- گردشِ والدها دوبار شمرده نشود.
       ROW_NUMBER() OVER (PARTITION BY AccountCode ORDER BY LinkId)
FROM DetailTree
OPTION (MAXRECURSION 32767);

CREATE INDEX IX_DetilTree_Link ON #DetilTree(LinkId);
CREATE INDEX IX_DetilTree_Parent ON #DetilTree(ParentLinkId);
CREATE INDEX IX_DetilTree_Detil ON #DetilTree(DetilId);

-- گردش زیردرختِ هر مسیر (فقط برای linkهایی که در این سطح لازم است).
IF @Level = 1
BEGIN
    SELECT
        t.ColId AS NodeId,
        1 AS [Level],
        t.ColCode AS Code,
        t.ColTitle AS Title,
        N'BaseCol' AS NodeType,
        t.ColId,
        CAST(NULL AS INT) AS MoeinId,
        CAST(NULL AS INT) AS DetilId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS ParentLinkId,
        COUNT(DISTINCT t.MoeinId) AS ChildCount,
        CAST(t.ColCode AS NVARCHAR(4000)) AS AccountCode,
        t.ColNature AS AccountNature,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) AS Debit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) AS Credit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit - l.Credit ELSE 0 END), 0) AS Balance
    FROM #DetilTree t
    LEFT JOIN [accounting].[DocumentLines] l ON l.AccountCode LIKE t.AccountCode + N'%'
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
        AND d.DocumentDate BETWEEN @From AND @To
        AND (@Status IS NULL OR d.Status = @Status)
        AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
    WHERE t.DetilId = @DetilId
      AND t.PathRank = 1
    GROUP BY t.ColId, t.ColCode, t.ColTitle, t.ColNature
    HAVING ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) <> 0
        OR ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) <> 0
    ORDER BY t.ColCode;
END
ELSE IF @Level = 2
BEGIN
    SELECT
        t.MoeinId AS NodeId,
        2 AS [Level],
        t.MoeinCode AS Code,
        t.MoeinTitle AS Title,
        N'BaseMoein' AS NodeType,
        t.ColId,
        t.MoeinId,
        CAST(NULL AS INT) AS DetilId,
        CAST(NULL AS INT) AS LinkId,
        CAST(NULL AS INT) AS ParentLinkId,
        COUNT(DISTINCT t.LinkId) AS ChildCount,
        CAST(t.ColCode + t.MoeinCode AS NVARCHAR(4000)) AS AccountCode,
        t.MoeinNature AS AccountNature,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) AS Debit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) AS Credit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit - l.Credit ELSE 0 END), 0) AS Balance
    FROM #DetilTree t
    LEFT JOIN [accounting].[DocumentLines] l ON l.AccountCode LIKE t.AccountCode + N'%'
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
        AND d.DocumentDate BETWEEN @From AND @To
        AND (@Status IS NULL OR d.Status = @Status)
        AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
    WHERE t.DetilId = @DetilId
      AND t.ColId = @ColId
      AND t.PathRank = 1
    GROUP BY t.ColId, t.MoeinId, t.ColCode, t.MoeinCode, t.MoeinTitle, t.MoeinNature
    HAVING ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) <> 0
        OR ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) <> 0
    ORDER BY t.MoeinCode;
END
ELSE
BEGIN
    -- سطح ۳: خودِ placementهای این تفصیلی زیر معین انتخاب‌شده.
    -- سطح ۴+: فرزندان مستقیم یک placement (@ParentLinkId) — هر تفصیلی زیرین.
    SELECT
        t.LinkId AS NodeId,
        t.TreeLevel AS [Level],
        t.DetilCode AS Code,
        t.DetilTitle AS Title,
        N'BaseDetil' AS NodeType,
        t.ColId,
        t.MoeinId,
        t.DetilId,
        t.LinkId,
        t.ParentLinkId,
        (SELECT COUNT(*) FROM #DetilTree child WHERE child.ParentLinkId = t.LinkId AND child.PathRank = 1) AS ChildCount,
        CAST(t.AccountCode AS NVARCHAR(4000)) AS AccountCode,
        t.DetilNature AS AccountNature,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) AS Debit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) AS Credit,
        ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit - l.Credit ELSE 0 END), 0) AS Balance
    FROM #DetilTree t
    LEFT JOIN [accounting].[DocumentLines] l ON l.AccountCode LIKE t.AccountCode + N'%'
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
        AND d.DocumentDate BETWEEN @From AND @To
        AND (@Status IS NULL OR d.Status = @Status)
        AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
    WHERE t.PathRank = 1
      AND (
            (@ParentLinkId IS NULL AND t.DetilId = @DetilId AND t.MoeinId = @MoeinId)
            OR (@ParentLinkId IS NOT NULL AND t.ParentLinkId = @ParentLinkId)
          )
    GROUP BY t.LinkId, t.TreeLevel, t.DetilCode, t.DetilTitle, t.DetilNature,
             t.ColId, t.MoeinId, t.DetilId, t.ParentLinkId, t.AccountCode
    HAVING ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Debit ELSE 0 END), 0) <> 0
        OR ISNULL(SUM(CASE WHEN d.DocumentId IS NOT NULL THEN l.Credit ELSE 0 END), 0) <> 0
    ORDER BY t.AccountCode, t.LinkId;
END

DROP TABLE #DetilTree;
