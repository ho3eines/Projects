-- =============================================
-- webapi/Data/Scripts/central/PartyUpsert.sql
-- Schema: central | Contract: Party (producer)
-- Execute.
-- =============================================
DECLARE @PartyCodeLocal NVARCHAR(50) = ISNULL(@PartyCode, N'PRT-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(PartyId) FROM [central].[Parties]), 0) + 1 AS NVARCHAR(10)), 5));

IF NOT EXISTS (SELECT 1 FROM [central].[Parties] WHERE PartyId = @PartyId)
BEGIN
    INSERT INTO [central].[Parties] (PartyCode, PartyType, FullName, NationalId, Phone, Email, IsActive, CreatedAt, CreatedBy)
    VALUES (@PartyCodeLocal, @PartyType, @FullName, @NationalId, @Phone, @Email, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy);
END
ELSE
BEGIN
    UPDATE [central].[Parties]
    SET PartyType  = ISNULL(@PartyType, PartyType),
        FullName   = ISNULL(@FullName, FullName),
        NationalId = @NationalId,
        Phone      = @Phone,
        Email      = @Email,
        IsActive   = ISNULL(@IsActive, IsActive),
        UpdatedAt  = SYSUTCDATETIME(),
        UpdatedBy  = @CreatedBy
    WHERE PartyId = @PartyId;
END
