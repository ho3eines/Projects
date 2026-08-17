-- =============================================
-- Tarazin.Data/Scripts/central/CompanyUpsert.sql
-- Schema: central
-- Execute. Create or update a company.
-- =============================================
IF @CompanyId = 0
BEGIN
    INSERT INTO [central].[Companies] (CompanyName, IsActive, CreatedAt, CreatedBy)
    VALUES (@CompanyName, @IsActive, SYSUTCDATETIME(), @CreatedBy);
    
    DECLARE @NewCompanyId INT = SCOPE_IDENTITY();
    SELECT @NewCompanyId AS NewId;
END
ELSE
BEGIN
    UPDATE [central].[Companies]
    SET CompanyName = @CompanyName,
        IsActive = @IsActive,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE CompanyId = @CompanyId AND IsDeleted = 0;
    
    SELECT @CompanyId AS NewId;
END
