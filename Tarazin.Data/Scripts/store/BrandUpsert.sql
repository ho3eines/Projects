-- =============================================
-- Tarazin.Data/Scripts/store/BrandUpsert.sql
-- Schema: store
-- Execute. درج/ویرایش برند. کد تکراری → 51340.
-- =============================================
DECLARE @Code NVARCHAR(30) = LTRIM(RTRIM(ISNULL(@BrandCode, N'')));
DECLARE @Ttl NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@Title, N'')));

IF @Ttl = N''
    THROW 51341, N'نام برند الزامی است', 1;

IF @Code = N''
    SET @Code = N'BR-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(BrandId) FROM [store].[Brands] WHERE CompanyId = @CompanyId), 0) + 1 AS NVARCHAR(10)), 5);

IF EXISTS (SELECT 1 FROM [store].[Brands]
           WHERE CompanyId = @CompanyId AND BrandCode = @Code
             AND IsDeleted = 0 AND BrandId <> ISNULL(@BrandId, 0))
    THROW 51340, N'کد برند در این شرکت تکراری است', 1;

IF ISNULL(@BrandId, 0) = 0
BEGIN
    INSERT INTO [store].[Brands]
        (CompanyId, BrandCode, Title, LogoUrl, [Description], IsActive, CreatedAt, CreatedBy)
    VALUES
        (@CompanyId, @Code, @Ttl, @LogoUrl, @Description, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
END
ELSE
BEGIN
    UPDATE [store].[Brands]
    SET Title = @Ttl, LogoUrl = @LogoUrl, [Description] = @Description,
        IsActive = ISNULL(@IsActive, IsActive), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
    WHERE BrandId = @BrandId AND CompanyId = @CompanyId AND IsDeleted = 0;

    IF @@ROWCOUNT = 0 THROW 51342, N'برند یافت نشد', 1;
    SELECT @BrandId AS NewId;
END
