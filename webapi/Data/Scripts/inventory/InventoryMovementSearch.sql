-- =============================================
-- webapi/Data/Scripts/inventory/InventoryMovementSearch.sql
-- Schema: inventory | Contract: InventoryMovement
-- Query. Shape MUST match InventoryMovementRow (Share) exactly.
-- =============================================
SELECT
    m.MovementId,
    m.MovementNumber,
    m.MovementType,
    m.ItemId,
    i.ItemCode,
    i.ItemTitle,
    m.Qty,
    m.UnitPrice,
    m.MovementDate
FROM [inventory].[Movements] m
JOIN [inventory].[Items] i ON i.ItemId = m.ItemId
WHERE m.IsDeleted = 0
ORDER BY m.MovementId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
