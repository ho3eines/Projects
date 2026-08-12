-- =============================================
-- webapi/Data/Scripts/accounting/TaxRuleSearch.sql
-- Schema: accounting | Contract: TaxRule
-- Query. Shape MUST match TaxRuleRow (Share) exactly.
-- =============================================
SELECT
    t.TaxRuleId,
    t.RuleCode,
    t.Title,
    t.Category,
    t.RatePercent,
    t.EffectiveFrom,
    t.IsActive
FROM [accounting].[TaxRules] t
WHERE t.IsDeleted = 0
  AND (@SearchText = N'' OR t.Title LIKE N'%' + @SearchText + N'%'
       OR t.RuleCode LIKE N'%' + @SearchText + N'%')
ORDER BY t.EffectiveFrom DESC, t.RuleCode
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
