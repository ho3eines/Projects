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
    public string? SourceReference { get; set; }
    public string? SourceType { get; set; }
    public long? SourceId { get; set; }
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
    // Phase 1 enrichment
    public string? SKU { get; set; }
    public string? Barcode { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public decimal MinStock { get; set; }
    public decimal MaxStock { get; set; }
    public decimal ReorderPoint { get; set; }
    public decimal? LivePrice { get; set; }        // قیمت زندهٔ آنلاین (طلا/فلزات) از مرکز قیمت — فقط نمایشی
    public string? LiveSource { get; set; }
    public string? LiveItemKey { get; set; }
    public bool HasBatch { get; set; }
    public bool HasSerial { get; set; }
    public bool HasExpiry { get; set; }
    public string? LatinTitle { get; set; }
    public decimal PurchasePrice { get; set; }
    public decimal SalePrice { get; set; }
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    // ItemStockInfo.sql — قیمت آخرین فاکتور (نه قیمت ثابت کالا)
    public decimal? LastPurchasePrice { get; set; }
    public decimal? LastSalePrice { get; set; }
}

public class ItemStockInfoRow
{
    public decimal StockQty { get; set; }
    public string Unit { get; set; } = "";
    public decimal? LastPurchasePrice { get; set; }
    public decimal? LastSalePrice { get; set; }
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
    public int? AdjustmentAccountId { get; set; }
    public string? AdjustmentAccountCode { get; set; }
    public string? AdjustmentAccountTitle { get; set; }
    public int? DefaultWarehouseId { get; set; }
    public string? DefaultWarehouseTitle { get; set; }
    public int? DefaultSubWarehouseId { get; set; }
    public string? DefaultSubWarehouseTitle { get; set; }
    public bool IsEnabled { get; set; } = true;
    public DateTime UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>خروجی StocktakeRun — شناسهٔ سند حسابداری انبارگردانی (اگر ساخته شده باشد).</summary>
public class StocktakeResultRow
{
    public int? DocumentId { get; set; }
}

/// <summary>واحدهای چندگانهٔ یک کالا — ضریب تبدیل (Factor) نسبت به واحد پایه (IsDefault=1 با Factor=1).</summary>
public class ItemUnitRow
{
    public int ItemUnitId { get; set; }
    public int ItemId { get; set; }
    public int UnitId { get; set; }
    public decimal Factor { get; set; } = 1;
    public bool IsDefault { get; set; }
    public string? UnitTitle { get; set; }
    public string? UnitCode { get; set; }
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
    public string? LotNo { get; set; }
    public string? SerialNo { get; set; }
    public string? ExpiryDate { get; set; }
    public string? EarliestExpiry { get; set; }
    public string? SourceReference { get; set; }
    public string? SourceType { get; set; }
    public long? SourceId { get; set; }
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

// ============================================================
// Phase 1 — Purchase/Sales invoices, returns, transfers, barcodes
// ============================================================

/// <summary>فاکتور خرید — مستقل از فاکتور فروش.</summary>
public class PurchaseInvoiceRow
{
    public int PurchaseInvoiceId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public DateTime InvoiceDate { get; set; }
    public int? SupplierPartyId { get; set; }
    public string? SupplierName { get; set; }
    public int? WarehouseId { get; set; }
    public string? WarehouseTitle { get; set; }
    public string? ReferenceNumber { get; set; }
    public string? PaymentTerms { get; set; }
    public DateTime? DueDate { get; set; }
    public string? Description { get; set; }
    public decimal GrossAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal ChargesAmount { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal DutyAmount { get; set; }
    public decimal NetAmount { get; set; }
    public string Status { get; set; } = "Draft";
    public int? DocumentId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>قلم فاکتور خرید.</summary>
public class PurchaseInvoiceLineRow
{
    public int PurchaseInvoiceLineId { get; set; }
    public int PurchaseInvoiceId { get; set; }
    public int ItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public int? UnitId { get; set; }
    public string? UnitTitle { get; set; }
    public decimal Qty { get; set; }
    public decimal GiftQty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal GrossAmount { get; set; }
    public decimal DiscountPercent { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal TaxPercent { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal DutyPercent { get; set; }
    public decimal DutyAmount { get; set; }
    public decimal ChargesAmount { get; set; }
    public decimal CostPrice { get; set; }
    public decimal NetAmount { get; set; }
    public int SortOrder { get; set; }
}

/// <summary>فاکتور فروش — مستقل از فاکتور خرید.</summary>
public class SalesInvoiceRow
{
    public int SalesInvoiceId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public DateTime InvoiceDate { get; set; }
    public int? CustomerPartyId { get; set; }
    public string? CustomerName { get; set; }
    public int? WarehouseId { get; set; }
    public string? WarehouseTitle { get; set; }
    public string? ReferenceNumber { get; set; }
    public string? PaymentTerms { get; set; }
    public DateTime? DueDate { get; set; }
    public string? SaleType { get; set; }
    public string? Description { get; set; }
    public decimal GrossAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal ChargesAmount { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal DutyAmount { get; set; }
    public decimal NetAmount { get; set; }
    public decimal CostOfGoodsSold { get; set; }
    public decimal GrossProfit { get; set; }
    public string Status { get; set; } = "Draft";
    public int? DocumentId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>قلم فاکتور فروش.</summary>
public class SalesInvoiceLineRow
{
    public int SalesInvoiceLineId { get; set; }
    public int SalesInvoiceId { get; set; }
    public int ItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public int? UnitId { get; set; }
    public string? UnitTitle { get; set; }
    public decimal Qty { get; set; }
    public decimal GiftQty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal GrossAmount { get; set; }
    public decimal DiscountPercent { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal TaxPercent { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal DutyPercent { get; set; }
    public decimal DutyAmount { get; set; }
    public decimal ChargesAmount { get; set; }
    public decimal CostPrice { get; set; }
    public decimal NetAmount { get; set; }
    public int SortOrder { get; set; }
}

/// <summary>برگشت خرید.</summary>
public class PurchaseReturnRow
{
    public int PurchaseReturnId { get; set; }
    public string ReturnNumber { get; set; } = "";
    public DateTime ReturnDate { get; set; }
    public int PurchaseInvoiceId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public int? WarehouseId { get; set; }
    public string? WarehouseTitle { get; set; }
    public string? Description { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = "Draft";
    public int? DocumentId { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>برگشت فروش.</summary>
public class SalesReturnRow
{
    public int SalesReturnId { get; set; }
    public string ReturnNumber { get; set; } = "";
    public DateTime ReturnDate { get; set; }
    public int SalesInvoiceId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public int? WarehouseId { get; set; }
    public string? WarehouseTitle { get; set; }
    public string? Description { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = "Draft";
    public int? DocumentId { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>انتقال بین انبارها.</summary>
public class WarehouseTransferRow
{
    public int TransferId { get; set; }
    public string TransferNumber { get; set; } = "";
    public DateTime TransferDate { get; set; }
    public int FromWarehouseId { get; set; }
    public string FromWarehouseTitle { get; set; } = "";
    public int ToWarehouseId { get; set; }
    public string ToWarehouseTitle { get; set; } = "";
    public string? Description { get; set; }
    public string Status { get; set; } = "Draft";
    public int? DocumentId { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>قلم انتقال بین انبارها.</summary>
public class TransferLineRow
{
    public int TransferLineId { get; set; }
    public int TransferId { get; set; }
    public int ItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal UnitCost { get; set; }
}

/// <summary>بارکد کالا (یک کالا چند بارکد).</summary>
public class ItemBarcodeRow
{
    public int BarcodeId { get; set; }
    public int ItemId { get; set; }
    public string Barcode { get; set; } = "";
    public bool IsPrimary { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}
