-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilDelete.sql
-- Schema: accounting | Contract: BaseDetil
-- تفصیلی در صورت داشتن پیوند یا گردش، فقط غیرفعال می‌شود.
-- =============================================
DECLARE @HasLink  BIT = 0;
DECLARE @HasUsage BIT = 0;

IF EXISTS (SELECT 1 FROM [accounting].[BaseDetilLink] WHERE DetilId = @DetilId AND IsDeleted = 0)
    SET @HasLink = 1;

-- گردش: DocumentLines.AccountCode کد تفصیلی ۷ رقمی را در هر جایگاهی دارد.
IF EXISTS (
    SELECT 1
    FROM [accounting].[DocumentLines] dl
    JOIN [accounting].[BaseDetil] d ON dl.AccountCode LIKE N'%' + d.DetilCode
    WHERE d.DetilId = @DetilId AND d.IsDeleted = 0)
    SET @HasUsage = 1;

IF @HasLink = 1
    THROW 50050, N'این تفصیلی در چند مسیر استفاده شده است؛ ابتدا پیوندها را حذف کنید.', 1;

IF @HasUsage = 1
    THROW 50051, N'این تفصیلی به‌دلیل داشتن گردش مالی امکان حذف ندارد. به‌جای آن غیرفعال کنید.', 1;

UPDATE [accounting].[BaseDetil]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE DetilId = @DetilId AND IsDeleted = 0;

IF @@ROWCOUNT = 0
    THROW 50052, N'حساب تفصیلی پیدا نشد یا قبلاً حذف شده است.', 1;
