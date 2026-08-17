-- =============================================
-- حذف نرم گروه حساب؛ گروه دارای حساب ابتدا باید تخلیه یا غیرفعال شود.
-- قانون چندشرکتی: هدف حذف باید متعلق به شرکت جاری (یا گروه سراسری با
-- CompanyId=NULL) باشد؛ حذف گروه شرکت دیگر ممنوع است. چک «گروه دارای
-- حساب» برای گروه‌های سراسری عمداً روی همهٔ شرکت‌ها انجام می‌شود (محافظت).
-- =============================================
SET XACT_ABORT ON;

DECLARE @LockResult INT;
DECLARE @LockResource NVARCHAR(255) = N'Tarazin:AccountGroups';

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC @LockResult = sys.sp_getapplock
        @LockResource, N'Exclusive', N'Transaction', 15000;

    IF @LockResult < 0
        THROW 50122, N'ویرایش گروه‌ها هم‌اکنون توسط کاربر دیگری انجام می‌شود؛ چند لحظه بعد دوباره تلاش کنید.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM [accounting].[AccountGroups] WITH (UPDLOCK, HOLDLOCK)
        WHERE AccountGroupId = @AccountGroupId AND IsDeleted = 0
          AND (CompanyId = @CompanyId OR CompanyId IS NULL))
        THROW 50120, N'گروه حساب پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت نیست.', 1;

    IF EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE AccountGroupId = @AccountGroupId AND IsDeleted = 0)
       OR EXISTS (SELECT 1 FROM [accounting].[BaseMoein] WHERE AccountGroupId = @AccountGroupId AND IsDeleted = 0)
       OR EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE AccountGroupId = @AccountGroupId AND IsDeleted = 0)
        THROW 50121, N'این گروه دارای حساب است و قابل حذف نیست؛ می‌توانید آن را غیرفعال کنید.', 1;

    UPDATE [accounting].[AccountGroups]
    SET IsDeleted = 1,
        IsActive = 0,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @UpdatedBy
    WHERE AccountGroupId = @AccountGroupId AND IsDeleted = 0
      AND (CompanyId = @CompanyId OR CompanyId IS NULL);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
