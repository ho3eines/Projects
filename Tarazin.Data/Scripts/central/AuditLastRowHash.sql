-- =============================================
-- Tarazin.Data/Scripts/central/AuditLastRowHash.sql
-- Schema: central
-- Query. آخرین هش ردیف ممیزی — سر زنجیره برای ردیف بعدی.
-- =============================================
SELECT TOP 1
    a.AuditId,
    a.RowHash,
    a.PrevHash,
    a.SchemaName,
    a.ScriptName,
    a.Outcome,
    a.CreatedAt
FROM [central].[AuditLog] a
ORDER BY a.AuditId DESC;
