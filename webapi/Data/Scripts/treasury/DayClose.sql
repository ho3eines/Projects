-- =============================================
-- webapi/Data/Scripts/treasury/DayClose.sql
-- Schema: treasury
-- Execute. عملیات ویژه: بستن روز — ثبت جمع صندوق و بانک.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
IF EXISTS (SELECT 1 FROM [treasury].[DayCloses] WHERE DayDate = @Today)
    THROW 51011, N'روز جاری قبلاً بسته شده است', 1;

BEGIN TRAN;
    INSERT INTO [treasury].[DayCloses] (DayDate, CashTotal, BankTotal, CreatedAt, CreatedBy)
    VALUES (
        @Today,
        (SELECT ISNULL(SUM(CASE WHEN Direction = N'In' THEN Amount ELSE -Amount END), 0)
         FROM [treasury].[CashMovements] WHERE MovementDate = @Today AND CashBoxId IS NOT NULL),
        (SELECT ISNULL(SUM(CASE WHEN Direction = N'In' THEN Amount ELSE -Amount END), 0)
         FROM [treasury].[CashMovements] WHERE MovementDate = @Today AND AccountId IS NOT NULL),
        SYSUTCDATETIME(), @CreatedBy);
COMMIT;
