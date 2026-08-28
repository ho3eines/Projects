-- =============================================
-- Tarazin.Data/Scripts/payroll/SalaryTemplateUpsert.sql
-- Schema: payroll
-- Execute. ایجاد یا ویرایش الگوی قلم حقوق
-- =============================================
IF @TemplateId = 0
BEGIN
    INSERT INTO [payroll].[SalaryTemplates]
        (Title, Category, IsPercent, Percentage, FixedAmount,
         SortOrder, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (@Title, ISNULL(@Category, N'Earning'), ISNULL(@IsPercent, 0), @Percentage, @FixedAmount,
         ISNULL(@SortOrder, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [payroll].[SalaryTemplates]
    SET Title       = @Title,
        Category    = ISNULL(@Category, Category),
        IsPercent   = ISNULL(@IsPercent, IsPercent),
        Percentage  = @Percentage,
        FixedAmount = @FixedAmount,
        SortOrder   = ISNULL(@SortOrder, SortOrder),
        IsActive    = ISNULL(@IsActive, IsActive),
        UpdatedAt   = SYSUTCDATETIME(),
        UpdatedBy   = @CreatedBy
    WHERE TemplateId = @TemplateId;
END
