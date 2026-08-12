-- =============================================
-- HermesApp/Data/Scripts/central/AuditInsert.sql
-- Schema: central
-- Execute. ثبت ردیف ممیزی با زنجیرهٔ هش (PrevHash از سرویس ممیزی می‌آید).
-- =============================================
INSERT INTO [central].[AuditLog]
    (PrevHash, RowHash, SchemaName, ScriptName, UserTokenId, Outcome, Error, CreatedAt)
VALUES
    (@PrevHash, @RowHash, @SchemaName, @ScriptName, @UserName, @Outcome, @Error, SYSUTCDATETIME());
