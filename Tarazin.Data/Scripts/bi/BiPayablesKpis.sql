-- =============================================
-- Tarazin.Data/Scripts/bi/BiPayablesKpis.sql
-- Schema: bi
-- Cross-schema: accounting
-- Query. داشبورد بدهی‌ها (§21–§23): کل بدهی/سررسیدشده + تأمین‌کننده برتر.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Payable DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.Credit, 0) - ISNULL(l.Debit, 0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Liability' AND a.IsDeleted = 0), 0);
DECLARE @PayableOverdue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.Credit, 0) - ISNULL(l.Debit, 0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    WHERE a.AccountType = N'Liability' AND a.IsDeleted = 0
      AND d.DocumentDate < DATEADD(DAY, -30, CAST(SYSDATETIME() AS DATE))), 0);
DECLARE @TopSupplierName NVARCHAR(200) = ISNULL((
    SELECT TOP 1 d.CounterPartyName
    FROM [accounting].[Documents] d
    WHERE d.IsDeleted = 0 AND d.DocumentType = N'Purchase' AND d.CounterPartyName IS NOT NULL
    GROUP BY d.CounterPartyName
    ORDER BY SUM(d.TotalAmount) DESC), N'—');
DECLARE @TopSupplierAmount DECIMAL(18,2) = ISNULL((
    SELECT TOP 1 SUM(d.TotalAmount)
    FROM [accounting].[Documents] d
    WHERE d.IsDeleted = 0 AND d.DocumentType = N'Purchase' AND d.CounterPartyName IS NOT NULL
    GROUP BY d.CounterPartyName
    ORDER BY SUM(d.TotalAmount) DESC), 0);

SELECT N'payable_total' AS KpiKey, N'کل بدهی‌ها' AS Title, ISNULL(@Payable, 0) AS Amount, NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent,
       N'IRR' AS Unit, N'/bi?tab=payables' AS Link, N'ماندهٔ حساب‌های بدهکار (دفتر کل)' AS Formula, N'accounting' AS Source
UNION ALL SELECT N'payable_overdue', N'بدهی سررسیدشده (بیش از ۳۰ روز)', ISNULL(@PayableOverdue, 0), NULL, NULL, NULL, N'IRR', N'/accounting/reports', N'بدهی با سند قدیمی‌تر از ۳۰ روز', N'accounting'
UNION ALL SELECT N'top_supplier', N'تأمین‌کننده برتر — ' + @TopSupplierName, ISNULL(@TopSupplierAmount, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=payables', N'بیشترین اسناد خرید', N'accounting';
