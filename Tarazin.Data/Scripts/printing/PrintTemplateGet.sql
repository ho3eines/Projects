-- =============================================
-- Tarazin.Data/Scripts/printing/PrintTemplateGet.sql
-- بارگذاری یک قالب چاپ با ستون‌های JSON (برای رندر و دیزاین).
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
    t.[ColumnsJson],
    t.[MetaJson],
    t.[IsSystem],
    t.[DefaultFor],
    t.[CompanyId],
    t.[UpdatedAt],
    t.[UpdatedBy]
FROM [printing].[PrintTemplates] t
WHERE t.[Id] = @Id;
