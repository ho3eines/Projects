-- =============================================
-- Tarazin.Data/Scripts/store/CustomerList.sql
-- Schema: store
-- Query.
-- =============================================
SELECT c.CustomerId, c.CustomerCode, c.FullName, c.Phone, c.Email, c.IsActive,
       c.CreatedAt, c.UpdatedAt, c.CreatedBy, c.UpdatedBy
FROM [store].[Customers] c
WHERE c.IsDeleted = 0
ORDER BY c.FullName;
