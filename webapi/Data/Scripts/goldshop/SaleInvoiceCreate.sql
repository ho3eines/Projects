-- =============================================
-- webapi/Data/Scripts/goldshop/SaleInvoiceCreate.sql
-- Schema: goldshop
-- Cross-schema: accounting (TaxRules — config-driven tax engine)
-- Execute. ثبت فاکتور فروش طلا — مالیات از TaxRules (جدول‌محور) خوانده می‌شود.
-- =============================================
DECLARE @GoldTax DECIMAL(9,4) = ISNULL((
    SELECT TOP 1 RatePercent FROM [accounting].[TaxRules]
    WHERE Category = N'Gold' AND IsActive = 1 AND EffectiveFrom <= CAST(SYSDATETIME() AS DATE)
    ORDER BY EffectiveFrom DESC), 0);
DECLARE @Base DECIMAL(18,2) = (@WeightGram * @PricePerGram) + @Workmanship + @Profit;
DECLARE @Tax DECIMAL(18,2) = ROUND(@Base * @GoldTax / 100.0, 0);

BEGIN TRAN;
    INSERT INTO [goldshop].[SaleInvoices]
        (InvoiceNumber, InvoiceDate, CustomerName, ItemCode, WeightGram, Workmanship, Profit, Tax, TotalAmount, Status, CreatedBy)
    VALUES
        (N'', @InvoiceDate, @CustomerName, @ItemCode, @WeightGram, @Workmanship, @Profit, @Tax, @Base + @Tax, N'Issued', @CreatedBy);

    DECLARE @Iid INT = SCOPE_IDENTITY();
    UPDATE [goldshop].[SaleInvoices]
    SET InvoiceNumber = N'GINV-' + RIGHT(N'00000' + CAST(@Iid AS NVARCHAR(10)), 5)
    WHERE InvoiceId = @Iid;
COMMIT;
