namespace Tarazin.Models;

// ============================================================
// BI — داشبورد و Business Intelligence (PRD BI §1–§121).
// الگوی غالب گزارش‌ها: ردیف‌های KPI با مقایسهٔ دوره‌ای + سری‌های نمودار.
// همهٔ داده‌ها از دیتابیس واقعی نرم‌افزار می‌آیند — هیچ دادهٔ نمایشی نیست.
// ============================================================

/// <summary>یک ردیف KPI با مقایسهٔ دوره قبلی (الگوی مشترک همهٔ داشبوردها).</summary>
public class BiKpiRow
{
    public string KpiKey { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal Amount { get; set; }
    public decimal? PrevAmount { get; set; }
    public decimal? Change { get; set; }
    public decimal? ChangePercent { get; set; }
    public string Direction { get; set; } = "Flat";     // Up | Down | Flat
    public string Status { get; set; } = "Neutral";     // Good | Bad | Neutral
    public string? Unit { get; set; }
    public string? Link { get; set; }                    // مسیر Drill-down (§105)
    public string? Formula { get; set; }                 // §106 — فرمول KPI
    public string? Source { get; set; }                  // §106 — منبع داده
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>ردیف سری زمانی (نمودار Line/Bar/Area).</summary>
public class BiSeriesRow
{
    public DateTime Bucket { get; set; }
    public string Label { get; set; } = "";
    public decimal Value1 { get; set; }                  // معمولاً فروش/درآمد/دریافت
    public decimal Value2 { get; set; }                  // هزینه/پرداخت/دوره قبل
    public decimal Value3 { get; set; }                  // سود/خالص/سری سوم
    public decimal Value4 { get; set; }                  // سری چهارم (تعداد و …)
}

/// <summary>ردیف ترکیب (نمودار Donut/Pie/Bar — مثل ترکیب دارایی §11).</summary>
public class BiCompositionRow
{
    public string GroupKey { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal Value { get; set; }
    public decimal? SecondaryValue { get; set; }
}

/// <summary>ردیف جدول تحلیلی (Top Debtors / Top Suppliers / Cheque Calendar / …).</summary>
public class BiTableRow
{
    public string RowKey { get; set; } = "";
    public string Col1 { get; set; } = "";
    public string Col2 { get; set; } = "";
    public string Col3 { get; set; } = "";
    public string Col4 { get; set; } = "";
    public string Col5 { get; set; } = "";
    public decimal Amount { get; set; }
    public decimal? SecondaryAmount { get; set; }
    public DateTime? Date1 { get; set; }
    public string? Link { get; set; }
}

/// <summary>هشدار (مرکز هشدار — §102): Critical/Warning/Information با اقدام پیشنهادی.</summary>
public class BiAlertRow
{
    public string AlertKey { get; set; } = "";
    public string Severity { get; set; } = "Warning";    // Critical | Warning | Information
    public string Title { get; set; } = "";
    public string? Detail { get; set; }
    public decimal? Amount { get; set; }
    public DateTime? OccurredAt { get; set; }
    public string? Source { get; set; }
    public string? Action { get; set; }                  // اقدام پیشنهادی
    public string? Link { get; set; }
}

/// <summary>تحلیل هوشمند متنی (§103/§104) — بر اساس دادهٔ واقعی سیستم.</summary>
public class BiInsightRow
{
    public string InsightKey { get; set; } = "";
    public string Kind { get; set; } = "Info";           // Good | Bad | Info | Action
    public string Title { get; set; } = "";
    public string Detail { get; set; } = "";
    public string? Link { get; set; }
}

/// <summary>امتیاز سلامت کسب‌وکار (§119).</summary>
public class BiHealthRow
{
    public int Score { get; set; }                        // 0..100
    public string Grade { get; set; } = "";              // عالی | خوب | متوسط | ضعیف
    public string? Summary { get; set; }
}

/// <summary>ردیف نقطهٔ نمودار قیمت طلا/ارز (از RateHistory).</summary>
public class BiPricePointRow
{
    public DateTime ChangedAt { get; set; }
    public string ItemKey { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal NewValue { get; set; }
}

/// <summary>هدف تعریف‌شده (§117).</summary>
public class BiTargetRow
{
    public int TargetId { get; set; }
    public string TargetKey { get; set; } = "";          // Sales | Profit | Expense | Collection
    public string Title { get; set; } = "";
    public string Period { get; set; } = "Month";        // Month | Year
    public int PeriodYear { get; set; }
    public int? PeriodMonth { get; set; }
    public decimal TargetAmount { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>هدف در برابر عملکرد واقعی (§117).</summary>
public class BiTargetVsActualRow
{
    public string TargetKey { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal TargetAmount { get; set; }
    public decimal ActualAmount { get; set; }
    public decimal Variance { get; set; }
    public decimal VariancePercent { get; set; }
    public decimal ProgressPercent { get; set; }
    public string Status { get; set; } = "Neutral";      // Good | Bad | Neutral
}
