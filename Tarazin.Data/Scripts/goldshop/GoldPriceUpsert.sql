-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldPriceUpsert.sql
-- Schema: goldshop | Contract: GoldPrice (producer)
-- Execute. عملیات ویژه: ثبت/به‌روزرسانی قیمت روز + رویداد GoldPriceUpdated
-- (pub/sub → accounting.RefreshGoldPrice, store.RefreshGoldPrice).
-- =============================================
BEGIN TRAN;
    IF NOT EXISTS (SELECT 1 FROM [goldshop].[GoldPrices] WHERE ItemCode = @ItemCode)
    BEGIN
        INSERT INTO [goldshop].[GoldPrices] (ItemCode, Title, PricePerGram, RateToIRR, UpdatedAt)
        VALUES (@ItemCode, @Title, @PricePerGram, @RateToIRR, SYSUTCDATETIME());
    END
    ELSE
    BEGIN
        UPDATE [goldshop].[GoldPrices]
        SET PricePerGram = @PricePerGram, RateToIRR = @RateToIRR, UpdatedAt = SYSUTCDATETIME()
        WHERE ItemCode = @ItemCode;
    END

    INSERT INTO [goldshop].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
    VALUES (N'GoldPriceUpdated', CONCAT(N'ItemCode=', @ItemCode),
        (SELECT @ItemCode AS ItemCode, @PricePerGram AS PricePerGram, @RateToIRR AS RateToIRR,
                SYSUTCDATETIME() AS UpdatedAt
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
COMMIT;
