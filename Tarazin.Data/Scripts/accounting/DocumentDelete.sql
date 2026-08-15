-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentDelete.sql
-- Schema: accounting
-- Execute. حذف سند حسابداری (حذف نرم — همان قرارداد IsDeleted پروژه).
--
-- قانون: حذف فقط در وضعیت «یادداشت» (Note) و «سند موقت» (Draft) مجاز است؛
-- سند «تأیید شده»/«تأیید نهایی» بخشی از دفاتر رسمی است و حذف نمی‌شود.
-- کنترل در همین اسکریپت انجام می‌شود تا با فراخوانی مستقیم قابل دور زدن نباشد.
-- =============================================
DECLARE @CurrentStatus NVARCHAR(50);

SELECT @CurrentStatus = d.Status
FROM [accounting].[Documents] d
WHERE d.DocumentId = @DocumentId AND d.IsDeleted = 0;

IF @CurrentStatus IS NULL
    THROW 51045, N'سند پیدا نشد یا قبلاً حذف شده است', 1;

IF @CurrentStatus NOT IN (N'Note', N'Draft')
    THROW 51047, N'سند تأییدشده یا تأیید نهایی قابل حذف نیست.', 1;

UPDATE [accounting].[Documents]
SET IsDeleted = 1,
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @UpdatedBy
WHERE DocumentId = @DocumentId AND IsDeleted = 0;

IF @@ROWCOUNT = 0
    THROW 51045, N'سند پیدا نشد یا قبلاً حذف شده است', 1;
