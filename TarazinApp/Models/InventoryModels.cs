namespace TarazinApp.Models;

public class DailyMovementRow
{
    public int MovementId { get; set; }
    public string MovementNumber { get; set; } = "";
    public DateTime MovementDate { get; set; }
    public string MovementType { get; set; } = "";
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public string WarehouseName { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalValue { get; set; }
    public string Status { get; set; } = "";
    public string? Description { get; set; }
}

public class InventoryDashboardRow
{
    public int TodayMovements { get; set; }
    public int TotalItems { get; set; }
    public decimal StockValue { get; set; }
    public int ActiveReservations { get; set; }
}

public class ItemRow
{
    public int ItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public string Category { get; set; } = "";
    public string Unit { get; set; } = "";
    public decimal StockQty { get; set; }
    public decimal UnitPrice { get; set; }
    public bool IsActive { get; set; }
}

public class WarehouseRow
{
    public int WarehouseId { get; set; }
    public string WarehouseCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Location { get; set; }
}

public class StockCardRow
{
    public int MovementId { get; set; }
    public DateTime MovementDate { get; set; }
    public string MovementNumber { get; set; } = "";
    public string MovementType { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalValue { get; set; }
    public string? Description { get; set; }
}

public class StockBalanceRow
{
    public int ItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public string Unit { get; set; } = "";
    public decimal StockQty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal StockValue { get; set; }
}
