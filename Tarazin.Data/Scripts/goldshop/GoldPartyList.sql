SELECT p.PartyId, p.PartyCode, p.PartyType, p.FullName, p.NationalId, p.Phone, p.Email,
       p.IsActive,
       ISNULL(SUM(l.DebitRial - l.CreditRial), 0) AS BalanceRial,
       ISNULL(SUM(l.DebitGoldGram - l.CreditGoldGram), 0) AS GoldBalanceGram,
       ISNULL(SUM(CASE WHEN l.CurrencyCode = N'IRR' THEN 0 ELSE l.DebitCurrency - l.CreditCurrency END), 0) AS CurrencyBalance,
       MAX(l.CurrencyCode) AS CurrencyCode,
       link.DetailLinkId,
       link.DetailAccountCode
FROM [central].[Parties] p
LEFT JOIN [goldshop].[GoldPartyLedger] l ON l.PartyId = p.PartyId AND l.CompanyId = @CompanyId
LEFT JOIN [goldshop].[GoldPartyLinks] link ON link.PartyId = p.PartyId AND link.CompanyId = @CompanyId
WHERE p.CompanyId = @CompanyId AND p.IsDeleted = 0
  AND p.PartyType IN (N'Customer', N'Vendor')
  AND (@PartyType IS NULL OR p.PartyType = @PartyType)
  AND (@SearchText = N'' OR p.FullName LIKE N'%' + @SearchText + N'%' OR p.PartyCode LIKE N'%' + @SearchText + N'%')
GROUP BY p.PartyId, p.PartyCode, p.PartyType, p.FullName, p.NationalId, p.Phone, p.Email, p.IsActive,
         link.DetailLinkId, link.DetailAccountCode
ORDER BY p.FullName
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
