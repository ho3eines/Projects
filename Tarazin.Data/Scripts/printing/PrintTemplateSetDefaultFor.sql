-- =============================================
-- Tarazin.Data/Scripts/printing/PrintTemplateSetDefaultFor.sql
-- یک قالب را «پیش‌فرض»ِ گزارش مشخص می‌کند (DefaultFor) برای شرکتِ درخواست‌کننده
-- بدون دست زدن به سایر فیلدهای قالب. سایر قالب‌هایی که قبلاً پیش‌فرضِ همان
-- گزارش بودند (برای همین شرکت یا سراسری) آزاد می‌شوند.
-- =============================================
SET NOCOUNT ON;

-- حداکثر یک پیش‌فرض برای هر گزارش در هر شرکت: قبلیِ همین شرکت/سراسری آزاد شود
UPDATE [printing].[PrintTemplates]
SET [DefaultFor] = NULL,
    [CompanyId]  = NULL,
    [UpdatedAt]  = SYSUTCDATETIME()
WHERE [DefaultFor] = @ReportId
  AND [Id] <> @TemplateId
  AND (ISNULL([CompanyId], 0) = ISNULL(@CompanyId, 0) OR [CompanyId] IS NULL);

-- قالب هدف پیش‌فرضِ گزارش (دامنهٔ شرکت) شود
UPDATE [printing].[PrintTemplates]
SET [DefaultFor] = @ReportId,
    [CompanyId]  = @CompanyId,
    [UpdatedAt]  = SYSUTCDATETIME(),
    [UpdatedBy]  = @UpdatedBy
WHERE [Id] = @TemplateId;