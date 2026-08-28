-- =============================================
-- Tarazin.Data/Scripts/payroll/EmploymentOrderDelete.sql
-- Schema: payroll
-- Execute. حذف حکم اداری
-- =============================================
DELETE FROM [payroll].[EmploymentOrders]
WHERE OrderId = @OrderId;
