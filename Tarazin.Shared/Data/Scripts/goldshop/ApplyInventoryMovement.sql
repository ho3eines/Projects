-- =============================================
-- Tarazin.Shared/Data/Scripts/goldshop/ApplyInventoryMovement.sql
-- Schema: goldshop | Consumer of InventoryMovement (inventory → goldshop)
-- Execute. Idempotent on MovementId (read-model rebuild).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [goldshop].[InventorySnapshot] WHERE MovementId = @MovementId)
BEGIN
    INSERT INTO [goldshop].[InventorySnapshot] (MovementId, ItemCode, MovementType, Qty, UnitPrice, MovementDate, CreatedAt)
    VALUES (@MovementId, @ItemCode, @MovementType, @Qty, @UnitPrice, @MovementDate, SYSUTCDATETIME());
END
