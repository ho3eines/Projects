-- =============================================
-- Tarazin.Data/Scripts/bi/BiChequeCalendar.sql
-- Schema: bi
-- Cross-schema: treasury
-- Query. تقویم چک (§67): چک‌های سررسید ۳۰ روز آینده.
-- خروجی: جدول (Col1=شماره, Col2=بانک, Col3=جهت, Col4=وضعیت, Date1=سررسید, Amount)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

SELECT c.ChequeNumber AS RowKey,
       c.ChequeNumber AS Col1,
       ISNULL(b.Title, N'—') AS Col2,
       CASE c.Direction WHEN N'In' THEN N'دریافتی' ELSE N'پرداختی' END AS Col3,
       c.Status AS Col4,
       CAST(c.Amount AS DECIMAL(18,2)) AS Amount,
       c.Amount AS SecondaryAmount,
       c.DueDate AS Date1,
       N'/treasury' AS Link
FROM [treasury].[Cheques] c
LEFT JOIN [treasury].[Banks] b ON b.BankId = c.BankId
WHERE c.DueDate BETWEEN @Today AND DATEADD(DAY, 30, @Today)
  AND c.Status = N'Pending'
ORDER BY c.DueDate;
