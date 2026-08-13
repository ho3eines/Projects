-- =============================================
-- Tarazin.Data/Scripts/bi/BiCashFlowTrend.sql
-- Schema: bi
-- Cross-schema: treasury
-- Query. روند جریان نقدی (§14): دریافت/پرداخت/خالص روزانه.
-- خروجی: (Bucket, Label, Value1=دریافت, Value2=پرداخت, Value3=خالص)
-- =============================================
DECLARE @From DATE = ISNULL(@FromDate, DATEADD(DAY, -29, CAST(SYSDATETIME() AS DATE)));
DECLARE @To DATE = ISNULL(@ToDate, CAST(SYSDATETIME() AS DATE));

SELECT MovementDate AS Bucket,
       FORMAT(MovementDate, 'yyyy/MM/dd') AS Label,
       ISNULL(SUM(CASE WHEN Direction = N'In' THEN Amount ELSE 0 END), 0) AS Value1,
       ISNULL(SUM(CASE WHEN Direction = N'Out' THEN Amount ELSE 0 END), 0) AS Value2,
       ISNULL(SUM(CASE WHEN Direction = N'In' THEN Amount ELSE -Amount END), 0) AS Value3,
       0 AS Value4
FROM [treasury].[CashMovements]
WHERE MovementDate BETWEEN @From AND @To
GROUP BY MovementDate
ORDER BY MovementDate;
