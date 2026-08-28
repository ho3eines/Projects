-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldPartyUpsert.sql
-- Schema: goldshop
-- ثبت/ویرایش طرف حساب (مشتری/تأمین‌کننده) + لینک خودکار حسابداری.
-- اتصال حسابداری **اتوماتیک** است: گروه تفصیلی از تنظیمات طلافروشی خوانده
-- می‌شود و تفصیلی با **کد همان طرف‌حساب** (مثلاً CUS-00001) در آن گروه ساخته
-- یا بازیابی شده و به معین پیش‌فرض گروه لینک می‌شود؛ کاربر دیگر نیازی به
-- انتخاب دستی حساب ندارد. اگر همچنان DetailLinkId/DetailAccountCode صریح
-- ارسال شود، همان‌ها نگه داشته می‌شوند (سازگاری با دادهٔ قدیمی).
-- =============================================
DECLARE @ActualPartyId INT = @PartyId;
DECLARE @Code NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@PartyCode)), N'');
IF @Code IS NULL
    SET @Code = CASE WHEN @PartyType = N'Vendor' THEN N'VEN-' ELSE N'CUS-' END
        + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(PartyId) FROM [central].[Parties]), 0) + 1 AS NVARCHAR(10)), 5);
IF @PartyType NOT IN (N'Customer', N'Vendor') THROW 51070, N'نوع طرف حساب نامعتبر است.', 1;

BEGIN TRAN;

IF @ActualPartyId = 0
BEGIN
    INSERT INTO [central].[Parties]
        (CompanyId, PartyCode, PartyType, FullName, NationalId, Phone, Email, IsActive, CreatedAt, CreatedBy)
    VALUES
        (@CompanyId, @Code, @PartyType, @FullName, @NationalId, @Phone, @Email, ISNULL(@IsActive,1), SYSUTCDATETIME(), @CreatedBy);
    SET @ActualPartyId = SCOPE_IDENTITY();
END
ELSE
BEGIN
    UPDATE [central].[Parties]
    SET PartyType=@PartyType, FullName=@FullName, NationalId=@NationalId, Phone=@Phone, Email=@Email,
        IsActive=ISNULL(@IsActive,IsActive), UpdatedAt=SYSUTCDATETIME(), UpdatedBy=@CreatedBy
    WHERE PartyId=@ActualPartyId AND CompanyId=@CompanyId AND IsDeleted=0;
    IF @@ROWCOUNT = 0 THROW 51071, N'طرف حساب یافت نشد.', 1;
END

-- ============ اتصال حسابداری خودکار ============
-- 1) گروه تفصیلی از تنظیمات (CustomerAccountGroupId / SupplierAccountGroupId)
-- 2) معین پیش‌فرض گروه (AccountGroups.DefaultMoeinId)
-- 3) تفصیلی با کد طرف‌حساب پیدا/ساخته می‌شود و لینک می‌شود
DECLARE @AutoLinkId INT = NULLIF(@DetailLinkId, 0);
DECLARE @AutoLinkCode NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@DetailAccountCode)), N'');
IF @AutoLinkId IS NULL OR @AutoLinkCode IS NULL
BEGIN
    -- گروه تفصیلی از تنظیمات سراسری شرکت (CompanyAccountSettings)؛
    -- برای دادهٔ قدیمی که هنوز منتقل نشده، از تنظیمات طلافروشی fallback می‌شود.
    DECLARE @GrpId INT = CASE WHEN @PartyType = N'Customer'
        THEN ISNULL((SELECT CustomerAccountGroupId FROM [accounting].[CompanyAccountSettings] WHERE CompanyId=@CompanyId),
                    (SELECT CustomerAccountGroupId FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId))
        ELSE ISNULL((SELECT SupplierAccountGroupId FROM [accounting].[CompanyAccountSettings] WHERE CompanyId=@CompanyId),
                    (SELECT SupplierAccountGroupId FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId)) END;
    DECLARE @MoeinId INT = (SELECT DefaultMoeinId FROM [accounting].[AccountGroups] WHERE AccountGroupId=@GrpId AND CompanyId=@CompanyId AND IsDeleted=0 AND IsActive=1);
    DECLARE @Nature NVARCHAR(10) = (SELECT DefaultNature FROM [accounting].[AccountGroups] WHERE AccountGroupId=@GrpId AND CompanyId=@CompanyId);
    DECLARE @GrpFrom NVARCHAR(7) = (SELECT FromCode FROM [accounting].[AccountGroups] WHERE AccountGroupId=@GrpId AND CompanyId=@CompanyId);
    IF @GrpId IS NOT NULL AND @MoeinId IS NOT NULL
    BEGIN
        -- کد تفصیلی = شمارهٔ ۷رقمی داخل بازهٔ گروه (FromCode) + شمارهٔ طرف‌حساب؛
        -- کد طرف‌حساب برای جستجو/نمایش نگه داشته می‌شود.
        DECLARE @NumPart INT = TRY_CONVERT(INT, RIGHT(@Code, 5));
        DECLARE @DetilCode7 NVARCHAR(7) = CASE WHEN @NumPart IS NOT NULL AND @GrpFrom IS NOT NULL
            THEN RIGHT(N'0000000' + CONVERT(NVARCHAR(7), CONVERT(INT, @GrpFrom) + @NumPart - 1), 7)
            ELSE @GrpFrom END;
        -- تفصیلی موجود با همین کد؟ (تکراری‌سازی نشود)
        DECLARE @ExistingDetilId INT = (SELECT TOP 1 d.DetilId FROM [accounting].[BaseDetil] d
                                        WHERE d.CompanyId=@CompanyId AND d.DetilCode=@DetilCode7 AND d.IsDeleted=0);
        IF @ExistingDetilId IS NOT NULL
        BEGIN
            SET @AutoLinkId = @ExistingDetilId;
            SET @AutoLinkCode = @DetilCode7;
        END
        ELSE
        BEGIN
            INSERT INTO [accounting].[BaseDetil]
                (DetilCode, Title, [Description], AccountGroupId, AccountNature, IsActive, CreatedAt, CreatedBy, CompanyId)
            VALUES
                (@DetilCode7, @FullName, N'تفصیلی خودکار ' + CASE WHEN @PartyType=N'Customer' THEN N'مشتری' ELSE N'تأمین‌کننده' END,
                 @GrpId, ISNULL(@Nature, N'Both'), 1, SYSUTCDATETIME(), @CreatedBy, @CompanyId);
            DECLARE @NewDetilId INT = CAST(SCOPE_IDENTITY() AS INT);
            INSERT INTO [accounting].[BaseDetilLink]
                (DetilId, MoeinId, [Description], IsActive, CreatedAt, CreatedBy, CompanyId)
            VALUES
                (@NewDetilId, @MoeinId, N'لینک خودکار ' + @DetilCode7, 1, SYSUTCDATETIME(), @CreatedBy, @CompanyId);
            SET @AutoLinkId = @NewDetilId;
            SET @AutoLinkCode = @DetilCode7;
        END
    END
END

IF EXISTS (SELECT 1 FROM [treasury].[PartyLinks] WHERE CompanyId=@CompanyId AND PartyId=@ActualPartyId)
    UPDATE [treasury].[PartyLinks]
    SET PartyType=@PartyType, DetailLinkId=@AutoLinkId, DetailAccountCode=@AutoLinkCode, UpdatedAt=SYSUTCDATETIME(), UpdatedBy=@CreatedBy
    WHERE CompanyId=@CompanyId AND PartyId=@ActualPartyId;
ELSE
    INSERT INTO [treasury].[PartyLinks]
        (CompanyId, PartyId, PartyType, DetailLinkId, DetailAccountCode, CreatedAt, CreatedBy)
    VALUES (@CompanyId, @ActualPartyId, @PartyType, @AutoLinkId, @AutoLinkCode, SYSUTCDATETIME(), @CreatedBy);
COMMIT;
SELECT @ActualPartyId AS PartyId;
