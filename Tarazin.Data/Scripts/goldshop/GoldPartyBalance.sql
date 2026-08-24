SELECT LedgerId, PartyId, InvoiceId, EntryDate, EntryType, DebitRial, CreditRial,
       DebitGoldGram, CreditGoldGram, DebitCurrency, CreditCurrency, CurrencyCode, Description
FROM [goldshop].[GoldPartyLedger]
WHERE CompanyId=@CompanyId AND PartyId=@PartyId
ORDER BY EntryDate, LedgerId;
