IF EXISTS (SELECT 1 FROM [goldshop].[GoldPartyLedger] WHERE CompanyId=@CompanyId AND PartyId=@PartyId)
    THROW 51072, N'طرف حساب دارای گردش است و قابل حذف نیست؛ آن را غیرفعال کنید.', 1;
DELETE FROM [goldshop].[GoldPartyLinks] WHERE CompanyId=@CompanyId AND PartyId=@PartyId;
UPDATE [central].[Parties]
SET IsDeleted=1, IsActive=0, UpdatedAt=SYSUTCDATETIME()
WHERE PartyId=@PartyId AND CompanyId=@CompanyId AND IsDeleted=0;
