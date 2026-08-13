-- =============================================
-- Tarazin.Data/Scripts/bi/BiWorkingCapital.sql
-- Schema: bi
-- Cross-schema: accounting, treasury, inventory, currency
-- Query. سرمایه در گردش (§24): موجودی + مطالبات − بدهی‌ها + نقدینگی + نسبت‌ها.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Inventory DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(StockQty,0)*ISNULL(UnitPrice,0)) FROM [inventory].[Items] WHERE IsDeleted = 0), 0);
DECLARE @Receivable DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.Debit,0)-ISNULL(l.Credit,0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Asset' AND a.IsDeleted = 0
      AND a.AccountCode NOT IN (N'1000',N'1010',N'1020',N'1030',N'1040')), 0);
DECLARE @Payable DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.Credit,0)-ISNULL(l.Debit,0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Liability' AND a.IsDeleted = 0), 0);
DECLARE @Cash DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0)
    + ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0);
DECLARE @FxValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(w.Quantity,0)*ISNULL(r.SystemRate,0))
    FROM [currency].[Wallets] w
    LEFT JOIN [currency].[PriceRates] r
        ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)), 0);
DECLARE @WorkingCapital DECIMAL(18,2) = (@Cash + @FxValue + @Receivable + @Inventory) - @Payable;
DECLARE @CurrentRatio DECIMAL(12,2) = CASE WHEN @Payable = 0 THEN NULL ELSE ROUND((@Cash + @FxValue + @Receivable + @Inventory) / @Payable, 2) END;
DECLARE @QuickRatio DECIMAL(12,2) = CASE WHEN @Payable = 0 THEN NULL ELSE ROUND((@Cash + @FxValue + @Receivable) / @Payable, 2) END;
DECLARE @CashRatio DECIMAL(12,2) = CASE WHEN @Payable = 0 THEN NULL ELSE ROUND((@Cash + @FxValue) / @Payable, 2) END;

SELECT N'wc_inventory' AS KpiKey, N'موجودی کالا' AS Title, ISNULL(@Inventory, 0) AS Amount, NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent,
       N'IRR' AS Unit, N'/inventory/reports' AS Link, N'∑ موجودی × قیمت واحد' AS Formula, N'inventory' AS Source, N'Neutral' AS Status
UNION ALL SELECT N'wc_receivable', N'مطالبات', ISNULL(@Receivable, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=customers', N'ماندهٔ دارایی‌های غیرنقد', N'accounting', N'Neutral'
UNION ALL SELECT N'wc_payable', N'بدهی‌ها', ISNULL(@Payable, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=payables', N'ماندهٔ حساب‌های بدهکار', N'accounting', N'Bad'
UNION ALL SELECT N'wc_liquidity', N'نقدینگی', ISNULL(@Cash, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'بانک + صندوق', N'treasury', N'Neutral'
UNION ALL SELECT N'wc_total', N'سرمایه در گردش', ISNULL(@WorkingCapital, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=financial', N'(نقد + ارز + مطالبات + موجودی) − بدهی‌ها', N'multi',
       CASE WHEN @WorkingCapital >= 0 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'wc_current_ratio', N'Current Ratio', ISNULL(@CurrentRatio, 0), NULL, NULL, NULL, N'نسبت', N'/bi?tab=financial', N'دارایی جاری ÷ بدهی جاری', N'multi',
       CASE WHEN ISNULL(@CurrentRatio, 0) >= 1 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'wc_quick_ratio', N'Quick Ratio', ISNULL(@QuickRatio, 0), NULL, NULL, NULL, N'نسبت', N'/bi?tab=financial', N'(نقد + مطالبات) ÷ بدهی جاری', N'multi',
       CASE WHEN ISNULL(@QuickRatio, 0) >= 1 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'wc_cash_ratio', N'Cash Ratio', ISNULL(@CashRatio, 0), NULL, NULL, NULL, N'نسبت', N'/treasury', N'نقد ÷ بدهی جاری', N'treasury',
       CASE WHEN ISNULL(@CashRatio, 0) >= 0.5 THEN N'Good' ELSE N'Bad' END;
