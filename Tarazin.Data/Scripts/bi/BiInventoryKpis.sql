-- =============================================
-- Tarazin.Data/Scripts/bi/BiInventoryKpis.sql
-- Schema: bi
-- Cross-schema: inventory
-- Query. داشبورد انبار (§34–§38): ارزش/تعداد/کم‌موجودی/بدون موجودی/منفی/راکد.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Value DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(StockQty, 0) * ISNULL(UnitPrice, 0)) FROM [inventory].[Items] WHERE IsDeleted = 0), 0);
DECLARE @ItemCount INT = ISNULL((SELECT COUNT(*) FROM [inventory].[Items] WHERE IsDeleted = 0), 0);
DECLARE @ZeroStock INT = ISNULL((SELECT COUNT(*) FROM [inventory].[Items] WHERE IsDeleted = 0 AND ISNULL(StockQty, 0) = 0), 0);
DECLARE @Negative INT = ISNULL((SELECT COUNT(*) FROM [inventory].[Items] WHERE IsDeleted = 0 AND ISNULL(StockQty, 0) < 0), 0);
-- راکد: بدون هیچ حرکت انبار در ۹۰ روز گذشته
DECLARE @Dead90 INT = ISNULL((
    SELECT COUNT(*) FROM [inventory].[Items] i
    WHERE i.IsDeleted = 0 AND NOT EXISTS (
        SELECT 1 FROM [inventory].[Movements] m
        WHERE m.ItemId = i.ItemId AND m.MovementDate >= DATEADD(DAY, -90, CAST(SYSDATETIME() AS DATE)))),
    0);

SELECT N'inv_value' AS KpiKey, N'ارزش کل موجودی' AS Title, ISNULL(@Value, 0) AS Amount, NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent,
       N'IRR' AS Unit, N'/inventory/reports' AS Link, N'∑ (موجودی × قیمت واحد)' AS Formula, N'inventory' AS Source
UNION ALL SELECT N'inv_items', N'تعداد اقلام کالا', ISNULL(@ItemCount, 0), NULL, NULL, NULL, N'قلم', N'/inventory', N'تعداد کالاهای فعال', N'inventory'
UNION ALL SELECT N'inv_zero', N'کالاهای بدون موجودی', ISNULL(@ZeroStock, 0), NULL, NULL, NULL, N'قلم', N'/inventory/reports', N'کالاهای با موجودی صفر', N'inventory'
UNION ALL SELECT N'inv_negative', N'کالاهای با موجودی منفی', ISNULL(@Negative, 0), NULL, NULL, NULL, N'قلم', N'/inventory/reports', N'کالاهای با موجودی منفی', N'inventory'
UNION ALL SELECT N'inv_dead90', N'کالاهای راکد (۹۰ روز)', ISNULL(@Dead90, 0), NULL, NULL, NULL, N'قلم', N'/inventory/reports', N'بدون حرکت در ۹۰ روز گذشته', N'inventory';
