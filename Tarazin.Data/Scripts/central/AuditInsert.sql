-- =============================================
-- Tarazin.Data/Scripts/central/AuditInsert.sql
-- Schema: central
-- Execute. ثبت ردیف ممیزی با زنجیرهٔ هش (PrevHash از سرویس ممیزی می‌آید).
-- Mobile callers cannot choose audit ownership: resolve it from the active,
-- customer-bound broker session even if UI/session context is stale or forged.
-- =============================================
DECLARE @ResolvedCompanyId INT = CASE
    WHEN ORIGINAL_LOGIN() LIKE N'tz_m[_]%'
        THEN [central].[fn_MobileCompanyId]()
    ELSE @CompanyId
END;

INSERT INTO [central].[AuditLog]
    (CompanyId, PrevHash, RowHash, SchemaName, ScriptName, UserTokenId, Outcome, Error, CreatedAt)
VALUES
    (@ResolvedCompanyId, @PrevHash, @RowHash, @SchemaName, @ScriptName, @UserName, @Outcome, @Error, SYSUTCDATETIME());
