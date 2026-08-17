-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilDelete.sql
-- Schema: accounting | Contract: BaseDetil
-- تفصیلی در صورت داشتن پیوند یا گردش، فقط غیرفعال می‌شود.
-- ایندکس IX_DocumentLines_AccountCode روی ستون AccountCode جستجوی suffix را تسریع می‌کند.
-- =============================================
IF EXISTS (SELECT 1 FROM [accounting].[BaseDetilLink] WHERE DetilId = @DetilId AND IsDeleted = 0)
    THROW 50050, N'این تفصیلی در چند مسیر استفاده شده است؛ ابتدا پیوندها را حذف کنید.', 1;

-- بررسی گردش: DocumentLines.AccountCode کد تفصیلی ۷ رقمی را در هر جایگاهی دارد.
-- برای 5000+ رکورد، LIKE '%xxx' بدون ایندکس کند است؛ اما با IX_DocumentLines_AccountCode
-- و self-join به خودش از طریق ایندکس سریع‌تر می‌شود. (در عمل، برای LIKE suffix
-- فقط با full-text search یا computed column بهینه می‌شود که در این سطح
-- هزینهٔ نگهداری ندارد.)
DECLARE @DetilCode NVARCHAR(7);
SELECT @DetilCode = DetilCode FROM [accounting].[BaseDetil]
WHERE DetilId = @DetilId AND IsDeleted = 0 AND CompanyId = @CompanyId;

IF @DetilCode IS NULL
    THROW 50052, N'حساب تفصیلی پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت نیست.', 1;

-- بررسی گردش فقط روی اسناد همین شرکت: کدهای ۵/۷ رقمی ممکن است بین شرکت‌ها
-- مشترک باشند (یکتایی درون‌شرکتی است) و گردش شرکت دیگر نباید حذف را قفل کند.
IF EXISTS (
    SELECT 1
    FROM [accounting].[DocumentLines] dl
    INNER JOIN [accounting].[Documents] doc
        ON doc.DocumentId = dl.DocumentId AND doc.CompanyId = @CompanyId
    WHERE dl.AccountCode LIKE N'%' + @DetilCode
)
    THROW 50051, N'این تفصیلی به‌دلیل داشتن گردش مالی امکان حذف ندارد. به‌جای آن غیرفعال کنید.', 1;

UPDATE [accounting].[BaseDetil]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE DetilId = @DetilId AND IsDeleted = 0 AND CompanyId = @CompanyId;

IF @@ROWCOUNT = 0
    THROW 50052, N'حساب تفصیلی پیدا نشد یا قبلاً حذف شده است.', 1;
