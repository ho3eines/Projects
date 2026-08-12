-- =============================================
-- webapi/Data/Scripts/store/ProductUpsert.sql
-- Schema: store
-- Execute.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[Products] WHERE ProductId = @ProductId)
BEGIN
    INSERT INTO [store].[Products] (ProductCode, Title, ItemCode, Price, IsActive, CreatedAt)
    VALUES (@ProductCode, @Title, @ItemCode, ISNULL(@Price, 0), ISNULL(@IsActive, 1), SYSUTDATETIME());
END
ELSE
BEGIN
    UPDATE [store].[Products]
    SET ProductCode = ISNULL(@ProductCode, ProductCode),
        Title       = ISNULL(@Title, Title),
        ItemCode    = @ItemCode,
        Price       = @Price,
        IsActive    = ISNULL(@IsActive, IsActive)
    WHERE ProductId = @ProductId;
END
