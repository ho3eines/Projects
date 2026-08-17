-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentPeriodClose.sql
-- Schema: accounting
-- Execute. عملیات ویژه: بستن دوره.
-- Checks that every document in the period is balanced (debit == credit), then
-- marks non-closed documents as Closed. Returns the number of closed documents.
-- =============================================
DECLARE @Bad INT;

SELECT @Bad = COUNT(*)
FROM (
    SELECT d.DocumentId
    FROM [accounting].[Documents] d
    LEFT JOIN [accounting].[DocumentLines] l ON l.DocumentId = d.DocumentId
    WHERE d.DocumentDate BETWEEN @FromDate AND @ToDate AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
      AND d.Status = N'Posted'
    GROUP BY d.DocumentId
    HAVING ISNULL(SUM(l.Debit), 0) <> ISNULL(SUM(l.Credit), 0)
) x;

IF @Bad > 0
    THROW 51042, N'اسناد نامتوازن در بازه وجود دارد؛ ابتدا اصلاح کنید', 1;

-- «بستن دوره» = تأیید نهاییِ اسنادِ تأییدشده.
-- مطابق چرخهٔ وضعیت سند (یادداشت → موقت → تأیید شده → تأیید نهایی)، اسنادی که
-- هنوز یادداشت/موقت‌اند نباید یک‌باره به «تأیید نهایی» بپرند؛ آن‌ها ابتدا باید
-- تأیید شوند. قبلاً این اسکریپت همه را بی‌قید Closed می‌کرد و چرخه را دور می‌زد.
UPDATE [accounting].[Documents]
SET Status = N'Closed', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
WHERE DocumentDate BETWEEN @FromDate AND @ToDate
  AND Status = N'Posted' AND IsDeleted = 0 AND CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId;
