-- =============================================
-- Tarazin.Data/Scripts/treasury/ChequeAlertSummary.sql
-- Schema: treasury
-- Query. خلاصهٔ هشدار چک‌ها برای داشبورد اصلی:
--   OverdueCount — چک‌های باز (در انتظار/در جریان) که سررسیدشان گذشته است
--   DueSoonCount — چک‌های باز که تا ۷ روز آینده سررسید می‌شوند (شامل امروز)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

SELECT
    (SELECT COUNT(*) FROM [treasury].[Cheques]
     WHERE Status IN (N'Pending', N'Collecting') AND DueDate < @Today
       AND (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS OverdueCount,
    (SELECT COUNT(*) FROM [treasury].[Cheques]
     WHERE Status IN (N'Pending', N'Collecting')
       AND DueDate >= @Today AND DueDate <= DATEADD(DAY, 7, @Today)
       AND (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS DueSoonCount;
