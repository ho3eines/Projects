-- =============================================
-- HermesApp/Data/Scripts/accounting/ApplyInventoryMovement.sql
-- Schema: accounting | Consumer of InventoryMovement (inventory → accounting)
-- Execute. Idempotent on MovementId (read-model rebuild).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [accounting].[InventoryLedger] WHERE MovementId = @MovementId)
BEGIN
    INSERT INTO [accounting].[InventoryLedger] (MovementId, ItemCode, MovementType, Qty, UnitPrice, MovementDate, CreatedAt)
    VALUES (@MovementId, @ItemCode, @MovementType, @Qty, @UnitPrice, @MovementDate, SYSUTCDATETIME());
END
