namespace Tarazin.Models;

public class DailyMovementRow
{
    public int MovementId { get; set; }
    public string MovementNumber { get; set; } = "";
    public DateTime MovementDate { get; set; }
    public string MovementType { get; set; } = "";
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public string WarehouseName { get; set; } = "";
    public string SubWarehouseName { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal CostPrice { get; set; }
    public decimal TotalValue { get; set; }
    public string Status { get; set; } = "";
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
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
    public int? GroupId { get; set; }
    public string? GroupTitle { get; set; }
    public int? UnitId { get; set; }
    public string? UnitTitle { get; set; }
    public decimal StockQty { get; set; }
    public decimal UnitPrice { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class WarehouseRow
{
    public int WarehouseId { get; set; }
    public string WarehouseCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Location { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class SubWarehouseRow
{
    public int SubWarehouseId { get; set; }
    public int WarehouseId { get; set; }
    public string WarehouseTitle { get; set; } = "";
    public string SubWarehouseCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Location { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ItemGroupRow
{
    public int GroupId { get; set; }
    public string GroupCode { get; set; } = "";
    public string Title { get; set; } = "";
    public int SortOrder { get; set; }
    public bool IsActive { get; set; }
    public int ItemCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class UnitRow
{
    public int UnitId { get; set; }
    public string UnitCode { get; set; } = "";
    public string Title { get; set; } = "";
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class InventorySettingsRow
{
    public int CompanyId { get; set; }
    public string CostingMethod { get; set; } = "WeightedAverage";
    public int? InventoryAccountId { get; set; }
    public string? InventoryAccountCode { get; set; }
    public string? InventoryAccountTitle { get; set; }
    public int? ReceiptContraAccountId { get; set; }
    public string? ReceiptContraAccountCode { get; set; }
    public string? ReceiptContraAccountTitle { get; set; }
    public int? IssueContraAccountId { get; set; }
    public string? IssueContraAccountCode { get; set; }
    public string? IssueContraAccountTitle { get; set; }
    public int? DefaultWarehouseId { get; set; }
    public string? DefaultWarehouseTitle { get; set; }
    public int? DefaultSubWarehouseId { get; set; }
    public string? DefaultSubWarehouseTitle { get; set; }
    public bool IsEnabled { get; set; } = true;
    public DateTime UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
}

public class StockCardRow
{
    public int MovementId { get; set; }
    public DateTime MovementDate { get; set; }
    public string MovementNumber { get; set; } = "";
    public string MovementType { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal CostPrice { get; set; }
    public decimal TotalValue { get; set; }
    public string? Description { get; set; }
    public decimal InQty { get; set; }
    public decimal OutQty { get; set; }
    public decimal InValue { get; set; }
    public decimal OutValue { get; set; }
    public decimal OpeningQty { get; set; }
    public decimal OpeningValue { get; set; }
    public decimal BalanceQty { get; set; }
    public decimal BalanceValue { get; set; }
}

public class StockBalanceRow
{
    public int ItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public string Unit { get; set; } = "";
    public int? WarehouseId { get; set; }
    public string? WarehouseName { get; set; }
    public int? SubWarehouseId { get; set; }
    public string? SubWarehouseName { get; set; }
    public decimal StockQty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal StockValue { get; set; }
}
