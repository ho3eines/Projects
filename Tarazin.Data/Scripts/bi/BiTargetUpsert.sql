-- =============================================
-- Tarazin.Data/Scripts/bi/BiTargetUpsert.sql
-- Schema: bi
-- Execute. ایجاد/به‌روزرسانی هدف (§117).
-- =============================================
IF EXISTS (SELECT 1 FROM [bi].[Targets]
           WHERE TargetKey = @TargetKey AND Period = @Period AND PeriodYear = @PeriodYear
             AND ISNULL(PeriodMonth, 0) = ISNULL(@PeriodMonth, 0))
BEGIN
    UPDATE [bi].[Targets]
    SET Title = @Title, TargetAmount = @TargetAmount, UpdatedAt = SYSUTCDATETIME(), CreatedBy = ISNULL(@CreatedBy, CreatedBy)
    WHERE TargetKey = @TargetKey AND Period = @Period AND PeriodYear = @PeriodYear
      AND ISNULL(PeriodMonth, 0) = ISNULL(@PeriodMonth, 0);
END
ELSE
BEGIN
    INSERT INTO [bi].[Targets] (TargetKey, Title, Period, PeriodYear, PeriodMonth, TargetAmount, CreatedAt, CreatedBy)
    VALUES (@TargetKey, @Title, @Period, @PeriodYear, @PeriodMonth, @TargetAmount, SYSUTCDATETIME(), @CreatedBy);
END
