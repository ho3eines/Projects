-- =============================================
-- Tarazin.Data/Scripts/central/AuditSearch.sql
-- Schema: central
-- Query. Audit trail viewer (صفحهٔ /central/audit).
-- CompanyId NULL = عملیات سطح-central/سیستمی (ADR-004) — هرگز backfill نشود.
-- فیلتر CompanyFilter: 'all' = همه | 'null' = فقط سیستمی (NULL) | عدد = شرکت خاص
-- =============================================
DECLARE @From DATE = TRY_CONVERT(DATE, @FromDate);
DECLARE @To DATE = TRY_CONVERT(DATE, @ToDate);
DECLARE @Schema NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@SchemaName)), N'');
DECLARE @Script NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@ScriptName)), N'');
DECLARE @FilterCompany NVARCHAR(20) = NULLIF(LTRIM(RTRIM(@CompanyFilter)), N'');

SELECT
    a.AuditId,
    a.CompanyId,
    c.CompanyName,
    a.SchemaName,
    a.ScriptName,
    a.UserTokenId,
    a.RequestId,
    a.Outcome,
    a.RowHash,
    a.CreatedAt,
    COUNT_BIG(*) OVER() AS TotalRows
FROM [central].[AuditLog] a
LEFT JOIN [central].[Companies] c ON c.CompanyId = a.CompanyId
WHERE (@Schema IS NULL OR a.SchemaName = @Schema)
  AND (@Script IS NULL OR a.ScriptName LIKE N'%' + @Script + N'%')
  AND (@From IS NULL OR CAST(a.CreatedAt AS DATE) >= @From)
  AND (@To IS NULL OR CAST(a.CreatedAt AS DATE) <= @To)
  AND (
        @FilterCompany = 'all'
        OR (@FilterCompany = 'null' AND a.CompanyId IS NULL)
        OR (@FilterCompany NOT IN ('all', 'null') AND a.CompanyId = TRY_CONVERT(INT, @FilterCompany))
      )
ORDER BY a.AuditId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
