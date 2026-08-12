-- =============================================
-- Tarazin.Data/Scripts/store/ProductUpsert.sql
-- Schema: store
-- Execute.
-- =============================================
DECLARE @EffectiveCode NVARCHAR(50) = ISNULL(NULLIF(@ProductCode, N''),
    N'P-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(ProductId) FROM [store].[Products]), 0) + 1 AS NVARCHAR(10)), 5));

-- ProductId=0 identifies a new record; every non-zero id is an edit.
IF @ProductId = 0
BEGIN
    INSERT INTO [store].[Products] (ProductCode, Title, ItemCode, Price, IsActive, CreatedAt)
    VALUES (@EffectiveCode, @Title, @ItemCode, ISNULL(@Price, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME());
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
