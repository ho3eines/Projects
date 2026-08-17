-- =============================================
-- Tarazin.Data/Scripts/central/CompanyAssignToUser.sql
-- Schema: central
-- Execute. اختصاص یک شرکت مالی به کاربر (ایجاد رکورد دسترسی).
-- Idempotent: اگر قبلاً تخصیص داده شده کاری نمی‌کند.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [central].[UserCompanies] WHERE UserId = @UserId AND CompanyId = @CompanyId)
    INSERT INTO [central].[UserCompanies] (UserId, CompanyId) VALUES (@UserId, @CompanyId);
