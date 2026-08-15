-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartNodeBreadcrumb.sql
-- Schema: accounting
-- مسیر کامل (Breadcrumb) یک Node خاص.
--
-- قرارداد پارامترها (همان چیزی که UI می‌فرستد):
--   @NodeId   : شناسهٔ گره (ColId | MoeinId | DetilId بسته به @NodeType)
--   @NodeType : BaseCol | BaseMoein | BaseDetil
--   @LinkId   : فقط برای BaseDetil — مشخص‌کنندهٔ «کدام مسیر» (یک تفصیلی
--               می‌تواند زیر چند معین باشد). NULL = اولین مسیر فعال.
--
-- ⚠ باگ تاریخی (رفع شد): نسخهٔ قبلی به @ColId/@MoeinId/@DetilId نیاز داشت که
--   هیچ‌کدام از فراخوان‌ها (AccountingChart و AccountPickerDialog) آن‌ها را
--   نمی‌فرستادند → خطای «Must declare the scalar variable @ColId» (Msg 137).
--   چون فراخوانی داخل try/catch بی‌صدا بود، Breadcrumb همیشه خالی می‌ماند.
-- =============================================
DECLARE @Type    NVARCHAR(20) = ISNULL(NULLIF(LTRIM(RTRIM(@NodeType)), N''), N'');
DECLARE @ColRef   INT = NULL;
DECLARE @MoeinRef INT = NULL;
DECLARE @DetilRef INT = NULL;

IF @Type = N'BaseCol'
BEGIN
    SET @ColRef = @NodeId;
END
ELSE IF @Type = N'BaseMoein'
BEGIN
    SET @MoeinRef = @NodeId;
    SELECT @ColRef = m.ColId
    FROM [accounting].[BaseMoein] m
    WHERE m.MoeinId = @MoeinRef AND m.IsDeleted = 0;
END
ELSE IF @Type = N'BaseDetil'
BEGIN
    SET @DetilRef = @NodeId;

    -- مسیر انتخابی: اگر LinkId داده شده همان، وگرنه اولین پیوند فعال.
    SELECT TOP (1) @MoeinRef = dl.MoeinId
    FROM [accounting].[BaseDetilLink] dl
    WHERE dl.DetilId = @DetilRef
      AND dl.IsDeleted = 0
      AND (@LinkId IS NULL OR dl.LinkId = @LinkId)
    ORDER BY CASE WHEN dl.LinkId = @LinkId THEN 0 ELSE 1 END, dl.IsActive DESC, dl.LinkId;

    SELECT @ColRef = m.ColId
    FROM [accounting].[BaseMoein] m
    WHERE m.MoeinId = @MoeinRef AND m.IsDeleted = 0;
END

SELECT NodeId, Level, Code, Title, IsActive, NodeType, ParentId, AccountCode
FROM (
    -- سطح ۱ — حساب کل
    SELECT
        c.ColId AS NodeId, 1 AS Level, c.ColCode AS Code, c.Title, c.IsActive,
        N'BaseCol' AS NodeType, CAST(NULL AS INT) AS ParentId,
        CAST(c.ColCode AS NVARCHAR(200)) AS AccountCode
    FROM [accounting].[BaseCol] c
    WHERE @ColRef IS NOT NULL AND c.ColId = @ColRef AND c.IsDeleted = 0

    UNION ALL

    -- سطح ۲ — حساب معین
    SELECT
        m.MoeinId AS NodeId, 2 AS Level, m.MoeinCode AS Code, m.Title, m.IsActive,
        N'BaseMoein' AS NodeType, m.ColId AS ParentId,
        CAST(c.ColCode + m.MoeinCode AS NVARCHAR(200)) AS AccountCode
    FROM [accounting].[BaseMoein] m
    INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
    WHERE @MoeinRef IS NOT NULL AND m.MoeinId = @MoeinRef AND m.IsDeleted = 0

    UNION ALL

    -- سطح ۳ — تفصیلی (در همان مسیر)
    SELECT
        d.DetilId AS NodeId, 3 AS Level, d.DetilCode AS Code, d.Title, d.IsActive,
        N'BaseDetil' AS NodeType, @MoeinRef AS ParentId,
        CAST(ISNULL(c.ColCode, N'') + ISNULL(m.MoeinCode, N'') + d.DetilCode AS NVARCHAR(200)) AS AccountCode
    FROM [accounting].[BaseDetil] d
    LEFT JOIN [accounting].[BaseMoein] m ON m.MoeinId = @MoeinRef AND m.IsDeleted = 0
    LEFT JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId   AND c.IsDeleted = 0
    WHERE @DetilRef IS NOT NULL AND d.DetilId = @DetilRef AND d.IsDeleted = 0
) steps
ORDER BY Level
OPTION (RECOMPILE);
