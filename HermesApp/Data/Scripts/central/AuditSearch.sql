-- =============================================
-- HermesApp/Data/Scripts/central/AuditSearch.sql
-- Schema: central
-- Query. Audit trail viewer (صفحهٔ /central/audit).
-- =============================================
SELECT
    a.AuditId,
    a.SchemaName,
    a.ScriptName,
    a.UserTokenId,
    a.RequestId,
    a.Outcome,
    a.RowHash,
    a.CreatedAt
FROM [central].[AuditLog] a
WHERE (@SchemaName IS NULL OR a.SchemaName = @SchemaName)
  AND (@ScriptName IS NULL OR a.ScriptName = @ScriptName)
  AND (@FromDate IS NULL OR CAST(a.CreatedAt AS DATE) >= @FromDate)
  AND (@ToDate IS NULL OR CAST(a.CreatedAt AS DATE) <= @ToDate)
ORDER BY a.AuditId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
