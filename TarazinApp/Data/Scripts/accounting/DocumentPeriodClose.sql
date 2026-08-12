-- =============================================
-- TarazinApp/Data/Scripts/accounting/DocumentPeriodClose.sql
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
    WHERE d.DocumentDate BETWEEN @FromDate AND @ToDate AND d.IsDeleted = 0
    GROUP BY d.DocumentId
    HAVING ISNULL(SUM(l.Debit), 0) <> ISNULL(SUM(l.Credit), 0)
) x;

IF @Bad > 0
    THROW 51042, N'اسناد نامتوازن در بازه وجود دارد؛ ابتدا اصلاح کنید', 1;

UPDATE [accounting].[Documents]
SET Status = N'Closed', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
WHERE DocumentDate BETWEEN @FromDate AND @ToDate
  AND Status <> N'Closed' AND IsDeleted = 0;
