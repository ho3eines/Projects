-- =============================================
-- TarazinApp/Data/Scripts/inventory/ItemUpsert.sql
-- Schema: inventory
-- Execute.
-- =============================================
DECLARE @EffectiveCode NVARCHAR(50) = ISNULL(NULLIF(@ItemCode, N''),
    N'ITM-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(ItemId) FROM [inventory].[Items]), 0) + 1 AS NVARCHAR(10)), 5));

IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE ItemId = @ItemId)
BEGIN
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, StockQty, UnitPrice, IsActive, CreatedAt)
    VALUES (@EffectiveCode, @ItemTitle, @Category, @Unit, 0, ISNULL(@UnitPrice, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [inventory].[Items]
    SET ItemCode  = ISNULL(@ItemCode, ItemCode),
        ItemTitle = ISNULL(@ItemTitle, ItemTitle),
        Category  = @Category,
        Unit      = ISNULL(@Unit, Unit),
        UnitPrice = @UnitPrice,
        IsActive  = ISNULL(@IsActive, IsActive),
        UpdatedAt = SYSUTCDATETIME()
    WHERE ItemId = @ItemId;
END
