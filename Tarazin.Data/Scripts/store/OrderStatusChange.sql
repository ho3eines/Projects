-- =============================================
-- Tarazin.Data/Scripts/store/OrderStatusChange.sql
-- Schema: store | Cross-schema: inventory
-- Execute. تغییر وضعیت سفارش به‌صورت State Machine.
--   * انتقال باید در OrderStatusTransitions مجاز باشد → وگرنه 51320.
--   * @ExpectedStatus برای کنترل هم‌زمانی (optimistic).
--   * Cancelled/Rejected → آزادسازی رزروهای انبار (Saga compensation).
--   * تاریخچه در OrderStatusHistory ثبت می‌شود.
-- =============================================
SET NOCOUNT ON;

DECLARE @Current NVARCHAR(30);

SELECT @Current = Status FROM [store].[Orders]
WHERE OrderId = @OrderId;

IF @Current IS NULL
    THROW 51031, N'سفارش یافت نشد', 1;

-- کنترل هم‌زمانی
IF @ExpectedStatus IS NOT NULL AND @ExpectedStatus <> @Current
    THROW 51321, N'وضعیت سفارش از زمان بارگذاری تغییر کرده است؛ صفحه را دوباره بارگذاری کنید', 1;

-- انتقال مجاز؟
IF NOT EXISTS (SELECT 1 FROM [store].[OrderStatusTransitions]
               WHERE FromStatus = @Current AND ToStatus = @NewStatus)
BEGIN
    DECLARE @Msg NVARCHAR(300) =
        N'انتقال وضعیت «' + @Current + N'» به «' + @NewStatus + N'» مجاز نیست.';
    THROW 51320, @Msg, 1;
END

BEGIN TRAN;

    UPDATE [store].[Orders]
    SET Status = @NewStatus
    WHERE OrderId = @OrderId;

    INSERT INTO [store].[OrderStatusHistory] (OrderId, FromStatus, ToStatus, Reason, ChangedBy)
    VALUES (@OrderId, @Current, @NewStatus, @Reason, @ChangedBy);

    -- لغو/رد: آزادسازی رزروهای فعال انبار
    IF @NewStatus IN (N'Cancelled', N'Rejected')
        UPDATE [inventory].[Reservations]
        SET Status = N'Released', ReleasedAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME()
        WHERE OrderId = @OrderId AND Status = N'Active';

COMMIT;

SELECT @NewStatus AS NewStatus;
