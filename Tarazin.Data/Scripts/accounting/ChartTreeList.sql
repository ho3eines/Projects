-- =============================================
-- Tarazin.Data/Scripts/accounting/ChartTreeList.sql
-- Schema: accounting
-- برگرداندن کل درخت حساب‌ها به‌صورت مسطح با سلسله‌مراتب:
--   Level 1: BaseCol
--   Level 2: BaseMoein (ColId → BaseCol)
--   Level 3: BaseDetil از طریق BaseDetilLink (MoeinId → BaseMoein)
--   Level 4+: BaseDetilهایی که خودشان والد سایر DetilLinkها هستند (multi-level detail)
--
-- هر ردیف شامل AccountCode ترکیبی مسیر است.
-- همچنین ردیف‌های Level 3 به بعد به ازای هر «مسیر» تکرار می‌شوند
-- (اگر یک تفصیلی در چند مسیر باشد، هر مسیر یک ردیف).
-- =============================================
-- پارامتر @IncludeInactive=0: فقط حساب‌های فعال.
-- @IncludeInactive=1: همه (شامل غیرفعال).
-- برای "نمایش حساب غیرفعال در جستجو" از @IncludeInactive=1 در کوئری جستجو استفاده می‌شود.

;WITH BaseCols AS (
    SELECT
        c.ColId        AS NodeId,
        1              AS Level,
        CAST(c.ColId AS NVARCHAR(20)) AS IdPath,
        CAST(c.ColCode AS NVARCHAR(200)) AS CodePath,
        c.ColCode      AS Code,
        c.Title        AS Title,
        N'BaseCol'     AS NodeType,
        NULL           AS ParentId,
        c.IsActive     AS IsActive,
        c.IsDeleted    AS IsDeleted
    FROM [accounting].[BaseCol] c
    WHERE c.IsDeleted = 0
      AND (@IncludeInactive = 1 OR c.IsActive = 1)
),
BaseMoeins AS (
    SELECT
        m.MoeinId      AS NodeId,
        2              AS Level,
        CAST(bc.IdPath + N'/' + CAST(m.MoeinId AS NVARCHAR(20)) AS NVARCHAR(200)) AS IdPath,
        CAST(bc.CodePath + m.MoeinCode AS NVARCHAR(200)) AS CodePath,
        m.MoeinCode    AS Code,
        m.Title        AS Title,
        N'BaseMoein'   AS NodeType,
        m.ColId        AS ParentId,
        m.IsActive     AS IsActive,
        m.IsDeleted    AS IsDeleted
    FROM [accounting].[BaseMoein] m
    JOIN BaseCols bc ON bc.NodeId = m.ColId
    WHERE m.IsDeleted = 0
      AND (@IncludeInactive = 1 OR m.IsActive = 1)
),
BaseDetils AS (
    -- Level 3: BaseDetil از طریق BaseDetilLink در مسیر معین فعلی
    SELECT
        d.DetilId      AS NodeId,
        3              AS Level,
        CAST(bm.IdPath + N'/' + CAST(dl.LinkId AS NVARCHAR(20)) AS NVARCHAR(200)) AS IdPath,
        CAST(bm.CodePath + d.DetilCode AS NVARCHAR(200)) AS CodePath,
        d.DetilCode    AS Code,
        d.Title        AS Title,
        N'BaseDetil'   AS NodeType,
        dl.LinkId      AS ParentId,  -- در سطح پیوند
        d.IsActive     AS IsActive,
        d.IsDeleted    AS IsDeleted,
        d.DetilId      AS DetilEntityId,
        dl.LinkId      AS LinkId,
        dl.MoeinId     AS MoeinId
    FROM [accounting].[BaseDetilLink] dl
    JOIN BaseMoeins bm ON bm.NodeId = dl.MoeinId
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    WHERE dl.IsDeleted = 0
      AND d.IsDeleted = 0
      AND (@IncludeInactive = 1 OR (d.IsActive = 1 AND dl.IsActive = 1))
)
SELECT
    NodeId, Level, IdPath, CodePath, Code, Title, NodeType, ParentId, IsActive, IsDeleted,
    -- AccountCode = ترکیب کدهای مسیر. Col+Moein+Detil.
    -- در Level 1 و 2 نیز CodePath فقط شامل کدهای خودشان تا آن سطح است.
    CodePath AS AccountCode,
    -- عنوان کامل مسیر (Breadcrumb): از طریق Cross Apply از جداول پایه
    NULL AS FullPathTitle,
    DetilEntityId, LinkId, MoeinId
FROM (
    SELECT * FROM BaseCols
    UNION ALL
    SELECT * FROM BaseMoeins
    UNION ALL
    SELECT * FROM BaseDetils
) tree
ORDER BY CodePath, Level, Code;
