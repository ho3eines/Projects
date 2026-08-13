-- =============================================
-- Tarazin.Data/Scripts/bi/BiEcommerceKpis.sql
-- Schema: bi
-- Cross-schema: store
-- Query. داشبورد فروشگاه اینترنتی (§79): سفارش‌ها بر اساس وضعیت.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

SELECT N'order_today' AS KpiKey, N'سفارش امروز' AS Title,
       ISNULL((SELECT COUNT(*) FROM [store].[Orders] WHERE OrderDate = @Today), 0) AS Amount,
       NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent, N'سفارش' AS Unit,
       N'/store' AS Link, N'تعداد سفارش‌های امروز' AS Formula, N'store' AS Source
UNION ALL SELECT N'order_completed', N'سفارش‌های تکمیل‌شده (همهٔ دوره)',
       ISNULL((SELECT COUNT(*) FROM [store].[Orders] WHERE Status = N'Invoiced'), 0), NULL, NULL, NULL, N'سفارش', N'/store/reports', N'سفارش‌های با وضعیت Invoiced', N'store'
UNION ALL SELECT N'order_pending', N'سفارش‌های در انتظار',
       ISNULL((SELECT COUNT(*) FROM [store].[Orders] WHERE Status IN (N'Placed', N'Reserved')), 0), NULL, NULL, NULL, N'سفارش', N'/store', N'سفارش‌های Placed/Reserved', N'store'
UNION ALL SELECT N'order_cancelled', N'سفارش‌های لغوشده',
       ISNULL((SELECT COUNT(*) FROM [store].[Orders] WHERE Status IN (N'Cancelled', N'Rejected')), 0), NULL, NULL, NULL, N'سفارش', N'/store/reports', N'سفارش‌های لغو/ردشده', N'store'
UNION ALL SELECT N'order_avg', N'میانگین ارزش سفارش',
       ISNULL((SELECT ROUND(AVG(TotalAmount), 0) FROM [store].[Orders] WHERE Status = N'Invoiced'), 0), NULL, NULL, NULL, N'IRR', N'/store/reports', N'میانگین مبلغ سفارش‌های تکمیل‌شده', N'store';
