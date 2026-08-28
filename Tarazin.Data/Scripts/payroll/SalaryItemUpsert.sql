-- =============================================
-- Tarazin.Data/Scripts/payroll/SalaryItemUpsert.sql
-- Schema: payroll
-- Execute. اقلام حقوق (پایه، مزایا، کسورات).
-- =============================================
-- SalaryItemId=0 identifies a new record; every non-zero id is an edit.
IF @SalaryItemId = 0
BEGIN
    INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt, CreatedBy)
    SELECT @EmployeeId, @Period, @Title, @Amount, ISNULL(@IsDeduction, 0), SYSUTCDATETIME(), @CreatedBy
    WHERE EXISTS (SELECT 1 FROM [payroll].[Employees] e WHERE e.EmployeeId = @EmployeeId AND e.IsDeleted = 0 AND (@CompanyId IS NULL OR e.CompanyId = @CompanyId));
END
ELSE
BEGIN
    UPDATE [payroll].[SalaryItems]
    SET Title       = @Title,
        Amount      = @Amount,
        IsDeduction = ISNULL(@IsDeduction, IsDeduction),
        UpdatedAt   = SYSUTCDATETIME(),
        UpdatedBy   = @CreatedBy
    WHERE SalaryItemId = @SalaryItemId
      AND EXISTS (SELECT 1 FROM [payroll].[Employees] e WHERE e.EmployeeId = (SELECT EmployeeId FROM [payroll].[SalaryItems] WHERE SalaryItemId = @SalaryItemId) AND (@CompanyId IS NULL OR e.CompanyId = @CompanyId));
END
