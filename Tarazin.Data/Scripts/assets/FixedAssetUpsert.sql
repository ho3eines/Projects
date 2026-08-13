-- =============================================
-- Tarazin.Data/Scripts/assets/FixedAssetUpsert.sql
-- Schema: assets
-- Execute. ایجاد/ویرایش دارایی ثابت.
-- =============================================
IF LEN(LTRIM(RTRIM(@AssetCode))) = 0 OR LEN(LTRIM(RTRIM(@Title))) = 0
    THROW 51200, N'کد و عنوان دارایی الزامی است', 1;
IF @PurchaseCost < 0 OR @UsefulLifeMonths <= 0
    THROW 51201, N'بها و عمر مفید معتبر نیست', 1;

IF @AssetId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [assets].[FixedAssets] WHERE AssetCode = @AssetCode)
        THROW 51202, N'این کد دارایی قبلاً ثبت شده است', 1;

    INSERT INTO [assets].[FixedAssets]
        (AssetCode, Title, Category, PurchaseDate, PurchaseCost, UsefulLifeMonths, ResidualValue, Status, IsActive, CreatedAt, CreatedBy)
    VALUES
        (@AssetCode, @Title, NULLIF(@Category, N''), @PurchaseDate, @PurchaseCost, @UsefulLifeMonths,
         ISNULL(@ResidualValue, 0), ISNULL(@Status, N'Active'), 1, SYSUTCDATETIME(), @CreatedBy);
END
ELSE
BEGIN
    UPDATE [assets].[FixedAssets]
    SET AssetCode        = @AssetCode,
        Title            = @Title,
        Category         = NULLIF(@Category, N''),
        PurchaseDate     = @PurchaseDate,
        PurchaseCost     = @PurchaseCost,
        UsefulLifeMonths = @UsefulLifeMonths,
        ResidualValue    = ISNULL(@ResidualValue, 0),
        Status           = ISNULL(@Status, Status),
        IsActive         = ISNULL(@IsActive, IsActive),
        UpdatedAt        = SYSUTCDATETIME(),
        UpdatedBy        = @CreatedBy
    WHERE AssetId = @AssetId;
END
