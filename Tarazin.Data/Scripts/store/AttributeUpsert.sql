-- =============================================
-- Tarazin.Data/Scripts/store/AttributeUpsert.sql
-- Schema: store
-- Execute. درج/ویرایش ویژگی داینامیک (بدون تغییر اسکیما).
-- =============================================
DECLARE @Ttl NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@Title, N'')));
IF @Ttl = N''
    THROW 51350, N'نام ویژگی الزامی است', 1;

IF EXISTS (SELECT 1 FROM [store].[Attributes]
           WHERE CompanyId = @CompanyId AND Title = @Ttl AND IsDeleted = 0
             AND AttributeId <> ISNULL(@AttributeId, 0))
    THROW 51351, N'ویژگی با این نام قبلاً تعریف شده است', 1;

IF ISNULL(@AttributeId, 0) = 0
BEGIN
    INSERT INTO [store].[Attributes]
        (CompanyId, AttributeGroupId, Title, DataType, Unit, IsVariantFacet, SortOrder, IsActive, CreatedAt)
    VALUES
        (@CompanyId, @AttributeGroupId, @Ttl,
         ISNULL(NULLIF(LTRIM(RTRIM(@DataType)), N''), N'Text'),
         @Unit, ISNULL(@IsVariantFacet, 0), ISNULL(@SortOrder, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME());
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
END
ELSE
BEGIN
    UPDATE [store].[Attributes]
    SET AttributeGroupId = @AttributeGroupId, Title = @Ttl,
        DataType = ISNULL(NULLIF(LTRIM(RTRIM(@DataType)), N''), DataType),
        Unit = @Unit, IsVariantFacet = ISNULL(@IsVariantFacet, IsVariantFacet),
        SortOrder = ISNULL(@SortOrder, SortOrder), IsActive = ISNULL(@IsActive, IsActive)
    WHERE AttributeId = @AttributeId AND CompanyId = @CompanyId AND IsDeleted = 0;

    IF @@ROWCOUNT = 0 THROW 51352, N'ویژگی یافت نشد', 1;
    SELECT @AttributeId AS NewId;
END
