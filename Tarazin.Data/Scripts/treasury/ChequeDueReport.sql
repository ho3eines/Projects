-- =============================================
-- Tarazin.Data/Scripts/treasury/ChequeDueReport.sql
-- Schema: treasury
-- Query. گزارش چک‌های در جریان (Pending / Collecting) با هشدار سررسید.
--
--   AlertLevel:
--     Overdue — سررسید گذشته است (DueDate < امروز)
--     DueSoon — تا ۷ روز آینده سررسید می‌شود (شامل امروز)
--     OnTime  — بیش از ۷ روز مانده
--   @AlertFilter: N'All' (همه) یا N'Problem' (فقط سررسیدشده + نزدیک).
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

SELECT c.ChequeId,
       c.ChequeNumber,
       b.Title AS BankName,
       c.Amount,
       c.DueDate,
       c.Direction,
       c.Status,
       c.SourceReference,
       DATEDIFF(DAY, @Today, c.DueDate) AS DaysToDue,
       CASE
           WHEN c.DueDate < @Today THEN N'Overdue'
           WHEN DATEDIFF(DAY, @Today, c.DueDate) <= 7 THEN N'DueSoon'
           ELSE N'OnTime'
       END AS AlertLevel
FROM [treasury].[Cheques] c
LEFT JOIN [treasury].[Banks] b ON b.BankId = c.BankId
WHERE c.CompanyId = @CompanyId
  AND c.Status IN (N'Pending', N'Collecting')
  AND (@Direction IS NULL OR c.Direction = @Direction)
  AND (@AlertFilter IS NULL OR @AlertFilter = N'All'
       OR (@AlertFilter = N'Problem' AND c.DueDate <= DATEADD(DAY, 7, @Today)))
ORDER BY c.DueDate ASC, c.ChequeId DESC;
