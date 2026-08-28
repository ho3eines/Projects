-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldInvoiceSettlements.sql
-- Schema: goldshop (Cross: treasury, currency, goldshop)
-- Execute. لود اطلاعات تسویه یک فاکتور برای ویرایش.
-- =============================================

-- ۱) نقدی + بانک (خزانه)
SELECT
    IIF(cm.CashBoxId IS NOT NULL, N'Cash', IIF(cm.AccountId IS NOT NULL, N'Bank', N'Other')) AS SettlementType,
    cm.Amount,
    cm.CashBoxId,
    cm.AccountId
FROM [treasury].[CashMovements] cm
WHERE cm.CompanyId=@CompanyId
  AND cm.SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId);

-- ۲) چک
SELECT
    c.ChequeNumber,
    c.BankId,
    c.Amount,
    c.DueDate,
    c.Status
FROM [treasury].[Cheques] c
WHERE c.CompanyId=@CompanyId
  AND (c.SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId)
       OR (c.SourceReference IS NULL
           AND c.CreatedAt >= (SELECT InvoiceDate FROM [goldshop].[SaleInvoices] WHERE InvoiceId=@InvoiceId)
           AND c.CreatedAt < DATEADD(DAY,1,(SELECT InvoiceDate FROM [goldshop].[SaleInvoices] WHERE InvoiceId=@InvoiceId))
           AND c.Direction=N'In' AND c.Status=N'Pending'
           AND EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices] s WHERE s.InvoiceId=@InvoiceId
                       AND ABS(s.TotalAmount-c.Amount)<=s.TotalAmount*0.01)));

-- ۳) پرداخت ارز (تسویه)
SELECT
    cm.CurrencyCode,
    cm.Quantity,
    cm.Rate
FROM [currency].[CurrencyMovements] cm
WHERE cm.CompanyId=@CompanyId
  AND cm.SourceReference=CONCAT(N'GOLDINV:',@InvoiceId)
  AND cm.Direction=N'In';

-- ۴) تسویه با طلا (دفتر طرف‌حساب)
SELECT
    ISNULL(CreditGoldGram,0) AS CreditGoldGram
FROM [goldshop].[GoldPartyLedger]
WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId;