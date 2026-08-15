-- =============================================
-- Tarazin.Data/Scripts/accounting/BaseDetilUsagePaths.sql
-- Schema: accounting
-- تمام مسیرهایی که یک DetilId در آن‌ها قرار گرفته است.
-- بهینه‌سازی: ایندکس IX_BaseDetilLink_Detil_Active (DetilId, IsDeleted, IsActive)
-- جستجوی مستقیم روی DetilId را با covering index تسریع می‌کند.
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
INNER JOIN [accounting].[BaseMoein] m  ON m.MoeinId  = dl.MoeinId
INNER JOIN [accounting].[BaseCol]   c  ON c.ColId    = m.ColId
INNER JOIN [accounting].[BaseDetil] d  ON d.DetilId  = dl.DetilId
WHERE dl.DetilId = @DetilId
  AND dl.IsDeleted = 0
  AND m.IsDeleted = 0
  AND c.IsDeleted = 0
  AND d.IsDeleted = 0
ORDER BY c.ColCode, m.MoeinCode
OPTION (RECOMPILE);
