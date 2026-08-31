-- =============================================
-- Tarazin.Data/Scripts/treasury/SourceDetail.sql
-- Schema: treasury
-- Query. وضوح «منبع یک چک» به سابقه/سفارش پشتنویس + سند حسابداری لینک‌شده.
-- SourceReference به شکل‌های {GoldInvoice:Id}, {GoldPurchase:Id}, {StoreOrder:Id},
-- {Order:Id}, {Invoice:Id}, {Cheque:Id}, {Payroll:...} است.
-- برای هر type شناسه را می‌شکافد و عنوان/شماره + DocumentId لینک‌شده را برمی‌گرداند
-- تا UI بتواند با همان شناسه به سند حسابداری یا صفحهٔ ماژول دامنه عمیق شود.
-- =============================================
SET NOCOUNT ON;

DECLARE @Src NVARCHAR(200) = ISNULL(@SourceReference, N'');
DECLARE @Colon INT = CHARINDEX(N':', @Src);
DECLARE @Prefix NVARCHAR(40) = CASE WHEN @Colon > 0 THEN LEFT(@Src, @Colon - 1) ELSE N'' END;
DECLARE @Id BIGINT = TRY_CONVERT(BIGINT, SUBSTRING(@Src, @Colon + 1, 400));

-- ── منبع: فاکتور طلافروشی (فروش و خرید) ──
-- DocumentId از 설명 ردیف سند که شامل شماره فاکتور است وضوح می‌شود.
SELECT TOP 1
    @Src                AS SourceReference,
    @Prefix             AS SourceType,
    @Id                 AS SourceId,
    s.InvoiceNumber     AS [Key],
    ISNULL(s.CustomerName, N'') AS Detail,
    (SELECT TOP 1 CAST(l.DocumentId AS INT)
       FROM [accounting].[Documents] d
       INNER JOIN [accounting].[DocumentLines] l ON l.DocumentId = d.DocumentId
      WHERE d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
        AND l.Description LIKE N'%' + s.InvoiceNumber + N'%') AS DocumentId,
    (SELECT TOP 1 d.DocumentNumber
       FROM [accounting].[Documents] d
       INNER JOIN [accounting].[DocumentLines] l ON l.DocumentId = d.DocumentId
      WHERE d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
        AND l.Description LIKE N'%' + s.InvoiceNumber + N'%') AS DocumentNumber,
    s.InvoiceId          AS ModuleId
FROM [goldshop].[SaleInvoices] s
WHERE @Prefix IN (N'GoldInvoice', N'GoldPurchase') AND s.InvoiceId = @Id AND s.CompanyId = @CompanyId

UNION ALL

-- ── منبع: سفارش فروشگاه (Order / StoreOrder / Invoice) — DocumentId مستقیم ذخیره می‌شود ──
SELECT TOP 1
    @Src                AS SourceReference,
    @Prefix             AS SourceType,
    @Id                 AS SourceId,
    o.OrderNumber       AS [Key],
    ISNULL(o.CustomerName, N'') AS Detail,
    o.DocumentId        AS DocumentId,
    (SELECT d.DocumentNumber FROM [accounting].[Documents] d
      WHERE d.DocumentId = o.DocumentId AND d.IsDeleted = 0) AS DocumentNumber,
    o.OrderId           AS ModuleId
FROM [store].[Orders] o
WHERE @Prefix IN (N'Order', N'StoreOrder', N'Invoice') AND o.OrderId = @Id AND o.CompanyId = @CompanyId

UNION ALL

-- ── منبع: چک دیگری در خزانه (وصول چک → چک) ──
SELECT TOP 1
    @Src                AS SourceReference,
    @Prefix             AS SourceType,
    @Id                 AS SourceId,
    c.ChequeNumber      AS [Key],
    ISNULL(b.Title, N'') AS Detail,
    CAST(NULL AS INT)   AS DocumentId,
    N''                 AS DocumentNumber,
    c.ChequeId          AS ModuleId
FROM [treasury].[Cheques] c
LEFT JOIN [treasury].[Banks] b ON b.BankId = c.BankId
WHERE @Prefix = N'Cheque' AND c.ChequeId = @Id AND c.CompanyId = @CompanyId

UNION ALL

-- ── منبع: حقوق و دستمزد (Payroll) — سند از جستجوی شرح دوره وضوح می‌شود ──
SELECT TOP 1
    @Src                AS SourceReference,
    @Prefix             AS SourceType,
    @Id                 AS SourceId,
    r.Period            AS [Key],
    (N'حقوق و دستمزد — دورهٔ ' + r.Period) AS Detail,
    (SELECT TOP 1 CAST(l.DocumentId AS INT)
       FROM [accounting].[Documents] d
       INNER JOIN [accounting].[DocumentLines] l ON l.DocumentId = d.DocumentId
      WHERE d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
        AND l.Description LIKE N'%' + r.Period + N'%') AS DocumentId,
    (SELECT TOP 1 d.DocumentNumber
       FROM [accounting].[Documents] d
       INNER JOIN [accounting].[DocumentLines] l ON l.DocumentId = d.DocumentId
      WHERE d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
        AND l.Description LIKE N'%' + r.Period + N'%') AS DocumentNumber,
    r.RunId             AS ModuleId
FROM [payroll].[PayrollRuns] r
WHERE @Prefix = N'Payroll' AND r.RunId = @Id

UNION ALL

-- ── منبع: دستی / سایر — فقط نمایش خام ──
SELECT
    @Src                        AS SourceReference,
    @Prefix                     AS SourceType,
    @Id                         AS SourceId,
    @Src                        AS [Key],
    CASE WHEN @Colon = 0 THEN @Src ELSE N'' END AS Detail,
    CAST(NULL AS INT)           AS DocumentId,
    N''                         AS DocumentNumber,
    CAST(NULL AS INT)           AS ModuleId
WHERE @Prefix NOT IN (N'GoldInvoice', N'GoldPurchase', N'Order', N'StoreOrder', N'Invoice', N'Cheque', N'Payroll')
   OR (@Colon = 0 AND @Prefix NOT IN (N'GoldInvoice', N'GoldPurchase', N'Order', N'StoreOrder', N'Invoice', N'Cheque', N'Payroll'));