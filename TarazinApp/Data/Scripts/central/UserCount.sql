-- =============================================
-- TarazinApp/Data/Scripts/central/UserCount.sql
-- Schema: central
-- Query. تعداد کاربران فعال — برای bootstrap اولین مدیر در اولین اجرا.
-- =============================================
SELECT COUNT(*)
FROM [central].[Users]
WHERE IsDeleted = 0;
