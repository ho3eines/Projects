-- =============================================
-- Tarazin.Data/Scripts/store/ProductCategoryUpsert.sql
-- Schema: store
-- Execute.
-- =============================================
-- CategoryId=0 identifies a new record; every non-zero id is an edit.
IF @CategoryId = 0
BEGIN
    INSERT INTO [store].[ProductCategories] (CategoryCode, Title, SortOrder, IsActive, CreatedAt, CreatedBy)
    VALUES (ISNULL(NULLIF(@CategoryCode, N''),
                N'CAT-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(CategoryId) FROM [store].[ProductCategories]), 0) + 1 AS NVARCHAR(10)), 5)),
            @Title, ISNULL(@SortOrder, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);
END
ELSE
BEGIN
    UPDATE [store].[ProductCategories]
    SET CategoryCode = ISNULL(@CategoryCode, CategoryCode),
        Title        = ISNULL(@Title, Title),
        SortOrder    = ISNULL(@SortOrder, SortOrder),
        IsActive     = ISNULL(@IsActive, IsActive),
        UpdatedAt    = SYSUTCDATETIME(),
        UpdatedBy    = @UpdatedBy
    WHERE CategoryId = @CategoryId AND IsDeleted = 0;
END
