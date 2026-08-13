-- =============================================
-- Tarazin.Data/Scripts/currency/FeedApply.sql
-- Schema: currency
-- Execute. اعمال نرخ‌های دریافت‌شدهٔ آنلاین در مرکز قیمت (PRD §44/§46/§56/§57).
--   ItemsJson: [ { "ItemKey":"USD", "Value":615200, "FetchedAt":"..." }, ... ]
--
-- قوانین کلیدی:
--   1. نرخ جدید فقط در «OnlineRate» می‌نشیند (§46)؛ هرگز مستقیم وارد معامله نمی‌شود.
--   2. اگر IsOverride=1 باشد (مدیر نرخ سیستم را دستی/تأیید کرده) نرخ آنلاین هرگز
--      نرخ سیستم را عوض نمی‌کند.
--   3. فقط اگر تنظیم AutoPromoteOnlineToSystem=1 و IsOverride=0 باشد، نرخ سیستم
--      خودکار هم‌گام می‌شود (خط مشی مدیر — §56).
--   4. در صورت قطع منبع (صفر/نامعتبر) هیچ‌چیز صفر نمی‌شود — آخرین نرخ معتبر می‌ماند (§57).
-- =============================================
IF @ItemsJson IS NULL OR LEN(@ItemsJson) = 0
    THROW 51140, N'داده‌ای برای اعمال وجود ندارد', 1;

DECLARE @AutoPromote INT = ISNULL((
    SELECT TRY_CAST(SettingValue AS INT) FROM [currency].[Settings]
    WHERE SettingKey = N'AutoPromoteOnlineToSystem'), 0);

DECLARE @Now DATETIME2 = SYSUTCDATETIME();

BEGIN TRAN;
    -- آخرین مقدار هر منبع (برای مقایسهٔ منابع — §59).
    MERGE [currency].[PriceSourceValues] AS target
    USING (
        SELECT @SourceKey AS SourceKey, p.PriceItemId AS PriceItemId, j.Value AS Value, ISNULL(j.FetchedAt, @Now) AS FetchedAt
        FROM OPENJSON(@ItemsJson)
        WITH (ItemKey NVARCHAR(50), Value DECIMAL(18,2), FetchedAt DATETIME2) j
        JOIN [currency].[PriceItems] p ON p.ItemKey = j.ItemKey AND p.IsDeleted = 0
    ) AS source
    ON target.SourceKey = source.SourceKey AND target.PriceItemId = source.PriceItemId
    WHEN MATCHED THEN
        UPDATE SET Value = source.Value, FetchedAt = source.FetchedAt
    WHEN NOT MATCHED THEN
        INSERT (SourceKey, PriceItemId, Value, FetchedAt) VALUES (source.SourceKey, source.PriceItemId, source.Value, source.FetchedAt);

    -- به‌روزرسانی نرخ آنلاین + تاریخچه (هرگز صفر نمی‌شود).
    DECLARE @Item NVARCHAR(50), @Val DECIMAL(18,2), @ItemType NVARCHAR(20), @Prev DECIMAL(18,2), @Sys DECIMAL(18,2), @Ov BIT;
    DECLARE feed CURSOR LOCAL FAST_FORWARD FOR
        SELECT j.ItemKey, j.Value, p.ItemType
        FROM OPENJSON(@ItemsJson)
        WITH (ItemKey NVARCHAR(50), Value DECIMAL(18,2)) j
        JOIN [currency].[PriceItems] p ON p.ItemKey = j.ItemKey AND p.IsDeleted = 0
        WHERE j.Value > 0;

    OPEN feed;
    FETCH NEXT FROM feed INTO @Item, @Val, @ItemType;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @Prev = OnlineRate, @Sys = SystemRate, @Ov = IsOverride
        FROM [currency].[PriceRates] WHERE PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = @Item);

        -- اگر آیتم هنوز ردیف نرخ ندارد (مثلاً ارز جدیدِ هنوز قیمت‌گذاری‌نشده)، ردیف ساخته
        -- می‌شود؛ نرخ سیستم ۰ می‌ماند تا مدیر آن را تعیین کند — هرگز صفر وارد معامله نمی‌شود (§57).
        IF @Prev IS NULL
        BEGIN
            INSERT INTO [currency].[PriceRates]
                (PriceItemId, OnlineRate, SystemRate, SourceKey, Status, RateDate, UpdatedAt, UpdatedBy)
            VALUES
                ((SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = @Item), @Val, 0,
                 @SourceKey, N'Active', CAST(@Now AS DATE), @Now, @CreatedBy);
            SET @Prev = NULL;
        END

        UPDATE [currency].[PriceRates]
        SET OnlineRate     = @Val,
            PrevValue      = @Prev,
            ChangeAmount   = @Val - ISNULL(@Prev, @Val),
            ChangePercent  = CASE WHEN ISNULL(@Prev, 0) <> 0 THEN (@Val - @Prev) * 100.0 / @Prev ELSE NULL END,
            LastFetchAt    = @Now,
            LastChangeAt   = CASE WHEN ISNULL(@Prev, 0) <> @Val THEN @Now ELSE LastChangeAt END,
            SourceKey      = @SourceKey,
            RateDate       = CAST(@Now AS DATE),
            IsValid        = 1,
            Status         = N'Active',
            UpdatedAt      = @Now,
            UpdatedBy      = @CreatedBy
        WHERE PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = @Item);

        INSERT INTO [currency].[RateHistory]
            (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
        VALUES
            (@ItemType, @Item, N'Online', @Prev, @Val, @SourceKey, N'AutoFetch', N'دریافت خودکار از منبع ' + @SourceKey, @CreatedBy, 1);

        -- خط مشی ورود به نرخ سیستم (§46/§56): فقط با تأیید مدیر یا با AutoPromote.
        IF @AutoPromote = 1 AND ISNULL(@Ov, 0) = 0 AND ISNULL(@Sys, 0) <> @Val
        BEGIN
            UPDATE [currency].[PriceRates]
            SET SystemRate   = @Val,
                IsOverride   = 0,
                UpdatedAt    = @Now,
                UpdatedBy    = @CreatedBy
            WHERE PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = @Item);

            INSERT INTO [currency].[RateHistory]
                (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
            VALUES
                (@ItemType, @Item, N'System', @Sys, @Val, @SourceKey, N'AutoFetch', N'همگام‌سازی خودکار نرخ سیستم', @CreatedBy, 1);
        END

        FETCH NEXT FROM feed INTO @Item, @Val, @ItemType;
    END
    CLOSE feed;
    DEALLOCATE feed;

    -- وضعیت منبع: آنلاین.
    UPDATE [currency].[PriceSources]
    SET Status = N'Online', LastFetchAt = @Now, LastSuccessAt = @Now, LastValidAt = @Now,
        LastError = NULL, ErrorCount = 0, UpdatedAt = @Now
    WHERE SourceKey = @SourceKey;
COMMIT;
