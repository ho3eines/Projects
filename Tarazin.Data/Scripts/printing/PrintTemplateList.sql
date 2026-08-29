-- =============================================
-- Tarazin.Data/Scripts/printing/PrintTemplateList.sql
-- فهرست قالب‌های چاپ (اختیاری: فیلتر ماژول) — برای صفحهٔ مدیریت چاپ.
-- =============================================
SET NOCOUNT ON;

SELECT
    t.[Id],
    t.[Name],
    t.[Description],
    t.[Module],
    t.[PaperSize],
    t.[Orientation],
    t.[MarginMm],
    t.[FontSizePt],
    t.[ShowCompanyHeader],
    t.[ShowPageFooter],
    t.[ShowReportFooter],
    t.[QrEnabled],
    t.[ReportTitle],
    t.[ReportSubtitle],
    t.[IsSystem],
    t.[DefaultFor],
    t.[CompanyId],
    t.[UpdatedAt],
    t.[UpdatedBy]
FROM [printing].[PrintTemplates] t
WHERE (@Module IS NULL OR @Module = N'' OR t.[Module] = @Module)
ORDER BY t.[Module], t.[Name];
