-- =============================================
-- TarazinApp/Data/Scripts/store/ApplyInventoryMovement.sql
-- Schema: store | Consumer of InventoryMovement (inventory → store)
-- Execute. Idempotent on MovementId (read-model rebuild).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[InventorySnapshot] WHERE MovementId = @MovementId)
BEGIN
    INSERT INTO [store].[InventorySnapshot] (MovementId, ItemCode, MovementType, Qty, UnitPrice, MovementDate, CreatedAt)
    VALUES (@MovementId, @ItemCode, @MovementType, @Qty, @UnitPrice, @MovementDate, SYSUTCDATETIME());
END
