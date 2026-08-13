-- =============================================
-- Tarazin.Data/Scripts/currency/PriceSourceUpsert.sql
-- Schema: currency
-- Execute. ایجاد/ویرایش منبع قیمت (نقطهٔ Endpoint و نگاشت‌ها توسط مدیر قابل
-- ویرایش است — PRD §61: بدون وابستگی به HTML Selector شکننده).
-- =============================================
IF @SourceId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [currency].[PriceSources] WHERE SourceKey = @SourceKey)
        THROW 51110, N'این منبع قبلاً تعریف شده است', 1;

    INSERT INTO [currency].[PriceSources]
        (SourceKey, Title, BaseUrl, Endpoint, MappingsJson, IsActive, Priority, FetchIntervalSeconds, Status, CreatedAt, CreatedBy)
    VALUES
        (UPPER(LTRIM(RTRIM(@SourceKey))), @Title, NULLIF(@BaseUrl, N''), NULLIF(@Endpoint, N''), NULLIF(@MappingsJson, N''),
         ISNULL(@IsActive, 1), ISNULL(@Priority, 100), ISNULL(@FetchIntervalSeconds, 300), N'Unknown', SYSUTCDATETIME(), @CreatedBy);
END
ELSE
BEGIN
    UPDATE [currency].[PriceSources]
    SET Title                = @Title,
        BaseUrl              = NULLIF(@BaseUrl, N''),
        Endpoint             = NULLIF(@Endpoint, N''),
        MappingsJson         = NULLIF(@MappingsJson, N''),
        IsActive             = ISNULL(@IsActive, IsActive),
        Priority             = ISNULL(@Priority, Priority),
        FetchIntervalSeconds = ISNULL(@FetchIntervalSeconds, FetchIntervalSeconds),
        UpdatedAt            = SYSUTCDATETIME(),
        UpdatedBy            = @CreatedBy
    WHERE SourceId = @SourceId;
END
