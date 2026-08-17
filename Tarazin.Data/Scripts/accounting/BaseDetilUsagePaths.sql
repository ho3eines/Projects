-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilUsagePaths.sql
-- Schema: accounting
-- تمام placementهای یک موجودیت تفصیلی، در هر عمق و هر مسیر.
-- =============================================
;WITH DetailTree AS (
    SELECT
        dl.LinkId,
        dl.ParentLinkId,
        dl.MoeinId,
        dl.DetilId,
        3 AS Level,
        CAST(c.ColCode + m.MoeinCode + d.DetilCode AS NVARCHAR(4000)) AS AccountCode,
        CAST(c.Title + N' > ' + m.Title + N' > ' + d.Title AS NVARCHAR(4000)) AS PathTitle,
        dl.IsActive AS LinkIsActive,
        c.ColId,
        c.ColCode,
        c.Title AS ColTitle,
        m.MoeinCode,
        m.Title AS MoeinTitle,
        d.DetilCode,
        d.Title AS DetilTitle
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId AND m.IsDeleted = 0
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0 AND c.CompanyId = @CompanyId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId AND d.IsDeleted = 0
    WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0

    UNION ALL

    SELECT
        dl.LinkId,
        dl.ParentLinkId,
        dl.MoeinId,
        dl.DetilId,
        parent.Level + 1,
        CAST(parent.AccountCode + d.DetilCode AS NVARCHAR(4000)),
        CAST(parent.PathTitle + N' > ' + d.Title AS NVARCHAR(4000)),
        dl.IsActive,
        parent.ColId,
        parent.ColCode,
        parent.ColTitle,
        parent.MoeinCode,
        parent.MoeinTitle,
        d.DetilCode,
        d.Title
    FROM [accounting].[BaseDetilLink] dl
    INNER JOIN DetailTree parent ON parent.LinkId = dl.ParentLinkId
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId AND d.IsDeleted = 0
    WHERE dl.IsDeleted = 0 AND dl.MoeinId = parent.MoeinId
)
SELECT
    LinkId,
    ParentLinkId,
    MoeinId,
    DetilId,
    Level,
    LinkIsActive,
    ColId,
    ColCode,
    ColTitle,
    MoeinCode,
    MoeinTitle,
    DetilCode,
    DetilTitle,
    AccountCode,
    PathTitle
FROM DetailTree
WHERE DetilId = @DetilId
ORDER BY AccountCode, LinkId
OPTION (MAXRECURSION 32767, RECOMPILE);
