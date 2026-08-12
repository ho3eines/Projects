namespace TarazinApp.Models;

public class DailySaleRow
{
    public int InvoiceId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public DateTime InvoiceDate { get; set; }
    public string CustomerName { get; set; } = "";
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public decimal WeightGram { get; set; }
    public decimal Workmanship { get; set; }
    public decimal Profit { get; set; }
    public decimal Tax { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = "";
}

public class GoldShopDashboardRow
{
    public int TodaySales { get; set; }
    public decimal TodayAmount { get; set; }
    public int PriceCount { get; set; }
    public decimal Gold24Price { get; set; }
}

public class GoldItemRow
{
    public int GoldItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal? Purity { get; set; }
    public bool IsActive { get; set; }
}
