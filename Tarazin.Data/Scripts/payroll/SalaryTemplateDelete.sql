-- =============================================
-- Tarazin.Data/Scripts/payroll/SalaryTemplateDelete.sql
-- Schema: payroll
-- Execute. حذف الگوی قلم حقوق
-- =============================================
DELETE FROM [payroll].[SalaryTemplates]
WHERE TemplateId = @TemplateId;
