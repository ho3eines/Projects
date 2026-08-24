-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldItemUpsert.sql
-- Schema: goldshop
-- Execute. ثبت/ویرایش جنس طلا + لینک خودکار تفصیلی موجودی.
-- اتصال حسابداری خودکار: گروه تفصیلی موجودی از تنظیمات
-- (InventoryAccountGroupId) خوانده می‌شود و تفصیلی با کد همان کالا
-- (مثلاً XAU-18) ساخته یا بازیابی شده و به معین پیش‌فرض گروه لینک می‌شود.
-- =============================================
IF @GoldItemId = 0
BEGIN
    INSERT INTO [goldshop].[GoldItems] (ItemCode, Title, Purity, InventoryItemCode, IsActive, CreatedAt, CompanyId)
    VALUES (@ItemCode, @Title, @Purity, @InventoryItemCode, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CompanyId);
END
ELSE
BEGIN
    UPDATE [goldshop].[GoldItems]
    SET ItemCode = ISNULL(@ItemCode, ItemCode),
        Title    = ISNULL(@Title, Title),
        Purity   = @Purity,
        InventoryItemCode = @InventoryItemCode,
        IsActive = ISNULL(@IsActive, IsActive),
        UpdatedAt = SYSUTCDATETIME()
    WHERE GoldItemId = @GoldItemId AND CompanyId = @CompanyId;
END

-- ============ اتصال حسابداری خودکار (تفصیلی موجودی کالا) ============
-- گروه تفصیلی موجودی از تنظیمات سراسری شرکت؛ fallback به تنظیمات طلافروشی
DECLARE @GrpId INT = ISNULL((SELECT InventoryAccountGroupId FROM [accounting].[CompanyAccountSettings] WHERE CompanyId=@CompanyId),
                            (SELECT InventoryAccountGroupId FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId));
IF @GrpId IS NOT NULL
BEGIN
    DECLARE @MoeinId INT = (SELECT DefaultMoeinId FROM [accounting].[AccountGroups] WHERE AccountGroupId=@GrpId AND CompanyId=@CompanyId AND IsDeleted=0 AND IsActive=1);
    DECLARE @Nature NVARCHAR(10) = (SELECT DefaultNature FROM [accounting].[AccountGroups] WHERE AccountGroupId=@GrpId AND CompanyId=@CompanyId);
    DECLARE @GrpFrom NVARCHAR(7) = (SELECT FromCode FROM [accounting].[AccountGroups] WHERE AccountGroupId=@GrpId AND CompanyId=@CompanyId);
    -- کد تفصیلی ۷رقمی داخل بازهٔ گروه: FromCode + شمارهٔ ترتیبی کالا در شرکت
    DECLARE @Seq INT = ISNULL((SELECT MAX(TRY_CONVERT(INT, RIGHT(DetilCode, 6)) - CONVERT(INT, LEFT(DetilCode, 1)) * 100000)
                               FROM [accounting].[BaseDetil] WHERE CompanyId=@CompanyId AND AccountGroupId=@GrpId AND IsDeleted=0), 0) + 1;
    DECLARE @DetilCode7 NVARCHAR(7) = CASE WHEN @GrpFrom IS NOT NULL
        THEN RIGHT(N'0000000' + CONVERT(NVARCHAR(7), CONVERT(INT, @GrpFrom) + @Seq - 1), 7) ELSE NULL END;
    IF @MoeinId IS NOT NULL AND @DetilCode7 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] d WHERE d.CompanyId=@CompanyId AND d.DetilCode=@DetilCode7 AND d.IsDeleted=0)
    BEGIN
        INSERT INTO [accounting].[BaseDetil]
            (DetilCode, Title, [Description], AccountGroupId, AccountNature, IsActive, CreatedAt, CreatedBy, CompanyId)
        VALUES
            (@DetilCode7, @Title, N'تفصیلی خودکار کالای طلا', @GrpId, ISNULL(@Nature, N'Both'), 1, SYSUTCDATETIME(), @CreatedBy, @CompanyId);
        DECLARE @DetilId INT = CAST(SCOPE_IDENTITY() AS INT);
        INSERT INTO [accounting].[BaseDetilLink]
            (DetilId, MoeinId, [Description], IsActive, CreatedAt, CreatedBy, CompanyId)
        VALUES
            (@DetilId, @MoeinId, N'لینک خودکار کالا ' + @DetilCode7, 1, SYSUTCDATETIME(), @CreatedBy, @CompanyId);
    END
END
