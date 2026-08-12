-- =============================================
-- TarazinApp/Data/Scripts/accounting/RefreshGoldPrice.sql
-- Schema: accounting | Consumer of GoldPriceUpdated (goldshop → accounting)
-- Execute. Idempotent upsert on ItemCode (pub/sub read-model).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [accounting].[GoldPriceSnapshot] WHERE ItemCode = @ItemCode)
BEGIN
    INSERT INTO [accounting].[GoldPriceSnapshot] (ItemCode, PricePerGram, UpdatedAt)
    VALUES (@ItemCode, @PricePerGram, @UpdatedAt);
END
ELSE
BEGIN
    UPDATE [accounting].[GoldPriceSnapshot]
    SET PricePerGram = @PricePerGram, UpdatedAt = @UpdatedAt
    WHERE ItemCode = @ItemCode;
END
