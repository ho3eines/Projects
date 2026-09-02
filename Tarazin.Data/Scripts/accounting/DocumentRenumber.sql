-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentRenumber.sql
-- Schema: accounting
-- Execute. شماره‌گذاری مجدد قطعی اسناد بر اساس تاریخ.
--   شمارهٔ ۸رقمی ترتیبی (00000001...) به همهٔ اسناد غیرحذفِ شرکت (و سال مالی
--   اختیاری) به‌ترتیب DocumentDate (و در تاریخ مساوی، DocumentId) اختصاص
--   می‌دهد — در یک تراکنش، تا هیچ سندی نیمه‌شماره‌دار نماند.
-- پارامترها: @CompanyId، @FiscalYearId (اختیاری = همهٔ سال‌ها)، @CreatedBy
-- =============================================
DECLARE @Renumbered INT = 0;

BEGIN TRAN;

    DECLARE @Doc TABLE (DocumentId INT PRIMARY KEY, NewNumber NVARCHAR(50));
    INSERT INTO @Doc (DocumentId, NewNumber)
    SELECT DocumentId,
           RIGHT(N'00000000' + CAST(ROW_NUMBER() OVER (ORDER BY DocumentDate, DocumentId) AS NVARCHAR(10)), 8)
    FROM [accounting].[Documents]
    WHERE CompanyId = @CompanyId
      AND IsDeleted = 0
      AND (@FiscalYearId IS NULL OR FiscalYearId = @FiscalYearId);

    UPDATE d
    SET DocumentNumber = x.NewNumber,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    FROM [accounting].[Documents] d
    JOIN @Doc x ON x.DocumentId = d.DocumentId;

    SET @Renumbered = (SELECT COUNT(*) FROM @Doc);

COMMIT;

SELECT @Renumbered AS Renumbered;
