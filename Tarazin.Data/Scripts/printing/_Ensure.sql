-- =============================================
-- Tarazin.Data/Scripts/printing/_Ensure.sql
-- Schema: printing — مدیریت قالب‌های چاپ (موتور چاپ عمومی)
-- هر گزارش/سند می‌تواند قالب چاپ مجزای خود را داشته باشد؛ قالب به‌صورت
-- JSON (ستون‌ها + فیلدهای هدر) ذخیره می‌شود تا در حالت دیزاین قابل ویرایش باشد.
-- =============================================
IF SCHEMA_ID(N'printing') IS NULL
    EXEC(N'CREATE SCHEMA [printing]');
GO

IF OBJECT_ID(N'[printing].[PrintTemplates]', N'U') IS NULL
BEGIN
    CREATE TABLE [printing].[PrintTemplates]
    (
        [Id]                NVARCHAR(80)   NOT NULL PRIMARY KEY,
        [Name]              NVARCHAR(120)  NOT NULL,
        [Description]       NVARCHAR(300)  NULL,
        [Module]            NVARCHAR(40)   NULL,
        [PaperSize]         NVARCHAR(10)   NOT NULL DEFAULT N'A4',
        [Orientation]       NVARCHAR(10)   NOT NULL DEFAULT N'Portrait',
        [MarginMm]          INT            NOT NULL DEFAULT 12,
        [FontSizePt]        REAL           NOT NULL DEFAULT 9,
        [ShowCompanyHeader] BIT            NOT NULL DEFAULT 1,
        [ShowPageFooter]    BIT            NOT NULL DEFAULT 1,
        [ShowReportFooter]  BIT            NOT NULL DEFAULT 1,
        [QrEnabled]         BIT            NOT NULL DEFAULT 1,
        [ReportTitle]       NVARCHAR(200)  NULL,
        [ReportSubtitle]    NVARCHAR(200)  NULL,
        [ColumnsJson]       NVARCHAR(MAX)  NOT NULL,
        [MetaJson]          NVARCHAR(MAX)  NOT NULL,
        [IsSystem]          BIT            NOT NULL DEFAULT 0,
        [DefaultFor]        NVARCHAR(80)   NULL,
        [UpdatedAt]         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
        [UpdatedBy]         NVARCHAR(60)   NULL
    );

    CREATE INDEX [IX_PrintTemplates_Module] ON [printing].[PrintTemplates] ([Module]);
END
GO

-- مهاجرت: ستون DefaultFor برای «قالب سفارشی = پیش‌فرضِ یک گزارش» (بدون تغییر کد)
IF COL_LENGTH(N'[printing].[PrintTemplates]', N'DefaultFor') IS NULL
    ALTER TABLE [printing].[PrintTemplates] ADD [DefaultFor] NVARCHAR(80) NULL;
GO

-- مهاجرت: هر شرکت می‌تواند «پیش‌فرضِ چاپ» جداگانه داشته باشد → CompanyId به قالب اضافه می‌شود
-- (NULL = قالب مشترک/سیستمی یا پیش‌فرضِ سراسری قدیمی؛ غیر-NULL = دامنهٔ آن شرکت).
IF COL_LENGTH(N'[printing].[PrintTemplates]', N'CompanyId') IS NULL
    ALTER TABLE [printing].[PrintTemplates] ADD [CompanyId] INT NULL;
GO

-- ایندکس یکتای قدیمی (سراسری) حذف می‌شود تا جایش را ایندکس‌های per-company بگیرند
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_PrintTemplates_DefaultFor' AND object_id = OBJECT_ID(N'[printing].[PrintTemplates]'))
    DROP INDEX [UQ_PrintTemplates_DefaultFor] ON [printing].[PrintTemplates];
GO

-- حداکثر یک قالب پیش‌فرض برای هر گزارش در هر شرکت (کلید یکتای (CompanyId, DefaultFor))
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_PrintTemplates_DefaultFor_Company' AND object_id = OBJECT_ID(N'[printing].[PrintTemplates]'))
    CREATE UNIQUE INDEX [UQ_PrintTemplates_DefaultFor_Company]
        ON [printing].[PrintTemplates] ([CompanyId], [DefaultFor])
        WHERE [DefaultFor] IS NOT NULL AND [CompanyId] IS NOT NULL;
GO

-- حداکثر یک «پیش‌فرضِ سراسری» برای هر گزارش (CompanyId NULL — قالب‌های قدیمی/مشترک)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_PrintTemplates_DefaultFor_Global' AND object_id = OBJECT_ID(N'[printing].[PrintTemplates]'))
    CREATE UNIQUE INDEX [UQ_PrintTemplates_DefaultFor_Global]
        ON [printing].[PrintTemplates] ([DefaultFor])
        WHERE [DefaultFor] IS NOT NULL AND [CompanyId] IS NULL;
GO
