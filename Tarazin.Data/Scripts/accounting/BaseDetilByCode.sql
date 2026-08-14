-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilByCode.sql
-- Schema: accounting
-- یافتن تفصیلی بر اساس کد 7 رقمی.
-- ایندکس UNIQUE روی DetilCode (PK یا UNIQUE constraint) جستجوی O(log n) می‌دهد.
-- =============================================
DECLARE @NormCode NVARCHAR(7) = RIGHT('0000000' + ISNULL(NULLIF(LTRIM(RTRIM(@DetilCode)), ''), '0000000'), 7);

SELECT
    d.DetilId, d.DetilCode, d.Title, d.[Description], d.IsActive,
    d.CreatedAt, d.UpdatedAt, d.CreatedBy, d.UpdatedBy
FROM [accounting].[BaseDetil] d
WHERE d.IsDeleted = 0 AND d.DetilCode = @NormCode;
