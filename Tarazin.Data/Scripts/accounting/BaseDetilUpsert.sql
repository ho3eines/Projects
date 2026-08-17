-- =============================================
-- ویرایش حساب تفصیلی یکپارچه.
-- ایجاد حساب تفصیلی فقط از مسیر BaseDetilCreateAuto انجام می‌شود تا شماره از
-- بازهٔ گروه، اتمیک و بدون استفادهٔ دوباره از شماره‌های حذف‌شده تخصیص یابد.
-- @Description: مقدار NULL یعنی «تغییرش نده» و رشتهٔ خالی یعنی «پاکش کن».
-- قانون چندشرکتی: ویرایش فقط روی تفصیلی متعلق به همان شرکت؛ گروه باید
-- متعلق به همین شرکت (یا گروه سراسری با CompanyId=NULL) باشد.
-- =============================================
DECLARE @NormCode NVARCHAR(7) = RIGHT('0000000' + ISNULL(NULLIF(LTRIM(RTRIM(@DetilCode)), ''), '0000000'), 7);
DECLARE @Nature NVARCHAR(10) = LTRIM(RTRIM(ISNULL(@AccountNature, N'')));
DECLARE @GroupId INT = NULLIF(@AccountGroupId, 0);
DECLARE @GroupFrom NVARCHAR(7);
DECLARE @GroupTo NVARCHAR(7);
DECLARE @CurrentCode NVARCHAR(7);

IF @DetilId = 0
    THROW 50048, N'ایجاد حساب تفصیلی باید با تخصیص خودکار شماره انجام شود.', 1;

IF @NormCode NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
    THROW 50040, N'کد حساب تفصیلی باید دقیقاً ۷ رقم باشد.', 1;

IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = N''
    THROW 50041, N'عنوان حساب تفصیلی الزامی است.', 1;

IF @Nature NOT IN (N'Debit', N'Credit', N'Both')
    THROW 50045, N'ماهیت حساب باید بدهکار، بستانکار یا هر دو باشد.', 1;

SELECT @CurrentCode = DetilCode
FROM [accounting].[BaseDetil]
WHERE DetilId = @DetilId AND IsDeleted = 0 AND CompanyId = @CompanyId;

IF @CurrentCode IS NULL
    THROW 50044, N'حساب تفصیلی پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت نیست.', 1;
IF @NormCode <> @CurrentCode
    THROW 50043, N'شمارهٔ حساب تفصیلی پس از تخصیص قابل تغییر نیست.', 1;

IF @GroupId IS NOT NULL
BEGIN
    SELECT @GroupFrom = FromCode, @GroupTo = ToCode
    FROM [accounting].[AccountGroups]
    WHERE AccountGroupId = @GroupId AND GroupType = N'Detil' AND IsDeleted = 0
      AND (CompanyId = @CompanyId OR CompanyId IS NULL);

    IF @GroupFrom IS NULL
        THROW 50046, N'گروه انتخاب‌شده برای حساب تفصیلی معتبر نیست.', 1;
    IF @NormCode < @GroupFrom OR @NormCode > @GroupTo
        THROW 50047, N'شمارهٔ حساب تفصیلی خارج از بازهٔ گروه انتخاب‌شده است.', 1;
END

UPDATE [accounting].[BaseDetil]
SET Title          = LTRIM(RTRIM(@Title)),
    [Description]  = CASE WHEN @Description IS NULL THEN [Description]
                          ELSE NULLIF(LTRIM(RTRIM(@Description)), N'') END,
    AccountGroupId = @GroupId,
    AccountNature  = @Nature,
    IsActive       = ISNULL(@IsActive, IsActive),
    UpdatedAt      = SYSUTCDATETIME(),
    UpdatedBy      = @UpdatedBy
WHERE DetilId = @DetilId AND IsDeleted = 0 AND CompanyId = @CompanyId;

SELECT @DetilId AS NewId;
