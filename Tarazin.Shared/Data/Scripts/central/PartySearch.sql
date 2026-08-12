-- =============================================
-- Tarazin.Shared/Data/Scripts/central/PartySearch.sql
-- Schema: central | Contract: Party v2
-- Query. Shape MUST match PartyRow (Share) exactly.
-- =============================================
SELECT
    p.PartyId,
    p.PartyCode,
    p.PartyType,
    p.FullName,
    p.NationalId,
    p.Phone,
    p.Email,
    p.IsActive,
    p.CreatedAt
FROM [central].[Parties] p
WHERE p.IsDeleted = 0
  AND (@PartyType IS NULL OR p.PartyType = @PartyType)
  AND (@SearchText = N'' OR p.FullName LIKE N'%' + @SearchText + N'%'
       OR p.PartyCode LIKE N'%' + @SearchText + N'%')
ORDER BY p.PartyId
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
