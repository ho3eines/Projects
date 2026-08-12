-- =============================================
-- HermesApp/Data/Scripts/accounting/SalesInvoiceFromOrder.sql
-- Schema: accounting | Consumer of StockReserved (store → accounting)
-- Execute. Idempotent on OrderId (ADR-002).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [accounting].[SalesInvoices] WHERE OrderId = @OrderId)
BEGIN
    INSERT INTO [accounting].[SalesInvoices]
        (InvoiceNumber, OrderId, CustomerName, TotalAmount, CurrencyCode, Status, InvoiceDate, CreatedAt)
    VALUES
        (N'', @OrderId, @CustomerName, @TotalAmount, @CurrencyCode, N'Issued', CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME());

    DECLARE @Iid INT = SCOPE_IDENTITY();
    UPDATE [accounting].[SalesInvoices]
    SET InvoiceNumber = N'INV-' + RIGHT(N'00000' + CAST(@Iid AS NVARCHAR(10)), 5)
    WHERE InvoiceId = @Iid;

    INSERT INTO [accounting].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
    VALUES (N'InvoiceCreated', CONCAT(N'OrderId=', @OrderId),
        (SELECT @OrderId AS OrderId, @Iid AS InvoiceId, @CustomerName AS CustomerName,
                @TotalAmount AS TotalAmount, @CurrencyCode AS CurrencyCode
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
END
