-- =============================================
-- Tarazin.Data/Scripts/store/CustomerUpsert.sql
-- Schema: store
-- Execute. ثبت/ویرایش مشتری فروشگاه + ساخت خودکار طرف حساب (central.Parties)
-- و لینک حسابداری (treasury.PartyLinks) — دقیقاً الگوی طلافروشی:
-- گروه تفصیلی از CompanyAccountSettings.CustomerAccountGroupId خوانده می‌شود
-- و تفصیلی با کد همان مشتری ساخته/بازیابی و لینک می‌شود؛ کاربر نیازی به
-- انتخاب دستی حساب ندارد.
-- =============================================
DECLARE @EffectiveCode NVARCHAR(30) = ISNULL(NULLIF(@CustomerCode, N''),
    N'CST-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(CustomerId) FROM [store].[Customers]), 0) + 1 AS NVARCHAR(10)), 5));

BEGIN TRAN;

-- ── ساخت/به‌روزرسانی مشتری فروشگاه ──
DECLARE @PartyId INT = ISNULL(@PartyId, 0);
IF @CustomerId = 0
BEGIN
    -- طرف حساب (central.Parties) با کد یکسان
    DECLARE @PartyCode NVARCHAR(50) = N'CUS-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(PartyId) FROM [central].[Parties]), 0) + 1 AS NVARCHAR(10)), 5);
    INSERT INTO [central].[Parties]
        (CompanyId, PartyCode, PartyType, FullName, Phone, Email, IsActive, CreatedAt, CreatedBy)
    VALUES
        (@CompanyId, @PartyCode, N'Customer', @FullName, @Phone, @Email, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);
    SET @PartyId = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO [store].[Customers] (CustomerCode, FullName, Phone, Email, IsActive, CreatedAt, CreatedBy, CompanyId, PartyId)
    VALUES (@EffectiveCode, @FullName, @Phone, @Email, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId, @PartyId);
END
ELSE
BEGIN
    UPDATE [store].[Customers]
    SET CustomerCode = ISNULL(@CustomerCode, CustomerCode),
        FullName     = ISNULL(@FullName, FullName),
        Phone        = @Phone,
        Email        = @Email,
        IsActive     = ISNULL(@IsActive, IsActive),
        UpdatedAt    = SYSUTCDATETIME(),
        UpdatedBy    = @CreatedBy
    WHERE CustomerId = @CustomerId AND CompanyId = @CompanyId;
    IF @@ROWCOUNT = 0 THROW 51072, N'مشتری فروشگاه یافت نشد.', 1;

    -- همگام‌سازی اطلاعات در central.Parties (اگر لینک از قبل هست)
    SELECT @PartyId = PartyId FROM [store].[Customers] WHERE CustomerId = @CustomerId;
    IF @PartyId IS NOT NULL
        UPDATE [central].[Parties]
        SET FullName = @FullName, Phone = @Phone, Email = @Email,
            IsActive = ISNULL(@IsActive, IsActive), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
        WHERE PartyId = @PartyId AND CompanyId = @CompanyId AND IsDeleted = 0;
END

-- ── لینک حسابداری خودکار (treasury.PartyLinks) ──
IF @PartyId IS NOT NULL
BEGIN
    DECLARE @GrpId INT = (SELECT CustomerAccountGroupId FROM [accounting].[CompanyAccountSettings] WHERE CompanyId = @CompanyId);
    DECLARE @MoeinId INT = (SELECT DefaultMoeinId FROM [accounting].[AccountGroups] WHERE AccountGroupId = @GrpId AND CompanyId = @CompanyId AND IsDeleted = 0 AND IsActive = 1);
    DECLARE @Nature NVARCHAR(10) = (SELECT DefaultNature FROM [accounting].[AccountGroups] WHERE AccountGroupId = @GrpId AND CompanyId = @CompanyId);
    DECLARE @GrpFrom NVARCHAR(7) = (SELECT FromCode FROM [accounting].[AccountGroups] WHERE AccountGroupId = @GrpId AND CompanyId = @CompanyId);
    DECLARE @AutoLinkId INT = NULL;
    DECLARE @AutoLinkCode NVARCHAR(50) = NULL;
    IF @GrpId IS NOT NULL AND @MoeinId IS NOT NULL AND @GrpFrom IS NOT NULL
    BEGIN
        DECLARE @NumPart INT = TRY_CONVERT(INT, RIGHT(@EffectiveCode, 5));
        DECLARE @DetilCode7 NVARCHAR(7) = CASE WHEN @NumPart IS NOT NULL
            THEN RIGHT(N'0000000' + CONVERT(NVARCHAR(7), CONVERT(INT, @GrpFrom) + @NumPart - 1), 7)
            ELSE @GrpFrom END;
        DECLARE @ExistingDetilId INT = (SELECT TOP 1 d.DetilId FROM [accounting].[BaseDetil] d
                                        WHERE d.CompanyId = @CompanyId AND d.DetilCode = @DetilCode7 AND d.IsDeleted = 0);
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
                (@DetilCode7, @FullName, N'تفصیلی خودکار فروشگاه', @GrpId, ISNULL(@Nature, N'Both'), 1, SYSUTCDATETIME(), @CreatedBy, @CompanyId);
            SET @AutoLinkId = CAST(SCOPE_IDENTITY() AS INT);
            SET @AutoLinkCode = @DetilCode7;
            INSERT INTO [accounting].[BaseDetilLink]
                (DetilId, MoeinId, [Description], IsActive, CreatedAt, CreatedBy, CompanyId)
            VALUES
                (@AutoLinkId, @MoeinId, N'لینک خودکار ' + @DetilCode7, 1, SYSUTCDATETIME(), @CreatedBy, @CompanyId);
        END
    END

    IF EXISTS (SELECT 1 FROM [treasury].[PartyLinks] WHERE CompanyId = @CompanyId AND PartyId = @PartyId)
        UPDATE [treasury].[PartyLinks]
        SET PartyType = N'Customer', DetailLinkId = @AutoLinkId, DetailAccountCode = @AutoLinkCode,
            UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
        WHERE CompanyId = @CompanyId AND PartyId = @PartyId;
    ELSE
        INSERT INTO [treasury].[PartyLinks]
            (CompanyId, PartyId, PartyType, DetailLinkId, DetailAccountCode, CreatedAt, CreatedBy)
        VALUES (@CompanyId, @PartyId, N'Customer', @AutoLinkId, @AutoLinkCode, SYSUTCDATETIME(), @CreatedBy);
END

COMMIT;
SELECT @PartyId AS PartyId;
