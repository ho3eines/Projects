-- =============================================
-- Tarazin.Data/Scripts/accounting/TrialBalanceReport.sql
-- Schema: accounting
-- تراز آزمایشی از گردش واقعی؛ بدون JOIN چندبرابرکننده.
-- ChartOfAccounts فقط برای ماهیت حساب قدیمی و با تطابق دقیق کد خوانده می‌شود.
-- =============================================
DECLARE @Status NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@StatusFilter)), N'');
DECLARE @Number NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@DocumentNumber)), N'');

;WITH Turnover AS (
    SELECT
        l.AccountCode,
        MAX(l.Title) AS AccountTitle,
        SUM(l.Debit) AS Debit,
        SUM(l.Credit) AS Credit
    FROM [accounting].[DocumentLines] l
    INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0
        AND d.CompanyId = @CompanyId
        AND d.FiscalYearId = @FiscalYearId
        AND d.DocumentDate BETWEEN @FromDate AND @ToDate
        AND (@Status IS NULL OR d.Status = @Status)
        AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
    GROUP BY l.AccountCode
)
SELECT
    turnover.AccountCode,
    turnover.AccountTitle,
    account.AccountType,
    turnover.Debit,
    turnover.Credit,
    turnover.Debit - turnover.Credit AS Balance
FROM Turnover turnover
LEFT JOIN [accounting].[ChartOfAccounts] account
    ON account.AccountCode = turnover.AccountCode
   AND account.IsDeleted = 0
ORDER BY turnover.AccountCode;
