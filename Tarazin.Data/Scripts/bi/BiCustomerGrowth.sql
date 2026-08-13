-- =============================================
-- Tarazin.Data/Scripts/bi/BiCustomerGrowth.sql
-- Schema: bi
-- Cross-schema: central
-- Query. رشد مشتریان (§83): تعداد مشتریان جدید ماهانه (ساخته‌شده).
-- خروجی: سری (Bucket=ماه, Label, Value1=مشتری جدید)
-- =============================================
DECLARE @From DATE = ISNULL(@FromDate, DATEADD(MONTH, -11, CAST(SYSDATETIME() AS DATE)));
DECLARE @To DATE = ISNULL(@ToDate, CAST(SYSDATETIME() AS DATE));

SELECT DATEFROMPARTS(YEAR(CreatedAt), MONTH(CreatedAt), 1) AS Bucket,
       FORMAT(DATEFROMPARTS(YEAR(CreatedAt), MONTH(CreatedAt), 1), N'yyyy/MM') AS Label,
       COUNT(*) AS Value1,
       0 AS Value2, 0 AS Value3, 0 AS Value4
FROM [central].[Parties]
WHERE PartyType = N'Customer' AND IsDeleted = 0
  AND CreatedAt BETWEEN @From AND DATEADD(DAY, 1, @To)
GROUP BY DATEFROMPARTS(YEAR(CreatedAt), MONTH(CreatedAt), 1)
ORDER BY Bucket;
