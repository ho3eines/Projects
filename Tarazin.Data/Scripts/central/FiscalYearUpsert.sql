-- =============================================
-- Tarazin.Data/Scripts/central/FiscalYearUpsert.sql
-- Schema: central
-- Execute. Create or update a fiscal year.
-- =============================================
IF @FiscalYearId = 0
BEGIN
    INSERT INTO [central].[FiscalYears] (CompanyId, YearName, StartDate, EndDate, IsActive, CreatedAt, CreatedBy)
    VALUES (@CompanyId, @YearName, @StartDate, @EndDate, @IsActive, SYSUTCDATETIME(), @CreatedBy);
    
    DECLARE @NewFiscalYearId INT = SCOPE_IDENTITY();
    SELECT @NewFiscalYearId AS NewId;
END
ELSE
BEGIN
    UPDATE [central].[FiscalYears]
    SET YearName = @YearName,
        StartDate = @StartDate,
        EndDate = @EndDate,
        IsActive = @IsActive,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE FiscalYearId = @FiscalYearId AND IsDeleted = 0;
    
    SELECT @FiscalYearId AS NewId;
END
