-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentTrace.sql
-- Schema: accounting
-- Query. ردیابی یک‌پارچهٔ زنجیرهٔ یک رویداد در ۴ ماژول:
--   فروشگاه → انبار → خزانه → حسابداری
--
-- «شمارهٔ مشترک» کلید SourceReference با قالب '{Prefix}:{LocalId}' است
-- که همهٔ ماژول‌ها هنگام ثبت می‌نویسند، مثلاً:
--   StoreOrder:12      (فروشگاه + حرکت انبار + نقد/چک خزانه + سند)
--   SalesInvoice:34    (انبار + سند)      PurchaseInvoice:56  (انبار + سند)
--   Cheque:78          (چک + حرکت نقدی + سند وصول)
--   Invoice:90         (دریافت نقدی بابت فاکتور)
-- ردیف‌های خزانه علاوه بر کلید مشترک، DocumentId سند حسابداری را هم
-- نگه می‌دارند (لنگر مستقیم) تا گزارش بدون واکشی متن کلید join شود.
--
-- ورودی: @DocumentId و @SourceReference هر دو باید (nullable) پاس داده شوند؛
--         حداقل یکی مقدار داشته باشد.
-- خروجی: یک ردیف برای هر «پای» زنجیره با DocumentId/DocumentNumber مشترک.
-- =============================================
SET NOCOUNT ON;

DECLARE @DocId INT = ISNULL(@DocumentId, 0);
DECLARE @Src NVARCHAR(200) = ISNULL(@SourceReference, N'');

-- وضوح: اگر فقط کلید مشترک داده شد، سند حسابداری را پیدا کن
IF @DocId = 0 AND @Src <> N''
    SELECT @DocId = DocumentId
    FROM [accounting].[Documents]
    WHERE IsDeleted = 0 AND SourceReference = @Src;

-- اگر فقط DocumentId داده شد، کلید مشترک را از سند برگردان
IF @Src = N'' AND @DocId > 0
    SELECT @Src = ISNULL(SourceReference, N'')
    FROM [accounting].[Documents]
    WHERE DocumentId = @DocId AND IsDeleted = 0;

IF @DocId = 0 AND @Src = N''
BEGIN
    SELECT CAST(N'' AS NVARCHAR(30))  AS [Leg],
           CAST(N'' AS NVARCHAR(100)) AS [Key],
           CAST(N'سندی یافت نشد — @DocumentId یا @SourceReference بدهید.' AS NVARCHAR(300)) AS Detail,
           CAST(NULL AS DECIMAL(18,2)) AS Amount,
           CAST(NULL AS DATE)          AS [Date],
           CAST(N'' AS NVARCHAR(200)) AS SourceReference,
           CAST(NULL AS INT)           AS DocumentId,
           CAST(N'' AS NVARCHAR(100)) AS DocumentNumber;
    RETURN;
END

SELECT [Leg], [Key], Detail, Amount, [Date], SourceReference, DocumentId, DocumentNumber
FROM
(
    -- حسابداری: سند
    SELECT N'حسابداری' AS [Leg],
           d.DocumentNumber AS [Key],
           d.DocumentType + N' — ' + ISNULL(d.CounterPartyName, N'') AS Detail,
           d.TotalAmount AS Amount,
           d.DocumentDate AS [Date],
           ISNULL(d.SourceReference, N'') AS SourceReference,
           d.DocumentId AS DocumentId,
           d.DocumentNumber AS DocumentNumber
    FROM [accounting].[Documents] d
    WHERE d.DocumentId = @DocId AND d.IsDeleted = 0

    UNION ALL

    -- انبار: فاکتور خرید/فروش (لنگر DocumentId سند)
    SELECT N'انبار',
           i.InvoiceNumber,
           i.OperationType + N' — ' + ISNULL(i.CustomerName, i.SupplierName),
           i.NetAmount,
           i.InvoiceDate,
           ISNULL(d.SourceReference, N'') ,
           i.DocumentId,
           d.DocumentNumber
    FROM [inventory].[Invoices] i
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = i.DocumentId
    WHERE i.DocumentId = @DocId AND i.IsDeleted = 0

    UNION ALL

    -- فروشگاه: سفارش (لنگر DocumentId سند)
    SELECT N'فروشگاه',
           o.OrderNumber,
           ISNULL(o.CustomerName, N''),
           o.TotalAmount,
           o.OrderDate,
           CONCAT(N'StoreOrder:', o.OrderId),
           o.DocumentId,
           d.DocumentNumber
    FROM [store].[Orders] o
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = o.DocumentId
    WHERE o.DocumentId = @DocId

    UNION ALL

    -- خزانه: حرکت نقدی (لنگر مستقیم DocumentId یا کلید مشترک)
    SELECT N'خزانه (نقد)',
           cm.MovementNumber,
           ISNULL(cm.Description, N''),
           cm.Amount,
           cm.MovementDate,
           ISNULL(cm.SourceReference, N''),
           cm.DocumentId,
           d.DocumentNumber
    FROM [treasury].[CashMovements] cm
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = cm.DocumentId
    WHERE cm.DocumentId = @DocId OR cm.SourceReference = @Src

    UNION ALL

    -- خزانه: چک
    SELECT N'خزانه (چک)',
           c.ChequeNumber,
           N'وضعیت: ' + c.Status,
           c.Amount,
           c.DueDate,
           ISNULL(c.SourceReference, N''),
           c.DocumentId,
           d.DocumentNumber
    FROM [treasury].[Cheques] c
    LEFT JOIN [accounting].[Documents] d ON d.DocumentId = c.DocumentId
    WHERE c.DocumentId = @DocId OR c.SourceReference = @Src

    UNION ALL

    -- انبار: حرکات (کلید مشترک روی ردیف حرکت)
    SELECT N'حرکت انبار',
           m.MovementNumber,
           m.MovementType + N' — ' + ISNULL(m.Description, N''),
           m.Qty * m.CostPrice,
           m.MovementDate,
           ISNULL(m.SourceReference, N''),
           CAST(NULL AS INT),
           CAST(NULL AS NVARCHAR(100))
    FROM [inventory].[Movements] m
    WHERE m.SourceReference = @Src
) legs
ORDER BY [Date];