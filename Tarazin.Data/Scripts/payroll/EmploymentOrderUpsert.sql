-- =============================================
-- Tarazin.Data/Scripts/payroll/EmploymentOrderUpsert.sql
-- Schema: payroll
-- Execute. ایجاد یا ویرایش حکم اداری
-- =============================================
IF @OrderId = 0
BEGIN
    INSERT INTO [payroll].[EmploymentOrders]
        (EmployeeId, ContractType, StartDate, EndDate, BaseSalary,
         HousingAllowance, FoodAllowance, TransportAllowance,
         InsurancePct, TaxExemptCount, IsActive, Notes, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (@EmployeeId, ISNULL(@ContractType, N'Permanent'), @StartDate, @EndDate, ISNULL(@BaseSalary, 0),
         ISNULL(@HousingAllowance, 0), ISNULL(@FoodAllowance, 0), ISNULL(@TransportAllowance, 0),
         ISNULL(@InsurancePct, 7.00), ISNULL(@TaxExemptCount, 0),
         ISNULL(@IsActive, 1), @Notes, SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [payroll].[EmploymentOrders]
    SET ContractType       = ISNULL(@ContractType, ContractType),
        StartDate          = @StartDate,
        EndDate            = @EndDate,
        BaseSalary         = ISNULL(@BaseSalary, BaseSalary),
        HousingAllowance   = ISNULL(@HousingAllowance, HousingAllowance),
        FoodAllowance      = ISNULL(@FoodAllowance, FoodAllowance),
        TransportAllowance = ISNULL(@TransportAllowance, TransportAllowance),
        InsurancePct       = ISNULL(@InsurancePct, InsurancePct),
        TaxExemptCount     = ISNULL(@TaxExemptCount, TaxExemptCount),
        IsActive           = ISNULL(@IsActive, IsActive),
        Notes              = @Notes,
        UpdatedAt          = SYSUTCDATETIME(),
        UpdatedBy          = @CreatedBy
    WHERE OrderId = @OrderId;
END
