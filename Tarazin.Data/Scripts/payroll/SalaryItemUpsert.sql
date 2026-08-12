-- =============================================
-- Tarazin.Data/Scripts/payroll/SalaryItemUpsert.sql
-- Schema: payroll
-- Execute. اقلام حقوق (پایه، مزایا، کسورات).
-- =============================================
-- SalaryItemId=0 identifies a new record; every non-zero id is an edit.
IF @SalaryItemId = 0
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
