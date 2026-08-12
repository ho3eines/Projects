-- =============================================
-- webapi/Data/Scripts/treasury/ChequeInsert.sql
-- Schema: treasury
-- Execute. ثبت چک دریافتی/پرداختی.
-- =============================================
INSERT INTO [treasury].[Cheques] (ChequeNumber, BankId, Amount, DueDate, Direction, Status, CreatedAt)
VALUES (@ChequeNumber, @BankId, @Amount, @DueDate, @Direction, N'Pending', SYSUTCDATETIME());
