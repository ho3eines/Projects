namespace Tarazin.Models;

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
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class GoldShopDashboardRow
{
    public int TodaySales { get; set; }
    public decimal TodayAmount { get; set; }
    public int PriceCount { get; set; }
    public decimal Gold24Price { get; set; }
    public int PendingInvoiceCheques { get; set; }
}

public class GoldItemRow
{
    public int GoldItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal? Purity { get; set; }
    public string? InventoryItemCode { get; set; }
    public string? InventoryItemTitle { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>طرف‌حساب مشترک طلافروشی؛ مشتری و تأمین‌کننده عمداً جدا نمایش داده می‌شوند.</summary>
public class GoldPartyRow
{
    public int PartyId { get; set; }
    public string PartyCode { get; set; } = "";
    public string PartyType { get; set; } = "Customer";
    public string FullName { get; set; } = "";
    public string? NationalId { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public bool IsActive { get; set; }
    public decimal BalanceRial { get; set; }
    public decimal GoldBalanceGram { get; set; }
    public decimal CurrencyBalance { get; set; }
    public string? CurrencyCode { get; set; }
    public int? DetailLinkId { get; set; }
    public string? DetailAccountCode { get; set; }
}

/// <summary>تنظیمات اتصال طلافروشی به انبار، حسابداری و خزانه‌داری.</summary>
public class GoldShopSettingsRow
{
    public int CompanyId { get; set; }
    public int? InventoryWarehouseId { get; set; }
    public string? InventoryWarehouseTitle { get; set; }
    public int? CustomerAccountGroupId { get; set; }
    public string? CustomerAccountGroupTitle { get; set; }
    public int? SupplierAccountGroupId { get; set; }
    public string? SupplierAccountGroupTitle { get; set; }
    public int? InventoryAccountGroupId { get; set; }
    public string? InventoryAccountGroupTitle { get; set; }
    public int? SalesAccountId { get; set; }
    public string? SalesAccountTitle { get; set; }
    public string? SalesAccountCode { get; set; }
    public int? InventoryAccountId { get; set; }
    public string? InventoryAccountTitle { get; set; }
    public string? InventoryAccountCode { get; set; }
    public int? TaxPayableAccountId { get; set; }
    public string? TaxPayableAccountTitle { get; set; }
    public string? TaxPayableAccountCode { get; set; }
    public int? CashAccountId { get; set; }
    public string? CashAccountTitle { get; set; }
    public string? CashAccountCode { get; set; }
    public int? BankAccountId { get; set; }
    public string? BankAccountTitle { get; set; }
    public int? CashBoxId { get; set; }
    public string? CashBoxTitle { get; set; }
    public int? BankChartAccountId { get; set; }
    public string? BankChartAccountTitle { get; set; }
    public string? BankChartAccountCode { get; set; }
    public decimal DefaultTaxPercent { get; set; }
    public decimal LaborTaxPercent { get; set; }
    public bool IsEnabled { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>مدل چاپ فاکتور خرید/فروش طلا — ورودی موتور چاپ عمومی (QuestPDF).</summary>
public class GoldInvoicePrintModel
{
    public string InvoiceType { get; set; } = "Sale";
    public string InvoiceNumber { get; set; } = "";
    public DateTime InvoiceDate { get; set; } = DateTime.Today;
    public string PartyName { get; set; } = "";
    public string? DetailCode { get; set; }
    public decimal TotalBase { get; set; }
    public decimal TotalTax { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal BalanceRial { get; set; }
    public decimal TaxPct { get; set; } = 10;
    public decimal LaborTaxPct { get; set; } = 10;
    public int DocumentId { get; set; }
    public List<GoldInvoicePrintLine> Lines { get; set; } = new();

    // سربرگ رسمی چاپ — از تنظیمات شرکت مالی (مثل سند حسابداری)
    public string? BrandName { get; set; }
    public string? QrBaseUrl { get; set; }

    // تسویه
    public decimal PayCash { get; set; }
    public decimal PayBank { get; set; }
    public decimal PayGoldGram { get; set; }
    public decimal GoldPrice { get; set; }
    public decimal PayCurrencyQty { get; set; }
    public string? PayCurrencyCode { get; set; }
    public decimal PayCurrencyRate { get; set; }
    public decimal PayChequeAmount { get; set; }
    public string? ChequeNumber { get; set; }
    public string? ChequeBankName { get; set; }
    public DateTime? ChequeDueDate { get; set; }
}

/// <summary>ردیف چاپی فاکتور (طلا یا ارز).</summary>
public class GoldInvoicePrintLine
{
    public string RowType { get; set; } = "Gold";
    public string Title { get; set; } = "";
    public string? CurrencyCode { get; set; }
    public decimal Qty { get; set; }
    public decimal Price { get; set; }
    public decimal ResolvedRate { get; set; }
    public decimal Workmanship { get; set; }
    public decimal Profit { get; set; }
    public bool TaxEnabled { get; set; }
}

public class GoldPartyEditModel
{
    public int PartyId { get; set; }
    public string PartyCode { get; set; } = "";
    public string PartyType { get; set; } = "Customer";
    public string FullName { get; set; } = "";
    public string? NationalId { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public int? DetailLinkId { get; set; }
    public string? DetailAccountCode { get; set; }
    public bool IsActive { get; set; } = true;
}

public class GoldPartyLedgerRow
{
    public long LedgerId { get; set; }
    public int PartyId { get; set; }
    public int? InvoiceId { get; set; }
    public DateTime EntryDate { get; set; }
    public string EntryType { get; set; } = "";
    public decimal DebitRial { get; set; }
    public decimal CreditRial { get; set; }
    public decimal DebitGoldGram { get; set; }
    public decimal CreditGoldGram { get; set; }
    public decimal DebitCurrency { get; set; }
    public decimal CreditCurrency { get; set; }
    public string? CurrencyCode { get; set; }
    public string? Description { get; set; }
}

public class GoldInvoiceResultRow
{
    public int InvoiceId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public decimal Tax { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal BalanceRial { get; set; }
}
