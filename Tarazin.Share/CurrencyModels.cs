namespace Tarazin.Models;

// ============================================================
// Currency module (ارز و معاملات ارزی) — PRD §34–§63.
// واحد مرجع تمام محاسبات: ریال (IRR). هر دارایی با واحد اصلی
// خودش نگهداری می‌شود ولی ارزش‌گذاری/گزارش‌گیری بر مبنای ریال است.
// ستون‌های اسکریپت‌های نامدار باید با همین نام‌ها هم‌نام باشند (ADR-003).
// ============================================================

/// <summary>Contract: Currency (تعریف ارز) — §34/§35.</summary>
public class CurrencyDefRow
{
    public int CurrencyId { get; set; }
    public string CurrencyCode { get; set; } = "";    // IRR | TOMAN | USD | EUR | AED | GBP | TRY | CNY | IQD | KWD | SAR | CHF | CAD | AUD | JPY | RUB
    public string CurrencyName { get; set; } = "";    // ریال ایران، تومان، دلار آمریکا، …
    public string? Symbol { get; set; }               // ﷼ | تومان | $ | € | …
    public bool IsBase { get; set; }                  // واحد پایهٔ سیستم (ریال)
    public decimal UnitFactor { get; set; } = 1m;     // ضریب نسبت به ریال: IRR=1 ، TOMAN=10
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Contract: Setting (تنظیمات ارز).</summary>
public class CurrencySettingRow
{
    public string SettingKey { get; set; } = "";
    public string SettingValue { get; set; } = "";
    public string? Description { get; set; }
}

/// <summary>Contract: PriceSource (منبع قیمت) — §44/§45/§57/§58/§61.</summary>
public class PriceSourceRow
{
    public int SourceId { get; set; }
    public string SourceKey { get; set; } = "";       // TABLOTALA | MATISA | MANUAL | …
    public string Title { get; set; } = "";
    public string? BaseUrl { get; set; }
    public string? Endpoint { get; set; }             // آدرس API/Feed رسمی (قابل ویرایش توسط مدیر)
    public string? MappingsJson { get; set; }         // نگاشت کلید آیتم ← مسیر در پاسخ
    public bool IsActive { get; set; }
    public int Priority { get; set; }                 // ترتیب منابع (§58)
    public int FetchIntervalSeconds { get; set; }
    public string Status { get; set; } = "Unknown";   // Online | Offline | Disabled
    public DateTime? LastFetchAt { get; set; }
    public DateTime? LastSuccessAt { get; set; }
    public DateTime? LastValidAt { get; set; }
    public string? LastError { get; set; }
    public int ErrorCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Contract: PriceItem (آیتم مرکز قیمت) — §43.</summary>
public class PriceItemRow
{
    public int PriceItemId { get; set; }
    public string ItemType { get; set; } = "";        // Currency | Gold | Coin | Metal
    public string ItemKey { get; set; } = "";         // USD | XAU-18 | SIKKEH-EMAMI | XAG
    public string Title { get; set; } = "";
    public string? Unit { get; set; }                 // گرم | سکه | انس | واحد
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>
/// Contract: PriceRate — ردیف مرکز نرخ‌ها (§42/§45/§47/§60).
/// همهٔ قیمت‌های سیستم از این جدول تغذیه می‌شوند؛ نرخ معامله در
/// خودِ معامله قفل می‌شود (§48).
/// </summary>
public class PriceRateRow
{
    public int RateId { get; set; }
    public int PriceItemId { get; set; }
    public string ItemType { get; set; } = "";
    public string ItemKey { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Unit { get; set; }
    public decimal? OnlineRate { get; set; }          // نرخ آنلاین (مرجع — هرگز مستقیم وارد معامله نمی‌شود)
    public decimal? ManualRate { get; set; }          // نرخ دستی
    public decimal SystemRate { get; set; }           // نرخ سیستم — تنها نرخی که وارد معاملات می‌شود
    public decimal? BuyRate { get; set; }             // نرخ خرید
    public decimal? SellRate { get; set; }            // نرخ فروش
    public decimal? AccountingRate { get; set; }      // نرخ حسابداری
    public decimal? MidRate { get; set; }             // نرخ میانی
    public decimal? Spread { get; set; }              // تفاوت خرید/فروش (§42)
    public string? SourceKey { get; set; }            // منبع فعال نرخ آنلاین (§45)
    public string? SourceTitle { get; set; }
    public decimal? PrevValue { get; set; }           // نرخ قبلی (§45)
    public decimal? ChangePercent { get; set; }       // درصد تغییر (§45)
    public decimal? ChangeAmount { get; set; }        // مبلغ تغییر (§45)
    public bool IsOverride { get; set; }              // نرخ سیستم دستی override شده (§46)
    public bool IsValid { get; set; }                 // وضعیت معتبر بودن نرخ (§45/§57)
    public string Status { get; set; } = "";          // Active | Stale | Offline
    public DateTime? LastFetchAt { get; set; }        // آخرین دریافت آنلاین (§45)
    public DateTime? LastChangeAt { get; set; }       // آخرین تغییر (§45)
    public DateTime? RateDate { get; set; }
    public DateTime UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Contract: RateHistory — تاریخچهٔ نرخ‌ها (§49).</summary>
public class RateHistoryRow
{
    public long HistoryId { get; set; }
    public string ItemType { get; set; } = "";
    public string ItemKey { get; set; } = "";
    public string Title { get; set; } = "";
    public string RateKind { get; set; } = "";        // Online | System | Manual | Buy | Sell | Accounting | Transaction
    public decimal? PrevValue { get; set; }
    public decimal NewValue { get; set; }
    public string? SourceKey { get; set; }
    public string ChangeType { get; set; } = "";      // AutoFetch | Manual | Override | Transaction
    public string? Reason { get; set; }
    public string? ChangedBy { get; set; }
    public DateTime ChangedAt { get; set; }
    public bool IsOnline { get; set; }
}

/// <summary>Contract: RateComparison — مقایسهٔ منابع (§59).</summary>
public class RateComparisonRow
{
    public string ItemType { get; set; } = "";
    public string ItemKey { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal? TabloRate { get; set; }
    public decimal? MatisaRate { get; set; }
    public decimal? OtherRate { get; set; }
    public decimal SystemRate { get; set; }
    public DateTime? TabloAt { get; set; }
    public DateTime? MatisaAt { get; set; }
}

/// <summary>Contract: Wallet — کیف پول و موجودی ارز (§36/§52).</summary>
public class WalletRow
{
    public string CurrencyCode { get; set; } = "";
    public string CurrencyName { get; set; } = "";
    public string Symbol { get; set; } = "";
    public decimal Quantity { get; set; }
    public decimal? AvgBuyRate { get; set; }          // نرخ متوسط خرید
    public decimal SystemRate { get; set; }           // نرخ جاری (سیستم)
    public decimal RialValue { get; set; }            // ارزش ریالی = Quantity × SystemRate
    public decimal UnrealizedPnl { get; set; }        // سود/زیان تغییر ارزش (§52)
    public decimal OpeningQty { get; set; }           // موجودی اول دوره
    public decimal OpeningAvgRate { get; set; }
    public decimal InQty { get; set; }                // ورود دوره
    public decimal OutQty { get; set; }               // خروج دوره
    public DateTime? LastMovementAt { get; set; }
}

/// <summary>Contract: CurrencyMovement — گردش ارز (§36).</summary>
public class CurrencyMovementRow
{
    public long MovementId { get; set; }
    public string MovementNumber { get; set; } = "";
    public DateTime MovementDate { get; set; }
    public string? MovementTime { get; set; }
    public string MovementType { get; set; } = "";    // Buy | Sell | In | Out | Transfer | Conversion | Adjustment
    public string Direction { get; set; } = "";       // In | Out
    public string CurrencyCode { get; set; } = "";
    public string CurrencyName { get; set; } = "";
    public decimal Quantity { get; set; }
    public decimal Rate { get; set; }                 // نرخ معامله (قفل‌شده — §48)
    public decimal AmountRial { get; set; }
    public string? CounterPartyName { get; set; }
    public string? FundType { get; set; }             // Cash | Bank
    public int? FundId { get; set; }
    public string? FundTitle { get; set; }
    public int? FxTransactionId { get; set; }
    public int? DocumentId { get; set; }
    public string? Description { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>Contract: FxTransaction — سربرگ معاملهٔ ارز (§37/§38/§39).</summary>
public class FxTransactionRow
{
    public int FxTransactionId { get; set; }
    public string TransactionNumber { get; set; } = "";
    public DateTime TransactionDate { get; set; }
    public string? TransactionTime { get; set; }
    public string TransactionType { get; set; } = ""; // Buy | Sell | Conversion | Combined | Transfer
    public string? PartyName { get; set; }
    public string Status { get; set; } = "";
    public decimal TotalRial { get; set; }
    public int? DocumentId { get; set; }
    public string? DocumentNumber { get; set; }
    public string? Description { get; set; }
    public int LegCount { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>Contract: FxTransactionLeg — پای معامله (ترکیبی §38).</summary>
public class FxTransactionLegRow
{
    public long LegId { get; set; }
    public int FxTransactionId { get; set; }
    public string LegType { get; set; } = "";         // Currency | Gold | Coin | Metal | Rial
    public string ItemKey { get; set; } = "";
    public string Title { get; set; } = "";
    public string Direction { get; set; } = "";       // In | Out
    public decimal? Quantity { get; set; }
    public decimal? Rate { get; set; }                // نرخ قفل‌شدهٔ معامله
    public decimal AmountRial { get; set; }
    public decimal? RealizedPnl { get; set; }         // سود/زیان محقق‌شدهٔ این پای (§52)
    public string? FundType { get; set; }
    public int? FundId { get; set; }
    public string? Description { get; set; }
}

/// <summary>Contract: ConvertResult — پیش‌نمایش/ثبت تبدیل ارز (§39–§41).</summary>
public class ConvertResultRow
{
    public string SourceCurrency { get; set; } = "";
    public decimal SourceAmount { get; set; }
    public decimal SourceRate { get; set; }
    public string TargetCurrency { get; set; } = "";
    public decimal TargetAmount { get; set; }
    public decimal TargetRate { get; set; }
    public string FeeType { get; set; } = "";         // None | Percent | Fixed
    public decimal FeeValue { get; set; }
    public string FeeChargeTo { get; set; } = "";     // Source | Target | Rial
    public decimal FeeAmount { get; set; }
    public decimal RialAmount { get; set; }           // ارزش ریالی مبلغ مبدا
    public decimal FinalAmount { get; set; }          // مبلغ نهایی مقصد پس از کارمزد
    public decimal FinalRate { get; set; }            // نرخ نهایی مؤثر
    public decimal RateDiff { get; set; }             // اختلاف نرخ (§40)
    public decimal Pnl { get; set; }                  // سود/زیان تبدیل (§40)
    public string RateSource { get; set; } = "";      // Auto | Manual
    public string? SourceKey { get; set; }            // منبع نرخ (§40)
    public DateTime RateDate { get; set; }
    public string? Message { get; set; }
}

/// <summary>Contract: AssetValuationRow — ارزش لحظه‌ای دارایی (§50/§51).</summary>
public class AssetValuationRow
{
    public string GroupKey { get; set; } = "";        // Cash | Currency | Gold | Coin | Metal
    public string AssetType { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Unit { get; set; }
    public decimal? Quantity { get; set; }
    public decimal? Rate { get; set; }
    public decimal RialValue { get; set; }
    public decimal? UnrealizedPnl { get; set; }
}

/// <summary>Contract: AssetValuationSummary — جمع‌بندی ارزش دارایی.</summary>
public class AssetValuationSummaryRow
{
    public decimal TotalRial { get; set; }
    public decimal CashPart { get; set; }
    public decimal CurrencyPart { get; set; }
    public decimal GoldPart { get; set; }
    public decimal CoinPart { get; set; }
    public decimal MetalPart { get; set; }
    public decimal YesterdayTotal { get; set; }
    public decimal Change { get; set; }
    public decimal ChangePercent { get; set; }
}

/// <summary>Contract: AssetValuationSnapshot — اسنپ‌شات روزانهٔ ارزش.</summary>
public class AssetValuationSnapshotRow
{
    public int SnapshotId { get; set; }
    public DateTime SnapshotDate { get; set; }
    public decimal TotalRial { get; set; }
    public decimal CashPart { get; set; }
    public decimal CurrencyPart { get; set; }
    public decimal GoldPart { get; set; }
    public decimal CoinPart { get; set; }
    public decimal MetalPart { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>Contract: PnlBreakdown — تفکیک سود و زیان (§53).</summary>
public class PnlBreakdownRow
{
    public string PnlKey { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal Amount { get; set; }
}

/// <summary>Contract: RateChart — نقطهٔ نمودار تاریخچهٔ نرخ (§49).</summary>
public class RateChartRow
{
    public DateTime ChangedAt { get; set; }
    public decimal NewValue { get; set; }
}

/// <summary>نتیجهٔ دریافت آنلاین نرخ از یک منبع (§44/§57/§58).</summary>
public sealed class PriceSourceFetchResult
{
    public string SourceKey { get; set; } = "";
    public string Title { get; set; } = "";
    public bool Success { get; set; }
    public int ItemCount { get; set; }
    public string? Error { get; set; }
    public DateTime FetchedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>خلاصهٔ یک چرخهٔ دریافت نرخ از همهٔ منابع فعال.</summary>
public sealed class PriceFeedResult
{
    public List<PriceSourceFetchResult> Results { get; set; } = new();
    public int SuccessCount => Results.Count(r => r.Success);
    public int TotalCount => Results.Count;
}

/// <summary>یک مقدار استخراج‌شده از خروجی منبع برای اعمال در مرکز نرخ‌ها.</summary>
public sealed class FeedItemValue
{
    public string ItemKey { get; set; } = "";
    public decimal Value { get; set; }
    public DateTime FetchedAt { get; set; } = DateTime.UtcNow;
}
