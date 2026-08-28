-- =============================================
-- Tarazin.Data/Scripts/inventory/InventoryMovementSearch.sql
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
    m.CostPrice,
    m.WarehouseId,
    m.SubWarehouseId,
    m.MovementDate,
    m.CreatedAt,
    m.UpdatedAt,
    m.CreatedBy,
    m.UpdatedBy
FROM [inventory].[Movements] m
JOIN [inventory].[Items] i ON i.ItemId = m.ItemId
WHERE m.IsDeleted = 0 AND m.CompanyId = @CompanyId
ORDER BY m.MovementId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
