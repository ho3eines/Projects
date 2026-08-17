-- =============================================
-- Tarazin.Data/Scripts/accounting/DetailAccountSummary.sql
-- Schema: accounting
-- Query. خلاصهٔ حساب تفصیلی در یک placement دقیق.
-- =============================================
DECLARE @From DATE = CAST(@FromDate AS DATE);
DECLARE @To DATE = CAST(@ToDate AS DATE);
DECLARE @Status NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@StatusFilter)), N'');
DECLARE @Number NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@DocumentNumber)), N'');

;WITH DetailPaths AS (
    SELECT dl.LinkId, dl.ParentLinkId, dl.MoeinId, dl.DetilId,
           c.ColId, c.ColCode, c.Title AS ColTitle,
           m.MoeinCode, m.Title AS MoeinTitle,
           bd.DetilCode, bd.Title AS DetilTitle,
           CAST(c.ColCode + m.MoeinCode + bd.DetilCode AS NVARCHAR(4000)) AS AccountCode
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId AND m.IsDeleted = 0
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0 AND c.CompanyId = @CompanyId
    INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
    WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0

    UNION ALL

    SELECT dl.LinkId, dl.ParentLinkId, dl.MoeinId, dl.DetilId,
           p.ColId, p.ColCode, p.ColTitle, p.MoeinCode, p.MoeinTitle,
           bd.DetilCode, bd.Title,
           CAST(p.AccountCode + bd.DetilCode AS NVARCHAR(4000))
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN DetailPaths p ON p.LinkId = dl.ParentLinkId AND p.MoeinId = dl.MoeinId
    INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
    WHERE dl.IsDeleted = 0
),
SelectedPath AS (
    SELECT TOP (1) * FROM DetailPaths WHERE AccountCode = @AccountCode
),
Opening AS (
    SELECT ISNULL(SUM(l.Debit - l.Credit), 0) AS OpeningBalance
    FROM [accounting].[DocumentLines] l
    INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
    WHERE l.AccountCode = @AccountCode AND d.DocumentDate < @From
      AND (@Status IS NULL OR d.Status = @Status)
      AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
),
PeriodTotals AS (
    SELECT ISNULL(SUM(l.Debit), 0) AS Debit, ISNULL(SUM(l.Credit), 0) AS Credit
    FROM [accounting].[DocumentLines] l
    INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
    WHERE l.AccountCode = @AccountCode AND d.DocumentDate BETWEEN @From AND @To
      AND (@Status IS NULL OR d.Status = @Status)
      AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
)
SELECT
    p.DetilId, p.LinkId, p.AccountCode,
    p.DetilCode, p.DetilTitle,
    p.ColId, p.ColCode, p.ColTitle,
    p.MoeinId, p.MoeinCode, p.MoeinTitle,
    o.OpeningBalance,
    t.Debit,
    t.Credit,
    o.OpeningBalance + t.Debit - t.Credit AS FinalBalance
FROM SelectedPath p
CROSS JOIN Opening o
CROSS JOIN PeriodTotals t
OPTION (MAXRECURSION 32767);
