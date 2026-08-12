-- =============================================
-- Tarazin.Shared/Data/Scripts/store/RefreshGoldPrice.sql
-- Schema: store | Consumer of GoldPriceUpdated (goldshop → store)
-- Execute. Idempotent upsert on ItemCode (pub/sub read-model).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[GoldPriceSnapshot] WHERE ItemCode = @ItemCode)
BEGIN
    INSERT INTO [store].[GoldPriceSnapshot] (ItemCode, PricePerGram, UpdatedAt)
    VALUES (@ItemCode, @PricePerGram, @UpdatedAt);
END
ELSE
BEGIN
    UPDATE [store].[GoldPriceSnapshot]
    SET PricePerGram = @PricePerGram, UpdatedAt = @UpdatedAt
    WHERE ItemCode = @ItemCode;
END
