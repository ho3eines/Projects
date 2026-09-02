namespace Tarazin.Models;

public class CartItemRow
{
    public int CartItemId { get; set; }
    public int CustomerId { get; set; }
    public int ProductId { get; set; }
    public string ProductTitle { get; set; } = "";
    public string ItemCode { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal Price { get; set; }
    public decimal LineTotal { get; set; }
}

public class ProductRow
{
    public int ProductId { get; set; }
    public string ProductCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string ItemCode { get; set; } = "";
    public decimal Price { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class CustomerRow
{
    public int CustomerId { get; set; }
    public string CustomerCode { get; set; } = "";
    public string FullName { get; set; } = "";
    public string Phone { get; set; } = "";
    public string Email { get; set; } = "";
    public bool IsActive { get; set; }
    public int? PartyId { get; set; }
    public decimal Balance { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>تنظیمات فروشگاه — لینک‌های حسابداری/خزانه/انبار برای سند خودکار سفارش.</summary>
public class StoreSettingsRow
{
    public int CompanyId { get; set; }
    public int? InventoryWarehouseId { get; set; }
    public string? InventoryWarehouseTitle { get; set; }
    public int? SalesAccountId { get; set; }
    public string? SalesAccountCode { get; set; }
    public string? SalesAccountTitle { get; set; }
    public int? InventoryAccountId { get; set; }
    public string? InventoryAccountCode { get; set; }
    public string? InventoryAccountTitle { get; set; }
    public int? CashAccountId { get; set; }
    public string? CashAccountCode { get; set; }
    public string? CashAccountTitle { get; set; }
    public int? BankChartAccountId { get; set; }
    public string? BankChartAccountCode { get; set; }
    public string? BankChartAccountTitle { get; set; }
    public int? CashBoxId { get; set; }
    public string? CashBoxTitle { get; set; }
    public int? BankAccountId { get; set; }
    public string? BankAccountTitle { get; set; }
    public bool IsEnabled { get; set; } = true;
    public DateTime? UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>ردیف دفتر مشتری فروشگاه (کیف پول ریالی بدهکار/بستانکار).</summary>
public class OrderLedgerRow
{
    public int LedgerId { get; set; }
    public int CustomerId { get; set; }
    public int OrderId { get; set; }
    public DateTime EntryDate { get; set; }
    public string EntryType { get; set; } = "";
    public decimal DebitRial { get; set; }
    public decimal CreditRial { get; set; }
    public string? Description { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class OrderItemRow
{
    public int OrderItemId { get; set; }
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public string ProductTitle { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
}

public class LedgerBalanceRow
{
    public decimal Balance { get; set; }
}

/// <summary>نتیجهٔ ثبت سفارش (خروجی OrderPlace).</summary>
public class OrderResultRow
{
    public int OrderId { get; set; }
    public string OrderNumber { get; set; } = "";
    public decimal GrossTotal { get; set; }
    public decimal DiscountTotal { get; set; }
    public decimal PromotionDiscount { get; set; }
    public decimal CouponDiscount { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal BalanceRial { get; set; }
    public int DocumentId { get; set; }
}

// ═══════════════ WAVE 3: Pricing (per-store PriceLists + Promotions + Coupons) ═══════════════

/// <summary>لیست قیمت (Retail/Wholesale/VIP/...) — StoreId=NULL یعنی همهٔ فروشگاه‌ها.</summary>
public class PriceListRow
{
    public int PriceListId { get; set; }
    public int CompanyId { get; set; }
    public string Code { get; set; } = "";
    public string Title { get; set; } = "";
    public int? StoreId { get; set; }
    public string? StoreTitle { get; set; }
    public string CurrencyCode { get; set; } = "IRR";
    public bool IsActive { get; set; }
    public int PriceCount { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>قیمت محصول در یک لیست (با بازهٔ تاریخ و MinQty).</summary>
public class ProductPriceRow
{
    public int PriceId { get; set; }
    public int CompanyId { get; set; }
    public int PriceListId { get; set; }
    public string PriceListTitle { get; set; } = "";
    public int ProductId { get; set; }
    public string ProductTitle { get; set; } = "";
    public string ProductCode { get; set; } = "";
    public int? StoreId { get; set; }
    public string? StoreTitle { get; set; }
    public decimal Price { get; set; }
    public decimal BasePrice { get; set; }
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
    public decimal MinQty { get; set; }
}

/// <summary>کمپین تخفیف (درصدی/مبلغی) با دامنهٔ فروشگاه/محصول/دسته.</summary>
public class PromotionRow
{
    public int PromotionId { get; set; }
    public int CompanyId { get; set; }
    public string Code { get; set; } = "";
    public string Title { get; set; } = "";
    public int? StoreId { get; set; }
    public string? StoreTitle { get; set; }
    public int? ProductId { get; set; }
    public string? ProductTitle { get; set; }
    public int? CategoryId { get; set; }
    public string? CategoryTitle { get; set; }
    public string DiscountType { get; set; } = "Percent";
    public decimal DiscountValue { get; set; }
    public DateTime FromDate { get; set; }
    public DateTime ToDate { get; set; }
    public decimal MinOrderTotal { get; set; }
    public bool IsActive { get; set; }
    public bool IsRunning { get; set; }
}

/// <summary>کد تخفیف قابل‌اعمال در سبد/OrderPlace.</summary>
public class CouponRow
{
    public int CouponId { get; set; }
    public int CompanyId { get; set; }
    public string Code { get; set; } = "";
    public string Title { get; set; } = "";
    public int? StoreId { get; set; }
    public string? StoreTitle { get; set; }
    public string DiscountType { get; set; } = "Percent";
    public decimal DiscountValue { get; set; }
    public decimal? MaxDiscount { get; set; }
    public decimal MinOrderTotal { get; set; }
    public int? UsageLimit { get; set; }
    public int UsedCount { get; set; }
    public int? PerCustomerLimit { get; set; }
    public DateTime FromDate { get; set; }
    public DateTime ToDate { get; set; }
    public bool IsActive { get; set; }
    public bool IsValidNow { get; set; }
}

/// <summary>ردیف پیش‌نمایش قیمت (خروجی OrderPriceQuote — ردیف __TOTAL__ جمع است).</summary>
public class OrderQuoteRow
{
    public int? ProductId { get; set; }
    public string Title { get; set; } = "";
    public string? ItemCode { get; set; }
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
    public bool IsTotal => Title == "__TOTAL__";
}

public class ProductCategoryRow
{
    public int CategoryId { get; set; }
    public string CategoryCode { get; set; } = "";
    public string Title { get; set; } = "";
    public int SortOrder { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class StoreDashboardRow
{
    public int TodayOrders { get; set; }
    public decimal TodayAmount { get; set; }
    public int PendingOrders { get; set; }
    public int TotalCustomers { get; set; }
}

// ═══════════════ WAVE 1: Multi-Store + State Machine ═══════════════

/// <summary>فروشگاه فیزیکی/آنلاین متصل به یک انبار اختصاصی.</summary>
public class StoreRow
{
    public int StoreId { get; set; }
    public int CompanyId { get; set; }
    public string StoreCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string StoreType { get; set; } = "Physical";
    public int? WarehouseId { get; set; }
    public string? WarehouseTitle { get; set; }
    public string? ManagerName { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? Address { get; set; }
    public string? WorkingHours { get; set; }
    public string? Description { get; set; }
    public bool OnlineEnabled { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>یک تغییر وضعیت سفارش در State Machine.</summary>
public class OrderStatusHistoryRow
{
    public int HistoryId { get; set; }
    public int OrderId { get; set; }
    public string? FromStatus { get; set; }
    public string ToStatus { get; set; } = "";
    public string? Reason { get; set; }
    public string? ChangedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>ردیف سفارش با اطلاعات فروشگاه (گزارش لیست سفارش‌ها).</summary>
public class OrderListRow
{
    public int OrderId { get; set; }
    public string OrderNumber { get; set; } = "";
    public DateTime OrderDate { get; set; }
    public string CustomerName { get; set; } = "";
    public int? StoreId { get; set; }
    public string? StoreTitle { get; set; }
    public int ItemCount { get; set; }
    public decimal TotalAmount { get; set; }
    public string CurrencyCode { get; set; } = "IRR";
    public string Status { get; set; } = "";
    public string PaymentStatus { get; set; } = "Unpaid";
    public decimal BalanceRial { get; set; }
    public int? DocumentId { get; set; }
}

// ═══════════════ WAVE 2: Product Catalog ═══════════════

/// <summary>برند محصول.</summary>
public class BrandRow
{
    public int BrandId { get; set; }
    public int CompanyId { get; set; }
    public string BrandCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? LogoUrl { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public int ProductCount { get; set; }
}

/// <summary>ویژگی داینامیک محصول (بدون تغییر اسکیما).</summary>
public class AttributeRow
{
    public int AttributeId { get; set; }
    public int CompanyId { get; set; }
    public int? AttributeGroupId { get; set; }
    public string? GroupTitle { get; set; }
    public string Title { get; set; } = "";
    public string DataType { get; set; } = "Text";
    public string? Unit { get; set; }
    public bool IsVariantFacet { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; }
}

/// <summary>مقدار یک ویژگی روی محصول.</summary>
public class ProductAttributeRow
{
    public int ProductAttributeId { get; set; }
    public int AttributeId { get; set; }
    public string AttributeTitle { get; set; } = "";
    public string? Unit { get; set; }
    public string? ValueText { get; set; }
    public int SortOrder { get; set; }
}

/// <summary>تنوع محصول (رنگ/سایز/...) با موجودی مستقل از انبار.</summary>
public class ProductVariantRow
{
    public int VariantId { get; set; }
    public string VariantCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Barcode { get; set; }
    public decimal Price { get; set; }
    public decimal? DiscountPrice { get; set; }
    public decimal? Weight { get; set; }
    public string? ImageUrl { get; set; }
    public bool IsActive { get; set; }
    public string? ItemCode { get; set; }
    public decimal AvailableQty { get; set; }
    public string? FacetsSummary { get; set; }
}

/// <summary>تصویر محصول.</summary>
public class ProductImageRow
{
    public int ImageId { get; set; }
    public string ImageUrl { get; set; } = "";
    public string? AltText { get; set; }
    public int SortOrder { get; set; }
    public bool IsMain { get; set; }
}

/// <summary>ردیف کاتالوگ محصولات (لیست با دسته/برند/موجودی).</summary>
public class ProductCatalogRow
{
    public int ProductId { get; set; }
    public string ProductCode { get; set; } = "";
    public string? SKU { get; set; }
    public string? Barcode { get; set; }
    public string Title { get; set; } = "";
    public int? CategoryId { get; set; }
    public string? CategoryTitle { get; set; }
    public int? BrandId { get; set; }
    public string? BrandTitle { get; set; }
    public string? ItemCode { get; set; }
    public decimal Price { get; set; }
    public decimal? DiscountPrice { get; set; }
    public string? MainImageUrl { get; set; }
    public bool IsActive { get; set; }
    public bool HasVariants { get; set; }
    public decimal AvailableQty { get; set; }
    public int VariantCount { get; set; }
}

/// <summary>جزئیات کامل محصول (۴ Result Set از ProductDetail.sql).</summary>
public class ProductDetailBundle
{
    public ProductCatalogRow Product { get; set; } = new();
    public List<ProductAttributeRow> Attributes { get; set; } = new();
    public List<ProductVariantRow> Variants { get; set; } = new();
    public List<ProductImageRow> Images { get; set; } = new();
}
