-- =============================================
-- Tarazin.Data/Scripts/store/OrderPriceQuote.sql
-- Schema: store
-- Query. پیش‌نمایش قیمت سفارش با موتور قیمت موج ۳ — همان منطقی که
--        OrderPlace اجرا می‌کند تا «آنچه می‌بینی همان است که پرداخت می‌کنی».
-- ورودی: @CustomerId (+ اختیاری @StoreId/@PriceListId/@CouponCode)
-- خروجی: ردیف‌های سبد با قیمت واحد مؤثر + ردیف جمع (Gross/Discount/Total).
-- ترتیب موتور قیمت:
--   ۱) ProductPrices (لیست قیمت per-store، بازهٔ تاریخ، MinQty) — دقیق‌ترین منبع
--   ۲) Products.DiscountPrice (در بازهٔ DiscountFrom/To)
--   ۳) Products.Price (پایه)
--   سپس Promotion فعال (درصدی/مبلغی) و در پایان Coupon (با سقف MaxDiscount).
-- =============================================
DECLARE @CustomerStoreId INT, @EffDate DATE = CAST(SYSDATETIME() AS DATE);

IF @StoreId IS NULL
    SELECT @CustomerStoreId = StoreId FROM [store].[Customers]
    WHERE CustomerId = @CustomerId AND IsDeleted = 0;

DECLARE @Store INT = COALESCE(@StoreId, @CustomerStoreId);
DECLARE @CouponCodeValue NVARCHAR(50) = @CouponCode;

-- ── ردیف‌های سبد با قیمت مؤثر ────────────────────────────────
WITH Cart AS (
    SELECT ci.ProductId, p.Title, p.ItemCode, ci.Qty,
           p.Price AS BasePrice, p.DiscountPrice, p.DiscountFrom, p.DiscountTo,
           p.CategoryId
    FROM [store].[CartItems] ci
    JOIN [store].[Products] p ON p.ProductId = ci.ProductId
    WHERE ci.CustomerId = @CustomerId
),
BestPrice AS (
    SELECT c.ProductId, c.Title, c.ItemCode, c.Qty, c.CategoryId,
           -- قیمت لیست: دقیق‌ترین بازه/MinQty و اولویت فروشگاه مشخص
           COALESCE(
               (SELECT TOP 1 pp.Price
                  FROM [store].[ProductPrices] pp
                 WHERE pp.CompanyId = @CompanyId
                   AND pp.ProductId = c.ProductId
                   AND pp.IsDeleted = 0
                   AND (@PriceListId IS NULL OR pp.PriceListId = @PriceListId)
                   AND (@Store IS NULL OR pp.StoreId IS NULL OR pp.StoreId = @Store)
                   AND (pp.FromDate IS NULL OR pp.FromDate <= @EffDate)
                   AND (pp.ToDate IS NULL OR pp.ToDate >= @EffDate)
                   AND pp.MinQty <= c.Qty
                 ORDER BY (CASE WHEN pp.StoreId IS NOT NULL THEN 0 ELSE 1 END),
                          pp.MinQty DESC),
               CASE WHEN c.DiscountPrice IS NOT NULL
                     AND (c.DiscountFrom IS NULL OR c.DiscountFrom <= SYSDATETIME())
                     AND (c.DiscountTo   IS NULL OR c.DiscountTo   >= SYSDATETIME())
                    THEN c.DiscountPrice END,
               c.BasePrice) AS UnitPrice
    FROM Cart c
)
SELECT ProductId AS TotalKey, Title, ItemCode, Qty, UnitPrice, ROUND(Qty * UnitPrice, 0) AS LineTotal, 0 AS SortKey
FROM BestPrice
UNION ALL
-- ردیف جمع: Title='__TOTAL__'؛ UnitPrice = تخفیف کل؛ LineTotal = قابل‌پرداخت
SELECT NULL AS TotalKey, N'__TOTAL__' AS Title, NULL AS ItemCode, SUM(b9.Qty) AS Qty,
       G.Gross - G.Payable AS UnitPrice, G.Payable AS LineTotal, 1 AS SortKey
FROM BestPrice b9
CROSS JOIN (
    SELECT (SELECT SUM(ROUND(b2.Qty * b2.UnitPrice, 0)) FROM BestPrice b2) AS Gross,
           (SELECT SUM(ROUND(b2.Qty * b2.UnitPrice, 0)) FROM BestPrice b2) -
           COALESCE((SELECT TOP 1 CASE pr.DiscountType
                                    WHEN N'Percent' THEN ROUND((SELECT SUM(ROUND(b2.Qty * b2.UnitPrice, 0)) FROM BestPrice b2) * pr.DiscountValue / 100.0, 0)
                                    ELSE pr.DiscountValue END
                       FROM [store].[Promotions] pr
                      WHERE pr.CompanyId = @CompanyId AND pr.IsActive = 1 AND pr.IsDeleted = 0
                        AND GETDATE() BETWEEN pr.FromDate AND pr.ToDate
                        AND (SELECT SUM(ROUND(b.Qty * b.UnitPrice, 0)) FROM BestPrice b) >= pr.MinOrderTotal
                        AND (@Store IS NULL OR pr.StoreId IS NULL OR pr.StoreId = @Store)
                        AND (   (pr.ProductId IS NOT NULL AND EXISTS (SELECT 1 FROM BestPrice b2 WHERE b2.ProductId = pr.ProductId))
                             OR (pr.ProductId IS NULL AND pr.CategoryId IS NOT NULL
                                 AND EXISTS (SELECT 1 FROM BestPrice b2 WHERE b2.CategoryId = pr.CategoryId))
                             OR (pr.ProductId IS NULL AND pr.CategoryId IS NULL) )
                      ORDER BY CASE WHEN pr.ProductId IS NOT NULL THEN 0
                                    WHEN pr.CategoryId IS NOT NULL THEN 1
                                    ELSE 2 END), 0)
           - COALESCE((SELECT CASE cp.DiscountType
                                   WHEN N'Percent' THEN LEAST(ROUND((SELECT SUM(ROUND(b.Qty * b.UnitPrice, 0)) FROM BestPrice b) * cp.DiscountValue / 100.0, 0),
                                                              ISNULL(cp.MaxDiscount, 999999999999))
                                   ELSE LEAST(cp.DiscountValue, (SELECT SUM(ROUND(b.Qty * b.UnitPrice, 0)) FROM BestPrice b)) END
                        FROM [store].[Coupons] cp
                       WHERE cp.CompanyId = @CompanyId AND cp.Code = @CouponCode
                         AND cp.IsDeleted = 0 AND cp.IsActive = 1
                         AND GETDATE() BETWEEN cp.FromDate AND cp.ToDate
                         AND (cp.UsageLimit IS NULL OR cp.UsedCount < cp.UsageLimit)
                         AND (SELECT SUM(ROUND(b.Qty * b.UnitPrice, 0)) FROM BestPrice b) >= cp.MinOrderTotal
                         AND (@Store IS NULL OR cp.StoreId IS NULL OR cp.StoreId = @Store)
                         AND (cp.PerCustomerLimit IS NULL OR
                              (SELECT COUNT(*) FROM [store].[CouponRedemptions] cr
                                WHERE cr.CouponId = cp.CouponId AND cr.CustomerId = @CustomerId) < cp.PerCustomerLimit)), 0) AS Payable
) G
GROUP BY G.Gross, G.Payable;
