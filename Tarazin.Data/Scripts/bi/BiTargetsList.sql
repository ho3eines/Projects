-- =============================================
-- Tarazin.Data/Scripts/bi/BiTargetsList.sql
-- Schema: bi
-- Query. فهرست اهداف (§117).
-- =============================================
SELECT TargetId, TargetKey, Title, Period, PeriodYear, PeriodMonth, TargetAmount, CreatedAt
FROM [bi].[Targets]
WHERE (@PeriodYear IS NULL OR PeriodYear = @PeriodYear)
  AND (@PeriodMonth IS NULL OR PeriodMonth = @PeriodMonth)
ORDER BY TargetKey, Period, PeriodYear, PeriodMonth;
