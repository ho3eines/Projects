-- =============================================
-- TarazinApp/Data/Scripts/payroll/SalaryItemUpsert.sql
-- Schema: payroll
-- Execute. اقلام حقوق (پایه، مزایا، کسورات).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] WHERE SalaryItemId = @SalaryItemId)
BEGIN
    INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt)
    VALUES (@EmployeeId, @Period, @Title, @Amount, ISNULL(@IsDeduction, 0), SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [payroll].[SalaryItems]
    SET Title       = @Title,
        Amount      = @Amount,
        IsDeduction = ISNULL(@IsDeduction, IsDeduction)
    WHERE SalaryItemId = @SalaryItemId;
END
