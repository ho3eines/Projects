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
    public decimal TotalAmount { get; set; }
    public decimal BalanceRial { get; set; }
    public int DocumentId { get; set; }
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
