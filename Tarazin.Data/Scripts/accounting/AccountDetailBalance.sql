-- =============================================
-- Tarazin.Data/Scripts/accounting/AccountDetailBalance.sql
-- Schema: accounting | Contract: BaseDetilLink
-- نمایش اطلاعات اکانت
-- =============================================


WITH DetailPaths AS (
        SELECT
            dl.LinkId, dl.ParentLinkId, dl.MoeinId, dl.DetilId, bd.Title,
            CAST(c.ColCode + m.MoeinCode + bd.DetilCode AS NVARCHAR(4000)) AS AccountCode,
            CAST(c.Title +' - '+ m.Title +' - '+ bd.Title AS NVARCHAR(4000)) as LinkName
        FROM [accounting].[BaseDetilLink] dl
        INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId AND m.IsDeleted = 0
        INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
        INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
        WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0 AND dl.CompanyId = @CompanyId

        UNION ALL

        SELECT
            dl.LinkId, dl.ParentLinkId, dl.MoeinId, dl.DetilId, bd.Title,
            CAST(parent.AccountCode + bd.DetilCode AS NVARCHAR(4000)),
            CAST(parent.LinkName +' - '+ bd.Title AS NVARCHAR(4000)) as LinkName
        FROM [accounting].[BaseDetilLink] dl
        INNER JOIN DetailPaths parent ON parent.LinkId = dl.ParentLinkId AND parent.MoeinId = dl.MoeinId
        INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
        WHERE dl.IsDeleted = 0 and dl.CompanyId=@CompanyId
    ),
Opening AS (
    SELECT AccountCode,sum(isnull(l.Debit,0)) as Debit,sum(isnull(l.Credit,0)) as Credit ,ISNULL(SUM(l.Debit - l.Credit), 0) AS OpeningBalance
    FROM [accounting].[DocumentLines] l
    INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
    Group by AccountCode
)

select p.AccountCode,Title,LinkName,isnull(o.Debit,0) as Debit,isnull(o.Credit,0) as  Credit, isnull(o.OpeningBalance ,0) as OpeningBalance 
from DetailPaths as P
left outer join Opening O on P.AccountCode=o.AccountCode
Where p.AccountCode=@AccountCode;