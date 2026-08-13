-- =============================================
-- Tarazin.Data/Scripts/bi/BiReceivablesAging.sql
-- Schema: bi
-- Cross-schema: accounting
-- Query. Aging مطالبات (§17): سن اسناد فروش/ارز بر اساس تاریخ سند.
-- خروجی: ترکیب (GroupKey=بازه, Title, Value=مبلغ, SecondaryValue=درصد)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

WITH docs AS (
    SELECT d.TotalAmount, DATEDIFF(DAY, d.DocumentDate, @Today) AS AgeDays
    FROM [accounting].[Documents] d
    WHERE d.IsDeleted = 0
      AND d.DocumentType IN (N'Sale', N'FxSell', N'FxCombined')
),
buckets AS (
    SELECT N'Current' AS GroupKey, N'جاری' AS Title, 0 AS MinAge, 0 AS MaxAge
    UNION ALL SELECT N'1-30', N'۱ تا ۳۰ روز', 1, 30
    UNION ALL SELECT N'31-60', N'۳۱ تا ۶۰ روز', 31, 60
    UNION ALL SELECT N'61-90', N'۶۱ تا ۹۰ روز', 61, 90
    UNION ALL SELECT N'91-180', N'۹۱ تا ۱۸۰ روز', 91, 180
    UNION ALL SELECT N'180+', N'بیش از ۱۸۰ روز', 181, 999999
)
SELECT b.GroupKey, b.Title,
       ISNULL((SELECT SUM(TotalAmount) FROM docs WHERE AgeDays BETWEEN b.MinAge AND b.MaxAge), 0) AS Value,
       CASE WHEN (SELECT SUM(TotalAmount) FROM docs) = 0 THEN 0
            ELSE ROUND(ISNULL((SELECT SUM(TotalAmount) FROM docs WHERE AgeDays BETWEEN b.MinAge AND b.MaxAge), 0) * 100.0
                       / (SELECT SUM(TotalAmount) FROM docs), 1) END AS SecondaryValue
FROM buckets b
ORDER BY b.MinAge;
