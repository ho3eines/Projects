-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartNodeBreadcrumb.sql
-- Schema: accounting
-- برگرداندن مسیر کامل (Breadcrumb) یک Node خاص.
-- پارامترها: @NodeId, @NodeType ('BaseCol' | 'BaseMoein' | 'BaseDetil'), @LinkId (برای Detil در مسیر خاص)
-- خروجی: مسیر از ریشه تا این Node به‌صورت ردیف‌هایی (NodeId, Level, Title, Code, AccountCode).
-- =============================================
DECLARE @ColId    INT = NULL;
DECLARE @MoeinId  INT = NULL;
DECLARE @DetilId  INT = NULL;
DECLARE @AccountCode NVARCHAR(200) = N'';
DECLARE @OutPath  NVARCHAR(200) = N'';

IF @NodeType = N'BaseCol'
BEGIN
    SET @ColId = @NodeId;
    SELECT @OutPath = ColCode FROM [accounting].[BaseCol] WHERE ColId = @ColId AND IsDeleted = 0;
END
ELSE IF @NodeType = N'BaseMoein'
BEGIN
    SET @MoeinId = @NodeId;
    SELECT @OutPath = c.ColCode + m.MoeinCode, @ColId = m.ColId
    FROM [accounting].[BaseMoein] m
    JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId
    WHERE m.MoeinId = @MoeinId AND m.IsDeleted = 0 AND c.IsDeleted = 0;
END
ELSE IF @NodeType = N'BaseDetil'
BEGIN
    SET @DetilId = @NodeId;
    -- از LinkId مسیر را تشخیص می‌دهیم
    SELECT @OutPath = c.ColCode + m.MoeinCode + d.DetilCode,
           @MoeinId = dl.MoeinId,
           @ColId   = m.ColId,
           @DetilId = dl.DetilId
    FROM [accounting].[BaseDetilLink] dl
    JOIN [accounting].[BaseMoein] m  ON m.MoeinId  = dl.MoeinId
    JOIN [accounting].[BaseCol]   c  ON c.ColId    = m.ColId
    JOIN [accounting].[BaseDetil] d  ON d.DetilId  = dl.DetilId
    WHERE ((@LinkId IS NOT NULL AND dl.LinkId = @LinkId)
        OR (@LinkId IS NULL AND dl.DetilId = @DetilId))
      AND dl.IsDeleted = 0 AND m.IsDeleted = 0 AND c.IsDeleted = 0 AND d.IsDeleted = 0;
END

;WITH Path AS (
    SELECT
        c.ColId AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title, c.IsActive,
        N'BaseCol' AS NodeType, NULL AS ParentId, CAST(c.ColCode AS NVARCHAR(200)) AS AccountCode
    FROM [accounting].[BaseCol] c
    WHERE c.ColId = @ColId AND c.IsDeleted = 0

    UNION ALL

    SELECT
        m.MoeinId, 2, m.MoeinCode, m.Title, m.IsActive, N'BaseMoein', m.ColId,
        CAST(p.AccountCode + m.MoeinCode AS NVARCHAR(200))
    FROM [accounting].[BaseMoein] m
    JOIN Path p ON p.NodeId = m.ColId
    WHERE m.IsDeleted = 0

    UNION ALL

    SELECT
        d.DetilId, 3, d.DetilCode, d.Title, d.IsActive, N'BaseDetil', dl.LinkId,
        CAST(p.AccountCode + d.DetilCode AS NVARCHAR(200))
    FROM [accounting].[BaseDetilLink] dl
    JOIN Path p ON p.NodeId = dl.MoeinId
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0 AND d.IsDeleted = 0
)
SELECT NodeId, Level, Code, Title, IsActive, NodeType, ParentId, AccountCode
FROM Path
ORDER BY Level;
