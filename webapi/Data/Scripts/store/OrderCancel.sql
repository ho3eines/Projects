-- =============================================
-- webapi/Data/Scripts/store/OrderCancel.sql
-- Schema: store
-- Cross-schema: inventory
-- Execute. عملیات ویژه: لغو سفارش + آزادسازی رزرو (Saga compensation).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[Orders] WHERE OrderId = @OrderId)
    THROW 51031, N'سفارش یافت نشد', 1;

IF EXISTS (SELECT 1 FROM [store].[Orders] WHERE OrderId = @OrderId AND Status IN (N'Cancelled', N'Rejected'))
    THROW 51032, N'سفارش قبلاً لغو/رد شده است', 1;

BEGIN TRAN;
    UPDATE [store].[Orders] SET Status = N'Cancelled' WHERE OrderId = @OrderId;

    UPDATE [inventory].[Reservations]
    SET Status = N'Released', ReleasedAt = SYSUTCDATETIME()
    WHERE OrderId = @OrderId AND Status = N'Active';
COMMIT;
