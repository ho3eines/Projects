-- =============================================
-- Tarazin.Data/Scripts/currency/RateOverride.sql
-- Schema: currency
-- Execute. تأیید/Override نرخ آنلاین ← نرخ سیستم (PRD §46).
--   نرخ آنلاین هرگز مستقیم وارد معامله نمی‌شود؛ مدیر آن را می‌بیند،
--   در صورت نیاز اصلاح می‌کند و با این عملیات به «نرخ سیستم» تبدیل می‌شود.
-- =============================================
DECLARE @ItemId INT, @ItemType NVARCHAR(20), @Online DECIMAL(18,2), @System DECIMAL(18,2);
SELECT TOP (1) @ItemId = p.PriceItemId, @ItemType = p.ItemType
FROM [currency].[PriceItems] p
WHERE p.ItemKey = @ItemKey AND p.IsDeleted = 0;

IF @ItemId IS NULL
    THROW 51130, N'آیتم قیمت یافت نشد', 1;

SELECT @Online = OnlineRate, @System = SystemRate
FROM [currency].[PriceRates] WHERE PriceItemId = @ItemId;

IF @Online IS NULL OR @Online <= 0
    THROW 51131, N'نرخ آنلاین معتبری برای Override وجود ندارد', 1;

BEGIN TRAN;
    UPDATE [currency].[PriceRates]
    SET SystemRate    = @Online,
        IsOverride    = 1,
        PrevValue     = @System,
        ChangeAmount  = @Online - @System,
        ChangePercent = CASE WHEN ISNULL(@System, 0) <> 0 THEN (@Online - @System) * 100.0 / @System ELSE NULL END,
        LastChangeAt  = SYSUTCDATETIME(),
        RateDate      = CAST(SYSDATETIME() AS DATE),
        IsValid       = 1,
        Status        = N'Active',
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @ChangedBy
    WHERE PriceItemId = @ItemId;

    INSERT INTO [currency].[RateHistory]
        (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
    VALUES
        (@ItemType, @ItemKey, N'System', @System, @Online, @SourceKey, N'Override', @Reason, @ChangedBy, 0);
COMMIT;
