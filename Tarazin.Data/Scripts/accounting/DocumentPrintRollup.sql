-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentPrintRollup.sql
-- Schema: accounting
-- چاپ پیشرفته سند: عناوین و جمع بدهکار/بستانکار حساب کل (۲ رقم اول) و معین (۵ رقم اول).
-- خروجی: Level = Kol | Moein — یک ردیف برای هر کد یکتا در سند.
-- =============================================
SELECT N'Kol' AS [Level],
       LEFT(l.AccountCode, 2) AS Code,
       MAX(c.Title) AS Title,
       COUNT(*) AS LineCount,
       SUM(l.Debit) AS Debit,
       SUM(l.Credit) AS Credit
FROM [accounting].[DocumentLines] l
LEFT JOIN [accounting].[BaseCol] c
       ON c.ColCode = LEFT(l.AccountCode, 2)
      AND c.CompanyId = @CompanyId AND c.IsDeleted = 0
WHERE l.DocumentId = @DocumentId
  AND l.CompanyId = @CompanyId
GROUP BY LEFT(l.AccountCode, 2)

UNION ALL

SELECT N'Moein' AS [Level],
       LEFT(l.AccountCode, 5) AS Code,
       MAX(m.Title) AS Title,
       COUNT(*) AS LineCount,
       SUM(l.Debit) AS Debit,
       SUM(l.Credit) AS Credit
FROM [accounting].[DocumentLines] l
LEFT JOIN [accounting].[BaseCol] c
       ON c.ColCode = LEFT(l.AccountCode, 2)
      AND c.CompanyId = @CompanyId AND c.IsDeleted = 0
LEFT JOIN [accounting].[BaseMoein] m
       ON m.ColId = c.ColId
      AND m.MoeinCode = SUBSTRING(l.AccountCode, 3, 3)
      AND m.IsDeleted = 0
WHERE l.DocumentId = @DocumentId
  AND l.CompanyId = @CompanyId
GROUP BY LEFT(l.AccountCode, 5)
ORDER BY [Level] DESC, Code ASC;