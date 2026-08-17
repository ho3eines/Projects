-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartNodeBreadcrumb.sql
-- Schema: accounting
-- مسیر کامل یک گره؛ برای BaseDetil، LinkId مسیر دقیق را مشخص می‌کند.
-- سطح‌های ۴ به بعد از زنجیرهٔ ParentLinkId استخراج می‌شوند.
-- =============================================
DECLARE @Type NVARCHAR(20) = ISNULL(NULLIF(LTRIM(RTRIM(@NodeType)), N''), N'');
DECLARE @ColRef INT = NULL;
DECLARE @MoeinRef INT = NULL;
DECLARE @SelectedLinkId INT = NULL;

IF @Type = N'BaseCol'
BEGIN
    SET @ColRef = @NodeId;
END
ELSE IF @Type = N'BaseMoein'
BEGIN
    SET @MoeinRef = @NodeId;
    SELECT @ColRef = m.ColId
    FROM [accounting].[BaseMoein] m
    WHERE m.MoeinId = @MoeinRef AND m.IsDeleted = 0 AND m.CompanyId = @CompanyId;
END
ELSE IF @Type = N'BaseDetil'
BEGIN
    SELECT TOP (1)
        @SelectedLinkId = dl.LinkId,
        @MoeinRef = dl.MoeinId
    FROM [accounting].[BaseDetilLink] dl
    WHERE dl.DetilId = @NodeId
      AND dl.IsDeleted = 0
      AND dl.CompanyId = @CompanyId
      AND (@LinkId IS NULL OR dl.LinkId = @LinkId)
    ORDER BY CASE WHEN dl.LinkId = @LinkId THEN 0 ELSE 1 END, dl.IsActive DESC, dl.LinkId;

    SELECT @ColRef = m.ColId
    FROM [accounting].[BaseMoein] m
    WHERE m.MoeinId = @MoeinRef AND m.IsDeleted = 0 AND m.CompanyId = @CompanyId;
END

;WITH Ancestors AS (
    -- از گره انتخابی به سمت ریشه؛ Depth=0 خود گره است.
    SELECT dl.LinkId, dl.ParentLinkId, dl.DetilId, dl.MoeinId, dl.IsActive, 0 AS Depth
    FROM [accounting].[BaseDetilLink] dl
    WHERE dl.LinkId = @SelectedLinkId AND dl.IsDeleted = 0

    UNION ALL

    SELECT parent.LinkId, parent.ParentLinkId, parent.DetilId,
           parent.MoeinId, parent.IsActive, child.Depth + 1
    FROM [accounting].[BaseDetilLink] parent
    INNER JOIN Ancestors child ON child.ParentLinkId = parent.LinkId
    WHERE parent.IsDeleted = 0 AND parent.MoeinId = child.MoeinId
),
DetailSteps AS (
    SELECT
        a.LinkId,
        a.ParentLinkId,
        a.DetilId,
        a.MoeinId,
        a.IsActive AS LinkIsActive,
        a.Depth,
        MAX(a.Depth) OVER () AS MaxDepth
    FROM Ancestors a
),
BreadcrumbRows AS (
    SELECT
        c.ColId AS NodeId,
        1 AS Level,
        c.ColCode AS Code,
        c.Title,
        c.IsActive,
        N'BaseCol' AS NodeType,
        CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(MAX)) AS AccountCode
    FROM [accounting].[BaseCol] c
    WHERE @ColRef IS NOT NULL AND c.ColId = @ColRef AND c.IsDeleted = 0 AND c.CompanyId = @CompanyId

    UNION ALL

    SELECT
        m.MoeinId,
        2,
        m.MoeinCode,
        m.Title,
        m.IsActive,
        N'BaseMoein',
        m.ColId,
        CAST(c.ColCode + m.MoeinCode AS NVARCHAR(MAX))
    FROM [accounting].[BaseMoein] m
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
    WHERE @MoeinRef IS NOT NULL AND m.MoeinId = @MoeinRef AND m.IsDeleted = 0
      AND m.CompanyId = @CompanyId

    UNION ALL

    SELECT
        d.DetilId,
        3 + (step.MaxDepth - step.Depth),
        d.DetilCode,
        d.Title,
        CAST(CASE WHEN d.IsActive = 1 AND step.LinkIsActive = 1 THEN 1 ELSE 0 END AS BIT),
        N'BaseDetil',
        CASE WHEN step.ParentLinkId IS NULL THEN step.MoeinId ELSE step.ParentLinkId END,
        CAST(c.ColCode + m.MoeinCode + ISNULL(codes.DetailCodes, N'') AS NVARCHAR(MAX))
    FROM DetailSteps step
    INNER JOIN [accounting].[BaseDetil] d ON d.DetilId = step.DetilId AND d.IsDeleted = 0
    INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = step.MoeinId AND m.IsDeleted = 0
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
    OUTER APPLY (
        SELECT STRING_AGG(CAST(pathDetil.DetilCode AS NVARCHAR(MAX)), N'')
                   WITHIN GROUP (ORDER BY pathStep.Depth DESC) AS DetailCodes
        FROM DetailSteps pathStep
        INNER JOIN [accounting].[BaseDetil] pathDetil
            ON pathDetil.DetilId = pathStep.DetilId AND pathDetil.IsDeleted = 0
        WHERE pathStep.Depth >= step.Depth
    ) codes
)
SELECT NodeId, Level, Code, Title, IsActive, NodeType, ParentId, AccountCode
FROM BreadcrumbRows
ORDER BY Level
OPTION (MAXRECURSION 32767, RECOMPILE);
