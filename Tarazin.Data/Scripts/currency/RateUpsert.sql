-- =============================================
-- Tarazin.Data/Scripts/currency/RateUpsert.sql
-- Schema: currency
-- Execute. تغییر دستی یک نرخ در مرکز قیمت (PRD §46/§47/§48/§49).
--   RateKind: System | Manual | Buy | Sell | Accounting
-- هر تغییر در RateHistory ثبت می‌شود (نرخ قبلی/جدید/منبع/کاربر/تاریخ/دلیل).
-- وقتی نرخ سیستم به‌صورت دستی ست می‌شود IsOverride=1 می‌شود تا بروزرسانی
-- آنلاین خودکار آن را جایگزین نکند (§46/§56).
-- =============================================
IF @NewValue <= 0
    THROW 51120, N'نرخ باید بزرگ‌تر از صفر باشد', 1;

DECLARE @ItemId INT, @ItemType NVARCHAR(20), @ItemTitle NVARCHAR(200);
SELECT TOP (1) @ItemId = p.PriceItemId, @ItemType = p.ItemType, @ItemTitle = p.Title
FROM [currency].[PriceItems] p
WHERE p.ItemKey = @ItemKey AND p.IsDeleted = 0;

IF @ItemId IS NULL
    THROW 51121, N'آیتم قیمت یافت نشد', 1;

DECLARE @PrevSystem DECIMAL(18,2), @PrevBuy DECIMAL(18,2), @PrevSell DECIMAL(18,2);
SELECT @PrevSystem = SystemRate, @PrevBuy = BuyRate, @PrevSell = SellRate
FROM [currency].[PriceRates] WHERE PriceItemId = @ItemId;

BEGIN TRAN;
    IF @RateKind = N'System'
    BEGIN
        UPDATE [currency].[PriceRates]
        SET SystemRate    = @NewValue,
            IsOverride    = 1,                       -- دستی/تأیید مدیر — آنلاین خودکار جایگزین نکند
            PrevValue     = @PrevSystem,
            ChangeAmount  = @NewValue - @PrevSystem,
            ChangePercent = CASE WHEN ISNULL(@PrevSystem, 0) <> 0
                                 THEN (@NewValue - @PrevSystem) * 100.0 / @PrevSystem
                                 ELSE NULL END,
            LastChangeAt  = SYSUTCDATETIME(),
            SourceKey     = CASE WHEN @SourceKey IS NOT NULL THEN @SourceKey ELSE SourceKey END,
            RateDate      = CAST(SYSDATETIME() AS DATE),
            IsValid       = 1,
            Status        = N'Active',
            UpdatedAt     = SYSUTCDATETIME(),
            UpdatedBy     = @ChangedBy
        WHERE PriceItemId = @ItemId;

        INSERT INTO [currency].[RateHistory]
            (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
        VALUES
            (@ItemType, @ItemKey, N'System', @PrevSystem, @NewValue, @SourceKey, N'Manual', @Reason, @ChangedBy, 0);
    END
    ELSE IF @RateKind = N'Manual'
    BEGIN
        UPDATE [currency].[PriceRates]
        SET ManualRate    = @NewValue,
            UpdatedAt     = SYSUTCDATETIME(),
            UpdatedBy     = @ChangedBy
        WHERE PriceItemId = @ItemId;

        INSERT INTO [currency].[RateHistory]
            (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
        VALUES
            (@ItemType, @ItemKey, N'Manual', NULL, @NewValue, N'MANUAL', N'Manual', @Reason, @ChangedBy, 0);
    END
    ELSE IF @RateKind = N'Buy'
    BEGIN
        -- توجه: در UPDATE، ارجاع به ستون‌ها مقدار «قدیمی» ردیف است، پس میانی/اسپرد
        -- را صریحاً با @NewValue محاسبه می‌کنیم.
        UPDATE [currency].[PriceRates]
        SET BuyRate       = @NewValue,
            MidRate       = CASE WHEN SellRate IS NOT NULL THEN (@NewValue + SellRate) / 2.0 ELSE NULL END,
            Spread        = CASE WHEN SellRate IS NOT NULL THEN SellRate - @NewValue ELSE NULL END,
            UpdatedAt     = SYSUTCDATETIME(),
            UpdatedBy     = @ChangedBy
        WHERE PriceItemId = @ItemId;

        INSERT INTO [currency].[RateHistory]
            (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
        VALUES
            (@ItemType, @ItemKey, N'Buy', @PrevBuy, @NewValue, N'MANUAL', N'Manual', @Reason, @ChangedBy, 0);
    END
    ELSE IF @RateKind = N'Sell'
    BEGIN
        UPDATE [currency].[PriceRates]
        SET SellRate      = @NewValue,
            MidRate       = CASE WHEN BuyRate IS NOT NULL THEN (BuyRate + @NewValue) / 2.0 ELSE NULL END,
            Spread        = CASE WHEN BuyRate IS NOT NULL THEN @NewValue - BuyRate ELSE NULL END,
            UpdatedAt     = SYSUTCDATETIME(),
            UpdatedBy     = @ChangedBy
        WHERE PriceItemId = @ItemId;

        INSERT INTO [currency].[RateHistory]
            (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
        VALUES
            (@ItemType, @ItemKey, N'Sell', @PrevSell, @NewValue, N'MANUAL', N'Manual', @Reason, @ChangedBy, 0);
    END
    ELSE IF @RateKind = N'Accounting'
    BEGIN
        UPDATE [currency].[PriceRates]
        SET AccountingRate = @NewValue,
            UpdatedAt      = SYSUTCDATETIME(),
            UpdatedBy      = @ChangedBy
        WHERE PriceItemId = @ItemId;

        INSERT INTO [currency].[RateHistory]
            (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
        VALUES
            (@ItemType, @ItemKey, N'Accounting', NULL, @NewValue, N'MANUAL', N'Manual', @Reason, @ChangedBy, 0);
    END
    ELSE
        THROW 51122, N'نوع نرخ نامعتبر است', 1;
COMMIT;
