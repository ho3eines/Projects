-- =============================================
-- Tarazin.Data/Scripts/printing/PrintTemplateDelete.sql
-- حذف قالب چاپ (قالب‌های سیستمی قابل حذف نیستند).
-- =============================================
SET NOCOUNT ON;

DELETE FROM [printing].[PrintTemplates]
WHERE [Id] = @Id
  AND [IsSystem] = 0;
