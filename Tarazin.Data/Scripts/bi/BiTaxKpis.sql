-- =============================================
-- Tarazin.Data/Scripts/bi/BiTaxKpis.sql
-- Schema: bi
-- Cross-schema: goldshop, accounting
-- Query. داشبورد مالیات (§89): مالیات وصولی فاکتورهای طلا + نرخ‌های فعال.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

SELECT N'tax_collected_month' AS KpiKey, N'مالیات وصولی ماه (فاکتور طلا)' AS Title,
       ISNULL((SELECT SUM(Tax) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0) AS Amount,
       NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent, N'IRR' AS Unit,
       N'/goldshop/reports' AS Link, N'جمع ستون مالیات فاکتورهای طلا' AS Formula, N'goldshop' AS Source, N'Neutral' AS Status
UNION ALL SELECT N'tax_invoices_month', N'فاکتورهای مشمول مالیات (ماه)',
       ISNULL((SELECT COUNT(*) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart AND Tax > 0), 0),
       NULL, NULL, NULL, N'فاکتور', N'/goldshop/reports', N'فاکتورهای دارای مالیات غیرصفر', N'goldshop', N'Neutral'
UNION ALL SELECT N'tax_free_month', N'فاکتورهای غیرمشمول (ماه)',
       ISNULL((SELECT COUNT(*) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart AND Tax = 0), 0),
       NULL, NULL, NULL, N'فاکتور', N'/goldshop/reports', N'فاکتورهای بدون مالیات', N'goldshop', N'Neutral'
UNION ALL SELECT N'tax_rules_active', N'نرخ‌های مالیاتی فعال',
       ISNULL((SELECT COUNT(*) FROM [accounting].[TaxRules] WHERE IsActive = 1), 0),
       NULL, NULL, NULL, N'نرخ', N'/accounting/settings', N'قواعد مالیاتی فعال (TaxRules)', N'accounting', N'Neutral'
UNION ALL SELECT N'tax_gold_rate', N'نرخ مالیات طلا',
       ISNULL((SELECT TOP 1 RatePercent FROM [accounting].[TaxRules]
               WHERE Category = N'Gold' AND IsActive = 1 ORDER BY EffectiveFrom DESC), 0),
       NULL, NULL, NULL, N'٪', N'/accounting/settings', N'نرخ فعال دسته Gold', N'accounting', N'Neutral';
