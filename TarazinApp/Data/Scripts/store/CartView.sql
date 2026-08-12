-- =============================================
-- TarazinApp/Data/Scripts/store/CartView.sql
-- Schema: store
-- Query. سبد خرید مشتری.
-- =============================================
SELECT
    c.CartItemId,
    c.CustomerId,
    c.ProductId,
    p.Title AS ProductTitle,
    p.ItemCode,
    c.Qty,
    p.Price,
    (c.Qty * p.Price) AS LineTotal
FROM [store].[CartItems] c
JOIN [store].[Products] p ON p.ProductId = c.ProductId
WHERE c.CustomerId = @CustomerId
ORDER BY c.AddedAt;
