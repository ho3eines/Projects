-- =============================================
-- Tarazin.Data/Scripts/payroll/LeaveDelete.sql
-- Schema: payroll
-- Execute. حذف ردیف مرخصی (حذف فیزیکی — دادهٔ سادهٔ حضورغیاب).
-- =============================================
DELETE FROM [payroll].[LeaveRecords]
WHERE LeaveId = @LeaveId AND CompanyId = @CompanyId;
