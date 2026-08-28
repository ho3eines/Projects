-- =============================================
-- Tarazin.Data/Scripts/payroll/SalaryTemplateList.sql
-- Schema: payroll
-- Query. لیست الگوهای اقلام حقوق (اضافات/کسورات)
-- =============================================
SELECT
    t.TemplateId,
    t.Title,
    t.Category,
    t.IsPercent,
    t.Percentage,
    t.FixedAmount,
    t.SortOrder,
    t.IsActive,
    t.CreatedAt,
    t.UpdatedAt,
    t.CompanyId
FROM [payroll].[SalaryTemplates] t
WHERE t.IsActive = 1
ORDER BY t.Category, t.SortOrder, t.Title;
