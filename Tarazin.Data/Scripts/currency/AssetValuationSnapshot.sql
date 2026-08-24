-- =============================================
-- Tarazin.Data/Scripts/currency/AssetValuationSnapshot.sql
-- Schema: currency
-- Cross-schema: treasury (ماندهٔ صندوق/بانک)
-- Execute. ثبت اسنپ‌شات روزانهٔ ارزش دارایی (PRD §51 — ارزش روز گذشته/امروز).
-- جمع‌بندی از همان منطق AssetValuation؛ برای هر روز یک ردیف.
-- =============================================
DECLARE @Cash DECIMAL(18,2), @Curr DECIMAL(18,2), @Gold DECIMAL(18,2), @Coin DECIMAL(18,2), @Metal DECIMAL(18,2);

SELECT @Cash = ISNULL(SUM(RialValue), 0) FROM (
    SELECT c.Balance AS RialValue FROM [treasury].[CashBoxes] c WHERE c.IsDeleted = 0 AND c.CompanyId = [central].[fn_MobileCompanyId]()
    UNION ALL
    SELECT b.Balance FROM [treasury].[BankAccounts] b WHERE b.IsDeleted = 0 AND b.CompanyId = [central].[fn_MobileCompanyId]()
) x;

SELECT @Curr = ISNULL(SUM(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0)), 0)
FROM [currency].[Wallets] w
LEFT JOIN [currency].[PriceRates] r
    ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)
WHERE w.CompanyId = [central].[fn_MobileCompanyId]();

SELECT @Gold = ISNULL(SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0)), 0)
FROM [currency].[AssetHoldings] h
JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
WHERE p.ItemType = N'Gold' AND h.CompanyId = [central].[fn_MobileCompanyId]();

SELECT @Coin = ISNULL(SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0)), 0)
FROM [currency].[AssetHoldings] h
JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
WHERE p.ItemType = N'Coin' AND h.CompanyId = [central].[fn_MobileCompanyId]();

SELECT @Metal = ISNULL(SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0)), 0)
FROM [currency].[AssetHoldings] h
JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
WHERE p.ItemType = N'Metal' AND h.CompanyId = [central].[fn_MobileCompanyId]();

DECLARE @Total DECIMAL(18,2) = ISNULL(@Cash, 0) + ISNULL(@Curr, 0) + ISNULL(@Gold, 0) + ISNULL(@Coin, 0) + ISNULL(@Metal, 0);
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF EXISTS (SELECT 1 FROM [currency].[AssetValuationHistory]
           WHERE SnapshotDate = @Today
             AND CompanyId = [central].[fn_MobileCompanyId]())
BEGIN
    UPDATE [currency].[AssetValuationHistory]
    SET TotalRial = @Total, CashPart = @Cash, CurrencyPart = @Curr,
        GoldPart = @Gold, CoinPart = @Coin, MetalPart = @Metal,
        CreatedAt = SYSUTCDATETIME(), CreatedBy = @CreatedBy
    WHERE SnapshotDate = @Today
      AND CompanyId = [central].[fn_MobileCompanyId]();
END
ELSE
BEGIN
    INSERT INTO [currency].[AssetValuationHistory]
        (SnapshotDate, TotalRial, CashPart, CurrencyPart, GoldPart, CoinPart, MetalPart, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (@Today, @Total, @Cash, @Curr, @Gold, @Coin, @Metal, SYSUTCDATETIME(), @CreatedBy, [central].[fn_MobileCompanyId]());
END

UPDATE [currency].[Settings]
SET SettingValue = CONVERT(NVARCHAR(10), @Today, 111)
WHERE SettingKey = N'LastValuationDate';
