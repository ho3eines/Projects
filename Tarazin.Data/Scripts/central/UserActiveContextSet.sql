-- =============================================
-- Tarazin.Data/Scripts/central/UserActiveContextSet.sql
-- Schema: central
-- Execute. Set active company and fiscal year for a user.
-- =============================================
IF EXISTS (SELECT 1 FROM [central].[UserActiveContext] WHERE UserId = @UserId)
BEGIN
    UPDATE [central].[UserActiveContext]
    SET ActiveCompanyId = @ActiveCompanyId,
        ActiveFiscalYearId = @ActiveFiscalYearId
    WHERE UserId = @UserId;
END
ELSE
BEGIN
    INSERT INTO [central].[UserActiveContext] (UserId, ActiveCompanyId, ActiveFiscalYearId)
    VALUES (@UserId, @ActiveCompanyId, @ActiveFiscalYearId);
END
