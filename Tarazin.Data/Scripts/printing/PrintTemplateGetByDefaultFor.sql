-- =============================================
-- Tarazin.Data/Scripts/printing/PrintTemplateGetByDefaultFor.sql
-- بارگذاری قالبِ «پیش‌فرض» یک گزارش (DefaultFor) برای شرکتِ درخواست‌کننده.
-- اولویت: قالبِ همان شرکت → قالبِ سراسری (CompanyId NULL — legacy/مشترک).
-- =============================================
SET NOCOUNT ON;

SELECT TOP (1)
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
    t.[ColumnsJson],
    t.[MetaJson],
    t.[IsSystem],
    t.[DefaultFor],
    t.[CompanyId],
    t.[UpdatedAt],
    t.[UpdatedBy]
FROM [printing].[PrintTemplates] t
WHERE t.[DefaultFor] = @ReportId
  AND (t.[CompanyId] = @CompanyId OR t.[CompanyId] IS NULL)
ORDER BY CASE WHEN t.[CompanyId] = @CompanyId THEN 0 ELSE 1 END;