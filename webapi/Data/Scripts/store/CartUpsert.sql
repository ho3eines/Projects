-- =============================================
-- webapi/Data/Scripts/store/CartUpsert.sql
-- Schema: store
-- Execute. افزودن/به‌روزرسانی/حذف ردیف سبد (Qty = 0 حذف می‌کند).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[CartItems] WHERE CustomerId = @CustomerId AND ProductId = @ProductId)
BEGIN
    IF @Qty > 0
        INSERT INTO [store].[CartItems] (CustomerId, ProductId, Qty, AddedAt)
        VALUES (@CustomerId, @ProductId, @Qty, SYSUTDATETIME());
END
ELSE
BEGIN
    IF @Qty <= 0
        DELETE FROM [store].[CartItems] WHERE CustomerId = @CustomerId AND ProductId = @ProductId;
    ELSE
        UPDATE [store].[CartItems] SET Qty = @Qty WHERE CustomerId = @CustomerId AND ProductId = @ProductId;
END
