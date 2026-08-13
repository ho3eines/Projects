-- =============================================
-- Tarazin.Data/Scripts/branch/BranchUpsert.sql
-- Schema: branch
-- Execute. ایجاد/ویرایش شعبه.
-- =============================================
IF LEN(LTRIM(RTRIM(@BranchCode))) = 0 OR LEN(LTRIM(RTRIM(@Title))) = 0
    THROW 51210, N'کد و عنوان شعبه الزامی است', 1;

IF @BranchId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [branch].[Branches] WHERE BranchCode = @BranchCode)
        THROW 51211, N'این کد شعبه قبلاً ثبت شده است', 1;

    INSERT INTO [branch].[Branches] (BranchCode, Title, Location, Manager, IsActive, CreatedAt, CreatedBy)
    VALUES (@BranchCode, @Title, NULLIF(@Location, N''), NULLIF(@Manager, N''), 1, SYSUTCDATETIME(), @CreatedBy);
END
ELSE
BEGIN
    UPDATE [branch].[Branches]
    SET BranchCode = @BranchCode,
        Title      = @Title,
        Location   = NULLIF(@Location, N''),
        Manager    = NULLIF(@Manager, N''),
        IsActive   = ISNULL(@IsActive, IsActive),
        UpdatedAt  = SYSUTCDATETIME(),
        UpdatedBy  = @CreatedBy
    WHERE BranchId = @BranchId;
END
