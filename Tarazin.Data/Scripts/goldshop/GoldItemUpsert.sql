-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldItemUpsert.sql
-- Schema: goldshop
-- Execute.
-- =============================================
-- GoldItemId=0 identifies a new record; every non-zero id is an edit.
IF @GoldItemId = 0
BEGIN
    INSERT INTO [goldshop].[GoldItems] (ItemCode, Title, Purity, IsActive, CreatedAt)
    VALUES (@ItemCode, @Title, @Purity, ISNULL(@IsActive, 1), SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [goldshop].[GoldItems]
    SET ItemCode = ISNULL(@ItemCode, ItemCode),
        Title    = ISNULL(@Title, Title),
        Purity   = @Purity,
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE GoldItemId = @GoldItemId;
END
