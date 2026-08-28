-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemGroupUpsert.sql
-- Schema: inventory
-- Execute. ثبت/ویرایش گروه کالا. GroupId=0 یعنی رکورد جدید.
-- =============================================
DECLARE @EffectiveCode NVARCHAR(50) = ISNULL(NULLIF(@GroupCode, N''),
    N'GRP-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(GroupId) FROM [inventory].[ItemGroups] WHERE CompanyId = @CompanyId), 0) + 1 AS NVARCHAR(10)), 5));

IF @GroupId = 0
BEGIN
    INSERT INTO [inventory].[ItemGroups] (GroupCode, Title, SortOrder, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES (@EffectiveCode, @Title, ISNULL(@SortOrder, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [inventory].[ItemGroups]
    SET GroupCode = ISNULL(@GroupCode, GroupCode),
        Title     = ISNULL(@Title, Title),
        SortOrder = ISNULL(@SortOrder, SortOrder),
        IsActive  = ISNULL(@IsActive, IsActive),
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE GroupId = @GroupId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51030, N'گروه کالا یافت نشد.', 1;
END
