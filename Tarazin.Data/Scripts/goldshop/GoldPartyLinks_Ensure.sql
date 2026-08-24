IF OBJECT_ID(N'goldshop.GoldPartyLinks',N'U') IS NULL
BEGIN
    CREATE TABLE [goldshop].[GoldPartyLinks] (
        CompanyId INT NOT NULL,
        PartyId INT NOT NULL,
        PartyType NVARCHAR(30) NOT NULL,
        DetailLinkId INT NULL,
        DetailAccountCode NVARCHAR(50) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy NVARCHAR(100) NULL,
        UpdatedAt DATETIME2 NULL,
        UpdatedBy NVARCHAR(100) NULL,
        CONSTRAINT PK_GoldPartyLinks PRIMARY KEY (CompanyId, PartyId),
        CONSTRAINT FK_GoldPartyLinks_Party FOREIGN KEY (PartyId) REFERENCES [central].[Parties](PartyId)
    );
END
