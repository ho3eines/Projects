-- =============================================
-- Tarazin.Data/Scripts/store/CustomerList.sql
-- Schema: store
-- Query. فهرست مشتریان + ماندهٔ دفتر (بدهکار/بستانکار).
-- =============================================
SELECT c.CustomerId, c.CustomerCode, c.FullName, c.Phone, c.Email, c.IsActive,
       c.PartyId,
       ISNULL(lb.Balance, 0) AS Balance,
       c.CreatedAt, c.UpdatedAt, c.CreatedBy, c.UpdatedBy
FROM [store].[Customers] c
LEFT JOIN (
    SELECT CustomerId, SUM(DebitRial - CreditRial) AS Balance
    FROM [store].[OrderLedger]
    WHERE CompanyId = @CompanyId
    GROUP BY CustomerId
) lb ON lb.CustomerId = c.CustomerId
WHERE c.IsDeleted = 0
  AND c.CompanyId = @CompanyId
ORDER BY c.FullName;
