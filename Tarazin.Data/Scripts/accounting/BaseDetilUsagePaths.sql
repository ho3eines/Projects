-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilUsagePaths.sql
-- Schema: accounting
-- برگرداندن تمام مسیرهایی که یک DetilId در آن‌ها قرار گرفته است.
-- هر ردیف: LinkId, AccountCode (Col+Moein+Detil), عنوان مسیر (Col> > Moein)
-- =============================================
SELECT
    dl.LinkId        AS LinkId,
    dl.MoeinId       AS MoeinId,
    dl.DetilId       AS DetilId,
    dl.IsActive      AS LinkIsActive,
    c.ColId          AS ColId,
    c.ColCode        AS ColCode,
    c.Title          AS ColTitle,
    m.MoeinCode      AS MoeinCode,
    m.Title          AS MoeinTitle,
    d.DetilCode      AS DetilCode,
    d.Title          AS DetilTitle,
    c.ColCode + m.MoeinCode + d.DetilCode AS AccountCode,
    c.Title + N' > ' + m.Title AS PathTitle
FROM [accounting].[BaseDetilLink] dl
JOIN [accounting].[BaseMoein] m  ON m.MoeinId  = dl.MoeinId
JOIN [accounting].[BaseCol]   c  ON c.ColId    = m.ColId
JOIN [accounting].[BaseDetil] d  ON d.DetilId  = dl.DetilId
WHERE dl.DetilId = @DetilId
  AND dl.IsDeleted = 0
  AND m.IsDeleted = 0
  AND c.IsDeleted = 0
  AND d.IsDeleted = 0
ORDER BY c.ColCode, m.MoeinCode;
