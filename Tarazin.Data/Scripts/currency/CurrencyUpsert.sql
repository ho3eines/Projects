-- =============================================
-- Tarazin.Data/Scripts/currency/CurrencyUpsert.sql
-- Schema: currency
-- Execute. ایجاد/ویرایش تعریف ارز (PRD §34: امکان تعریف ارز جدید توسط مدیر).
-- وقتی ارز جدید ساخته می‌شود، آیتم مرکز قیمت و ردیف نرخ هم ساخته می‌شود
-- تا «مرکز قیمت واحد» (§60) همیشه برای همهٔ ارزها برقرار باشد.
-- =============================================
IF LEN(LTRIM(RTRIM(@CurrencyCode))) < 2 OR LEN(LTRIM(RTRIM(@CurrencyName))) = 0
    THROW 51100, N'کد و نام ارز الزامی است', 1;

DECLARE @Code NVARCHAR(10) = UPPER(LTRIM(RTRIM(@CurrencyCode)));
DECLARE @IsBase BIT = CASE WHEN @Code = N'IRR' THEN 1 ELSE ISNULL(@IsBase, 0) END;
DECLARE @Factor DECIMAL(18,4) = ISNULL(@UnitFactor, 1);
IF @Factor <= 0
    THROW 51101, N'ضریب واحد باید بزرگ‌تر از صفر باشد', 1;

BEGIN TRAN;
    IF @CurrencyId = 0
    BEGIN
        -- واحد پایهٔ سیستم ریال است؛ نمی‌توان واحد پایهٔ دیگری ساخت (§35).
        IF EXISTS (SELECT 1 FROM [currency].[Currencies] WHERE IsBase = 1 AND IsDeleted = 0)
           AND @IsBase = 1
           AND @Code <> N'IRR'
            THROW 51102, N'واحد پایهٔ سیستم فقط ریال است', 1;

        IF EXISTS (SELECT 1 FROM [currency].[Currencies] WHERE CurrencyCode = @Code)
            THROW 51103, N'این ارز قبلاً تعریف شده است', 1;

        INSERT INTO [currency].[Currencies] (CurrencyCode, CurrencyName, Symbol, IsBase, UnitFactor, IsActive, CreatedAt, CreatedBy)
        VALUES (@Code, @CurrencyName, NULLIF(LTRIM(RTRIM(@Symbol)), N''), @IsBase, @Factor, 1, SYSUTCDATETIME(), @CreatedBy);

        DECLARE @Cid INT = SCOPE_IDENTITY();

        -- آیتم مرکز قیمت + ردیف نرخ (نرخ سیستم اولیه = ضریب واحد برای ریال/تومان، وگرنه 0 تا مدیر نرخ بدهد).
        IF NOT EXISTS (SELECT 1 FROM [currency].[PriceItems] WHERE ItemKey = @Code AND IsDeleted = 0)
        BEGIN
            INSERT INTO [currency].[PriceItems] (ItemType, ItemKey, Title, Unit, IsActive, CreatedAt, CreatedBy)
            VALUES (N'Currency', @Code, @CurrencyName, N'واحد', 1, SYSUTCDATETIME(), @CreatedBy);

            DECLARE @Pid INT = SCOPE_IDENTITY();
            DECLARE @InitialRate DECIMAL(18,2) = CASE WHEN @Code IN (N'IRR', N'TOMAN') THEN @Factor ELSE 0 END;

            INSERT INTO [currency].[PriceRates] (PriceItemId, SystemRate, SourceKey, Status, RateDate, UpdatedAt, UpdatedBy)
            VALUES (@Pid, @InitialRate, N'MANUAL', N'Active', CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME(), @CreatedBy);

            IF @InitialRate > 0
                INSERT INTO [currency].[RateHistory] (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
                VALUES (N'Currency', @Code, N'System', NULL, @InitialRate, N'MANUAL', N'Manual', N'تعریف ارز جدید', @CreatedBy, 0);
        END
    END
    ELSE
    BEGIN
        UPDATE [currency].[Currencies]
        SET CurrencyName = @CurrencyName,
            Symbol       = NULLIF(LTRIM(RTRIM(@Symbol)), N''),
            UnitFactor   = @Factor,
            IsActive     = ISNULL(@IsActive, IsActive),
            UpdatedAt    = SYSUTCDATETIME(),
            UpdatedBy    = @CreatedBy
        WHERE CurrencyId = @CurrencyId;

        -- همگام‌سازی عنوان در مرکز قیمت.
        UPDATE p SET p.Title = @CurrencyName, p.UpdatedAt = SYSUTCDATETIME(), p.UpdatedBy = @CreatedBy
        FROM [currency].[PriceItems] p
        WHERE p.ItemKey = (SELECT CurrencyCode FROM [currency].[Currencies] WHERE CurrencyId = @CurrencyId);
    END
COMMIT;
