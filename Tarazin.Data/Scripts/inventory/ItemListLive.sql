-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemListLive.sql
-- Schema: inventory
-- Query. لیست کالا + قیمت زندهٔ آنلاین (طلا/فلزات) از مرکز قیمت.
--
-- اتصال: ItemCode کالا = ItemKey در [currency].[PriceItems] (مثل XAU-24؛
-- نگاره‌های TABLOTALA با همین کلیدها ثبت می‌شوند). برای جنس‌های طلافروشی،
-- از طریق goldshop.GoldItems.InventoryItemCode ← ItemCode هم امتحان می‌شود.
-- LivePrice: نرخ آنلاینِ آخرین سطر فعال (SystemRate اگر IsOverride=0 نشده باشد
-- طبق سیاست مرکز قیمت، اما برای نمایش از OnlineRate استفاده می‌شود چون «قیمت
-- زنده» است و هرگز مستقیم وارد معامله نمی‌شود — درج در فاکتور همچنان قیمت
-- دستی/پیش‌فرض کالا است).
-- =============================================
SELECT i.ItemId, i.ItemCode, i.ItemTitle, i.Category, i.Unit, i.StockQty, i.UnitPrice, i.IsActive,
       i.GroupId, g.Title AS GroupTitle,
       i.UnitId, u.Title AS UnitTitle,
       i.CreatedAt, i.UpdatedAt, i.CreatedBy, i.UpdatedBy,
       i.SKU, i.Barcode, i.Brand, i.Model, i.MinStock, i.MaxStock, i.ReorderPoint,
       i.HasBatch, i.HasSerial, i.HasExpiry, i.LatinTitle, i.PurchasePrice, i.SalePrice,
       i.Description, i.ImageUrl,
       pr.OnlineRate AS LivePrice,
       pr.SourceKey AS LiveSource,
       pi.ItemKey AS LiveItemKey,
       (SELECT TOP 1 il.UnitPrice
        FROM [inventory].[InvoiceLines] il
        JOIN [inventory].[Invoices] inv ON inv.InvoiceId = il.InvoiceId
        WHERE il.ItemId = i.ItemId AND inv.OperationType = N'Purchase' AND inv.IsDeleted = 0
        ORDER BY inv.InvoiceDate DESC, inv.InvoiceId DESC) AS LastPurchasePrice,
       (SELECT TOP 1 il.UnitPrice
        FROM [inventory].[InvoiceLines] il
        JOIN [inventory].[Invoices] inv ON inv.InvoiceId = il.InvoiceId
        WHERE il.ItemId = i.ItemId AND inv.OperationType = N'Sales' AND inv.IsDeleted = 0
        ORDER BY inv.InvoiceDate DESC, inv.InvoiceId DESC) AS LastSalePrice
FROM [inventory].[Items] i
LEFT JOIN [inventory].[ItemGroups] g ON g.GroupId = i.GroupId AND g.IsDeleted = 0
LEFT JOIN [inventory].[Units] u ON u.UnitId = i.UnitId AND u.IsDeleted = 0
LEFT JOIN (
    SELECT r.PriceItemId, r.OnlineRate, r.SourceKey, r.IsValid
    FROM [currency].[PriceRates] r
    WHERE r.IsValid = 1
) pr ON pr.PriceItemId = (
    SELECT TOP 1 pi.PriceItemId
    FROM [currency].[PriceItems] pi
    WHERE pi.IsDeleted = 0
      AND (pi.ItemKey = i.ItemCode
           OR pi.ItemKey IN (SELECT g2.InventoryItemCode FROM [goldshop].[GoldItems] g2
                             WHERE g2.InventoryItemCode = i.ItemCode AND g2.IsDeleted = 0))
    ORDER BY pi.ItemKey
)
LEFT JOIN [currency].[PriceItems] pi ON pi.PriceItemId = pr.PriceItemId
WHERE i.IsDeleted = 0 AND i.CompanyId = @CompanyId
  AND (@Search IS NULL OR @Search = N''
       OR i.ItemCode LIKE N'%' + @Search + N'%'
       OR i.ItemTitle LIKE N'%' + @Search + N'%'
       OR i.SKU LIKE N'%' + @Search + N'%'
       OR i.Barcode LIKE N'%' + @Search + N'%'
       OR i.Brand LIKE N'%' + @Search + N'%')
ORDER BY i.ItemTitle;