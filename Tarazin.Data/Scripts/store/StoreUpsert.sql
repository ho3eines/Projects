-- =============================================
-- Tarazin.Data/Scripts/store/StoreUpsert.sql
-- Schema: store | Cross-schema: inventory
-- Execute. درج/ویرایش فروشگاه. کد تکراری → 51300.
-- =============================================
DECLARE @Code NVARCHAR(30) = LTRIM(RTRIM(ISNULL(@StoreCode, N'')));
DECLARE @Ttl NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@Title, N'')));

IF @Code = N'' OR @Ttl = N''
    THROW 51301, N'کد و نام فروشگاه الزامی است', 1;

-- کد فروشگاه باید درون شرکت یکتا باشد
IF EXISTS (SELECT 1 FROM [store].[Stores]
           WHERE CompanyId = @CompanyId AND StoreCode = @Code
             AND IsDeleted = 0 AND StoreId <> ISNULL(@StoreId, 0))
    THROW 51300, N'کد فروشگاه در این شرکت تکراری است', 1;

-- انبار متصل باید از همان شرکت باشد (وقتی مشخص شده)
IF @WarehouseId IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [inventory].[Warehouses] WHERE WarehouseId = @WarehouseId)
    THROW 51302, N'انبار انتخابی یافت نشد', 1;

IF ISNULL(@StoreId, 0) = 0
BEGIN
    INSERT INTO [store].[Stores]
        (CompanyId, StoreCode, Title, StoreType, WarehouseId, ManagerName,
         Phone, Email, Address, WorkingHours, [Description], OnlineEnabled,
         IsActive, CreatedAt, CreatedBy)
    VALUES
        (@CompanyId, @Code, @Ttl,
         ISNULL(NULLIF(LTRIM(RTRIM(@StoreType)), N''), N'Physical'),
         @WarehouseId, @ManagerName, @Phone, @Email, @Address, @WorkingHours,
         @Description, ISNULL(@OnlineEnabled, 0), ISNULL(@IsActive, 1),
         SYSUTCDATETIME(), @CreatedBy);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
END
ELSE
BEGIN
    UPDATE [store].[Stores]
    SET StoreCode     = @Code,
        Title         = @Ttl,
        StoreType     = ISNULL(NULLIF(LTRIM(RTRIM(@StoreType)), N''), StoreType),
        WarehouseId   = @WarehouseId,
        ManagerName   = @ManagerName,
        Phone         = @Phone,
        Email         = @Email,
        Address       = @Address,
        WorkingHours  = @WorkingHours,
        [Description] = @Description,
        OnlineEnabled = ISNULL(@OnlineEnabled, OnlineEnabled),
        IsActive      = ISNULL(@IsActive, IsActive),
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @CreatedBy
    WHERE StoreId = @StoreId AND CompanyId = @CompanyId AND IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 51303, N'فروشگاه یافت نشد یا حذف شده است', 1;

    SELECT @StoreId AS NewId;
END
