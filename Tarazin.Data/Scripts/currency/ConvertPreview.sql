-- =============================================
-- Tarazin.Data/Scripts/currency/ConvertPreview.sql
-- Schema: currency
-- Query. موتور تبدیل ارز — پیش‌نمایش محاسبه (PRD §39/§40/§41).
-- واحد مرجع تمام محاسبات ریال است:  ارز مبدا → ریال → ارز مقصد.
-- کارمزد می‌تواند درصدی/ثابت و به‌ارز مبدا/مقصد/ریالی باشد (§41).
-- =============================================
DECLARE @RialAmount DECIMAL(18,2) = ROUND(@SourceAmount * @SourceRate, 0);
DECLARE @BaseTarget DECIMAL(18,6) = @RialAmount / NULLIF(@TargetRate, 0);
DECLARE @FeeAmount DECIMAL(18,2) = 0;

IF @FeeType = N'Percent'
BEGIN
    SET @FeeAmount = CASE @FeeChargeTo
        WHEN N'Rial'   THEN ROUND(@RialAmount * @FeeValue / 100.0, 0)
        WHEN N'Source' THEN ROUND(@SourceAmount * @FeeValue / 100.0 * @SourceRate, 0)
        WHEN N'Target' THEN ROUND(@BaseTarget * @FeeValue / 100.0 * @TargetRate, 0)
        ELSE 0 END;
END
ELSE IF @FeeType = N'Fixed'
BEGIN
    SET @FeeAmount = CASE @FeeChargeTo
        WHEN N'Rial'   THEN @FeeValue
        WHEN N'Source' THEN ROUND(@FeeValue * @SourceRate, 0)
        WHEN N'Target' THEN ROUND(@FeeValue * @TargetRate, 0)
        ELSE 0 END;
END

DECLARE @NetRial DECIMAL(18,2) = @RialAmount - @FeeAmount;
IF @NetRial <= 0
    THROW 51170, N'مبلغ نهایی پس از کسر کارمزد معتبر نیست', 1;

DECLARE @FinalAmount DECIMAL(18,4) = ROUND(@NetRial / NULLIF(@TargetRate, 0), 4);
DECLARE @FinalRate DECIMAL(18,2) = ROUND(@RialAmount / NULLIF(@FinalAmount, 0), 0);

SELECT @SourceCurrency AS SourceCurrency,
       @SourceAmount AS SourceAmount,
       @SourceRate AS SourceRate,
       @TargetCurrency AS TargetCurrency,
       @FinalAmount AS TargetAmount,
       @TargetRate AS TargetRate,
       @FeeType AS FeeType,
       @FeeValue AS FeeValue,
       @FeeChargeTo AS FeeChargeTo,
       @FeeAmount AS FeeAmount,
       @RialAmount AS RialAmount,
       @FinalAmount AS FinalAmount,
       @FinalRate AS FinalRate,
       (@SourceRate - @TargetRate) AS RateDiff,
       0 AS Pnl,
       @RateSource AS RateSource,
       ISNULL(@RateDate, CAST(SYSDATETIME() AS DATE)) AS RateDate,
       NULL AS Message;
