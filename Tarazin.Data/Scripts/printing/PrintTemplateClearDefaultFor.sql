-- =============================================
-- Tarazin.Data/Scripts/printing/PrintTemplateClearDefaultFor.sql
-- برداشتن «پیش‌فرض بودن» یک قالب برای گزارشِ خودش (DefaultFor = NULL).
-- CompanyId هم به NULL بازگردانده می‌شود تا قالب دوباره مشترک/سراسری شود.
-- =============================================
SET NOCOUNT ON;

UPDATE [printing].[PrintTemplates]
SET [DefaultFor] = NULL,
    [CompanyId]  = NULL,
    [UpdatedAt]  = SYSUTCDATETIME(),
    [UpdatedBy]  = @UpdatedBy
WHERE [Id] = @Id;