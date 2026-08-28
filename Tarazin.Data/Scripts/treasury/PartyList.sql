-- =============================================
-- Tarazin.Data/Scripts/treasury/PartyList.sql
-- Schema: treasury | Cross-schema: central
-- Query. طرف حساب‌های یکپارچه (مشتری/تأمین‌کننده) — همان [central].[Parties]
-- که طلافروشی و ارز هم استفاده می‌کنند؛ لینک حسابداری از [treasury].[PartyLinks].
-- =============================================
SELECT p.PartyId, p.PartyCode, p.PartyType, p.FullName, p.NationalId, p.Phone, p.Email,
       p.IsActive,
       link.DetailLinkId,
       link.DetailAccountCode
FROM [central].[Parties] p
LEFT JOIN [treasury].[PartyLinks] link ON link.PartyId = p.PartyId AND link.CompanyId = @CompanyId
WHERE p.CompanyId = @CompanyId AND p.IsDeleted = 0
  AND p.PartyType IN (N'Customer', N'Vendor')
  AND (@PartyType IS NULL OR p.PartyType = @PartyType)
  AND (@SearchText = N'' OR p.FullName LIKE N'%' + @SearchText + N'%' OR p.PartyCode LIKE N'%' + @SearchText + N'%')
ORDER BY p.FullName
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
