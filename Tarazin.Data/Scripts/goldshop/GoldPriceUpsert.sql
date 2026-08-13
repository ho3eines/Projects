-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldPriceUpsert.sql
-- Schema: goldshop | Contract: GoldPrice (producer)
-- Execute. PriceId=0 identifies a new record; every non-zero id is an edit.
-- ثبت/به‌روزرسانی قیمت روز + رویداد GoldPriceUpdated
-- (pub/sub → accounting.RefreshGoldPrice, store.RefreshGoldPrice).
-- =============================================
BEGIN TRAN;
    IF @PriceId = 0
    BEGIN
        INSERT INTO [goldshop].[GoldPrices] (ItemCode, Title, PricePerGram, RateToIRR, CreatedAt, UpdatedAt)
        VALUES (@ItemCode, @Title, @PricePerGram, @RateToIRR, SYSUTCDATETIME(), SYSUTCDATETIME());
    END
    ELSE
    BEGIN
        UPDATE [goldshop].[GoldPrices]
        SET Title = @Title,
            PricePerGram = @PricePerGram,
            RateToIRR = @RateToIRR,
            UpdatedAt = SYSUTCDATETIME()
        WHERE PriceId = @PriceId;
    END

    INSERT INTO [goldshop].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
    VALUES (N'GoldPriceUpdated', CONCAT(N'ItemCode=', @ItemCode),
        (SELECT @ItemCode AS ItemCode, @PricePerGram AS PricePerGram, @RateToIRR AS RateToIRR,
                SYSUTCDATETIME() AS UpdatedAt
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
COMMIT;
