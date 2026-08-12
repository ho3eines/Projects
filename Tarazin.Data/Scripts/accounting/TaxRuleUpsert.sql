-- =============================================
-- Tarazin.Data/Scripts/accounting/TaxRuleUpsert.sql
-- Schema: accounting | Contract: TaxRule (producer)
-- Execute. Hot-reloadable: consumers re-read this table per period.
-- =============================================
-- TaxRuleId=0 identifies a new record; every non-zero id is an edit.
IF @TaxRuleId = 0
BEGIN
    INSERT INTO [accounting].[TaxRules] (RuleCode, Title, Category, RatePercent, EffectiveFrom, IsActive, CreatedAt)
    VALUES (@RuleCode, @Title, @Category, @RatePercent, @EffectiveFrom, ISNULL(@IsActive, 1), SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [accounting].[TaxRules]
    SET RuleCode      = ISNULL(@RuleCode, RuleCode),
        Title         = ISNULL(@Title, Title),
        Category      = @Category,
        RatePercent   = @RatePercent,
        EffectiveFrom = ISNULL(@EffectiveFrom, EffectiveFrom),
        IsActive      = ISNULL(@IsActive, IsActive),
        UpdatedAt     = SYSUTCDATETIME()
    WHERE TaxRuleId = @TaxRuleId;
END
