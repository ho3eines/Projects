-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentDelete.sql
-- Schema: accounting
-- Cross-schema: central
-- Execute. حذف سند حسابداری (حذف نرم — همان قرارداد IsDeleted پروژه).
--
-- قانون: حذف فقط در وضعیت «یادداشت» (Note) و «سند موقت» (Draft) مجاز است؛
-- سند «تأیید شده»/«تأیید نهایی» بخشی از دفاتر رسمی است و حذف نمی‌شود.
-- کنترل در همین اسکریپت انجام می‌شود تا با فراخوانی مستقیم قابل دور زدن نباشد.
-- =============================================
DECLARE @CurrentStatus NVARCHAR(50);

SELECT @CurrentStatus = d.Status
FROM [accounting].[Documents] d
WHERE d.DocumentId = @DocumentId AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId;

IF @CurrentStatus IS NULL
    THROW 51045, N'سند پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت و سال مالی نیست', 1;

-- حذف سند در سال مالی بسته ممنوع است.
IF EXISTS (SELECT 1 FROM [central].[FiscalYears]
           WHERE FiscalYearId = @FiscalYearId AND CompanyId = @CompanyId
             AND ISNULL([Status], N'Open') = N'Closed')
    THROW 51006, N'سال مالی بسته شده است؛ امکان حذف سند وجود ندارد.', 1;

IF @CurrentStatus NOT IN (N'Note', N'Draft')
    THROW 51047, N'سند تأییدشده یا تأیید نهایی قابل حذف نیست.', 1;

UPDATE [accounting].[Documents]
SET IsDeleted = 1,
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @UpdatedBy
WHERE DocumentId = @DocumentId AND IsDeleted = 0 AND CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId;

IF @@ROWCOUNT = 0
    THROW 51045, N'سند پیدا نشد یا قبلاً حذف شده است', 1;
