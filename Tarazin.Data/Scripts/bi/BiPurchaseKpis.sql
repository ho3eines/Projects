-- =============================================
-- Tarazin.Data/Scripts/bi/BiPurchaseKpis.sql
-- Schema: bi
-- Cross-schema: accounting, currency, central
-- Query. داشبورد خرید (§31): خرید امروز/ماه/سال از اسناد خرید + خرید ارز + تأمین‌کنندگان.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @YearStart DATE = DATEFROMPARTS(YEAR(@Today), 1, 1);

-- خرید از دفتر کل (DocumentType=Purchase) + خرید ارز (FxTransactionType=Buy)
DECLARE @PurchaseToday DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [accounting].[Documents]
                                               WHERE DocumentType = N'Purchase' AND IsDeleted = 0 AND DocumentDate = @Today), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate = @Today AND TransactionType = N'Buy'), 0);
DECLARE @PurchaseYesterday DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [accounting].[Documents]
                                                   WHERE DocumentType = N'Purchase' AND IsDeleted = 0 AND DocumentDate = @Yesterday), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate = @Yesterday AND TransactionType = N'Buy'), 0);
DECLARE @PurchaseMonth DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [accounting].[Documents]
                                               WHERE DocumentType = N'Purchase' AND IsDeleted = 0 AND DocumentDate >= @MonthStart), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate >= @MonthStart AND TransactionType = N'Buy'), 0);
DECLARE @PurchaseYear DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [accounting].[Documents]
                                              WHERE DocumentType = N'Purchase' AND IsDeleted = 0 AND DocumentDate >= @YearStart), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate >= @YearStart AND TransactionType = N'Buy'), 0);
DECLARE @PurchaseCountMonth INT = ISNULL((SELECT COUNT(*) FROM [accounting].[Documents]
                                          WHERE DocumentType = N'Purchase' AND IsDeleted = 0 AND DocumentDate >= @MonthStart), 0)
    + ISNULL((SELECT COUNT(*) FROM [currency].[FxTransactions] WHERE TransactionDate >= @MonthStart AND TransactionType = N'Buy'), 0);
DECLARE @SupplierCount INT = ISNULL((SELECT COUNT(*) FROM [central].[Parties]
                                     WHERE PartyType = N'Vendor' AND IsDeleted = 0), 0);

SELECT N'purchase_today' AS KpiKey, N'خرید امروز' AS Title, ISNULL(@PurchaseToday, 0) AS Amount, ISNULL(@PurchaseYesterday, 0) AS PrevAmount,
       @PurchaseToday - ISNULL(@PurchaseYesterday, 0) AS Change,
       CASE WHEN ISNULL(@PurchaseYesterday, 0) <> 0 THEN (@PurchaseToday - @PurchaseYesterday) * 100.0 / @PurchaseYesterday ELSE NULL END AS ChangePercent,
       N'IRR' AS Unit, N'/accounting' AS Link, N'اسناد خرید + خرید ارز' AS Formula, N'accounting/currency' AS Source, N'Neutral' AS Status
UNION ALL SELECT N'purchase_month', N'خرید ماه', ISNULL(@PurchaseMonth, 0), NULL, NULL, NULL, N'IRR', N'/accounting/reports', N'خرید از ابتدای ماه جاری', N'accounting/currency', N'Neutral'
UNION ALL SELECT N'purchase_year', N'خرید سال', ISNULL(@PurchaseYear, 0), NULL, NULL, NULL, N'IRR', N'/accounting/reports', N'خرید از ابتدای سال جاری', N'accounting/currency', N'Neutral'
UNION ALL SELECT N'purchase_count_month', N'تعداد فاکتور خرید (ماه)', ISNULL(@PurchaseCountMonth, 0), NULL, NULL, NULL, N'فاکتور', N'/accounting', N'اسناد خرید + معاملات خرید ارز', N'accounting/currency', N'Neutral'
UNION ALL SELECT N'suppliers_total', N'تعداد تأمین‌کنندگان', ISNULL(@SupplierCount, 0), NULL, NULL, NULL, N'تأمین‌کننده', N'/central/users', N'اشخاص نوع Vendor', N'central', N'Neutral';
