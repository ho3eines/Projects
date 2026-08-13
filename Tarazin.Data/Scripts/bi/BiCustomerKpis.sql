-- =============================================
-- Tarazin.Data/Scripts/bi/BiCustomerKpis.sql
-- Schema: bi
-- Cross-schema: central, goldshop, accounting
-- Query. داشبورد مشتریان (§82–§85): کل/فعال/جدید/تکراری + مطالبات.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

DECLARE @Total INT = ISNULL((SELECT COUNT(*) FROM [central].[Parties] WHERE PartyType = N'Customer' AND IsDeleted = 0), 0);
DECLARE @New INT = ISNULL((SELECT COUNT(*) FROM [central].[Parties] WHERE PartyType = N'Customer' AND IsDeleted = 0 AND CreatedAt >= @MonthStart), 0);
-- مشتری فعال: حداقل یک فاکتور طلا یا سفارش در ۹۰ روز
DECLARE @Active INT = ISNULL((
    SELECT COUNT(DISTINCT p.PartyId)
    FROM [central].[Parties] p
    WHERE p.PartyType = N'Customer' AND p.IsDeleted = 0
      AND EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices] s
                  WHERE s.CustomerName = p.FullName AND s.InvoiceDate >= DATEADD(DAY, -90, @Today))), 0);
-- بزرگ‌ترین بدهکار (بر اساس اسناد فروش معوق — CounterPartyName)
DECLARE @TopDebtorName NVARCHAR(200) = ISNULL((
    SELECT TOP 1 d.CounterPartyName
    FROM [accounting].[Documents] d
    WHERE d.IsDeleted = 0 AND d.DocumentType IN (N'Sale', N'FxSell', N'FxCombined')
      AND d.CounterPartyName IS NOT NULL
    GROUP BY d.CounterPartyName
    ORDER BY SUM(d.TotalAmount) DESC), N'—');
DECLARE @TopDebtorAmount DECIMAL(18,2) = ISNULL((
    SELECT TOP 1 SUM(d.TotalAmount)
    FROM [accounting].[Documents] d
    WHERE d.IsDeleted = 0 AND d.DocumentType IN (N'Sale', N'FxSell', N'FxCombined')
      AND d.CounterPartyName IS NOT NULL
    GROUP BY d.CounterPartyName
    ORDER BY SUM(d.TotalAmount) DESC), 0);

SELECT N'cust_total' AS KpiKey, N'کل مشتریان' AS Title, ISNULL(@Total, 0) AS Amount, NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent,
       N'مشتری' AS Unit, N'/central/users' AS Link, N'تعداد اشخاص نوع Customer' AS Formula, N'central' AS Source
UNION ALL SELECT N'cust_new_month', N'مشتریان جدید ماه', ISNULL(@New, 0), NULL, NULL, NULL, N'مشتری', N'/central/users', N'ساخته‌شده در ماه جاری', N'central'
UNION ALL SELECT N'cust_active', N'مشتریان فعال (۹۰ روز)', ISNULL(@Active, 0), NULL, NULL, NULL, N'مشتری', N'/central/users', N'دارای خرید در ۹۰ روز گذشته', N'goldshop'
UNION ALL SELECT N'cust_top_debtor', N'بزرگ‌ترین بدهکار — ' + @TopDebtorName, ISNULL(@TopDebtorAmount, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=customers', N'جمع اسناد فروش/ارز به نام مشتری', N'accounting';
