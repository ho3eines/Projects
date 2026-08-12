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
}

public class CustomerRow
{
    public int CustomerId { get; set; }
    public string CustomerCode { get; set; } = "";
    public string FullName { get; set; } = "";
    public string Phone { get; set; } = "";
    public string Email { get; set; } = "";
    public bool IsActive { get; set; }
}

public class StoreDashboardRow
{
    public int TodayOrders { get; set; }
    public decimal TodayAmount { get; set; }
    public int PendingOrders { get; set; }
    public int TotalCustomers { get; set; }
}
