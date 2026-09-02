-- =============================================
-- Tarazin.Data/Scripts/store/PriceListUpsert.sql
-- Schema: store
-- Execute. درج/ویرایش لیست قیمت (@PriceListId=0 → درج).
-- =============================================
IF @PriceListId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [store].[PriceLists]
               WHERE CompanyId = @CompanyId AND Code = @Code AND IsDeleted = 0)
        THROW 51300, N'کد لیست قیمت تکراری است.', 1;

    INSERT INTO [store].[PriceLists] (CompanyId, Code, Title, StoreId, CurrencyCode, IsActive, CreatedBy)
    VALUES (@CompanyId, @Code, @Title, @StoreId, ISNULL(@CurrencyCode, N'IRR'), @IsActive, @CreatedBy);
END
ELSE
BEGIN
    UPDATE [store].[PriceLists]
       SET Code = @Code, Title = @Title, StoreId = @StoreId,
           CurrencyCode = @CurrencyCode, IsActive = @IsActive,
           UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
     WHERE PriceListId = @PriceListId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51301, N'لیست قیمت یافت نشد.', 1;
END
