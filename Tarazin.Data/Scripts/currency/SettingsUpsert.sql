-- =============================================
-- Tarazin.Data/Scripts/currency/SettingsUpsert.sql
-- Schema: currency
-- Execute. ذخیرهٔ یک تنظیم (upsert).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [currency].[Settings] WHERE SettingKey = @SettingKey)
    INSERT INTO [currency].[Settings] (SettingKey, SettingValue, Description)
    VALUES (@SettingKey, @SettingValue, @Description);
ELSE
    UPDATE [currency].[Settings]
    SET SettingValue = @SettingValue,
        Description  = ISNULL(@Description, Description)
    WHERE SettingKey = @SettingKey;
