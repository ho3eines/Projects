-- =============================================
-- Tarazin.Data/Scripts/printing/PrintTemplateUpsert.sql
-- درج/به‌روزرسانی قالب چاپ (ذخیره از حالت دیزاین).
-- DefaultFor به دامنهٔ شرکتِ جاری (CompanyId) محدود می‌شود؛ یعنی هر شرکت
-- می‌تواند «پیش‌فرضِ چاپ» جداگانهٔ همان گزارش داشته باشد.
-- =============================================
SET NOCOUNT ON;

-- حداکثر یک پیش‌فرض برای هر گزارش در هر شرکت: قبلیِ همین شرکت/سراسری آزاد شود
IF @DefaultFor IS NOT NULL AND @DefaultFor <> N''
    UPDATE [printing].[PrintTemplates]
    SET [DefaultFor] = NULL,
        [CompanyId]  = NULL
    WHERE [DefaultFor] = @DefaultFor
      AND [Id] <> @Id
      AND (ISNULL([CompanyId], 0) = ISNULL(@CompanyId, 0) OR [CompanyId] IS NULL);

IF EXISTS (SELECT 1 FROM [printing].[PrintTemplates] WHERE [Id] = @Id)
    UPDATE [printing].[PrintTemplates]
    SET [Name]              = @Name,
        [Description]       = @Description,
        [Module]            = @Module,
        [PaperSize]         = @PaperSize,
        [Orientation]       = @Orientation,
        [MarginMm]          = @MarginMm,
        [FontSizePt]        = @FontSizePt,
        [ShowCompanyHeader] = @ShowCompanyHeader,
        [ShowPageFooter]    = @ShowPageFooter,
        [ShowReportFooter]  = @ShowReportFooter,
        [QrEnabled]         = @QrEnabled,
        [ReportTitle]       = @ReportTitle,
        [ReportSubtitle]    = @ReportSubtitle,
        [ColumnsJson]       = @ColumnsJson,
        [MetaJson]          = @MetaJson,
        [DefaultFor]        = NULLIF(@DefaultFor, N''),
        [CompanyId]         = CASE WHEN NULLIF(@DefaultFor, N'') IS NULL THEN NULL ELSE @CompanyId END,
        [UpdatedAt]         = SYSUTCDATETIME(),
        [UpdatedBy]         = @UpdatedBy
    WHERE [Id] = @Id;
ELSE
    INSERT INTO [printing].[PrintTemplates]
        ([Id], [Name], [Description], [Module], [PaperSize], [Orientation],
         [MarginMm], [FontSizePt], [ShowCompanyHeader], [ShowPageFooter],
         [ShowReportFooter], [QrEnabled], [ReportTitle], [ReportSubtitle],
         [ColumnsJson], [MetaJson], [IsSystem], [DefaultFor], [CompanyId], [UpdatedAt], [UpdatedBy])
    VALUES
        (@Id, @Name, @Description, @Module, @PaperSize, @Orientation,
         @MarginMm, @FontSizePt, @ShowCompanyHeader, @ShowPageFooter,
         @ShowReportFooter, @QrEnabled, @ReportTitle, @ReportSubtitle,
         @ColumnsJson, @MetaJson, @IsSystem, NULLIF(@DefaultFor, N''),
         CASE WHEN NULLIF(@DefaultFor, N'') IS NULL THEN NULL ELSE @CompanyId END,
         SYSUTCDATETIME(), @UpdatedBy);