-- =============================================
-- webapi/Data/Scripts/central/PartySearch_V1.sql
-- Schema: central | Contract: Party v1 (backward-compat, NO NationalId)
-- Query. Kept for v1 consumers until they migrate (ADR-003).
-- =============================================
SELECT
    p.PartyId,
    p.PartyCode,
    p.PartyType,
    p.FullName,
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
